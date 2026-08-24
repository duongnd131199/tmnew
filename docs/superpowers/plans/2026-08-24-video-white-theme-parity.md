# Video White Theme Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the Flutter app from its dark presentation to the white presentation in `giaoDienMau/giaodientrang.MP4` without changing behavior, layout, data, routes, gestures, or trading semantics.

**Architecture:** Replace the dark-first neutral palette with one semantic light palette, make the production Material theme and Android system chrome light, then remove hard-coded dark neutrals screen by screen. Preserve the current widget tree and Chart geometry; use focused tests and masked emulator/video comparison to calibrate only theme-sensitive pixels.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, GoRouter, Material 3, Flutter widget/golden tests, OpenCV reference-frame extraction, LDPlayer/ADB, ASP.NET Core 8 verification.

**Spec:** `docs/superpowers/specs/2026-08-24-video-white-theme-parity-design.md`

## Global Constraints

- Read `META_TRADER_CLONE_GUIDE.md`, `README.md`, `docs/architecture.md`, and `docs/design-system.md` before implementation.
- Keep Flutter, Dart, Riverpod, GoRouter, Dio, SignalR, secure storage, ASP.NET Core, and the native CustomPainter Chart.
- Do not modify providers, controllers, repositories, API clients, backend behavior, routes, market values, account data, order behavior, or realtime behavior.
- Do not change size, spacing, alignment, typography metrics, copy, icon geometry, safe areas, widget hierarchy, gestures, scrolling, or animation timing.
- Freeze Chart painter geometry, viewport mathematics, hit targets, and market-data flow; only shell/theme integration may change.
- Treat `giaoDienMau/giaodientrang.MP4` as the canonical white-theme source at 384 x 848 pixels and 30 fps.
- Claim exact reference parity only for video-visible scenes. Apply the light baseline to other routes and list them as unverified.
- Preserve all owner changes in the dirty checkout. Do not reset, checkout, stash, stage broadly, or run a repository-wide formatter.
- Several target production/test files already contain owner changes. Use scoped diffs and test checkpoints; do not commit implementation files whose pre-task state cannot be isolated safely.
- Write a failing focused test before each production change and observe the intended failure.
- After each task, run its focused tests, `flutter analyze`, and `flutter build apk --debug` when the task crosses an app-wide theme boundary.
- Final verification must run full Flutter analyze/test/build and backend build/test from the final tree.

---

## File Structure

### New files

- `mobile/test/app_light_theme_test.dart` — exact semantic palette, Material theme, and system-overlay contract.
- `mobile/test/video_white_theme_source_policy_test.dart` — rejects unexplained dark neutral literals in production theme surfaces.
- `mobile/test/video_white_theme_parity_test.dart` — focused widget/color/overlay/responsive contracts for video-visible scenes.
- `reference/screens/theme-light/manifest.json` — video timestamps, scene names, verification status, and dynamic-pixel exclusions.
- `docs/screens/white-theme.md` — final palette, screen-by-screen evidence, residual differences, and missing-reference report.

### Existing files expected to change

- `mobile/lib/core/theme/app_colors.dart` — semantic light palette.
- `mobile/lib/core/theme/app_theme.dart` — production light Material theme and system overlay style.
- `mobile/lib/core/theme/app_shadows.dart` — video-matched light-surface shadows.
- `mobile/lib/app/app.dart` — select `AppTheme.light`.
- `mobile/lib/app/bootstrap.dart` — apply light Android system chrome.
- `mobile/lib/features/account_sync/presentation/device_gate.dart` — use the same light theme in nested apps.
- `mobile/lib/shared/widgets/app_shell.dart` — white floating bottom navigation and light selected/unselected roles.
- `mobile/lib/shared/widgets/trading_drawer.dart` — replace dark neutral leakage with semantic roles.
- `mobile/lib/shared/widgets/mt5_settings_icons.dart` — replace neutral white/black painter literals only; retain brand colors.
- `mobile/lib/shared/widgets/mt5_toolbar_icons.dart` — replace neutral painter literals only.
- `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart` — Prices and symbol sheet colors.
- `mobile/lib/features/trade/presentation/screens/trade_screen.dart` — Trade surfaces and position sheets.
- `mobile/lib/features/history/presentation/screens/history_screen.dart` — History surfaces, tabs, totals, and sheets.
- `mobile/lib/features/profile/presentation/screens/settings_screen.dart` — grouped Settings background/cards/rows.
- `mobile/lib/features/profile/presentation/screens/profile_screen.dart` — account-list background and selection.
- `mobile/lib/features/account_link/presentation/screens/broker_list_screen.dart` — add-account catalog light surfaces.
- `mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart` — form rows, switch, and disabled state.
- `mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart` — server-list surfaces and selection.
- `mobile/lib/features/account_link/presentation/widgets/account_link_toolbar.dart` — common light toolbar.
- `mobile/lib/features/account_link/presentation/widgets/account_link_visuals.dart` — common account card/symbol neutral roles.
- Existing focused tests that instantiate `AppTheme.dark` or assert dark values — mechanically update to `AppTheme.light` without changing behavioral expectations.

