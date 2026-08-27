# Seven-State Visual Parity Completion Design

**Date:** 2026-08-27

**Builds on:**

- `docs/superpowers/specs/2026-08-25-tab-typography-spacing-parity-design.md`
- `docs/superpowers/plans/2026-08-26-reference-parity-foundation.md`
- `docs/screens/reference-parity-manifest.md`

## Goal

Complete reference-driven visual parity for every application-controlled pixel
visible in the seven supplied 590 x 1280 screenshots while preserving trading,
navigation, realtime, scrolling, and chart behavior.

The seven states are Prices, Chart, Trade, History Positions, History Orders,
History Orders at the end summary, and History Deals at the end summary. The
canonical Flutter viewport remains 393.3333333333 x 853.3333333333 logical
pixels at device pixel ratio 1.5 and text scale 1.0.

## Meaning of Complete

Completion is a machine-verifiable contract, not a visual impression:

- every comparator row for application-controlled static content is `PASS`;
- a `SKIP` is allowed only for a typed, reasoned live/platform value whose
  complete declared reference and candidate rectangles are covered by its
  dynamic mask;
- static text has edge delta at most 1 physical pixel, semantic RGB delta at
  most 4 per channel, and optical-density delta at most 5 percent;
- static canvas, visual regions, and controls have surface and foreground RGB
  delta at most 4 per channel, feature-edge delta at most 1 physical pixel,
  and no more than 0.5 percent residual pixels beyond the measured-reference
  JPEG allowance of 12 per channel;
- all seven deterministic goldens and seven fresh Android-engine screenshots
  are produced after the final production change;
- supported logical widths 360, 384, 393.3333333333, and 430 render without
  overflow or clipped required content;
- Flutter analyze, the relevant and full Flutter suites, and debug APK build
  pass; repository-required backend commands also receive fresh results.

The 12-channel JPEG allowance is never a semantic color tolerance. It only
separates compression/anti-alias residuals from material pixel differences.

## Scope

### Application-controlled areas

- shared top safe-area contract and white system-chrome configuration;
- shared five-item bottom navigation surface, shadow, selected pill, icons,
  labels, colors, bounds, and spacing;
- Prices toolbar and both quote rows;
- Trade header, account metrics, section header, position rows, and visible
  scrollbar;
- History shared header/segmented control, position/order/deal rows, summaries,
  exact scroll states, and visible scrollbar indicators;
- Chart toolbar, one-click ticket, static labels, plot frame, grid, right price
  axis, X axis, overflow control, and navigation;
- local deterministic font assets and reference-specific typography/geometry
  tokens consumed by those areas;
- deterministic golden, comparator, artifact, and device-capture tooling.

### Explicit exclusions

- dynamic quote values, quote times, open-position P/L values, and drawable
  candle contours may differ in value but not in their declared typography or
  container geometry;
- operating-system clock, silent/carrier/signal/battery glyphs are platform
  owned and remain reasoned dynamic exclusions; their app-controlled
  background and safe-area geometry remain audited;
- Settings content and routes not visible in the seven references are not
  claimed as reference-perfect;
- no provider, repository, REST, SignalR, authentication, account, order,
  position, wallet, or backend behavior redesign;
- no replacement of Flutter, Dart, Riverpod, GoRouter, or ASP.NET Core;
- no screenshot-as-widget implementation and no runtime download of fonts or
  reference assets.

## Considered Approaches

### Shared-first strict calibration — selected

First remove comparator false-passes, then fix shared shell/navigation and
fonts, and finally calibrate Prices, Trade, History, and Chart. Each screen
inherits already-correct shared pixels and must pass its focused comparator
before the next screen starts. This minimizes repeated tuning and keeps every
acceptance decision tied to reference pixels.

### Screen-first calibration — rejected

Directly tuning each screen appears faster, but shared navigation, safe-area,
font, and color defects would be rediscovered and reworked in every state.

### Static screenshot composition — rejected

Displaying supplied screenshots could make a capture look exact but would
destroy semantics, responsiveness, live data, gestures, accessibility, and
the required trading behavior.

## Architecture

### Comparator hardening

`mobile/tool/compare_tab_typography.dart` remains the single comparison
engine. Public manifest and invocation APIs stay compatible, with one optional
case filter for focused calibration.

Dynamic-only authorization uses a shared private helper that returns a typed,
reasoned mask only when that one mask fully contains both the declared
reference and candidate rectangles. Intersection alone is invalid. Static
text/control overlap validation continues to prevent masks from hiding labels,
icons, axes, scrollbars, borders, or selected surfaces.

Every static canvas/region/control measurement adds an independently derived
foreground semantic sample. The estimator:

1. measures the modal unmasked local surface;
2. collects unmasked pixels more than 12 RGB levels from that surface;
3. orders them by contrast to the surface;
4. takes the highest-contrast quartile, with at least one pixel;
5. uses per-channel medians as the foreground sample.

Surface, foreground, geometry, and residual checks fail independently and are
reported as separate CSV fields. Tight control regions are used when one
larger region contains multiple principal colors.

### Capture and evidence flow

The deterministic widget harness remains the calibration loop because it fixes
viewport, DPR, fonts, Riverpod fixtures, navigation selection, and scroll
position. Production screens and `MtBottomNavigationBar` are rendered; no
reference raster is displayed by production code.

For each state:

```text
production widgets + deterministic providers
  -> 590 x 1280 PNG candidate
  -> strict comparator against original JPEG
  -> CSV row set + 50/50 overlay + heatmap
  -> focused source adjustment
  -> repeat until the state has no FAIL rows
```

The Android integration harness then renders the same states through the
Android engine at 590 x 1280 and 240 dpi. Its screenshots are evidence and a
renderer regression check; deterministic goldens remain the source used for
the strict cross-reference gate.

### Shared visual foundations

`AppColors`, `AppTypography`, `TabReferenceMetrics`, and `AppShadows` own
reference-visible semantic values. Feature widgets consume named roles rather
than introducing new anonymous visual literals. Reference-only subpixel
corrections remain explicit and narrowly scoped; functional providers and
controllers are not moved during visual calibration.

The variable Roboto and Roboto Condensed assets already referenced by
`pubspec.yaml` are checked in with their existing provenance and licenses so a
fresh checkout renders deterministically.

The production `AppShell` keeps its safe-inset cap and keyboard/navigation
behavior. A router-backed test covers that production boundary because the
seven-state fixture intentionally pumps individual feature screens for exact
state control.

### Screen isolation

- Prices changes stay in its toolbar and quote-row presentation plus shared
  tokens proven by more than one state.
- Trade changes stay in its reference-width layout, metrics, rows, and
  scrollbar. Existing swipe, tap, long-press, edit, close, and add-order flows
  remain unchanged.
- History changes share one header and row system across all four captured
  states. All four states rerun after any row-height or scroll calculation
  change.
- Chart visual work stays in the visual composition, geometry, theme, and
  painter layers. Realtime subscriptions, order dispatch, viewport persistence,
  gestures, and session storage remain intact.

## Error Handling

- Invalid paths, duplicate IDs, non-opaque inputs, wrong dimensions, unsafe
  masks, missing dynamic coverage, and absent one-sided foreground samples fail
  preflight before evidence is partially written.
- An unknown focused case ID exits with an input error rather than silently
  comparing zero states.
- A screen cannot be marked complete while any focused comparator row is
  `FAIL`, any expected evidence file is missing/empty, or any behavior test in
  its scope regresses.
- Environment-only verification failures are recorded verbatim. They do not
  authorize changing `global.json`, weakening tests, or loosening visual
  thresholds.

## Testing Strategy

Every behavior change follows RED-GREEN-REFACTOR:

- comparator mutations first demonstrate the 1 x 1 partial-mask and RGB 5/12
  same-bounds foreground false-passes;
- each shared/screen task starts with a focused parity assertion that fails on
  the current candidate and names the state being protected;
- implementation changes one visual cause at a time and reruns the focused
  golden/comparator plus existing behavior tests for that feature;
- golden files are regenerated only from production widgets after the source
  change, never copied from references;
- final verification runs all seven states together, the complete Flutter
  suite, Android integration captures, analyze, APK build, and backend gates.

## Owner Work Preservation

The dedicated local branch `codex/reference-parity-foundation` and its baseline
snapshot remain in use because the checkout contains owner work that a fresh
worktree would omit. Unrelated untracked iOS, account-sync, chart-session, and
artifact paths are not modified, staged, reset, stashed, or cleaned.

The untracked variable-font binaries/licenses and the safe-inset/trade-width
tests overlap this scope. They may be incorporated byte-for-byte or extended
only after their current content is preserved and their relevance is recorded
in the task report.

## Deliverables

- hardened comparator with complete-mask and foreground-semantic enforcement;
- reproducible local fonts and shared visual foundations;
- calibrated shared navigation and all seven reference states;
- focused and full regression tests;
- seven final deterministic candidates, seven overlays, seven heatmaps, one
  final CSV, and seven fresh Android-engine screenshots;
- updated screen/evidence documentation and a final debug APK;
- a final report containing exact commands, outcomes, environment limitations,
  assumptions, and every ruling made during autonomous execution.
