# MT5 Chart Geometry and Price-Axis Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make only the Flutter Chart tab match official MT5 candle, grid, label, and axis geometry and support MT5-style vertical scaling by dragging the right price axis.

**Architecture:** Retain the existing Flutter `CustomPainter` renderer and market-data flow. Add immutable chart geometry tokens, keep the existing horizontal `ChartViewport`, introduce an independent absolute `ChartPriceViewport`, and make `Mt5CandlePainter` derive grid rows, price labels, and candles from both transforms.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, GoRouter, Flutter `CustomPainter`, Flutter unit/widget/golden tests, LDPlayer/ADB, ASP.NET Core 8 verification.

**Spec:** `docs/superpowers/specs/2026-08-23-mt5-chart-geometry-price-axis-parity-design.md`

## Global Constraints

- Modify production code only under `mobile/lib/features/chart`.
- Keep the shared bottom navigation, Quotes, Trade, History, Messages/Settings, order workflows, and market-data contracts unchanged.
- Keep Flutter, Riverpod, GoRouter, Dio, SignalR, and the native `CustomPainter`; add no chart dependency or WebView.
- Canonical reference is BTCUSD M5 at `590 x 1280`, `240 dpi`; retain responsive support for `360-430` Flutter logical-pixel widths.
- Preserve received candle OHLC, volume, quote values, and timestamps exactly.
- Use TDD: observe a focused test fail for the intended reason before each production change.
- The checkout contains owner changes. Do not reset, revert, stage, or commit pre-existing Chart files; use scoped diffs and test checkpoints instead of task commits.
- Final verification must include focused Chart tests, full Flutter tests, `flutter analyze`, debug APK build, backend build/tests, and fresh device screenshots.

---

### Task 1: Lock canonical Chart geometry

**Files:**
- Create: `mobile/lib/features/chart/presentation/geometry/chart_geometry.dart`
- Create: `mobile/test/chart_geometry_test.dart`
- Modify: `mobile/lib/features/chart/presentation/viewport/chart_viewport.dart`

**Interfaces:**
- Produces: immutable `ChartGeometry` with `canonical`, `priceAxisWidth`, `timeAxisHeight`, `headerHeight`, `targetGridPitch`, `candleBodyRatio`, `wickWidth`, `axisLabelInset`, and `newestCandleRightPadding`.
- Produces: `ChartViewport.defaultBarSpacing == 28` and `ChartViewport.defaultRightPadding == 8` logical pixels.

- [ ] **Step 1: Write the failing geometry contract**

Add tests equivalent to:

```dart
test('canonical MT5 geometry converts to measured physical pixels', () {
  const geometry = ChartGeometry.canonical;
  expect(geometry.priceAxisWidth * 1.5, closeTo(114, .01));
  expect(geometry.targetGridPitch * 1.5, closeTo(42, .01));
  expect(geometry.newestCandleRightPadding * 1.5, closeTo(12, .01));
  expect(geometry.candleBodyRatio, closeTo(.64, .001));
  expect(ChartViewport.defaultBarSpacing * 1.5, closeTo(42, .01));
  expect(ChartViewport.defaultRightPadding * 1.5, closeTo(12, .01));
});

test('geometry produces finite plot bounds from 360 through 430 px', () {
  for (final width in <double>[360, 393.333333, 430]) {
    final plotWidth = ChartGeometry.canonical.plotWidthFor(width);
    expect(plotWidth, greaterThan(0));
    expect(plotWidth + ChartGeometry.canonical.priceAxisWidth, closeTo(width, .001));
  }
});
```

- [ ] **Step 2: Run the geometry test and verify RED**

Run:

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_geometry_test.dart
```

Expected: FAIL because `ChartGeometry` does not exist and viewport defaults are `32`/`20`.

- [ ] **Step 3: Implement the immutable geometry contract**

Create a focused value object with these canonical logical-pixel values:

```dart
@immutable
final class ChartGeometry {
  const ChartGeometry({
    required this.priceAxisWidth,
    required this.timeAxisHeight,
    required this.headerHeight,
    required this.targetGridPitch,
    required this.candleBodyRatio,
    required this.wickWidth,
    required this.axisLabelInset,
    required this.newestCandleRightPadding,
  });

