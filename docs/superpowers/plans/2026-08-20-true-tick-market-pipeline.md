# True-Tick Market Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver every captured real MT5 broker tick to Prices, Chart, and Trade without intentional client delay or synthetic interpolation.

**Architecture:** Recover missed terminal ticks with `CopyTicksRange`, submit bounded HTTP batches, enqueue validated ticks into a single-reader ASP.NET Channel, and publish each accepted tick's quote/candles concurrently. Flutter keeps one shared SignalR quote family and rejects strictly older source timestamps.

**Tech Stack:** MQL5 EA, ASP.NET Core 8, `System.Threading.Channels`, SignalR, Flutter 3.44+, Dart, Riverpod, Dio.

**Spec:** `docs/superpowers/specs/2026-08-20-true-tick-market-pipeline-design.md`

## Global Constraints

- Never synthesize or interpolate production prices.
- Preserve Flutter/Riverpod/SignalR and ASP.NET Core; add no replacement stack.
- Preserve the existing feed-key boundary and never expose it to Flutter.
- Preserve the existing single-tick endpoint while routing it through the same ordered queue.
- Queue capacity is 4096, batch size is 1–256, and EA capture interval defaults to 50 ms.
- Exact duplicate retries do not publish twice; strictly older ticks never overwrite newer state.
- Do not deploy or restart `trochoi.top` or replace its EA without explicit deployment authorization.

---

### Task 1: Canonical duplicate handling and parallel fan-out

**Files:**
- Modify: `backend/tests/Trading.UnitTests/MarketFeedServiceTests.cs`
- Modify: `backend/src/Trading.Infrastructure/Market/InMemoryMarketDataStore.cs`
- Modify: `backend/src/Trading.Application/Market/MarketContracts.cs`

**Interfaces:**
- Consumes: `IMarketDataStore.UpsertTick(MarketTick)` and `IMarketRealtimePublisher`.
- Produces: idempotent `UpsertTick` behavior and concurrent publication within `MarketFeedService.IngestTickAsync`.

- [ ] **Step 1: Write the duplicate RED test**

Add a test that ingests the same literal tick twice and asserts the second call returns `false`, the quote publisher contains exactly one event, and the store retains the literal bid/ask.

```csharp
var tick = new MarketTick("XAUUSD+", 4488.10m, 4488.36m, timestamp, "Exness");
Assert.True(await service.IngestTickAsync(tick));
Assert.False(await service.IngestTickAsync(tick));
Assert.Single(publisher.Quotes);
```

- [ ] **Step 2: Run the duplicate test and verify RED**

Run:

```powershell
dotnet test tests/Trading.UnitTests/Trading.UnitTests.csproj --filter ExactDuplicateTickIsPublishedOnce
```

Expected: FAIL because equal timestamp/content currently republishes.

- [ ] **Step 3: Implement exact duplicate rejection**

In `InMemoryMarketDataStore.UpsertTick`, return `false` when current and incoming records have the same symbol, timestamp, bid, ask, and source. Continue accepting a different price at the same millisecond and continue rejecting strictly older timestamps.

- [ ] **Step 4: Verify duplicate GREEN and same-millisecond behavior**

Add and run a test with two distinct equal-timestamp prices; assert both publish in arrival order and the second becomes canonical.

- [ ] **Step 5: Write the parallel publication RED test**

Add a gated publisher whose quote and candle methods record that they started, then await a shared release gate. Start one ingestion without awaiting it and assert one quote plus `MarketTimeframes.Supported.Count` candle calls have started before releasing the gate.

Expected old behavior: only the quote call starts because publication is sequential.

- [ ] **Step 6: Implement and verify parallel fan-out**

Replace sequential awaits with one task array:

```csharp
var publications = new List<Task>(updatedCandles.Count + 1)
{
    _publisher.PublishQuoteAsync(normalized, cancellationToken)
};
publications.AddRange(updatedCandles.Select(candle =>
    _publisher.PublishCandleAsync(candle, cancellationToken)));
await Task.WhenAll(publications);
```

Run the complete `MarketFeedServiceTests` class and confirm all cases pass.

---

### Task 2: Bounded ordered ingestion queue and batch API

