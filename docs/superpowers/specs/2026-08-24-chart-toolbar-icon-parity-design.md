# Chart Toolbar Icon Parity Design

## Goal

Match the normal Chart toolbar in `iconMau/photo_2026-08-24_13-46-23.jpg`
while preserving every existing tap, long-press, route, and chart state change.

## Measured contract

The supplied JPEG is 1280 px wide. Its toolbar ends at physical y=188. On the
canonical 590x1280 LDPlayer at DPR 1.5, the corresponding app toolbar occupies
physical y=36..120. Reference ink is mapped by horizontal ratio `590 / 1280`
and by vertical toolbar ratio `84 / 188` after the 36 px system inset.

At the canonical device size the five icon ink bounds are:

- crosshair: approximately `(223.6, 76.7)..(251.3, 103.5)`;
- indicator: approximately `(285.9, 78.9)..(303.4, 102.1)`;
- objects: approximately `(339.3, 76.7)..(364.1, 102.1)`;
- chart mode: approximately `(486.0, 79.3)..(513.6, 100.8)`;
- windows/one-click: approximately `(541.8, 80.7)..(570.0, 99.4)`.

Neutral icon ink remains theme-derived. The red and blue toolbar marks use the
measured MT5 toolbar brand colors rather than the brighter candle/trade colors.

## Design

Use the existing code-native `CustomPainter` icons. Position the three
left/center controls from proportions of the available toolbar width so the
384 logical-pixel reference also holds at 393.33 and 430 logical pixels. Keep
the current 38x40 logical hit targets and all callbacks. Adjust only painter
paths, transforms, stroke widths, icon-specific colors, and timeframe text
geometry.

Widget tests capture raw RGBA pixels at 590x1280/DPR 1.5 and compare global ink
bounds with the measured reference. Existing behavior tests continue to prove
that every toolbar action remains functional.

## Non-goals

- No chart data, candle, axis, order, navigation, or account changes.
- No bitmap assets or icon-font substitutions.
- No technology-stack or dependency changes.

