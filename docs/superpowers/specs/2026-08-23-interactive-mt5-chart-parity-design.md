# Interactive MT5 Chart Parity Design

## Goal

Make the Chart experience on the development LDPlayer interactive after the
verification run, source BTCUSD quotes and candles from the same public MT5
bridge used by production, and match the live MT5 reference Chart chrome and
plot geometry while preserving the clone's existing five-item dark bottom
navigation design.

## Confirmed root causes

The APK left on `emulator-5554` was built from
`integration_test/chart_performance_test.dart`. That target overrides the
production market origin with `benchmark.invalid.example`, replaces BTCUSD
history and realtime providers with deterministic fixtures, and leaves the
last test frame visible after the integration binding finishes. Android
semantics still reports the five tabs as enabled and clickable, but a real ADB
tap on the `Gia` bounds does not change the selected branch after the test has
finished.

The production bootstrap is separate and correctly injects
`MarketApiConfig.production`, whose default origin is `https://trochoi.top`.
A direct public probe returned BTCUSD M5 history and a quote whose source was
`Exness Technologies Ltd / Exness-MT5Trial7`. The server accepts exact bid,
ask, broker timestamp, and seeded OHLC values from
`TradingDemoMarketBridge.mq5`; Flutter does not need a second price source.

The current static Chart layout also differs from the live MT5 reference. On
the canonical 590 x 1280, 240-dpi device, the measured differences include:

- one-click strip `y=120..183` in the clone versus `y=120..180` in MT5;
- plot/right-axis boundary `x=489` versus `x=476`;
- vertical grid spacing of about 71 physical pixels versus 42 pixels;
- horizontal price-label spacing of about 59 pixels versus 42 pixels;
- different toolbar ordering and hit-target positions;
- extra OHLC text and the shortened `Bitcoin` subtitle instead of the current
  MT5 title/subtitle presentation;
- narrower candle bodies and a different default viewport/right padding.

## Runtime architecture

Keep `lib/main.dart` and `DeviceGate` as the authenticated production entry
point. Add a clearly named development-only Chart parity entry point that
runs the same `TradingApp`, `appRouter`, `AppShell`, Chart providers, REST
client, SignalR client, painter, and navigation callbacks, but does not require
an EX V2 device token. It injects only `MarketApiConfig.production`; it must not
override quote, candle, position, clock, or realtime providers.

The parity entry point exists because the previous integration run cleared the
device's secure-storage session. It is a visual/interaction development build,
not a replacement for the authenticated production APK. Both entry points are
built and verified. No feed key, broker credential, or trading password is
embedded in either APK.

The performance integration target remains deterministic and test-only. It may
render the production shell during measurement, but it is never the final APK
left running for manual acceptance.

## Navigation behavior

Preserve the existing `MtBottomNavigationBar` colors, capsule geometry, icons,
Vietnamese labels, selected-state treatment, and five destinations. Do not
redesign it to the white native MT5 bottom bar.

The final device gate is physical input, not only `WidgetTester.tap`: install
the normal parity APK, launch it without an instrumentation runner, use ADB
input to visit Prices, Chart, Trade, History, and Settings, and verify the
selected semantics plus visible route content after every tap. Returning to
Chart must retain a usable BTCUSD M5 screen.

## Market-data behavior

The parity build consumes:

```text
https://trochoi.top/api/market/candles
https://trochoi.top/api/market/quotes/{symbol}
https://trochoi.top/hubs/market
```

REST history seeds the exact broker OHLC/time/volume sequence. SignalR quote
and candle events update the active candle without interpolation, local random
movement, domain shifting, or screenshot-shaped fallback data once production
history is available. Bid and ask shown in the one-click strip come from the
same `DemoQuote` event used by Prices and Trade.

During initial loading, the last valid broker frame may remain visible. If no
broker frame has ever loaded, show an explicit light loading/error state rather
than a fabricated reference contour. Reconnect may refresh REST history, but
an older snapshot cannot overwrite a newer broker timestamp.

Exact equality is checked at component boundaries: decoded REST candles equal
the payload, accepted SignalR quotes preserve bid/ask/source timestamp, and the
Chart painter receives the same values. Two independently captured live
screens can show different ticks because capture and network timestamps differ;
the implementation must never alter a received financial value to force a
screenshot match.

## Chart visual contract

The Chart region above the preserved bottom navigation follows the current
native MT5 screen on `emulator-5560`:

