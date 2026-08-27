# Seven-State Visual Parity Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every application-controlled static region in the seven supplied 590 x 1280 references pass the strict reference comparator while preserving all existing behavior and producing fresh deterministic and Android-engine evidence.

**Architecture:** Harden the comparator first so it cannot hide partially masked text or small foreground recolors. Then calibrate shared fonts/shell/navigation before Prices, Trade, History, and Chart, using a failing per-state acceptance test plus generated golden, CSV, overlay, and heatmap evidence for every stage.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, Riverpod, GoRouter, package:image, Flutter widget/integration tests, Android emulator/ADB, ASP.NET Core 8.

**Spec:** `docs/superpowers/specs/2026-08-27-seven-state-visual-parity-completion-design.md`

## Global Constraints

- Preserve every owner change already present; never stash, reset, clean, discard, overwrite, or broadly format unrelated files.
- Remain on `codex/reference-parity-foundation`; do not merge, push, publish, or modify shared external state without separate authority.
- Keep Flutter, Dart, Riverpod, GoRouter, and ASP.NET Core unchanged.
- Use only the seven original JPEGs under `iconMau/anhmau`, each at exactly 590 x 1280 physical pixels.
- Use a 393.3333333333 x 853.3333333333 logical viewport, DPR 1.5, and text scale 1.0 for deterministic acceptance.
- Static text limits are edge <= 1 physical pixel, semantic RGB <= 4/channel, and optical-density delta <= 5 percent.
- Static canvas/region/control limits are surface RGB <= 4/channel, foreground RGB <= 4/channel, feature edge <= 1 physical pixel, and residual ratio <= 0.5 percent after the reference-JPEG separation threshold of 12/channel.
- A dynamic `SKIP` requires one typed, reasoned mask to fully contain both its declared reference and candidate rectangles; masks may never cover required static text, controls, axes, borders, scrollbars, selected surfaces, or navigation.
- Reference images are comparison inputs only. Never copy, embed, or display them from production widgets or use candidate tokens as reference truth.
- Preserve providers, repositories, routes, gestures, scrolling semantics, chart interaction, order actions, and realtime behavior unless a behavior test proves the visual boundary cannot be corrected otherwise.
- Follow RED-GREEN-REFACTOR for every production behavior change. A checked-in golden is valid only when regenerated from production widgets after the relevant source change.
- After every task run Flutter analyze, focused and relevant tests, debug APK build, `dotnet build Trading.sln`, and `dotnet test Trading.sln --no-build`; record environmental blocks verbatim and never change `global.json` to bypass them.

---

### Task 1: Harden Comparator Acceptance (Task 2.1 continuation)

