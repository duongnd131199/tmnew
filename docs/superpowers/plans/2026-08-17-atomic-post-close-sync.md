# Atomic Post-Close Synchronization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a committed close update balance, positions, deals, closed history, and History totals coherently before the close action completes.

**Architecture:** Keep the deployed REST contract and make the existing post-close read phase an awaited, account-scoped snapshot reconciliation. Extend the trading-history snapshot with the canonical History summary, publish all post-close collections in one state update, and retry only read APIs when history visibility lags.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, Dio, flutter_test.

## Global Constraints

- Do not change backend code, public base URL, authentication, or required technology stack.
- Do not invent an endpoint absent from production OpenAPI.
- Send the close mutation exactly once with one new idempotency key.
- Retry only canonical GET reads after a committed close.
- Do not calculate financial values in Flutter or log sensitive/financial payloads.
- Preserve unrelated dirty-worktree changes.
- Write and observe regression tests failing before production changes.

---

### Task 1: Lock atomic post-close behavior with RED tests

**Files:**
- Modify: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Consumes: `ExV2AccountController.closePosition(String, {double? volume})`.
- Produces: regression coverage for awaited history, balance/summary coherence, and mutation idempotency.

- [ ] Change the delayed-history test to assert resolved History immediately after awaiting `closePosition`, without polling the provider.
- [ ] Make the fake bootstrap balance change only after the close commits and make `/history/summary` return matching post-close totals.
- [ ] Assert the returned state contains the new balance, resolved closed row, exit deals, and updated summary together.
- [ ] Assert delayed reconciliation still sends exactly one close POST.
- [ ] Run `flutter test --reporter expanded test/ex_v2_trading_command_test.dart` and verify failure because retry is detached and summary is not part of the post-close snapshot.

### Task 2: Publish an awaited canonical post-close snapshot

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`

**Interfaces:**
- Extends: `_TradingHistorySnapshot` with `ExV2HistorySummary summary`.
- Updates: `_mergeCoreWithHydrated(..., ExV2HistorySummary? historySummary)`.
- Produces: `_retryCommittedCloseHistory(...) -> Future<DemoDeal?>` that publishes each coherent snapshot and returns after resolution or bounded exhaustion.

- [ ] Load `historySummary()` with deals and closed positions in `_loadTradingHistorySnapshot`.
- [ ] Add optional `historySummary` to `_mergeCoreWithHydrated` and publish it with the post-close state.
- [ ] Replace the detached full-close retry with an awaited retry.
- [ ] On each retry, reload bootstrap and the complete trading-history snapshot, then publish balance, positions, deals, closed history, and summary in one `AsyncData` assignment.
- [ ] Preserve active-account generation checks before and after every await.
- [ ] Never retry `repository.closePosition`.
- [ ] Run the focused trading command test and require GREEN.

### Task 3: Regression and release verification

**Files:**
- Verify: `mobile/`
- Verify: `backend/`

**Interfaces:**
- Produces: fresh test, analyze, build, and emulator evidence.

- [ ] Run focused account/history/controller tests with concurrency 1.
- [ ] Run the complete Flutter test suite and record pass/fail totals.
- [ ] Run `flutter analyze` and require no issues.
- [ ] Build the debug APK and verify the artifact exists.
- [ ] Run `dotnet build backend/Trading.sln` and `dotnet test backend/Trading.sln`.
- [ ] Install and launch the APK on the existing LDPlayer instance; inspect Trade and History without placing or closing another order.
- [ ] Run `git diff --check`, review scoped diffs, and scan changed source/tests for secrets or newly added request logging.