- system/status area ends at physical `y=36`;
- Chart toolbar occupies `y=36..120`;
- one-click strip occupies `y=120..180`;
- plot and price axis begin at `y=180` within one physical pixel;
- plot/right-axis boundary is physical `x=476` within one pixel;
- plot bottom border is physical `y=1119` within one pixel;
- time axis ends at physical `y=1151` within one pixel;
- the first visible plot header is `BTCUSD ▾ M5` followed by
  `Bitcoin vs US Dollar` in the native positions;
- default BTCUSD M5 vertical and horizontal grid cadence is approximately
  42 physical pixels and is derived from the measured native geometry;
- candle center spacing, body-to-slot ratio, wick width, right padding, price
  labels, time labels, badges, and line strokes are measured from the live
  reference rather than from self-generated goldens;
- existing light palette values remain canvas `#FFFFFF`, grid `#E8E8E8`,
  bullish `#26A69A`, bearish `#EF5350`, trade blue `#3183FF`, and primary text
  `#000000`.

The toolbar uses the native six 78-physical-pixel cells: drawer,
crosshair, indicators, timeframe, order/one-click control, and chart-window
control. Every visible control remains tappable and retains its existing route
or action; this work must not produce decorative dead icons.

The Chart stays responsive for 360--430 logical-pixel widths. Canonical values
are expressed as layout tokens/ratios and scale from the available width where
appropriate; they are not symbol-specific screenshot contours.

## Comparison method

Capture fresh PNGs and UI hierarchies from both LDPlayers in the same
BTCUSD/M5/one-click-visible state. Normalize neither image because both devices
already use 590 x 1280 at 240 dpi.

The static comparison mask excludes only:

- changing bid/ask and countdown digits;
- candle bodies/wicks whose source timestamp is not shared by both captures;
- position profit and account-owned order values;
- the deliberately preserved dark bottom-navigation design;
- Android clock and status icons.

Toolbar bounds, one-click bounds, plot edges, grid, axes, title/subtitle,
static icons, typography baselines, and colors are not masked. Acceptance
requires every specified boundary within one physical pixel and no unexplained
static-region difference. Self-generated Flutter goldens remain regression
tests, but they are not presented as proof of native parity.

## Testing strategy

Follow TDD for each production change:

1. Add a failing entry-point/configuration contract proving the interactive
   build uses `MarketApiConfig.production` and has no fixture overrides.
2. Add failing navigation tests for all five branches and a device script that
   verifies physical ADB taps after a normal APK launch.
3. Add failing market-data tests proving exact REST/SignalR value preservation
   and removal of fabricated production fallback contours.
4. Add failing geometry/painter tests for the measured toolbar, strip, plot,
   axis, grid, viewport, candle, title, and subtitle metrics.
5. Generate candidate device screenshots only after behavior is green, compare
   them with the native capture, and adjust one measured variable per loop.
6. Re-run focused tests, all Flutter tests, analyzer, debug/profile builds,
   backend build/tests, and the profile performance benchmark.

## Error and safety behavior

- Public API unavailable: keep the last valid broker frame and expose
  reconnecting/error state; never synthesize market prices.
- Device authentication unavailable: production remains on its legitimate
  login gate; the dev parity entry point remains explicitly development-only.
- SignalR reconnect: resubscribe to the active symbol/timeframe and prevent
  stale generations from replacing current state.
- No real-money trades or broker credentials are added. Existing demo order
  behavior remains unchanged.
- The Flutter/Riverpod/GoRouter/Dio/SignalR and ASP.NET Core stack remains
  unchanged.

## Acceptance criteria

1. All five preserved bottom tabs respond to real ADB taps in a normally
   launched APK, and Chart can be left selected after the sequence.
2. The final development LDPlayer is not running an integration-test target.
3. BTCUSD bid, ask, candle OHLC, broker timestamps, and volumes are passed
   unchanged from the public MT5 REST/SignalR payload to Chart.
4. No deterministic Chart benchmark fixture is used by the interactive build.
5. The measured native toolbar, one-click strip, plot, axes, grid, title,
   subtitle, candle geometry, and viewport meet the one-physical-pixel static
   boundary contract on the canonical device.
6. The dark five-tab navigation remains visually unchanged.
7. Pan, pinch zoom, double-tap reset, timeframe changes, one-click controls,
   and Chart toolbar actions remain functional.
8. Flutter analyze, relevant and full tests, debug/profile APK builds, backend
   build/tests, and the device performance gate pass.
9. Both LDPlayers are left running on complete BTCUSD M5 screens with final
   screenshots and an evidence report.

## Repository constraint

The shared checkout is extensively dirty and mostly untracked. This design
document and later implementation files must not be committed as a bundle with
unrelated owner work. Verification reports the exact files changed; no commit
is created unless the owner separately requests one.