  static const canonical = ChartGeometry(
    priceAxisWidth: 76,
    timeAxisHeight: 22,
    headerHeight: 64 / 3,
    targetGridPitch: 28,
    candleBodyRatio: .64,
    wickWidth: 2 / 3,
    axisLabelInset: 4,
    newestCandleRightPadding: 8,
  );

  double plotWidthFor(double totalWidth) =>
      math.max(0, totalWidth - priceAxisWidth);
}
```

Update only the two horizontal viewport defaults to `28` and `8`; leave clamp, focal-point zoom, and bounded pan behavior intact.

- [ ] **Step 4: Run geometry and existing viewport tests**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_geometry_test.dart test/chart_viewport_test.dart
```

Expected: PASS after updating existing default-value expectations.

- [ ] **Step 5: Review the scoped checkpoint**

Run:

```powershell
git diff -- mobile/lib/features/chart/presentation/geometry/chart_geometry.dart mobile/lib/features/chart/presentation/viewport/chart_viewport.dart mobile/test/chart_geometry_test.dart mobile/test/chart_viewport_test.dart
```

Expected: only chart geometry/default-spacing changes; do not stage the dirty shared checkout.

### Task 2: Implement a pure MT5 price-axis viewport

**Files:**
- Create: `mobile/lib/features/chart/presentation/viewport/chart_price_viewport.dart`
- Create: `mobile/test/chart_price_viewport_test.dart`

**Interfaces:**
- Produces: immutable `ChartPriceRange({required double minPrice, required double maxPrice})` with finite `centerPrice`, `range`, and `priceAt(...)` helpers.
- Produces: immutable `ChartPriceViewport.auto()` and `ChartPriceViewport.manual({required double centerPrice, required double range})`.
- Produces: `ChartPriceViewportController.beginDrag(...)`, `updateDrag({required double deltaY})`, and `reset()`.
- Contract: `factor = exp(deltaY * 0.00104)` so an observed `-213.333` logical-pixel drag is approximately the official MT5 `0.80x` displayed range.

- [ ] **Step 1: Write failing price-viewport tests**

Cover direction, sensitivity, anchor, reset, and finite edge cases:

```dart
test('upward axis drag zooms in and preserves anchored price', () {
  final controller = ChartPriceViewportController();
  controller.beginDrag(
    viewport: const ChartPriceViewport.auto(),
    focalY: 300,
    priceTop: 20,
    priceHeight: 700,
    minPrice: 77000,
    maxPrice: 78000,
  );
  final next = controller.updateDrag(deltaY: -213.333333);
  expect(next.range, closeTo(800, 2));
  final resolved = next.resolve(
    const ChartPriceRange(minPrice: 77000, maxPrice: 78000),
  );
  expect(
    resolved.priceAt(y: 300, priceTop: 20, priceHeight: 700),
    closeTo(77600, .01),
  );
});

test('downward drag expands range and reset restores auto scale', () {
  final controller = ChartPriceViewportController();
  controller.beginDrag(
    viewport: const ChartPriceViewport.auto(),
    focalY: 400,
    priceTop: 20,
    priceHeight: 700,
    minPrice: 77000,
    maxPrice: 78000,
  );
  expect(controller.updateDrag(deltaY: 213.333333).range, closeTo(1250, 3));
  expect(controller.reset().isAuto, isTrue);
});
```

Also test zero height, equal min/max, `double.nan`, extreme deltas, and repeated drags; all public values must remain finite and range must remain positive.

- [ ] **Step 2: Run the price-viewport test and verify RED**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_price_viewport_test.dart
```

Expected: FAIL because the viewport/controller do not exist.

- [ ] **Step 3: Implement the pure model and controller**

Use an absolute manual center/range so the scale stays stable until reset:

```dart
@immutable
final class ChartPriceRange {
  const ChartPriceRange({required this.minPrice, required this.maxPrice});
  final double minPrice;
  final double maxPrice;
  double get centerPrice => (minPrice + maxPrice) / 2;
  double get range => maxPrice - minPrice;
  double priceAt({required double y, required double priceTop, required double priceHeight});
}

