# Account/Password Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the visible EX V2 device-token activation gate with a two-field account/password login that calls the new backend login endpoint, stores the returned token internally, publishes canonical bootstrap, and opens Trade.

**Architecture:** Add a focused `account_login` feature with request/result models, a repository, controller, and screen. Extend the existing EX V2 client with one narrowly scoped unauthenticated login call carrying installation/correlation/idempotency headers; all other calls continue requiring the stored device token. `DeviceGate` remains the session/bootstrap authority but renders account/password login when the session is missing or rejected.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, GoRouter, Dio, Flutter Secure Storage, flutter_test.

## Global Constraints

- Do not modify `D:/mt5New/backend`; it is not the deployed EX V2 service.
- Do not change `https://trochoi.top/ex/v2/api` or append duplicate API prefixes.
- Primary login UI contains only Login and Password; device token, broker selection, and server selection stay hidden.
- Login target IDs are typed configuration values: `yodo-demo` and `yodo-demo-01`.
- Password travels unchanged from `TextEditingController` to JSON; never trim, hash, lowercase, normalize, log, persist, or echo it.
- Login request does not send `X-Device-Token`; it must send `X-Installation-Id`, `X-Correlation-Id`, `Idempotency-Key`, and JSON content type.
- A new user action creates new metadata. A transport retry of the same unresolved action reuses metadata and body.
- Store the returned device token only after the complete response and three-way account identity parse successfully.
- Never log password, device token, Authorization, full request/response body, or reconnect grant.
- Backend endpoint must be deployed before claiming public login success; Flutter tests use synthetic sentinels only.

---

### Task 1: UUID and installation identity primitives

**Files:**
- Create: `mobile/lib/core/utils/uuid_v4.dart`
- Create: `mobile/lib/features/account_login/data/installation_id_store.dart`
- Modify: `mobile/lib/features/account_sync/data/ex_v2_api_client.dart`
- Create: `mobile/test/installation_id_store_test.dart`
- Modify: `mobile/test/ex_v2_api_client_test.dart`

**Interfaces:**
- Produces: `String uuidV4()` and `typedef UuidV4Factory = String Function()`.
- Produces: `InstallationIdStore.readOrCreate(): Future<String>`.
- `SecureInstallationIdStore` stores one UUID under `ex_v2_installation_id` and accepts a `UuidV4Factory` for deterministic tests.
- `ExV2CommandMetadata.create()` consumes `uuidV4()` without changing its public API.

- [ ] **Step 1: Write failing UUID and installation-store tests**

```dart
test('uuidV4 returns RFC 4122 version 4 values', () {
  expect(
    uuidV4(),
    matches(RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    )),
  );
});

test('readOrCreate persists and reuses one installation id', () async {
  FlutterSecureStorage.setMockInitialValues({});
  final store = SecureInstallationIdStore(
    const FlutterSecureStorage(),
    uuidFactory: () => '11111111-1111-4111-8111-111111111111',
  );
  expect(await store.readOrCreate(), '11111111-1111-4111-8111-111111111111');
  expect(await store.readOrCreate(), '11111111-1111-4111-8111-111111111111');
  expect(
    await const FlutterSecureStorage().read(key: 'ex_v2_installation_id'),
    '11111111-1111-4111-8111-111111111111',
  );
});
```

- [ ] **Step 2: Run RED tests**

Run:

```powershell
& 'D:\toolchains\flutter\bin\flutter.bat' test --reporter expanded --concurrency=1 test/installation_id_store_test.dart test/ex_v2_api_client_test.dart
```

Expected: FAIL because `uuid_v4.dart` and `InstallationIdStore` do not exist.

- [ ] **Step 3: Implement UUID generation and secure installation storage**

```dart
typedef UuidV4Factory = String Function();

String uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final raw = bytes.map(hex).join();
  return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-'
      '${raw.substring(12, 16)}-${raw.substring(16, 20)}-'
      '${raw.substring(20)}';
}
```

