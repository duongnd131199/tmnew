# Reference Parity Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a trustworthy, reproducible foundation for matching the seven supplied 590 x 1280 reference screenshots before changing any screen visuals.

**Architecture:** Preserve the existing Flutter and ASP.NET Core stack. First protect the dirty baseline and restore truthful build/test gates, then enrich the seven-state reference manifest, and finally replace the permissive typography-only comparator with a reference-driven comparator that validates measured geometry, color, density, surfaces, and full static regions.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, Riverpod, GoRouter, package:image, Flutter widget/integration tests, Android ADB capture, ASP.NET Core 8.

**Spec:** `docs/superpowers/specs/2026-08-25-tab-typography-spacing-parity-design.md`

## Global Constraints

- Preserve all owner changes already present in the working tree; do not stash, reset, discard, or overwrite unrelated files.
- Work only on Task 0-2 infrastructure; do not visually tune Prices, Chart, Trade, History, or shared navigation in this execution batch.
- Keep the required Flutter/Dart/Riverpod/GoRouter and ASP.NET Core technology stack unchanged.
- Use the seven original JPEG files under `iconMau/anhmau` at exactly 590 x 1280 physical pixels.
- Canonical Flutter viewport is 393.3333333333 x 853.3333333333 logical pixels at DPR 1.5 and text scale 1.0.
- Reference measurements, not hard-coded candidate expectations, are the source of truth for comparison acceptance.
- Static geometry edge tolerance is 1 physical pixel, semantic reference-to-candidate RGB tolerance is 4 per channel, and optical ink-density tolerance is 5 percent.
- Dynamic masks may cover only platform-owned status values, changing prices/timestamps/P&L, and truly live chart content; static labels, controls, surfaces, borders, shadows, and spacing may not be masked.
- Follow RED-GREEN-REFACTOR for every behavior change.
- After every task run Flutter analyze, focused tests, debug APK build, and the required backend build/test commands; report environment blockers without changing `global.json`.

---

### Task 0: Protect Baseline and Restore Truthful Validation Gates

**Files:**
- Create: `mobile/test/android_version_code_test.dart`
- Modify: `mobile/pubspec.yaml`
- Modify: `mobile/test/chart_controls_test.dart`
- Create outside git: `.superpowers/sdd/2026-08-26-reference-parity-foundation/baseline/*`

**Interfaces:**
- Consumes: current dirty working tree and Android `versionCode` contract.
- Produces: recoverable baseline artifacts, a legal monotonic version code, and a deterministic Chart realtime-history test.

- [ ] **Step 1: Capture a recoverable baseline without changing the working tree**

Write a binary tracked diff, status manifest, HEAD/branch metadata, and an archive of untracked paths under this plan's git-ignored SDD workspace. Verify each artifact can be listed/read and record hashes in the task report.

- [ ] **Step 2: Write and run the failing Android version-code contract test**

The test reads `pubspec.yaml`, extracts the build metadata after `+`, verifies it parses as an integer in `1..2100000000`, and fails against the current 12-digit value `202608262038`.

Run: `flutter test test/android_version_code_test.dart`

Expected RED: the build number exceeds `2100000000`.

- [ ] **Step 3: Use the minimal legal monotonic build number**

Set `version: 1.0.0+26082601`, preserving the date/build intent while remaining within Android's signed integer range.

Run: `flutter test test/android_version_code_test.dart`

Expected GREEN: the version-code contract passes.

- [ ] **Step 4: Resolve the existing Chart test fixture failure without changing production candle behavior**

In `realtime chart renders API candles without demo reshaping`, override `marketClockProvider` with `() => history.last.time.toUtc()`, matching the established test pattern and ensuring the emitted quote stays in the final history bucket. Do not change `ChartScreen` or the live candle controller in this task.

Run: `flutter test test/chart_controls_test.dart --plain-name "realtime chart renders API candles without demo reshaping"`

Expected GREEN: resolved candles have the same length and timestamps as the 40-candle history fixture.

- [ ] **Step 5: Run Task 0 verification**

Run:

```bash
cd mobile
flutter analyze
flutter test test/android_version_code_test.dart test/chart_controls_test.dart
flutter build apk --debug
cd ../backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Record any .NET SDK environment block exactly; do not edit `global.json`.

---

### Task 1: Expand the Seven-State Reference Manifest

**Files:**
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`
- Modify: `mobile/test/tab_reference_manifest_test.dart`
- Create: `docs/screens/reference-parity-manifest.md`

