# Bottom Navigation Icon Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the `Gia`, `Bieu do`, `Giao dich`, and `Lich su` bottom-navigation icons to `giaoDienMau/giaodientrang.MP4` at the canonical 384 x 848 viewport, including contour, size, vertical alignment, selected fill, unselected ink, and the navigation capsule border.

**Architecture:** Keep `MtBottomNavigationBar` routing, semantics, labels, selected-state behavior, and public constructor unchanged. Calibrate only navigation-specific color tokens and the existing Canvas painters/transforms, then lock the approved raster result with focused widget contracts and a small golden contact sheet. Use generic repo-native Canvas paths; do not add or copy proprietary icon assets from the reference application.

**Tech Stack:** Flutter 3.44.6, Dart 3.12.2, flutter_riverpod, flutter_test, CustomPainter golden testing.

**Spec:** `docs/superpowers/specs/2026-08-24-video-white-theme-parity-design.md`; visual source `giaoDienMau/giaodientrang.MP4` at 0.0 s, 12.0 s, 20.0 s, and 36.0 s.

## Global Constraints

- Preserve Flutter, Riverpod, GoRouter, and all existing application interfaces.
- Preserve the 346 x 61 logical-pixel navigation capsule, its x=20 placement, five equal tap targets, labels, and tab routing.
- Preserve selected Trade color behavior: negative account profit is red; zero or positive profit is blue.
- Do not change Chart painter/viewport code, account state, market data, order behavior, or backend code.
- Use semantic design tokens; do not introduce color literals inside `app_shell.dart`.
- Verify at 360, 384, 393, and 430 logical-pixel widths; the 384 x 848 render is the visual reference authority.
- Do not overwrite unrelated dirty-worktree changes in `app_shell.dart` or `app_colors.dart`; apply edits to the current file contents.
- Literal pixel equality with an H.264 MP4 is not a valid acceptance rule because codec artifacts and device rasterization differ. Accept only when visible icon bounds equal the measured reference bounds, contour displacement is at most 1 physical pixel, and the masked golden difference is at most 1.5%.

## Measured Gap Summary

Measurements compare the 20.0 s video frame with `docs/screenshots/trade-context-bulk/bulk-actions-final.png`, captured after the current white-navigation changes. The runtime screenshot is dimmed by a modal, which affects color but not geometry.

| Icon | Video visible bounds | Current app visible bounds | Confirmed gap |
|---|---:|---:|---|
| Gia | 18 x 16 px, top y=790 | 22 x 17 px, top y=786 | 4 px too wide and about 4 px too high |
| Bieu do | 13 x 16 px, top y=790 | 14 x 18 px, top y=786 | 1 px too wide, 2 px too tall, and 4 px too high |
| Giao dich | 19 x 18 px, top y=789 | 20 x 19 px, top y=785 | square border is 1 px too wide and the glyph is 4 px too high |
| Lich su | 20 x 18 px, top y=789 | 20 x 20 px, top y=785 | 2 px too tall and 4 px too high |

Additional confirmed gaps:

- Video selected pill mode is neutral `#E8E8E8`; current `navigationSelectedSurface` is blue-tinted `#E6F2FC`.
- Video navigation surface mode is `#FDFDFD`; current `navigationSurface` already matches.
- Video unselected icon strokes cluster around neutral `#303030`; current `navigationUnselected` is lighter/cooler `#3C3C43`.
- The video has no visible dark divider outline around the capsule. The current app adds a `.7` px `#D9D9DE` border, so the outline is too dark.
- Existing blue/red selected-state logic is correct. Do not change `AppColors.primary` or `AppColors.negative` unless a clean, non-dimmed runtime capture proves a residual accent mismatch.

---

### Task 1: Add failing navigation parity contracts

**Files:**
- Create: `mobile/test/bottom_navigation_icon_parity_test.dart`
- Create after visual approval: `mobile/test/goldens/navigation/quotes-384x848.png`
- Create after visual approval: `mobile/test/goldens/navigation/chart-384x848.png`
- Create after visual approval: `mobile/test/goldens/navigation/trade-384x848.png`
- Create after visual approval: `mobile/test/goldens/navigation/history-384x848.png`
- Modify: `mobile/test/video_white_theme_parity_test.dart`

**Interfaces:**
- Consumes: `MtBottomNavigationBar`, `AppColors`, `demoAccountProvider`, and the existing `bottom-nav-icon-*` keys.
- Produces: geometry, palette, border, selected-state, and golden contracts for the four requested icons.

- [ ] **Step 1: Write failing palette and border assertions**

Extend the existing bottom-navigation test with exact reference roles:

