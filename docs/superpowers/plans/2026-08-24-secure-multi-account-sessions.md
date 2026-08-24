# Secure Multi-Account Sessions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist one encrypted device session per real trading account, render all remembered accounts with correct broker metadata, and switch valid accounts without asking for the password again.

**Architecture:** Add a focused `account_sessions` feature containing the secure session model/store, registry, atomic login committer, and token-scoped bootstrap switcher. Existing account-password login and the existing add-account UI feed successful authentication results into the same committer; the current account list merges local sessions with server-linked accounts while preserving the active bootstrap as canonical financial state.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, `flutter_secure_storage`, Flutter unit/widget tests, Android debug APK.

**Spec:** `docs/superpowers/specs/2026-08-24-secure-multi-account-sessions-design.md`

## Global Constraints

- Before implementation, read `META_TRADER_CLONE_GUIDE.md`, `README.md`, `docs/architecture.md`, and `docs/design-system.md` in full.
- Do not change the required technology stack, EX V2 base URLs, or production backend contracts.
- Never persist a password; persist only opaque device tokens and account presentation metadata in Flutter Secure Storage.
- Never log passwords, device tokens, Authorization headers, reconnect grants, or complete authentication responses.
- Do not synthesize, seed, or hard-code accounts, balances, positions, history, or broker identities.
- Preserve the current white theme, Account screen geometry, trading behavior, and server-authoritative account state.
- A previously overwritten token cannot be recovered. Each old account must be authenticated once through the existing add-account interface.
- Do not modify the local backend because it is not the deployed EX V2 service.
- Use `apply_patch` for hand edits and stage/commit only the exact files owned by each task; preserve unrelated dirty-worktree changes.
- After every code task, run its focused tests, `flutter analyze`, and `flutter build apk --debug` from `mobile/`.

---

### Task 1: Secure account session model and store

**Files:**
- Create: `mobile/lib/features/account_sessions/domain/account_session.dart`
- Create: `mobile/lib/features/account_sessions/data/account_session_store.dart`
- Create: `mobile/test/account_session_store_test.dart`

**Interfaces:**
- Consumes: `LinkedTradingAccount` from `features/account_link/domain/account_link_models.dart` and `FlutterSecureStorage`.
- Produces: `AccountSessionAvailability`, `AccountSession`, `AccountSessionStore.readAll()`, `AccountSessionStore.writeAll(List<AccountSession>)`, and `accountSessionStoreProvider`.

- [ ] **Step 1: Write failing serialization and secure-store tests**

```dart
test('round trips two independent account tokens without a password field', () async {
  FlutterSecureStorage.setMockInitialValues({});
  const store = SecureAccountSessionStore(FlutterSecureStorage());
  await store.writeAll([
    _session('account-a', token: 'token-a'),
    _session('account-b', token: 'token-b'),
  ]);

  final restored = await store.readAll();
  expect(restored.map((item) => item.account.id), ['account-a', 'account-b']);
  expect(restored.map((item) => item.deviceToken), ['token-a', 'token-b']);
  final encoded = await const FlutterSecureStorage().read(
    key: SecureAccountSessionStore.storageKey,
  );
  expect(encoded, isNot(contains('password')));
});

test('invalid entry is isolated while valid entries survive', () async {
  FlutterSecureStorage.setMockInitialValues({
    SecureAccountSessionStore.storageKey:
        '[{"bad":true},${jsonEncode(_sessionJson('account-a', 'token-a'))}]',
  });
  final restored = await const SecureAccountSessionStore(
    FlutterSecureStorage(),
  ).readAll();
  expect(restored.single.account.id, 'account-a');
});
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_session_store_test.dart
```

Expected: FAIL because the session model and store do not exist.

- [ ] **Step 3: Implement the minimal versioned model and store**

```dart
enum AccountSessionAvailability { ready, reauthenticationRequired }

final class AccountSession {
  const AccountSession({
    required this.account,
    required this.deviceToken,
    required this.availability,
    required this.updatedAt,
  });

  final LinkedTradingAccount account;
  final String? deviceToken;
  final AccountSessionAvailability availability;
  final DateTime updatedAt;

  factory AccountSession.ready({
    required LinkedTradingAccount account,
    required String deviceToken,
    required DateTime updatedAt,
  }) => AccountSession(
    account: account,
    deviceToken: deviceToken.trim(),
    availability: AccountSessionAvailability.ready,
    updatedAt: updatedAt.toUtc(),
  );

  bool get canSwitch =>
      availability == AccountSessionAvailability.ready &&
      deviceToken != null &&
      deviceToken!.trim().isNotEmpty;

  AccountSession markReauthenticationRequired() => AccountSession(
    account: account,
    deviceToken: null,
    availability: AccountSessionAvailability.reauthenticationRequired,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'account': account.toJson(),
    'deviceToken': deviceToken,
    'availability': availability.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

abstract interface class AccountSessionStore {
  Future<List<AccountSession>> readAll();
  Future<void> writeAll(List<AccountSession> sessions);
}
```

