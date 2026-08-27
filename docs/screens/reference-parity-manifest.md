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
- Measurements are taken directly from the decoded JPEG pixel grid. Horizontal
  text-mask edges are placed immediately after protected label glyphs and
  around changing numeric glyphs; their vertical extents retain the measured
  baseline band. Scrollbar rectangles identify the visible indicator/thumb,
  not an inferred full-height scroll rail.

Each case has a full-canvas `staticAuditRegion` of `[0, 0, 590, 1280]`. Its
dynamic masks are narrowly-scoped exclusions; they do not turn a partial crop
into the source of truth.

## File-to-state mapping

| JPEG | Case / route | Selected tab | Capture and scroll state |
| --- | --- | --- | --- |
| `photo_2026-08-25_22-30-10.jpg` | Prices, `/prices` | Prices | Market Watch at the initial top-of-list position. |
| `photo_2026-08-25_22-30-17.jpg` | Chart, `/chart` | Chart | One-click chart with the initial visible candle range. |
| `photo_2026-08-25_22-30-20.jpg` | Trade, `/trade` | Trade | Open Positions at the initial top-of-list position; scrollbar indicator `[581, 318, 5, 790]`. |
| `photo_2026-08-25_22-30-23.jpg` | History positions, `/history/positions` | History | Positions segment at the initial top-of-list position. |
| `photo_2026-08-25_22-30-26.jpg` | History orders, `/history/orders` | History | Orders segment after a 32 physical-pixel list offset; scrollbar indicator `[581, 177, 5, 687]`. |
| `photo_2026-08-25_22-30-29.jpg` | History orders summary, `/history/orders` | History | Orders segment scrolled to its end summary; scrollbar indicator `[581, 474, 5, 688]`. |
| `photo_2026-08-25_22-30-34.jpg` | History deals, `/history/deals` | History | Deals segment scrolled to its end summary; scrollbar indicator `[581, 525, 5, 637]`. |

## Static audit contract

Every case declares typed visual regions for the system area, content bounds,
header, body, and bottom navigation. Trade and the three scrolled History
images declare their individually measured scrollbar indicators; Prices,
Chart, and History Positions have none. `staticControlRegions` identifies
controls and labels that a mask must never cover, including price `L:`/`H:`
labels, chart frame and axes, Trade section surface and scrollbar, history
selected segment, and every visible scrollbar indicator. The manifest test
enforces those independent expected bounds, mask non-overlap, and canvas
bounds.

`StaticTextRegion.auditMode` defaults to `StaticTextAuditMode.static`.
Static text is always measured against the decoded reference with edge
`<= 1` physical pixel, RGB `<= 4` per channel, and optical-density delta
`<= 5%`. A genuinely changing value must opt into `dynamicOnly` and both its
reference and candidate rectangles must be wholly contained by one typed,
reasoned dynamic mask. The comparator emits a machine-readable `SKIP` row
containing only that covering mask's reason; it never silently treats excluded
text as a pass. The legacy `allowsDynamicMask` flag remains compatibility-only
and does not confer `SKIP` semantics.

Mixed strings are split into independent audit regions. Prices keep the four
`L:`/`H:` labels static while their numeric values are dynamic-only. Trade
keeps the `USD` suffix static while only the numeric header P/L is
dynamic-only. Static controls independently protect those labels and suffixes
from mask overlap.

Reference-only semantic roles declare exact interior rectangles on the decoded
reference. Samples cluster at Chebyshev radius 2, and the most-frequent
cluster's deterministic medoid is the calibrated role color. Empty or
inconsistent samples, unassigned required foreground, and missing or extra
composite roles fail. Manifest ink and role keys route measurements only; they
are not RGB truth.

Uniform icon and label controls declare their selection state, semantic role,
and explicit uniform surface. Their reference support is decoded independently
with the fixed geometry tolerance; RGB12 is supplemental reference seed
evidence, while the candidate remains raw with RGB4 cores and reconstruction
error `<= 4`. The geometry tolerance discovers lossy reference support only:
it is not a semantic color allowance and never snaps or normalizes a candidate.