```dart
expect(AppColors.navigationSurface, const Color(0xFFFDFDFD));
expect(AppColors.navigationSelectedSurface, const Color(0xFFE8E8E8));
expect(AppColors.navigationUnselected, const Color(0xFF303030));

final capsule = decorations.singleWhere(
  (decoration) => decoration.color == AppColors.navigationSurface,
);
expect(capsule.border, isNull);
```

- [ ] **Step 2: Add deterministic 384 x 848 icon goldens**

In `bottom_navigation_icon_parity_test.dart`, define this full-viewport harness:

```dart
class BottomNavigationIconGoldenHarness extends StatelessWidget {
  const BottomNavigationIconGoldenHarness({
    required this.selectedIndex,
    super.key,
  });

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('bottom-navigation-icon-golden'),
      child: Material(
        color: Colors.white,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: MtBottomNavigationBar(
            selectedIndex: selectedIndex,
            onTap: (_) {},
          ),
        ),
      ),
    );
  }
}
```

Pump one full 384 x 848 render for each selected index from 0 through 3. Use a positive demo-account override for the blue Trade state and a negative override in a separate color assertion for the red Trade state:

```dart
await tester.binding.setSurfaceSize(const Size(384, 848));
addTearDown(() => tester.binding.setSurfaceSize(null));

for (final state in <(int, String)>[
  (0, 'quotes'),
  (1, 'chart'),
  (2, 'trade'),
  (3, 'history'),
]) {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        demoAccountProvider.overrideWithValue(
          const DemoAccountSnapshot(
            balance: 100000,
            equity: 100246,
            margin: 0,
            freeMargin: 100246,
            marginLevel: 0,
            profit: 246,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BottomNavigationIconGoldenHarness(selectedIndex: state.$1),
      ),
    ),
  );
  await tester.pump();
  await expectLater(
    find.byKey(const Key('bottom-navigation-icon-golden')),
    matchesGoldenFile(
      'goldens/navigation/${state.$2}-384x848.png',
    ),
  );
}
```

- [ ] **Step 3: Add visible-bound assertions to the golden harness**

Pump one additional harness with `selectedIndex: 4` so all four requested icons use the same unselected ink. Decode that boundary image with `toByteData(format: ImageByteFormat.rawRgba)`. Implement `_darkInkBounds` using the same luminance threshold used for the video measurements:

```dart
Future<Rect> _darkInkBounds(
  WidgetTester tester,
  Rect searchRect,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('bottom-navigation-icon-golden')),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (bytes == null) throw StateError('Unable to read navigation pixels');

  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = searchRect.top.toInt(); y < searchRect.bottom.toInt(); y++) {
    for (var x = searchRect.left.toInt(); x < searchRect.right.toInt(); x++) {
      final offset = (y * image.width + x) * 4;
      final red = bytes.getUint8(offset);
      final green = bytes.getUint8(offset + 1);
      final blue = bytes.getUint8(offset + 2);
      final matches = (red + green + blue) / 3 < 160;
      if (!matches) continue;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  image.dispose();
  if (maxX < minX || maxY < minY) {
    throw StateError('Unselected icon ink was not found in $searchRect');
  }
  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    (maxX + 1).toDouble(),
    (maxY + 1).toDouble(),
  );
}
```

Import `dart:math` as `math`, `dart:ui`'s `ImageByteFormat`, and `package:flutter/rendering.dart`. Scan the four unselected icon cells between y=780 and y=810 and assert these canonical visible bounds relative to the viewport:

```dart
expect(quotesBounds, const Rect.fromLTWH(51, 790, 18, 16));
expect(chartBounds, const Rect.fromLTWH(120, 790, 13, 16));
expect(tradeBounds, const Rect.fromLTWH(184, 789, 19, 18));
expect(historyBounds, const Rect.fromLTWH(250, 789, 20, 18));
```

Use these search rectangles so labels and neighboring icons cannot enter the mask:

```dart
const iconSearchRects = <Rect>[
  Rect.fromLTWH(36, 780, 48, 30),
  Rect.fromLTWH(102, 780, 48, 30),
  Rect.fromLTWH(169, 780, 48, 30),
  Rect.fromLTWH(236, 780, 48, 30),
];
```

- [ ] **Step 4: Run the focused tests and verify RED**

Run:

```powershell
cd D:\mt5New\mobile
D:\toolchains\flutter\bin\flutter.bat test test/bottom_navigation_icon_parity_test.dart test/video_white_theme_parity_test.dart
```

Expected: FAIL on `#E6F2FC`, `#3C3C43`, the non-null divider border, and all four current visible-bound assertions.

- [ ] **Step 5: Commit the failing contracts**

```powershell
git add mobile/test/bottom_navigation_icon_parity_test.dart mobile/test/video_white_theme_parity_test.dart
git commit -m "test: lock bottom navigation icon reference"
```

---