Use storage key `ex_v2_account_sessions_v1`. Reject an invalid top-level payload with `FormatException`; skip only malformed individual entries so one corrupt account cannot remove valid accounts. Normalize non-empty tokens with `trim()` and enforce that `ready` sessions have a token.

- [ ] **Step 4: Run focused verification**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_session_store_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: all three commands succeed.

- [ ] **Step 5: Commit only Task 1 files**

```powershell
git add -- mobile/lib/features/account_sessions/domain/account_session.dart mobile/lib/features/account_sessions/data/account_session_store.dart mobile/test/account_session_store_test.dart
git commit -m "feat: add secure account session storage"
```

---

### Task 2: Session registry, active-account migration, and catalog merge

**Files:**
- Create: `mobile/lib/features/account_sessions/application/account_session_registry.dart`
- Create: `mobile/lib/features/account_sessions/application/account_catalog_merge.dart`
- Create: `mobile/test/account_session_registry_test.dart`
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart:587-720`
- Modify: `mobile/test/ex_v2_account_provider_test.dart`

**Interfaces:**
- Consumes: `AccountSessionStore`, `deviceTokenStoreProvider`, `exV2AccountProvider`, `LinkedTradingAccount`, and the current `/mobile/accounts` controller.
- Produces: `accountSessionRegistryProvider`, `AccountSessionRegistryController.upsert(AccountSession)`, `markReauthenticationRequired(String)`, `sessionFor(String)`, and `List<LinkedTradingAccount> mergeAccountCatalog({required String activeAccountId, required List<LinkedTradingAccount> remoteAccounts, required List<AccountSession> localSessions})`.

- [ ] **Step 1: Write failing registry and merge tests**

```dart
test('upsert preserves another account and replaces only matching id', () async {
  final registry = _registryWith([
    _session('account-a', token: 'token-a'),
    _session('account-b', token: 'token-old'),
  ]);
  await registry.upsert(_session('account-b', token: 'token-new'));
  final sessions = await registry.read();
  expect(sessions.singleWhere((s) => s.account.id == 'account-a').deviceToken,
      'token-a');
  expect(sessions.singleWhere((s) => s.account.id == 'account-b').deviceToken,
      'token-new');
});

test('empty server list keeps local sessions with active account first', () {
  final merged = mergeAccountCatalog(
    activeAccountId: 'account-b',
    remoteAccounts: const [],
    localSessions: [
      _session('account-a', token: 'token-a'),
      _session('account-b', token: 'token-b'),
    ],
  );
  expect(merged.map((item) => item.id), ['account-b', 'account-a']);
});
```

Add a provider test where an existing active bootstrap plus current global token migrates to one local session, and a second rebuild does not duplicate or replace a newer saved token.

- [ ] **Step 2: Run the tests and confirm RED**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_session_registry_test.dart test/ex_v2_account_provider_test.dart
```

Expected: FAIL because registry and merge APIs are absent.

- [ ] **Step 3: Implement registry and idempotent migration**

```dart
final accountSessionRegistryProvider = AsyncNotifierProvider<
    AccountSessionRegistryController, List<AccountSession>>(
  AccountSessionRegistryController.new,
  retry: (_, _) => null,
);

final class AccountSessionRegistryController
    extends AsyncNotifier<List<AccountSession>> {
  @override
  Future<List<AccountSession>> build() async {
    final stored = await ref.read(accountSessionStoreProvider).readAll();
    final active = ref.watch(exV2AccountProvider).value;
    final token = await ref.read(deviceTokenStoreProvider).read();
    return _migrateActiveSession(stored, active, token);
  }

  Future<void> upsert(AccountSession session) async {
    final current = state.value ??
        await ref.read(accountSessionStoreProvider).readAll();
    final next = <AccountSession>[
      for (final item in current)
        if (item.account.id != session.account.id) item,
      session,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await ref.read(accountSessionStoreProvider).writeAll(next);
    state = AsyncData(List.unmodifiable(next));
  }

  Future<void> markReauthenticationRequired(String accountId) async {
    final current = state.value ??
        await ref.read(accountSessionStoreProvider).readAll();
    final next = [
      for (final item in current)
        item.account.id == accountId
            ? item.markReauthenticationRequired()
            : item,
    ];
    await ref.read(accountSessionStoreProvider).writeAll(next);
    state = AsyncData(List.unmodifiable(next));
  }

  AccountSession? sessionFor(String accountId) {
    for (final session in state.value ?? const <AccountSession>[]) {
      if (session.account.id == accountId) return session;
    }
    return null;
  }
}
```

