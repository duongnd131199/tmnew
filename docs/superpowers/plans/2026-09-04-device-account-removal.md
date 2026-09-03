# Device Account Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user remove the active trading-account login from the current device, switch automatically to the first remaining account, and keep the removed account hidden until it is explicitly logged in or linked again.

**Architecture:** Persist removed public account IDs in Flutter Secure Storage, filter only inactive server-catalog rows through that store, and coordinate replacement activation or last-account sign-out in one application service. Keep the existing global `deviceToken`, EX V2 activation coordinator, and server data intact; the account-detail widget only confirms, invokes the service, and reacts to its typed result.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Dio/EX V2 client, Flutter Secure Storage, Flutter widget/unit tests.

**Spec:** `docs/superpowers/specs/2026-09-04-device-account-removal-design.md`

## Global Constraints

- This is device-local removal; never call a server delete endpoint or delete trading, balance, order, position, deal, wallet, or history data.
- Do not change Flutter, Riverpod, GoRouter, Dio, Secure Storage, or the EX V2 base URL.
- Do not store or log passwords, device tokens, bootstrap payloads, or financial data in the removed-account store.
- Preserve server-authoritative `GET /mobile/accounts` ordering and `PUT /mobile/accounts/{accountId}/activate` semantics.
- Enter removal only through **Xóa tài khoản** in account detail; do not add swipe or long-press deletion.
- Preserve unrelated dirty-worktree changes; the existing white account-row styling remains intact while the fixed fake `Delete` row is removed.
- Every production behavior starts with a failing test and a verified RED result.

---

### Task 1: Secure removed-account store

**Files:**
- Create: `mobile/lib/features/account_sessions/data/removed_account_store.dart`
- Create: `mobile/test/removed_account_store_test.dart`

**Interfaces:**
- Consumes: `FlutterSecureStorage.read`, `write`, and `delete`.
- Produces: `RemovedAccountStore.read()`, `add(String accountId)`, `remove(String accountId)` and `removedAccountStoreProvider`.

- [ ] **Step 1: Write failing store tests**

```dart
setUp(() => FlutterSecureStorage.setMockInitialValues({}));

test('add deduplicates normalized account IDs and survives a new instance', () async {
  const first = SecureRemovedAccountStore(FlutterSecureStorage());
  await first.add(' account-a ');
  await first.add('account-a');
  await first.add('account-b');

  const restored = SecureRemovedAccountStore(FlutterSecureStorage());
  expect(await restored.read(), {'account-a', 'account-b'});
});

test('remove deletes only the selected account ID', () async {
  const store = SecureRemovedAccountStore(FlutterSecureStorage());
  await store.add('account-a');
  await store.add('account-b');
  await store.remove('account-a');
  expect(await store.read(), {'account-b'});
});

test('malformed secure payload fails without deleting it', () async {
  FlutterSecureStorage.setMockInitialValues({
    SecureRemovedAccountStore.storageKey: '{bad-json',
  });
  const storage = FlutterSecureStorage();
  const store = SecureRemovedAccountStore(storage);
  await expectLater(store.read(), throwsA(isA<FormatException>()));
  expect(await storage.read(key: SecureRemovedAccountStore.storageKey), '{bad-json');
});
```

- [ ] **Step 2: Run the store tests and verify RED**

Run: `cd mobile && flutter test test/removed_account_store_test.dart`

Expected: compilation fails because `removed_account_store.dart` and its types do not exist.

- [ ] **Step 3: Implement the minimal secure store**

```dart
abstract interface class RemovedAccountStore {
  Future<Set<String>> read();
  Future<void> add(String accountId);
  Future<void> remove(String accountId);
}

final class SecureRemovedAccountStore implements RemovedAccountStore {
  const SecureRemovedAccountStore(this._storage);
  static const storageKey = 'ex_v2_removed_account_ids_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<Set<String>> read() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.isEmpty) return <String>{};
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Removed account IDs must be a JSON list');
    return decoded.map((value) {
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Removed account ID must be a non-empty string');
      }
      return value.trim();
    }).toSet();
  }

  @override
  Future<void> add(String accountId) => _update(accountId, add: true);

  @override
  Future<void> remove(String accountId) => _update(accountId, add: false);

  Future<void> _update(String accountId, {required bool add}) async {
    final normalized = accountId.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Removed account ID must not be empty');
    }
    final values = await read();
    add ? values.add(normalized) : values.remove(normalized);
    if (values.isEmpty) {
      await _storage.delete(key: storageKey);
      return;
    }
    final sorted = values.toList()..sort();
    await _storage.write(key: storageKey, value: jsonEncode(sorted));
  }
}

final removedAccountStoreProvider = Provider<RemovedAccountStore>(
  (ref) => const SecureRemovedAccountStore(FlutterSecureStorage()),
);
```