### Task 2: Match navigation fill, ink, and outer border

**Files:**
- Modify: `mobile/lib/core/theme/app_colors.dart`
- Modify: `mobile/lib/shared/widgets/app_shell.dart`
- Test: `mobile/test/bottom_navigation_icon_parity_test.dart`
- Test: `mobile/test/video_white_theme_parity_test.dart`

**Interfaces:**
- Consumes: existing semantic navigation roles.
- Produces: neutral selected fill, reference unselected ink, exact white surface, and no dark capsule outline.

- [ ] **Step 1: Replace only the proven navigation tokens**

Use these exact values in `AppColors`:

```dart
static const navigationSurface = Color(0xFFFDFDFD);
static const navigationSelectedSurface = Color(0xFFE8E8E8);
static const navigationUnselected = Color(0xFF303030);
```

Keep `primary`, `positive`, `negative`, and `destructive` unchanged.

- [ ] **Step 2: Remove the unrelated divider border from the capsule**

Change the navigation `BoxDecoration` to:

```dart
decoration: BoxDecoration(
  color: AppColors.navigationSurface,
  borderRadius: BorderRadius.circular(31),
  boxShadow: AppShadows.card,
),
```

Do not change capsule width, height, padding, radius, shadow, or selected-pill bounds in this task.

- [ ] **Step 3: Run palette, theme, and shell behavior tests**

Run:

```powershell
cd D:\mt5New\mobile
D:\toolchains\flutter\bin\flutter.bat test test/bottom_navigation_icon_parity_test.dart test/video_white_theme_parity_test.dart test/video2_functional_regression_test.dart test/tab_swipe_reset_test.dart
```

Expected: palette/border assertions PASS; geometry assertions remain RED until Task 3; tab routing and reset tests PASS.

- [ ] **Step 4: Commit the palette checkpoint**

```powershell
git add mobile/lib/core/theme/app_colors.dart mobile/lib/shared/widgets/app_shell.dart mobile/test/bottom_navigation_icon_parity_test.dart mobile/test/video_white_theme_parity_test.dart
git commit -m "fix: match bottom navigation surfaces"
```

---

### Task 3: Match the four icon contours and vertical alignment

**Files:**
- Modify: `mobile/lib/shared/widgets/app_shell.dart:261-439`
- Test: `mobile/test/bottom_navigation_icon_parity_test.dart`

**Interfaces:**
- Consumes: `_MtNavIcon`, `_MtNavIconPainter`, and the existing icon keys.
- Produces: the same public widgets and hit targets with corrected visual transforms.

- [ ] **Step 1: Move the icon row to the measured video baseline**

Change the icon position without moving labels or tap targets:

```dart
Positioned(
  top: 12.7666666667,
  child: _MtNavIcon(kind, color: color),
),
```

This moves all four requested contours down 4 logical pixels, from current y=785/786 to video y=789/790.

- [ ] **Step 2: Apply measured per-icon transforms around the top center**

Replace the four transforms with these final raster-calibrated values. The
initial ratios were refined against the one-pixel visible-ink contract at the
canonical viewport:

```dart
return switch (kind) {
  _MtNavKind.quotes => Transform.translate(
    offset: const Offset(1, 0),
    child: Transform.scale(
      scaleX: .90,
      scaleY: .94,
      alignment: Alignment.topCenter,
      child: icon,
    ),
  ),
  _MtNavKind.chart => Transform.translate(
    offset: const Offset(.1666666667, 2),
    child: Transform.scale(
      scaleX: .93,
      scaleY: .83,
      alignment: Alignment.topCenter,
      child: icon,
    ),
  ),
  _MtNavKind.trade => Transform.translate(
    offset: const Offset(0, -.6666666667),
    child: Transform.scale(
      scaleX: 1.02,
      scaleY: 1.06,
      alignment: Alignment.topLeft,
      child: icon,
    ),
  ),
  _MtNavKind.history => Transform.translate(
    offset: const Offset(.5, .3333333333),
    child: Transform.scale(
      scaleX: 1,
      scaleY: .90,
      alignment: Alignment.topCenter,
      child: icon,
    ),
  ),
  _ => icon,
};
```

- [ ] **Step 3: Prove the existing painter paths need no topology change**

Keep every coordinate and stroke primitive inside `_MtNavIconPainter` unchanged. Run the visible-bound and contact-sheet tests after applying the transforms. Expected: all four measured bounds PASS; the two Quotes arrows remain disconnected, Chart keeps one filled and one outlined candle, Trade keeps its square/four-segment line, and History keeps its open counter-clockwise arc and two hands. Any failure at this checkpoint means the measured transform was applied around the wrong alignment and must be corrected in `_MtNavIcon`; do not compensate by changing the reference bounds.

- [ ] **Step 4: Verify blue, red, and unselected states**