**Files:**
- Create: `backend/src/Trading.Api/Market/MarketTickIngestionQueue.cs`
- Modify: `backend/src/Trading.Api/Controllers/MarketFeedController.cs`
- Modify: `backend/src/Trading.Api/Program.cs`
- Create: `backend/tests/Trading.IntegrationTests/MarketTickIngestionQueueTests.cs`
- Create: `backend/tests/Trading.IntegrationTests/MarketFeedBatchContractTests.cs`

**Interfaces:**
- Produces: `MarketTickIngestionQueue.EnqueueAsync(IReadOnlyList<MarketTick>, CancellationToken)`.
- Produces: `POST /api/market/feed/ticks/batch` accepting `TickBatchIngestRequest(IReadOnlyList<TickIngestRequest> Ticks)`.
- Consumes: `MarketFeedService.IngestTickAsync` from Task 1.

- [ ] **Step 1: Write queue RED tests**

Construct a real `MarketFeedService` with an in-memory store and recording publisher. Test these observable behaviors:

1. A 50-tick ordered burst produces exactly 50 ordered quote events and the 50th price in the store.
2. With capacity 1 and a gated worker, the next producer remains incomplete until capacity is released.
3. `StopAsync` drains/terminates without an unhandled exception.

Run:

```powershell
dotnet test tests/Trading.IntegrationTests/Trading.IntegrationTests.csproj --filter MarketTickIngestionQueueTests
```

Expected: compile failure because the queue does not exist.

- [ ] **Step 2: Implement the bounded queue**

Create a `BackgroundService` backed by:

```csharp
Channel.CreateBounded<MarketTick>(new BoundedChannelOptions(capacity)
{
    SingleReader = true,
    SingleWriter = false,
    FullMode = BoundedChannelFullMode.Wait
});
```

`EnqueueAsync` writes every validated tick in array order. `ExecuteAsync` reads with `ReadAllAsync(stoppingToken)` and awaits one `IngestTickAsync` before reading the next tick.

- [ ] **Step 3: Register one shared queue instance**

In `Program.cs`, register one singleton and expose the same object as the hosted service:

```csharp
builder.Services.AddSingleton<MarketTickIngestionQueue>();
builder.Services.AddSingleton<IHostedService>(provider =>
    provider.GetRequiredService<MarketTickIngestionQueue>());
```

- [ ] **Step 4: Write batch contract RED tests**

Deserialize a literal camelCase body containing two XAUUSD+ ticks, submit it through a controller configured with a valid feed key and a running real queue, then wait conditionally for the store to reach the second price. Also assert:

- unauthorized requests return 401;
- 0 and 257 items return validation errors;
- one invalid quote makes the whole batch fail before any tick is enqueued;
- the existing single endpoint enqueues through the same queue.

- [ ] **Step 5: Implement atomic request validation and endpoints**

Extract public application-level tick normalization from the current private `NormalizeTick` so both controller and service use the same rule. Validate/map the full array before calling `EnqueueAsync`. Return `202 Accepted` after enqueue, with no SignalR wait.

- [ ] **Step 6: Verify queue and API GREEN**

Run both backend test projects and confirm the burst, backpressure, auth, size, atomic validation, and compatibility cases pass.

---

### Task 3: MT5 catch-up batching

**Files:**
- Modify: `mt5/Experts/TradingDemoMarketBridge.mq5`
- Modify: `docs/market-data-ubuntu.md`
- Modify: `backend/scripts/local/Test-MarketApi.ps1`

**Interfaces:**
- Consumes: `POST /api/market/feed/ticks/batch` from Task 2.
- Produces: bounded `{ "ticks": [...] }` batches containing exact MQL tick fields.

- [ ] **Step 1: Extend the local API test before changing the EA**

Update `Test-MarketApi.ps1` to send a literal ordered batch of at least 20 ticks with 50–100 ms source timestamp spacing. Poll the public quote endpoint until the last literal bid appears, then assert status is connected and the H4 candle closes at that bid.

Run the script against the local API and verify it fails because the batch route is not yet available in the running baseline.

- [ ] **Step 2: Implement 50 ms bounded collection**

Set `TickIntervalMilliseconds = 50` and add `MaximumBatchTicks = 256`. Establish each mapping's initial cursor from `SymbolInfoTick`, then use `CopyTicksRange` for milliseconds strictly after the acknowledged cursor. Keep ticks ordered per mapping and stop collecting at the batch limit.

- [ ] **Step 3: Implement one batch request and acknowledgement**

