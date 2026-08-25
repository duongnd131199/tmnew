# EX V2 Flutter API Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Flutter app's production account/trading demo state with the server-authoritative EX V2 REST and SignalR data while preserving the current web application, current Flutter UI, and current market-price/chart pipeline.

**Architecture:** Keep `https://trochoi.top/api/market/*` and its market SignalR connection unchanged. Add an independent EX V2 client whose device token resolves one active web-configured account, bootstrap REST snapshot owns account state, and EX V2 SignalR events invalidate and refresh that state after committed server mutations. Riverpod exposes small feature providers; mock fixtures remain available only through explicit test/development overrides.

**Tech Stack:** Flutter 3.44+, Dart 3.12+, Riverpod 3.3.x, Dio 5.10.x, GoRouter 17.x, `signalr_hub` 2.x, Flutter Secure Storage 10.x, Drift/SQLite, Freezed/json_serializable, existing ASP.NET Core EX V2 API.

## Global Constraints

- Read `META_TRADER_CLONE_GUIDE.md`, `README.md`, `docs/architecture.md`, and `docs/design-system.md` completely before implementation.
- Do not modify or redeploy legacy `/ex/api/api/*`, `ex-api.service`, legacy static files, or legacy database objects.
- Use only `https://trochoi.top/ex/v2/api` for EX V2 REST and `https://trochoi.top/ex/v2/hubs/trading` for account realtime.
- Do not change `https://trochoi.top/api/market/*` or the existing market quote/candle SignalR implementation.
- App has no user login and no account picker. `X-Device-Token` determines the single active account configured on the web.
- Never put a production device token in Git, Dart source, assets, build arguments, screenshots, analytics, crash reports, or logs.
- Every mutation uses a stable `Idempotency-Key` and `X-Correlation-Id`; retries reuse both the key and identical body.
- App never sends `accountId` or `executedPrice`; server data always wins over local state.
- All amounts are demo money, but financial consistency, ownership scope, concurrency, and audit behavior remain mandatory.
- Preserve the current visual layout and interaction flow. Add only loading, stale, reconnecting, error, empty, and first-device activation states.
- Every task ends with `flutter analyze`, relevant `flutter test`, `flutter build apk --debug`, `dotnet build Trading.sln`, and `dotnet test Trading.sln --no-build` unless the task is documentation-only.
- Before Android builds, verify at least 15 GB free disk space so Gradle/LDPlayer does not freeze from disk pressure.

---

## Confirmed Production Contract

| Capability | Method and relative path |
|---|---|
| Device status/bootstrap | `GET /mobile/status`, `GET /mobile/bootstrap` |
| Account | `GET /account`, `/account/snapshot`, `/account/summary`, `/account/performance` |
| Orders | `GET/POST /orders`, `GET/PUT/DELETE /orders/{orderId}` |
| Positions | `GET /positions`, `GET /positions/{positionId}`, `PUT /positions/{positionId}/protection`, `POST /positions/{positionId}/close`, `/partial-close`, `/close-by` |
| History | `GET /history/deals`, `/history/orders`, `/history/positions`, `/history/transactions`, `/history/summary` |
| Wallet | `GET /wallet`, `GET /wallet/transactions` |
| Payment demo | `GET/POST /deposits`, `GET/POST /withdrawals`, `GET/POST /transfers` |
| Notifications | `GET /notifications`, `PUT /notifications/{id}/read`, `PUT /notifications/read-all` |
| Settings | `GET/PUT /settings` |

All paths above are relative to `https://trochoi.top/ex/v2/api`. The current Swagger advertises backend routes with an additional `/api/v2` prefix; therefore Task 1 must freeze the public reverse-proxy contract using authenticated probes rather than deriving mobile URLs directly from Swagger path text.

SignalR events: `OrderCreated`, `OrderUpdated`, `OrderCanceled`, `PositionCreated`, `PositionUpdated`, `PositionClosed`, `DealCreated`, `HistoryUpdated`, `WalletUpdated`, `DepositUpdated`, `WithdrawalUpdated`, `TransferUpdated`, `PerformanceUpdated`, `AccountSnapshotInvalidated`, and `ActiveAccountChanged`.

## Target File Map

```text
mobile/lib/core/ex_v2/
  ex_v2_config.dart                 REST/hub origins only
  device_token_store.dart           secure device-token persistence
  command_metadata.dart             stable idempotency/correlation IDs
  ex_v2_error.dart                  typed HTTP/domain failures
  ex_v2_api_client.dart             Dio transport and headers

mobile/lib/features/device/
  data/device_repository.dart
  presentation/device_activation_screen.dart
  presentation/device_gate.dart

mobile/lib/features/account_sync/
  domain/account_models.dart
  domain/trading_models.dart
  domain/history_models.dart
  domain/wallet_models.dart
  domain/communication_models.dart
  data/ex_v2_mappers.dart
  data/ex_v2_repository.dart
  data/ex_v2_realtime_service.dart
  data/account_snapshot_cache.dart
  application/account_sync_state.dart
  application/account_sync_controller.dart
  application/account_sync_providers.dart

mobile/test/fixtures/ex_v2/              sanitized server response fixtures
mobile/test/core/ex_v2/                  transport/token tests
mobile/test/features/account_sync/       mapping, state, realtime, command tests
tool/verify_ex_v2_contract.ps1           read-only public contract probe
docs/api/ex-v2-openapi.json              reviewed OpenAPI snapshot
docs/api/ex-v2-flutter-mapping.md         field and endpoint mapping
```