### Existing files audited but not changed unless a test proves dark leakage

- `mobile/lib/features/chart/**` — Chart is already light and geometrically frozen.
- Unverified routes under authentication, wallet, notifications, messages, order, and detail screens — inherit the global palette; change local literals only when they create an obvious dark surface.

---

### Task 1: Lock video evidence and the semantic palette contract

**Files:**
- Create: `reference/screens/theme-light/manifest.json`
- Create: `mobile/test/app_light_theme_test.dart`
- Test: `mobile/test/app_light_theme_test.dart`

**Interfaces:**
- Consumes: `giaoDienMau/giaodientrang.MP4` at 384 x 848, 30 fps, 79.6 seconds.
- Produces: exact `AppColors` role names and values consumed by all later tasks.
- Produces: `AppTheme.light` and `AppTheme.systemUiOverlayStyle` contracts implemented in Task 2.

- [ ] **Step 1: Create the reference manifest**

Create `reference/screens/theme-light/manifest.json` with this exact shape and scene inventory:

```json
{
  "source": "giaoDienMau/giaodientrang.MP4",
  "width": 384,
  "height": 848,
  "fps": 30,
  "durationSeconds": 79.6,
  "scenes": [
    {"id":"prices","seconds":0.0,"route":"/market","verified":false},
    {"id":"symbol-sheet","seconds":8.37,"route":"/market","verified":false},
    {"id":"chart","seconds":12.57,"route":"/chart?symbol=XAUUSD+&timeframe=M1","verified":false},
    {"id":"trade","seconds":20.93,"route":"/trade","verified":false},
    {"id":"position-sheet","seconds":25.13,"route":"/trade","verified":false},
    {"id":"bulk-position-sheet","seconds":29.30,"route":"/trade","verified":false},
    {"id":"history","seconds":37.70,"route":"/history","verified":false},
    {"id":"settings","seconds":41.87,"route":"/settings","verified":false},
    {"id":"accounts","seconds":46.07,"route":"/profile","verified":false},
    {"id":"existing-account","seconds":54.43,"route":"/accounts/add/yodo-demo","verified":false},
    {"id":"server-picker","seconds":58.63,"route":"/accounts/add/yodo-demo/servers","verified":false}
  ],
  "dynamicExclusions": [
    "status clock",
    "prices",
    "timestamps",
    "account values",
    "profit and loss",
    "candle contour",
    "countdown"
  ]
}
```

- [ ] **Step 2: Write the failing palette and theme test**

Create `mobile/test/app_light_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';

void main() {
  test('video light palette locks semantic neutral and financial roles', () {
    expect(AppColors.background, const Color(0xFFFDFDFD));
    expect(AppColors.groupedBackground, const Color(0xFFEEEDF5));
    expect(AppColors.surface, const Color(0xFFFDFDFD));
    expect(AppColors.surfaceElevated, const Color(0xFFF5F5F5));
    expect(AppColors.surfaceSelected, const Color(0xFFE4E4E4));
    expect(AppColors.sheetSurface, const Color(0xFFECECEC));
    expect(AppColors.disabledSurface, const Color(0xFFF1F1F1));
    expect(AppColors.primary, const Color(0xFF0A6CF1));
    expect(AppColors.negative, const Color(0xFFD83048));
    expect(AppColors.textPrimary, const Color(0xFF111111));
    expect(AppColors.textSecondary, const Color(0xFF66666B));
    expect(AppColors.textTertiary, const Color(0xFF9A9A9F));
    expect(AppColors.divider, const Color(0xFFD9D9DE));
  });

  test('production Material theme and Android chrome are light', () {
    final theme = AppTheme.light;
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.colorScheme.onSurface, AppColors.textPrimary);
    expect(theme.bottomSheetTheme.backgroundColor, AppColors.sheetSurface);
    expect(theme.dialogTheme.backgroundColor, AppColors.surface);
    expect(
      AppTheme.systemUiOverlayStyle.statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      AppTheme.systemUiOverlayStyle.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
    expect(
      AppTheme.systemUiOverlayStyle.statusBarColor,
      AppColors.background,
    );
  });
}
```

- [ ] **Step 3: Run the test and verify RED**

