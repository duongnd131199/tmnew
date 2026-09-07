# Immediate Trading Mutation Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make successful opens appear in Trade and successful closes appear in History immediately without resending a trading mutation.

**Architecture:** Extend the existing EX V2 account controller reconciliation only. Confirm created positions through the order/deal/position IDs returned by authoritative bootstrap data, and merge valid close transaction data independently from a newer realtime Account Summary watermark.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-06-immediate-trading-mutation-sync-design.md`

## Global Constraints

- Do not change the required Flutter/Riverpod/Dio stack.
- Do not change public API contracts, financial formulas, UI, navigation, or feature flags.
- Send every mutation exactly once; retry GET reconciliation only.
- Preserve authenticated active-account scope and newer authoritative summary data.

---

### Task 1: Reproduce delayed open reconciliation

**Files:**
- Modify: `mobile/test/ex_v2_trading_command_test.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`

**Interfaces:**
- Consumes: `ExV2AccountController.createOrder(..., reconcileBeforeReturning: true)` and `ExV2Bootstrap.recentDeals`.
- Produces: bounded authoritative create reconciliation linked by `orderId` and `positionId`.

- [x] **Step 1: Write the failing test**

Add an adapter mode whose first post-create bootstrap remains stale and whose
second read contains a recent deal linked to the created order and its open
position. Assert that the command has posted once, has not returned after the
first stale read, and returns after the linked position is published.

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/ex_v2_trading_command_test.dart --plain-name "reconciled create retries GET until its linked position is visible"`

Expected: FAIL because the current implementation returns after one stale read.

- [x] **Step 3: Write minimal implementation**

Add a private bounded GET-only reconciliation method. For market fills, accept
only a bootstrap containing a recent deal whose `orderId` equals the returned
order ID and whose `positionId` resolves to an open position. Publish each safe
newer core snapshot without waiting for History hydration. If the bounded reads
end first, retain the confirmed order and schedule normal reconciliation.

- [x] **Step 4: Run test to verify it passes**

Run the exact focused command from Step 2 and expect PASS with one order POST.

### Task 2: Apply a close transaction after a newer summary event

**Files:**
- Modify: `mobile/test/ex_v2_realtime_service_test.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`

**Interfaces:**
- Consumes: `ExV2CloseSync`, `ExV2AccountViewState.withAuthoritativeSummary`.
- Produces: atomic Trade/History update that preserves a newer summary watermark.

- [x] **Step 1: Write the failing test**

While a close response is gated, emit an Account Summary event with a version
higher than the close sync. Release the response and assert that the position is
removed and its order/deal/History row is published immediately, no fallback
bootstrap is read, and the newer Summary version and values remain unchanged.

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/ex_v2_realtime_service_test.dart --plain-name "newer summary does not block immediate HTTP close history"`

Expected: FAIL because the close sync is rejected as stale.

- [x] **Step 3: Write minimal implementation**

Separate the operation replay/deduplication guard from the summary watermark.
Merge affected positions, deals, orders, and closed History rows from the valid
close payload. Use its summary only when the sync version is not older; otherwise
retain the current bootstrap summary/version/server time and last summary version.

- [x] **Step 4: Run test to verify it passes**

Run the exact focused command from Step 2 and expect PASS with no extra GET.

### Task 3: Verify the bounded fix

**Files:**
- Verify only the files changed in Tasks 1 and 2 plus the existing chart/order behavior tests.

**Interfaces:**
- Consumes: completed controller and regression tests.
- Produces: build and test evidence suitable for simulator handoff.

- [x] **Step 1: Format and inspect the diff**

Run: `dart format lib/features/account_sync/application/ex_v2_account_provider.dart test/ex_v2_trading_command_test.dart test/ex_v2_realtime_service_test.dart`

Run: `git diff --check -- mobile/lib/features/account_sync/application/ex_v2_account_provider.dart mobile/test/ex_v2_trading_command_test.dart mobile/test/ex_v2_realtime_service_test.dart`

- [x] **Step 2: Run relevant tests**

Run: `flutter test test/ex_v2_trading_command_test.dart test/ex_v2_realtime_service_test.dart test/order_failure_silent_feedback_test.dart test/video2_cross_tab_test.dart test/video2_functional_regression_test.dart`

- [x] **Step 3: Analyze and build**

Run: `flutter analyze`

Run: `flutter build ios --simulator --debug`

- [x] **Step 4: Install the verified debug build**

Install and launch the generated app on the currently authorized iPhone 17
Simulator. Do not execute a real Buy, Sell, Close, deposit, or withdrawal while
performing visual inspection.

## Verification record

- Focused mutation/realtime/feedback suites: 96/96 passed.
- `flutter analyze`: passed with no issues.
- iOS Simulator debug build: passed and installed/launched on iPhone 17.
- Full repository suite: 1,072 passed, 1 skipped, 51 failed in pre-existing
  UI/golden/font/reference fixtures outside this mutation-sync scope. The
  focused mutation suites remained green within and after that run.
