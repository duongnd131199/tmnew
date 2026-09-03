# Chart Rightmost Toolbar Icon Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the far-right Chart toolbar windows icon to the supplied 590x1280 reference without changing its behavior or neighboring controls.

**Architecture:** Retain the existing `CustomPainter` and toolbar hit target. Correct the icon-local transform and the two colored rectangle bounds, then protect the result with the existing real-widget raw-RGBA capture at DPR 1.5.

**Tech Stack:** Flutter, Dart, `CustomPainter`, Flutter widget raster tests, iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-08-31-chart-rightmost-toolbar-icon-parity-design.md`

## Global Constraints

- Do not change the required technology stack or add bitmap icon assets.
- Preserve all unrelated dirty-worktree changes.
- Preserve the 38x40 logical hit target and one-click trading callback.
- Do not alter the adjacent circular chart-mode icon.
- Run relevant tests, Flutter analyze, build, and direct iPhone 17 verification.

---

### Task 1: Correct the far-right toolbar icon raster

**Files:**
- Modify: `mobile/test/chart_controls_test.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`

**Interfaces:**
- Consumes: `chart-one-click-toggle`, `_ToolbarWindowsIcon`, `_ToolbarWindowsIconPainter`, and `_chartButtonColorMetrics`.
- Produces: a 28x19 physical-pixel icon at DPR 1.5 whose meaningful global
  contour starts at y=102, with a 13-pixel red block and 14-pixel blue block
  beginning at local x=14.

- [x] **Step 1: Write the failing raster expectations**

Update the DPR 1.5 colored-icon assertions so the red and blue blocks are 13
and 14 physical pixels wide and the blue begins 14 pixels from the colored
contour's left edge. Protect the measured rounded final row and the white
bridge opening. Update
the mapped global ink literal for `chart-one-click-toggle` from
`Rect.fromLTRB(542, 105, 570, 124)` to
`Rect.fromLTRB(542, 102, 570, 121)`.

```dart
expect(windows.redBounds.size, const Size(13, 19));
expect(windows.blueBounds.size, const Size(14, 19));
expect(
  windows.blueBounds.topLeft - windows.coloredBounds.topLeft,
  const Offset(14, 0),
);

const Key('chart-one-click-toggle'):
    const Rect.fromLTRB(542, 102, 570, 121),

expect(windows.backgroundOpeningPixels, greaterThanOrEqualTo(50));
```

- [x] **Step 2: Run the focused tests and verify RED**

Run:

```bash
cd mobile
flutter test test/chart_controls_test.dart --plain-name "Chart colored toolbar rasterization matches the mapped sample at device DPR"
flutter test test/chart_controls_test.dart --plain-name "Chart toolbar ink matches the supplied 590px device reference"
```

Expected: the first test reports the old 13-pixel blue block/15-pixel offset,
and the second reports the old y=105..124 global bounds.

- [x] **Step 3: Implement the minimal vector correction**

Move `_ToolbarWindowsIcon` upward by 2 logical pixels and balance both colored
rectangles while retaining the approved palette:

```dart
offset: const Offset(0, -.6666666667),
size: const Size(18.3333333333, 12.6666666667),

const Rect.fromLTWH(0, 0, 9, 12.6666666667)
const Rect.fromLTWH(9.6666666667, .3, 8.8333333333, 12.3666666667)
```

Keep lower corner radii at `3` on both colored blocks; the normalized native
crop had a higher SSIM with this rounded contour than the sharper candidate.
Recenter the existing bridge without changing its treatment:

```dart
const Rect.fromLTWH(4.3333333333, 3.3333333333, 10, 5.3333333333)
const Rect.fromLTWH(5.8333333333, 4.5, 7, 4)
```

- [x] **Step 4: Run focused and relevant tests and verify GREEN**

Run:

```bash
cd mobile
flutter test test/chart_controls_test.dart --plain-name "Chart colored toolbar rasterization matches the mapped sample at device DPR"
flutter test test/chart_controls_test.dart --plain-name "Chart toolbar ink matches the supplied 590px device reference"
flutter test test/chart_controls_test.dart
flutter analyze
```

Expected: all commands pass without new warnings or errors.

- [x] **Step 5: Build and verify on iPhone 17**

Run:

```bash
cd mobile
flutter build ios --simulator --debug
xcrun simctl install 5AD1B6AA-5814-4EAA-A573-4B9C561BABA4 build/ios/iphonesimulator/Runner.app
xcrun simctl launch 5AD1B6AA-5814-4EAA-A573-4B9C561BABA4 com.tradingdemo.tradingMobile
```

Capture a native Simulator screenshot and normalize the rightmost icon crop to
the reference's DPR 1.5 dimensions. Confirm its top edge, outer 28-pixel width,
red/blue separation, white bridge, and gray core visually match the supplied
sample.

- [x] **Step 6: Review the scoped diff**

Inspect only the new design/plan, `chart_screen.dart`, and
`chart_controls_test.dart`; confirm no unrelated worktree edits were reverted.

## Test-design evidence

- The old implementation failed the new global position expectation with
  `Rect.fromLTRB(542, 105, 570, 124)` and failed the balanced blue-block
  expectation with a 13-pixel width and local x=15.
- A sharp-lower-corner/12-pixel-red candidate was rejected after normalized
  native-crop comparison because its SSIM was lower than the retained rounded
  13-pixel-red contour.
- A deliberate light-gray bridge mutation reduced the near-white opening to
  18 pixels and failed the `>= 50` regression guard; restoring the theme
  background passed the focused raster test.

## Final verification evidence

- Both focused raster tests passed after restoring the white bridge.
- All 49 tests in `mobile/test/chart_controls_test.dart` passed.
- `flutter analyze` completed with no issues.
- `flutter build ios --simulator --debug` produced the Simulator Runner app.
- The final app was installed and relaunched on iPhone 17 Simulator
  `5AD1B6AA-5814-4EAA-A573-4B9C561BABA4`; the native capture is
  `artifacts/qa/chart-rightmost-icon-final-verified.png`.
- The normalized reference/current comparison is
  `artifacts/qa/chart-rightmost-icon-reference-vs-final-verified.png`; its
  SSIM is `0.689864`, the best measured candidate for this compressed JPEG.
- Final independent review reported no Critical or Important findings, and
  `git diff --check` found no whitespace errors in the scoped code/test files.