Run:

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/app_light_theme_test.dart
```

Expected: FAIL because the new light roles and `AppTheme.light` do not exist and current values are dark.

- [ ] **Step 4: Review the evidence checkpoint**

Run:

```powershell
cd ..
git diff --check -- reference/screens/theme-light/manifest.json mobile/test/app_light_theme_test.dart
git status --short -- reference/screens/theme-light/manifest.json mobile/test/app_light_theme_test.dart
```

Expected: only the manifest and RED test appear in this checkpoint.

---

### Task 2: Implement the central light theme and system chrome

**Files:**
- Modify: `mobile/lib/core/theme/app_colors.dart`
- Modify: `mobile/lib/core/theme/app_theme.dart`
- Modify: `mobile/lib/core/theme/app_shadows.dart`
- Modify: `mobile/lib/app/app.dart`
- Modify: `mobile/lib/app/bootstrap.dart`
- Modify: `mobile/lib/features/account_sync/presentation/device_gate.dart`
- Modify: tests containing `AppTheme.dark`
- Test: `mobile/test/app_light_theme_test.dart`
- Test: `mobile/test/device_gate_test.dart`

**Interfaces:**
- Consumes: palette contract from Task 1.
- Produces: `AppColors.groupedBackground`, `sheetSurface`, `disabledSurface`, `dimBarrier`, `navigationSurface`, `navigationSelectedSurface`, and `navigationUnselected`.
- Produces: `AppTheme.light` and `AppTheme.systemUiOverlayStyle` for root and nested `MaterialApp` instances.

- [ ] **Step 1: Replace the neutral palette with named light roles**

Keep existing brand roles and `transparent`, but change/add the neutral and interaction roles in `app_colors.dart`:

```dart
static const background = Color(0xFFFDFDFD);
static const groupedBackground = Color(0xFFEEEDF5);
static const surface = Color(0xFFFDFDFD);
static const accountSelectedSurface = Color(0xFFF4F4F4);
static const surfaceElevated = Color(0xFFF5F5F5);
static const surfaceSelected = Color(0xFFE4E4E4);
static const sheetSurface = Color(0xFFECECEC);
static const disabledSurface = Color(0xFFF1F1F1);
static const navigationSurface = Color(0xFFFDFDFD);
static const navigationSelectedSurface = Color(0xFFE6F2FC);
static const navigationUnselected = Color(0xFF3C3C43);
static const dimBarrier = Color(0x39000000);
static const primary = Color(0xFF0A6CF1);
static const primaryMuted = Color(0xFFDCEBFF);
static const positive = Color(0xFF0A6CF1);
static const negative = Color(0xFFD83048);
static const destructive = Color(0xFFD83048);
static const textPrimary = Color(0xFF111111);
static const textSecondary = Color(0xFF66666B);
static const textTertiary = Color(0xFF9A9A9F);
static const divider = Color(0xFFD9D9DE);
```

Do not change `chartUp`, `chartDown`, or Chart reference-theme colors in this step.

- [ ] **Step 2: Implement `AppTheme.light`**

Replace the dark scheme with `ColorScheme.light`, add component themes for sheets/dialogs/switches/disabled states, and expose system chrome:

```dart
static const systemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: AppColors.background,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: AppColors.background,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: AppColors.background,
);

static ThemeData get light {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.positive,
    surface: AppColors.surface,
    error: AppColors.negative,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimary,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'sans-serif-condensed',
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: scheme,
    textTheme: AppTypography.textTheme,
    dividerColor: AppColors.divider,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.sheetSurface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    // Preserve the existing typography, radius, navigation height, and input
    // geometry exactly; change only semantic colors.
  );
}
```

- [ ] **Step 3: Route every root/nested app through the light theme**

Change `TradingApp`, `DeviceGate`, and test harnesses from `AppTheme.dark` to `AppTheme.light`. In `bootstrap.dart`, replace the literal black `SystemUiOverlayStyle` with:

```dart
SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyle);
```

Do not change `ProviderScope`, provider overrides, `DeviceGate`, or router construction.

- [ ] **Step 4: Update light-surface shadows**

Change only shadow color/opacity in `AppShadows.card`; retain blur and offset unless a video comparison proves those metrics differ:

```dart
static const card = <BoxShadow>[
  BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 8)),
];
```

- [ ] **Step 5: Run the theme and gate tests**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/app_light_theme_test.dart test/device_gate_test.dart test/account_password_login_screen_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: PASS; root and device-gate screens use light system/theme roles without changing authentication behavior.

- [ ] **Step 6: Review the scoped checkpoint**

Run `git diff --check` and inspect only the files named in Task 2. Confirm no controller, repository, route, Chart painter, or backend file changed.

---

### Task 3: Match the shared app shell and bottom navigation

**Files:**
- Modify: `mobile/lib/shared/widgets/app_shell.dart`
- Modify: `mobile/lib/shared/widgets/trading_drawer.dart`
- Modify: `mobile/lib/shared/widgets/mt5_toolbar_icons.dart`
- Modify: `mobile/lib/shared/widgets/mt5_settings_icons.dart`
- Modify: `mobile/test/video2_functional_regression_test.dart`
- Modify: `mobile/test/tab_swipe_reset_test.dart`
- Create/Modify: `mobile/test/video_white_theme_parity_test.dart`

**Interfaces:**
- Consumes: light navigation/surface/text roles from Task 2.
- Produces: unchanged `MtBottomNavigationBar` public constructor and tab semantics with video-matched colors.
- Produces: shared light neutral painter roles used by Settings and account flows.

- [ ] **Step 1: Write failing bottom-navigation color assertions**

In `video_white_theme_parity_test.dart`, pump `MtBottomNavigationBar` at each selected index and assert:

```dart
expect(find.byType(MtBottomNavigationBar), findsOneWidget);
expect(
  tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any(
    (box) => box.decoration is BoxDecoration &&
      (box.decoration! as BoxDecoration).color == AppColors.navigationSurface,
  ),
  isTrue,
);
expect(find.text('Gia'), findsOneWidget);
expect(find.text('Bieu do'), findsOneWidget);
expect(find.text('Giao dich'), findsOneWidget);
expect(find.text('Lich su'), findsOneWidget);
expect(find.text('Cai dat'), findsOneWidget);
```

Also capture the selected and unselected icon painter colors by locating their `CustomPaint` widgets and assert `AppColors.primary` versus `AppColors.navigationUnselected`.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/video_white_theme_parity_test.dart --plain-name "bottom navigation uses video white roles"
```