```dart
abstract interface class InstallationIdStore {
  Future<String> readOrCreate();
}

final class SecureInstallationIdStore implements InstallationIdStore {
  const SecureInstallationIdStore(
    this._storage, {
    this.uuidFactory = uuidV4,
  });

  static const storageKey = 'ex_v2_installation_id';
  final FlutterSecureStorage _storage;
  final UuidV4Factory uuidFactory;

  @override
  Future<String> readOrCreate() async {
    final existing = await _storage.read(key: storageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = uuidFactory();
    await _storage.write(key: storageKey, value: created);
    return created;
  }
}
```

Move the existing private UUID implementation out of `ex_v2_api_client.dart` and import `uuid_v4.dart` there.

- [ ] **Step 4: Run GREEN tests**

Run the Step 2 command. Expected: all tests PASS.

- [ ] **Step 5: Commit Task 1**

```powershell
git add mobile/lib/core/utils/uuid_v4.dart mobile/lib/features/account_login/data/installation_id_store.dart mobile/lib/features/account_sync/data/ex_v2_api_client.dart mobile/test/installation_id_store_test.dart mobile/test/ex_v2_api_client_test.dart
git commit -m "feat: add stable EX V2 installation identity"
```

### Task 2: Login wire contract, parser, and repository

**Files:**
- Create: `mobile/lib/features/account_login/domain/account_password_login_models.dart`
- Create: `mobile/lib/features/account_login/data/account_password_login_repository.dart`
- Create: `mobile/lib/features/account_login/data/account_password_login_dependencies.dart`
- Modify: `mobile/lib/features/account_sync/data/ex_v2_api_client.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Create: `mobile/test/account_password_login_repository_test.dart`

**Interfaces:**
- Produces: `AccountPasswordLoginRequest.toJson()` with exact fields `brokerId`, `serverId`, `login`, `password`.
- Produces: `AccountPasswordLoginResult` containing `String deviceToken`, `LinkedTradingAccount account`, and `ExV2Bootstrap bootstrap`.
- Produces: `ExV2ApiClient.postLoginJson(path:, body:, installationId:, metadata:)`.
- Produces: `AccountPasswordLoginRepository.login(request, installationId:, metadata:)`.
- Produces providers `installationIdStoreProvider` and `accountPasswordLoginRepositoryProvider`.

- [ ] **Step 1: Write failing request/HTTP/parser tests**

```dart
test('login sends exact public URL, raw password, and login headers', () async {
  await repository.login(
    const AccountPasswordLoginRequest(
      brokerId: 'yodo-demo',
      serverId: 'yodo-demo-01',
      login: '109740422',
      password: ' Test-Pass_123! ',
    ),
    installationId: '11111111-1111-4111-8111-111111111111',
    metadata: const ExV2CommandMetadata(
      idempotencyKey: '22222222-2222-4222-8222-222222222222',
      correlationId: '33333333-3333-4333-8333-333333333333',
    ),
  );
  final request = adapter.requests.single;
  expect(request.uri.toString(), 'https://trochoi.top/ex/v2/api/mobile/auth/login');
  expect(request.headers['X-Device-Token'], isNull);
  expect(request.headers['X-Installation-Id'], isNotEmpty);
  expect(request.headers['X-Correlation-Id'], isNotEmpty);
  expect(request.headers['Idempotency-Key'], isNotEmpty);
  expect(request.data['password'], ' Test-Pass_123! ');
  expect(request.data['login'], '109740422');
});

