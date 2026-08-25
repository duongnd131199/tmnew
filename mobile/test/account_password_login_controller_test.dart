import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_login/application/account_password_login_controller.dart';
import 'package:trading_mobile/features/account_login/data/account_password_login_dependencies.dart';
import 'package:trading_mobile/features/account_login/data/account_password_login_repository.dart';
import 'package:trading_mobile/features/account_login/data/installation_id_store.dart';
import 'package:trading_mobile/features/account_login/domain/account_password_login_models.dart';
import 'package:trading_mobile/features/account_sessions/application/account_session_committer.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

void main() {
  test(
    'successful login stores token and publishes canonical bootstrap',
    () async {
      final repository = _FakeLoginRepository();
      final tokenStore = _MemoryTokenStore();
      final harness = _harness(repository, tokenStore);
      addTearDown(harness.dispose);

      final accepted = await harness.controller.submit(
        login: '109740422',
        password: ' Test-Pass_123! ',
      );

      expect(accepted, isTrue);
      expect(tokenStore.value, 'opaque-test-token');
      expect(repository.requests.single.password, ' Test-Pass_123! ');
      expect(repository.requests.single.brokerId, 'yodo-demo');
      expect(repository.requests.single.serverId, 'yodo-demo-01');
      expect(harness.committer.results.single.account.id, 'account-1');
      final published = harness.container
          .read(exV2AccountProvider)
          .requireValue!;
      expect(published.bootstrap.account.id, 'account-1');
      expect(published.presentation!.brokerId, 'yodo-demo');
      expect(harness.state.phase, AccountPasswordLoginPhase.succeeded);
    },
  );

  test(
    'invalid credentials persist no token and expose safe diagnostics',
    () async {
      final repository = _FakeLoginRepository(
        error: const ExV2RequestFailure(
          statusCode: 422,
          code: 'invalid_credentials',
          correlationId: 'corr-safe-test',
          message: 'Unable to sign in.',
        ),
      );
      final tokenStore = _MemoryTokenStore();
      final harness = _harness(repository, tokenStore);
      addTearDown(harness.dispose);

      final accepted = await harness.controller.submit(
        login: '109740422',
        password: 'synthetic-wrong',
      );

      expect(accepted, isFalse);
      expect(tokenStore.value, isNull);
      expect(harness.state.errorCode, 'invalid_credentials');
      expect(harness.state.errorMessage, contains('invalid_credentials'));
      expect(harness.state.errorMessage, contains('corr-safe-test'));
    },
  );

  test('double submit while in flight sends one request', () async {
    final gate = Completer<void>();
    final repository = _FakeLoginRepository(gate: gate);
    final harness = _harness(repository, _MemoryTokenStore());
    addTearDown(harness.dispose);

    final first = harness.controller.submit(
      login: '109740422',
      password: 'synthetic-sentinel',
    );
    await Future<void>.delayed(Duration.zero);
    final second = await harness.controller.submit(
      login: '109740422',
      password: 'synthetic-sentinel',
    );

    expect(second, isFalse);
    expect(repository.calls, 1);
    gate.complete();
    expect(await first, isTrue);
  });

  test('each completed user action creates a new idempotency key', () async {
    final repository = _FakeLoginRepository();
    final harness = _harness(repository, _MemoryTokenStore());
    addTearDown(harness.dispose);

    await harness.controller.submit(
      login: '109740422',
      password: 'synthetic-first',
    );
    await harness.controller.submit(
      login: '109740422',
      password: 'synthetic-second',
    );

    expect(repository.metadata, hasLength(2));
    expect(
      repository.metadata.first.idempotencyKey,
      isNot(repository.metadata.last.idempotencyKey),
    );
  });

  test('new login replaces a higher-version different account', () async {
    final repository = _FakeLoginRepository();
    final tokenStore = _MemoryTokenStore();
    final harness = _harness(repository, tokenStore);
    addTearDown(harness.dispose);
    harness.container
        .read(exV2AccountProvider.notifier)
        .publishBootstrap(_bootstrap(version: 2, accountId: 'account-new'));

    final accepted = await harness.controller.submit(
      login: '109740422',
      password: 'synthetic-sentinel',
    );

    expect(accepted, isTrue);
    expect(tokenStore.value, 'opaque-test-token');
    expect(harness.state.phase, AccountPasswordLoginPhase.succeeded);
    expect(
      harness.container
          .read(exV2AccountProvider)
          .requireValue
          ?.bootstrap
          .account
          .id,
      'account-1',
    );
  });
}

