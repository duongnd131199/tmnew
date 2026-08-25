# MT5 Light Chart Parity and Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make only the Flutter Chart tab match the live MT5 light chart in color, candle rendering, zoom/pan behavior, timeframe transitions, and perceived runtime performance.

**Architecture:** Retain Flutter, Riverpod, GoRouter, the existing realtime REST/SignalR contracts, and the native `CustomPainter` renderer. First lock the MT5 behavior with reference captures and characterization tests, then isolate the renderer, introduce immutable light-chart tokens and a focal-point-aware viewport model, make timeframe subscriptions lifecycle-safe, and finally measure visual and frame-time parity on both LDPlayers.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, GoRouter, Flutter `CustomPainter`, Dio, SignalR, Flutter unit/widget/integration tests, LDPlayer/ADB.

**Spec:** `docs/screens/chart.md`

## Global Constraints

- Change only Chart-tab code and chart-specific tokens/tests; do not redesign Quotes, Trade, History, Settings, or shared bottom-navigation content.
- Do not change the required technology stack and do not add a WebView or third-party chart library.
- Do not copy MetaTrader source, logos, or proprietary assets; reproduce observed behavior with project-native Flutter code.
- Canonical comparison device is `590 x 1280`, `240 dpi`; continue supporting `360-430` logical-pixel widths.
- Use exact sampled chart colors: `#FFFFFF`, `#E8E8E8`, `#26A69A`, `#EF5350`, `#3183FF`, and `#000000`.
- Supported timeframe matrix is `M1`, `M5`, `M15`, `M30`, `H1`, `H4`, `D1`, `W1`, and `MN`.
- A timeframe switch must not show a blank, black, or stale chart frame.
- Device target is p95 build/raster `<= 16.7 ms` and missed frames `< 2%` during the defined 10-second interaction run.
- After implementation run focused tests, the full Flutter test suite, `flutter analyze`, and `flutter build apk --debug`.

---

### Task 1: Freeze the two-emulator reference matrix

**Files:**
- Create: `scripts/capture-chart-parity.ps1`
- Create: `reference/screens/chart/light/manifest.json`
- Create: canonical evidence images only: `ref-M5-default.png` and
  `dev-before-M5-default.png`; remaining rows are image-free fixtures.
- Modify: `docs/screens/chart.md`

**Interfaces:**
- Consumes: reference MT5 at `127.0.0.1:5561`, development app at `127.0.0.1:5555`, both at `590 x 1280`, `240 dpi`.
- Produces: all 54 `source/timeframe/zoom` rows with device, crop, mask, target
  palette, state, geometry, and timestamp metadata. Only verified canonical
  evidence rows contain a screenshot path; native-pinch rows are explicitly
  image-free fixtures.

- [ ] **Step 1: Add a capture-script contract test**

Create `mobile/test/chart_reference_manifest_test.dart`. It must parse
`../reference/screens/chart/light/manifest.json`, require all 27
timeframe/zoom combinations for both `ref` and `dev-before`, and assert every
entry's canonical device metrics, crop bounds, comparison mask, target palette,
and captured-versus-fixture path/note invariants. It must exercise capture
script preflight with `ANDROID_HOME` unset.

- [ ] **Step 2: Run the manifest test and verify RED**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_reference_manifest_test.dart
```

Expected: FAIL because the manifest and complete capture matrix do not exist.

- [ ] **Step 3: Implement deterministic ADB capture**

Implement `scripts/capture-chart-parity.ps1` with explicit parameters
`-ReferenceSerial`, `-DevelopmentSerial`, `-Timeframe`, `-Zoom`,
`-OperatorStateConfirmation`, and `-OutputRoot`. The confirmation must attest
to matching timeframe/zoom, symbol, and one-click state; zoom is never claimed
as auto-verified. Use `adb shell screencap -p` followed by `adb pull`; never
use PowerShell byte redirection for PNG data. Record device size/density from
`wm size` and `wm density` in the manifest.

- [ ] **Step 4: Capture and annotate the complete matrix**

Capture and annotate the real canonical BTCUSD/M5 default state on both apps.
Reserve the other 52 rows as deterministic, image-free
`fixture-pending-native-pinch` metadata because native pinch automation is not
reliable enough to create truthful evidence. Store geometry and comparison-mask
exclusions in every row.

- [ ] **Step 5: Run the manifest test and verify GREEN**

Run the command from Step 2. Expected: all 54 matrix rows, two canonical image
entries, and 52 honest fixture entries PASS.

- [ ] **Step 6: Record the no-commit exception**

Do not commit Task 1 in the dirty, mostly untracked shared checkout. Record
that an isolated baseline commit is unsafe in the plan and task report.

### Task 2: Extract the renderer without changing current behavior

**Files:**
- Create: `mobile/lib/features/chart/presentation/rendering/chart_hit_targets.dart`
- Create: `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Modify: `mobile/test/chart_controls_test.dart`