test('login result rejects account and bootstrap identity mismatch', () {
  expect(
    () => AccountPasswordLoginResult.fromJson(mismatchedResponse),
    throwsFormatException,
  );
});
```

- [ ] **Step 2: Run RED repository test**

```powershell
& 'D:\toolchains\flutter\bin\flutter.bat' test --reporter expanded --concurrency=1 test/account_password_login_repository_test.dart
```

Expected: FAIL because login models/repository/client method do not exist.

- [ ] **Step 3: Implement the focused unauthenticated login boundary**

Add to `ExV2ApiClient`:

```dart
Future<Map<String, dynamic>> postLoginJson(
  String path, {
  required Map<String, dynamic> body,
  required String installationId,
  required ExV2CommandMetadata metadata,
}) => _mutation(
  'POST',
  path,
  body,
  metadata,
  requiresDeviceToken: false,
  extraHeaders: {'X-Installation-Id': installationId},
);
```

Extend private `_request`/`_mutation` with `requiresDeviceToken` and `extraHeaders`. Default `requiresDeviceToken` remains `true`, so no existing endpoint can accidentally become public.

Implement result parsing and assert:

```dart
if (account.id != bootstrap.account.id ||
    account.id != bootstrap.summary.accountId) {
  throw const FormatException(
    'Login account and bootstrap account identities must match',
  );
}
```

Add typed configuration:

```dart
final class ExV2LoginConfig {
  const ExV2LoginConfig({required this.brokerId, required this.serverId});
  static const production = ExV2LoginConfig(
    brokerId: 'yodo-demo',
    serverId: 'yodo-demo-01',
  );
}
```

- [ ] **Step 4: Run GREEN repository test and existing API tests**

```powershell
& 'D:\toolchains\flutter\bin\flutter.bat' test --reporter expanded --concurrency=1 test/account_password_login_repository_test.dart test/ex_v2_api_client_test.dart test/account_link_repository_test.dart
```

Expected: all tests PASS; legacy authenticated requests still include `X-Device-Token`.

- [ ] **Step 5: Commit Task 2**

```powershell
git add mobile/lib/features/account_login mobile/lib/features/account_sync/data/ex_v2_api_client.dart mobile/lib/features/account_sync/application/ex_v2_account_provider.dart mobile/test/account_password_login_repository_test.dart mobile/test/ex_v2_api_client_test.dart mobile/test/account_link_repository_test.dart
git commit -m "feat: add EX V2 account password login client"
```

### Task 3: Login controller and atomic local session publication

**Files:**
- Create: `mobile/lib/features/account_login/application/account_password_login_controller.dart`
- Create: `mobile/test/account_password_login_controller_test.dart`

**Interfaces:**
- Produces enum `AccountPasswordLoginPhase { editing, submitting, succeeded, failed }`.
- Produces immutable `AccountPasswordLoginState` with phase, `String? errorMessage`, and `String? errorCode`; it never contains password or device token.
- Produces `AccountPasswordLoginController.submit({required String login, required String password, ExV2CommandMetadata? metadata}) -> Future<bool>`.
- Consumes repository, installation store, device-token store, login config, and `ExV2AccountController.publishBootstrap`.

- [ ] **Step 1: Write failing controller tests**

```dart
test('successful login stores token and publishes canonical bootstrap', () async {
  final result = await controller.submit(
    login: '109740422',
    password: ' Test-Pass_123! ',
  );
  expect(result, isTrue);
  expect(tokenStore.value, 'opaque-test-token');
  expect(container.read(exV2AccountProvider).requireValue!.bootstrap.account.id,
      'account-1');
  expect(repository.requests.single.password, ' Test-Pass_123! ');
});

test('invalid credentials do not persist a token and expose safe diagnostics', () async {
  repository.error = const ExV2RequestFailure(
    statusCode: 422,
    code: 'invalid_credentials',
    correlationId: 'corr-safe-test',
    message: 'Unable to sign in.',
  );
  expect(await controller.submit(login: '109740422', password: 'wrong'), isFalse);
  expect(tokenStore.value, isNull);
  expect(state.errorCode, 'invalid_credentials');
  expect(state.errorMessage, contains('invalid_credentials'));
  expect(state.errorMessage, contains('corr-safe-test'));
});

