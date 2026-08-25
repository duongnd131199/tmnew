# True-Tick Market Pipeline Design

## Goal

Make Prices, Chart, and Trade display every real broker tick delivered by the
configured MT5 source with no intentional mobile delay, while preserving one
ordered source of truth and never inventing intermediate financial prices.

The controlled-system target is at least 10 accepted ticks per second for one
symbol and publication to Flutter within one rendered frame after SignalR
delivery. Live cadence can still be lower when the broker itself emits fewer
ticks or the network is unavailable; exact parity with the native MT5 terminal
cannot be guaranteed independently of those external inputs.

## Evidence and root cause

- Prices, Chart, and Trade already consume the same
  `demoQuoteProvider(symbol)` family. A shared production family instance calls
  `RealtimeMarketService.watchQuote`; there is no debounce or throttle in the
  mobile SignalR handler.
- A direct sample of the public XAUUSD+ REST snapshot on 2026-08-20 observed 15
  distinct source timestamps over 10.3 seconds, approximately 1.46 distinct
  ticks per second. Gaps ranged from about 0.19 to 1.78 seconds.
- `TradingDemoMarketBridge.mq5` checks symbols on a 100 ms timer, but each
  `WebRequest` is synchronous. While the HTTP request is in flight, the EA only
  retains the latest `SymbolInfoTick`, so broker ticks between two timer passes
  can be skipped.
- The bridge posts one request per changed symbol. Multiple mapped symbols
  therefore add sequential network round trips to the same timer callback.
- `MarketFeedService.IngestTickAsync` publishes the quote and then nine candle
  events sequentially before the ingestion endpoint responds. This extends the
  synchronous EA request and further reduces its effective sampling rate.
- Lowering only the mock interval cannot affect production because the APK is
  configured to use `https://trochoi.top`.
- REST polling from Flutter cannot create additional source ticks and would
  add server load. Synthetic interpolation would display prices the broker
  never sent and is prohibited.

## Chosen architecture

Use a loss-resistant HTTP batch bridge and a bounded, ordered server ingestion
queue. Keep SignalR and the existing shared Riverpod quote family.

```text
MT5 tick history (CopyTicksRange)
  -> EA 50 ms capture window
  -> one bounded tick batch HTTP request
  -> ASP.NET bounded Channel queue
  -> single ordered ingestion worker
  -> canonical quote/candle store
  -> parallel QuoteUpdated + CandleUpdated publication for one tick
  -> shared Flutter demoQuoteProvider(symbol)
  -> Prices + Chart + Trade in the same event/frame
```

### MT5 bridge

- Change the default capture interval from 100 ms to 50 ms, retaining the
  existing minimum of 50 ms.
- After the initial current tick establishes each mapping's cursor, use
  `CopyTicksRange` from the last acknowledged millisecond through the current
  broker time. This recovers ticks that arrived while a synchronous
  `WebRequest` was running.
- Preserve broker order within each symbol. A batch may contain multiple ticks
  per symbol and multiple mapped symbols.
- Limit one request to 256 ticks. Leave the cursor at the last acknowledged
  tick so overflow is sent in the next timer pass.
- Post one JSON object with a `ticks` array to
  `POST /api/market/feed/ticks/batch` instead of one HTTP request per symbol.
- Advance cursors only after a 2xx response. A failed or timed-out request is
  retried without losing its unsent range.
- Do not include account credentials, login, password, or trading commands.

### Backend ingestion

- Add a typed `TickBatchIngestRequest` with 1–256 `TickIngestRequest` items.
- Apply the existing feed-key authorization and existing tick validation to
  every item before enqueueing the batch. Invalid batches fail atomically with
  the current validation response style.
- Add a bounded `Channel<MarketTick>` with capacity 4096 and a single reader.
  Full mode waits, providing backpressure instead of dropping financial data.
- The batch endpoint returns `202 Accepted` after the validated batch has been
  enqueued, without waiting for SignalR fan-out.
- A hosted worker consumes ticks in queue order and calls the canonical
  `MarketFeedService`. Store rejection continues to prevent older timestamps
  from moving state backwards.
- Treat an exact retry (same symbol, timestamp, bid, ask, and source) as a
  duplicate and do not publish it twice. Equal timestamps with different price
  content remain valid and retain arrival order.
- For one accepted tick, start quote publication and all updated candle
  publications together with `Task.WhenAll`. The worker awaits that group
  before consuming the next tick, preserving visible tick order while removing
  nine sequential SignalR waits.
