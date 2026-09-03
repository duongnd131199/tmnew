# EX V2 Close Sync App Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make valid EX V2 close snapshots update Trade and History immediately without unconditional post-close polling.

**Architecture:** Extend the existing account-sync DTO and SignalR envelope parser, then route both HTTP and realtime snapshots through one Riverpod reducer. Keep the existing GET-only reconciliation exclusively for compatibility failures and version gaps.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, SignalR, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-01-ex-v2-close-sync-app-update-design.md`

## Global Constraints

- Do not change the required Flutter/Riverpod/Dio/SignalR stack.
- Do not calculate server-canonical financial values in Flutter.
- Never send a second close POST for reconciliation.
- Preserve unrelated dirty-worktree changes.
- Keep compatibility fallback for missing or invalid `sync` payloads.

---

### Task 1: Typed close responses and realtime envelope metadata

**Files:**
- Modify: `mobile/lib/features/account_sync/domain/ex_v2_models.dart`
- Modify: `mobile/lib/features/account_sync/data/ex_v2_repository.dart`
- Modify: `mobile/lib/features/account_sync/data/ex_v2_realtime_service.dart`
- Test: `mobile/test/ex_v2_models_test.dart`
- Test: `mobile/test/ex_v2_repository_test.dart`
- Test: `mobile/test/ex_v2_realtime_service_test.dart`

**Interfaces:**
- Produces: typed close response objects with `ExV2CloseSync? sync` for legacy compatibility.
- Produces: `ExV2RealtimeEvent.eventId` and `correlationId`.

- [ ] **Step 1: Write failing parser and repository tests**

```dart
test('close response parses required canonical sync', () {
  final response = ExV2CloseExecutionResponse.fromJson(fullCloseFixture);
  expect(response.sync!.operation.mode, 'full');
});

test('realtime close exposes outbox metadata', () async {
  hub.emit('CloseExecutionCommitted', [closeEnvelopeFixture]);
  expect(events.single.eventId, 'event-1');
  expect(events.single.correlationId, 'correlation-1');
});
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```text
flutter test test/ex_v2_models_test.dart test/ex_v2_repository_test.dart test/ex_v2_realtime_service_test.dart
```

Expected: new typed-response or envelope-metadata assertions fail.

- [ ] **Step 3: Implement the minimum typed parsing**

```dart
final class ExV2RealtimeEvent {
  const ExV2RealtimeEvent({
    required this.name,
    required this.data,
    this.eventId,
    this.correlationId,
    this.version,
    this.accountId,
  });
}
```

Repository mutation methods parse their JSON through the typed response while
preserving a nullable `sync` only for old-server compatibility.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the Task 1 command and require exit code 0.

### Task 2: One atomic reducer with bounded deduplication

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Test: `mobile/test/ex_v2_realtime_service_test.dart`
- Test: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Consumes: `ExV2CloseSync` and optional realtime `eventId`.
- Produces: one `_applyCloseSync(...)` result for both delivery paths.

- [ ] **Step 1: Write failing delivery-order tests**

```dart
test('HTTP then realtime applies one canonical close', () async {
  // Complete HTTP sync, emit the matching outbox event, and assert one deal
  // and no additional History GET.
});

test('realtime then HTTP applies one canonical close', () async {
  // Emit the matching event while POST is in flight, then complete HTTP and
  // assert the same single canonical entity set.
});

test('version gap publishes immediately and queues one reconciliation', () async {
  // Emit N+2 and assert the close state before releasing the blocked GET.
});
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```text
flutter test test/ex_v2_realtime_service_test.dart test/ex_v2_trading_command_test.dart
```

Expected: duplicate delivery or unconditional refresh assertions fail.

- [ ] **Step 3: Implement reducer state and bounded keys**

```dart
enum _CloseSyncApplyResult { applied, duplicate, rejected }

_CloseSyncApplyResult _applyCloseSync({
  required ExV2CloseSync sync,
  required _AccountMutationScope scope,
  required Set<String> completedOperationIds,
  required Set<String> affectedRequestIds,
  String? eventId,
});
```

Use bounded insertion-order sets for operation/event keys, clear them on
active-account replacement, and queue a background refresh only for a detected
version gap.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the Task 2 command and require exit code 0.

### Task 3: Remove polling from valid HTTP success paths

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Test: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Consumes: `_CloseSyncApplyResult` from Task 2.
- Produces: immediate full/partial/bulk/close-by completion.

- [ ] **Step 1: Write failing no-poll tests**

```dart
test('valid full close sync performs no post-close History GET', () async {
  await notifier.closePosition('server-position-1');
  expect(adapter.postCloseHistoryReads, 0);
});

test('valid close-by sync performs no unconditional refresh', () async {
  await notifier.closeBy('server-position-1', 'server-position-2');
  expect(adapter.postCloseBootstrapReads, 0);
});
```

Add equivalent coverage for partial and all-valid bulk close. Existing missing
or malformed sync tests must continue proving the compatibility fallback.

- [ ] **Step 2: Run each new test and verify RED**

Run each test by `--plain-name`; failure must be the unexpected GET count.

- [ ] **Step 3: Implement minimal branching**

For an applied or duplicate valid sync, return immediately. Invoke existing
single/bulk/close-by reconciliation only for missing, malformed, mismatched, or
rejected snapshots. Settle grouped-close bookkeeping locally when every bulk
operation produced a valid sync.

- [ ] **Step 4: Run trading command tests and verify GREEN**

```text
flutter test test/ex_v2_trading_command_test.dart
```

### Task 4: Version-aware fallback and final verification

**Files:**
- Modify if required: `mobile/lib/features/account_sync/data/ex_v2_repository.dart`
- Modify if required: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Test: `mobile/test/ex_v2_repository_test.dart`
- Test: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Produces: fallback reconciliation that never replaces version `N` with an
  older History page.

- [ ] **Step 1: Add a failing stale-History regression**

```dart
test('fallback waits for History snapshotVersion to reach close version', () async {
  // First History page is N-1, second is N; assert only N is published.
});
```

- [ ] **Step 2: Implement the smallest page-envelope version propagation**

Preserve `snapshotVersion` while reading paged History and require it to be at
least the target close version before fallback publication. Do not alter
ordinary entity mapping or pagination semantics.

- [ ] **Step 3: Run required verification**

```text
flutter analyze
flutter test test/ex_v2_account_provider_test.dart test/ex_v2_account_view_state_test.dart test/ex_v2_api_client_test.dart test/ex_v2_demo_mapper_test.dart test/ex_v2_history_reconciler_test.dart test/ex_v2_models_test.dart test/ex_v2_realtime_service_test.dart test/ex_v2_repository_test.dart test/ex_v2_trading_command_test.dart test/ex_v2_wallet_history_mapper_test.dart
flutter build ios --simulator --debug
flutter build apk --debug
git diff --check
```

Expected: analyzer clean, all focused tests pass, both builds exit 0, and diff
check emits no errors.