Migration must use bootstrap identity plus `ExV2AccountPresentation` broker/server metadata, must be idempotent, and must never overwrite an existing non-empty session token with an older global token.

Implement `mergeAccountCatalog` as a pure function. Local authenticated metadata wins for duplicate account IDs, server-only accounts remain visible, `isActive` is recomputed from `activeAccountId`, and active is always first.

Update `LinkedTradingAccountsController.build()` to merge registry sessions even when `/mobile/accounts` returns `[]`. Do not write an empty successful response over a non-empty linked-account metadata cache.

- [ ] **Step 4: Run focused verification**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_session_store_test.dart test/account_session_registry_test.dart test/ex_v2_account_provider_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: all commands succeed; the server-empty test renders local accounts.

- [ ] **Step 5: Commit only Task 2 files**

```powershell
git add -- mobile/lib/features/account_sessions/application/account_session_registry.dart mobile/lib/features/account_sessions/application/account_catalog_merge.dart mobile/lib/shared/providers/demo_data_provider.dart mobile/test/account_session_registry_test.dart mobile/test/ex_v2_account_provider_test.dart
git commit -m "feat: restore remembered account catalog"
```

---

### Task 3: Atomic authentication commit and initial-login integration

**Files:**
- Create: `mobile/lib/features/account_sessions/application/account_switch_guard.dart`
- Create: `mobile/lib/features/account_sessions/application/account_session_committer.dart`
- Create: `mobile/test/account_session_committer_test.dart`
- Modify: `mobile/lib/features/account_login/application/account_password_login_controller.dart:27-125`
- Modify: `mobile/test/account_password_login_controller_test.dart`

**Interfaces:**
- Consumes: `AccountPasswordLoginResult`, `AccountSessionRegistryController`, `DeviceTokenStore`, `ExV2AccountController.publishBootstrap`, and the presentation mapper fields returned by login.
- Produces: `AccountSwitchGuard.tryAcquire()`, `AccountSwitchLease.authority`, `AccountSessionCommitter.commit(AccountPasswordLoginResult)`, and `accountSessionCommitterProvider`.

- [ ] **Step 1: Write failing transaction tests**

```dart
test('commit stores session, writes active token, then publishes bootstrap', () async {
  final result = await fixture.commit(_loginResult('account-b', 'token-b'));
  expect(result, ExV2BootstrapPublication.committed);
  expect(fixture.events, ['session:account-b', 'token:token-b', 'publish:account-b']);
});

test('rejected publication restores previous active token', () async {
  fixture.tokenStore.value = 'token-a';
  fixture.publisher.result = ExV2BootstrapPublication.rejectedStale;
  final result = await fixture.commit(_loginResult('account-b', 'token-b'));
  expect(result, ExV2BootstrapPublication.rejectedStale);
  expect(fixture.tokenStore.value, 'token-a');
});

test('guard refuses a second account switch while one is active', () {
  final first = guard.tryAcquire();
  expect(first, isNotNull);
  expect(guard.tryAcquire(), isNull);
  guard.release(first!);
});
```

Extend `account_password_login_controller_test.dart` to assert successful login stores the returned session and that a failed/rejected commit restores the old token instead of deleting it.

- [ ] **Step 2: Run the tests and confirm RED**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_session_committer_test.dart test/account_password_login_controller_test.dart
```

Expected: FAIL because the committer and guard do not exist and login still writes the global token directly.

- [ ] **Step 3: Implement one atomic commit path**

```dart
final class AccountSwitchInProgress implements Exception {
  const AccountSwitchInProgress();
}

final class AccountSwitchLease {
  const AccountSwitchLease(this.authority);
  final int authority;
}

final class AccountSwitchGuard {
  var _nextAuthority = 0;
  AccountSwitchLease? _active;

  AccountSwitchLease? tryAcquire() {
    if (_active != null) return null;
    return _active = AccountSwitchLease(++_nextAuthority);
  }

  void release(AccountSwitchLease lease) {
    if (identical(_active, lease)) _active = null;
  }
}