Do not add new account logic to `mobile/lib/shared/providers/demo_data_provider.dart`. Existing `DemoQuote`/chart seed types may remain until a separate market-model cleanup, but account, order, position, history, wallet, notification, and settings state must move to `features/account_sync`.

## Shared Test Harness Contract

Create `mobile/test/support/ex_v2_test_harness.dart` with the first task that needs it and extend it without changing these names:

```dart
Map<String, dynamic> fixtureJson(String name);
FakeExV2Repository fakeRepository({String bootstrapFixture = 'bootstrap.json'});
Widget testApp({required FakeExV2Repository repository, String? deviceToken});

final class RecordedRequest {
  const RecordedRequest({required this.method, required this.path, required this.headers, required this.body});
  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> body;
}
```

Transport tests use Dio's custom `HttpClientAdapter` and assert against its `List<RecordedRequest> requests`. Controller tests use `FakeExV2Repository`, `FakeExV2RealtimeService`, and `fakeAsync`; widget tests override the same Riverpod repository/realtime providers. Production integration tests read `EX_V2_DEVICE_TOKEN` from the test runner environment and fail before app startup when it is absent.

### Task 1: Freeze and Verify the Public EX V2 Contract

**Files:**
- Create: `docs/api/ex-v2-openapi.json`
- Create: `docs/api/ex-v2-flutter-mapping.md`
- Create: `tool/verify_ex_v2_contract.ps1`
- Test: `tool/verify_ex_v2_contract.ps1`

**Interfaces:**
- Consumes: production Swagger, `$env:EX_V2_DEVICE_TOKEN`, public REST base.
- Produces: reviewed response fixtures and an explicit public-path contract used by every later repository method.

- [ ] **Step 1: Write a failing read-only contract probe**

```powershell
param([Parameter(Mandatory = $true)][string]$DeviceToken)
$base = 'https://trochoi.top/ex/v2/api'
$headers = @{ 'X-Device-Token' = $DeviceToken; 'X-Correlation-Id' = [guid]::NewGuid().ToString() }
$required = @('/mobile/status', '/mobile/bootstrap', '/account', '/account/summary', '/positions', '/orders', '/wallet')
foreach ($path in $required) {
  $response = Invoke-WebRequest -Uri "$base$path" -Headers $headers -Method Get
  if ($response.StatusCode -ne 200) { throw "$path returned $($response.StatusCode)" }
}
```

- [ ] **Step 2: Run the probe and verify the current contract**

Run: `powershell -ExecutionPolicy Bypass -File tool/verify_ex_v2_contract.ps1 -DeviceToken $env:EX_V2_DEVICE_TOKEN`

Expected: every required read returns 200; no POST, PUT, or DELETE is issued. If either `/mobile/bootstrap` path variant is ambiguous, record the one returning the authenticated bootstrap body in `docs/api/ex-v2-flutter-mapping.md` and use only that public path.

- [ ] **Step 3: Save and sanitize contract evidence**

Run: `Invoke-WebRequest https://trochoi.top/ex/v2/swagger/v1/swagger.json -OutFile docs/api/ex-v2-openapi.json`

Document every JSON field used by Flutter, nullable fields, enum strings, UTC rules, pagination envelope, error envelope, and SignalR payload. Replace account IDs, names, bank details, token-like values, and transaction references in fixtures with deterministic test values before committing.

- [ ] **Step 4: Add contract gates for known Swagger weaknesses**

The mapping document must explicitly state that device/security headers and several response schemas are absent from current OpenAPI. Capture authenticated samples for bootstrap, history, wallet transactions, payments, notifications, and settings; do not infer those shapes from the UI.

- [ ] **Step 5: Validate and commit**

Run: `rg -n "X-Device-Token:|Bearer |device-token|109740422|2022" docs/api mobile/test/fixtures`

Expected: no production token or production account identity appears.

Commit: `git add docs/api tool/verify_ex_v2_contract.ps1 && git commit -m "docs: freeze EX V2 mobile contract"`

### Task 2: Add EX V2 Configuration and One-Time Device Activation

**Files:**
- Create: `mobile/lib/core/ex_v2/ex_v2_config.dart`
- Create: `mobile/lib/core/ex_v2/device_token_store.dart`
- Create: `mobile/lib/features/device/presentation/device_activation_screen.dart`
- Create: `mobile/lib/features/device/presentation/device_gate.dart`
- Modify: `mobile/lib/app/bootstrap.dart`
- Modify: `mobile/lib/app/router.dart`
- Test: `mobile/test/core/ex_v2/device_token_store_test.dart`
- Test: `mobile/test/features/device/device_gate_test.dart`

**Interfaces:**
- Produces: `ExV2Config`, `DeviceTokenStore.read/write/delete`, and `DeviceGate`.
- Consumes: `flutter_secure_storage`; no login credentials.

- [ ] **Step 1: Write failing token-store and gate tests**

```dart
test('stores the device token under one non-logged key', () async {
  final storage = FakeSecureStorage();
  final store = DeviceTokenStore(storage);
  await store.write('device-token-test');
  expect(await store.read(), 'device-token-test');
  expect(storage.writes.keys, ['ex_v2_device_token']);
});

testWidgets('shows activation only when the secure token is missing', (tester) async {
  await tester.pumpWidget(DeviceGateTestHost(token: null));
  expect(find.byType(DeviceActivationScreen), findsOneWidget);
});
```

- [ ] **Step 2: Verify failure**

Run: `cd mobile; flutter test test/core/ex_v2/device_token_store_test.dart test/features/device/device_gate_test.dart`

Expected: FAIL because the store and gate do not exist.

- [ ] **Step 3: Implement config, secure storage, and activation**

