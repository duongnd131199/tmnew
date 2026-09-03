# Exact Reference Typography Parity Design

**Date:** 2026-08-31

**Status:** Proposed implementation design; no production changes made

## Objective

Make every app-controlled text run visible in the supplied MetaTrader reference
screens match the reference in font face, apparent weight, size, tracking,
baseline, and color. The first implementation target is the seven canonical
590 x 1280 light-theme tab states; Settings and dark Trade follow as separately
controlled states.

This design deliberately separates two claims:

1. **Exact canonical build-input identity** is achievable: the app can lock every
   face used by an in-scope semantic role by SHA-256, map each role to an exact
   face and weight, and lock size, height, spacing, features, and color in tests.
2. **Raw-pixel identity to the current seven JPEGs is not certifiable.** The
   supplied canonical screenshots are progressive JPEGs. Compression has
   irreversibly changed antialiased glyph edges and some colors. With these
   sources the defensible result is visual equivalence at explicit tolerances.
   A raw-pixel identity claim requires native lossless PNG/HEIC references
   captured with recorded device and renderer metadata, the same locked
   renderer, and zero unmasked differing pixels.

## Decision Summary

The current global `wdth: 90` variable-font approach is rejected for reference
parity. It makes ordinary Roboto about 7-8% narrower, does nothing to the bundled
Roboto Condensed variable font because that file has no `wdth` axis, and is
combined with weights and vertical text transforms that make current candidates
visibly taller, narrower, and darker than the samples.

Canonical roles will instead use explicit, role-specific static faces. Exact
Roboto binaries corroborated by the official MetaTrader 5 Android package are
the starting candidates. Font family selection is then confirmed per role with
glyph-shape evidence, not inferred from one screenshot or applied globally.

Large quote and P/L numerals are a separate decision gate. The official package
contains Avenir Next Condensed Demi Bold and the reference shapes are consistent
with it, but redistribution rights have not been established. That binary may
be used only for local forensic comparison. It must not be added to the product
unless the owner supplies a valid license or another lawful source is verified.
Because a sandboxed iOS app cannot read a host `/tmp` path, this unlicensed face
is rendered only in a separate host CoreText/CoreGraphics forensic lane. That
lane is labeled `host-coretext-forensic`, cannot be reported as Flutter iOS
evidence, and exists only to decide whether the legal gate must block. If it
clearly wins an in-scope role, implementation stops until the exact face can be
lawfully bundled and rerendered on the primary Flutter iOS lane.

## Reference Authority

The reference corpus contains 11 files with different purposes. They must not be
merged into one state or treated as equal evidence.

| Reference | SHA-256 | Authority |
| --- | --- | --- |
| `photo_2026-08-25_22-30-10.jpg` | `6739a1668fa87ca745f5e43ea472c2413ef0434fa1074c3b180c7278ea658db5` | Canonical Prices, light, 590 x 1280 JPEG |
| `photo_2026-08-25_22-30-17.jpg` | `e5d878286e76f843fec97ac2fc14de68d219fd20475a381a2bda941226854e31` | Canonical Chart, light, 590 x 1280 JPEG |
| `photo_2026-08-25_22-30-20.jpg` | `5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc` | Canonical Trade, light, 590 x 1280 JPEG |
| `photo_2026-08-25_22-30-23.jpg` | `40bfd8ddf3e24158453da32e4318e9219d02a201b09bb2fb53d6ee95a98a5924` | Canonical History / Positions, light, 590 x 1280 JPEG |
| `photo_2026-08-25_22-30-26.jpg` | `48dbab6778e247325222bf0e10e991f0ef4d160ecf4cb4127be1e6d1b6eb83c1` | Canonical History / Orders offset, light, 590 x 1280 JPEG |
| `photo_2026-08-25_22-30-29.jpg` | `7f8d2fe5c086eacb5a8364435373645a4ba3e2ba3df7b852467b5a51d0ee45ee` | Canonical History / Orders summary, light, 590 x 1280 JPEG |
| `photo_2026-08-25_22-30-34.jpg` | `6fbbf3ccfc834b94052df32713a153c10518298b644844fb9482fa51a70e3bb9` | Canonical History / Deals summary, light, 590 x 1280 JPEG |
| `image.png` | `4c4f508369707ef576521c220e918bc0db5c9f3bdb900334ff5a5a859fcfcf9c` | Primary Settings typography source because it is lossless, 590 x 1280 PNG |
| `photo_2026-08-27_21-13-34.jpg` | `bf67307f7e12f378ac2bf6abbbdf3b351d1e5492d59a50f0a0233b9a8955d092` | Secondary Settings state; validates shared roles but not account content or scroll/fade state |
| `photo_2026-08-21_16-51-41.jpg` | `349b41ed7ab4e974966b7bf1394e65f39cd43f07667613c5f92f0e2e8b2cefe9` | Separate dark Trade state, 413 x 881 JPEG; never used to tune light-state geometry |
| `photo_2026-08-31_10-47-10.jpg` | `3e6d3c3693119c96f78c56e07638f54a16e8238911ec55b7cc94bddfb65ced57` | Partial system/UI crop only; not a full-screen typography golden |

