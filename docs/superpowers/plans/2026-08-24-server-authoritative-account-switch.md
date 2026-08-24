# Server-Authoritative Account Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make production account switching use only accounts returned by EX V2 and switch them with one server activation call without password or relink routing.

**Architecture:** Keep one authenticated device token from `/mobile/auth/login`. Build the production account catalog from `/mobile/accounts`, publish the active server bootstrap separately, and use the existing activation coordinator for atomic account changes. Local per-account sessions and cached linked-account rows no longer participate in production selection.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Dio, Flutter Secure Storage, ASP.NET Core verification commands.

**Spec:** `docs/superpowers/specs/2026-08-24-server-authoritative-account-switch-design.md`

## Global Constraints

- Do not change the required technology stack.
- Preserve the current account on every failed switch.
- Never route a switch failure to a password form.
- Never expose or log the device token or account password.
- Follow RED-GREEN-REFACTOR for every behavior change.
- Preserve unrelated dirty-worktree changes.

---

### Task 1: Make the Server Catalog Authoritative

**Files:**
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart`
- Modify: `mobile/test/multi_account_switch_test.dart`
- Modify: `mobile/test/ex_v2_account_provider_test.dart`

**Interfaces:**
- Consumes: `AccountLinkRepository.accounts()` and `exV2AccountGenerationProvider.accountId`.
- Produces: `linkedTradingAccountsProvider` containing only server-returned inactive accounts plus server-authoritative active presentation.

- [ ] Add a widget/provider test with a local-only account and an empty server response; assert that the local-only row is absent while the active bootstrap row remains visible.
- [ ] Run the focused test and confirm it fails because the current catalog merges `AccountSessionRegistry` or linked-account cache.
- [ ] Remove production reads of `accountSessionRegistryProvider`, `linkedTradingAccountsStoreProvider`, and `mergeAccountCatalog` from `LinkedTradingAccountsController.build()`.
- [ ] Return `AccountLinkRepository.accounts()` directly, with the active account ordered first when it is present.
- [ ] Run the focused account catalog tests and confirm they pass.

### Task 2: Make Switching One-Tap and Password-Free

**Files:**
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- Modify: `mobile/test/multi_account_switch_test.dart`

**Interfaces:**
- Consumes: `AccountActivationCoordinator.activate(String, metadata:)`.
- Produces: `LinkedTradingAccountsController.activate(String)` that either returns the accepted activation result or throws a safe server failure without navigation metadata.

- [ ] Add a widget test proving a tap on a server account calls `/activate` once and never pushes `/accounts/add/...`.
- [ ] Add a `404 account_not_found` test proving the catalog is invalidated/refetched and the password form is never opened.
- [ ] Run both tests and confirm the existing `AccountRelinkRequired` branch fails them.
- [ ] Remove `AccountRelinkRequired`, `_routableReauthenticationAccount`, and the relink route catch from `ProfileScreen`.
- [ ] On `404 account_not_found`, invalidate the account catalog and rethrow a safe failure; on `401`/`403`, invalidate the global bootstrap.
- [ ] Keep the activation guard so repeat taps cannot issue parallel switch requests.
- [ ] Run the switching tests and confirm success, 404, unauthorized, conflict, offline, and identity mismatch all preserve the correct active account.

### Task 3: Reduce Login State to One Global Device Token

**Files:**
- Modify: `mobile/lib/features/account_sessions/application/account_session_committer.dart`
- Modify: `mobile/lib/features/account_login/application/account_password_login_controller.dart`
- Modify: `mobile/test/account_session_committer_test.dart`
- Modify: `mobile/test/account_password_login_controller_test.dart`

**Interfaces:**
- Consumes: `AccountPasswordLoginResult(deviceToken, account, bootstrap)`.
- Produces: an `AccountSessionCommitter` that writes only `DeviceTokenStore`, publishes the bootstrap atomically, and restores the old token on rejected publication.

- [ ] Add a committer test proving login writes the global token and publishes bootstrap without writing an account-session registry.
- [ ] Run it and confirm the current per-account session write is observable and fails the desired contract.
- [ ] Remove `AccountSessionStore` and registry invalidation dependencies from `SecureAccountSessionCommitter`.
- [ ] Preserve token rollback when publication is rejected or throws.
- [ ] Run login/controller/device-gate tests and confirm one login unlocks the app.

### Task 4: Remove Switching Dependencies on Legacy Session and Reconnect State

**Files:**
- Modify: `mobile/lib/features/account_link/application/account_link_controller.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart`
- Modify: `mobile/test/account_link_controller_test.dart`
- Modify: `mobile/test/account_link_login_video_test.dart`
- Delete only when unreferenced: `mobile/lib/features/account_sessions/application/account_catalog_merge.dart`
- Delete only when unreferenced: `mobile/lib/features/account_sessions/application/account_session_registry.dart`
- Delete only when unreferenced: `mobile/lib/features/account_sessions/application/account_session_switch_coordinator.dart`
- Delete only when unreferenced: `mobile/lib/features/account_sessions/data/account_session_bootstrap_loader.dart`
- Delete only when unreferenced: `mobile/lib/features/account_sessions/data/account_session_store.dart`
- Delete only when unreferenced: `mobile/lib/features/account_sessions/domain/account_session.dart`

**Interfaces:**
- Consumes: the explicit add-account `/mobile/accounts/link` flow only.
- Produces: add-account behavior that cannot affect ordinary account switching.

- [ ] Add a test proving ordinary switching has no dependency on reconnect grants or stored per-account tokens.
- [ ] Remove reconnect/session references from switching providers and production account catalog construction.
- [ ] Keep explicit add-account credential submission isolated; do not persist password plaintext.
- [ ] Use `rg` to prove deleted types have no production references before deleting files and obsolete tests.
- [ ] Run all account login/link/switch tests.

### Task 5: Documentation and End-to-End Verification

**Files:**
- Modify: `docs/ex-v2-mobile-integration.md`

**Interfaces:**
- Consumes: final production behavior.
- Produces: accurate operational documentation and a verified APK.

- [ ] Update the integration document to describe one global device token, server-only account catalog, and `/activate` switching.
- [ ] Run `dart format --output=none --set-exit-if-changed` on every touched Dart file.
- [ ] Run `flutter analyze`.
- [ ] Run focused account tests, then `flutter test --concurrency=1`; isolate and document only independently reproducible unrelated golden failures.
- [ ] Run `dotnet build backend/Trading.sln` and `dotnet test backend/Trading.sln --no-build`.
- [ ] Run `flutter build apk --debug`, install with `adb install -r`, and smoke-test login plus A/B/A switching without password.