final accountSwitchGuardProvider = Provider<AccountSwitchGuard>(
  (ref) => AccountSwitchGuard(),
);

abstract interface class AccountSessionCommitter {
  Future<ExV2BootstrapPublication> commit(AccountPasswordLoginResult result);
}

final class SecureAccountSessionCommitter implements AccountSessionCommitter {
  const SecureAccountSessionCommitter({
    required this.guard,
    required this.registry,
    required this.tokenStore,
    required this.publisher,
  });

  final AccountSwitchGuard guard;
  final AccountSessionRegistryController registry;
  final DeviceTokenStore tokenStore;
  final ExV2AccountController publisher;

  @override
  Future<ExV2BootstrapPublication> commit(
    AccountPasswordLoginResult result,
  ) async {
    final lease = guard.tryAcquire();
    if (lease == null) throw const AccountSwitchInProgress();
    final previousToken = await tokenStore.read();
    try {
      await registry.upsert(AccountSession.ready(
        account: result.account,
        deviceToken: result.deviceToken,
        updatedAt: DateTime.now().toUtc(),
      ));
      await tokenStore.write(result.deviceToken);
      final publication = publisher.publishBootstrap(
        result.bootstrap,
        operationAuthority: lease.authority,
        authoritativeAccountSwitch: true,
        presentation: ExV2AccountPresentation(
          brokerId: result.account.brokerId,
          companyName: result.account.brokerName,
          serverId: result.account.serverId,
          tradingServer: result.account.serverName,
        ),
      );
      if (publication == ExV2BootstrapPublication.rejectedStale) {
        await _restoreToken(previousToken);
      }
      return publication;
    } catch (_) {
      await _restoreToken(previousToken);
      rethrow;
    } finally {
      guard.release(lease);
    }
  }

  Future<void> _restoreToken(String? previousToken) => previousToken == null
      ? tokenStore.delete()
      : tokenStore.write(previousToken);
}

final accountSessionCommitterProvider = Provider<AccountSessionCommitter>(
  (ref) => SecureAccountSessionCommitter(
    guard: ref.watch(accountSwitchGuardProvider),
    registry: ref.read(accountSessionRegistryProvider.notifier),
    tokenStore: ref.watch(deviceTokenStoreProvider),
    publisher: ref.read(exV2AccountProvider.notifier),
  ),
);
```

Replace direct `deviceTokenStoreProvider.write/delete` logic in `AccountPasswordLoginController.submit()` with `accountSessionCommitterProvider.commit(result)`. Preserve current safe error messages, duplicate-submit prevention, password handling, and `stale_bootstrap` behavior.

- [ ] **Step 4: Run focused verification**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_session_committer_test.dart test/account_password_login_controller_test.dart test/account_password_login_screen_test.dart test/device_gate_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: all commands succeed and no test observes deletion of a valid previous token.

- [ ] **Step 5: Commit only Task 3 files**

```powershell
git add -- mobile/lib/features/account_sessions/application/account_switch_guard.dart mobile/lib/features/account_sessions/application/account_session_committer.dart mobile/lib/features/account_login/application/account_password_login_controller.dart mobile/test/account_session_committer_test.dart mobile/test/account_password_login_controller_test.dart
git commit -m "feat: commit account authentication atomically"
```

---

### Task 4: Capture a per-account token through the existing add-account UI

**Files:**
- Modify: `mobile/lib/features/account_link/application/account_link_controller.dart:1-260`
- Modify: `mobile/test/account_link_controller_test.dart`
- Modify: `mobile/test/account_link_cross_tab_video_test.dart`
- Modify: `mobile/test/account_link_login_video_test.dart`

**Interfaces:**
- Consumes: the selected `MobileBroker`, `MobileTradingServer`, login/password already held only in `AccountLinkState`, `accountPasswordLoginRepositoryProvider`, `installationIdStoreProvider`, and `accountSessionCommitterProvider`.
- Produces: the same public `AccountLinkController.submit()` result and the same visible add-account flow, plus a persisted per-account session token.

- [ ] **Step 1: Write failing add-account session tests**

```dart
test('existing account submit authenticates once and stores its own session', () async {
  controller.selectBroker(_broker);
  controller.selectServer(_server);
  controller.updateLogin('109740422');
  controller.updatePassword('secret-used-only-for-request');

  final result = await controller.submit();

  expect(result?.account.id, 'account-b');
  expect(loginRepository.requests.single.brokerId, _broker.id);
  expect(loginRepository.requests.single.serverId, _server.id);
  expect(committer.results.single.deviceToken, 'token-b');
  expect(controllerState.password, isEmpty);
});