**Files:**
- Modify: `mobile/tool/compare_tab_typography.dart`
- Modify: `mobile/test/tab_typography_comparator_test.dart`
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`
- Modify: `mobile/test/tab_reference_manifest_test.dart`
- Modify: `docs/screens/reference-parity-manifest.md`

**Interfaces:**
- Consumes: `TabReferenceCase`, `StaticTextRegion`, `ReferenceDynamicMask`, original/candidate rasters.
- Produces: `_coveringDynamicMask`, foreground semantic metrics, a 22-column CSV, and optional `--case CASE_ID` filtering used by Tasks 2-7.

- [ ] **Step 1: Write and run RED tests for complete dynamic-mask authorization**

Add fixtures that prove a 1 x 1 intersection and reference-only containment are invalid, while one mask containing both rectangles is valid:

```dart
test('rejects a partial mask for dynamic-only text', () async {
  final source = _blankImage();
  _fillRect(source, 12, 12, 16, 10, 0, 0, 0);
  final result = await _runFixture(
    reference: source,
    candidate: image.Image.from(source),
    referenceCase: _fixtureCase(
      staticTextRegions: const [
        StaticTextRegion(
          name: 'live-price',
          referenceRect: _textSearch,
          candidateRect: _textSearch,
          ink: referencePrimaryInk,
          auditMode: StaticTextAuditMode.dynamicOnly,
        ),
      ],
      dynamicMaskRegions: const [
        ReferenceDynamicMask(
          kind: ReferenceDynamicMaskKind.livePrices,
          rect: ReferencePixelRect(12, 12, 1, 1),
          reason: 'Synthetic live price.',
        ),
      ],
    ),
  );
  expect(result.exitCode, 2, reason: result.diagnostics);
  expect(result.diagnostics, contains('must be fully covered'));
});
```

Add a second fixture whose candidate rectangle extends two pixels beyond the
mask and a green fixture where both rectangles are contained by one mask.

Run: `cd mobile && flutter test test/tab_typography_comparator_test.dart --plain-name "rejects a partial mask for dynamic-only text"`

Expected RED: current intersection logic exits 0 and emits `SKIP`.

- [ ] **Step 2: Write and run RED foreground-color mutation tests**

Use a white 64 x 64 canvas with a black 10 x 10 required control. Keep bounds
unchanged and table-test candidate RGB values 4, 5, and 12:

```dart
for (final mutation in <(int, int)>[(4, 0), (5, 1), (12, 1)]) {
  test('static foreground RGB ${mutation.$1} has exit ${mutation.$2}', () async {
    final reference = _blankImage();
    _fillRect(reference, 20, 20, 10, 10, 0, 0, 0);
    final candidate = _blankImage();
    _fillRect(
      candidate,
      20,
      20,
      10,
      10,
      mutation.$1,
      mutation.$1,
      mutation.$1,
    );
    final result = await _runFixture(
      reference: reference,
      candidate: candidate,
      referenceCase: _fixtureCase(
        staticControlRegions: const [
          ReferenceStaticControlRegion(name: 'ink-control', rect: _canvas),
        ],
      ),
    );
    expect(result.exitCode, mutation.$2, reason: result.diagnostics);
  });
}
```

Run: `cd mobile && flutter test test/tab_typography_comparator_test.dart --plain-name "static foreground RGB 5 has exit 1"`

Expected RED: RGB 5 and 12 currently exit 0 because bounds/surface are unchanged
and residual counting ignores differences <= 12.

- [ ] **Step 3: Implement one shared full-containment helper**

Use the existing `_containsRect` function and call this helper from manifest
validation and SKIP reporting:

```dart
ReferenceDynamicMask? _coveringDynamicMask(
  TabReferenceCase referenceCase,
  StaticTextRegion region,
) {
  for (final mask in referenceCase.dynamicMaskRegions) {
    if (_containsRect(mask.rect, region.referenceRect) &&
        _containsRect(mask.rect, region.candidateRect)) {
      return mask;
    }
  }
  return null;
}
```

Return input exit code 2 with the case/region name when no covering mask exists.
The SKIP row uses only the covering mask's non-empty reason.

- [ ] **Step 4: Implement measured static foreground semantics**

Amendment: replace the crop-quartile estimator with explicit reference-only
semantic roles. Each role declares decoded-reference interior rectangles;
cluster their samples with Chebyshev radius 2 and select the most-frequent
cluster's deterministic medoid. Reject empty or inconsistent calibration,
required roles without assigned text/control regions, and composite maps with
missing or extra roles. The manifest `ink` and role key are routing identities,
not RGB truth.

Measure candidate text and atomic-control ink locally from the raw candidate;
never snap it to the reference role. Composite regions compare an independent
per-role map and use the worst role delta. Preserve whole-canvas and
whole-navigation residual/geometry rows, all existing thresholds, and exact
decoded-raster invariance. Add adversarial black, blue, misleading-hint,
empty/inconsistent, missing/extra-role, and one-pixel-mutation regressions.

- [ ] **Step 5: Extend the CSV and focused CLI contract**

Add `measuredReferenceForeground`, `candidateForeground`, and
`foregroundColorDelta` immediately after the existing surface-color columns,
making every row exactly 22 columns. Add `--case SAFE_ID` parsing; filter the
canonical cases before manifest/input preflight and reject an unknown ID with
exit code 2. Tests must assert filtering emits only the requested case and
never creates artifacts for unselected cases.

- [ ] **Step 6: Tighten dynamic-only rectangles rather than broadening masks**

For every `StaticTextAuditMode.dynamicOnly` entry, set its reference and
candidate rectangles to the already-measured live-value mask it belongs to.
Keep mixed static suffixes/labels separate and retain static-control overlap
checks. Add independent manifest expectations for all dynamic-only rectangles.

- [ ] **Step 7: Verify RED-GREEN and JPEG calibration**

Run:

```bash
cd mobile
flutter test test/tab_typography_comparator_test.dart
flutter test test/tab_reference_manifest_test.dart test/tab_typography_golden_test.dart
dart run tool/compare_tab_typography.dart --case prices
flutter analyze
flutter build apk --debug
cd ../backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