test('double submit while in flight sends one request', () async {
  final first = controller.submit(login: '109740422', password: 'sentinel');
  final second = await controller.submit(login: '109740422', password: 'sentinel');
  expect(second, isFalse);
  expect(repository.calls, 1);
  gate.complete();
  await first;
});
```

- [ ] **Step 2: Run RED controller test**

```powershell
& 'D:\toolchains\flutter\bin\flutter.bat' test --reporter expanded --concurrency=1 test/account_password_login_controller_test.dart
```

Expected: FAIL because the controller/provider do not exist.

- [ ] **Step 3: Implement minimal controller**

Validation uses `RegExp(r'^\d+$').hasMatch(login.trim())` and `password.isNotEmpty`. Build request with `login.trim()` and raw `password`. Use `ExV2CommandMetadata.create()` only once per submit action. After a parsed success:

```dart
await tokenStore.write(result.deviceToken);
final publication = ref.read(exV2AccountProvider.notifier).publishBootstrap(
  result.bootstrap,
  presentation: ExV2AccountPresentation(
    brokerId: result.account.brokerId,
    companyName: result.account.brokerName,
    serverId: result.account.serverId,
    tradingServer: result.account.serverName,
  ),
);
```

If publication is rejected, delete the just-written token and return failed. Catch structured errors through `safeDisplayMessage`, and copy only `ExV2RequestFailure.code` into `state.errorCode`. Never put password/token into provider state or exception text.

- [ ] **Step 4: Run GREEN controller test**

Run the Step 2 command. Expected: all tests PASS.

- [ ] **Step 5: Commit Task 3**

```powershell
git add mobile/lib/features/account_login/application/account_password_login_controller.dart mobile/test/account_password_login_controller_test.dart
git commit -m "feat: coordinate account password session login"
```

### Task 4: Two-field login screen and session gate migration

**Files:**
- Create: `mobile/lib/features/account_login/presentation/account_password_login_screen.dart`
- Modify: `mobile/lib/features/account_sync/presentation/device_gate.dart`
- Modify: `mobile/test/device_gate_test.dart`
- Create: `mobile/test/account_password_login_screen_test.dart`

**Interfaces:**
- Produces `AccountPasswordLoginScreen({required VoidCallback onAuthenticated})`.
- Screen owns login/password `TextEditingController`s; controller receives values only at submit.
- `DeviceGate` invokes `onAuthenticated`, sets `_activated = true`, preserves the already-published bootstrap, and arms existing bootstrap watchdog only when a later provider load is required.
- Missing/rejected token renders login screen instead of `_DeviceActivationScreen`.

- [ ] **Step 1: Replace legacy widget expectations with failing login-screen tests**

```dart
testWidgets('missing token shows account password login without token input',
    (tester) async {
  await pumpGate(tester, tokenStore: _MemoryTokenStore());
  expect(find.byKey(const Key('account-password-login-screen')), findsOneWidget);
  expect(find.byKey(const Key('account-login-field')), findsOneWidget);
  expect(find.byKey(const Key('account-password-field')), findsOneWidget);
  expect(find.text('Device token'), findsNothing);
  expect(find.text('Kích hoạt thiết bị'), findsNothing);
});

testWidgets('text controllers preserve password and success opens app',
    (tester) async {
  await tester.enterText(find.byKey(const Key('account-login-field')), '109740422');
  await tester.enterText(
    find.byKey(const Key('account-password-field')),
    ' Test-Pass_123! ',
  );
  await tester.tap(find.byKey(const Key('account-login-submit')));
  await tester.pumpAndSettle();
  expect(repository.requests.single.password, ' Test-Pass_123! ');
  expect(find.text('SERVER APP'), findsOneWidget);
});

testWidgets('invalid credentials clear password but preserve login',
    (tester) async {
  repository.error = const ExV2RequestFailure(
    statusCode: 422,
    code: 'invalid_credentials',
    correlationId: 'corr-safe-widget',
    message: 'Unable to sign in.',
  );
  await tester.enterText(find.byKey(const Key('account-login-field')), '109740422');
  await tester.enterText(find.byKey(const Key('account-password-field')), 'wrong');
  await tester.tap(find.byKey(const Key('account-login-submit')));
  await tester.pumpAndSettle();
  final loginField = tester.widget<TextField>(
    find.byKey(const Key('account-login-field')),
  );
  final passwordField = tester.widget<TextField>(
    find.byKey(const Key('account-password-field')),
  );
  expect(loginField.controller!.text, '109740422');
  expect(passwordField.controller!.text, isEmpty);
  expect(find.textContaining('invalid_credentials'), findsOneWidget);
  expect(find.textContaining('corr-safe-widget'), findsOneWidget);
});
```

- [ ] **Step 2: Run RED widget tests**

```powershell
& 'D:\toolchains\flutter\bin\flutter.bat' test --reporter expanded --concurrency=1 test/account_password_login_screen_test.dart test/device_gate_test.dart
```

Expected: FAIL because missing token still shows the device-token activation screen.

- [ ] **Step 3: Implement the production login screen**

Use existing semantic theme tokens (`AppColors`, `AppSpacing`, `AppTypography`, `AppRadius`) and a dark video-parity layout. Submit logic:

```dart
final accepted = await ref
    .read(accountPasswordLoginControllerProvider.notifier)
    .submit(login: _loginController.text, password: _passwordController.text);
