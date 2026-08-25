# Account Tab Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce the Settings account flow observable in `IMG_5526.MP4` while preserving EX V2 active-account scoping and API-backed business data.

**Architecture:** Keep `SettingsScreen` as the root, `ProfileScreen` as the server-scoped account list, and add a focused `AccountDetailScreen`. Route mutations through the existing Riverpod EX V2 controller and reuse current wallet routes.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Dio, Flutter widget tests.

## Global Constraints

- Do not change the required technology stack.
- Do not send or select `accountId` from the app.
- Do not hardcode financial/account values from the reference video.
- Keep web-admin account mapping authoritative.
- Run Flutter analyze, tests, debug build, and LDPlayer visual verification.

---

### Task 1: Lock the account-detail behavior with failing tests

**Files:**
- Modify: `mobile/test/settings_navigation_video_test.dart`
- Modify: `mobile/test/video2_functional_regression_test.dart`

**Interfaces:**
- Consumes: `SettingsScreen`, `ProfileScreen`, `activeDemoAccountProvider`.
- Produces: observable requirements for `/account-detail`, scroll rows, and wallet navigation.

- [ ] Add a widget test that selects the production account row and expects an account-detail screen instead of returning to Settings.
- [ ] Assert the detail contains company, deposit, withdrawal, login, server, access point, trade notifications, connect-device, password, and delete rows.
- [ ] Add route assertions for deposit and withdrawal actions.
- [ ] Run the focused tests and confirm they fail because `/account-detail` and its UI do not exist.

### Task 2: Add account-detail navigation and reference UI

**Files:**
- Create: `mobile/lib/features/profile/presentation/screens/account_detail_screen.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- Modify: `mobile/lib/app/router.dart`

**Interfaces:**
- Consumes: `DemoAccountProfile`, `activeDemoAccountProvider`, `exV2AccountProvider`.
- Produces: `AccountDetailScreen` and the `/account-detail` route.

- [ ] Add the minimal detail screen required by the failing test.
- [ ] Change the active production account row to push `/account-detail`.
- [ ] Register the route with the existing iOS transition helper.
- [ ] Run the focused tests and confirm the navigation/detail assertions pass.

### Task 3: Implement immediate settings behavior and all observed taps

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/account_detail_screen.dart`
- Test: `mobile/test/account_detail_screen_test.dart`

**Interfaces:**
- Consumes: `ExV2AccountController.updateSettings(JsonMap patch)`.
- Produces: immediate `tradeNotificationsEnabled` UI state and wallet navigation.

- [ ] Write a failing test that toggles trade notifications and observes an immediate visual change.
- [ ] Implement local immediate state initialized from EX V2 settings.
- [ ] Call the EX V2 settings mutation when server state is present and retain local behavior otherwise.
- [ ] Wire deposit and withdrawal rows to their existing routes.
- [ ] Make remaining rows hit-testable without sending unsupported destructive commands.
- [ ] Run focused tests and confirm they pass.

### Task 4: Match the reference geometry and copy

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/account_detail_screen.dart`
- Modify: `mobile/test/settings_navigation_video_test.dart`

**Interfaces:**
- Consumes: existing theme tokens and broker icon renderer.
- Produces: reference-matched Settings root, account list, and detail layouts.

- [ ] Correct Vietnamese copy and semantic labels.
- [ ] Match toolbar positions, row heights, separators, colors, radii, typography, and bounce scrolling against sampled video frames.
- [ ] Remove the unconditional production Demo ribbon and show it only from account state.
- [ ] Ensure long API values use the same single-line truncation seen in the reference.
- [ ] Run focused widget tests after each visual adjustment.

### Task 5: Regression and emulator acceptance

**Files:**
- Test: `mobile/test/settings_navigation_video_test.dart`
- Test: `mobile/test/account_detail_screen_test.dart`
- Test: `mobile/test/video2_functional_regression_test.dart`
- Test: `mobile/test/video2_cross_tab_test.dart`

**Interfaces:**
- Consumes: completed account flow.
- Produces: verified APK and visual evidence.

- [ ] Run `flutter analyze`.
- [ ] Run the focused Settings/Profile tests.
- [ ] Run the full `flutter test` suite.
- [ ] Run `flutter build apk --debug`.
- [ ] Install the APK on LDPlayer without clearing app storage.
- [ ] Capture Settings root, account list, detail top, and detail bottom screenshots.
- [ ] Compare with the 576x1280 reference after normalizing for device pixel ratio and fix any app-owned discrepancies.
