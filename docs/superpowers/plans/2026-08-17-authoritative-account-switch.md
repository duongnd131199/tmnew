# Authoritative Account Switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure every successful login/activation atomically displays the selected account's own financial data, regardless of the previously active account's version.

**Architecture:** `publishBootstrap` receives an explicit authoritative-switch intent. Different-account switches use action authority instead of cross-account bootstrap versions; same-account refreshes retain version ordering.

**Tech Stack:** Flutter, Dart, Riverpod, Dio test adapters, Android debug APK.

## Global Constraints

- Never merge financial collections from different account IDs.
- Preserve stale-response protection for concurrent activation operations.
- Do not change backend contracts, base URLs, credentials, or device-token handling.
- Do not log secrets or full request bodies.
- Preserve unrelated dirty worktree changes.

---

### Task 1: Reproduce the low-version account switch failure

**Files:**
- Modify: `mobile/test/account_activation_coordinator_test.dart`
- Modify: `mobile/test/account_password_login_controller_test.dart`

- [ ] Seed a high-version active account, activate/login a different low-version account, and assert the new account is accepted.
- [ ] Assert every account-scoped state branch belongs to the new bootstrap.
- [ ] Run focused tests and verify they fail with stale publication.

### Task 2: Implement authoritative account switching

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Modify: `mobile/lib/features/account_link/application/account_activation_coordinator.dart`
- Modify: `mobile/lib/features/account_login/application/account_password_login_controller.dart`

- [ ] Add `authoritativeAccountSwitch` to `publishBootstrap`.
- [ ] For different identities, accept an authoritative switch unless its positive activation authority is older than the last accepted activation.
- [ ] Keep existing version validation for same-account publications.
- [ ] Pass the intent from linked-account activation and account/password login.
- [ ] Run focused tests and confirm RED becomes GREEN.

### Task 3: Verify all account-scoped consumers

**Files:**
- Test: `mobile/test/account_link_cross_tab_video_test.dart`
- Test: `mobile/test/multi_account_switch_test.dart`
- Test: `mobile/test/ex_v2_account_provider_test.dart`

- [ ] Run focused cross-tab, provider, account-login, and account-link suites.
- [ ] Run `flutter analyze`, full `flutter test`, and `flutter build apk --debug`.
- [ ] Run backend build and tests.
- [ ] Install APK on LDPlayer and confirm the stale-activation screen no longer blocks a valid new switch.
- [ ] Scan changed files for forbidden secret logging.