if (!mounted) return;
if (accepted) {
  _passwordController.clear();
  widget.onAuthenticated();
} else if (
    ref.read(accountPasswordLoginControllerProvider).errorCode ==
        'invalid_credentials') {
  _passwordController.clear();
}
```

Remove `_DeviceActivationScreen` and `DeviceActivationService` usage from production `DeviceGate`. On bootstrap 401/403, delete the rejected token and render `AccountPasswordLoginScreen`; button copy must no longer mention entering another device code.

- [ ] **Step 4: Run GREEN widget and gate tests**

Run the Step 2 command. Expected: all tests PASS.

- [ ] **Step 5: Run account-link regression tests**

```powershell
& 'D:\toolchains\flutter\bin\flutter.bat' test --reporter expanded --concurrency=1 test/account_link_login_video_test.dart test/account_link_controller_test.dart test/account_activation_coordinator_test.dart
```

Expected: existing in-app add/switch-account flow remains green for authenticated sessions.

- [ ] **Step 6: Commit Task 4**

```powershell
git add mobile/lib/features/account_login/presentation/account_password_login_screen.dart mobile/lib/features/account_sync/presentation/device_gate.dart mobile/test/account_password_login_screen_test.dart mobile/test/device_gate_test.dart
git commit -m "feat: replace token gate with account password login"
```

### Task 5: Security scan, full verification, and deploy handoff

**Files:**
- Reference unchanged backend prompt: `docs/ex-v2-account-password-login-contract.md`

**Interfaces:**
- Produces a buildable APK and a handoff that clearly separates local Flutter success from backend/public-smoke status.

- [ ] **Step 1: Format changed Dart files**

```powershell
& 'D:\toolchains\flutter\bin\dart.bat' format lib test
```

- [ ] **Step 2: Run focused feature suite**

```powershell
& 'D:\toolchains\flutter\bin\flutter.bat' test --reporter expanded --concurrency=1 test/installation_id_store_test.dart test/account_password_login_repository_test.dart test/account_password_login_controller_test.dart test/account_password_login_screen_test.dart test/device_gate_test.dart test/ex_v2_api_client_test.dart
```

Expected: 0 failures.

- [ ] **Step 3: Run analyzer and full Flutter suite**

```powershell
& 'D:\toolchains\flutter\bin\flutter.bat' analyze
& 'D:\toolchains\flutter\bin\flutter.bat' test --reporter compact --concurrency=4
```

Expected: analyzer reports `No issues found`; full suite reports `All tests passed`.

- [ ] **Step 4: Build the configured Android variant**

```powershell
$env:GRADLE_USER_HOME='D:\mt5New\.gradle_home'
$env:ANDROID_HOME='D:\toolchains\android-sdk'
$env:ANDROID_SDK_ROOT='D:\toolchains\android-sdk'
$env:JAVA_HOME='D:\toolchains\java'
& 'D:\toolchains\flutter\bin\flutter.bat' build apk --debug
```

Expected: `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 5: Run security and worktree checks**

```powershell
git diff --check
git status --short
rg -n "print\(|debugPrint\(|Authorization|request\.data|response\.data" mobile/lib/features/account_login mobile/lib/features/account_sync
```

Inspect results rather than printing any secret. Confirm no production logging of password, device token, full bodies, or Authorization. Test literals must be synthetic sentinels only.

- [ ] **Step 6: Public smoke only after backend deployment**

Use the backend prompt acceptance flow with secrets supplied through the server secret store. Capture only login/list/bootstrap status and correlation ID. If `/mobile/auth/login` is not deployed or no safe secret source exists, report smoke as blocked and do not claim end-to-end completion.
