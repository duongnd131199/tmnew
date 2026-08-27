# Seven-state reference parity evidence

Verification date: 2026-08-27 (Asia/Ho_Chi_Minh).

## Inputs and deterministic outputs

The only supplied references are the seven progressive JPEG files in
`iconMau/anhmau`. Every reference is 590 x 1280. No lossless PNG, WebP, TIFF,
BMP, or HEIC source exists under `iconMau`.

The seven production-widget candidates are stored in
`mobile/test/goldens/tab-typography` and use a 393.3333333333 x
853.3333333333 logical viewport, DPR 1.5, and text scale 1.0. They are renders
of production widgets, not image-backed widgets.

## Strict comparator result

The comparator contract remains strict: text edge <= 1 physical pixel,
semantic RGB <= 4/channel, density delta <= 5%; static controls use RGB <= 4,
edge <= 1, and residual ratio <= 0.5%. These limits were not loosened and
dynamic masks were not enlarged.

The final 22-column CSV and 14 non-empty overlay/heatmap images are in:

`.superpowers/sdd/2026-08-27-seven-state-visual-parity-completion/final-evidence`

The comparator correctly exits 1 against the lossy JPEG inputs:

| Case | PASS | FAIL | Dynamic SKIP |
| --- | ---: | ---: | ---: |
| Prices | 8 | 33 | 12 |
| Chart | 6 | 29 | 4 |
| Trade | 9 | 26 | 4 |
| History positions | 13 | 22 | 4 |
| History orders | 8 | 26 | 2 |
| History orders summary | 10 | 25 | 2 |
| History deals | 10 | 25 | 2 |

Total: 64 PASS / 186 FAIL / 30 typed SKIP across 280 data rows. All 21
navigation-shadow bounds match exactly with edge delta zero; 9 are strict PASS
and 12 lossy-reference residuals remain FAIL. No row was relabelled or hidden.

The four History selected interiors emit `static-surface` / `surface`, not
text. Orders and Orders Summary PASS. Positions remains FAIL at edge delta 3
and residual 1.194%; Deals remains FAIL at edge delta 1 and residual 3.272%.
Adjacent circular-control halo/rounded-edge evidence stays public and no
exclusion was added.

Independent final QA found no stable app-controlled font, size, weight,
letter-spacing, color, or block-spacing mismatch; principal static glyph
bounds are within one physical pixel. All stable app-controlled mismatches
supported by consistent evidence were corrected. Mathematical/raw-pixel 100%
identity is not certified from progressive JPEG; re-encoding JPEG as PNG is
not a lossless oracle.

## Verified implementation changes

- Prices: toolbar, 66.6667-logical-pixel row pitch, symbol, metadata, Bid/Ask,
  spread, and static L/H anchors are locked.
- Chart: routed/default XAUUSD M1 uses 10 logical pixels navigation overlap;
  BUY tags follow position side, annotation and X-axis are aligned, axis and
  subtitle use `#404040`, plot boundary is physical x=507, and plot blue is
  `#3985E9`.
- Trade: section surface is `#F8F8F8`; the borderless add control is 42.6667
  logical pixels with production shadow alpha `0x19`, blur 30, offset `(0,4)`.
  A real-shadow rendered oracle explicitly enables Flutter shadow rasterization
  and locks its halo; any crescent in the normal shadow-disabled golden is not
  production behavior.
- Shared navigation: shadow alpha `0x0D`, blur 30, spread
  `9.6666666667`, offset `(0,4)`.
- History: selected interiors are surface-audited. Scrollbar bounds are
  `[581,177,5,687]`, `[581,474,5,688]`, and `[581,525,5,637]` for Orders,
  Orders Summary, and Deals.

## Device state

The final integrated Flutter process is running directly on the existing
iPhone 17 simulator `5AD1B6AA-5814-4EAA-A573-4B9C561BABA4` as bundle
`com.tradingdemo.tradingMobile`, display name `MetaTrader 5`, in persistent
Flutter session `11742`; no second simulator was opened.

## Final regression/build results

- `flutter analyze`: no issues.
- `flutter test`: 767 passed, 1 platform skip, 0 failed.
- `flutter build apk --debug`: passed.
- `.NET 8.0.421` build: passed with 0 warnings and 0 errors.
- Backend tests: 17 passed (1 architecture, 7 unit, 9 integration), 0 failed.
- `git diff --check`: passed.

## Remaining input requirement

Remaining FAIL rows are progressive-JPEG/non-invertible evidence or broad/
dependent residuals. Platform-owned status values and live market values are
the typed, reasoned SKIP rows already declared in the manifest. A strict exit
0/raw-pixel certificate requires genuine lossless captures of the same seven
states; it cannot be inferred from the supplied JPEGs.
