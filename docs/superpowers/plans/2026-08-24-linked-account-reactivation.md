# Linked Account Reactivation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore production-compatible `link → activate` behavior so an unlinked saved account asks for its password once, then switches without another password prompt.

**Architecture:** Keep the device login gate on `/mobile/auth/login`, but make the existing-account form call `/mobile/accounts/link` and then the existing `AccountActivationCoordinator`. Treat server activation as the authority for every account switch; translate only `404 account_not_found` into a typed relink route while leaving the current account untouched.

**Tech Stack:** Flutter 3, Dart, Riverpod, GoRouter, `flutter_secure_storage`, EX V2 REST client, Flutter widget/unit tests, .NET backend verification.

**Spec:** `docs/superpowers/specs/2026-08-24-linked-account-reactivation-design.md`

## Global Constraints

- Do not change the required technology stack, base URL, or production backend contract.
- Do not store or log passwords, device tokens, Authorization headers, or reconnect grants.
- Preserve the active account and bootstrap on every failed or stale operation.
- Only `404` with normalized code `account_not_found` opens relink; other failures stay retryable errors.
- Only exact legacy sentinels `unknown-broker` and `unknown-server` may map to the configured reference route.
- Use TDD for every behavior change and run build, analyze, and relevant tests after the task.

---

### Task 1: Restore account linking and activation in the existing-account form

**Files:**
- Modify: `mobile/test/account_link_controller_test.dart`
- Modify: `mobile/lib/features/account_link/application/account_link_controller.dart`

**Interfaces:**
- Consumes: `AccountLinkRepository.link(LinkAccountRequest, {required ExV2CommandMetadata metadata})`, `AccountActivationCoordinator.activate(String, {required ExV2CommandMetadata metadata})`, `AccountReconnectGrantStore`, and `LinkedAccountPresentationStore`.
- Produces: unchanged `Future<ActivateLinkedAccountResult?> AccountLinkController.submit({ExV2CommandMetadata? loginMetadata})`, with link-first semantics and activation-only retry state.

- [ ] **Step 1: Replace auth-session expectations with failing link-first tests**

Add tests that assert the repository receives the exact selected IDs, numeric login, raw password, and `savePassword`, while `AccountPasswordLoginRepository` and `AccountSessionCommitter` receive no calls:

```dart
test('submit links credentials then activates the canonical account', () async {
  final repository = _FakeRepository();
  final harness = await _harness(repository: repository);
  addTearDown(harness.dispose);

  final result = await harness.controller.submit();

  expect(repository.linkRequests.single.toJson(), {
    'brokerId': 'broker-1',
    'serverId': 'server-1',
    'login': '100001',
    'password': 'transient-password',
    'savePassword': true,
  });
  expect(repository.activatedAccountIds, ['account-1']);
  expect(harness.loginRepository.requests, isEmpty);
  expect(harness.committer.results, isEmpty);
  expect(result?.account.id, 'account-1');
});
```

Add focused tests for `savePassword: true` writing the grant, `savePassword: false` deleting an old grant, invalid credentials clearing only password, and link identity mismatch skipping activation.

- [ ] **Step 2: Run the controller tests and verify RED**

Run:

```powershell
Set-Location mobile
flutter test test/account_link_controller_test.dart
```

Expected: failures show `linkCalls == 0`, login repository calls present, or no activation call.

- [ ] **Step 3: Implement minimal link-first submission**

Remove `accountPasswordLoginRepositoryProvider`, `installationIdStoreProvider`, and `accountSessionCommitterProvider` from `AccountLinkController.submit()`. Link and verify identity before persisting presentation or activating:

```dart
final linked = await ref.read(accountLinkRepositoryProvider).link(
  LinkAccountRequest(
    brokerId: before.selectedBroker!.id,
    serverId: before.selectedServer!.id,
    login: before.login.trim(),
    password: before.password,
    savePassword: before.savePassword,
  ),
  metadata: loginMetadata ?? ExV2CommandMetadata.create(),
);
_verifyLinkedIdentity(linked.account, before);
await _persistGrant(linked, savePassword: before.savePassword);
await ref.read(linkedAccountPresentationStoreProvider).write(
  linked.account.id,
  presentationForSelectedServer(
    before.selectedBroker!,
    before.selectedServer!,
  ),
);
final activation = await ref
    .read(accountActivationCoordinatorProvider.notifier)
    .activate(linked.account.id, metadata: ExV2CommandMetadata.create());
```

Keep `_operationInFlight`; clear password after link response; only return success when `activation.accepted` is true.

- [ ] **Step 4: Add activation-only retry behavior**

Store the just-linked stable account in the existing `AccountLinkState.linkedAccount` field when activation fails. At the start of `submit`, check this retry candidate before `canSubmit`; if the selected broker/server/login still match that account, skip password validation and `link`, then retry the coordinator activation. Clear `linkedAccount` in `selectBroker`, `selectServer`, and `updateLogin` so edited credentials cannot activate a stale candidate.

Add a test:

```dart
test('activation retry does not link again or require password', () async {
  final repository = _FakeRepository(failFirstActivation: true);
  final harness = await _harness(repository: repository);
  addTearDown(harness.dispose);

  expect(await harness.controller.submit(), isNull);
  expect(harness.state.password, isEmpty);
  final result = await harness.controller.submit();

  expect(repository.linkCalls, 1);
  expect(repository.activateCalls, 2);
  expect(result?.account.id, 'account-1');
});
```

- [ ] **Step 5: Run controller and account-link UI tests and verify GREEN**

Run:

```powershell
Set-Location mobile
flutter test test/account_link_controller_test.dart test/account_link_login_video_test.dart test/account_link_repository_test.dart test/account_activation_coordinator_test.dart
```

Expected: all tests pass without analyzer warnings.

- [ ] **Step 6: Commit the account-link change**

```powershell
git add -- mobile/lib/features/account_link/application/account_link_controller.dart mobile/test/account_link_controller_test.dart mobile/test/account_link_login_video_test.dart
git commit -m "fix: link existing accounts before activation"
```

---

### Task 2: Make server activation authoritative and surface typed relink recovery

**Files:**
- Modify: `mobile/test/multi_account_switch_test.dart`
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart`

**Interfaces:**
- Consumes: `AccountActivationCoordinator.activate` and `ExV2RequestFailure`.
- Produces: `AccountRelinkRequired(LinkedTradingAccount account)` and server-first `LinkedTradingAccountsController.activate(String accountId)`.

- [ ] **Step 1: Write failing server-first switch tests**

Change the ready-session test so it expects one REST activation and zero local session-switch calls. Add an adapter mode returning `404 account_not_found` and assert the active bootstrap remains account A.

```dart
testWidgets('saved account uses authoritative server activation', (tester) async {
  final switcher = _RecordingSessionSwitcher();
  final fixture = await _pumpProductionRoute(
    tester,
    initialLocation: '/profile',
    sessions: [_readySessionB()],
    sessionSwitcher: switcher,
  );
  addTearDown(fixture.dispose);

  await tester.tap(find.byKey(const ValueKey('account-account-b')));
  await tester.pumpAndSettle();

  expect(fixture.adapter.activationCalls, 1);
  expect(switcher.calls, isEmpty);
});
```

Add unit/widget coverage showing non-generic metadata and expired local sessions also try activation; remove tests that expect local token bootstrap to decide switch authority.

- [ ] **Step 2: Run the switch tests and verify RED**

Run:

```powershell
Set-Location mobile
flutter test test/multi_account_switch_test.dart
```

Expected: ready non-generic sessions call the local switch coordinator instead of REST activation, and `account_not_found` renders a generic snackbar.

- [ ] **Step 3: Introduce typed relink failure**

Define next to the linked account controller:

```dart
final class AccountRelinkRequired implements Exception {
  const AccountRelinkRequired(this.account);
  final LinkedTradingAccount account;
}
```

Normalize the error code with lowercase and hyphen-to-underscore conversion. Translate only:

```dart
if (error.statusCode == 404 && normalizedCode == 'account_not_found') {
  throw AccountRelinkRequired(
    _routableReauthenticationAccount(targetAccount, loginConfig),
  );
}
```

- [ ] **Step 4: Simplify switching to one server activation path**

Remove branching on `AccountSession.canSwitch`, per-account device tokens, `AccountSessionSwitchCoordinator`, and broad generic metadata. Resolve the target from the visible catalog, call the activation coordinator, and return only accepted results.

Tighten legacy routing:

```dart
bool _hasLegacyGenericRoute(LinkedTradingAccount account) =>
    account.brokerId.trim().toLowerCase() == 'unknown-broker' &&
    account.serverId.trim().toLowerCase() == 'unknown-server';