test('authentication identity mismatch keeps account A active', () async {
  loginRepository.result = _loginResult('different-account', 'token-x');
  final result = await controller.submit();
  expect(result, isNull);
  expect(tokenStore.value, 'token-a');
  expect(controllerState.phase, AccountLinkPhase.failed);
});
```

The widget regression test must still find the same broker header, server selector, login/password rows, save-password control, and `existing-account-login-button`; no geometry or copy changes are permitted.

- [ ] **Step 2: Run the tests and confirm RED**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_link_controller_test.dart test/account_link_cross_tab_video_test.dart test/account_link_login_video_test.dart
```

Expected: FAIL because the add-account flow does not obtain or commit a per-account device token.

- [ ] **Step 3: Add token capture without persisting the password**

Keep broker discovery, server selection, presentation storage, server link, and reconnect-grant behavior. Before clearing the in-memory password, call `/mobile/auth/login` with the selected broker/server/login through `accountPasswordLoginRepositoryProvider`, validate that its stable account ID matches the linked account, then pass the result to `accountSessionCommitterProvider`.

```dart
final class AccountLinkAuthenticationIdentityMismatch implements Exception {
  const AccountLinkAuthenticationIdentityMismatch();
}

final authenticated = await ref.read(accountPasswordLoginRepositoryProvider).login(
  AccountPasswordLoginRequest(
    brokerId: before.selectedBroker!.id,
    serverId: before.selectedServer!.id,
    login: before.login.trim(),
    password: before.password,
  ),
  installationId: await ref.read(installationIdStoreProvider).readOrCreate(),
  metadata: ExV2CommandMetadata.create(),
);
if (authenticated.account.id != linked.account.id) {
  throw const AccountLinkAuthenticationIdentityMismatch();
}
final publication = await ref
    .read(accountSessionCommitterProvider)
    .commit(authenticated);
```

Do not store the password in `AccountSession`, linked-account cache, logs, or reconnect-grant payload. Return `ActivateLinkedAccountResult(account: authenticated.account, bootstrap: authenticated.bootstrap)` so the screen retains its current success navigation contract. Server-only rows continue using the existing activation coordinator later.

- [ ] **Step 4: Run focused verification**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_link_controller_test.dart test/account_link_cross_tab_video_test.dart test/account_link_login_video_test.dart test/account_password_login_controller_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: all commands succeed and the video-parity widget geometry is unchanged.

- [ ] **Step 5: Commit only Task 4 files**

```powershell
git add -- mobile/lib/features/account_link/application/account_link_controller.dart mobile/test/account_link_controller_test.dart mobile/test/account_link_cross_tab_video_test.dart mobile/test/account_link_login_video_test.dart
git commit -m "feat: remember sessions from account login"
```

---

### Task 5: Token-scoped bootstrap switching, expiry handling, and realtime restart

**Files:**
- Create: `mobile/lib/features/account_sessions/data/account_session_bootstrap_loader.dart`
- Create: `mobile/lib/features/account_sessions/application/account_session_switch_coordinator.dart`
- Create: `mobile/test/account_session_switch_coordinator_test.dart`
- Modify: `mobile/lib/features/account_link/application/account_activation_coordinator.dart:1-100`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart:182-240,1495-1545`
- Modify: `mobile/test/account_activation_coordinator_test.dart`
- Modify: `mobile/test/multi_account_switch_test.dart`

**Interfaces:**
- Consumes: `AccountSession`, `ExV2ApiClient`, `ExV2Repository.bootstrap()`, shared `AccountSwitchGuard`, `DeviceTokenStore`, and `ExV2AccountController`.
- Produces: `AccountSessionBootstrapLoader.load(String token)`, `Future<ActivateLinkedAccountResult> AccountSessionSwitchCoordinator.switchTo(String accountId)`, `AccountSessionReauthenticationRequired`, and `ExV2AccountController.restartRealtimeForCurrentToken()`.

- [ ] **Step 1: Write failing switch/rollback tests**

```dart
test('switch validates target token before replacing active state', () async {
  loader.responses['token-b'] = _bootstrap('account-b');
  final outcome = await coordinator.switchTo('account-b');
  expect(outcome.bootstrap.account.id, 'account-b');
  expect(tokenStore.value, 'token-b');
  expect(publisher.activeAccountId, 'account-b');
});