_Harness _harness(
  _FakeLoginRepository repository,
  _MemoryTokenStore tokenStore,
) {
  late ProviderContainer container;
  final committer = _FakeSessionCommitter(
    tokenStore,
    publish: (result) => container
        .read(exV2AccountProvider.notifier)
        .publishBootstrap(
          result.bootstrap,
          authoritativeAccountSwitch: true,
          presentation: ExV2AccountPresentation(
            brokerId: result.account.brokerId,
            companyName: result.account.brokerName,
            serverId: result.account.serverId,
            tradingServer: result.account.serverName,
          ),
        ),
  );
  container = ProviderContainer(
    overrides: [
      accountPasswordLoginRepositoryProvider.overrideWithValue(repository),
      installationIdStoreProvider.overrideWithValue(
        _MemoryInstallationIdStore(),
      ),
      deviceTokenStoreProvider.overrideWithValue(tokenStore),
      accountSessionCommitterProvider.overrideWithValue(committer),
      exV2LoginConfigProvider.overrideWithValue(
        const ExV2LoginConfig(brokerId: 'yodo-demo', serverId: 'yodo-demo-01'),
      ),
    ],
  );
  container.read(accountPasswordLoginControllerProvider);
  return _Harness(container, committer);
}

final class _Harness {
  const _Harness(this.container, this.committer);

  final ProviderContainer container;
  final _FakeSessionCommitter committer;

  AccountPasswordLoginController get controller =>
      container.read(accountPasswordLoginControllerProvider.notifier);
  AccountPasswordLoginState get state =>
      container.read(accountPasswordLoginControllerProvider);
  void dispose() => container.dispose();
}

final class _FakeSessionCommitter implements AccountSessionCommitter {
  _FakeSessionCommitter(this.tokenStore, {required this.publish});

  final DeviceTokenStore tokenStore;
  final ExV2BootstrapPublication Function(AccountPasswordLoginResult) publish;
  final List<AccountPasswordLoginResult> results = [];

  @override
  Future<ExV2BootstrapPublication> commit(
    AccountPasswordLoginResult result,
  ) async {
    results.add(result);
    await tokenStore.write(result.deviceToken);
    return publish(result);
  }
}

final class _FakeLoginRepository implements AccountPasswordLoginRepository {
  _FakeLoginRepository({this.error, this.gate});

  final Object? error;
  final Completer<void>? gate;
  int calls = 0;
  final List<AccountPasswordLoginRequest> requests =
      <AccountPasswordLoginRequest>[];
  final List<ExV2CommandMetadata> metadata = <ExV2CommandMetadata>[];

  @override
  Future<AccountPasswordLoginResult> login(
    AccountPasswordLoginRequest request, {
    required String installationId,
    required ExV2CommandMetadata metadata,
  }) async {
    calls += 1;
    requests.add(request);
    this.metadata.add(metadata);
    expect(installationId, '11111111-1111-4111-8111-111111111111');
    if (gate != null) await gate!.future;
    if (error case final failure?) throw failure;
    return AccountPasswordLoginResult(
      deviceToken: 'opaque-test-token',
      account: _linkedAccount,
      bootstrap: _bootstrap(version: 1),
    );
  }
}

final class _MemoryInstallationIdStore implements InstallationIdStore {
  @override
  Future<String> readOrCreate() async => '11111111-1111-4111-8111-111111111111';
}

final class _MemoryTokenStore implements DeviceTokenStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}

const _linkedAccount = LinkedTradingAccount(
  id: 'account-1',
  brokerId: 'yodo-demo',
  brokerName: 'YODO Demo Markets',
  serverId: 'yodo-demo-01',
  serverName: 'YODO-Demo-01',
  login: '109740422',
  isActive: true,
);

ExV2Bootstrap _bootstrap({
  required int version,
  String accountId = 'account-1',
}) {
  return ExV2Bootstrap.fromJson(<String, Object?>{
    'serverTime': '2026-08-17T00:00:00Z',
    'version': version,
    'device': <String, Object?>{'id': 'device-1', 'name': 'Phone'},
    'activeAccount': <String, Object?>{
      'id': accountId,
      'accountCode': '109740422',
      'name': 'Virtual account',
      'currency': 'USD',
      'status': 'active',
    },
    'summary': <String, Object?>{
      'accountId': accountId,
      'currency': 'USD',
      'balance': 0,
      'equity': 0,
      'profit': 0,
      'margin': 0,
      'freeMargin': 0,
      'marginLevel': 0,
      'updatedAt': '2026-08-17T00:00:00Z',
    },
    'positions': <Object?>[],
    'pendingOrders': <Object?>[],
    'recentDeals': <Object?>[],
    'wallet': <String, Object?>{
      'currency': 'USD',
      'availableBalance': 0,
      'lockedBalance': 0,
      'totalBalance': 0,
    },
    'performance': <String, Object?>{
      'netProfit': 0,
      'grossProfit': 0,
      'grossLoss': 0,
      'floatingProfit': 0,
      'tradingVolume': 0,
      'updatedAt': null,
      'integrityWarnings': 0,
    },
    'connection': <String, Object?>{
      'marketFeedStatus': 'connected',
      'lastMarketTickAt': null,
    },
    'integrityWarnings': 0,
  });
}