```

Do not map 401/403 to an account password error. Let the device-session failure propagate to its dedicated UI handling.

Before rethrowing a 401/403 activation failure, invalidate `exV2AccountProvider`. Its next bootstrap uses the same token, exposes the authentication failure to `DeviceGate`, and the existing “Đăng nhập lại” action clears the expired device token safely.

- [ ] **Step 5: Run switch, activation, registry, and session regression tests**

Run:

```powershell
Set-Location mobile
flutter test test/multi_account_switch_test.dart test/account_activation_coordinator_test.dart test/account_session_registry_test.dart test/account_session_store_test.dart test/account_session_switch_coordinator_test.dart
```

Expected: all pass; retained session-store tests still validate migration/cache behavior independently.

- [ ] **Step 6: Commit the authoritative switch change**

```powershell
git add -- mobile/lib/shared/providers/demo_data_provider.dart mobile/test/multi_account_switch_test.dart
git commit -m "fix: recover unlinked accounts through server activation"
```

---

### Task 3: Route relink and device-session failures correctly

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- Modify: `mobile/test/multi_account_switch_test.dart`

**Interfaces:**
- Consumes: `AccountRelinkRequired.account` and existing GoRouter account-add route query parameters.
- Produces: deterministic relink navigation with an empty password field; generic failures remain snackbar errors.

- [ ] **Step 1: Write failing route tests**

Add a widget test where activation returns `404 account_not_found` and assert:

```dart
expect(fixture.router.state.uri.path, '/accounts/add/broker-second');
expect(fixture.router.state.uri.queryParameters['login'], 'LOGIN-A');
expect(fixture.router.state.uri.queryParameters['serverId'], 'server-b');
expect(find.byKey(const Key('existing-account-login-screen')), findsOneWidget);
expect(find.byKey(const Key('existing-account-password-field')), findsOneWidget);
expect(
  tester.widget<TextField>(
    find.byKey(const Key('existing-account-password-field')),
  ).controller?.text,
  isEmpty,
);
```

Add a separate test proving `500`, `409`, and unrelated `404` do not navigate away and keep account A active.

- [ ] **Step 2: Run route tests and verify RED**

Run:

```powershell
Set-Location mobile
flutter test test/multi_account_switch_test.dart
```

Expected: `account_not_found` currently stays on Profile with a snackbar.

- [ ] **Step 3: Handle `AccountRelinkRequired` in Profile**

Replace the account-session-specific relogin catch with a typed relink catch and reuse a small route builder:

```dart
} on AccountRelinkRequired catch (failure) {
  if (!context.mounted) return;
  context.push(Uri(
    path: '/accounts/add/${failure.account.brokerId}',
    queryParameters: {
      'login': failure.account.login,
      'serverId': failure.account.serverId,
    },
  ).toString());
}
```

Keep 409/5xx/timeouts in the existing safe snackbar branch. The controller invalidation from Task 2 makes `DeviceGate` own device-level 401/403; Profile must not convert those errors into the add-account password route.

- [ ] **Step 4: Run route and login-screen regression tests**

Run:

```powershell
Set-Location mobile
flutter test test/multi_account_switch_test.dart test/account_link_login_video_test.dart test/account_password_login_screen_test.dart test/device_gate_test.dart
```

Expected: all pass, password starts empty, and account A remains published on relink/error.

- [ ] **Step 5: Commit the routing change**

```powershell
git add -- mobile/lib/features/profile/presentation/screens/profile_screen.dart mobile/test/multi_account_switch_test.dart
git commit -m "fix: route missing account links to credential recovery"
```

---

### Task 4: Review the implementation against the approved spec

**Files:**
- Review: `mobile/lib/features/account_link/application/account_link_controller.dart`
- Review: `mobile/lib/shared/providers/demo_data_provider.dart`
- Review: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- Review: all tests changed in Tasks 1–3

**Interfaces:**
- Consumes: completed link, activation, relink, and routing behavior.
- Produces: a minimal follow-up patch only if review finds a concrete spec or safety defect.

- [ ] **Step 1: Run a focused diff review**

Inspect:

```powershell
git diff --check
git diff -- mobile/lib/features/account_link/application/account_link_controller.dart mobile/lib/shared/providers/demo_data_provider.dart mobile/lib/features/profile/presentation/screens/profile_screen.dart mobile/test/account_link_controller_test.dart mobile/test/multi_account_switch_test.dart
```

Confirm password/grant/token values are not logged, all failures preserve the old account, and no unrelated UI or market code changed.

- [ ] **Step 2: Run reviewer skill and address only verified findings**

Use `superpowers:requesting-code-review`. Any accepted behavior fix must start with a failing test and complete a RED/GREEN cycle.

- [ ] **Step 3: Run the focused suite after review**

```powershell
Set-Location mobile
flutter test test/account_link_controller_test.dart test/account_link_repository_test.dart test/account_activation_coordinator_test.dart test/multi_account_switch_test.dart test/account_session_registry_test.dart test/account_session_store_test.dart test/account_session_switch_coordinator_test.dart test/account_link_login_video_test.dart test/device_gate_test.dart
```

Expected: all tests pass.

---

### Task 5: Full verification and production emulator smoke test

**Files:**
- Verify only; no production file changes unless a failing test exposes a scoped defect.

**Interfaces:**
- Consumes: completed implementation.
- Produces: analyzer, full test, build, installation, and smoke-test evidence.

- [ ] **Step 1: Run Flutter format, analyze, and full tests**

```powershell
Set-Location mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Expected: format clean, analyzer reports no issues, full suite passes.