**Interfaces:**
- Consumes: `MarketCandle`, positions, pending orders, indicators, chart objects, current quote, timeframe, zoom, pan, and crosshair state currently passed to `_MtCandlePainter`.
- Produces: public `ChartHitTargets` and `Mt5CandlePainter` with the same constructor fields and debug getters used by existing tests.

- [ ] **Step 1: Add renderer characterization assertions**

Extend `chart_controls_test.dart` to assert, for BTCUSD/M5 and XAUUSD+/H4, painter type, price-axis rectangle, bottom-axis rectangle, resolved candle timestamps, visible candle count, current-price badge position, and hit-target mapping before extraction.

- [ ] **Step 2: Run focused tests and verify GREEN baseline**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_controls_test.dart test/live_market_candles_test.dart
```

- [ ] **Step 3: Move rendering code mechanically**

Move `_ChartHitTargets`, `_MtCandlePainter`, and painter-only helpers from `chart_screen.dart` into the two rendering files. Rename them to `ChartHitTargets` and `Mt5CandlePainter`; do not change constants, calculations, gestures, provider watches, or output in this step.

- [ ] **Step 4: Update imports and test-visible types**

Instantiate `Mt5CandlePainter` from `ChartScreen`, preserve the key `chart-canvas`, and keep the existing debug getters `debugResolvedCandles`, `priceAxisRect`, `chartMinPrice`, `chartMaxPrice`, `remainingTimeLabel`, and `visibleCandleCount`.

- [ ] **Step 5: Run focused tests and verify no behavior change**

Run the command from Step 2. Expected: PASS with the same characterization values.

- [ ] **Step 6: Commit the isolation change**

```powershell
git add mobile/lib/features/chart/presentation/rendering mobile/lib/features/chart/presentation/screens/chart_screen.dart mobile/test/chart_controls_test.dart
git commit -m "refactor: isolate chart renderer"
```

### Task 3: Apply the MT5 light palette and chart chrome

**Files:**
- Create: `mobile/lib/features/chart/presentation/theme/chart_reference_theme.dart`
- Create: `mobile/test/chart_light_theme_test.dart`
- Modify: `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`

**Interfaces:**
- Produces: immutable `ChartReferenceTheme.light` with `background`, `foreground`, `grid`, `bullish`, `bearish`, `tradeBlue`, `axisBorder`, and `priceLine` fields.
- Consumes: the theme in both `ChartScreen` chrome and `Mt5CandlePainter`; no chart-specific color remains hard-coded in those files.

- [ ] **Step 1: Write failing palette and widget tests**

Assert the exact sampled ARGB values, white chart `ColoredBox`/canvas, `#E8E8E8` grid paint, `#26A69A` bullish body and wick, `#EF5350` bearish body and wick, black axes/text, and blue position/order lines. Include one test that proves the global dark app theme remains unchanged outside Chart.

- [ ] **Step 2: Run tests and verify RED**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_light_theme_test.dart
```

Expected: FAIL because the plot currently paints `AppColors.background` and dark candle colors `#004C3C`/`#770C17`.

- [ ] **Step 3: Implement the immutable light theme**

Define `ChartReferenceTheme.light` with background `0xFFFFFFFF`, foreground `0xFF000000`, grid `0xFFE8E8E8`, bullish `0xFF26A69A`, bearish `0xFFEF5350`, trade blue `0xFF3183FF`, axis border `0xFFD8D8D8`, and price line `0xFF26A69A`.

- [ ] **Step 4: Route all chart colors through the theme**

Replace dark plot, grid, candle, axis, header, crosshair-label, current-price badge, and chart-only one-click-strip colors. Preserve red/blue tick-direction feedback, but use the reference bearish/trade-blue values. Do not alter shared application or bottom-navigation colors.