The seven canonical references retain the viewport contract already encoded by
the repository: 393.333333 logical pixels wide by 853.333333 logical pixels
high, device pixel ratio 1.5, 590 x 1280 physical output, and text scale 1.0.

The declared primary app renderer is Flutter iOS because the canonical corpus
has iOS system chrome. Renderer selection is frozen before face selection and
size tuning. Android receives separate evidence and must reuse identical
semantic tokens unless a documented platform exception is approved. Fixed-size
`RepaintBoundary.toImage(pixelRatio: 1.5)` captures provide the canonical
590 x 1280 app canvas; a native device screenshot is retained at its true native
dimensions rather than being mislabeled or rescaled.

Deterministic widget candidates and primary device candidates both encode a
keyed `RenderRepaintBoundary.toImage` result at the case's locked capture ratio.
The nine light/Settings cases use the 590 x 1280 contract above; dark Trade keeps
its separate 413 x 881 logical/DPR contract. On device, the app puts that PNG as
base64 plus case/renderer metadata in `binding.reportData`; the
host driver's `responseDataCallback` decodes, validates, hashes, and writes it.
One case is transported per drive invocation so response size remains bounded.
The driver reads case, renderer, device id, and its absolute output directory
from host environment variables. It cross-checks case/renderer against app
metadata; the `-d` command and matching host environment value are authoritative
for device id. The exact matching `flutter devices --machine` record supplies
the host-side device name, target platform, simulator flag, and SDK; app-observable
`Platform.operatingSystem` and `Platform.operatingSystemVersion` corroborate the
runtime platform. No sandboxed app is asked to write a host path, and an output
directory is never passed as a Dart define.

`binding.takeScreenshot(name)` is used only for a separately named native-window
artifact and is called without metadata arguments, because Flutter 3.44.8's IO
callback rejects non-null screenshot arguments. The host `onScreenshot` callback
retains those bytes at native dimensions; they never substitute for the canonical
case-specific boundary image.

System status-bar text is not an app typography role. On iOS it must remain
system-rendered rather than being imitated with a bundled face. Capture-time
clock, signal, carrier, and battery glyphs stay under typed system masks.

## Forensic Findings

### Current implementation

- `AppTypography.tabWidth = 90` is injected into nearly every primary-tab role.
- `MtTabTextScope` applies `tabDefault` to all tab bodies, so local `TextStyle`
  instances that omit a family inherit the narrowed variable family.
- Current uncommitted tuning increased many roles from roughly 300-350 weight
  to 400-650 while retaining narrow width and several `Transform.scale` text
  compensations.
- Plain `Roboto-Variable.ttf` supports `wdth` 75-100 and honors `wdth: 90`.
- `RobotoCondensed-Variable.ttf` supports `wght` only. Its requested `wdth: 90`
  values are ignored by the font engine.
- The current full comparator result is 32 PASS / 218 FAIL / 30 typed SKIP.
  Focused typography verification has 10 failures: seven candidate/golden
  mismatches and three stale expected-evidence failures. The checked-in evidence
  README therefore cannot be treated as current certification.

These facts explain the user's observation that current app text is elongated,
narrow, and heavy compared with the rounder sample text. Changing only a family
name or one global size cannot solve the mismatch.

