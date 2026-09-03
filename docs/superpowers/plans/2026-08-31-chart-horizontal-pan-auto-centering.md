# Chart Horizontal Pan Auto-Centering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the visible candlestick range vertically centered whenever the user pans the chart horizontally into history.

**Architecture:** Keep horizontal gesture and viewport ownership unchanged. Correct the painter's automatic price-domain input so it uses only the resolved candles selected by the current horizontal viewport; the already-resolved newest candle continues to carry the live price when visible.

**Tech Stack:** Flutter, Dart, Riverpod, Flutter widget/painter tests.

**Spec:** `docs/superpowers/specs/2026-08-31-chart-horizontal-pan-auto-centering-design.md`

## Global Constraints

- Do not change the required technology stack.
- Preserve all unrelated dirty-worktree changes.
- Auto-scale uses only visible resolved candle extrema and a minimum range derived from those extrema.
- Preserve manual price-axis scaling, pending-order focus, pinch zoom, crosshair behavior, and horizontal inertia.
- Run build, analyze, relevant tests, and direct iPhone 17 Simulator verification.

---

### Task 1: Center the automatic price range on visible candles

**Files:**
- Modify: `mobile/test/chart_controls_test.dart`
- Modify: `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`

**Interfaces:**
- Consumes: `ChartViewport.visibleStartIndex`, `ChartViewport.visibleEndIndex`, `ChartRenderSnapshot.resolvedCandles`, and `ChartHitTargets.minPrice/maxPrice`.
- Produces: automatic `chartMinPrice/chartMaxPrice` centered on the visible candle extrema without changing public APIs.

- [x] **Step 1: Write the failing regression test**

Add an optional `currentPrice` argument to `_viewportInvariantPainter`, defaulting to `referencePrice`, then add a painter test with historical candles around `100`, a newest candle/current price around `1000`, and a maximally historical `ChartViewport`. Assert that the newest candle is outside `hitTargets.visibleCandles`, that the displayed midpoint equals the hand-derived visible high/low midpoint, and that `currentPrice` is above `chartMaxPrice`.

```dart
test('historical horizontal pan centers auto scale on visible candles', () {
  final candles = <MarketCandle>[
    for (var index = 0; index < 19; index++)
      MarketCandle(
        time: DateTime.utc(2026, 8, 1, index),
        open: 99,
        high: 110,
        low: 90,
        close: 101,
      ),
    MarketCandle(
      time: DateTime.utc(2026, 8, 2),
      open: 1000,
      high: 1000,
      low: 1000,
      close: 1000,
    ),
  ];
  final painter = _viewportInvariantPainter(
    viewport: const ChartViewport(scrollOffset: 10000),
    candles: candles,
    referencePrice: 1000,
    currentPrice: 1000,
  );

  _paintViewportPainter(painter);

  final visible = painter.hitTargets.visibleCandles;
  expect(visible, isNot(contains(same(candles.last))));
  expect(
    (painter.chartMinPrice + painter.chartMaxPrice) / 2,
    closeTo(100, 1e-9),
  );
  expect(painter.currentPrice, greaterThan(painter.chartMaxPrice));
});
```

- [x] **Step 2: Run the focused test and verify RED**

Run:

```bash
cd mobile
flutter test test/chart_controls_test.dart --plain-name "historical horizontal pan centers auto scale on visible candles"
```

Expected: FAIL because the existing painter includes `currentPrice` in `dataMin/dataMax`, moving the midpoint away from `100`.

- [x] **Step 3: Implement the minimal painter correction**

In the automatic-range block, leave `dataMin` and `dataMax` as the visible
candle low/high extrema. Derive the minimum non-zero range from the visible
price magnitude rather than `currentPrice`:

```dart
final visibleMagnitude = math.max(dataMin.abs(), dataMax.abs());
final rawRange = math.max(
  dataMax - dataMin,
  visibleMagnitude * .0004,
);
```

Keep `focusedChartPrice`, `ChartPriceViewport.resolve`, and all gesture code unchanged.

- [x] **Step 4: Run focused and relevant tests and verify GREEN**

Run:

```bash
cd mobile
flutter test test/chart_controls_test.dart --plain-name "historical horizontal pan centers auto scale on visible candles"
flutter test test/chart_viewport_test.dart test/chart_price_viewport_test.dart test/chart_controls_test.dart
```

Expected: PASS with no warnings or errors.

- [x] **Step 5: Verify the application and device behavior**

Run:

```bash
cd mobile
flutter test
flutter analyze
flutter build ios --simulator --debug
```

Install and relaunch the resulting app on iPhone 17 Simulator
`5AD1B6AA-5814-4EAA-A573-4B9C561BABA4`, then repeatedly pan the chart left.
Confirm the visible high/low range stays vertically centered and capture the
final Simulator screenshot under `artifacts/qa/`.

- [x] **Step 6: Review only the scoped diff**

Inspect the two modified implementation/test files and verify that no existing
unrelated worktree changes were reverted or staged.

## Execution evidence

- RED: midpoint was `545.0`, expected `100.0`.
- GREEN: 69 relevant chart tests passed.
- `flutter analyze`: no issues.
- iOS Simulator debug build and Android debug APK build succeeded.
- iPhone 17 Simulator pan verification completed; screenshots are
  `artifacts/qa/chart-pan-centering-before.png` and
  `artifacts/qa/chart-pan-centering-after.png`.
- The full Flutter suite reached 757 tests but retained 41 unrelated existing
  failures, primarily golden/font baselines. A controlled A/B run of the
  `M1 min` chart golden produced the identical `2.94% / 9893 px` mismatch with
  both the old and new range calculation.
- Backend build/test could not start because the repository requires .NET SDK
  `8.0.421`, while this machine only has `10.0.203` installed.