- [ ] **Step 5: Run palette and chart regression tests**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_light_theme_test.dart test/chart_controls_test.dart test/chart_market_order_dispatch_regression_test.dart
```

- [ ] **Step 6: Commit the light chart**

```powershell
git add mobile/lib/features/chart/presentation/theme mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart mobile/lib/features/chart/presentation/screens/chart_screen.dart mobile/test/chart_light_theme_test.dart
git commit -m "feat: match MT5 light chart colors"
```

### Task 4: Replace symbol-specific zoom hacks with a focal-point viewport

**Files:**
- Create: `mobile/lib/features/chart/presentation/viewport/chart_viewport.dart`
- Create: `mobile/test/chart_viewport_test.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Modify: `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`
- Modify: `mobile/test/chart_controls_test.dart`
- Modify: `mobile/test/market_chart_route_test.dart`

**Interfaces:**
- Produces: immutable `ChartViewport` with `barSpacing`, `scrollOffset`, and `rightPadding`; `ChartViewportController.beginScale`, `updateScale`, `panBy`, `endPan`, and `reset`.
- Consumes: plot width, candle count, gesture focal point, gesture scale, and drag delta.

- [ ] **Step 1: Write failing pure viewport tests**

Cover these exact invariants: bar spacing clamps to `4-48` logical pixels; default spacing is `32`; newest candle keeps `20` logical pixels of right padding; pinch preserves the focal candle within one candle slot; pan cannot move beyond oldest/newest data; double tap resets spacing, right padding, and offset; calculations remain finite for zero/one candle.

- [ ] **Step 2: Run viewport tests and verify RED**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_viewport_test.dart
```

- [ ] **Step 3: Implement the pure viewport model**

Use candle spacing rather than the current symbol-specific `.64-3` zoom scalar. Compute visible indices from plot width, `barSpacing`, `scrollOffset`, and `rightPadding`; update scroll offset during pinch so the index under `focalPoint.dx` remains stable.

- [ ] **Step 4: Wire gestures to the viewport controller**

Replace `_canonicalZoomFor`, `_scaleStartZoom`, `zoom`, and `horizontalPan` in `ChartScreen`. Keep bounded inertial pan, disable zoom/pan while crosshair or a pending level owns the gesture, and preserve the `chart-gesture-area` and `chart-canvas` keys.

- [ ] **Step 5: Make the painter consume visible-window indices**

Remove symbol/timeframe-specific visible-count, leading-slot, and centered-progress branches. Render the slice selected by `ChartViewport`, use the same body-to-slot ratio as the reference capture, and auto-scale only from visible high/low plus the current price.

- [ ] **Step 6: Run viewport, route, and chart tests**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_viewport_test.dart test/chart_controls_test.dart test/market_chart_route_test.dart
```

- [ ] **Step 7: Commit viewport parity**

```powershell
git add mobile/lib/features/chart/presentation/viewport mobile/lib/features/chart/presentation/screens/chart_screen.dart mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart mobile/test/chart_viewport_test.dart mobile/test/chart_controls_test.dart mobile/test/market_chart_route_test.dart
git commit -m "feat: match MT5 chart zoom and pan"
```

### Task 5: Make timeframe transitions atomic and lifecycle-safe

**Files:**
- Create: `mobile/test/chart_timeframe_transition_test.dart`
- Modify: `mobile/lib/features/chart/data/market_data_provider.dart`
- Modify: `mobile/lib/shared/providers/realtime_market_provider.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Modify: `mobile/test/realtime_market_service_test.dart`
- Modify: `mobile/test/live_market_candles_test.dart`

**Interfaces:**
- Consumes: `MarketDataRequest(symbol, timeframe)`, REST history, quote ticks, and `CandleUpdated` SignalR events.
- Produces: one active realtime candle subscription for the selected request; cached last-valid chart frame; generation-safe atomic swap when the selected timeframe history arrives.

- [ ] **Step 1: Write failing rapid-switch tests**

Simulate `M1 -> M5 -> H1 -> H4` before earlier requests complete. Assert only H4 can replace the visible series, previous UI remains visible while H4 loads, old subscriptions are disposed, the newest candle is right-aligned, zoom spacing is preserved, and the chart never emits an empty/dark frame.

- [ ] **Step 2: Run transition tests and verify RED**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_timeframe_transition_test.dart test/realtime_market_service_test.dart
```

- [ ] **Step 3: Dispose obsolete history and realtime streams**

Convert chart request providers to lifecycle-safe families. Cancel `watchCandle(request)` when the request loses its last listener. Keep the most recent successful history in a bounded cache of the nine supported requests and dispose the local `200 ms` polling loop when inactive.

- [ ] **Step 4: Add generation-safe frame swapping**