```dart
final class ExV2Config {
  const ExV2Config({required this.restBaseUrl, required this.hubUrl});
  final String restBaseUrl;
  final String hubUrl;
  static const production = ExV2Config(
    restBaseUrl: 'https://trochoi.top/ex/v2/api',
    hubUrl: 'https://trochoi.top/ex/v2/hubs/trading',
  );
}

final class DeviceTokenStore {
  DeviceTokenStore(this._storage);
  static const key = 'ex_v2_device_token';
  final FlutterSecureStorage _storage;
  Future<String?> read() => _storage.read(key: key);
  Future<void> write(String value) => _storage.write(key: key, value: value.trim());
  Future<void> delete() => _storage.delete(key: key);
}
```

Activation is not a login: on the first install, the owner pastes the one-time token shown by the web admin, the app validates `GET /mobile/status`, saves it only after HTTP 200, and then never asks again unless the token is rotated/revoked.

Define `FakeSecureStorage` and `DeviceGateTestHost` locally in the two test files; both implement only the secure-storage operations and provider overrides exercised by these tests.

- [ ] **Step 4: Make startup pass through `DeviceGate`**

Keep the existing splash visual. Remove automatic navigation based only on a timer; navigate to `/trade` only after the token exists and bootstrap succeeds. Invalid/revoked tokens return to activation with a clear Vietnamese message.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test test/core/ex_v2/device_token_store_test.dart test/features/device/device_gate_test.dart; flutter build apk --debug`

Commit: `git add mobile/lib/core/ex_v2 mobile/lib/features/device mobile/lib/app mobile/test && git commit -m "feat: add EX V2 device activation"`

### Task 3: Build the Authenticated Dio Client and Stable Mutation Metadata

**Files:**
- Create: `mobile/lib/core/ex_v2/command_metadata.dart`
- Create: `mobile/lib/core/ex_v2/ex_v2_error.dart`
- Create: `mobile/lib/core/ex_v2/ex_v2_api_client.dart`
- Test: `mobile/test/core/ex_v2/ex_v2_api_client_test.dart`

**Interfaces:**
- Produces: `ExV2ApiClient.get/post/put/delete`, `CommandMetadata`, `ExV2Error`.
- Consumes: `ExV2Config`, `DeviceTokenStore`.

- [ ] **Step 1: Write failing header and error tests**

```dart
test('mutation sends stable device, idempotency, and correlation headers', () async {
  final harness = ExV2ClientHarness(token: 'test-token', statusCode: 200);
  const metadata = CommandMetadata(idempotencyKey: 'idem-1', correlationId: 'corr-1');
  await harness.client.post('/orders', data: const {'symbol': 'XAUUSD+'}, metadata: metadata);
  expect(harness.requests.single.headers['X-Device-Token'], 'test-token');
  expect(harness.requests.single.headers['Idempotency-Key'], 'idem-1');
  expect(harness.requests.single.headers['X-Correlation-Id'], 'corr-1');
});

test('maps 409 to concurrency conflict without retrying automatically', () async {
  final harness = ExV2ClientHarness(token: 'test-token', statusCode: 409);
  await expectLater(harness.client.put('/orders/id', data: const {}), throwsA(isA<ExV2ConcurrencyConflict>()));
  expect(harness.requests, hasLength(1));
});
```

- [ ] **Step 2: Verify failure**

Run: `cd mobile; flutter test test/core/ex_v2/ex_v2_api_client_test.dart`

- [ ] **Step 3: Implement transport rules**

```dart
final class CommandMetadata {
  const CommandMetadata({required this.idempotencyKey, required this.correlationId});
  final String idempotencyKey;
  final String correlationId;
}
```

Configure 15-second connect/receive timeouts, JSON content type, redacted logs, and no automatic mutation retry. Map 400, 401, 404, 409, 422, 429, and 5xx into typed failures; a 401 deletes the rejected secure token only after `/mobile/status` confirms it is invalid.

- [ ] **Step 4: Implement stable retry behavior**

Generate RFC 4122 v4 IDs from `Random.secure()`. A UI submission creates one `CommandMetadata`; retry buttons reuse the same object and request body until success or explicit cancellation.

Define `ExV2ClientHarness` in `mobile/test/support/ex_v2_test_harness.dart`; its adapter records method/path/headers/body and returns the constructor's status code with a deterministic JSON body.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test test/core/ex_v2/ex_v2_api_client_test.dart; flutter build apk --debug`

Commit: `git add mobile/lib/core/ex_v2 mobile/test/core/ex_v2 && git commit -m "feat: add EX V2 API transport"`

### Task 4: Add Typed Domain Models, JSON Mappers, and Read Repository

**Files:**
- Modify: `mobile/pubspec.yaml`
- Create: `mobile/lib/features/account_sync/domain/account_models.dart`
- Create: `mobile/lib/features/account_sync/domain/trading_models.dart`
- Create: `mobile/lib/features/account_sync/domain/history_models.dart`
- Create: `mobile/lib/features/account_sync/domain/wallet_models.dart`
- Create: `mobile/lib/features/account_sync/domain/communication_models.dart`
- Create: `mobile/lib/features/account_sync/data/ex_v2_mappers.dart`
- Create: `mobile/lib/features/account_sync/data/ex_v2_repository.dart`
- Test: `mobile/test/features/account_sync/ex_v2_mappers_test.dart`
- Test: `mobile/test/features/account_sync/ex_v2_repository_test.dart`

**Interfaces:**
- Produces: immutable `BootstrapSnapshot`, `TradingAccount`, `AccountSummary`, `TradingOrder`, `TradingPosition`, `Deal`, `HistoryPosition`, `WalletSnapshot`, payment/notification/settings models, and `ExV2Repository`.
- Consumes: sanitized Task 1 fixtures and `ExV2ApiClient`.

