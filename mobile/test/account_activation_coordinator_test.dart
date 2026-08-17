import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/application/account_activation_coordinator.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  test(
    'global activation authority commits responses by device version',
    () async {
      final repository = _OutOfOrderActivationRepository();
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(false),
          accountLinkRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      final coordinator = container.read(
        accountActivationCoordinatorProvider.notifier,
      );

      final olderRequest = coordinator.activate(
        'account-a',
        metadata: const ExV2CommandMetadata(
          idempotencyKey: 'activate-a',
          correlationId: 'correlation-a',
        ),
      );
      final newerRequest = coordinator.activate(
        'account-b',
        metadata: const ExV2CommandMetadata(
          idempotencyKey: 'activate-b',
          correlationId: 'correlation-b',
        ),
      );

      repository.complete('account-b', version: 3);
      final newer = await newerRequest;
      repository.complete('account-a', version: 2);
      final older = await olderRequest;

      expect(older.authority, 1);
      expect(newer.authority, 2);
      expect(newer.publication, ExV2BootstrapPublication.committed);
      expect(older.publication, ExV2BootstrapPublication.rejectedStale);
      expect(newer.accepted, isTrue);
      expect(older.accepted, isFalse);
      final active = container.read(exV2AccountProvider).requireValue!;
      expect(active.bootstrap.version, 3);
      expect(active.bootstrap.account.id, 'account-b');
      expect(active.presentation?.companyName, 'Second Broker Ltd');
      expect(active.presentation?.tradingServer, 'Second-Live-02');
    },
  );

  test(
    'same-version replay requires the same active account identity',
    () async {
      final container = ProviderContainer(
        overrides: [exV2EnabledProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      final controller = container.read(exV2AccountProvider.notifier);

      expect(
        controller.publishBootstrap(
          _bootstrap('account-a', version: 4),
          operationAuthority: 1,
        ),
        ExV2BootstrapPublication.committed,
      );
      expect(
        controller.publishBootstrap(
          _bootstrap('account-a', version: 4),
          operationAuthority: 1,
        ),
        ExV2BootstrapPublication.idempotentReplay,
      );
      expect(
        controller.publishBootstrap(
          _bootstrap('account-b', version: 4),
          operationAuthority: 2,
        ),
        ExV2BootstrapPublication.rejectedStale,
      );
      expect(
        container.read(exV2AccountProvider).requireValue?.bootstrap.account.id,
        'account-a',
      );
    },
  );

  test(
    'authoritative activation replaces a higher-version different account',
    () async {
      final repository = _OutOfOrderActivationRepository();
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(false),
          accountLinkRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      container
          .read(exV2AccountProvider.notifier)
          .publishBootstrap(_bootstrap('account-a', version: 50));

      final activation = container
          .read(accountActivationCoordinatorProvider.notifier)
          .activate(
            'account-b',
            metadata: const ExV2CommandMetadata(
              idempotencyKey: 'activate-lower-version-account',
              correlationId: 'lower-version-account-correlation',
            ),
          );
      repository.complete(
        'account-b',
        version: 1,
        bootstrap: ExV2Bootstrap.fromJson({
          ..._secondBrokerBootstrapJson,
          'version': 1,
        }),
      );

      final outcome = await activation;
      final active = container.read(exV2AccountProvider).requireValue!;
      expect(outcome.accepted, isTrue);
      expect(outcome.publication, ExV2BootstrapPublication.committed);
      expect(active.bootstrap.account.id, 'account-b');
      expect(active.bootstrap.summary.accountId, 'account-b');
      expect(active.balance, 1000);
      expect(active.positions.single.id, 'second-position');
      expect(active.presentation?.companyName, 'Second Broker Ltd');
      expect(active.presentation?.tradingServer, 'Second-Live-02');
    },
  );

  test(
    'second broker presentation survives core mutation reconciliation',
    () async {
      final repository = _OutOfOrderActivationRepository();
      final adapter = _SecondBrokerMutationAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(false),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('device-token'),
          ),
          accountLinkRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      final activation = container
          .read(accountActivationCoordinatorProvider.notifier)
          .activate(
            'account-b',
            metadata: const ExV2CommandMetadata(
              idempotencyKey: 'activate-second',
              correlationId: 'activate-second-correlation',
            ),
          );
      repository.complete(
        'account-b',
        version: 2,
        bootstrap: _secondBrokerBootstrap,
      );
      expect((await activation).accepted, isTrue);

      await container
          .read(exV2AccountProvider.notifier)
          .updatePositionProtection(
            positionId: 'second-position',
            stopLoss: 1.05,
          );

      final state = container.read(exV2AccountProvider).requireValue!;
      final profile = container.read(activeDemoAccountProvider);
      expect(state.settings, isEmpty);
      expect(state.presentation?.companyName, 'Second Broker Ltd');
      expect(state.presentation?.tradingServer, 'Second-Live-02');
      expect(profile.company, 'Second Broker Ltd');
      expect(profile.server, 'Second-Live-02');
    },
  );
}

