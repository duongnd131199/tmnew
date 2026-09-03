# Chart Rightmost Toolbar Icon Parity Design

## Problem

The red/blue windows icon at the far-right of the Chart toolbar renders lower
than the supplied 590x1280 reference
`iconMau/anhmau/photo_2026-08-25_22-30-17.jpg`. The meaningful colored contour
in the reference occupies physical y=102..120 at DPR 1.5, while the current
app maps it to y=105..123. The current red/blue split also leaves a wider
center gap and gives the blue block less width than the reference.

## Approved behavior

- Move only the far-right red/blue windows icon upward by 3 physical pixels at
  DPR 1.5 (2 logical pixels).
- Preserve its 38x40 logical tap target, callback, one-click trading behavior,
  palette, white bridge, and gray core.
- Keep the complete colored contour 28 physical pixels wide at DPR 1.5.
- Match the DPR 1.5 colored bounds used by the native reference comparison:
  the red block is 13x19 physical pixels, the blue block is 14x19 physical
  pixels, and the blue block starts 14 pixels from the contour's left edge.
- Retain the original 3-logical-pixel lower corner radii. Direct normalized
  crop comparison showed this contour matches the JPEG reference better than
  the sharper experimental lower corners.
- Keep the bridge opening truly white, not merely a light neutral that can
  pass a generic darkness check. The real-widget raster capture must retain
  at least 50 near-white pixels inside the colored contour.
- Do not move or redraw the adjacent circular chart-mode icon.

## Implementation boundary

Change only `_ToolbarWindowsIcon` and `_ToolbarWindowsIconPainter` in
`mobile/lib/features/chart/presentation/screens/chart_screen.dart`, plus the
existing raw-RGBA toolbar regression assertions in
`mobile/test/chart_controls_test.dart`. Keep the icon code-native; do not add
a bitmap asset, dependency, or technology change.

## Verification

First change the DPR 1.5 raster expectations and confirm they fail against the
old offset and asymmetric blocks. Then make the minimal painter correction and
run the focused toolbar tests, the relevant Chart test file, Flutter analyze,
and iOS Simulator debug build. Install and relaunch on iPhone 17 Simulator
`5AD1B6AA-5814-4EAA-A573-4B9C561BABA4`, capture a native screenshot, and compare
the icon crop against the supplied reference at the same normalized scale.
Use the native DPR 1.5 capture as the geometry acceptance source; do not derive
exact DPR 3 threshold bounds from the compressed JPEG because that was shown
to overfit antialiasing artifacts.