- [ ] **Step 2: Build the mobile app**

```powershell
Set-Location mobile
flutter build apk --debug
```

Expected: `build/app/outputs/flutter-apk/app-debug.apk` is produced successfully.

- [ ] **Step 3: Run backend build and tests**

Run the checked-in backend solution:

```powershell
dotnet build backend/Trading.sln
dotnet test backend/Trading.sln --no-build
```

Expected: zero build errors and all relevant backend tests pass.

- [ ] **Step 4: Install without clearing emulator data**

```powershell
adb -s emulator-5560 install -r mobile/build/app/outputs/flutter-apk/app-debug.apk
```

Expected: `Success`; do not run `pm clear` or uninstall.

- [ ] **Step 5: Smoke test the production flow**

Open Settings → Accounts, select the previously unlinked account, confirm the app opens the prefilled existing-account form with an empty password, enter the user-provided password once, and confirm link plus activation succeeds. Then switch A → B → A without another password prompt and cold-restart the app to confirm the list and switch behavior persist.

If credentials are unavailable to automation, verify every step up to the password boundary and report that final credential-dependent activation as externally blocked without exposing or requesting the secret in logs.

- [ ] **Step 6: Apply verification-before-completion**

Use `superpowers:verification-before-completion`, cite the exact commands and outcomes, and do not claim the bug fixed if production smoke still returns `account_not_found`, `invalid_credentials`, or another error.