The synthetic comparator tests must pass. The real Prices comparison must
still exit 1 with actionable visual mismatches; do not loosen thresholds.

- [ ] **Step 8: Commit Task 1**

```bash
git add mobile/tool/compare_tab_typography.dart \
  mobile/test/tab_typography_comparator_test.dart \
  mobile/test/test_support/tab_reference_manifest.dart \
  mobile/test/tab_reference_manifest_test.dart \
  docs/screens/reference-parity-manifest.md
git commit -m "fix: close reference comparator false passes"
```

---

### Task 2: Reproduce Fonts and Calibrate Shared Shell/Navigation (Task 3)

**Files:**
- Add unchanged owner assets: `mobile/assets/fonts/Roboto-Variable.ttf`
- Add unchanged owner assets: `mobile/assets/fonts/RobotoCondensed-Variable.ttf`
- Add unchanged owner provenance/licenses: `mobile/assets/fonts/README.md`, `mobile/assets/fonts/OFL-Roboto.txt`, `mobile/assets/fonts/LICENSE-RobotoCondensed-Apache-2.0.txt`
- Modify: `mobile/lib/core/theme/app_colors.dart`
- Modify: `mobile/lib/core/theme/app_typography.dart`
- Modify: `mobile/lib/core/theme/app_shadows.dart`
- Modify: `mobile/lib/core/theme/tab_reference_metrics.dart`
- Modify: `mobile/lib/shared/widgets/app_shell.dart`
- Add unchanged or extend without weakening: `mobile/test/app_shell_reference_safe_inset_test.dart`
- Modify: `mobile/test/bottom_navigation_icon_parity_test.dart`
- Modify: `mobile/test/chart_reference_manifest_test.dart`
- Modify: `mobile/test/tab_typography_comparator_test.dart`
- Modify generated candidates: `mobile/test/goldens/tab-typography/*.png`

**Interfaces:**
- Consumes: strict comparator fields and all seven selected-tab states.
- Produces: reproducible fonts, exact safe-area/nav tokens, and shared chrome that every later screen inherits.

- [ ] **Step 1: Preserve and validate the owner font assets**

Record their current SHA-256 values before staging. Assert the two font files
exist and that `pubspec.yaml` resolves all four declared families. Do not
rewrite the binaries or license text.

- [ ] **Step 2: Add a RED shared-chrome acceptance test**

Run the comparator against the seven checked-in candidates and inspect only
rows whose region is `system`, `bottom-navigation`,
`bottom-navigation-surface`, or starts with `navigation-`. Require every such
static row to be `PASS` and keep dynamic status rows as reasoned `SKIP`.

```dart
expect(
  sharedRows.where((row) => row.status == 'FAIL'),
  isEmpty,
  reason: sharedRows.where((row) => row.status == 'FAIL').join('\n'),
);
```

Run: `cd mobile && flutter test test/tab_typography_comparator_test.dart --plain-name "all seven candidates pass shared chrome"`

Expected RED: current nav bounds, shadow, selected ink/density, settings label,
and system residuals fail.

- [ ] **Step 3: Lock the production AppShell safe-area boundary**

Incorporate the existing owner test that feeds a 62-point iPhone top inset and
asserts the production shell exposes `24.0/24.0/34.0` to its tab body. Add a
keyboard case proving the bottom navigation is removed only while
`viewInsets.bottom > 0`.

- [ ] **Step 4: Calibrate shared tokens and nav geometry**