Track the selected `MarketDataRequest` generation in `ChartScreen`. Continue painting the previous immutable candle snapshot while the new request loads; replace it only when data for the current generation is non-empty. Reconcile the first live quote into the new active candle without reloading the full series.

- [ ] **Step 5: Match timeframe display behavior**

For all nine timeframes, keep the current bar spacing, reset to the newest candle/right padding, recompute visible price scale, update the title immediately, and swap candle/axis labels together on the first valid frame. Clear only candle-specific crosshair selection; keep one-click visibility and volume unchanged.

- [ ] **Step 6: Run all data and transition tests**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_timeframe_transition_test.dart test/live_market_candles_test.dart test/market_data_service_test.dart test/realtime_market_service_test.dart test/chart_market_warmup_test.dart
```

- [ ] **Step 7: Commit timeframe lifecycle behavior**

```powershell
git add mobile/lib/features/chart/data/market_data_provider.dart mobile/lib/shared/providers/realtime_market_provider.dart mobile/lib/features/chart/presentation/screens/chart_screen.dart mobile/test/chart_timeframe_transition_test.dart mobile/test/realtime_market_service_test.dart mobile/test/live_market_candles_test.dart
git commit -m "fix: make chart timeframe changes atomic"
```

### Task 6: Isolate repaint work and cap per-tick rendering cost

**Files:**
- Create: `mobile/lib/features/chart/presentation/rendering/chart_render_snapshot.dart`
- Create: `mobile/test/chart_repaint_performance_test.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Modify: `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`
- Modify: `mobile/lib/features/chart/data/market_data_provider.dart`

**Interfaces:**
- Produces: immutable `ChartRenderSnapshot` with stable revisions for history, live candle, viewport, overlays, and theme.
- Consumes: only the latest changed candle/quote and the active viewport; static toolbar and shared shell are outside the repaint boundary.

- [ ] **Step 1: Write failing rebuild/repaint-count tests**

Instrument 120 quote ticks. Assert the chart canvas repaints at most once per delivered frame, the app bar and bottom shell do not rebuild per tick, unchanged prices emit no render revision, and only the final candle changes within an existing bucket.

- [ ] **Step 2: Run performance tests and verify RED**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_repaint_performance_test.dart
```

- [ ] **Step 3: Introduce immutable render revisions**

Create `ChartRenderSnapshot` values that preserve list identity for unchanged history and increment only the affected revision. Update `Mt5CandlePainter.shouldRepaint` to compare revisions and viewport/overlay values rather than newly allocated list instances.

- [ ] **Step 4: Isolate reactive regions**

Place the plot in a `RepaintBoundary`; split quote-strip consumers from toolbar/timeframe chrome; use provider `select` calls so quote ticks do not rebuild unrelated chart controls. Keep candle history merging out of `paint` and update only the active candle in provider state.

- [ ] **Step 5: Run performance and functional tests**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_repaint_performance_test.dart test/chart_controls_test.dart test/live_market_candles_test.dart test/chart_market_order_dispatch_regression_test.dart
```

- [ ] **Step 6: Commit rendering optimization**

```powershell
git add mobile/lib/features/chart/presentation/rendering mobile/lib/features/chart/presentation/screens/chart_screen.dart mobile/lib/features/chart/data/market_data_provider.dart mobile/test/chart_repaint_performance_test.dart
git commit -m "perf: isolate realtime chart repaint work"
```

### Task 7: Lock visual parity across timeframe and zoom states

**Files:**
- Create: `mobile/test/chart_light_parity_golden_test.dart`
- Create: `mobile/test/goldens/chart/light/<timeframe>-<zoom>.png`
- Modify: `mobile/test/chart_controls_test.dart`
- Modify: `reference/screens/chart/light/manifest.json`

**Interfaces:**
- Consumes: deterministic candle fixture, the canonical surface derived from `590 x 1280` at `240 dpi`, and the reference mask/geometry metadata.
- Produces: 27 deterministic Flutter golden states and a masked device comparison report.

- [ ] **Step 1: Add deterministic golden scenarios**

Render the same normalized OHLC fixture for all nine timeframes at min/default/max zoom. Include header, axes, grid, current-price badge, bullish/bearish candles, one position line, and one-click strip. Set the surface to the canonical logical size and use a fixed clock.