### Official MetaTrader package evidence

The Android package downloaded through the official MetaTrader mobile download
route was inspected read-only:

- Package: `net.metaquotes.metatrader5`
- Version: `500.6140` (`versionCode 6140`)
- APK SHA-256:
  `c76582495cdd55061a38942bae9a4d2d33ed140840af94dec82cc6ad7001782b`

It contains these relevant faces:

| Face | Name-table version | SHA-256 | Product status |
| --- | --- | --- | --- |
| Roboto Regular | `1.200310; 2013` | `f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27` | Apache 2.0 metadata; eligible after provenance/license gate |
| Roboto Bold | `1.100141; 2013` | `9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70` | Apache 2.0 metadata; eligible after provenance/license gate |
| Roboto Condensed Regular | `1.200311; 2013` | `f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8` | Apache 2.0 metadata; eligible after provenance/license gate |
| Roboto Condensed Bold | `1.200311; 2013` | `ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a` | Apache 2.0 metadata; eligible after provenance/license gate |
| Avenir Next Condensed Demi Bold | `2.000` | `94c0952db172bed2d0c030488a9d3f7f4bebb1398baf9e46e6a1acf5173ac192` | Forensic-only until redistribution rights are supplied |

The four Roboto files are not byte-identical to any current repo face. The
official Roboto Condensed specimen is visibly rounder/shorter than the repo's
current v3.008 variable face. Representative `XAUUSD` advance metrics also
differ by about 4.1%, which is large enough to invalidate spacing tuned against
the current font.

The package proves which candidate binaries MetaTrader ships, but it does not
prove chain of custody from this Android build to the supplied iOS-like JPEGs.
Role assignment therefore remains an evidence-backed selection step.

## Role Attribution Matrix

This matrix is the hypothesis to test. A role is not migrated until its specimen
comparison and full-screen static-region audit agree.

| Role group | First candidate | Alternatives to test | Confidence |
| --- | --- | --- | --- |
| Settings titles, account/body rows, toolbar titles, History segments/summaries, bottom navigation | exact Roboto Regular/Bold | current static Roboto; system face only where OS-owned | High |
| Trade/History symbols, sides/actions, timestamps, secondary numeric rows | exact Roboto Condensed Regular/Bold | exact Roboto; current condensed | High |
| Chart canvas axes/annotation | exact Roboto Regular | exact Roboto Condensed | High; official ChartSurface code loads Roboto Regular |
| Large Prices Bid/Ask, chart ticket prices, large blue/red P/L | licensed Avenir Next Condensed Demi Bold | exact Roboto Condensed Bold; otherwise block the exact objective pending a licensed winner | High visual likelihood, unproved widget mapping |
| iOS clock/carrier/battery | operating system SF family | none | OS-owned; excluded from app styles |

Font selection order for every role is fixed: face binary, weight/axis, point
size and line metrics, tracking/advance, color, then position. Geometry transforms
must not compensate for a wrong face.

## Typography Architecture

### Isolated reference families

Canonical screen roles use new reference family aliases so unrelated screens do
not silently change:

- `Mt5ReferenceRoboto`: exact regular and bold faces only.
- `Mt5ReferenceRobotoCondensed`: exact regular and bold faces only.
- `Mt5ReferenceNumeric`: registered only if a lawful winning numeric face is
  approved; otherwise it remains absent and the large-number gate remains open.

No synthetic intermediate `wght` and no unsupported `wdth` variation may be
used for canonical roles. If visual evidence genuinely requires an intermediate
weight, the implementation must name a licensed file or prove an actual variable
axis in the font lock; it must not rely on platform synthesis.

`MtTabTextScope` becomes neutral. Every visible canonical text run obtains a
semantic role explicitly, including painter text. This prevents silent family,
fallback, or width inheritance.

Migration is opt-in until all screens pass. Complete `legacyTokens`,
`legacyColors`, and `legacyGeometry` maps preserve every current metric,
state/theme color, transform, and platform adjustment for the ordinary app/test
profile, while separate reference maps drive candidate fixtures. The app default
changes atomically only after all screen gates pass; partially migrated screens
never fall through from one map to the other.