Move all nav capsule height/insets/radius/icon/label offsets into named
`TabReferenceMetrics` members. Tune from measured reference bounds, preserving
five equal interactive hit targets and semantic selection. Keep
`AppColors.primary == Color(0xFF007AFF)`, navigation selected surface
`0xFFEDEDED`, white surface, and black unselected ink. Adjust the nav shadow
only through `AppShadows`.

- [ ] **Step 5: Regenerate all seven candidates from production widgets**

Run: `cd mobile && flutter test test/tab_typography_golden_test.dart --update-goldens`

Then rerun the shared-chrome acceptance test. Iterate one shared metric/token
at a time until every shared row is `PASS`; unrelated screen-body rows may
still fail.

- [ ] **Step 6: Make the Windows-only Chart capture preflight truthful on macOS**

Keep the PowerShell behavior test active on Windows. On other hosts, mark only
that process-launch test skipped with the explicit reason
`capture-chart-parity.ps1 requires Windows PowerShell`; keep the platform-
independent chart manifest assertions active. This removes a false host-tool
failure without changing the PowerShell script or treating an unexecuted
preflight as a pass.

- [ ] **Step 7: Run Task 2 verification**

```bash
cd mobile
flutter analyze
flutter test test/app_shell_reference_safe_inset_test.dart \
  test/bottom_navigation_icon_parity_test.dart \
  test/chart_reference_manifest_test.dart \
  test/tab_typography_tokens_test.dart \
  test/tab_typography_golden_test.dart \
  test/tab_typography_comparator_test.dart
flutter build apk --debug
cd ../backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

- [ ] **Step 8: Commit Task 2**

Stage only the named assets, shared source/tests, and seven regenerated
candidates. Confirm all other untracked owner paths remain unstaged.

```bash
git commit -m "fix: calibrate shared reference chrome"
```

---

### Task 3: Calibrate Prices (Task 4)

**Files:**
- Modify: `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart`
- Modify when shared evidence requires: `mobile/lib/core/theme/app_typography.dart`
- Modify when shared evidence requires: `mobile/lib/core/theme/tab_reference_metrics.dart`
- Modify: `mobile/test/market_watch_parity_test.dart`
- Modify: `mobile/test/tab_typography_comparator_test.dart`
- Modify generated candidate: `mobile/test/goldens/tab-typography/prices-590x1280.png`
- Update: `docs/screens/reference-parity-manifest.md`

**Interfaces:**
- Consumes: exact shared chrome and `--case prices`.
- Produces: a fully passing Prices state without changing quote streams or interactions.

- [ ] **Step 1: Add a RED strict Prices acceptance test**

Call `runTabTypographyComparison` with only the Prices manifest case and the
checked-in candidate directory. Require exit code 0 and no `,FAIL,` row.

Run: `cd mobile && flutter test test/tab_typography_comparator_test.dart --plain-name "Prices candidate passes strict reference parity"`

Expected RED: current toolbar, quote geometry, colors, and density fail.

- [ ] **Step 2: Preserve Prices behavior with focused widget assertions**

Cover menu/edit/search actions, both deterministic rows, semantic blue/red
price state, and the supported-width no-overflow contract. These tests use
production widgets and the existing deterministic providers.

- [ ] **Step 3: Calibrate toolbar and quote-row presentation**

Tune only the named toolbar/quote roles and their measured row anchors. Keep
the title independently centered; keep Bid/Ask, time, spread, `L:`/`H:` labels,
and values in separate semantic widgets. Do not replace data with screenshot
text or hide any static label with a mask.

- [ ] **Step 4: Regenerate and compare Prices until green**

```bash
cd mobile
flutter test test/tab_typography_golden_test.dart \
  --plain-name "prices typography matches the canonical candidate" \
  --update-goldens
dart run tool/compare_tab_typography.dart --case prices \
  --output-dir ../.superpowers/sdd/2026-08-27-seven-state-visual-parity-completion/prices-evidence
```

The comparator must exit 0. Inspect the final overlay/heatmap and require zero
`FAIL` rows, not merely a reduced residual percentage.

- [ ] **Step 5: Run Task 3 verification and commit**

```bash
cd mobile
flutter analyze
flutter test test/market_watch_parity_test.dart \
  test/tab_typography_golden_test.dart \
  test/tab_typography_comparator_test.dart