@immutable
final class ChartPriceViewport {
  const ChartPriceViewport.auto() : centerPrice = null, range = null;
  const ChartPriceViewport.manual({
    required this.centerPrice,
    required this.range,
  });

  final double? centerPrice;
  final double? range;
  bool get isAuto => centerPrice == null || range == null;
  ChartPriceRange resolve(ChartPriceRange automatic);
}
```

`beginDrag` freezes the displayed range, pointer fraction, and anchor price. `updateDrag` applies `math.exp(deltaY * .00104)`, clamps to finite `1e-12..1e15`, and solves the new center so the anchor price remains at its original pointer fraction.

- [ ] **Step 4: Run the pure tests and verify GREEN**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_price_viewport_test.dart
```

Expected: PASS.

- [ ] **Step 5: Review the scoped checkpoint**

Run `git diff -- mobile/lib/features/chart/presentation/viewport/chart_price_viewport.dart mobile/test/chart_price_viewport_test.dart` and verify no UI/navigation/data code changed.

### Task 3: Route right-axis gestures without disturbing plot gestures

**Files:**
- Modify: `mobile/lib/features/chart/presentation/rendering/chart_render_snapshot.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Modify: `mobile/test/chart_controls_test.dart`

**Interfaces:**
- `ChartRenderSnapshot.evolve` consumes `required ChartPriceViewport priceViewport` and increments `priceViewportRevision` only when it changes.
- `ChartScreen` owns `_priceViewport`, `_priceViewportController`, `_priceAxisPointer`, and `_doubleTapPosition`.
- Existing keys `chart-gesture-area`, `chart-canvas`, and `chart-plot-repaint-boundary` remain unchanged.

- [ ] **Step 1: Add failing widget interaction tests**

Add tests that locate `Mt5CandlePainter.priceAxisRect`, then:

```dart
final before = currentPainter(tester);
final axisPoint = tester.getTopLeft(find.byKey(const Key('chart-canvas'))) +
    before.priceAxisRect.center;
await tester.dragFrom(axisPoint, const Offset(0, -160));
await tester.pump();
final after = currentPainter(tester);
expect(after.priceViewport.isAuto, isFalse);
expect(after.chartMaxPrice - after.chartMinPrice,
    lessThan(before.chartMaxPrice - before.chartMinPrice));
expect(after.viewport, before.viewport);
```

Add companion assertions that a plot drag changes only horizontal viewport, a
plot pinch still changes `barSpacing`, an axis drag cannot move a pending
order, and an axis double tap restores `priceViewport.isAuto` without resetting
horizontal spacing.

- [ ] **Step 2: Run the focused widget test and verify RED**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_controls_test.dart --plain-name "price axis"
```

Expected: FAIL because painter/snapshot do not expose or consume a price viewport and the whole canvas currently pans horizontally.

- [ ] **Step 3: Add price viewport to the render snapshot**

Store `priceViewport`, compute `priceViewportRevision` exactly like the existing
horizontal viewport revision, include it in `requiresRepaintComparedTo`, and
expose `Mt5CandlePainter.priceViewport => snapshot.priceViewport`.

- [ ] **Step 4: Route pointer events by hit target**

At the start of `_handleChartPointerDown`, claim a non-crosshair pointer when
`_chartHitTargets.priceAxisRect.contains(event.localPosition)`. Begin the price
drag from the current `minPrice`, `maxPrice`, `priceTop`, and `priceHeight`.
Handle only that pointer in move/end, and make `onScaleStart`, `onScaleUpdate`,
and `onScaleEnd` return while it is active.

Use `GestureDetector.onDoubleTapDown` to remember the local position. In
`onDoubleTap`, reset the price viewport when the saved position is on the right
axis; otherwise retain the existing horizontal viewport reset. Clear the saved
position after handling.