- [ ] **Step 1: Add required model/local-data dependencies**

Add `freezed_annotation`, `json_annotation`, `drift`, `sqlite3_flutter_libs`, and `path_provider`; add `build_runner`, `freezed`, `json_serializable`, and `drift_dev` to dev dependencies. Keep all existing dependencies and SDK floors unchanged.

- [ ] **Step 2: Write failing fixture mapping tests**

```dart
test('bootstrap maps UTC, nullable protection, and server version', () {
  final json = fixtureJson('bootstrap.json');
  final value = ExV2Mappers.bootstrap(json);
  expect(value.version, 2);
  expect(value.activeAccount.accountCode, 'TEST-ACCOUNT');
  expect(value.positions.single.stopLoss, isNull);
  expect(value.serverTime.isUtc, isTrue);
});
```

- [ ] **Step 3: Define the repository contract**

```dart
abstract interface class ExV2Repository {
  Future<BootstrapSnapshot> bootstrap();
  Future<List<TradingOrder>> orders();
  Future<List<TradingPosition>> positions();
  Future<HistoryPage<Deal>> deals({required int page, required int pageSize});
  Future<HistoryPage<HistoryPosition>> historyPositions({required int page, required int pageSize});
  Future<HistoryPage<WalletTransaction>> transactions({required int page, required int pageSize});
  Future<WalletSnapshot> wallet();
  Future<List<AppNotification>> notifications();
  Future<AppSettings> settings();
}
```

- [ ] **Step 4: Implement strict parsing and reads**

Parse numeric JSON as `num.toDouble()`, all server timestamps as UTC, preserve `rowVersion`, and fail with `ExV2ContractError(field, payloadType)` when a required field is absent. Never replace malformed finance values with zero. Generate code with `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; dart run build_runner build --delete-conflicting-outputs; flutter analyze; flutter test test/features/account_sync/ex_v2_mappers_test.dart test/features/account_sync/ex_v2_repository_test.dart; flutter build apk --debug`

Commit: `git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/features/account_sync mobile/test/features/account_sync && git commit -m "feat: map EX V2 account data"`

### Task 5: Add Server-Authoritative Bootstrap State and Local Snapshot Cache

**Files:**
- Create: `mobile/lib/features/account_sync/data/account_snapshot_cache.dart`
- Create: `mobile/lib/features/account_sync/application/account_sync_state.dart`
- Create: `mobile/lib/features/account_sync/application/account_sync_controller.dart`
- Create: `mobile/lib/features/account_sync/application/account_sync_providers.dart`
- Modify: `mobile/lib/app/bootstrap.dart`
- Test: `mobile/test/features/account_sync/account_sync_controller_test.dart`
- Test: `mobile/test/features/account_sync/account_snapshot_cache_test.dart`

**Interfaces:**
- Produces: `accountSyncControllerProvider`, read-only selectors for account, summary, positions, pending orders, deals, wallet, performance, connection state.
- Consumes: `ExV2Repository`, Task 4 models, Drift cache.

- [ ] **Step 1: Write failing state precedence tests**

```dart
test('server bootstrap replaces cached account state atomically', () async {
  final controller = AccountSyncHarness.cachedVersion(1, serverVersion: 2).controller;
  await controller.start();
  expect(controller.state.snapshot?.version, 2);
  expect(controller.state.phase, AccountSyncPhase.connected);
});

test('offline cache is marked stale and never accepts a mutation', () async {
  final controller = AccountSyncHarness.offlineCachedVersion(7).controller;
  await controller.start();
  expect(controller.state.phase, AccountSyncPhase.stale);
  expect(controller.canMutate, isFalse);
});
```

- [ ] **Step 2: Verify failure**

Run: `cd mobile; flutter test test/features/account_sync/account_sync_controller_test.dart test/features/account_sync/account_snapshot_cache_test.dart`

- [ ] **Step 3: Implement state and selectors**

```dart
enum AccountSyncPhase { initialLoading, connected, stale, reconnecting, error, deviceBlocked }

@freezed
class AccountSyncState with _$AccountSyncState {
  const factory AccountSyncState({
    required AccountSyncPhase phase,
    BootstrapSnapshot? snapshot,
    ExV2Error? error,
  }) = _AccountSyncState;
}
```

Derived providers must select from one snapshot so account code, balance, orders, positions, wallet, and history never come from different versions during a rebuild.

- [ ] **Step 4: Implement cache/startup policy**

Cache only the last successful bootstrap JSON, account ID, server version, and fetch time. Render it as stale while fetching; replace it atomically on success. A changed active account clears all old account rows before saving the new snapshot. Never cache the device token in SQLite.

Define `AccountSyncHarness.cachedVersion` and `.offlineCachedVersion` in the shared harness using an in-memory Drift database and `FakeExV2Repository`.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test test/features/account_sync; flutter build apk --debug`

Commit: `git add mobile/lib/features/account_sync mobile/lib/app/bootstrap.dart mobile/test/features/account_sync && git commit -m "feat: bootstrap canonical account state"`

### Task 6: Add EX V2 SignalR Invalidation and Reconnect Recovery

**Files:**
- Create: `mobile/lib/features/account_sync/data/ex_v2_realtime_service.dart`
- Modify: `mobile/lib/features/account_sync/application/account_sync_controller.dart`
- Test: `mobile/test/features/account_sync/ex_v2_realtime_service_test.dart`
- Test: `mobile/test/features/account_sync/account_reconnect_test.dart`

**Interfaces:**
- Produces: `Stream<AccountRealtimeEvent>`, `start`, `stop`, and `subscribe` lifecycle.
- Consumes: secure token as SignalR `access_token`, EX V2 hub URL, bootstrap refresh.

- [ ] **Step 1: Write failing event/reconnect tests**

```dart
test('invalidations are debounced into one bootstrap refresh', () async {
  final harness = AccountRealtimeHarness();
  harness.emit('OrderCreated', AccountRealtimeEvent.test(version: 3));
  harness.emit('AccountSnapshotInvalidated', AccountRealtimeEvent.test(version: 3));
  await harness.elapse(const Duration(milliseconds: 300));
  expect(harness.bootstrapCalls, 1);
});