test('401 marks only target session for reauthentication', () async {
  loader.errors['token-b'] = const ExV2RequestFailure(
    statusCode: 401,
    message: 'Expired',
  );
  await expectLater(
    coordinator.switchTo('account-b'),
    throwsA(isA<AccountSessionReauthenticationRequired>()),
  );
  expect(tokenStore.value, 'token-a');
  expect(registry.sessionFor('account-b')!.canSwitch, isFalse);
  expect(publisher.activeAccountId, 'account-a');
});

test('network failure and identity mismatch keep token and state A', () async {
  loader.responses['token-b'] = _bootstrap('wrong-account');
  await expectLater(
    coordinator.switchTo('account-b'),
    throwsA(isA<AccountSessionIdentityMismatch>()),
  );
  expect(tokenStore.value, 'token-a');
  expect(publisher.activeAccountId, 'account-a');
});
```

Add a test that a shared guard prevents a server activation and local-session switch from running concurrently, and a test that accepted token replacement restarts SignalR with the new token reader.

- [ ] **Step 2: Run the tests and confirm RED**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_session_switch_coordinator_test.dart test/account_activation_coordinator_test.dart test/multi_account_switch_test.dart
```

Expected: FAIL because local-session switching and realtime restart APIs do not exist.

- [ ] **Step 3: Implement token-scoped validation and atomic publication**

```dart
final class DioAccountSessionBootstrapLoader
    implements AccountSessionBootstrapLoader {
  DioAccountSessionBootstrapLoader(this.dio);
  final Dio dio;

  @override
  Future<ExV2Bootstrap> load(String token) => ExV2Repository(
    ExV2ApiClient(dio: dio, tokenReader: () async => token),
  ).bootstrap();
}

final accountSessionBootstrapLoaderProvider =
    Provider<AccountSessionBootstrapLoader>(
  (ref) => DioAccountSessionBootstrapLoader(ref.watch(exV2DioProvider)),
);
```

`switchTo` must acquire the shared guard, load bootstrap with the target token before touching the global token, verify requested/session/bootstrap/summary IDs, snapshot the previous token, write the target token, publish with the lease authority and `authoritativeAccountSwitch: true`, restore the previous token if publication is rejected, then restart realtime. Only HTTP 401/403 marks the target session `reauthenticationRequired`; timeouts, 5xx, and format failures retain the ready session for retry.

Define typed failures so UI and tests never inspect raw server text:

```dart
final class AccountSessionIdentityMismatch implements Exception {
  const AccountSessionIdentityMismatch();
}

final class AccountSessionReauthenticationRequired implements Exception {
  const AccountSessionReauthenticationRequired(this.account);
  final LinkedTradingAccount account;
}

final class AccountSessionSwitchRejected implements Exception {
  const AccountSessionSwitchRejected();
}

final accountSessionSwitchCoordinatorProvider = NotifierProvider<
    AccountSessionSwitchCoordinator, bool>(
  AccountSessionSwitchCoordinator.new,
);

final class AccountSessionSwitchCoordinator extends Notifier<bool> {
  @override
  bool build() => false;

  Future<ActivateLinkedAccountResult> switchTo(String accountId) async {
    await ref.read(accountSessionRegistryProvider.future);
    final registry = ref.read(accountSessionRegistryProvider.notifier);
    final session = registry.sessionFor(accountId);
    if (session == null) {
      throw StateError('No saved session for account $accountId');
    }
    if (!session.canSwitch) {
      throw AccountSessionReauthenticationRequired(session.account);
    }
    final lease = ref.read(accountSwitchGuardProvider).tryAcquire();
    if (lease == null) throw const AccountSwitchInProgress();
    state = true;
    var tokenReplaced = false;
    final tokenStore = ref.read(deviceTokenStoreProvider);
    final previousToken = await tokenStore.read();
    try {
      final bootstrap = await ref
          .read(accountSessionBootstrapLoaderProvider)
          .load(session.deviceToken!);
      if (bootstrap.account.id != accountId ||
          bootstrap.summary.accountId != accountId) {
        throw const AccountSessionIdentityMismatch();
      }
      await tokenStore.write(session.deviceToken!);
      tokenReplaced = true;
      final publication = ref.read(exV2AccountProvider.notifier).publishBootstrap(
        bootstrap,
        operationAuthority: lease.authority,
        authoritativeAccountSwitch: true,
        presentation: ExV2AccountPresentation(
          brokerId: session.account.brokerId,
          companyName: session.account.brokerName,
          serverId: session.account.serverId,
          tradingServer: session.account.serverName,
        ),
      );
      if (publication == ExV2BootstrapPublication.rejectedStale) {
        throw const AccountSessionSwitchRejected();
      }
      tokenReplaced = false;
      await ref
          .read(exV2AccountProvider.notifier)
          .restartRealtimeForCurrentToken();
      return ActivateLinkedAccountResult(
        account: session.account,
        bootstrap: bootstrap,
      );
    } on ExV2RequestFailure catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await registry.markReauthenticationRequired(accountId);
        throw AccountSessionReauthenticationRequired(session.account);
      }
      rethrow;
    } finally {
      if (tokenReplaced) {
        if (previousToken == null) {
          await tokenStore.delete();
        } else {
          await tokenStore.write(previousToken);
        }
      }
      ref.read(accountSwitchGuardProvider).release(lease);
      state = false;
    }
  }
}
```

