# Chart Horizontal Pan Auto-Centering Design

## Problem

When the chart is panned horizontally into historical candles, the automatic
price range still includes the live `currentPrice`. If that live price is
outside the visible historical candle range, it pulls the vertical scale away
from the midpoint of the candles on screen. The chart therefore appears to
jump upward or downward during a horizontal-only gesture.

## Required behavior

- In automatic price mode, derive the vertical range from the high and low of
  the candles currently visible in the horizontal viewport.
- The visible candle extrema must remain centered vertically while the user
  pans left or right.
- The active live price remains part of automatic scaling whenever the newest
  candle is visible, because the resolved active candle already expands its
  high/low and close to include that price.
- A live-price line or badge outside a historical viewport may be clipped; it
  must not distort the historical candle scale.
- Preserve manual price-axis scaling, pending-order focus, pinch zoom,
  crosshair behavior, and horizontal inertia.

## Implementation boundary

Change only the automatic range calculation in
`mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`
and add a regression test in `mobile/test/chart_controls_test.dart`. Do not
change the technology stack or unrelated chart geometry and styling.

## Verification

The regression fixture places historical candles near `100` and a live price
near `1000`, then pans far enough that the newest candle is not visible. The
displayed price-range midpoint must equal the midpoint of the visible candle
high/low values, and the live price must fall outside that historical range.

After the focused test passes, run the relevant chart suite, `flutter test`,
`flutter analyze`, an iOS Simulator debug build, and a direct pan check on the
iPhone 17 Simulator.