- Keep the existing single-tick endpoint for compatibility. It must use the
  same validation, duplicate rules, queue, and ordering guarantees.

### Flutter client

- Keep `demoQuoteProvider(symbol)` as the only live quote source used by Prices,
  Chart, Trade, and order tickets.
- Extend `DemoQuote` with an optional broker timestamp populated from REST and
  `QuoteUpdated`. Existing fixtures may omit it.
- `RealtimeMarketService` must discard only strictly older source timestamps.
  Equal-timestamp events remain ordered so distinct same-millisecond ticks are
  not lost.
- Dispatch every accepted SignalR quote directly to the existing broadcast
  controller. Do not add debounce, throttle, REST polling, animation-generated
  prices, or artificial periodic ticks in production.
- Chart continues deriving the active candle from quote ticks. Trade continues
  recalculating open-position P/L from the same quote. Prices renders the same
  quote object and direction color.
- Optimize only if tests prove frame loss. Do not split the shared quote source
  or add independent per-tab timers.

## Failure and recovery behavior

- Bridge HTTP failure: do not advance the acknowledged cursor; resend the
  bounded range on the next callback.
- Queue saturation: await capacity and apply HTTP backpressure; never silently
  drop the oldest or newest tick.
- Duplicate retry: accept safely without republishing the exact same tick.
- Older tick: reject from canonical state and never send it to Flutter.
- SignalR reconnect: keep the current REST snapshot recovery and resubscribe
  flow. A refreshed snapshot older than the latest received SignalR timestamp
  cannot overwrite the latest quote.
- Market closed or sparse broker feed: show the last real quote and connection
  status; do not manufacture movement.

## Testing strategy

### Backend

- A gated publisher proves all quote/candle publication tasks for one tick
  start before any gate is released; the old sequential implementation must
  fail this test.
- Enqueue an ordered burst of at least 50 ticks and assert 50 ordered quote
  publications, the latest canonical store value, and correct candles.
- Retry an exact batch and assert no duplicate SignalR publication.
- Submit an older tick after a newer tick and assert it is not published.
- Fill a small test queue and assert producers wait rather than drop data.
- Verify batch size 0 and 257, invalid quote values, and invalid feed key are
  rejected.
- Existing single-tick, candle, status, authorization, architecture, and
  integration tests remain green.

### MT5 bridge contract

- Add a deterministic contract test for the batch JSON accepted by the API.
- Verify multiple ticks for the same symbol retain array order and precise
  `timeMsc`, bid, ask, symbol, and source values.
- Verify a failed batch does not advance the documented cursor behavior during
  manual EA validation.

### Flutter

- Feed multiple consecutive `QuoteUpdated` events and assert the quote stream
  exposes every event in source order without a timer delay.
- Deliver an older timestamp after a newer timestamp and assert the UI retains
  the newer quote.
- Deliver two distinct equal-timestamp ticks and assert both remain observable.
- Widget tests assert the latest burst tick reaches Prices, Chart active candle,
  and Trade position P/L after one pump/frame.
- Existing market-watch parity, chart behavior, trading valuation, reconnect,
  and cross-tab tests remain green.

## Verification and delivery

- Run `flutter analyze`, the relevant market/chart/trade tests, and the full
  `flutter test` suite.
- Run `dotnet build Trading.sln` and `dotnet test Trading.sln --no-build`.
- Run the local market API script and a controlled 10+ ticks/second burst.
- Build `flutter build apk --debug`, install it with `adb install -r`, and
  confirm Prices, Chart, and Trade remain synchronized without runtime errors.
- Compile and deploy the updated EA and backend separately before expecting the
  public `trochoi.top` feed cadence to change. APK installation alone cannot
  accelerate the upstream source.

## Non-goals and constraints

- No synthetic or interpolated production prices.
- No real-money order placement or broker credential handling.
- No change from Flutter/Riverpod/SignalR and ASP.NET Core.
- No claim that the UI can update faster than the broker emits real ticks.
- No production deployment, service restart, or EA replacement without the
  required server access and explicit deployment authorization.

## Acceptance criteria

1. A controlled 10+ ticks/second burst is accepted without loss or reordering.
2. Exact retries do not create duplicate visible ticks.
3. Older ticks cannot overwrite or flash after newer ticks.
4. Backend ingestion response is decoupled from SignalR fan-out latency.
5. Prices, Chart, and Trade consume the same last real quote within one Flutter
   frame after delivery.
6. Sparse/closed markets remain still rather than showing fabricated movement.
7. Full Flutter and backend validation passes and the debug APK runs on
   LDPlayer without clearing login data.