- [ ] **Step 4: Run the store tests and verify GREEN**

Run: `cd mobile && flutter test test/removed_account_store_test.dart`

Expected: all store tests pass with no warnings.

### Task 2: Filter removed rows and restore explicitly activated accounts

**Files:**
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart`
- Modify: `mobile/lib/features/account_link/application/account_activation_coordinator.dart`
- Modify: `mobile/test/ex_v2_account_provider_test.dart`
- Modify: `mobile/test/account_activation_coordinator_test.dart`

**Interfaces:**
- Consumes: `RemovedAccountStore.read/remove`, `linkedTradingAccountsProvider`, and accepted `AccountActivationOutcome`.
- Produces: a visible linked-account catalog that excludes removed inactive IDs while always retaining the current active account; accepted explicit activation removes the target ID from the removed set.

- [ ] **Step 1: Add failing provider and activation tests**

Use the existing `_BootstrapAdapter` fixture with a third catalog row and override `removedAccountStoreProvider`:

```dart
final removedStore = _MemoryRemovedAccountStore({'account-b'});
final container = ProviderContainer(overrides: [
  exV2EnabledProvider.overrideWithValue(true),
  exV2DioProvider.overrideWithValue(dio),
  deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore('test-token')),
  removedAccountStoreProvider.overrideWithValue(removedStore),
]);
await container.read(exV2AccountProvider.future);
final visible = await container.read(linkedTradingAccountsProvider.future);
expect(visible.map((account) => account.id), ['account-a', 'account-c']);
```

Repeat with `{'account-a'}` and assert `account-a` is retained because it is the active recovery row.

Add an activation-coordinator test with `account-b` initially removed. Activate `account-b`, assert the publication is accepted, then assert `RemovedAccountStore.read()` no longer contains `account-b`.

```dart
final removedStore = _MemoryRemovedAccountStore({'account-b'});
final container = ProviderContainer(overrides: [
  exV2EnabledProvider.overrideWithValue(false),
  accountLinkRepositoryProvider.overrideWithValue(repository),
  removedAccountStoreProvider.overrideWithValue(removedStore),
]);
await container.read(exV2AccountProvider.future);
final request = container.read(accountActivationCoordinatorProvider.notifier)
    .activate('account-b', metadata: metadata);
repository.complete('account-b', version: 2);
expect((await request).accepted, isTrue);
expect(await removedStore.read(), isEmpty);
```

- [ ] **Step 2: Run focused tests and verify RED**

Run: `cd mobile && flutter test test/ex_v2_account_provider_test.dart test/account_activation_coordinator_test.dart`

Expected: removed accounts are still returned and accepted activation does not clear the removed marker.

- [ ] **Step 3: Implement filtering and restoration**

In `LinkedTradingAccountsController.build()`, await `removedAccountStoreProvider.read()` and filter with:

```dart
final visibleAccounts = accounts.where(
  (account) => account.id == activeId || !removedIds.contains(account.id),
);
return List.unmodifiable([
  ...visibleAccounts.where((account) => account.id == activeId),
  ...visibleAccounts.where((account) => account.id != activeId),
]);
```

After `AccountActivationCoordinator` accepts a non-stale bootstrap, call:

```dart
await ref.read(removedAccountStoreProvider).remove(accountId);
ref.invalidate(linkedTradingAccountsProvider);
```

Do not clear a marker for rejected-stale activation.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `cd mobile && flutter test test/ex_v2_account_provider_test.dart test/account_activation_coordinator_test.dart`

Expected: all focused tests pass.

### Task 3: Coordinate active-account removal and same-process sign-out

**Files:**
- Create: `mobile/lib/features/account_sessions/application/account_removal_service.dart`
- Create: `mobile/test/account_removal_service_test.dart`
- Modify: `mobile/lib/features/account_sync/presentation/device_gate.dart`
- Modify: `mobile/test/device_gate_test.dart`
- Modify: `mobile/lib/features/account_sessions/application/account_session_committer.dart`
- Modify: `mobile/test/account_session_committer_test.dart`

**Interfaces:**
- Consumes: active `ExV2AccountViewState`, visible `LinkedTradingAccount` list, `AccountActivationCoordinator`, `RemovedAccountStore`, and `DeviceTokenStore`.
- Produces: `AccountRemovalResult.switched`, `AccountRemovalResult.signedOut`, `AccountRemovalService.removeActiveAccount()`, `accountRemovalServiceProvider`, and a `deviceSessionRevisionProvider` notification consumed by `DeviceGate`.

- [ ] **Step 1: Write failing workflow tests**

Cover these literal behaviors in `account_removal_service_test.dart`:

```dart
test('removing active account activates the first remaining account and hides the old ID', () async {
  final result = await fixture.service.removeActiveAccount();
  expect(result, AccountRemovalResult.switched);
  expect(fixture.activatedIds, ['account-b']);
  expect(await fixture.removedStore.read(), {'account-a'});
  expect(fixture.tokenStore.value, 'device-token');
});