test('ActiveAccountChanged clears old state before refresh', () async {
  final harness = AccountRealtimeHarness(initialAccountId: 'old');
  harness.emit('ActiveAccountChanged', AccountRealtimeEvent.test(version: 4));
  expect(harness.visibleAccountId, isNull);
  await harness.flush();
  expect(harness.visibleAccountId, 'new');
});
```

- [ ] **Step 2: Verify failure**

Run: `cd mobile; flutter test test/features/account_sync/ex_v2_realtime_service_test.dart test/features/account_sync/account_reconnect_test.dart`

- [ ] **Step 3: Implement the hub lifecycle**

Use `HubConnectionBuilder`, `HttpConnectionOptions(accessTokenFactory: tokenStore.read, logMessageContent: false)`, automatic reconnect delays `[0, 1000, 2000, 5000, 10000]`, register every confirmed event, call hub method `Subscribe` after connect, and unregister/dispose exactly once.

- [ ] **Step 4: Implement consistency behavior**

Treat events as invalidations in the first release: debounce 250 ms, call bootstrap, compare `version`, and atomically replace state. On reconnect, call bootstrap before showing connected. Drop events whose `accountId` differs from the current snapshot and then force bootstrap; do not merge their payload locally.

Define `AccountRealtimeHarness` in the shared harness with `emit`, `elapse`, `flush`, `bootstrapCalls`, and `visibleAccountId`. `AccountRealtimeEvent.test` builds deterministic non-production event payloads.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test test/features/account_sync/ex_v2_realtime_service_test.dart test/features/account_sync/account_reconnect_test.dart; flutter build apk --debug`

Commit: `git add mobile/lib/features/account_sync mobile/test/features/account_sync && git commit -m "feat: synchronize account realtime events"`

### Task 7: Switch Account, Trade, Chart Overlays, and Shell Reads to EX V2

**Files:**
- Modify: `mobile/lib/shared/widgets/app_shell.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/position_detail_screen.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- Test: `mobile/test/features/account_sync/account_ui_binding_test.dart`
- Test: existing `mobile/test/chart_controls_test.dart`

**Interfaces:**
- Consumes: Task 5 selectors and existing realtime market quote provider.
- Produces: unchanged screens rendered from server account state.

- [ ] **Step 1: Write failing UI binding tests**

```dart
testWidgets('trade renders the server account and positions', (tester) async {
  await tester.pumpWidget(testApp(repository: fakeRepository(bootstrapFixture: 'bootstrap.json'), deviceToken: 'test-token'));
  await tester.pumpAndSettle();
  expect(find.text('TEST-ACCOUNT'), findsOneWidget);
  expect(find.text('XAUUSD+'), findsWidgets);
  expect(find.textContaining('5,000.00'), findsOneWidget);
});
```

- [ ] **Step 2: Verify failure**

Run: `cd mobile; flutter test test/features/account_sync/account_ui_binding_test.dart`

- [ ] **Step 3: Replace read providers only**

Replace `demoAccountProvider`, `demoPositionsProvider`, and `demoPendingOrdersProvider` reads with account-sync selectors. Keep quote and candle providers unchanged. Compute live floating P/L for display from current market quote only when the API contract defines the formula; never write that computed display value back to server or canonical balance.

- [ ] **Step 4: Add consistent UI states**

Initial load keeps the splash overlay; stale/reconnecting shows a non-blocking banner; error offers retry; empty positions/orders show the existing empty presentation; `deviceBlocked` routes to activation. Disable mutation controls whenever phase is not `connected`.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test test/features/account_sync/account_ui_binding_test.dart test/chart_controls_test.dart; flutter build apk --debug`

Commit: `git add mobile/lib/shared/widgets/app_shell.dart mobile/lib/features/trade mobile/lib/features/chart mobile/lib/features/profile mobile/test && git commit -m "feat: render server account state"`

### Task 8: Replace Local Order Mutations with Idempotent Server Commands

**Files:**
- Modify: `mobile/lib/features/account_sync/data/ex_v2_repository.dart`
- Create: `mobile/lib/features/account_sync/application/order_commands.dart`
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Test: `mobile/test/features/account_sync/order_commands_test.dart`
- Test: `mobile/test/order_api_flow_test.dart`

**Interfaces:**
- Produces: `createOrder`, `modifyOrder`, `cancelOrder` commands.
- Consumes: `CreateOrderRequest`, `ModifyOrderRequest`, `rowVersion`, market quote for requested price, stable metadata.

- [ ] **Step 1: Write failing command tests**

```dart
test('retrying create order reuses clientOrderId and idempotency key', () async {
  final command = CreateOrderCommand.market(symbol: 'XAUUSD+', side: OrderSide.buy, volume: 0.1);
  await expectLater(controller.submit(command), throwsA(isA<ExV2NetworkError>()));
  await controller.retry(command.id);
  expect(recordedBodies.map((body) => body['clientOrderId']).toSet().length, 1);
  expect(recordedIdempotencyKeys.toSet().length, 1);
});
```

