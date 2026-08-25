# Tab Typography and Spacing Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make typography, foreground colors, baselines, and text spacing in the seven supplied tab screenshots match the 590 x 1280 references without changing trading behavior.

**Architecture:** Bundle deterministic Roboto/Roboto Condensed assets, expose reference-visible text roles through `AppTypography`, and expose canonical row/baseline values through a focused tab metrics file. Migrate shared navigation and each covered tab independently under RED/GREEN tests, then lock the seven canonical states with reference manifests, goldens, masked comparison evidence, and responsive checks.

**Tech Stack:** Flutter 3.44+, Dart 3.12+, Riverpod, GoRouter, Flutter widget/golden tests, local TTF font assets, existing CustomPainter chart.

**Spec:** `docs/superpowers/specs/2026-08-25-tab-typography-spacing-parity-design.md`

## Global Constraints

- Keep Flutter, Dart, Riverpod, GoRouter, Dio, SignalR, secure storage, and the native CustomPainter chart.
- Do not change providers, repositories, API contracts, realtime flow, authentication, trading commands, routes, gestures, or fixture values merely to resemble a screenshot.
- Use the seven original files under `iconMau/anhmau`; canonical canvas is 590 x 1280 physical pixels, 393.333 x 853.333 logical pixels, DPR 1.5.
- Settings body and every route absent from the seven references remain unverified and out of scope.
- Preserve all owner changes already present in the dirty checkout. Stage only paths named by the active task.
- Follow RED/GREEN/REFACTOR: no production change before its focused test has failed for the intended reason.
- Dynamic prices, timestamps, P/L values, candle contours, and system status content may be masked; static text geometry and color may not.
- Do not edit `global.json` or change the required .NET SDK 8.0.421.

---

## File Structure

**Create**

- `mobile/assets/fonts/Roboto-Regular.ttf` — deterministic ordinary UI regular face.
- `mobile/assets/fonts/Roboto-Medium.ttf` — deterministic ordinary UI medium face.
- `mobile/assets/fonts/Roboto-Bold.ttf` — deterministic ordinary UI bold face.
- `mobile/assets/fonts/RobotoCondensed-Regular.ttf` — deterministic dense trading regular face.
- `mobile/assets/fonts/RobotoCondensed-Medium.ttf` — deterministic dense trading medium face.
- `mobile/assets/fonts/RobotoCondensed-Bold.ttf` — deterministic dense trading bold face.
- `mobile/assets/fonts/LICENSE.txt` — Apache 2.0 redistribution license shipped with the official Roboto v2.138 release.
- `mobile/lib/core/theme/tab_reference_metrics.dart` — canonical viewport, row, inset, and baseline metrics shared by covered tabs.
- `mobile/test/test_support/reference_font_loader.dart` — loads production font assets in widget/golden tests.
- `mobile/test/test_support/tab_reference_manifest.dart` — exact mapping from seven reference files to app states and dynamic masks.
- `mobile/test/tab_reference_manifest_test.dart` — reference dimensions, font asset, and manifest contract.
- `mobile/test/tab_typography_tokens_test.dart` — exact semantic typography and color contract.
- `mobile/test/tab_typography_golden_test.dart` — seven canonical candidate captures plus responsive overflow coverage.
- `mobile/tool/compare_tab_typography.dart` — masked static-region comparison and evidence report generator.
- `docs/screenshots/tab-typography-parity/README.md` — final candidate/reference comparison results and device-capture status.

**Modify**

- `mobile/pubspec.yaml` — register the two local font families and weights without disturbing current iOS/account work.
- `mobile/lib/core/theme/app_colors.dart` — calibrate shared covered-tab ink roles.
- `mobile/lib/core/theme/app_typography.dart` — add deterministic family names and semantic reference roles.
- `mobile/lib/core/theme/app_theme.dart` — use the deterministic ordinary family and navigation roles.
- `mobile/lib/shared/widgets/app_shell.dart` — migrate bottom-navigation labels and remove per-label scale/offset compensation.
- `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart` — migrate Prices styles and baseline metrics.
- `mobile/lib/features/chart/presentation/screens/chart_screen.dart` — migrate Chart widget text and anchors only.
- `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart` — migrate Chart painter text roles only.
- `mobile/lib/features/trade/presentation/screens/trade_screen.dart` — migrate Trade header, metrics, section, and position text.
- `mobile/lib/features/history/presentation/screens/history_screen.dart` — migrate shared header, positions, orders, deals, and summaries.
- `mobile/test/bottom_navigation_icon_parity_test.dart` — lock label geometry as well as icons.
- `mobile/test/market_watch_parity_test.dart` — lock semantic Prices styles and canonical baselines.
- `mobile/test/chart_geometry_test.dart` and `mobile/test/chart_controls_test.dart` — lock Chart text roles while preserving canvas geometry/interactions.
- `mobile/test/trade_position_bulk_actions_flow_test.dart` — lock Trade row styles without changing behavior assertions.
- `mobile/test/history_screen_detail_test.dart` — lock History roles without changing detail behavior.

---