test('activation failure rolls back the pending removed marker', () async {
  fixture.activationError = const AccountMutationOffline();
  await expectLater(fixture.service.removeActiveAccount(), throwsA(isA<AccountMutationOffline>()));
  expect(await fixture.removedStore.read(), isEmpty);
  expect(fixture.tokenStore.value, 'device-token');
});

test('removing the last account deletes the token and advances session revision', () async {
  final before = fixture.container.read(deviceSessionRevisionProvider);
  final result = await fixture.service.removeActiveAccount();
  expect(result, AccountRemovalResult.signedOut);
  expect(fixture.tokenStore.value, isNull);
  expect(fixture.container.read(deviceSessionRevisionProvider), before + 1);
});

test('token deletion failure restores the removed marker', () async {
  fixture.tokenStore.deleteFails = true;
  await expectLater(fixture.service.removeActiveAccount(), throwsA(isA<StateError>()));
  expect(await fixture.removedStore.read(), isEmpty);
});
```

Also add a `DeviceGate` widget test: start with a token, bump `deviceSessionRevisionProvider` after deleting it, and assert `account-login-required` appears without restarting the widget.

Add a committer test with the login target in the removed store and assert a successful commit removes only that marker:

```dart
final removedStore = _MemoryRemovedAccountStore({'account-b', 'account-c'});
final committer = SecureAccountSessionCommitter(
  guard: AccountSwitchGuard(),
  tokenStore: tokenStore,
  publisher: container.read(exV2AccountProvider.notifier),
  removedAccountStore: removedStore,
  invalidateLinkedAccounts: () => container.invalidate(linkedTradingAccountsProvider),
);
expect(await committer.commit(_loginResult('account-b', 'token-b')),
    ExV2BootstrapPublication.committed);
expect(await removedStore.read(), {'account-c'});
```

- [ ] **Step 2: Run workflow tests and verify RED**

Run: `cd mobile && flutter test test/account_removal_service_test.dart test/device_gate_test.dart test/account_session_committer_test.dart`

Expected: compilation fails because the removal service/revision provider do not exist and existing login commit does not restore a removed account.

- [ ] **Step 3: Implement the workflow**

Define:

```dart
enum AccountRemovalResult { switched, signedOut }

abstract interface class AccountRemovalService {
  Future<AccountRemovalResult> removeActiveAccount();
}

final deviceSessionRevisionProvider =
    NotifierProvider<DeviceSessionRevisionController, int>(
      DeviceSessionRevisionController.new,
    );
```

The production service must reject concurrent calls, derive `targetId` from the active bootstrap, and select the first visible account whose ID differs from `targetId`.

For a replacement account, write the target marker without invalidating the visible provider, call the existing activation coordinator, rollback the marker if activation throws or is rejected stale, then invalidate `linkedTradingAccountsProvider` and return `switched`.

For the last account, write the marker, delete the global token, rollback the marker if token deletion throws, invalidate `exV2AccountProvider` and `linkedTradingAccountsProvider`, advance the session revision, and return `signedOut`.

Update `DeviceGate` to listen for a revision advance and invoke its existing `_readToken(retry: true)` flow:

```dart
ref.listen(deviceSessionRevisionProvider, (previous, next) {
  if (previous != null && next != previous) unawaited(_readToken(retry: true));
});
```

Update `SecureAccountSessionCommitter` so accepted login performs:

```dart
if (publication != ExV2BootstrapPublication.rejectedStale) {
  await removedAccountStore.remove(result.account.id);
  invalidateLinkedAccounts();
}
```

Keep the existing token rollback for rejected/stale publications.

- [ ] **Step 4: Run workflow tests and verify GREEN**

Run: `cd mobile && flutter test test/account_removal_service_test.dart test/device_gate_test.dart test/account_session_committer_test.dart`

Expected: all workflow tests pass.

### Task 4: Wire the account-detail confirmation UI and remove the fake row

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/account_detail_screen.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- Modify: `mobile/test/account_detail_screen_test.dart`
- Modify: `mobile/test/account_list_reference_test.dart`
- Modify: `docs/screens/account-list.md`

**Interfaces:**
- Consumes: `accountRemovalServiceProvider` and `AccountRemovalResult`.
- Produces: confirmation dialog, loading/double-submit guard, switched navigation, safe failure feedback, and a real-account-only list.

- [ ] **Step 1: Write failing widget tests**

Add tests that scroll to `account-delete-row`, tap it, and assert:

```dart
expect(find.text('Xóa tài khoản khỏi thiết bị?'), findsOneWidget);
expect(find.text('Hủy'), findsOneWidget);
expect(find.text('Xóa'), findsOneWidget);
```

Use an overridden fake `AccountRemovalService` to prove `Hủy` makes zero calls, two quick taps on the confirmed action make one call, `switched` pops the detail route, and a thrown `StateError` keeps the screen visible with `Không thể xóa tài khoản khỏi thiết bị. Thử lại.`.

Replace the fixed-row test with a real-list test asserting no `account-28210230`, no `Delete` text, and exactly the supplied real account rows.

- [ ] **Step 2: Run widget tests and verify RED**

Run: `cd mobile && flutter test test/account_detail_screen_test.dart test/account_list_reference_test.dart`

Expected: the delete row does nothing and the fixed `Delete` account is still rendered.

- [ ] **Step 3: Implement the UI**

Connect `account-delete-row` to a private async confirmation method. Use `AlertDialog`, `TextButton`, `AppColors.destructive`, and existing theme typography; keep `barrierDismissible: true`. After confirmation, set a local `_removalInFlight` flag before awaiting the service. On `switched`, call `context.pop()`; on `signedOut`, allow `DeviceGate` to replace the app. On error, show a SnackBar using the EX V2 safe message when available and the literal generic message otherwise.

Remove `_fixedDeleteAccount`, change the list `itemCount` back to `ordered.length`, and render `ordered[index]` directly. Keep the user-owned `AppColors.surface` row background change.

Replace the fixed-row documentation with:

```markdown
## States