Expected: FAIL because the shell still uses `#121212`, `#19191A`, white glyphs, and dark selected pills.

- [ ] **Step 3: Replace shell literals without changing geometry**

In `app_shell.dart` retain all `SizedBox`, `Padding`, `Positioned`, transforms, sizes, radii, labels, fade timing, and tab behavior. Replace only:

- outer dark colors with `AppColors.navigationSurface`;
- borders with `AppColors.divider`;
- selected pill with `AppColors.navigationSelectedSurface`;
- unselected icons/text from white to `AppColors.navigationUnselected`;
- selected blue with `AppColors.primary`;
- trade loss color with `AppColors.negative`;
- account-reset surface with `AppColors.background` as already named.

Add `AppShadows.card` to the floating navigation decoration only if the reference mask proves the shadow is visible; do not change its bounds.

- [ ] **Step 4: Replace shared neutral painter literals**

In shared toolbar/settings icon painters, replace only literal white/black/gray colors that represent theme foreground/background. Keep Telegram/MQL/brand fills and semantic red/green/yellow colors unchanged. Painter paths, sizes, stroke widths, and transforms must remain byte-for-byte unchanged.

- [ ] **Step 5: Run shell behavior and cross-tab regressions**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/video_white_theme_parity_test.dart test/video2_functional_regression_test.dart test/tab_swipe_reset_test.dart test/chart_market_warmup_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
```

Expected: PASS; tab taps, tab reset, account generation reset, Chart warmup, and selected labels are unchanged.

- [ ] **Step 6: Capture a shell checkpoint**

Build/install the debug APK and capture each bottom-tab selected state at 384 x 848. Compare only the bottom-navigation region against video timestamps 0.0, 12.57, 20.93, 37.70, and 41.87 seconds.

---

### Task 4: Match Prices and the symbol action sheet

**Files:**
- Modify: `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart`
- Modify if dark leakage is proven: `mobile/lib/features/market_watch/presentation/screens/symbol_search_screen.dart`
- Modify if dark leakage is proven: `mobile/lib/features/market_watch/presentation/screens/symbol_edit_screen.dart`
- Modify: `mobile/test/market_watch_parity_test.dart`
- Modify: `mobile/test/video_interactions_test.dart`
- Modify: `mobile/test/video_white_theme_parity_test.dart`

**Interfaces:**
- Consumes: shared light palette/sheet/barrier roles.
- Produces: unchanged Market Watch navigation callbacks and symbol action-sheet actions.

- [ ] **Step 1: Add failing Prices surface and sheet tests**

Extend `market_watch_parity_test.dart` to assert the Prices scaffold/background, primary/secondary text, and financial colors. Extend `video_white_theme_parity_test.dart` to open the existing symbol sheet and assert:

```dart
expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
    anyOf(isNull, AppColors.background));
await tester.tap(find.text('XAUUSD').first);
await tester.pumpAndSettle();
final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
expect(sheet.backgroundColor, AppColors.sheetSurface);
expect(find.text('Giao dich'), findsOneWidget);
expect(find.text('Bieu do'), findsOneWidget);
expect(find.text('Chi tiet'), findsOneWidget);
expect(find.text('Thong ke thi truong'), findsOneWidget);
expect(find.text('Depth of Market'), findsOneWidget);
expect(find.text('Huy'), findsOneWidget);
```

Use the app's actual Vietnamese strings/diacritics when they differ from the ASCII accessibility labels; do not change production copy to satisfy the test.

- [ ] **Step 2: Verify RED**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/market_watch_parity_test.dart test/video_white_theme_parity_test.dart --plain-name "Prices uses video white surfaces and sheet"
```