Pump these five states and compare the same contour mask:

```text
selectedIndex=0, primary blue
selectedIndex=1, primary blue
selectedIndex=2, positive profit, primary blue
selectedIndex=2, negative profit, negative red
selectedIndex=3, primary blue
```

Expected: selected state changes only fill/ink color; it never changes contour bounds, stroke width, or position.

- [ ] **Step 5: Approve and generate the navigation golden**

Capture clean non-dimmed app frames at 384 x 848 and compare them with video frames at 0.0 s, 12.0 s, 20.0 s, and 36.0 s. After the bounds and contour acceptance rules pass, generate the golden:

```powershell
cd D:\mt5New\mobile
D:\toolchains\flutter\bin\flutter.bat test test/bottom_navigation_icon_parity_test.dart --update-goldens
D:\toolchains\flutter\bin\flutter.bat test test/bottom_navigation_icon_parity_test.dart
```

Expected: the second command PASSes without changing the golden.

- [ ] **Step 6: Commit the icon checkpoint**

```powershell
git add mobile/lib/shared/widgets/app_shell.dart mobile/test/bottom_navigation_icon_parity_test.dart mobile/test/goldens/navigation/quotes-384x848.png mobile/test/goldens/navigation/chart-384x848.png mobile/test/goldens/navigation/trade-384x848.png mobile/test/goldens/navigation/history-384x848.png
git commit -m "fix: match bottom navigation icon geometry"
```

---

### Task 4: Verify responsive layout and repository health

**Files:**
- Test: `mobile/test/bottom_navigation_icon_parity_test.dart`
- Create: `docs/screenshots/bottom-navigation-icon-parity/report.md`
- Create: clean 384 x 848 screenshots under `docs/screenshots/bottom-navigation-icon-parity/`

**Interfaces:**
- Consumes: completed color and icon calibration.
- Produces: reproducible visual evidence and full validation results.

- [ ] **Step 1: Run responsive widget coverage**

Pump the navigation at widths 360, 384, 393, and 430. Assert no Flutter overflow exception, all five semantics buttons remain present, and each tap invokes the original index.

- [ ] **Step 2: Capture the four requested clean states on LDPlayer**

Install the debug APK, set the emulator content viewport to 384 x 848 logical pixels, and capture `Gia`, `Bieu do`, `Giao dich`, and `Lich su` with no dialog or dim barrier. Record the APK commit, device scale, and video timestamp beside each screenshot in the report.

- [ ] **Step 3: Record the final visual comparison**

In `report.md`, include a table with video bounds, final app bounds, maximum contour displacement, masked differing-pixel percentage, surface/pill/ink values, and PASS/FAIL for each icon. A row may be marked PASS only when its visible bounds are exact and contour displacement is at most 1 physical pixel.

- [ ] **Step 4: Run required Flutter validation**

Run sequentially:

```powershell
cd D:\mt5New\mobile
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat test
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: analyzer exits 0, all tests PASS, and `build/app/outputs/flutter-apk/app-debug.apk` is produced.

- [ ] **Step 5: Run required backend validation**

Run:

```powershell
cd D:\mt5New\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: build and tests exit 0. No backend files should change.

- [ ] **Step 6: Review scope and commit the evidence**

Run:

```powershell
cd D:\mt5New
git diff --check
git status --short
git diff -- mobile/lib/core/theme/app_colors.dart mobile/lib/shared/widgets/app_shell.dart mobile/test/bottom_navigation_icon_parity_test.dart mobile/test/video_white_theme_parity_test.dart
```

Confirm the final diff contains no route, controller, repository, Chart renderer, order, account, or backend change, then commit:

```powershell
git add docs/screenshots/bottom-navigation-icon-parity mobile/lib/core/theme/app_colors.dart mobile/lib/shared/widgets/app_shell.dart mobile/test/bottom_navigation_icon_parity_test.dart mobile/test/video_white_theme_parity_test.dart mobile/test/goldens/navigation/quotes-384x848.png mobile/test/goldens/navigation/chart-384x848.png mobile/test/goldens/navigation/trade-384x848.png mobile/test/goldens/navigation/history-384x848.png
git commit -m "test: verify bottom navigation video parity"
```

## Self-Review

- Spec coverage: covers the four requested icons, selected/unselected colors, selected pill, icon/shell borders, runtime screenshots, responsive widths, and required verification.
- Scope: Settings icon remains unchanged except as a regression neighbor in the shared navigation; no unrelated screen or behavior is redesigned.
- Type consistency: all production changes remain within the existing `MtBottomNavigationBar`/`_MtNavIconPainter` interfaces.
- Placeholder scan: the plan contains exact measured bounds, starting transforms, acceptance thresholds, file paths, and commands.