- [ ] **Step 2: Generate candidate goldens**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test --update-goldens test/chart_light_parity_golden_test.dart
```

- [ ] **Step 3: Review candidates against the MT5 matrix**

Compare chart-region geometry against the reference manifest. Reject any state with a static boundary displaced by more than `1 px`, a wrong exact palette color, or more than `1.5%` differing pixels after masking prices, times, candle contour, system chrome, and shared bottom navigation.

- [ ] **Step 4: Correct painter metrics until all states pass**

Adjust only chart-specific spacing, axis width, label baselines, grid dash spacing, candle body ratio, wick width, right padding, and header offsets. Do not add symbol-specific screenshot contours or fake market candles.

- [ ] **Step 5: Run goldens normally and verify GREEN**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_light_parity_golden_test.dart test/chart_controls_test.dart
```

- [ ] **Step 6: Commit visual parity**

```powershell
git add mobile/test/chart_light_parity_golden_test.dart mobile/test/goldens/chart/light mobile/test/chart_controls_test.dart reference/screens/chart/light/manifest.json
git commit -m "test: lock MT5 light chart visual parity"
```

### Task 8: Device performance, full verification, and handoff

**Files:**
- Create: `mobile/integration_test/chart_performance_test.dart`
- Create: `docs/screenshots/chart-light-parity-report.md`
- Verify: all modified Chart files and tests.

**Interfaces:**
- Consumes: debug APK for functional checks, profile APK for frame timing, both LDPlayer instances, and the reference capture manifest.
- Produces: analyzer/test/build evidence, device screenshots, frame-time statistics, missed-frame ratio, subscription-count evidence, and remaining limitations.

- [ ] **Step 1: Add the device interaction benchmark**

Automate a 10-second sequence containing continuous pan, four pinch zoom-in/out cycles, double-tap reset, and `M1 -> M5 -> M15 -> M30 -> H1 -> H4 -> D1 -> W1 -> MN -> M5`. Record `FrameTiming` build/raster durations and assert p95 `<= 16.7 ms` with missed frames `< 2%` in profile mode.

- [ ] **Step 2: Run focused Chart tests**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_reference_manifest_test.dart test/chart_light_theme_test.dart test/chart_viewport_test.dart test/chart_timeframe_transition_test.dart test/chart_repaint_performance_test.dart test/chart_light_parity_golden_test.dart test/chart_controls_test.dart test/live_market_candles_test.dart test/market_data_service_test.dart test/realtime_market_service_test.dart test/market_chart_route_test.dart test/chart_market_order_dispatch_regression_test.dart
```

- [ ] **Step 3: Run project-required verification**

```powershell
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat test
D:\toolchains\flutter\bin\flutter.bat build apk --debug
D:\toolchains\flutter\bin\flutter.bat build apk --profile
```

- [ ] **Step 4: Install and run the profile benchmark**

Install the profile APK on `127.0.0.1:5555`, reset `dumpsys gfxinfo com.tradingdemo.trading_mobile`, run the benchmark, and collect `framestats`. Repeat the equivalent manual interaction on MT5 at `127.0.0.1:5561` as the perceived-performance reference.

- [ ] **Step 5: Perform the final side-by-side acceptance pass**

Check all 27 timeframe/zoom states, live last-candle updates, focal-point zoom, inertial pan, double-tap reset, one-click strip, position/order lines, and 20 rapid timeframe switches. Confirm no dark flash, stale request, subscription leak, or interaction regression.

- [ ] **Step 6: Write the parity report**

Record exact commands, APK path, test totals, analyzer result, p50/p95/p99 build and raster times, missed-frame percentage, static pixel-diff percentage for every state, screenshots, changed files, and any data-source-only differences in `docs/screenshots/chart-light-parity-report.md`.

- [ ] **Step 7: Commit verification artifacts**

```powershell
git add mobile/integration_test/chart_performance_test.dart docs/screenshots/chart-light-parity-report.md
git commit -m "test: verify chart parity and performance"
```

---

## Self-review

- The plan covers the white background, exact candle colors, zoom in/out, pan, timeframe presentation, realtime lifecycle, and device performance requested by the user.
- The shared bottom navigation and all non-Chart tabs stay outside scope, matching the instruction to edit only the Chart tab.
- The current 6,197-line screen is split only where required to make rendering, viewport behavior, and tests independently reviewable; no unrelated architecture is changed.
- Existing order overlays, crosshair, indicators, objects, positions, and one-click trading remain protected by focused regression tests.
- Reference-data differences are masked only for visual comparison; implementation still renders genuine REST/SignalR candles and never fabricates market prices for production.