Expected: FAIL on remaining dark sheet/container/text literals.

- [ ] **Step 3: Replace only theme colors in Prices**

Map dark backgrounds, toolbar surfaces, row separators, sheet buttons, dim barrier, disabled states, and neutral icons to semantic tokens. Preserve:

- symbol row height and layout;
- bid/ask formatting and realtime selection granularity;
- red/blue price semantics;
- toolbar hit targets;
- action-sheet order, callbacks, and dismissal behavior;
- Chart and New Order navigation.

- [ ] **Step 4: Run Market Watch behavior regressions**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/market_watch_parity_test.dart test/video_interactions_test.dart test/market_chart_route_test.dart test/realtime_market_service_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
```

Expected: PASS with no change to quote updates or route behavior.

- [ ] **Step 5: Capture and compare both reference states**

Capture `/market` without overlay and with the XAUUSD action sheet. Compare against 0.0 and 8.37 seconds using masks for live price text and Android clock. Iterate semantic tokens first; use a screen-specific role only when the video proves a distinct surface.

---

### Task 5: Preserve Chart geometry while integrating the white shell

**Files:**
- Modify: `mobile/test/chart_light_theme_test.dart`
- Modify only if a failing integration test proves leakage: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Test: existing Chart suite and goldens

**Interfaces:**
- Consumes: `ChartReferenceTheme.light` and the Task 3 white shell.
- Produces: unchanged Chart render output inside the chart region.

- [ ] **Step 1: Update the obsolete host-theme assertion**

In `chart_light_theme_test.dart`, replace the test that expects `AppTheme.dark.brightness == Brightness.dark` with:

```dart
expect(AppTheme.light.brightness, Brightness.light);
expect(AppTheme.light.scaffoldBackgroundColor, AppColors.background);
expect(scaffoldMaterial.color, AppColors.background);
```

Do not alter tests that inject a deliberately hostile dark host theme; those prove Chart theme isolation.

- [ ] **Step 2: Run Chart integration and golden tests before production changes**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_light_theme_test.dart test/chart_light_parity_golden_test.dart test/chart_controls_test.dart test/chart_geometry_test.dart test/chart_price_viewport_test.dart
```

Expected: PASS after the host assertion update. If it passes, do not edit Chart production files.

- [ ] **Step 3: Fix only proven overlay leakage**

If a focused test fails because a Chart-owned overlay inherits an old global dark neutral, replace that neutral with the existing injected `ChartReferenceTheme` role. Do not change painter colors, candle geometry, grid cadence, axis labels, viewport values, or gesture routing.

- [ ] **Step 4: Run every Chart regression**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_controls_test.dart test/chart_light_theme_test.dart test/chart_light_parity_golden_test.dart test/chart_viewport_test.dart test/chart_price_viewport_test.dart test/chart_geometry_test.dart test/chart_timeframe_transition_test.dart test/chart_repaint_performance_test.dart test/market_chart_route_test.dart test/chart_market_order_dispatch_regression_test.dart
```

Expected: PASS with existing Chart goldens unchanged. Regenerating Chart goldens is forbidden unless visual inspection proves the only difference is the external shell captured by that golden.

- [ ] **Step 5: Capture Chart shell parity**

Capture XAUUSD+/M1 with the one-click strip visible and compare against 12.57 and 16.77 seconds. Mask live prices, countdown, labels containing prices, and candle contours; verify the surrounding shell/navigation is white and Chart geometry is unchanged.

---

### Task 6: Match Trade and position action sheets

**Files:**
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Modify if baseline leakage is proven: `mobile/lib/features/trade/presentation/screens/position_detail_screen.dart`
- Modify: `mobile/test/video2_cross_tab_test.dart`
- Modify: `mobile/test/video_interactions_test.dart`
- Modify: `mobile/test/video2_functional_regression_test.dart`
- Modify: `mobile/test/video_white_theme_parity_test.dart`

**Interfaces:**
- Consumes: theme/sheet/barrier roles.
- Produces: unchanged position taps, swipe behavior, close/modify/chart actions, bulk actions, and account metrics.

- [ ] **Step 1: Write failing Trade/sheet theme assertions**

Add tests for the Trade scaffold, account summary, position rows, and both overlays. Reuse existing fixture providers and interaction helpers. Assert sheet surface and destructive action color without asserting dynamic P/L:

```dart
expect(find.byType(TradeScreen), findsOneWidget);
expect(find.byKey(const Key('trade-account-metrics')), findsOneWidget);
expect(find.byKey(ValueKey('trade-position-surface-$positionId')), findsOneWidget);
// Open the position menu through the existing tested gesture.
expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
    AppColors.sheetSurface);
