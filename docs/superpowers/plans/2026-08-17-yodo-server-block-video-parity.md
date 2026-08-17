# YODO Server Block Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the YODO account-link server header, selected-server block, names, and list typography to the reference video without changing live API identifiers.

**Architecture:** A scoped reference presentation profile supplies visual labels for `yodo-demo`; the domain objects and callbacks retain live identities. Shared theme and mark primitives provide the exact visual treatment without changing global typography.

**Tech Stack:** Flutter, Dart, Riverpod widget tests, Android debug APK, LDPlayer.

## Global Constraints

- Real requests continue to use broker ID `yodo-demo` and server ID `yodo-demo-01`.
- The reference presentation is enabled only for broker ID `yodo-demo`.
- No password, device token, authorization header, request body, or reconnect grant may be logged.
- Existing unrelated worktree changes must remain untouched.

---

### Task 1: Lock the reference presentation with failing widget tests

**Files:**
- Modify: `mobile/test/account_link_catalog_video_test.dart`

**Interfaces:**
- Consumes: `ExistingAccountLoginScreen`, `TradingServerScreen`, `_LiveCatalogRepository`.
- Produces: regression assertions for title, mark, typography, 56-point server row, and live server ID preservation.

- [ ] Add a widget test that pumps the YODO form and expects `Exness Technologies Ltd`, lowercase `exness`, no visible `YODO Demo Markets`, regular-width reference typography, and a 56-point selected-server block.
- [ ] Extend the catalog test to expect the same reference typography while retaining the existing `yodo-demo-01` callback assertion.
- [ ] Run `flutter test test/account_link_catalog_video_test.dart` and confirm the new assertions fail because the current header and typography are not the reference presentation.

### Task 2: Implement the scoped presentation profile

**Files:**
- Modify: `mobile/lib/core/theme/app_typography.dart`
- Modify: `mobile/lib/features/account_link/presentation/widgets/reference_server_catalog.dart`
- Modify: `mobile/lib/features/account_link/presentation/widgets/account_link_visuals.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart`

**Interfaces:**
- Produces: `usesReferenceServerPresentation(String)`, `referenceServerBrokerDisplayName`, `AppTypography.referenceServerName`, and `AccountLinkBrokerMark(displayAsExness: true)`.

- [ ] Add the scoped profile constants/helper and semantic typography token.
- [ ] Add the presentation-only Exness mark override with lowercase `exness` lettering.
- [ ] Apply the profile to the form header, selected-server value, and YODO server list rows.
- [ ] Run the focused widget test and confirm it passes without changing selected broker/server IDs.

### Task 3: Verify and deploy to the emulator

**Files:**
- No additional production files.

**Interfaces:**
- Consumes: the completed Flutter implementation.
- Produces: test, analysis, build, installed-APK, and screenshot evidence.

- [ ] Run `flutter analyze`.
- [ ] Run `flutter test` and record the pass/fail count.
- [ ] Run `flutter build apk --debug`.
- [ ] Run the backend build and relevant backend tests required by the repository instructions.
- [ ] Install the new APK on `emulator-5558`, open the YODO account form and server catalog, and capture screenshots for comparison with the reference video.
- [ ] Scan changed files/artifacts for forbidden secret logging patterns and report the result.