- Empty: không hiển thị hàng tài khoản nào.
- Success: chỉ hiển thị tài khoản thật chưa bị gỡ trên thiết bị.

## Interactions

- Chạm tài khoản active mở chi tiết; dòng **Xóa tài khoản** trong chi tiết mở xác nhận gỡ khỏi thiết bị.
- Sau khi gỡ, account không còn trong list; nếu còn account khác app tự chuyển sang account đầu tiên.
```

- [ ] **Step 4: Run widget tests and verify GREEN**

Run: `cd mobile && flutter test test/account_detail_screen_test.dart test/account_list_reference_test.dart`

Expected: all widget tests pass.

### Task 5: Full verification and visual evidence

**Files:**
- Modify on a directly observed regression only: the specific source or test file from Tasks 1–4 that owns the failing behavior.
- Create: `artifacts/account-removal/` screenshots when an emulator is available.

**Interfaces:**
- Consumes: completed feature.
- Produces: analyzer, full-test, mobile build, backend build/test, and visual verification evidence.

- [ ] **Step 1: Format and inspect the patch**

Run: `cd mobile && dart format lib/features/account_sessions lib/features/account_link/application/account_activation_coordinator.dart lib/features/account_sync/presentation/device_gate.dart lib/features/profile/presentation/screens/account_detail_screen.dart lib/features/profile/presentation/screens/profile_screen.dart test/removed_account_store_test.dart test/account_removal_service_test.dart test/account_activation_coordinator_test.dart test/account_session_committer_test.dart test/device_gate_test.dart test/account_detail_screen_test.dart test/account_list_reference_test.dart`

Run: `git diff --check && git status --short && git diff --stat`

Expected: formatting succeeds, no whitespace errors, and unrelated pre-existing dirty files remain untouched.

- [ ] **Step 2: Run mobile analysis and tests**

Run: `cd mobile && flutter analyze`

Run: `cd mobile && flutter test`

Expected: analyzer reports no issues and the complete Flutter suite passes.

- [ ] **Step 3: Build both applications**

Run: `cd mobile && flutter build apk --debug`

Run: `cd backend && dotnet build Trading.sln`

Run: `cd backend && dotnet test Trading.sln --no-build`

Expected: all builds and backend tests exit successfully.

- [ ] **Step 4: Perform emulator smoke and visual checks**

Use an available Android emulator without clearing application data. Verify A/B behavior: open A detail, confirm deletion, observe B active at the top, cold restart and confirm A remains absent, then log in/link A and confirm it reappears. Capture the confirmation dialog and post-removal list under `artifacts/account-removal/`. If no emulator or usable test credentials are available, report that exact limitation and do not claim visual smoke completion.

- [ ] **Step 5: Review scope and hand off**

Run: `git diff --name-only` and inspect every changed file. Confirm there is no server delete call, secret, fixed fake `Delete` row, or unrelated source edit. Do not commit user-owned pre-existing changes unless the user explicitly requests a combined commit.