**Interfaces:**
- Consumes: seven JPEG references and canonical viewport constants.
- Produces: typed per-case element regions, dynamic masks with reasons, capture state metadata, and whole-screen static audit regions consumed by Task 2.

- [ ] **Step 1: Write failing manifest coverage tests**

Require every case to declare its route/state, selected tab, capture/scroll state, full-canvas static audit region, dynamic masks with non-empty reasons, and typed regions covering system/content bounds, header, body, scrollbar where visible, and bottom navigation. Require masks to stay inside the canvas and never intersect each case's required static controls/labels.

Run: `flutter test test/tab_reference_manifest_test.dart`

Expected RED: the current manifest lacks typed full-screen element coverage and mask reasons.

- [ ] **Step 2: Add the minimal typed manifest API and seven measured cases**

Retain existing `StaticTextRegion` compatibility while adding typed visual element metadata. Use original physical-pixel coordinates only. Add explicit state details for Prices, Chart, Trade, History positions, History orders, History orders summary, and History deals.

- [ ] **Step 3: Document the manifest contract**

Create `docs/screens/reference-parity-manifest.md` with the canonical environment, file-to-state mapping, measurement conventions, dynamic-mask policy, and the exact reason each dynamic class is excluded.

- [ ] **Step 4: Run Task 1 verification**

Run:

```bash
cd mobile
flutter analyze
flutter test test/tab_reference_manifest_test.dart test/tab_typography_golden_test.dart
flutter build apk --debug
cd ../backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

---

### Task 2: Replace the Permissive Comparator with Reference-Driven Validation

**Files:**
- Modify: `mobile/tool/compare_tab_typography.dart`
- Modify: `mobile/test/tab_typography_comparator_test.dart`
- Modify as required by the typed API: `mobile/test/test_support/tab_reference_manifest.dart`

**Interfaces:**
- Consumes: Task 1 typed manifest, original JPEG references, deterministic PNG candidates.
- Produces: exit-code-enforced reference-to-candidate geometry/color/density/static-pixel comparison plus machine-readable CSV and optional overlay/heatmap artifacts.

- [ ] **Step 1: Write RED regression tests for the current false-positive paths**

Add independent mutations proving the comparator rejects:

- candidate ink that matches a hard-coded manifest color but differs from measured reference ink;
- optical density drift above 5 percent with unchanged bounds;
- a 2-pixel baseline/edge shift;
- a static surface or control mutation outside text regions;
- a dynamic mask that intersects a required static region.

Run: `flutter test test/tab_typography_comparator_test.dart`

Expected RED: at least the measured-reference-color, strict-density, and static-surface cases pass incorrectly under the existing comparator.

- [ ] **Step 2: Implement measured reference-to-candidate comparison**

Compare candidate semantic ink to the measured reference sample, not to the manifest color. Preserve both values in the report. Enforce edge `<=1 px`, RGB delta `<=4`, and density delta `<=5%` for deterministic candidates. Validate masks before measuring.

- [ ] **Step 3: Add typed visual-region and static full-screen comparison**

Measure flat surfaces, controls/borders/icons, and all unmasked static pixels. Report differing pixel count/ratio and fail when a required typed region exceeds its contract. JPEG-aware comparison may estimate local backgrounds, but may not substitute a candidate token for the measured reference.

- [ ] **Step 4: Add artifact/report output without changing default inputs**

Keep the existing default command working. Add optional output-directory support for CSV, 50/50 overlay, and heatmap artifacts; output directories are generated evidence and remain outside production assets.

- [ ] **Step 5: Verify RED mutations turn GREEN and the real candidates report their actual failures**

Run:

```bash
cd mobile
flutter test test/tab_typography_comparator_test.dart
dart run tool/compare_tab_typography.dart
flutter analyze
flutter build apk --debug
cd ../backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

The real candidate command is expected to return non-zero until Tasks 3-8 visually calibrate the screens. That non-zero result is success for Task 2 if its report correctly identifies the existing reference mismatches; do not loosen thresholds to make current candidates pass.

---

## Task 0-2 Completion Gate

- Baseline artifacts are recoverable and verified.
- Android version code and debug APK build are valid.
- The pre-existing 40/41 Chart fixture failure is resolved deterministically.
- All seven references have complete typed manifest coverage.
- Comparator regression tests demonstrate RED before implementation and GREEN afterward.
- Current mismatched UI is rejected by the new comparator with actionable region-level evidence.
- No Task 3+ visual production files are modified as part of this batch.