expect(
  tester.widget<Text>(find.text('Đóng trạng thái')).style?.color,
  AppColors.negative,
);
```

Use the actual production labels and keys found in `trade_screen.dart`; adding a `Key` for test discovery is allowed only when it does not wrap/reorder widgets or alter layout.

- [ ] **Step 2: Verify RED**

Run the two new focused test names. Expected: FAIL on existing `#151516`, `#101010`, white text, or dark sheet literals.

- [ ] **Step 3: Replace Trade neutral literals**

Change only background, surface, border, neutral text/icon, selected/disabled, sheet, and barrier colors. Preserve exact account metric positions, row transforms, swipe physics, action ordering, gesture thresholds, and controller calls. Positive Trade P/L remains blue as in the video; negative Trade P/L uses `AppColors.negative`.

- [ ] **Step 4: Run all Trade behavior regressions**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/video2_cross_tab_test.dart test/video_interactions_test.dart test/video2_functional_regression_test.dart test/tab_swipe_reset_test.dart test/ex_v2_trading_command_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
```

Expected: PASS; no order, position, account, or cross-tab behavior changes.

- [ ] **Step 5: Capture all three Trade reference states**

Capture base Trade, one position sheet, and bulk-position sheet. Compare against 20.93, 25.13, and 29.30 seconds with balance/equity/P&L/price values masked.

---

### Task 7: Match History surfaces and filters

**Files:**
- Modify: `mobile/lib/features/history/presentation/screens/history_screen.dart`
- Modify if baseline leakage is proven: `mobile/lib/features/history/presentation/screens/history_detail_screen.dart`
- Modify: `mobile/test/history_screen_detail_test.dart`
- Modify: `mobile/test/video_button_coverage_test.dart`
- Modify: `mobile/test/video_white_theme_parity_test.dart`

**Interfaces:**
- Consumes: background/surface/divider/selected/text roles.
- Produces: unchanged history filters, date/symbol dialogs, tab state, totals, row taps, and detail navigation.

- [ ] **Step 1: Add failing History theme assertions**

Pump the existing populated server fixture and assert background, top filter chrome, selected tab, neutral row text, positive/negative values, and modal surfaces. Do not assert exact deal amounts or dates.

- [ ] **Step 2: Verify RED**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/history_screen_detail_test.dart test/video_white_theme_parity_test.dart --plain-name "History uses video white roles"
```

Expected: FAIL on the remaining hard-coded `#151516` surface or dark overlay roles.

- [ ] **Step 3: Replace only History theme literals**

Map the dark container, tab selection, dialog background, dividers, secondary labels, and barrier to semantic roles. Keep all existing row heights, filters, scroll behavior, calculations, reconciliation, and navigation.

- [ ] **Step 4: Run History regressions**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/history_screen_detail_test.dart test/video_button_coverage_test.dart test/ex_v2_history_reconciler_test.dart test/video2_functional_regression_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
```

Expected: PASS.

- [ ] **Step 5: Capture History parity**

Capture the same selected history mode shown at 37.70 seconds. Mask dates, prices, counts, and totals; compare toolbar/tab/borders/surfaces/text roles and bottom navigation.

---

### Task 8: Match Settings, account list, add-account form, and server picker

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/broker_list_screen.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart`
- Modify: `mobile/lib/features/account_link/presentation/widgets/account_link_toolbar.dart`
- Modify: `mobile/lib/features/account_link/presentation/widgets/account_link_visuals.dart`
- Modify: `mobile/test/settings_navigation_video_test.dart`
- Modify: `mobile/test/account_link_catalog_video_test.dart`
- Modify: `mobile/test/account_link_login_video_test.dart`
- Modify: `mobile/test/new_account_video_geometry_test.dart`
- Modify: `mobile/test/multi_account_switch_test.dart`
- Modify: `mobile/test/video_white_theme_parity_test.dart`

**Interfaces:**
- Consumes: grouped background, white card, divider, switch, selected account, and toolbar roles.
- Produces: unchanged Settings navigation, account switch, catalog loading/search, server selection, credential validation, link, activate, and reconnect-grant behavior.

- [ ] **Step 1: Add failing Settings/account color tests**

Assert:

```dart
expect(find.byType(SettingsScreen), findsOneWidget);
expect(
  tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
  AppColors.groupedBackground,
);
expect(find.byType(ProfileScreen), findsOneWidget);
expect(find.byKey(const Key('accounts-add')), findsOneWidget);
```