Update `AccountActivationCoordinator.activate()` to use the same guard and lease authority, so a server activation and token switch cannot interleave.

Add:

```dart
Future<void> restartRealtimeForCurrentToken() async {
  await _realtimeSubscription?.cancel();
  _realtimeSubscription = null;
  await _realtimeService?.dispose();
  _realtimeService = null;
  _realtimeStarted = false;
  await _startRealtime();
}
```

Ensure disposal is idempotent and no old-token realtime event can publish after the account generation changes.

- [ ] **Step 4: Run focused verification**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_session_switch_coordinator_test.dart test/account_activation_coordinator_test.dart test/multi_account_switch_test.dart test/ex_v2_account_provider_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: all commands succeed; all error paths retain account A and valid-token success publishes only account B state.

- [ ] **Step 5: Commit only Task 5 files**

```powershell
git add -- mobile/lib/features/account_sessions/data/account_session_bootstrap_loader.dart mobile/lib/features/account_sessions/application/account_session_switch_coordinator.dart mobile/lib/features/account_link/application/account_activation_coordinator.dart mobile/lib/features/account_sync/application/ex_v2_account_provider.dart mobile/test/account_session_switch_coordinator_test.dart mobile/test/account_activation_coordinator_test.dart mobile/test/multi_account_switch_test.dart
git commit -m "feat: switch saved accounts securely"
```

---

### Task 6: Account-screen routing, broker marks, diagnostics cleanup, and device verification

**Files:**
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart:587-760`
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart:1-145`
- Modify: `mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart:15-295`
- Modify: `mobile/lib/app/router.dart:42-63`
- Modify: `mobile/lib/features/profile/domain/account_presentation_profile.dart`
- Modify: `mobile/lib/features/profile/presentation/widgets/account_visuals.dart`
- Modify: `mobile/test/multi_account_switch_test.dart`
- Modify: `mobile/test/account_visuals_test.dart`
- Modify: `mobile/test/account_link_login_video_test.dart`
- Modify: `docs/ex-v2-mobile-integration.md`

**Interfaces:**
- Consumes: merged linked/session account catalog and `AccountSessionSwitchCoordinator.switchTo`.
- Produces: unchanged Account-screen layout, session-backed tap switching, expired-session reauthentication through the existing add-account screen, and updated integration documentation.

- [ ] **Step 1: Write failing widget regressions**

```dart
testWidgets('empty mobile accounts API still renders all saved sessions', (tester) async {
  final fixture = await _pumpProductionRoute(
    tester,
    initialLocation: '/profile',
    remoteAccounts: const [],
    sessions: [_sessionA, _sessionB],
  );
  expect(find.byKey(const ValueKey('account-account-a')), findsOneWidget);
  expect(find.byKey(const ValueKey('account-account-b')), findsOneWidget);
});

testWidgets('tapping a ready saved account switches without login form', (tester) async {
  await tester.tap(find.byKey(const ValueKey('account-account-b')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('existing-account-login-screen')), findsNothing);
  expect(fixture.activeAccountId, 'account-b');
});

testWidgets('expired saved account opens existing login with login prefilled', (tester) async {
  await tester.tap(find.byKey(const ValueKey('account-account-b')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('existing-account-login-screen')), findsOneWidget);
  expect(
    tester.widget<TextField>(find.byKey(const Key('existing-account-login-field')))
        .controller!
        .text,
    '109740422',
  );
  expect(find.byKey(const Key('existing-account-password-field')), findsOneWidget);
});
```

Retain tests asserting MetaQuotes uses `metaquotes-broker-mark-raster`, Exness uses its wordmark, and an unknown broker uses the neutral non-broken fallback.

