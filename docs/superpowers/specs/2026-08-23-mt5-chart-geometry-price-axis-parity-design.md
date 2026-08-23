# MT5 Chart Geometry and Price-Axis Parity Design

## Goal

Make only the Flutter Chart tab match the official MT5 Android chart for
candle spacing and body size, grid cadence, axis and label geometry, and
vertical scaling performed by dragging the right price axis. Use BTCUSD M5 on
the canonical `590 x 1280`, `240 dpi` LDPlayer as the measured reference, then
apply the same renderer rules to every supported symbol and timeframe.

The shared bottom navigation, other tabs, order workflows, market-data
contracts, and required Flutter/Riverpod/GoRouter/Dio/SignalR stack remain
unchanged.

## Measured Reference

Fresh side-by-side captures establish the following canonical targets:

- Plot/right-axis boundary: approximately physical `x=476`.
- Price-axis width: approximately `114` physical pixels.
- Default candle-center cadence: approximately `42` physical pixels.
- Vertical-grid cadence: approximately `42` physical pixels.
- Horizontal-grid and price-label cadence: approximately `42` physical pixels.
- Candle body: approximately 64 percent of one candle slot.
- Newest-candle right padding: approximately `12` physical pixels.
- An upward drag on the right price axis reduces the displayed price range and
  enlarges candles vertically; a downward drag expands the displayed range.

Changing market values, the Android status bar, account-owned overlays, and
the intentionally different shared bottom navigation are not static parity
targets. Geometry, fonts, baselines, colors, line widths, and gesture response
are parity targets.

## Architecture

Retain the native Flutter `CustomPainter` chart. Introduce immutable,
chart-local geometry metrics for the canonical axis width, plot insets, grid
target cadence, candle slot/body ratio, label offsets, and time-axis height.
Responsive values are derived from logical device pixels and the available
plot size; there are no symbol-specific screenshot contours.

Keep horizontal and vertical transforms independent:

- `ChartViewport` continues to own horizontal candle spacing, right padding,
  and scroll offset.
- A chart-local price-scale model owns the vertical range multiplier and the
  price anchor under the gesture.
- `Mt5CandlePainter` receives both transforms and one geometry contract. It
  derives the visible candle window, auto-range baseline, transformed min/max,
  grid steps, and labels without changing candle OHLC values.

The renderer uses a target grid pitch rather than a fixed row count. A nice
price step is selected for the current transformed range, and price labels are
drawn on the same rows as horizontal grid lines. Time labels are derived from
the candle at each rendered grid anchor.

## Interaction Model

The right price-axis rectangle is a dedicated gesture zone:

- Drag upward: zoom the price range in vertically.
- Drag downward: zoom the price range out vertically.
- Scaling is continuous and multiplicative, using a sensitivity calibrated
  from repeated controlled drags on official MT5.
- The price beneath the initial pointer remains under that pointer as the
  range changes.
- The multiplier is clamped to finite minimum and maximum values.
- Double-tapping the price axis resets to automatic vertical range.

Gestures beginning inside the plot retain their existing behavior: one-finger
horizontal pan, two-finger focal-point candle zoom, crosshair, pending-level
drag, and long-press order creation. Price-axis gestures must not place or move
orders and must not pan candles horizontally.

## Data and Rendering Flow

1. REST/SignalR providers supply the unchanged candle and quote series.
2. The horizontal viewport selects the visible candle indices.
3. Visible highs/lows and the current price produce an automatic baseline
   range with safe padding.
4. The price-scale model transforms that baseline around its anchored price.
5. A nice grid step is selected for the transformed range at the measured
   target pixel cadence.
6. The painter renders grid, candles, overlays, axes, badges, and labels from
   the same min/max transform.

Zero candles, one candle, flat candles, non-finite gesture input, and very
small or large prices must always produce finite bounds and labels.

## Testing

Follow TDD for every production change:

1. Add failing pure tests for canonical geometry, default candle spacing,
   candle-body ratio, newest-candle padding, responsive bounds, and grid pitch.
2. Add failing pure tests for vertical price scaling: drag direction,
   sensitivity, anchor preservation, clamping, reset, and finite edge cases.
3. Add failing widget tests proving the right axis exclusively owns vertical
   scaling while plot pan/pinch/crosshair/pending-level behaviors remain intact.
4. Add or update deterministic BTCUSD M5 golden coverage for labels, grid,
   axes, and candle geometry at the canonical surface.
5. Run focused chart tests, all Flutter tests, Flutter analyzer, debug APK
   build, backend build, and backend tests.

## Device Acceptance

Install the normal app APK on the development LDPlayer and leave both devices
on BTCUSD M5. Capture official MT5 and the development app in equivalent
states before and after the same controlled right-axis drags.

Acceptance requires:

- specified static boundaries within one physical pixel on the canonical
  device;
- exact chart palette and aligned grid/label baselines;
- candle slot, body, wick, and newest-bar padding matching the measured
  reference;
- vertical range response matching official MT5 within measurement tolerance
  for multiple upward and downward drag distances;
- no horizontal viewport movement during an axis drag;
- no regression to plot pan, pinch zoom, double-tap behavior, timeframe
  changes, crosshair, order overlays, or one-click controls;
- no modified production files outside the Chart module.

Live ticks can make the candle contour and prices differ between captures, so
they are compared semantically and excluded from static pixel assertions. No
financial data is fabricated to force screenshot equality.

## Repository Safety

The shared checkout already contains extensive owner changes. Only the new
spec, Chart-module production files, and Chart-specific tests may be changed.
Unrelated modifications are preserved. No commit is created unless it can be
made without capturing unrelated or previously untracked owner work.