Legacy compatibility is keyed by a composite semantic role plus explicit
callsite variant, platform, and theme. Variant ids cover every existing branch,
including navigation kind/selection and instrument-specific XAU/BTC behavior;
they are captured in a before-refactor manifest with resolved style, color, and
geometry snapshots. A missing legacy variant is an error, never a fallback to a
base/reference value. Reference variants normalize to the reviewed semantic base
token unless source evidence proves a real distinction.

### Font lock

`mobile/assets/fonts/mt5-reference/font-lock.json` records every font under that
directory and every face approved for a canonical role. Existing fonts used only
by out-of-scope screens may remain outside this lock, but no canonical role may
refer to them. The lock records:

- SHA-256 and byte length;
- upstream/source URL and retrieval date;
- family, subfamily, full name, name-table version, and head revision;
- license identifier and committed license file;
- units per em;
- axes and min/default/max values;
- registered Flutter family and legal weights;
- approved semantic role groups.

A test fails on any unrecorded `.ttf` inside `mt5-reference/`, missing locked
font, hash change, name/axis/OS/2 mismatch, missing required reference glyph in
`cmap`, or role requesting an unsupported axis/weight.

`docs/screens/reference-typography-color-lock.json` records every semantic text
color decision with reference SHA, color-role and region IDs, sample coordinates,
decoded background, compositing method, all accepted samples, consensus
RGB/opacity, uncertainty, and whether the source is diagnostic JPEG or
provenance-complete lossless evidence.

### Semantic role and color contract

Typography metrics and color are modeled separately. Each app-controlled static
text region maps to exactly one metric role, one semantic color role, and one
explicit callsite variant. Metric
roles may be reused across selected/unselected or positive/negative states, and
color roles may be reused across faces; the region mapping is therefore complete
but intentionally not bijective.

Each metric role locks:

- family alias and source font SHA;
- `fontSize`, `fontWeight`, `height`, `letterSpacing`;
- `fontFeatures` and `fontVariations`;
- locale, text direction, text scale, and fallback policy;
- expected baseline and run bounds for the canonical fixture.

Each color role locks foreground RGB/opacity plus the theme/state in which it
applies. Required semantic states include primary, secondary, selected and
unselected navigation, blue action, positive, negative, History status, Chart
toolbar/plot, and white. The production `forRole` API combines one metrics-only
token with one required color role; no reference token carries an implicit
color.

AppColors remains the only production color source. Reference RGB values are
measured from stable glyph cores or lossless sources, never from a single JPEG
edge pixel. Common measured targets already supported by the corpus include
black `#000000`, secondary `#3C3C43`, blue `#007AFF`, and red `#E42D30`.
History status and chart plot colors require their own role calibration rather
than reuse of generic blue.

### Text geometry

Text-only `Transform.scale` compensations become identity in the reference
profile after the underlying face and metrics pass. The staged legacy profile
retains its existing scale/offset map so the complete suite remains reproducible
until atomic promotion. A reference transform may remain only if a focused test
demonstrates that it represents reference geometry rather than compensating for
the wrong font. Icon transforms and non-typography geometry are outside this
decision.

All fitting is performed on whole strings and individual glyph components.
Matching just a text box width is insufficient because a different face can
coincidentally occupy the same rectangle.

## Verification Contract

### Tier A: deterministic build-input identity

This tier must pass before visual tuning:

- all product font binaries match the font lock exactly;
- every canonical text callsite has a declared metric role and color role;
- role tests assert family, legal weight/axes, size, height, tracking, features,
  locale, text scale, and no fallback; color-role tests independently assert the
  locked RGB/opacity and state/theme mapping;
- Flutter/Dart engine, platform, OS build, viewport, DPR, locale, timezone, text
  scale, and screenshot route are recorded with each capture;
- no canonical role inherits the global `wdth: 90` setting;
- Avenir or any other proprietary binary is absent without an approved license.

### Tier B: diagnostic equivalence to the current JPEG corpus

The existing JPEG references remain useful but non-certifying. For every stable
known string:

- whole-run/annotated-landmark outer-edge delta: at most 1 physical pixel;
- whole-run baseline proxy delta: at most 1 physical pixel;
- whole-run extent delta: at most 1 physical pixel;
- semantic flat/core RGB delta: at most 4 per channel;
- optical density delta: at most 5%;
- JPEG-aware support IoU and symmetric residual: reported and thresholded as
  diagnostic shape evidence without claiming exact component topology;
- no new mask may overlap stable labels, controls, or surfaces.

JPEG cannot reliably reveal shaping advances or exact glyph topology because
compression may join or split antialiased components. Per-glyph advances and
topology are enforced only on controlled specimens or provenance-complete
lossless sources.

Dynamic market values and system values may be typed SKIP only under their exact
existing narrow masks. Family, size, baseline, and color for a dynamic role are
still tested with a deterministic replacement string outside the screenshot
comparison.

### Tier C: lossless-source typography equivalence

Certification mode rejects JPEG inputs. It requires a native lossless reference
and a candidate capture with a capture manifest and hashes. For every static
glyph/run:

- component topology is exact;
- edge and baseline delta are at most 1 physical pixel;
- advance delta is at most 0.5 physical pixel;
- mask IoU is at least 0.98;
- centroid delta is at most 0.5 physical pixel;
- coverage mass and stroke-width deltas are at most 2%;
- flat/core RGB delta is at most 2 per channel; antialiased edge RGB is at most
  4 per channel.

Passing these nonzero tolerances is reported as **lossless-source typography
equivalence at Tier C tolerances**. It is not raw-pixel identity. If reference
and candidate are captured through the same locked renderer/device, a separate
composite gate may report **raw-pixel identity** only when it finds exactly zero
differing pixels outside authorized dynamic/system masks. Across different
renderers the result is visual equivalence only.

## Implementation Sequence

1. Freeze and repair the current verification baseline without overwriting dirty
   user work or accepting changed goldens.
2. Add the complete reference/capture manifest and font-lock/license gate.
3. Build a deterministic glyph specimen and per-role font bake-off.
4. Correct the shared typography architecture and remove global width inheritance.
5. Migrate and accept Settings/navigation, then Prices, Chart, Trade, and all
   History states independently.
6. Add the dark Trade state as a separate viewport/theme target.
7. Connect the complete ten-case primary iOS keyed-boundary output to the
   comparator through response data, and reconcile the current
   iPhone-versus-Android provenance contradiction.
8. Regenerate evidence only after all focused tests pass; never bulk-approve
   goldens first.
9. Obtain lossless native references and run certification mode for any claim
   containing “100% pixel.”

## Non-Goals and Safety Boundaries

- No change to Flutter/Dart, Riverpod, GoRouter, Dio, SignalR, secure storage,
  native chart architecture, backend contracts, trading behavior, providers,
  routes, gestures, fixture values, or account state.
- No proprietary font redistribution without explicit license evidence.
- No screenshot-as-background shortcut and no fake status bar text.
- No global font tweak used as a substitute for role-by-role evidence.
- No mass golden update, threshold relaxation, mask expansion, or JPEG
  normalization to turn failures green.
- Existing dirty worktree changes are user-owned. Implementation must snapshot
  overlapping diffs and patch only the exact typography/evidence paths named by
  the implementation plan.

## Definition of Done

The typography task is complete when:

1. Tier A passes for every app-controlled text role in all in-scope screens.
2. Every canonical JPEG row meets Tier B or is a valid typed dynamic/system SKIP.
3. Settings passes its lossless PNG typography checks; the secondary Settings
   JPEG agrees on shared roles.
4. Dark Trade passes at its own viewport without changing light Trade.
5. A complete ten-case primary Flutter iOS boundary-capture matrix passes and
   its scoped source snapshot, font lock, capture manifest, and comparator
   summaries match the current worktree. Host renders remain regression evidence.
6. Focused tests, the complete Flutter and backend test suites, analyzers, and
   required mobile/backend builds pass.
7. Evidence hashes/counts match current candidates and documentation; no stale
   PASS statement remains.
8. The final report explicitly distinguishes “exact font-input/token lock,”
   “visual equivalence to JPEG at documented tolerances,” “lossless-source
   typography equivalence at Tier C tolerances,” and the stricter “raw-pixel
   identity” result that additionally requires zero unmasked differences.
