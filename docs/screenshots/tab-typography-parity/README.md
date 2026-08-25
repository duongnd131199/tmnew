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

- Bundled deterministic families: `Mt5Roboto` and `Mt5RobotoCondensed`, weights
  400, 500, and 700.
- Covered semantic roles lock font size, line height, weight, letter spacing,
  baseline offsets, and row pitch.
- Calibrated inks: primary `#111111`, secondary `#5C5C60`, buy/selected
  `#007FFF`, and sell/negative `#E42D30`.
- Static comparison tolerance: every ink-bound edge must be within 1 physical
  pixel; median interior RGB delta must be no more than 6 per channel.

`dart run tool/compare_tab_typography.dart` passed with these worst results:

| Case | Maximum edge delta | Maximum median ink delta |
| --- | ---: | ---: |
| Prices | 1 px | 0 |
| Chart | 1 px | 1 |
| Trade | 1 px | 0 |
| History positions | 1 px | 0 |
| History orders | 1 px | 0 |
| History orders summary | 1 px | 0 |
| History deals | 1 px | 0 |

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
- Focused parity suite from the implementation plan: 109 passed, 1 existing
  data assertion failed (`realtime chart renders API candles without demo
  reshaping`, expected 40 candles and received 41). Every typography, golden,
  responsive, and comparator check passed.
- Related legacy baselines: 27 full-surface Chart goldens, the Trade bulk-dialog
  golden, Trade row-pitch sentinel, and global-font assertion were updated with
  the bundled fonts; their focused rerun passed 70/70. The resulting goldens
  were visually inspected to confirm text glyphs render normally.
- Full `flutter test`: 608 passed, 3 failed. Remaining failures are the two
  pre-existing Chart data assertions (40 vs 41 candles; H4 active high 4425 vs
  quote 4429) and the Windows-only PowerShell capture preflight on macOS
  (`powershell.exe` unavailable).
- `flutter build apk --debug`: passed. Output:
  `mobile/build/app/outputs/flutter-apk/app-debug.apk` (about 180 MB).
- `dotnet build Trading.sln` and `dotnet test Trading.sln --no-build`: blocked
  by SDK resolution. The repository requests .NET SDK 8.0.421; only 10.0.203 is
  installed. `global.json` was intentionally not changed.
- Device capture blocked: the Android SDK `adb` executable is present, but
  `adb devices -l` returned no connected emulator or device.

## Reference gaps

The Settings body and routes absent from the seven source screenshots remain
unverified. Dynamic trading values and candle contours are not claimed as
pixel-identical. No device screenshots were fabricated while emulator capture
was unavailable.
