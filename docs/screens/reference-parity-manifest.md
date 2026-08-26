# Seven-state reference parity manifest

`mobile/test/test_support/tab_reference_manifest.dart` is the canonical test
manifest for the seven tab references. It is intentionally test metadata: it
does not prescribe or tune production UI.

## Canonical capture environment

- JPEG source directory: `iconMau/anhmau`.
- Every source image is `590 × 1280` physical pixels.
- Flutter viewport: `393.3333333333 × 853.3333333333` logical pixels.
- Device pixel ratio: `1.5`.
- Text scale: `1.0`.
- Coordinates are original physical pixels. Rectangles use
  `[left, top, width, height]`, with right and bottom edges exclusive.

Each case has a full-canvas `staticAuditRegion` of `[0, 0, 590, 1280]`. Its
dynamic masks are narrowly-scoped exclusions; they do not turn a partial crop
into the source of truth.

## File-to-state mapping

| JPEG | Case / route | Selected tab | Capture and scroll state |
| --- | --- | --- | --- |
| `photo_2026-08-25_22-30-10.jpg` | Prices, `/prices` | Prices | Market Watch at the initial top-of-list position. |
| `photo_2026-08-25_22-30-17.jpg` | Chart, `/chart` | Chart | One-click chart with the initial visible candle range. |
| `photo_2026-08-25_22-30-20.jpg` | Trade, `/trade` | Trade | Open Positions at the initial top-of-list position. |
| `photo_2026-08-25_22-30-23.jpg` | History positions, `/history/positions` | History | Positions segment at the initial top-of-list position. |
| `photo_2026-08-25_22-30-26.jpg` | History orders, `/history/orders` | History | Orders segment after a 32 physical-pixel list offset; scrollbar visible. |
| `photo_2026-08-25_22-30-29.jpg` | History orders summary, `/history/orders` | History | Orders segment scrolled to its end summary; scrollbar visible. |
| `photo_2026-08-25_22-30-34.jpg` | History deals, `/history/deals` | History | Deals segment scrolled to its end summary; scrollbar visible. |

## Static audit contract

Every case declares typed visual regions for the system area, content bounds,
header, body, and bottom navigation. The three scrolled history images also
declare their measured scrollbar rail. `staticControlRegions` identifies
controls and labels that a mask must never cover; the manifest test enforces
both that restriction and canvas bounds.

`StaticTextRegion` remains unchanged for the existing typography comparator.
`dynamicMaskRegions` is the typed, reasoned mask API; the legacy
`dynamicMasks` getter continues to expose its pixel rectangles to the existing
comparator. This separation keeps the manifest useful to Task 2 without
embedding candidate-image expectations in the reference data.

## Dynamic-mask policy

Only values that can genuinely differ at capture time are masked. Labels,
icons, controls, surfaces, borders, shadows, spacing, selected-state fills,
and bottom navigation remain static audit targets.

| Dynamic class | Exact exclusion reason |
| --- | --- |
| `systemStatusValues` | “The operating-system clock and silent indicator are capture-time values.” Carrier, signal, and battery use the separate exact reason “Carrier, signal, and battery status are supplied by the device at capture time.” |
| `livePrices` | Quote Bid/Ask values are “supplied by the live market feed”; session Low/High values are “derived from the live market session”; chart-ticket sell and buy quotes are “a live market value.” |
| `liveTimes` | Quote timestamps are excluded because they “advance with the live market feed.” Historical transaction timestamps are not masked: they describe the captured history state. |
| `liveProfitAndLoss` | Trade header and open-position profit values change with live quotes. The Positions-history profit summary is excluded because it “is recalculated from position outcomes.” |
| `liveChartContent` | The drawable candle plot alone is excluded because “Only the drawable candle plot changes as new market candles arrive.” The chart toolbar, ticket labels, plot identity, axes outside the plot, and navigation remain audited. |

The masks use physical-pixel rectangles wholly inside the JPEG canvas. They
are evaluated against required static control/label rectangles so future
updates cannot accidentally hide a regression in UI structure.