- [ ] **Step 5: Run interaction and regression tests**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_controls_test.dart test/chart_viewport_test.dart test/chart_market_order_dispatch_regression_test.dart
```

Expected: PASS, including existing pan, pinch, crosshair, pending-order, and one-click tests.

- [ ] **Step 6: Review the scoped checkpoint**

Run a scoped diff for the three files and confirm no provider, route, tab, or order-dispatch behavior changed.

### Task 4: Match painter grid, candle, axis, and label geometry

**Files:**
- Modify: `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`
- Modify: `mobile/lib/features/chart/presentation/rendering/chart_hit_targets.dart`
- Modify: `mobile/test/chart_controls_test.dart`
- Modify: `mobile/test/chart_light_parity_golden_test.dart`
- Update: `mobile/test/goldens/chart/light/M5-default.png`

**Interfaces:**
- Painter consumes `ChartGeometry.canonical` and `ChartPriceViewport`.
- `ChartHitTargets` exposes `candleBodyWidth`, `horizontalGridYs`, `verticalGridXs`, and `priceAxisLabels` for deterministic geometry assertions.
- Price-axis labels and horizontal grid rows come from one shared resolved grid-step calculation.

- [ ] **Step 1: Add failing painter geometry assertions**

At canonical logical width `590 / 1.5`, assert:

```dart
expect(painter.priceAxisRect.width * 1.5, closeTo(114, 1));
expect(painter.priceAxisRect.left * 1.5, closeTo(476, 1));
expect(painter.hitTargets.candleWidth * 1.5, closeTo(42, 1));
expect(
  painter.hitTargets.candleBodyWidth * 1.5,
  closeTo(42 * .64, 1),
);
expectAdjacentSteps(painter.hitTargets.horizontalGridYs, 28, tolerance: 1);
expectAdjacentSteps(painter.hitTargets.verticalGridXs, 28, tolerance: 1);
expect(painter.hitTargets.priceAxisLabels.length,
    painter.hitTargets.horizontalGridYs.length);
```

Assert the newest candle center is `8` logical pixels left of the plot boundary and every label baseline maps to the same y-coordinate as its grid row.

- [ ] **Step 2: Run painter tests and verify RED**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_controls_test.dart --plain-name "canonical MT5 geometry"
```

Expected: FAIL because the current price axis is `67 1/3`, default spacing is `32`, body ratio is `.36`, and the painter uses 17 fixed horizontal divisions.

- [ ] **Step 3: Apply canonical frame and candle metrics**

Replace symbol-specific axis-width branches with `ChartGeometry.canonical.priceAxisWidth`; use canonical time/header heights, wick width, candle-body ratio, label inset, default spacing, and right padding. Keep all candle values and overlay prices unchanged.

- [ ] **Step 4: Derive grid rows and labels from target cadence**

Compute a row count from `usablePriceHeight / targetGridPitch`, choose a nice
price step covering the resolved manual/automatic range, center the rows around
the resolved price center, and record the actual visible y positions. Draw each
horizontal grid line once and draw exactly one price label for the same price/y
pair. Generate vertical grid lines at the 28-logical-pixel cadence and select
the time-axis candle from each chosen label anchor.

- [ ] **Step 5: Apply manual price range in the painter**

Build the existing padded automatic min/max from visible highs/lows/current
price, then call `priceViewport.resolve(automaticRange)`. Use the resolved
min/max for candles, current-price line, positions, pending levels, crosshair,
and every right-axis label.

- [ ] **Step 6: Run focused painter and golden tests**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_geometry_test.dart test/chart_price_viewport_test.dart test/chart_controls_test.dart test/chart_light_parity_golden_test.dart
```

Expected: functional tests PASS; golden test reports only the intentional M5 geometry update until the image is reviewed.

- [ ] **Step 7: Review and update only the canonical golden**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test --update-goldens test/chart_light_parity_golden_test.dart --plain-name "M5 default"
D:\toolchains\flutter\bin\flutter.bat test test/chart_light_parity_golden_test.dart
```

Visually inspect the candidate against official MT5 before accepting it. Do not regenerate unrelated golden states unless their deterministic contract genuinely depends on the new shared geometry.