For account link screens, assert toolbar/surface/input/switch colors in addition to the existing geometry and behavior expectations. Use current production keys such as `existing-account-login-screen`, `existing-account-login-field`, `existing-account-password-field`, and `existing-account-login-button`.

- [ ] **Step 2: Verify RED**

Run the focused new test names across `settings_navigation_video_test.dart`, `account_link_catalog_video_test.dart`, `account_link_login_video_test.dart`, and `video_white_theme_parity_test.dart`. Expected: FAIL on dark surfaces/text.

- [ ] **Step 3: Convert Settings and account-list neutrals**

Use `AppColors.groupedBackground` behind grouped cards, `AppColors.surface` for cards/rows, `AppColors.divider` between rows, and light selected/active roles. Keep every measured height, padding, transform, icon painter path, string, route, and callback unchanged.

- [ ] **Step 4: Convert add-account and server-picker neutrals**

Map toolbar, list, form row, hint, switch track, disabled button, search field, server selection, and error surfaces to semantic tokens. Retain broker/brand colors, credential security, password obscuring, request payloads, selected IDs, and controller behavior.

- [ ] **Step 5: Run Settings/account behavior regressions**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/settings_navigation_video_test.dart test/account_link_catalog_video_test.dart test/account_link_login_video_test.dart test/account_link_controller_test.dart test/new_account_video_geometry_test.dart test/multi_account_switch_test.dart test/account_link_cross_tab_video_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
```

Expected: PASS; geometry and account operations are unchanged.

- [ ] **Step 6: Capture five Settings/account reference states**

Capture Settings, account list, account form, server picker, and the return account list. Compare against 41.87, 46.07, 54.43, 58.63, and 62.80 seconds. Mask account names/numbers/balances and server rows whose live catalog differs.

---

### Task 9: Audit all routes for dark leakage and record unverified screens

**Files:**
- Create: `mobile/test/video_white_theme_source_policy_test.dart`
- Modify only when required by the test: unverified presentation files listed in the spec
- Modify: `docs/screens/white-theme.md`

**Interfaces:**
- Consumes: final semantic palette and route list.
- Produces: an explicit source-policy allowlist for brand/financial/drawing colors.
- Produces: the user-facing missing-reference report.

- [ ] **Step 1: Write the failing dark-neutral source-policy test**

Create `video_white_theme_source_policy_test.dart` using `dart:io`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production presentation has no unexplained dark neutral literals', () {
    final roots = <Directory>[
      Directory('lib/core/theme'),
      Directory('lib/features'),
      Directory('lib/shared/widgets'),
    ];
    final forbidden = RegExp(
      r'Color\(0xFF(?:000000|101010|111111|121212|151516|171719|19191A|1B1B1B|1C1C1E|2C2C2E|333333|373739|38383A)\)',
    );
    final allowlisted = <String>{
      'lib/core/theme/app_colors.dart',
      'lib/features/chart/presentation/theme/chart_reference_theme.dart',
    };
    final hits = <String>[];
    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (allowlisted.contains(path)) continue;
        for (final match in forbidden.allMatches(entity.readAsStringSync())) {
          hits.add('$path:${match.start}:${match.group(0)}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
```

The allowlist may contain only files where a dark literal is a verified brand,
financial, mask, or injected Chart-test color. Each added entry requires an
inline reason in the test.

- [ ] **Step 2: Run and verify RED**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/video_white_theme_source_policy_test.dart
```

Expected: FAIL with exact remaining production paths/literals.

- [ ] **Step 3: Classify and remove dark leakage**

For each hit:

- replace neutral surface/text/divider literals with an existing semantic role;
- retain brand/financial/drawing colors only with a narrow source-policy reason;
- do not change widgets, layout, callbacks, or business logic;
- do not claim unverified route parity.

- [ ] **Step 4: Write the screen report**

Create `docs/screens/white-theme.md` with:

- reference video metadata and accepted scene timestamps;
- final semantic palette table;
- one row per visible scene with capture path and comparison result;
- dynamic mask exclusions;
- residual differences and their evidence;
- the exact unverified route list from the spec;
- manual steps for the user to record each missing screen later;
- statement that functions/layout were preserved and which automated tests prove it.

- [ ] **Step 5: Run the policy and broad widget tests**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/video_white_theme_source_policy_test.dart test/video_white_theme_parity_test.dart test/video2_functional_regression_test.dart test/video_interactions_test.dart test/video_button_coverage_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
```

Expected: PASS.

---

### Task 10: Calibrate final video parity and complete repository verification

**Files:**
- Modify if measured evidence requires: semantic color files and video-covered presentation files from Tasks 2-8
- Modify: `reference/screens/theme-light/manifest.json`
- Modify: `docs/screens/white-theme.md`
- Produce: `.codex_tmp/white_theme_final/*.png`
- Produce: `mobile/build/app/outputs/flutter-apk/app-debug.apk`