Serialize exact `symbol`, `bid`, `ask`, `timeMsc`, and `source` values into one `ticks` array. Call `PostJson("/api/market/feed/ticks/batch", json)` once. Advance each mapping cursor only to the last included tick after a 2xx response; leave all cursors unchanged on failure.

- [ ] **Step 4: Document installation and recovery semantics**

Document the 50 ms default, history catch-up, 256-tick cap, retry behavior, and the requirement to compile/redeploy the EA before production cadence changes.

- [ ] **Step 5: Verify the local burst**

Run `Test-MarketApi.ps1` and confirm the controlled batch reaches the final quote/candle without loss. If MetaEditor is unavailable, report MQL compilation as an explicit deployment-time verification item rather than claiming it was compiled.

---

### Task 4: Flutter source timestamps and stale-tick protection

**Files:**
- Modify: `mobile/lib/shared/models/demo_models.dart`
- Modify: `mobile/lib/features/market_watch/data/data_sources/realtime_market_service.dart`
- Modify: `mobile/lib/features/market_watch/data/data_sources/mock_quote_service.dart`
- Modify: `mobile/test/realtime_market_service_test.dart`
- Relevant tests: `mobile/test/market_watch_parity_test.dart`
- Relevant tests: `mobile/test/chart_controls_test.dart`
- Relevant tests: `mobile/test/video2_functional_regression_test.dart`

**Interfaces:**
- Produces: optional `DateTime? sourceTimestamp` on `DemoQuote`.
- Consumes: REST/SignalR `timestamp` from the existing market API.

- [ ] **Step 1: Write realtime ordering RED tests**

Upgrade the fake hub to retain registered event handlers and expose `emit`. Subscribe once, discard the initial REST snapshot, then emit literal events and assert:

1. Three increasing timestamps are observed immediately and in order.
2. A strictly older event after a newer event is not observed.
3. Two different quotes with an equal timestamp are both observed.

Run:

```powershell
flutter test test/realtime_market_service_test.dart
```

Expected: compile/assertion failure because `DemoQuote` has no source timestamp and the service does not reject stale events.

- [ ] **Step 2: Add optional timestamp and stale guard**

Add `sourceTimestamp` with a default of `null` so existing fixtures remain source-compatible. Parse API timestamps as UTC. Before publishing a REST refresh or SignalR event, discard it only when both timestamps exist and the incoming timestamp is strictly earlier than the latest accepted timestamp.

- [ ] **Step 3: Preserve mock semantics**

Mock ticks may stamp their generated event time for tests/demo mode, but production selection remains unchanged and must never generate periodic ticks while `MarketApiConfig.production` is enabled.

- [ ] **Step 4: Verify screen consumers**

Run the realtime service test plus market-watch parity, live chart, and Trade quote valuation tests. Confirm no screen adds an independent timer, polling loop, debounce, or interpolation.

---

### Task 5: Full verification, benchmark, APK, and LDPlayer

**Files:**
- Verify all files changed in Tasks 1–4.
- Output: `mobile/build/app/outputs/flutter-apk/app-debug.apk`
- Output screenshot: `.codex_tmp/true-tick-ldplayer.png`

**Interfaces:**
- Consumes: the complete true-tick pipeline.
- Produces: verified build artifacts and evidence; no production deployment.

- [ ] **Step 1: Format and inspect**

Run Dart formatting, `dotnet format` only if already configured, `git diff --check`, and inspect the scoped diff without altering unrelated user changes.

- [ ] **Step 2: Run mobile validation**

```powershell
cd mobile
flutter analyze
flutter test --concurrency=1
flutter build apk --debug
```

- [ ] **Step 3: Run backend validation**

```powershell
cd backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

- [ ] **Step 4: Run controlled throughput verification**

Start the local API, send the 10+ ticks/second batch from the updated script, and record accepted/published count, final quote, and final active candle. Stop only the local process started by this task.

- [ ] **Step 5: Install and launch LDPlayer**

Install with `adb -s 127.0.0.1:5555 install -r ...app-debug.apk`, launch `com.tradingdemo.trading_mobile/.MainActivity`, preserve login data, capture the active UI, and inspect recent logcat for fatal Flutter/Android errors.

- [ ] **Step 6: Report deployment boundary**

Report source files, RED/GREEN evidence, test/build totals, APK and screenshot paths. State clearly that public cadence remains unchanged until the updated backend and compiled EA are deployed with explicit authorization.