- [ ] **Step 8: Run all Chart regressions**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_controls_test.dart test/chart_light_theme_test.dart test/chart_light_parity_golden_test.dart test/chart_viewport_test.dart test/chart_timeframe_transition_test.dart test/chart_repaint_performance_test.dart test/market_chart_route_test.dart test/chart_market_order_dispatch_regression_test.dart
```

Expected: PASS.

### Task 5: Calibrate on both LDPlayers and complete repository verification

**Files:**
- Modify if measurements require: `mobile/lib/features/chart/presentation/geometry/chart_geometry.dart`
- Modify if measurements require: `mobile/lib/features/chart/presentation/viewport/chart_price_viewport.dart`
- Modify if measurements require: `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`
- Modify: `docs/screens/chart.md`

**Interfaces:**
- Consumes official MT5 at `127.0.0.1:5559` and development app at `127.0.0.1:5561`.
- Produces fresh before/up-drag/down-drag captures with both apps left on BTCUSD M5.

- [ ] **Step 1: Run the complete focused Chart suite**

Run the Task 4 Step 8 command plus `test/chart_geometry_test.dart` and `test/chart_price_viewport_test.dart`. Expected: PASS.

- [ ] **Step 2: Run project-required static and full tests**

Run:

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat test
D:\toolchains\flutter\bin\flutter.bat build apk --debug
cd ..\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: analyzer has no issues; all Flutter and .NET tests pass; debug APK is produced.

- [ ] **Step 3: Install the normal APK on the development LDPlayer**

Run:

```powershell
D:\LDPlayer\LDPlayer9\adb.exe -s 127.0.0.1:5561 install -r mobile\build\app\outputs\flutter-apk\app-debug.apk
D:\LDPlayer\LDPlayer9\adb.exe -s 127.0.0.1:5561 shell monkey -p com.tradingdemo.trading_mobile 1
```

Navigate only inside the app to Chart > BTCUSD > M5 if state restoration does not leave it there.

- [ ] **Step 4: Capture equivalent static and axis-drag states**

For each device, capture baseline, drag the right axis upward by 160 and 320
physical pixels, reset, then drag downward by 160 and 320 physical pixels.
Use `adb shell screencap -p` plus `adb pull`; never redirect binary PNG output.

- [ ] **Step 5: Measure and iterate one variable at a time**

Compare plot boundary, axis width, grid x/y cadence, candle center/body/wick,
newest-candle padding, font baselines, and the ratio of displayed price ranges
before/after each drag. Adjust only `ChartGeometry` or
`ChartPriceViewportController.dragExponentPerLogicalPixel`, write/update the
corresponding failing expectation first, then rerun focused tests and rebuild.

- [ ] **Step 6: Verify untouched tabs and scoped production diff**

Use real ADB taps to visit the other bottom tabs and return to BTCUSD M5. Run:

```powershell
git diff --name-only
git status --short
```

Expected: no newly modified production file outside `mobile/lib/features/chart`; all pre-existing owner changes remain untouched.

- [ ] **Step 7: Record final measured behavior**

Update `docs/screens/chart.md` with the final canonical geometry, vertical-axis drag semantics, device serials, capture dimensions, test commands, and the explicit limitation that live tick contours are time-dependent.

- [ ] **Step 8: Run fresh completion verification**

Repeat Task 5 Step 2 after the last calibration edit. Leave `MT5-Real` and `MT5-App-Code` running on BTCUSD M5 and retain final screenshots for the handoff.

---

## Self-review

- Every static geometry requirement in the approved spec maps to Tasks 1 and 4.
- Price-axis direction, continuous scaling, anchor preservation, clamping, reset, and gesture ownership map to Tasks 2 and 3.
- BTCUSD M5 device calibration, responsive coverage, unchanged market values, untouched tabs, and required build/test evidence map to Task 5.
- All interfaces use `ChartGeometry`, `ChartPriceViewport`, `ChartPriceViewportController`, and `ChartPriceRange` consistently.
- The plan contains no deferred implementation placeholders and does not authorize changes outside the Chart module.