flutter build apk --debug
cd ../backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Commit: `fix: match Prices reference state`

---

### Task 4: Calibrate Trade (Task 5)

**Files:**
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Modify only if a Trade FAIL row maps to an existing shared role: `mobile/lib/core/theme/app_typography.dart`
- Modify only if a Trade FAIL row maps to an existing shared metric: `mobile/lib/core/theme/tab_reference_metrics.dart`
- Add unchanged or extend without weakening: `mobile/test/trade_reference_width_scale_test.dart`
- Modify: `mobile/test/trade_add_order_ticket_reference_test.dart`
- Modify: `mobile/test/trade_position_bulk_actions_flow_test.dart`
- Modify: `mobile/test/tab_typography_comparator_test.dart`
- Modify generated candidate: `mobile/test/goldens/tab-typography/trade-590x1280.png`

**Interfaces:**
- Consumes: shared chrome, reference-width contract, strict `--case trade`.
- Produces: passing Trade header/metrics/rows/scrollbar while retaining all position actions.

- [ ] **Step 1: Add RED Trade parity and scrollbar tests**

Require the Trade case comparator to exit 0. Add a widget assertion that an
overflowing deterministic positions list has a visible scrollbar at the
canonical width and that its captured indicator occupies the manifest's
`[581,318,5,790]` physical rectangle.

- [ ] **Step 2: Preserve Trade interaction and responsive behavior**

Incorporate the owner width-scale test byte-for-byte before extending it. Rerun
add-order, swipe actions, tap/long-press bulk actions, edit, and close flows.

- [ ] **Step 3: Calibrate the Trade visual layers**

Correct the centered numeric P/L plus independently audited `USD` suffix,
two-column account metrics, section surface/label, position primary/secondary
baselines, right-aligned P/L, row pitch, and persistent overflow scrollbar.
Keep the canonical-width layout responsive without clipping at 360-430.

- [ ] **Step 4: Regenerate and compare Trade until green**

```bash
cd mobile
flutter test test/tab_typography_golden_test.dart \
  --plain-name "trade typography matches the canonical candidate" \
  --update-goldens
dart run tool/compare_tab_typography.dart --case trade \
  --output-dir ../.superpowers/sdd/2026-08-27-seven-state-visual-parity-completion/trade-evidence
```

Require exit 0 and a non-empty CSV/overlay/heatmap set.

- [ ] **Step 5: Run Task 4 verification and commit**

Run analyze, the Trade tests named above, the golden/comparator suites, debug
APK, and both backend commands. Commit: `fix: match Trade reference state`.

---

### Task 5: Calibrate Four History States (Task 6)

**Files:**
- Modify: `mobile/lib/features/history/presentation/screens/history_screen.dart`
- Modify only if a History FAIL row maps to an existing shared role: `mobile/lib/core/theme/app_typography.dart`
- Modify only if a History FAIL row maps to an existing shared metric: `mobile/lib/core/theme/tab_reference_metrics.dart`
- Modify: `mobile/test/history_fixture_video2_test.dart`
- Modify: `mobile/test/history_screen_detail_test.dart`
- Modify: `mobile/test/history_screen_performance_test.dart`
- Modify: `mobile/test/tab_typography_comparator_test.dart`
- Modify generated candidates: `mobile/test/goldens/tab-typography/history-*.png`

**Interfaces:**
- Consumes: shared chrome and the four exact manifest scroll states.
- Produces: passing History Positions, Orders, Orders Summary, and Deals states from one shared header/list system.

- [ ] **Step 1: Add four RED strict History acceptance tests**

Table-test `history-positions`, `history-orders`,
`history-orders-summary`, and `history-deals`, requiring exit 0 and no failure
rows for each selected case.

- [ ] **Step 2: Add exact scroll-indicator behavior tests**

At the canonical viewport, assert no indicator for the non-overflowing
Positions state and visible indicators for Orders offset, Orders end, and
Deals end. Their final physical rectangles must equal the manifest's three
measured History scrollbar rectangles.

