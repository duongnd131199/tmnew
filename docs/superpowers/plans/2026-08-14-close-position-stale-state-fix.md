# Close Position Stale-State Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent a server-committed close from being restored locally and subsequently failing with `POSITION_NOT_FOUND`.

**Architecture:** Separate the close mutation boundary from best-effort reconciliation. The controller keeps optimistic removal after HTTP success, uses bootstrap/history only to enrich confirmed state, and reconciles a not-found response against a fresh bootstrap before deciding whether to roll back.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, EX V2 REST API.

## Global Constraints

- Keep the current Flutter/Riverpod/Dio stack and UI layout.
- Server data remains authoritative; do not synthesize close price or profit.
- Do not change the legacy web or production server.
- Run analyze, all relevant tests, builds, and emulator acceptance.

---

### Task 1: Lock the stale-close regression with tests

**Files:**
- Modify: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Consumes: `ExV2AccountController.closePosition(String, {double? volume})`.
- Produces: tests proving committed closes remain removed and stale not-found responses reconcile from bootstrap.

- [ ] Add an adapter mode where close POST succeeds but history has no closing deal.
- [ ] Assert the returned deal is absent, the position remains removed, and pending mutation state is cleared.
- [ ] Add an adapter mode where close returns `POSITION_NOT_FOUND` while bootstrap no longer contains the position.
- [ ] Assert the stale position is removed instead of restored.
- [ ] Run the targeted test and verify both new tests fail for the expected rollback behavior.

### Task 2: Separate mutation commit from reconciliation

**Files:**
- Modify: `mobile/lib/features/account_sync/data/ex_v2_api_client.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`

**Interfaces:**
- Produces: `Future<DemoDeal?> closePosition(String positionId, {double? volume})`.
- Produces: `ExV2RequestFailure.code` for stable server error classification.

- [ ] Preserve the structured server error code in `ExV2RequestFailure`.
- [ ] Roll back only when the close command fails and bootstrap still contains the position.
- [ ] After command success, keep the row removed even if history is delayed or unavailable.
- [ ] Return `null` when no authoritative closing deal is available and let the ticket return to Trade with a synchronization notice.
- [ ] Run targeted tests and verify they pass.

### Task 3: Full verification and installation

**Files:**
- Verify: `mobile/`
- Verify: `backend/`

**Interfaces:**
- Produces: analyzed/tested APK installed on `emulator-5558`.

- [ ] Run `flutter analyze --no-pub`.
- [ ] Run the full Flutter test suite.
- [ ] Run backend build and tests.
- [ ] Build the debug APK with temporary/cache paths on drive D.
- [ ] Install with `adb install -r`, launch the app, inspect a screenshot, and check for fatal crashes.