The reference corpus predeclares every control/state/role/surface consensus key
and assigns every eligible reference exactly once. Each member is normalized
once at the control level in its original coordinates. Consensus support uses
strict majority `floor(n / 2) + 1`, and coverage is the deterministic median
including zero for a non-supporting member. Consensus alone supplies bounds,
component topology, centroid, mass, projections, and the fixed reference 3x3
grid. Source path and SHA-256 provenance are emitted with every atomic row;
candidate pixels cannot affect either membership or consensus.

Each foreground child owns its exact audited support union; there is no blanket
dilation. Off-axis colors fail the child and remain parent-owned. Atomic rows
independently enforce raw semantic RGB `<= 4` per channel, feature edge `<= 1`
physical pixel, complete one-to-one local component matching, symmetric
missing-plus-extra support residual `<= 0.5%`, coverage-mass delta `<= 5%`,
centroid x/y `<= 1`, and reference-coordinate grid variation `<= 5%`.

Selected-pill and whole-navigation rows are hierarchical composites. Their
parent surface audit covers every pixel outside the named child foreground
ownership and explicitly audited class boundary; it never excludes whole child rectangles. The capsule's
white-on-white fill is surface-owned. Named left, right, and bottom shadow rows
use local decoded surface color, a reference-derived noise floor, and symmetric
surface-relative darkness matching within one physical pixel. Shadow is not a
solid foreground role. Composite rows aggregate the already-enforced child and
parent-surface results without canvas dilution or coordinate rescaling. The CSV
remains exactly 22 columns. The `12`-per-channel threshold is only a JPEG
residual-count allowance, never a semantic color tolerance. Candidate tokens
are never used as reference truth or snapped to a calibrated value.

`dynamicMaskRegions` is the typed, reasoned mask API; the legacy
`dynamicMasks` getter continues to expose its pixel rectangles for compatible
consumers. This separation keeps the manifest useful to the comparator
without embedding candidate-image expectations in the reference data.

## Dynamic-mask policy

Only values that can genuinely differ at capture time are masked. Labels,
icons, controls, surfaces, borders, shadows, spacing, selected-state fills,
and bottom navigation remain static audit targets.

| Dynamic class | Exact exclusion reason |
| --- | --- |
| `systemStatusValues` | “The operating-system clock and silent indicator are capture-time values.” The left glyph mask is `[62, 15, 98, 41]`, measured around the clock/silent glyphs rather than from the canvas edge. Carrier, signal, and battery use the separate exact reason “Carrier, signal, and battery status are supplied by the device at capture time.” |
| `livePrices` | Quote Bid/Ask values are “supplied by the live market feed”; session Low/High values are “derived from the live market session”; chart-ticket sell and buy quotes are “a live market value.” Low/High masks start after the static `L:`/`H:` glyphs. |
| `liveTimes` | Quote timestamps are excluded because they “advance with the live market feed.” Historical transaction timestamps are not masked: they describe the captured history state. |
| `liveProfitAndLoss` | Only the Trade header's changing numeric glyphs (`429.40` in the reference) and each visible open-position profit glyph are masked. The protected `USD` suffix, header spacing, and each Trade row's spacing and `[581, 318, 5, 790]` scrollbar remain static. The Positions-history profit summary is excluded because it “is recalculated from position outcomes.” |
| `liveChartContent` | The drawable candle plot alone is excluded because “Only the drawable candle plot changes as new market candles arrive.” Its mask ends at `y=1140`, before the protected X-axis labels; the chart toolbar, ticket labels, frame, price axis, X-axis, and navigation remain audited. |

The masks use physical-pixel rectangles wholly inside the JPEG canvas. They
are evaluated against required static control/label rectangles so future
updates cannot accidentally hide a regression in UI structure.
Task 2 navigation certification is verification-deferred, not PASS. The manifest owns every navigation pixel hierarchically through opaque foreground leaves, explicit capsule and selected-pill surface leaves, dedicated shadow leaves, and seven integrated composites. Current JPEG-derived atomic and pill evidence stays strict FAIL with `reference-evidence-deferred: lossless shared navigation source required; restore in Task 7`; Task 7 must provide the lossless shared source and remove that deferral. Tasks 3–6 may rely on the implemented ownership structure but may not promote these rows to PASS.