- [ ] **Step 3: Calibrate the shared History header and rows**

Tune toolbar circles, 385 x 49 physical segmented control, selected surface,
segment labels, list top gap, primary/secondary baselines, trailing status/date,
row heights, summary rows, and scrollbar geometry. Keep one shared row system;
do not fork styling per screenshot when the state difference is only scroll.

- [ ] **Step 4: Regenerate all four History states after every shared change**

```bash
cd mobile
flutter test test/tab_typography_golden_test.dart --update-goldens
for case_id in history-positions history-orders history-orders-summary history-deals; do
  dart run tool/compare_tab_typography.dart --case "$case_id" \
    --output-dir "../.superpowers/sdd/2026-08-27-seven-state-visual-parity-completion/$case_id-evidence"
done
```

All four comparator invocations must exit 0 in the final run.

- [ ] **Step 5: Run Task 5 verification and commit**

Run analyze, all History tests, golden/comparator suites, debug APK, and both
backend commands. Commit: `fix: match History reference states`.

---

### Task 6: Calibrate Chart (Task 7)

**Files:**
- Modify only where visual evidence requires: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Modify only where visual evidence requires: `mobile/lib/features/chart/presentation/geometry/chart_geometry.dart`
- Modify only where visual evidence requires: `mobile/lib/features/chart/presentation/theme/chart_reference_theme.dart`
- Modify only where visual evidence requires: `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`
- Modify: `mobile/test/chart_controls_test.dart`
- Modify: `mobile/test/chart_geometry_test.dart`
- Modify: `mobile/test/chart_light_parity_golden_test.dart`
- Modify: `mobile/test/tab_typography_comparator_test.dart`
- Modify generated candidate: `mobile/test/goldens/tab-typography/chart-590x1280.png`
- Modify generated chart goldens only if production output intentionally changes: `mobile/test/goldens/chart/light/*.png`

**Interfaces:**
- Consumes: shared chrome, canonical chart geometry, deterministic candle/quote fixtures.
- Produces: a passing Chart state without changing subscriptions, order dispatch, viewport/session behavior, gestures, or live candle semantics.

- [ ] **Step 1: Add a RED strict Chart acceptance test**

Require the Chart selected case to exit 0. Confirm the drawable candle mask is
exactly `[0,267,472,873]` physical and leaves toolbar, one-click ticket, plot
title/subtitle, frame, right axis, X axis, and overflow control audited.

- [ ] **Step 2: Lock behavior before visual edits**

Run the existing chart control, geometry, viewport, gesture, repaint,
timeframe-transition, order-dispatch, and session-store tests. Record the
untracked session-store source/test hashes and do not edit them.

- [ ] **Step 3: Calibrate static Chart layers from outside inward**

Adjust toolbar first, then one-click ticket, plot title/subtitle, frame/grid,
right price axis, X axis, annotations, and overflow control. Keep painter data
and viewport math unchanged unless a failing geometry test demonstrates that
the measured anchor—not market data—is wrong.

- [ ] **Step 4: Regenerate Chart candidates and the matrix after visual-source changes**

```bash
cd mobile
flutter test test/tab_typography_golden_test.dart \
  --plain-name "chart typography matches the canonical candidate" \
  --update-goldens
flutter test test/chart_light_parity_golden_test.dart --update-goldens
dart run tool/compare_tab_typography.dart --case chart \
  --output-dir ../.superpowers/sdd/2026-08-27-seven-state-visual-parity-completion/chart-evidence
```

Require strict Chart exit 0 and all 27 timeframe/zoom goldens green against
the newly reviewed production output.

- [ ] **Step 5: Run Task 6 verification and commit**

Run analyze, all relevant Chart tests including repaint/session/order paths,
the golden/comparator suites, debug APK, and both backend commands. Commit:
`fix: match Chart reference state`.

---

### Task 7: Close the Seven-State Gate and Capture Devices (Task 8)

