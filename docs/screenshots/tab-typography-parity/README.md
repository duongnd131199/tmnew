# Seven-state reference parity evidence

Verification date: 2026-08-27 (Asia/Ho_Chi_Minh).

## Inputs and deterministic outputs

The only supplied references are the seven progressive JPEG files in
`iconMau/anhmau`. Every reference is 590 x 1280. No lossless PNG, WebP, TIFF,
BMP, or HEIC source exists under `iconMau`.

The seven production-widget candidates are stored in
`mobile/test/goldens/tab-typography` and use a 393.3333333333 x
853.3333333333 logical viewport, DPR 1.5, and text scale 1.0. The final golden
test passed all seven cases, the exact History scrollbar check, the Chart M1
time-label check, and the responsive-width matrix: 10/10 tests passed.

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
| Prices | 6 | 35 | 12 |
| Chart | 5 | 30 | 4 |
| Trade | 9 | 26 | 4 |
| History positions | 11 | 24 | 4 |
| History orders | 7 | 27 | 2 |
| History orders summary | 7 | 28 | 2 |
| History deals | 8 | 27 | 2 |

Sixty-seven FAIL rows retain the explicit detail
`reference-evidence-deferred: lossless shared navigation source required;
restore in Task 7`. Other red aggregate/control rows include JPEG edge noise,
thin-glyph semantic sampling, and dynamic content inside broad crops. They are
not relabelled PASS or SKIP.

This means the implementation and regression gate are complete, but a
mathematical claim of 100% reference identity is not certified from the
current inputs. Re-encoding the JPEG files as PNG is not a valid substitute.

## Verified implementation changes

- Prices: reference-width row pitch, toolbar geometry, change text, metadata,
  spread, price typography, and L/H label/value spacing. The four L/H semantic
  RGB deltas are zero in the final focused evidence.
- Chart: M1 title/ticket/axis geometry and deterministic session fixture;
  production AppShell now preserves the full bottom-navigation clearance, so
  the chart no longer paints beneath the navigation bar.
- Trade: calibrated header, metrics, rows, and exact 590 x 1280 scrollbar;
  short viewports scale the minimum thumb length instead of showing a
  full-track thumb.
- History: all four states share calibrated segment, row, summary, and
  persistent scrollbar geometry. Orders, orders-summary, and deals scrollbar
  bounds exactly match their manifest rectangles.

## Device state

The final integrated Flutter process is running directly on the existing
iPhone 17 simulator `5AD1B6AA-5814-4EAA-A573-4B9C561BABA4` as bundle
`com.tradingdemo.tradingMobile`, display name `MetaTrader 5`. The final hot
restart completed successfully.

Seven Android-engine captures in this directory were refreshed during the
gate at 590 x 1280 and the emulator was restored to 1080 x 2400 at 420 dpi.
They predate the final Prices and AppShell live checkpoints and therefore are
renderer diagnostics, not final strict-certification artifacts. The user then
directed all further deployment to the already-running iPhone 17; no second
simulator was kept open.

## Final regression/build results

- `flutter analyze`: no issues.
- `flutter test`: 754 passed, 1 platform skip, 0 failed.
- `flutter build apk --debug`: passed.
- APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`, 202,032,360 bytes,
  SHA-256 `b1e64cab1af6ba1f024471cc72c27c2bb102cff144e376e94517b60c390d6d82`.
- `.NET 8.0.421` build: passed with 0 warnings and 0 errors.
- Backend tests: 17 passed (1 architecture, 7 unit, 9 integration), 0 failed.
- `git diff --check`: passed; the index remained empty during verification.

## Remaining input requirement

To close the strict comparator at exit 0 without weakening it, obtain genuine
lossless captures of the seven reference states, especially the shared bottom
navigation. Platform-owned status values and live market values remain the
typed, reasoned exclusions already declared in the manifest.