- [ ] **Step 2: Verify failure**

Run: `cd mobile; flutter test test/features/account_sync/order_commands_test.dart test/order_api_flow_test.dart`

- [ ] **Step 3: Implement exact requests**

Create sends `clientOrderId`, `symbol`, `type`, `side`, `volume`, nullable `requestedPrice`, `stopLoss`, and `takeProfit`. Modify sends nullable requested price/protection and current `rowVersion`. Cancel sends DELETE with metadata. Never send account ID, executed price, profit, status, or created time.

- [ ] **Step 4: Wire existing order UI**

Remove the artificial 700 ms delay and local `DemoTradingController` mutation. Keep the existing order sheet, pending-order chart panel, validations, and success/error feedback; wait for server success, then bootstrap refresh. On 409, refresh and ask the user to submit the edited values again.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test test/features/account_sync/order_commands_test.dart test/order_api_flow_test.dart test/chart_controls_test.dart; flutter build apk --debug`

Commit: `git add mobile/lib/features/account_sync mobile/lib/features/order mobile/lib/features/chart mobile/test && git commit -m "feat: execute orders through EX V2"`

### Task 9: Replace Position Protection and Close Actions with Server Commands

**Files:**
- Create: `mobile/lib/features/account_sync/application/position_commands.dart`
- Modify: `mobile/lib/features/account_sync/data/ex_v2_repository.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/position_detail_screen.dart`
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`
- Test: `mobile/test/features/account_sync/position_commands_test.dart`
- Test: `mobile/test/position_api_flow_test.dart`

**Interfaces:**
- Produces: `updateProtection`, `close`, `partialClose`, `closeBy`.
- Consumes: position ID, volume/opposite-position ID, rowVersion, metadata.

- [ ] **Step 1: Write failing position tests**

```dart
test('partial close sends only the requested volume', () async {
  await controller.partialClose(positionId: 'position-1', volume: 0.4);
  expect(recorded.path, '/positions/position-1/partial-close');
  expect(recorded.body, {'volume': 0.4});
});

test('protection sends the current row version', () async {
  await controller.updateProtection(positionId: 'position-1', stopLoss: 2300, takeProfit: 2400);
  expect(recorded.body['rowVersion'], 'row-version-1');
});
```

- [ ] **Step 2: Verify failure**

Run: `cd mobile; flutter test test/features/account_sync/position_commands_test.dart test/position_api_flow_test.dart`

- [ ] **Step 3: Implement commands and validation**

Reject zero/negative volume, volume greater than server `remainingVolume`, same-side close-by pairs, and SL/TP values invalid for the current side/quote. Server response and refreshed bootstrap remain authoritative.

- [ ] **Step 4: Replace every local close/modify call**