**Files:**
- Modify: `docs/screens/reference-ui.md`
- Modify: `docs/screens/reference-parity-manifest.md`
- Modify: `docs/screenshots/tab-typography-parity/README.md`
- Refresh: `docs/screenshots/tab-typography-parity/android-*-590x1280.png`
- Refresh ignored evidence: `.superpowers/sdd/2026-08-27-seven-state-visual-parity-completion/final-evidence/*`
- Modify tests/source only when a final cross-state regression proves a real shared defect.

**Interfaces:**
- Consumes: all six preceding task outputs.
- Produces: one clean seven-state acceptance result, fresh device evidence, final APK, and truthful documentation.

- [ ] **Step 1: Add and run the full seven-state acceptance test**

Run the comparator with all manifest cases and require exit 0, exactly seven
case IDs, exactly 14 non-empty overlay/heatmap PNGs, a 22-column CSV, no
`measurement failed`, no `FAIL`, and only the declared reasoned dynamic
`SKIP` rows.

- [ ] **Step 2: Generate final deterministic evidence**

```bash
cd mobile
flutter test test/tab_typography_golden_test.dart --update-goldens
dart run tool/compare_tab_typography.dart \
  --output-dir ../.superpowers/sdd/2026-08-27-seven-state-visual-parity-completion/final-evidence
```

Both commands must exit 0.

- [ ] **Step 3: Capture all seven states through the Android engine**

Launch `trading-debug-api36`, resolve its exact ADB serial, temporarily set it
to 590 x 1280 at 240 dpi, and run each state through. Resolve and validate the
serial before any display mutation:

```bash
android_sdk_adb=/Users/hoangnguyenxuan/Library/Android/sdk/platform-tools/adb
parity_device_serial=$("$android_sdk_adb" devices | awk '/^emulator-[0-9]+[[:space:]]+device$/{print $1; exit}')
test -n "$parity_device_serial"
"$android_sdk_adb" -s "$parity_device_serial" shell wm size 590x1280
"$android_sdk_adb" -s "$parity_device_serial" shell wm density 240
for case_id in prices chart trade history-positions history-orders history-orders-summary history-deals; do
flutter drive \
  --driver=test_driver/tab_typography_device_test.dart \
  --target=integration_test/tab_typography_device_test.dart \
  -d "$parity_device_serial" \
  --dart-define=TAB_REFERENCE_CASE="$case_id"
done
"$android_sdk_adb" -s "$parity_device_serial" shell wm size reset
"$android_sdk_adb" -s "$parity_device_serial" shell wm density reset
```

Verify every PNG is non-empty and exactly 590 x 1280, then restore emulator
size/density with `wm size reset` and `wm density reset`. Do not leave emulator
display overrides behind after failure or success.

- [ ] **Step 4: Run final full verification**

```bash
cd mobile
flutter analyze
flutter test
flutter build apk --debug
cd ../backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Also run `git diff --check` and confirm unrelated owner files remain unmodified
and unstaged. If a required environment tool remains unavailable, preserve the
exact failure evidence and do not weaken source/tests.

- [ ] **Step 5: Update documentation from fresh evidence**

Replace stale dark-theme and permissive-threshold claims. Record exact final
case counts, PASS/SKIP counts, hashes/paths of all evidence, emulator metrics,
APK path, commands, full-suite totals, and any platform-owned exclusions. Do
not retain older claims that contradict current output.

- [ ] **Step 6: Commit Task 7**

Stage only reviewed production/tests/goldens/documentation and the seven
tracked Android captures. Commit: `test: close seven-state reference parity`.

---

## Completion Gate

- Task 1 comparator regression tests prove both prior false-passes RED before GREEN.
- Tasks 2-6 each have an approved task review and their focused comparator contract is green.
- The final deterministic comparator exits 0 for all seven cases with no static `FAIL` rows.
- The seven deterministic candidates, seven Android-engine captures, seven overlays, seven heatmaps, and final CSV are present and non-empty.
- All relevant interaction, responsive, chart, navigation, and scroll tests pass.
- Flutter analyze, full Flutter test, and debug APK build have fresh successful results.
- Backend build/test have fresh successful results or a verbatim environment-only block that was not bypassed by changing the required stack.
- Final whole-branch review has no unaddressed Critical or Important finding.
- No unrelated owner work was modified, staged, reset, stashed, or cleaned.