- [ ] **Step 2: Run the tests and confirm RED**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/multi_account_switch_test.dart test/account_visuals_test.dart test/account_link_login_video_test.dart
```

Expected: FAIL because Profile still sends every inactive row to server activation and the login screen cannot prefill a remembered account.

- [ ] **Step 3: Route session rows through the switch coordinator**

In `LinkedTradingAccountsController.activate`, use the registry session when one exists and is ready; otherwise retain the current server activation path. Convert a successful local switch to the existing `ActivateLinkedAccountResult` return shape so `ProfileScreen` navigation remains unchanged.

Catch `AccountSessionReauthenticationRequired` separately in `ProfileScreen` and push the existing broker login route with encoded query parameters:

```dart
final uri = Uri(
  path: '/accounts/add/${failure.account.brokerId}',
  queryParameters: <String, String>{
    'login': failure.account.login,
    'serverId': failure.account.serverId,
  },
);
context.push(uri.toString());
```

Extend `ExistingAccountLoginScreen` with optional `initialLogin` and `initialServerId`; preselect them after catalog/server loading without changing widget sizes, labels, colors, or ordering. The router reads only those two query parameters and never receives a password.

Remove the temporary `[linked-accounts-diagnostic]` `debugPrint` calls and any now-unused `foundation.dart` import. Keep the existing shared broker resolver/marks, adding only missing metadata normalization proven by the widget tests.

Update `docs/ex-v2-mobile-integration.md` from “one device token” to the encrypted per-account registry, one-time reauthentication rule, target-token bootstrap validation, and no-password guarantee.

- [ ] **Step 4: Run security and focused checks**

```powershell
rg -n "linked-accounts-diagnostic|debugPrint.*token|print.*token|password.*storage" lib test
D:\toolchains\flutter\bin\flutter.bat test test/account_session_store_test.dart test/account_session_registry_test.dart test/account_session_committer_test.dart test/account_session_switch_coordinator_test.dart test/account_password_login_controller_test.dart test/account_link_controller_test.dart test/account_activation_coordinator_test.dart test/ex_v2_account_provider_test.dart test/multi_account_switch_test.dart test/account_visuals_test.dart test/account_link_login_video_test.dart
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: `rg` finds no diagnostic or secret logging pattern; tests, analyzer, and build succeed.

- [ ] **Step 5: Run full Flutter verification**

```powershell
D:\toolchains\flutter\bin\flutter.bat test --concurrency=1
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: full suite passes. If an already-existing unrelated test remains red, record its exact test name and failure while keeping all account-session tests green.

- [ ] **Step 6: Install without clearing data and smoke-test on LDPlayer**

```powershell
D:\LDPlayer\LDPlayer9\adb.exe -s emulator-5560 install -r build\app\outputs\flutter-apk\app-debug.apk
D:\LDPlayer\LDPlayer9\adb.exe -s emulator-5560 shell am force-stop com.tradingdemo.trading_mobile
D:\LDPlayer\LDPlayer9\adb.exe -s emulator-5560 shell monkey -p com.tradingdemo.trading_mobile -c android.intent.category.LAUNCHER 1
```

Verify manually without exposing credentials: authenticate two demo accounts once through the unchanged add-account UI, open **Cài đặt → Tài khoản**, confirm both real rows and correct broker marks, cold restart, then switch A → B → A without entering a password. Confirm positions, orders, wallet, history, and settings all follow the selected account.

- [ ] **Step 7: Commit only Task 6 files**

```powershell
git add -- mobile/lib/shared/providers/demo_data_provider.dart mobile/lib/features/profile/presentation/screens/profile_screen.dart mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart mobile/lib/app/router.dart mobile/lib/features/profile/domain/account_presentation_profile.dart mobile/lib/features/profile/presentation/widgets/account_visuals.dart mobile/test/multi_account_switch_test.dart mobile/test/account_visuals_test.dart mobile/test/account_link_login_video_test.dart docs/ex-v2-mobile-integration.md
git commit -m "fix: restore and switch remembered accounts"
```

---

## Final Acceptance Checklist

- [ ] `/mobile/accounts == []` does not remove or hide locally authenticated accounts.
- [ ] Each account owns its own encrypted opaque token; no password is persisted.
- [ ] Cold restart restores all remembered account rows and broker marks.
- [ ] Ready sessions switch without a password and publish no state from the previous account.
- [ ] 401/403 keeps the row, marks only that session for reauthentication, and preserves the active account.
- [ ] Network, malformed response, identity mismatch, stale publication, and concurrent switch paths all rollback safely.
- [ ] Temporary diagnostic logs are removed.
- [ ] Focused tests, full tests, analyzer, APK build, install, and LDPlayer smoke test are complete.
