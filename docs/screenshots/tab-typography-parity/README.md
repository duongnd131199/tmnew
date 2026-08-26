# Tab Typography Parity Evidence

Verification date: 2026-08-26 (Asia/Ho_Chi_Minh).

## References

The implementation is calibrated against the seven 590 x 1280 JPEG files in
`iconMau/anhmau`:

- `photo_2026-08-25_22-30-10.jpg` — Prices
- `photo_2026-08-25_22-30-17.jpg` — Chart
- `photo_2026-08-25_22-30-20.jpg` — Trade
- `photo_2026-08-25_22-30-23.jpg` — History positions
- `photo_2026-08-25_22-30-26.jpg` — History orders
- `photo_2026-08-25_22-30-29.jpg` — History orders summary
- `photo_2026-08-25_22-30-34.jpg` — History deals

The canonical Flutter viewport is 393.333 x 853.333 logical pixels at DPR 1.5.
The seven deterministic candidate PNGs are stored in
`mobile/test/goldens/tab-typography`.

## Static acceptance

- Bundled deterministic families: `Mt5Roboto`, `Mt5RobotoCondensed`,
  `Mt5RobotoVariable`, and `Mt5RobotoCondensedVariable`. The covered tab roles
  use calibrated variable axes from 250 through 600 where the static families
  were visibly too dense.
- Covered semantic roles lock font size, line height, weight, letter spacing,
  baseline offsets, and row pitch.
- Calibrated inks: primary `#000000`, secondary `#3C3C43`, buy/selected
  `#007AFF`, and sell/negative `#E42D30`.
- Static comparison tolerance: every ink-bound edge must be within 1 physical
  pixel; candidate semantic RGB must be within 6 per channel; optical ink
  density must be within 30 percent for regions where the source JPEG provides
  a reliable sample. Semantic color is estimated from the most opaque candidate
  pixels against the local background and is compared directly with the
  manifest color; it is never snapped to the expected value.
- Regression tests recolor the Prices blue ink and dilate a black quote symbol
  without changing its outer bounds. The comparator rejects both color drift
  and a visibly heavier font with unchanged geometry.

`dart run tool/compare_tab_typography.dart` passed with these worst results:

| Case | Maximum edge delta | Maximum semantic ink delta | Maximum density delta |
| --- | ---: | ---: | ---: |
| Prices | 1 px | 0 | 21.9% |
| Chart | 1 px | 0 | 14.0% |
| Trade | 1 px | 0 | 13.7% |
| History positions | 1 px | 0 | 17.8% |
| History orders | 1 px | 0 | 13.4% |
| History orders summary | 1 px | 0 | 15.1% |
| History deals | 1 px | 0 | 14.4% |

## Android renderer verification

The seven states were also rendered by the Flutter Android engine on
`emulator-5554` after setting the emulator to 590 x 1280 physical pixels and
240 dpi (DPR 1.5). Each state ran in an isolated integration-test process and
the emulator was restored to 1080 x 2400 at 420 dpi afterward. Captures:

- `android-prices-590x1280.png`
- `android-chart-590x1280.png`
- `android-trade-590x1280.png`
- `android-history-positions-590x1280.png`
- `android-history-orders-590x1280.png`
- `android-history-orders-summary-590x1280.png`
- `android-history-deals-590x1280.png`

Android uses a separate, explicit rasterizer allowance of 2 physical pixels
for ink bounds, 12 RGB levels for thin anti-aliased glyphs, and 40 percent for
optical ink density. The ticket labels, Trade metric labels, and the first
History segment have small Android-only raster corrections so the production
device output remains aligned with the iOS reference. The final device
comparison passed with these worst results:

| Case | Maximum edge delta | Maximum semantic ink delta | Maximum density delta |
| --- | ---: | ---: | ---: |
| Prices | 2 px | 0 | 28.3% |
| Chart | 2 px | 0 | 39.2% |
| Trade | 2 px | 0 | 38.4% |
| History positions | 2 px | 0 | 38.0% |
| History orders | 2 px | 0 | 30.8% |
| History orders summary | 2 px | 0 | 38.4% |
| History deals | 2 px | 0 | 37.7% |

The comparator checks named static regions for the Prices title/symbol/nav,
Chart timeframe/Sell/nav, Trade metrics/section/position, and History
segments/rows/summaries/nav. It does not use non-text pixels to pass or fail
this typography task.

## Dynamic masks

Rectangles below are physical-pixel `[left, top, width, height]` values. They
cover only status content, changing numbers/timestamps/P&L, or the candle plot.

- Prices: `[0,0,590,70]`, `[0,150,590,34]`, `[330,178,260,180]`.
- Chart: `[0,0,590,68]`, `[62,140,528,60]`, `[0,200,590,950]`.
- Trade: `[0,0,590,75]`, `[190,80,400,245]`, `[450,365,140,790]`.
- History positions: `[0,0,590,70]`, `[185,155,405,390]`,
  `[185,550,405,170]`.
- History orders: `[0,0,590,70]`, `[150,130,440,1025]`.
- History orders summary: `[0,0,590,70]`, `[150,130,440,930]`,
  `[380,1060,210,100]`.
- History deals: `[0,0,590,70]`, `[150,130,440,830]`,
  `[185,995,405,170]`.

## Responsive checks

Prices, Trade, and all three History modes were pumped at 360, 384, 393.333,
and 430 logical pixels. All states completed without overflow. Chart retains
its dedicated geometry, viewport, gesture, repaint, and multi-timeframe tests.

## Verification

- `flutter analyze`: passed, no issues.
- Final typography golden/comparator run passed. The deterministic
  comparator passed every named region across all seven states with a maximum
  edge delta of 1 physical pixel, zero semantic color delta, and a maximum
  optical density delta of 21.9 percent.
- The complete Flutter suite passed 639 assertions. The three remaining
  failures were reproduced unchanged on the pre-task baseline:
  the two Chart data assertions (40 vs 41 candles; H4 active high 4425 vs quote
  4429) and the Windows-only PowerShell capture preflight on macOS
  (`powershell.exe` unavailable). They are not regressions from this task.
- `flutter build apk --debug`: passed. Output:
  `mobile/build/app/outputs/flutter-apk/app-debug.apk` (200,213,736 bytes).
- `dotnet build Trading.sln` and `dotnet test Trading.sln --no-build`: blocked
  by SDK resolution. The repository requests .NET SDK 8.0.421; only 10.0.203 is
  installed. `global.json` was intentionally not changed.
- Android integration capture: passed all 7 isolated states with no Flutter
  exception or overflow. The Android-mode comparator passed all seven final
  captured PNGs with a maximum edge delta of 2 physical pixels, zero semantic
  color delta, and a maximum optical density delta of 39.2 percent. The normal
  debug APK was installed after the capture, launched successfully, and the
  emulator was verified restored to 1080 x 2400 at 420 dpi.

## Reference gaps

The Settings body and routes absent from the seven source screenshots remain
unverified. Platform-owned status-bar glyphs, dynamic trading values, and
candle contours are not claimed as pixel-identical; the requested static tab
typography, colors, and spacing are covered by the deterministic and Android
checks above.