Cover swipe actions, expanded trade rows, position detail, chart overlay controls, close-all workflow, profitable/losing bulk filters, full close, partial close, close-by, and protection editing. Bulk actions execute sequentially with a distinct metadata pair per position and stop on the first server error so the next bootstrap can reconcile completed commands.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test test/features/account_sync/position_commands_test.dart test/position_api_flow_test.dart test/position_detail_functionality_test.dart; flutter build apk --debug`

Commit: `git add mobile/lib/features/account_sync mobile/lib/features/trade mobile/lib/features/order mobile/lib/features/chart mobile/test && git commit -m "feat: manage positions through EX V2"`

### Task 10: Load Server History with Pagination and Account Isolation

**Files:**
- Create: `mobile/lib/features/account_sync/application/history_controller.dart`
- Modify: `mobile/lib/features/history/presentation/screens/history_screen.dart`
- Modify: `mobile/lib/features/history/presentation/screens/history_detail_screen.dart`
- Test: `mobile/test/features/account_sync/history_controller_test.dart`
- Test: `mobile/test/history_api_binding_test.dart`

**Interfaces:**
- Produces: paged deal/order/position/transaction history and summary providers.
- Consumes: `/history/*`, active account identity from bootstrap.

- [ ] **Step 1: Write failing pagination/account-change tests**

```dart
test('loads each history page once and deduplicates by entity id', () async {
  await controller.loadFirstPage(HistoryTab.deals);
  await controller.loadNextPage(HistoryTab.deals);
  expect(controller.state.deals.map((item) => item.id).toSet().length, controller.state.deals.length);
});

test('active account change clears all old history before loading', () async {
  await controller.onAccountChanged('new-account');
  expect(controller.state.accountId, 'new-account');
  expect(controller.state.deals, isEmpty);
});
```

- [ ] **Step 2: Verify failure**

Run: `cd mobile; flutter test test/features/account_sync/history_controller_test.dart test/history_api_binding_test.dart`

- [ ] **Step 3: Implement server paging and filters**

Use `page=1` and `pageSize=50`; preserve existing Deals/Orders/Positions tabs and date filter. If the server lacks date query parameters, page until the oldest loaded UTC timestamp is before the selected range and filter only the loaded immutable list in memory.

- [ ] **Step 4: Replace fixture history**

Remove production reads from `demoDealsProvider`, `demoOrdersProvider`, and `demoHistoryPositionsProvider`. Detail routes resolve server IDs from the controller; missing records show error/retry instead of opening a different local item.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test test/features/account_sync/history_controller_test.dart test/history_api_binding_test.dart test/history_screen_detail_test.dart; flutter build apk --debug`

Commit: `git add mobile/lib/features/account_sync mobile/lib/features/history mobile/test && git commit -m "feat: load EX V2 trading history"`

### Task 11: Integrate Wallet, Deposit, Withdrawal, and Transfer

**Files:**
- Create: `mobile/lib/features/account_sync/application/wallet_commands.dart`
- Modify: `mobile/lib/features/wallet/presentation/screens/wallet_screen.dart`
- Modify: `mobile/lib/features/wallet/presentation/screens/wallet_request_screen.dart`
- Modify: `mobile/lib/app/router.dart`
- Test: `mobile/test/features/account_sync/wallet_commands_test.dart`
- Test: `mobile/test/wallet_api_flow_test.dart`

**Interfaces:**
- Produces: wallet read providers and idempotent deposit/withdrawal/transfer commands.
- Consumes: `/wallet`, `/wallet/transactions`, `/deposits`, `/withdrawals`, `/transfers`.

- [ ] **Step 1: Write failing wallet tests**

```dart
test('deposit creates one pending server request', () async {
  final command = DepositCommand(amount: 500, currency: 'USD', method: 'demo', reference: 'mobile-demo');
  await controller.deposit(command);
  expect(recorded.path, '/deposits');
  expect(recorded.body['amount'], 500);
  expect(controller.state.deposits.single.status, 'pending');
});

test('wallet screen renders server available and locked balances', () async {
  await tester.pumpWidget(testApp(repository: fakeRepository(bootstrapFixture: 'wallet.json'), deviceToken: 'test-token'));
  expect(find.textContaining('5,000.00'), findsOneWidget);
  expect(find.textContaining('100.00'), findsOneWidget);
});
```

- [ ] **Step 2: Verify failure**

Run: `cd mobile; flutter test test/features/account_sync/wallet_commands_test.dart test/wallet_api_flow_test.dart`

- [ ] **Step 3: Implement requests**

Deposit sends amount/currency/method/reference. Withdrawal sends amount/currency/bankName/bankAccount/accountHolder. Transfer sends amount/currency/toAccount. Use stable metadata and refresh bootstrap plus the affected list after success.

- [ ] **Step 4: Wire screens without changing business meaning**

Replace hard-coded wallet values and rows. Add request list/status, transfer route/form, validation, loading, pending approval copy, empty, retry, and reconnecting states. Do not optimistically change balance: legacy web/admin approval remains responsible for applying pending deposit/withdrawal requests.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test test/features/account_sync/wallet_commands_test.dart test/wallet_api_flow_test.dart; flutter build apk --debug`

Commit: `git add mobile/lib/features/account_sync mobile/lib/features/wallet mobile/lib/app/router.dart mobile/test && git commit -m "feat: synchronize demo wallet workflows"`

### Task 12: Integrate Performance, Notifications, and Settings

**Files:**
- Create: `mobile/lib/features/account_sync/application/communication_commands.dart`
- Modify: `mobile/lib/features/notifications/presentation/screens/notifications_screen.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/section_screen.dart`
- Test: `mobile/test/features/account_sync/communication_commands_test.dart`
- Test: `mobile/test/notifications_settings_api_test.dart`

**Interfaces:**
- Produces: performance, notification, unread-count, and settings providers; mark-read/read-all/update-settings commands.
- Consumes: `/account/performance`, `/notifications`, `/settings` and corresponding SignalR invalidations.

- [ ] **Step 1: Write failing notification/settings tests**

```dart
test('read-all updates server then refreshes notifications', () async {
  await controller.markAllRead();
  expect(recorded.method, 'PUT');
  expect(recorded.path, '/notifications/read-all');
  expect(repository.notificationsCalls, 2);
});

test('performance displays server values and warning count', () async {
  final performance = ExV2Mappers.performance(fixtureJson('performance.json'));
  expect(performance.netProfit, 125.5);
  expect(performance.integrityWarnings, 0);
});
```

- [ ] **Step 2: Verify failure**

Run: `cd mobile; flutter test test/features/account_sync/communication_commands_test.dart test/notifications_settings_api_test.dart`

- [ ] **Step 3: Implement APIs and state**

Load notifications/settings on screen entry, maintain server IDs/read state, and submit settings with metadata. Display performance exactly as returned; do not synthesize monthly rows or recalculate balance/equity. Show margin and margin level as unavailable while the server reports its documented non-authoritative zero values.

- [ ] **Step 4: Replace hard-coded UI collections**

Notifications mark one or all as read through the API. Settings remain visually identical but persist via server. Integrity warning count is diagnostic and must not crash the user flow.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test test/features/account_sync/communication_commands_test.dart test/notifications_settings_api_test.dart; flutter build apk --debug`

Commit: `git add mobile/lib/features/account_sync mobile/lib/features/notifications mobile/lib/features/profile mobile/test && git commit -m "feat: synchronize app account preferences"`

### Task 13: Isolate Mock Data to Tests and Development Builds

**Files:**
- Split: `mobile/lib/shared/providers/demo_data_provider.dart`
- Create: `mobile/lib/dev/demo_account_fixture.dart`
- Modify: all production imports reported by `rg "demo_data_provider" mobile/lib`
- Modify: affected tests under `mobile/test`
- Test: `mobile/test/production_account_source_test.dart`

**Interfaces:**
- Produces: production account state exclusively from `account_sync`; reusable dev/test fixtures via provider overrides.
- Consumes: all prior API-backed providers.

- [ ] **Step 1: Write a failing source-boundary test**

```dart
test('production widget sources do not import demo account state', () {
  final violations = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !file.path.contains('${Platform.pathSeparator}dev${Platform.pathSeparator}'))
      .where((file) => file.readAsStringSync().contains('shared/providers/demo_data_provider.dart'))
      .map((file) => file.path)
      .toList();
  expect(violations, isEmpty);
});
```

- [ ] **Step 2: Verify failure and inventory callers**

Run: `cd mobile; flutter test test/production_account_source_test.dart`

Run: `rg -n "demoTradingProvider|demoAccountProvider|demoPositionsProvider|demoPendingOrdersProvider|demoDealsProvider|demoOrdersProvider|demoHistoryPositionsProvider" lib`

- [ ] **Step 3: Move fixtures behind explicit overrides**

Keep symbol metadata/quote seeds required by market and chart in a narrowly named market fixture file. Move account fixtures and local mutation controller into `lib/dev`; production bootstrap never imports that directory. Tests override repository/provider interfaces instead of changing runtime globals.

- [ ] **Step 4: Preserve regression coverage**

Update existing chart, history, trade, order, and reference tests to inject `FakeExV2Repository` and `FakeExV2RealtimeService`. Do not delete visual parity assertions simply because their data source changed.

- [ ] **Step 5: Validate and commit**

Run: `cd mobile; flutter analyze; flutter test; flutter build apk --debug`

Commit: `git add mobile/lib mobile/test && git commit -m "refactor: isolate demo account fixtures"`

### Task 14: End-to-End Synchronization, Compatibility, and Rollout Gate

**Files:**
- Create: `mobile/integration_test/ex_v2_sync_test.dart`
- Create: `docs/ex-v2-mobile-runbook.md`
- Modify: `README.md`
- Test: `mobile/integration_test/ex_v2_sync_test.dart`

**Interfaces:**
- Produces: reproducible release/rollback procedure and proof that web-selected account and app mutations stay synchronized.
- Consumes: production-like test device token and a dedicated demo account.

- [ ] **Step 1: Write the end-to-end flow**

```dart
testWidgets('web-selected account and app mutations converge', (tester) async {
  final driver = ExV2IntegrationDriver.fromEnvironment();
  await driver.start(tester);
  expect(driver.accountCode, isNotEmpty);
  final orderId = await driver.placePendingOrder(symbol: 'XAUUSD+', volume: 0.01);
  await driver.awaitRealtimeRefresh();
  expect(driver.pendingOrderIds, contains(orderId));
  await driver.cancelOrder(orderId);
  await driver.awaitRealtimeRefresh();
  expect(driver.pendingOrderIds, isNot(contains(orderId)));
});
```

- [ ] **Step 2: Run automated verification**

Define `ExV2IntegrationDriver` in the integration-test file. It reads `EX_V2_DEVICE_TOKEN` and `ANDROID_DEVICE_ID`, uses the app's real repository, exposes the methods/properties shown above, and registers cleanup for every entity it creates.

Run: `cd mobile; flutter analyze; flutter test; flutter test integration_test/ex_v2_sync_test.dart -d $env:ANDROID_DEVICE_ID; flutter build apk --debug`

Run: `cd backend; dotnet build Trading.sln; dotnet test Trading.sln --no-build`

Expected: all commands pass; the E2E test uses only a dedicated demo account and cleans up its pending order through the public API.

- [ ] **Step 3: Perform manual two-way acceptance**

1. In web admin, switch the mobile device active account; app receives `ActiveAccountChanged`, clears old data, and displays the new code/balance/history without restart.
2. Create and cancel a pending app order; verify the same IDs/statuses appear on web.
3. Create deposit, withdrawal, and transfer demo requests in app; verify they appear only under the selected account on web.
4. Approve one pending demo request on web; verify app wallet/history updates after SignalR invalidation or foreground refresh.
5. Restart app and API connection; verify cached/stale then connected state with no duplicate mutation.
6. Rotate device token; verify old token receives 401 and the app returns to activation.

- [ ] **Step 4: Verify legacy compatibility and secrets**

Run the server's `COMPATIBILITY_PASSED` check, compare legacy static 188-file checksums, and confirm `ex-api.service` process start time/binary hash are unchanged. Scan APK/source/logs for the production token and known test token strings; expected findings: zero.

- [ ] **Step 5: Document rollout and rollback, then commit**

The runbook must include token provisioning/rotation, web account selection, health checks, common 401/409/reconnect recovery, cache clearing, test-account cleanup, and rollback by installing the previous APK. No rollback step may delete server v2 or legacy data.

Commit: `git add mobile/integration_test docs/ex-v2-mobile-runbook.md README.md && git commit -m "test: verify EX V2 mobile synchronization"`

## Release Acceptance Criteria

- App starts without user login after one-time device activation.
- Web admin is the only place that chooses the app's active account.
- Account change cannot leave balance/history/orders from the previous account visible.
- Balance, equity, positions, orders, deals, transaction history, wallet, performance, settings, and notifications come from EX V2.
- App order/position/payment mutations are visible on web and survive app restart.
- Web/admin changes refresh the app through SignalR plus REST reconciliation.
- Duplicate taps, timeouts, and retries do not create duplicate server mutations.
- 409 refreshes canonical state; 401 revokes local activation; network loss disables writes and marks cached state stale.
- Market quotes and candles remain on the existing fast market feed with no fake timer price generation.
- Legacy `/ex` behavior, files, process, routes, and data contracts remain unchanged.
- `flutter analyze`, full Flutter tests, Android debug build, backend build/tests, contract probe, integration test, legacy compatibility check, and secret scan all pass.

## Recommended Delivery Order

Deliver Tasks 1–6 as the connection foundation, Tasks 7–10 as trading/account migration, Tasks 11–12 as wallet and supporting features, then Tasks 13–14 as source cleanup and production acceptance. Do not enable production mutations before Tasks 1–6 pass and an owner-provisioned test device token is available.