**Interfaces:**
- Consumes: all focused green checkpoints and reference scene manifest.
- Produces: final verified APK, screenshots, and gap report.

- [ ] **Step 1: Run the complete focused light-theme suite**

Run:

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/app_light_theme_test.dart test/video_white_theme_source_policy_test.dart test/video_white_theme_parity_test.dart test/market_watch_parity_test.dart test/chart_light_theme_test.dart test/chart_light_parity_golden_test.dart test/video2_cross_tab_test.dart test/history_screen_detail_test.dart test/settings_navigation_video_test.dart test/account_link_catalog_video_test.dart test/account_link_login_video_test.dart test/new_account_video_geometry_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run the full Flutter requirements**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat test
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: analyzer reports no issues, all Flutter tests pass, and `app-debug.apk` is produced.

- [ ] **Step 3: Install and launch the final APK**

Discover the active development emulator rather than assuming an old serial:

```powershell
$adbPath = 'D:\LDPlayer\LDPlayer9\adb.exe'
$activeSerials = @(
  & $adbPath devices |
    Select-String '^\S+\s+device$' |
    ForEach-Object { ($_ -split '\s+')[0] }
)
$developmentSerial = @(
  $activeSerials | Where-Object {
    (& $adbPath -s $_ shell pm path com.tradingdemo.trading_mobile 2>$null) -match '^package:'
  }
)[0]
if (-not $developmentSerial) {
  throw 'No active LDPlayer with com.tradingdemo.trading_mobile is available.'
}
& $adbPath -s $developmentSerial install -r 'mobile\build\app\outputs\flutter-apk\app-debug.apk'
& $adbPath -s $developmentSerial shell monkey -p com.tradingdemo.trading_mobile 1
```

Use the serial actually returned by `adb devices`. Do not wait indefinitely on stale `127.0.0.1:5561`.

- [ ] **Step 4: Capture every reference-visible state**

Use `adb shell screencap -p` followed by `adb pull`; never redirect binary PNG output. Save captures under `.codex_tmp/white_theme_final/` with scene IDs matching the manifest. Navigate through the app using the same gestures and selected states as the video.

- [ ] **Step 5: Compare and calibrate one semantic variable at a time**

For each scene:

1. resize/align the development capture to the 384 x 848 reference canvas;
2. apply the documented dynamic mask;
3. inspect background, grouped background, cards, rows, dividers, text, selected states, sheets, barriers, and bottom navigation;
4. write or tighten a failing token/widget expectation before adjusting a value;
5. change one semantic token or one proven screen-specific theme role;
6. rerun the affected focused tests and recapture.

Do not move widgets or change typography/spacing to reduce a theme-only diff.

- [ ] **Step 6: Mark only evidenced manifest scenes verified**

Set `verified: true` and add `capturePath` for each accepted scene. If a state cannot be reached because the supplied account has different server data, keep it `verified: false`, record the exact limitation in `docs/screens/white-theme.md`, and do not fabricate data or mutate production state solely for a screenshot.

- [ ] **Step 7: Smoke every unverified route**

Open each unverified route available without unsafe financial mutations. Confirm no black shell/surface remains, no overflow occurs at 360-430 logical pixels, and existing back/retry/cancel actions work. Record each route as `light baseline — reference missing`, not `100% matched`.

- [ ] **Step 8: Run backend verification**

Run:

```powershell
cd ..\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: PASS; no backend file changed.

- [ ] **Step 9: Run fresh final verification after the last calibration edit**

Repeat Task 10 Steps 1, 2, and 8. Run:

```powershell
cd ..
git diff --check
git status --short
git diff --name-only
```

Confirm owner changes remain present, no provider/repository/API/backend behavior file was added to theme scope, and the APK timestamp is newer than the last source edit.

- [ ] **Step 10: Deliver the handoff**

Report:

- final APK path;
- final palette and changed files;
- focused/full Flutter and backend command results;
- emulator serial and capture paths;
- video-visible scenes verified;
- all screens/states missing reference evidence;
- any measurable residual caused by compressed video, platform rendering, or unavailable server state.

---

## Plan Self-Review

- Every approved video-visible scene maps to a focused migration task and final capture.
- Root theme, nested device-gate apps, system chrome, shared navigation, sheets, dialogs, and hard-coded dark leakage are covered.
- Chart production geometry is explicitly frozen and guarded by the complete existing Chart suite.
- Behavior is protected by existing Market Watch, Trade, History, account-link, cross-tab, realtime, and trading-command tests.
- Unverified screens receive a baseline and explicit report without an unsupported parity claim.
- No backend/API/data-flow change is required.
- Every production edit is preceded by a focused failing test and followed by targeted verification.
- Final completion includes build, analyze, all relevant tests, full tests, APK, emulator evidence, and missing-reference reporting.