final class _OutOfOrderActivationRepository implements AccountLinkRepository {
  final Map<String, Completer<ActivateLinkedAccountResult>> _requests = {};

  void complete(
    String accountId, {
    required int version,
    ExV2Bootstrap? bootstrap,
  }) {
    _requests[accountId]!.complete(
      ActivateLinkedAccountResult(
        account: _account(accountId),
        bootstrap: bootstrap ?? _bootstrap(accountId, version: version),
      ),
    );
  }

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) {
    final request = Completer<ActivateLinkedAccountResult>();
    _requests[accountId] = request;
    return request.future;
  }

  @override
  Future<List<LinkedTradingAccount>> accounts() => throw UnimplementedError();

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) =>
      throw UnimplementedError();

  @override
  Future<LinkAccountResult> link(
    LinkAccountRequest request, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();

  @override
  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) => throw UnimplementedError();
}

LinkedTradingAccount _account(String id) => LinkedTradingAccount(
  id: id,
  brokerId: id == 'account-b' ? 'broker-second' : 'broker-first',
  brokerName: id == 'account-b' ? 'Second Broker Ltd' : 'First Broker Ltd',
  serverId: id == 'account-b' ? 'server-second' : 'server-first',
  serverName: id == 'account-b' ? 'Second-Live-02' : 'First-Demo-01',
  login: id == 'account-b' ? '200002' : '100001',
  isActive: true,
);

ExV2Bootstrap _bootstrap(String id, {required int version}) =>
    ExV2Bootstrap.fromJson({
      'serverTime': '2026-08-16T08:00:00Z',
      'version': version,
      'device': {'id': 'device-1', 'name': 'Phone'},
      'activeAccount': {
        'id': id,
        'accountCode': id == 'account-b' ? '200002' : '100001',
        'name': id == 'account-b' ? 'Second account' : 'First account',
        'currency': 'USD',
        'status': 'active',
      },
      'summary': {
        'accountId': id,
        'currency': 'USD',
        'balance': 0,
        'equity': 0,
        'profit': 0,
        'margin': 0,
        'freeMargin': 0,
        'marginLevel': 0,
        'updatedAt': '2026-08-16T08:00:00Z',
      },
      'positions': <Object?>[],
      'pendingOrders': <Object?>[],
      'recentDeals': <Object?>[],
      'wallet': {
        'currency': 'USD',
        'availableBalance': 0,
        'lockedBalance': 0,
        'totalBalance': 0,
      },
      'performance': {
        'netProfit': 0,
        'grossProfit': 0,
        'grossLoss': 0,
        'floatingProfit': 0,
        'tradingVolume': 0,
        'updatedAt': null,
        'integrityWarnings': 0,
      },
      'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
      'integrityWarnings': 0,
    });

final Map<String, Object?> _secondBrokerBootstrapJson = {
  'serverTime': '2026-08-16T08:00:00Z',
  'version': 2,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-b',
    'accountCode': '200002',
    'name': 'Second account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': 'account-b',
    'currency': 'USD',
    'balance': 1000,
    'equity': 1000,
    'profit': 0,
    'margin': 10,
    'freeMargin': 990,
    'marginLevel': 10000,
    'updatedAt': '2026-08-16T08:00:00Z',
  },
  'positions': [
    {
      'id': 'second-position',
      'symbol': 'EURUSD',
      'side': 'buy',
      'initialVolume': 0.1,
      'remainingVolume': 0.1,
      'entryPrice': 1.1,
      'realizedProfit': 0,
      'status': 'open',
      'stopLoss': null,
      'takeProfit': null,
      'createdAt': '2026-08-16T08:00:00Z',
      'closedAt': null,
      'rowVersion': 'row-1',
    },
  ],
  'pendingOrders': <Object?>[],
  'recentDeals': <Object?>[],
  'wallet': {
    'currency': 'USD',
    'availableBalance': 0,
    'lockedBalance': 0,
    'totalBalance': 0,
  },
  'performance': {
    'netProfit': 0,
    'grossProfit': 0,
    'grossLoss': 0,
    'floatingProfit': 0,
    'tradingVolume': 0,
    'updatedAt': null,
    'integrityWarnings': 0,
  },
  'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
  'integrityWarnings': 0,
};

final ExV2Bootstrap _secondBrokerBootstrap = ExV2Bootstrap.fromJson(
  _secondBrokerBootstrapJson,
);

final class _SecondBrokerMutationAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final Object payload;
    if (path.endsWith('/mobile/bootstrap')) {
      payload = _secondBrokerBootstrapJson;
    } else if (path.endsWith('/settings')) {
      payload = <String, Object?>{};
    } else if (options.method != 'GET') {
      payload = <String, Object?>{};
    } else {
      payload = <Object?>[];
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _MemoryTokenStore implements DeviceTokenStore {
  _MemoryTokenStore(this.value);

  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}
