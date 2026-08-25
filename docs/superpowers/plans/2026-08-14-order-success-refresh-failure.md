# Order Success Refresh Failure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent the app from reporting a failed order after the server has already returned HTTP 201.

**Architecture:** Treat the mutation response as the command result, reconcile its optimistic row immediately, and move bootstrap hydration to a background refresh that preserves valid state on read failure. Genuine POST failures keep the existing rollback path.

**Tech Stack:** Flutter, Dart, Riverpod AsyncNotifier, Dio, flutter_test.

## Global Constraints

- Do not change the API contract or required technology stack.
- Do not invent position, executed price, balance, equity, or history data.
- Keep one unique idempotency key per user tap.
- Run build, analyze, and relevant tests after the change.

---

### Task 1: Reproduce the false failure

**Files:**
- Modify: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Consumes: `ExV2AccountController.createOrder(...)`
- Produces: regression coverage for HTTP 201 followed by bootstrap failure

- [ ] Add a fake adapter mode that accepts POST `/orders` and rejects only later `/mobile/bootstrap` reads.
- [ ] Assert `createOrder` returns `server-order-1`, keeps a filled order in state, and clears its pending marker.
- [ ] Run the focused test and verify it fails because the current code rethrows the bootstrap failure.

### Task 2: Separate command success from background synchronization

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Test: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Consumes: confirmed `ExV2Order` returned by `ExV2Repository.createOrder`
- Produces: `_refreshAfterMutation()` background reconciliation that preserves state on failure

- [ ] Limit the rollback `catch` to the POST mutation.
- [ ] Replace the matching optimistic row with `ExV2DemoMapper.order(order)` immediately after HTTP success.
- [ ] Clear only `order:<idempotencyKey>` and launch `_refreshAfterMutation()` without awaiting it.
- [ ] Implement background bootstrap/hydration with generation ordering and a no-state-change catch.
- [ ] Run focused tests and verify both refresh-failure success and genuine POST rejection.

### Task 3: Verify and deploy to the emulator

**Files:**
- Verify only; no additional production files expected.

**Interfaces:**
- Consumes: debug APK
- Produces: updated installed app on `emulator-5558`

- [ ] Run Dart formatting.
- [ ] Run focused trading tests, complete `flutter test`, and `flutter analyze`.
- [ ] Build `flutter build apk --debug`.
- [ ] Install with `adb install -r` and launch without clearing app data or drive D.