### Task 1: Lock Reference Inputs and Bundle Deterministic Fonts

**Files:**

- Create: `mobile/test/test_support/tab_reference_manifest.dart`
- Create: `mobile/test/tab_reference_manifest_test.dart`
- Create: `mobile/assets/fonts/*`
- Create: `mobile/assets/fonts/LICENSE.txt`
- Modify: `mobile/pubspec.yaml`

**Interfaces:**

- Produces: `TabReferenceCase`, `tabReferenceCases`, `tabReferenceLogicalSize`, `tabReferenceDevicePixelRatio`.
- Produces: font families `Mt5Roboto` and `Mt5RobotoCondensed` with weights 400, 500, and 700.
- Consumes: seven JPEG files committed under `../iconMau/anhmau` when tests run from `mobile`.

- [ ] **Step 1: Write the failing reference/font contract test**

Create `mobile/test/tab_reference_manifest_test.dart`:

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'test_support/tab_reference_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seven canonical references are 590x1280 and map to unique states', () async {
    expect(tabReferenceCases, hasLength(7));
    expect(tabReferenceCases.map((item) => item.id).toSet(), hasLength(7));
    expect(tabReferenceLogicalSize.width, closeTo(393.3333333333, .0001));
    expect(tabReferenceLogicalSize.height, closeTo(853.3333333333, .0001));
    expect(tabReferenceDevicePixelRatio, 1.5);
    for (final item in tabReferenceCases) {
      final codec = await ui.instantiateImageCodec(
        await File(item.referencePath).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 590, reason: item.id);
      expect(frame.image.height, 1280, reason: item.id);
    }
  });

  test('production declares deterministic reference font assets', () {
    final yaml = File('pubspec.yaml').readAsStringSync();
    for (final token in <String>[
      'family: Mt5Roboto',
      'family: Mt5RobotoCondensed',
      'assets/fonts/Roboto-Regular.ttf',
      'assets/fonts/Roboto-Medium.ttf',
      'assets/fonts/Roboto-Bold.ttf',
      'assets/fonts/RobotoCondensed-Regular.ttf',
      'assets/fonts/RobotoCondensed-Medium.ttf',
      'assets/fonts/RobotoCondensed-Bold.ttf',
    ]) {
      expect(yaml, contains(token), reason: token);
    }
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
cd mobile
flutter test test/tab_reference_manifest_test.dart
```

Expected: FAIL because `tab_reference_manifest.dart` and the six font declarations do not exist.

- [ ] **Step 3: Add the exact manifest**

Create `mobile/test/test_support/tab_reference_manifest.dart`:

```dart
import 'dart:ui';

enum TabReferenceState {
  prices,
  chart,
  trade,
  historyPositions,
  historyOrders,
  historyOrdersSummary,
  historyDeals,
}

class TabReferenceCase {
  const TabReferenceCase({
    required this.id,
    required this.fileName,
    required this.state,
    this.dynamicMasks = const <Rect>[],
  });

  final String id;
  final String fileName;
  final TabReferenceState state;
  final List<Rect> dynamicMasks;

  String get referencePath => '../iconMau/anhmau/$fileName';
}

const tabReferenceLogicalSize = Size(393.3333333333, 853.3333333333);
const tabReferenceDevicePixelRatio = 1.5;

const tabReferenceCases = <TabReferenceCase>[
  TabReferenceCase(id: 'prices', fileName: 'photo_2026-08-25_22-30-10.jpg', state: TabReferenceState.prices),
  TabReferenceCase(id: 'chart', fileName: 'photo_2026-08-25_22-30-17.jpg', state: TabReferenceState.chart),
  TabReferenceCase(id: 'trade', fileName: 'photo_2026-08-25_22-30-20.jpg', state: TabReferenceState.trade),
  TabReferenceCase(id: 'history-positions', fileName: 'photo_2026-08-25_22-30-23.jpg', state: TabReferenceState.historyPositions),
  TabReferenceCase(id: 'history-orders', fileName: 'photo_2026-08-25_22-30-26.jpg', state: TabReferenceState.historyOrders),
  TabReferenceCase(id: 'history-orders-summary', fileName: 'photo_2026-08-25_22-30-29.jpg', state: TabReferenceState.historyOrdersSummary),
  TabReferenceCase(id: 'history-deals', fileName: 'photo_2026-08-25_22-30-34.jpg', state: TabReferenceState.historyDeals),
];
```

- [ ] **Step 4: Add licensed font assets and register all weights**

Use the official Google Fonts Roboto v2.138 `roboto-unhinted.zip` static TTF files and its Apache 2.0 license. Register them without changing existing asset entries:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/metatrader5_splash.png
  fonts:
    - family: Mt5Roboto
      fonts:
        - asset: assets/fonts/Roboto-Regular.ttf
          weight: 400
        - asset: assets/fonts/Roboto-Medium.ttf
          weight: 500
        - asset: assets/fonts/Roboto-Bold.ttf
          weight: 700
    - family: Mt5RobotoCondensed
      fonts:
        - asset: assets/fonts/RobotoCondensed-Regular.ttf
          weight: 400
        - asset: assets/fonts/RobotoCondensed-Medium.ttf
          weight: 500
        - asset: assets/fonts/RobotoCondensed-Bold.ttf
          weight: 700
```

Before staging, verify each file is a TrueType font and the license is present:

```bash
file assets/fonts/*.ttf
shasum -a 256 assets/fonts/*.ttf
test -s assets/fonts/LICENSE.txt
```

- [ ] **Step 5: Run GREEN verification and commit only Task 1 paths**

Run:

```bash
flutter pub get
flutter test test/tab_reference_manifest_test.dart
git diff --check -- pubspec.yaml test/tab_reference_manifest_test.dart test/test_support/tab_reference_manifest.dart
```

Expected: PASS. Commit:

```bash
git add pubspec.yaml assets/fonts test/tab_reference_manifest_test.dart test/test_support/tab_reference_manifest.dart
git commit -m "test: lock tab typography references and fonts"
```

---

### Task 2: Introduce Semantic Typography, Ink, and Geometry Tokens

**Files:**

- Create: `mobile/lib/core/theme/tab_reference_metrics.dart`
- Create: `mobile/test/tab_typography_tokens_test.dart`
- Modify: `mobile/lib/core/theme/app_colors.dart`
- Modify: `mobile/lib/core/theme/app_typography.dart`
- Modify: `mobile/lib/core/theme/app_theme.dart`

**Interfaces:**

- Produces: `AppTypography.plainFamily`, `condensedFamily`, and every role named in the spec.
- Produces: `TabReferenceMetrics` canonical sizes and baselines consumed by Tasks 3-7.
- Produces calibrated inks: primary `0xFF007FFF`, negative `0xFFE42D30`, primary text `0xFF111111`, secondary text `0xFF5C5C60`.

- [ ] **Step 1: Write the failing token test**

Create `mobile/test/tab_typography_tokens_test.dart` with direct style assertions:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';

void main() {
  test('covered tabs use deterministic measured ink and font roles', () {
    expect(AppColors.primary, const Color(0xFF007FFF));
    expect(AppColors.negative, const Color(0xFFE42D30));
    expect(AppColors.textPrimary, const Color(0xFF111111));
    expect(AppColors.textSecondary, const Color(0xFF5C5C60));
    expect(AppTypography.plainFamily, 'Mt5Roboto');
    expect(AppTypography.condensedFamily, 'Mt5RobotoCondensed');
    expect(AppTypography.navigationLabel.fontSize, 10.8);
    expect(AppTypography.navigationLabel.height, 1);
    expect(AppTypography.quoteSymbol.fontSize, 18);
    expect(AppTypography.quoteSymbol.fontWeight, FontWeight.w700);
    expect(AppTypography.quoteSymbol.letterSpacing, -.15);
    expect(AppTypography.quoteMeta.fontSize, 17);
    expect(AppTypography.quotePriceMajor.fontSize, 18.5);
    expect(AppTypography.quotePriceMinor.fontSize, 29);
    expect(AppTypography.tradeMetric.fontSize, 18.5);
    expect(AppTypography.tradePositionPrimary.fontSize, 17.3);
    expect(AppTypography.tradePositionSecondary.fontSize, 17.2);
    expect(AppTypography.tradePositionProfit.fontSize, 23.5);
    expect(AppTypography.historyPrimary.fontSize, 16);
    expect(AppTypography.historySecondary.fontSize, 14);
    expect(AppTypography.historySummary.fontSize, 15);
  });

  test('canonical tab geometry remains explicit', () {
    expect(TabReferenceMetrics.viewportWidth, closeTo(393.3333333333, .0001));
    expect(TabReferenceMetrics.quoteRowHeight, 78);
    expect(TabReferenceMetrics.tradeMetricRowHeight, 25);
    expect(TabReferenceMetrics.tradePositionRowHeight, 61.75);
    expect(TabReferenceMetrics.historyRowHeight, 52);
    expect(TabReferenceMetrics.historyPrimaryTop, 4);
    expect(TabReferenceMetrics.historySecondaryTop, 26);
  });
}
```

- [ ] **Step 2: Run RED**

Run `flutter test test/tab_typography_tokens_test.dart`.

Expected: FAIL because semantic roles and metrics do not exist and ink values still differ.

- [ ] **Step 3: Add minimal semantic styles and metrics**

Add these public family constants and semantic `TextStyle` values to `AppTypography`; retain the existing generic aliases temporarily so uncovered screens do not break in the same step:

```dart
static const plainFamily = 'Mt5Roboto';
static const condensedFamily = 'Mt5RobotoCondensed';

static const toolbarTitle = TextStyle(fontFamily: plainFamily, fontSize: 20.5, fontWeight: FontWeight.w500, height: 1);
static const toolbarControl = TextStyle(fontFamily: plainFamily, fontSize: 15.5, height: 1);
static const navigationLabel = TextStyle(
  fontFamily: plainFamily,
  fontSize: 10.8,
  fontWeight: FontWeight.w400,
  height: 1,
);
static const navigationLabelSelected = TextStyle(
  fontFamily: plainFamily,
  fontSize: 10.8,
  fontWeight: FontWeight.w500,
  height: 1,
);
static const quoteChange = TextStyle(fontFamily: condensedFamily, fontSize: 17, letterSpacing: .6, height: 1);
static const quoteSymbol = TextStyle(fontFamily: condensedFamily, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.15, height: 1);
static const quoteMeta = TextStyle(fontFamily: condensedFamily, fontSize: 17, height: 1);
static const quotePriceMajor = TextStyle(fontFamily: condensedFamily, fontSize: 18.5, fontWeight: FontWeight.w500, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
static const quotePriceMinor = TextStyle(fontFamily: condensedFamily, fontSize: 29, fontWeight: FontWeight.w700, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
static const chartToolbar = TextStyle(fontFamily: plainFamily, fontSize: 14.5, fontWeight: FontWeight.w500, height: 1);
static const chartTicketLabel = TextStyle(fontFamily: condensedFamily, fontSize: 9, height: 1);
static const chartTicketPriceMajor = TextStyle(fontFamily: condensedFamily, fontSize: 15, fontWeight: FontWeight.w700, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
static const chartTicketPriceMinor = TextStyle(fontFamily: condensedFamily, fontSize: 22, fontWeight: FontWeight.w700, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
static const chartAnnotation = TextStyle(fontFamily: plainFamily, fontSize: 14, fontWeight: FontWeight.w500, height: 1);
static const chartAxis = TextStyle(fontFamily: plainFamily, fontSize: 12.5, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
static const chartTimeAxis = TextStyle(fontFamily: plainFamily, fontSize: 11.5, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
static const tradeHeaderProfit = TextStyle(fontFamily: condensedFamily, fontSize: 21.5, fontWeight: FontWeight.w500, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
static const tradeMetric = TextStyle(fontFamily: condensedFamily, fontSize: 18.5, height: 1.15, fontFeatures: [FontFeature.tabularFigures()]);
static const tradeSection = TextStyle(fontFamily: condensedFamily, fontSize: 13.9, fontWeight: FontWeight.w700, height: 1);
static const tradePositionPrimary = TextStyle(fontFamily: condensedFamily, fontSize: 17.3, height: 1);
static const tradePositionSecondary = TextStyle(fontFamily: condensedFamily, fontSize: 17.2, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
static const tradePositionProfit = TextStyle(fontFamily: condensedFamily, fontSize: 23.5, fontWeight: FontWeight.w500, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
static const historySegment = TextStyle(fontFamily: plainFamily, fontSize: 15.5, height: 1);
static const historyPrimary = TextStyle(fontFamily: condensedFamily, fontSize: 16, height: 1);
static const historySecondary = TextStyle(fontFamily: condensedFamily, fontSize: 14, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
static const historySummary = TextStyle(fontFamily: plainFamily, fontSize: 15, fontWeight: FontWeight.w500, height: 1, fontFeatures: [FontFeature.tabularFigures()]);
```

Create `TabReferenceMetrics` using the values asserted above plus existing canonical header/list insets. Change `AppTheme.light.fontFamily` and its app-bar/navigation label families to `AppTypography.plainFamily`.

- [ ] **Step 4: Calibrate semantic inks and run GREEN**

Update only the semantic constants listed by the test. Keep `orderTicketSell`, candle colors, brand colors, and unrelated sheet/surface colors unchanged. Run:

```bash
flutter test test/tab_typography_tokens_test.dart test/app_light_theme_test.dart test/video_white_theme_parity_test.dart
flutter analyze
```

Expected: the new token test passes; any existing theme test whose old literal is intentionally replaced is updated to assert the new semantic role, not a duplicate literal.

- [ ] **Step 5: Commit Task 2**

```bash
git add lib/core/theme/app_colors.dart lib/core/theme/app_typography.dart lib/core/theme/app_theme.dart lib/core/theme/tab_reference_metrics.dart test/tab_typography_tokens_test.dart test/app_light_theme_test.dart test/video_white_theme_parity_test.dart
git commit -m "feat: add tab reference typography tokens"
```

---

### Task 3: Calibrate Shared Bottom-Navigation Labels

**Files:**

- Modify: `mobile/lib/shared/widgets/app_shell.dart:259-318`
- Modify: `mobile/test/bottom_navigation_icon_parity_test.dart`

**Interfaces:**

- Consumes: `AppTypography.navigationLabel`, `navigationLabelSelected`.
- Produces: keys `bottom-nav-label-quotes`, `bottom-nav-label-chart`, `bottom-nav-label-trade`, `bottom-nav-label-history`, `bottom-nav-label-settings`.

- [ ] **Step 1: Add failing label-style and no-shift tests**

Extend `bottom_navigation_icon_parity_test.dart`:

```dart
testWidgets('selection changes nav ink without changing label geometry', (tester) async {
  final rects = <int, Rect>{};
  for (var selected = 0; selected < 5; selected++) {
    await _pumpNavigation(tester, selectedIndex: selected, surfaceSize: const Size(393.3333333333, 853.3333333333));
    final label = find.byKey(const ValueKey('bottom-nav-label-quotes'));
    rects[selected] = tester.getRect(label);
    final text = tester.widget<Text>(label);
    expect(text.style?.fontFamily, AppTypography.plainFamily);
    expect(text.style?.fontSize, 10.8);
    expect(text.style?.height, 1);
  }
  expect(rects.values.toSet(), hasLength(1));
});
```

- [ ] **Step 2: Run RED**

Run `flutter test test/bottom_navigation_icon_parity_test.dart --plain-name 'selection changes nav ink without changing label geometry'`.

Expected: FAIL because labels have no keys and use per-item transforms/platform aliases.

- [ ] **Step 3: Migrate `_NavItem` minimally**

Import `AppTypography`, remove `baseLabelScaleX`, item-specific label translation, and label `Transform.scale`. Keep the existing icon geometry, capsule, pill, tap targets, and top coordinate. Use:

```dart
Text(
  label,
  key: ValueKey('bottom-nav-label-${kind.name}'),
  maxLines: 1,
  textAlign: TextAlign.center,
  style: (selected
          ? AppTypography.navigationLabelSelected
          : AppTypography.navigationLabel)
      .copyWith(color: color),
)
```

- [ ] **Step 4: Run focused and responsive GREEN tests**

```bash
flutter test test/bottom_navigation_icon_parity_test.dart test/video_white_theme_parity_test.dart
```

Expected: style/geometry/responsive tests pass. Regenerate only the four navigation goldens after inspecting the diff and confirming icon pixels did not move.

- [ ] **Step 5: Commit Task 3**

```bash
git add lib/shared/widgets/app_shell.dart test/bottom_navigation_icon_parity_test.dart test/goldens/navigation
git commit -m "fix: align bottom navigation typography"
```

---

### Task 4: Calibrate Prices Typography and Baselines

**Files:**

- Modify: `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart:119-151, 995-1232`
- Modify: `mobile/test/market_watch_parity_test.dart`

**Interfaces:**

- Consumes: quote roles from `AppTypography` and quote metrics from `TabReferenceMetrics`.
- Produces stable keys already present for change/time/bid/ask plus new keys `market-symbol-*`, `market-low-*`, `market-high-*`.

- [ ] **Step 1: Replace old-literal assertions with failing semantic/baseline assertions**

Keep existing behavior tests and add:

```dart
final symbolText = tester.widget<Text>(find.byKey(const ValueKey('market-symbol-XAUUSD+')));
expect(symbolText.style, AppTypography.quoteSymbol.copyWith(color: AppColors.textPrimary));
expect(tester.getTopLeft(find.byKey(const ValueKey('market-symbol-XAUUSD+'))).dy, closeTo(114.7111111111, .75));
final metaText = tester.widget<Text>(find.byKey(const ValueKey('market-time-XAUUSD+')));
expect(metaText.style?.fontFamily, AppTypography.condensedFamily);
expect(metaText.style?.color, AppColors.textSecondary);
final bid = tester.widget<Text>(find.byKey(const ValueKey('market-bid-XAUUSD+')));
final spans = (bid.textSpan! as TextSpan).children!.cast<TextSpan>();
expect(spans.first.style?.fontFamily, AppTypography.condensedFamily);
expect(spans.last.style?.fontSize, 29);
```

- [ ] **Step 2: Run RED**

Run `flutter test test/market_watch_parity_test.dart --plain-name 'header and split-price typography match the video geometry'`.

Expected: FAIL on family/key/geometry because Prices still uses platform aliases and compensating transforms.

- [ ] **Step 3: Migrate the Prices header and quote row**

Use `AppTypography.toolbarTitle`, `quoteChange`, `quoteSymbol`, `quoteMeta`, `quotePriceMajor`, and `quotePriceMinor`. Remove `scaleX/scaleY` around symbol, metadata, low/high, and split price when the bundled font produces the required width; retain `FittedBox(scaleDown)` only as overflow protection. Move row/header constants into `TabReferenceMetrics` and use keys for every measured role.

- [ ] **Step 4: Run Prices GREEN and regression tests**

```bash
flutter test test/market_watch_parity_test.dart test/tab_swipe_reset_test.dart test/market_chart_route_test.dart test/video_white_theme_parity_test.dart
flutter analyze
```

Expected: typography/geometry and existing swipe/menu/navigation behavior pass.

- [ ] **Step 5: Commit Task 4**

```bash
git add lib/features/market_watch/presentation/screens/market_watch_screen.dart test/market_watch_parity_test.dart
git commit -m "fix: match Prices typography and spacing"
```

---

### Task 5: Calibrate Chart Widget and Painter Text Without Moving the Plot

**Files:**

- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart:1900-2410, 3740-3880, 4020-4165`
- Modify: `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart:760-1010, 1400-1840`
- Modify: `mobile/test/chart_geometry_test.dart`
- Modify: `mobile/test/chart_controls_test.dart`

**Interfaces:**

- Consumes: Chart semantic roles from `AppTypography`; existing `ChartReferenceTheme` remains the color source for canvas-specific text.
- Preserves: `ChartGeometry`, hit targets, candle/axis boundaries, viewport, pan, zoom, and order callbacks.

- [ ] **Step 1: Add failing font-role and frozen-geometry tests**

Add widget assertions for toolbar timeframe, volume field, plot title/subtitle, and painter snapshot. Preserve the existing geometry assertions and add before/after sentinels:

```dart
expect(tester.getRect(find.byKey(const Key('chart-canvas'))), const Rect.fromLTWH(0, 120, 393.3333333333, 647.3333333333));
final volume = tester.widget<Text>(find.text('1').first);
expect(volume.style?.fontFamily, AppTypography.condensedFamily);
expect(volume.style?.fontSize, 16.5);
expect(chartPainter.referenceTextFamily, AppTypography.plainFamily);
```

Expose `referenceTextFamily` as a read-only field on `Mt5CandlePainter`; do not expose mutable painter state.

- [ ] **Step 2: Run RED**

Run:

```bash
flutter test test/chart_geometry_test.dart test/chart_controls_test.dart --plain-name 'reference typography'
```

Expected: FAIL because Chart widget/painter text still names `sans-serif`/implicit families.

- [ ] **Step 3: Migrate widget text roles**

Replace only reference-visible Chart `TextStyle` families, sizes, spacing, and anchor offsets. Use `AppTypography.chartToolbar`, `chartTicketLabel`, `chartTicketPriceMajor`, `chartTicketPriceMinor`, `chartAnnotation`, `chartAxis`, and `chartTimeAxis`; derive foreground color with `copyWith(color: _theme.foreground/tradeBlue)`. Do not touch candle values, plot sizes, gesture handlers, or provider reads.

- [ ] **Step 4: Migrate painter text and prove geometry remains green**

Update `_text` call styles to deterministic families and pass the appropriate semantic role to position/pending/axis/time labels. Run:

```bash
flutter test test/chart_geometry_test.dart test/chart_controls_test.dart test/chart_viewport_test.dart test/chart_price_viewport_test.dart test/chart_repaint_performance_test.dart test/chart_market_order_dispatch_regression_test.dart
```

Expected: focused text tests and all frozen chart behavior/geometry tests pass. Do not regenerate unrelated chart goldens in this task.

- [ ] **Step 5: Commit Task 5**

```bash
git add lib/features/chart/presentation/screens/chart_screen.dart lib/features/chart/presentation/rendering/mt5_candle_painter.dart test/chart_geometry_test.dart test/chart_controls_test.dart
git commit -m "fix: match Chart text rendering"
```

---

### Task 6: Calibrate Trade Header, Metrics, and Position Rows

**Files:**

- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart:830-915, 1082-1440`
- Modify: `mobile/test/trade_position_bulk_actions_flow_test.dart`
- Modify: `mobile/test/trade_add_order_ticket_reference_test.dart` only if shared token assertions require it.

**Interfaces:**

- Consumes: `tradeHeaderProfit`, `tradeMetric`, `tradeSection`, `tradePositionPrimary`, `tradePositionSecondary`, `tradePositionProfit` and Trade geometry metrics.
- Preserves: swipe/reveal, menus, modify/close routes, profit calculations, and list ordering.

- [ ] **Step 1: Add failing Trade role and geometry assertions**

Add keys to the intended API in the test before production:

```dart
final metric = tester.widget<Text>(find.byKey(const ValueKey('trade-metric-label-Số dư:')));
expect(metric.style?.fontFamily, AppTypography.condensedFamily);
expect(metric.style?.fontSize, 18.5);
final primary = tester.widget<Text>(find.byKey(ValueKey('trade-position-primary-${position.id}')));
expect(primary.style?.fontSize, 17.3);
expect(primary.style?.height, 1);
final secondaryRect = tester.getRect(find.byKey(ValueKey('trade-position-secondary-${position.id}')));
expect(secondaryRect.top, closeTo(primaryRect.top + 25.3666666667, .75));
```

- [ ] **Step 2: Run RED**

Run `flutter test test/trade_position_bulk_actions_flow_test.dart`.

Expected: FAIL because keys and deterministic font roles are absent.

- [ ] **Step 3: Migrate Trade text and remove compensating scales**

Use semantic styles on the header profit, account labels/values, section label, position primary/secondary/profit. Replace `_tradeNegative` with `AppColors.negative`. Remove `Transform.scale` around text after applying bundled font; keep non-text icon transforms and overflow-only `FittedBox`. Use metrics constants for row heights and top offsets.

- [ ] **Step 4: Run Trade GREEN and behavior regression**

```bash
flutter test test/trade_position_bulk_actions_flow_test.dart test/trade_position_bulk_actions_dialog_test.dart test/trade_add_order_ticket_reference_test.dart test/video2_cross_tab_test.dart
flutter analyze
```

Expected: role/geometry assertions and all existing Trade actions pass.

- [ ] **Step 5: Commit Task 6**

```bash
git add lib/features/trade/presentation/screens/trade_screen.dart test/trade_position_bulk_actions_flow_test.dart test/trade_add_order_ticket_reference_test.dart
git commit -m "fix: match Trade typography and row spacing"
```

---

### Task 7: Calibrate All Three History Modes and Summaries

**Files:**

- Modify: `mobile/lib/features/history/presentation/screens/history_screen.dart:1-30, 740-860, 1000-1535`
- Modify: `mobile/test/history_screen_detail_test.dart`
- Modify: `mobile/test/history_screen_performance_test.dart`

**Interfaces:**

- Consumes: `historySegment`, `historyPrimary`, `historySecondary`, `historySummary` plus History metrics.
- Produces role keys for each row: `history-*-primary-*`, `history-*-secondary-*`, `history-*-trailing-primary-*`, `history-*-trailing-secondary-*`.
- Preserves: tab switching, filters, period sheet, bottom anchor, lazy builders, detail sheets, and ordering.

- [ ] **Step 1: Add failing shared-role tests across positions/orders/deals**

Pump each tab and assert the same pair of styles and baselines:

```dart
for (final tab in <String>['positions', 'orders', 'deals']) {
  final primary = tester.widget<Text>(find.byKey(ValueKey('history-$tab-primary-0')));
  final secondary = tester.widget<Text>(find.byKey(ValueKey('history-$tab-secondary-0')));
  expect(primary.style?.fontFamily, AppTypography.condensedFamily, reason: tab);
  expect(primary.style?.fontSize, 16, reason: tab);
  expect(secondary.style?.fontSize, 14, reason: tab);
  expect(secondary.style?.color, AppColors.textSecondary, reason: tab);
}
final summary = tester.widget<Text>(find.byKey(const ValueKey('history-summary-label-Tien nap')));
expect(summary.style?.fontFamily, AppTypography.plainFamily);
expect(summary.style?.fontSize, 15);
```

- [ ] **Step 2: Run RED**

Run:

```bash
flutter test test/history_screen_detail_test.dart test/history_screen_performance_test.dart --plain-name 'reference typography'
```

Expected: FAIL because History uses private numeric constants, platform aliases, and text transforms.

- [ ] **Step 3: Migrate header, rows, and summaries**

Replace `_history*FontSize` with semantic styles; replace row/header numeric geometry with `TabReferenceMetrics`; remove text-only scales/translations that merely compensated for platform font widths. Preserve the overlay gradient, scrollbar, item extent builders, controllers, and exact data mapping. Add the role keys named above.

- [ ] **Step 4: Run History GREEN and performance/behavior checks**

```bash
flutter test test/history_screen_detail_test.dart test/history_screen_performance_test.dart test/history_fixture_video2_test.dart test/video_button_coverage_test.dart test/video2_cross_tab_test.dart
flutter analyze
```

Expected: all three mode styles, summaries, detail behavior, lazy building, and bottom anchoring pass.

- [ ] **Step 5: Commit Task 7**

```bash
git add lib/features/history/presentation/screens/history_screen.dart test/history_screen_detail_test.dart test/history_screen_performance_test.dart
git commit -m "fix: match History typography and spacing"
```

---

### Task 8: Lock Seven Canonical Captures and Responsive Behavior

**Files:**

- Create: `mobile/test/test_support/reference_font_loader.dart`
- Create: `mobile/test/tab_typography_golden_test.dart`
- Create: `mobile/test/goldens/tab-typography/*.png`
- Create: `mobile/tool/compare_tab_typography.dart`
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`

**Interfaces:**

- Consumes: `tabReferenceCases`, production font assets, existing deterministic video fixtures.
- Produces: seven 590 x 1280 candidate PNGs and a comparison command whose exit code is non-zero when an unmasked static text region exceeds tolerance.

- [ ] **Step 1: Add failing canonical golden harness**

The harness must set `surfaceSize = tabReferenceLogicalSize`, DPR 1.5, top padding 24 logical pixels, load both production font families, and pump the exact state. Start with Prices and assert the physical output size before adding the remaining six cases:

```dart
testWidgets('prices typography matches the canonical candidate', (tester) async {
  await loadReferenceFonts();
  await tester.binding.setSurfaceSize(tabReferenceLogicalSize);
  tester.view.devicePixelRatio = tabReferenceDevicePixelRatio;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpTabReference(tester, TabReferenceState.prices);
  await expectLater(
    find.byKey(const Key('tab-reference-root')),
    matchesGoldenFile('goldens/tab-typography/prices-590x1280.png'),
  );
});
```

- [ ] **Step 2: Run RED**

Run `flutter test test/tab_typography_golden_test.dart`.

Expected: FAIL because the font loader, reference pump, and approved candidates do not exist.

- [ ] **Step 3: Complete all seven deterministic states and responsive tests**

Use the existing `video_reference_fixtures.dart`; do not alter production providers. For History, tap keys `history-tab-0/1/2` and scroll the orders-summary case to `maxScrollExtent`. Add a no-overflow loop at widths 360, 384, 393.333, and 430 for Prices, Trade, and all History modes. Chart uses its existing responsive/geometry tests plus the canonical capture.

- [ ] **Step 4: Implement masked static-text comparison**

Extend each manifest case with named physical-pixel `staticTextRegions` and `dynamicMasks`. Static regions are limited to header/segment labels, symbols and side words, section/summary labels, Chart Sell/Buy labels, and navigation labels. Dynamic masks are limited to system status content, changing numeric/timestamp glyph interiors, P/L values, and the candle plot. `compare_tab_typography.dart` decodes each reference/candidate pair, applies only those manifest masks, and reports each named static text region:

```text
case, region, referenceBounds, candidateBounds, maxEdgeDelta, medianInkDelta
```

Exit 1 if a static text bounding edge differs by more than 1 physical pixel or median interior RGB differs by more than 6 per channel. Non-text regions are not used to fail this typography task. Run:

```bash
flutter test --update-goldens test/tab_typography_golden_test.dart
dart run tool/compare_tab_typography.dart
flutter test test/tab_typography_golden_test.dart
```

- [ ] **Step 5: Inspect candidates and commit Task 8**

Open all seven candidate PNGs, compare them with the seven JPEGs, and correct production tokens rather than editing expected images by hand. After the comparator and goldens pass:

```bash
git add test/test_support/reference_font_loader.dart test/test_support/tab_reference_manifest.dart test/tab_typography_golden_test.dart test/goldens/tab-typography tool/compare_tab_typography.dart
git commit -m "test: lock tab typography goldens"
```

---

### Task 9: Device Verification, Full Validation, and Evidence Report

**Files:**

- Create: `docs/screenshots/tab-typography-parity/README.md`
- Create when an emulator is available: `docs/screenshots/tab-typography-parity/*.png`

**Interfaces:**

- Consumes: final debug APK and seven reference/candidate pairs.
- Produces: final evidence report with exact command outcomes, remaining baseline failures, masks, and unverified screens.

- [ ] **Step 1: Run fresh focused parity verification**

```bash
cd mobile
flutter test test/tab_reference_manifest_test.dart test/tab_typography_tokens_test.dart test/bottom_navigation_icon_parity_test.dart test/market_watch_parity_test.dart test/chart_geometry_test.dart test/chart_controls_test.dart test/trade_position_bulk_actions_flow_test.dart test/history_screen_detail_test.dart test/history_screen_performance_test.dart test/tab_typography_golden_test.dart
dart run tool/compare_tab_typography.dart
```

Expected: all focused parity tests and the masked comparator pass.

- [ ] **Step 2: Run complete mobile verification independently**

Run each command separately so one failure does not skip later checks:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Record test counts and every failing test. Do not regenerate unrelated goldens to hide regressions.

- [ ] **Step 3: Run backend verification without changing SDK policy**

```bash
cd ../backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

If SDK 8.0.421 remains absent, record the exact SDK-resolution error and continue with mobile/device evidence.

- [ ] **Step 4: Capture real emulator evidence when a device is available**

Install `mobile/build/app/outputs/flutter-apk/app-debug.apk`, launch the normal app, navigate through Prices, Chart, Trade, History positions/orders/deals and the shared Settings nav item, and save screenshots under `docs/screenshots/tab-typography-parity/`. If `adb devices -l` is empty, state `Device capture blocked: no emulator connected` in the report; do not fabricate captures.

- [ ] **Step 5: Write the report, verify scoped diff, and commit evidence**

The report must contain:

```markdown
# Tab Typography Parity Evidence

## References
Seven source JPEGs at 590 x 1280.

## Static acceptance
- Font families and weights
- Text sizes and line heights
- Letter spacing and baselines
- Primary, secondary, buy, and sell ink
- Per-case comparator result

## Dynamic masks
Exact masked rectangles and reasons.

## Responsive checks
360, 384, 393.333, and 430 logical pixels.

## Verification
Fresh analyze, focused tests, full tests, APK build, backend build/test results.

## Reference gaps
Settings body and routes absent from the seven screenshots remain unverified.
```

Run:

```bash
git status --short
git diff --check
git diff --stat 5fcee45..HEAD
```

Confirm unrelated account-sync/iOS files are not staged. Commit only evidence:

```bash
git add docs/screenshots/tab-typography-parity
git commit -m "docs: record tab typography parity evidence"
```

---

## Plan Self-Review

- Spec coverage: font determinism, semantic roles, Prices, Chart, Trade, three History modes, shared navigation, seven captures, responsive widths, device evidence, and missing-reference reporting each have a dedicated task.
- Safety: every production task starts with a focused failing test and stages explicit paths only; business data and owner work are excluded.
- Type consistency: all later tasks consume `AppTypography`, `TabReferenceMetrics`, `TabReferenceCase`, `TabReferenceState`, `tabReferenceCases`, `tabReferenceLogicalSize`, and `tabReferenceDevicePixelRatio` exactly as defined in Tasks 1-2.
- Completeness scan: no placeholder, deferred implementation instruction, or unnamed error-handling step remains.
