import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_hub/signalr_client.dart';
import 'package:trading_mobile/features/account_link/application/account_activation_coordinator.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sessions/application/account_switch_guard.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_realtime_service.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  test(
    'shared switch guard rejects activation before repository access',
    () async {
      final repository = _UnexpectedActivationRepository();
      final guard = AccountSwitchGuard();
      final lease = guard.tryAcquire()!;
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(false),
          accountSwitchGuardProvider.overrideWithValue(guard),
          accountLinkRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() {
        guard.release(lease);
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);

      await expectLater(
        container
            .read(accountActivationCoordinatorProvider.notifier)
            .activate(
              'account-b',
              metadata: const ExV2CommandMetadata(
                idempotencyKey: 'guarded-activation',
                correlationId: 'guarded-activation-correlation',
              ),
            ),
        throwsA(isA<AccountSwitchInProgress>()),
      );
      expect(repository.activateCalls, 0);
    },
  );

  test(
    'concurrent server activation is rejected while the first completes',
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

      final firstRequest = coordinator.activate(
        'account-a',
        metadata: const ExV2CommandMetadata(
          idempotencyKey: 'activate-a',
          correlationId: 'correlation-a',
        ),
      );
      await expectLater(
        coordinator.activate(
          'account-b',
          metadata: const ExV2CommandMetadata(
            idempotencyKey: 'activate-b',
            correlationId: 'correlation-b',
          ),
        ),
        throwsA(isA<AccountSwitchInProgress>()),
      );

      repository.complete('account-a', version: 2);
      final first = await firstRequest;

      expect(first.authority, 1);
      expect(first.publication, ExV2BootstrapPublication.committed);
      expect(first.accepted, isTrue);
      final active = container.read(exV2AccountProvider).requireValue!;
      expect(active.bootstrap.version, 2);
      expect(active.bootstrap.account.id, 'account-a');
      expect(active.presentation?.companyName, 'First Broker Ltd');
      expect(active.presentation?.tradingServer, 'First-Demo-01');
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

  test('accepted activation restarts account-scoped realtime once', () async {
    final repository = _OutOfOrderActivationRepository();
    final hubs = <_RecordingHubConnection>[];
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2RealtimeEnabledProvider.overrideWithValue(true),
        exV2AccountProvider.overrideWithBuild(
          (ref, controller) async => ExV2AccountViewState.fromBootstrap(
            _bootstrap('account-a', version: 1),
          ),
        ),
        accountLinkRepositoryProvider.overrideWithValue(repository),
        exV2RealtimeServiceProvider.overrideWith((ref) {
          final hub = _RecordingHubConnection();
          hubs.add(hub);
          return ExV2RealtimeService(
            hubUrl: 'https://example.com/ex/v2/hubs/trading',
            tokenReader: () async => 'global-device-token',
            connectionFactory: () => hub,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    await container
        .read(exV2AccountProvider.notifier)
        .restartRealtimeForCurrentToken();
    expect(hubs, hasLength(1));

    final activation = container
        .read(accountActivationCoordinatorProvider.notifier)
        .activate(
          'account-b',
          metadata: const ExV2CommandMetadata(
            idempotencyKey: 'activate-realtime-b',
            correlationId: 'activate-realtime-b-correlation',
          ),
        );
    repository.complete('account-b', version: 2);

    final outcome = await activation;
    await _waitFor(
      () => hubs.length == 2 && hubs.last.invocations.contains('Subscribe'),
      'the replacement realtime subscription',
    );

    expect(outcome.accepted, isTrue);
    expect(hubs, hasLength(2));
    expect(hubs.first.stopCalls, 1);
    expect(hubs.last.invocations, ['Subscribe']);
  });

  test(
    'accepted activation returns before realtime reconnect completes',
    () async {
      final repository = _OutOfOrderActivationRepository();
      final reconnectGate = Completer<void>();
      final hubs = <_RecordingHubConnection>[];
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2RealtimeEnabledProvider.overrideWithValue(true),
          exV2AccountProvider.overrideWithBuild(
            (ref, controller) async => ExV2AccountViewState.fromBootstrap(
              _bootstrap('account-a', version: 1),
            ),
          ),
          accountLinkRepositoryProvider.overrideWithValue(repository),
          exV2RealtimeServiceProvider.overrideWith((ref) {
            final hub = _RecordingHubConnection(
              startGate: hubs.isEmpty ? null : reconnectGate,
            );
            hubs.add(hub);
            return ExV2RealtimeService(
              hubUrl: 'https://example.com/ex/v2/hubs/trading',
              tokenReader: () async => 'global-device-token',
              connectionFactory: () => hub,
            );
          }),
        ],
      );
      addTearDown(() {
        if (!reconnectGate.isCompleted) reconnectGate.complete();
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);
      await container
          .read(exV2AccountProvider.notifier)
          .restartRealtimeForCurrentToken();

      var activationCompleted = false;
      final activation = container
          .read(accountActivationCoordinatorProvider.notifier)
          .activate(
            'account-b',
            metadata: const ExV2CommandMetadata(
              idempotencyKey: 'activate-with-slow-realtime',
              correlationId: 'activate-with-slow-realtime-correlation',
            ),
          )
          .whenComplete(() => activationCompleted = true);
      repository.complete('account-b', version: 2);
      await _waitFor(
        () => hubs.length == 2,
        'the blocked replacement realtime connection',
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(exV2AccountProvider).requireValue!.bootstrap.account.id,
        'account-b',
      );
      expect(reconnectGate.isCompleted, isFalse);
      expect(activationCompleted, isTrue);
      expect((await activation).accepted, isTrue);
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

  test(
    'activation rejects a canonical bootstrap for another account',
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
          .publishBootstrap(_bootstrap('account-a', version: 10));

      final activation = container
          .read(accountActivationCoordinatorProvider.notifier)
          .activate(
            'account-b',
            metadata: const ExV2CommandMetadata(
              idempotencyKey: 'activate-identity-check',
              correlationId: 'activate-identity-check-correlation',
            ),
          );
      repository.complete(
        'account-b',
        version: 11,
        bootstrap: _bootstrap('account-a', version: 11),
      );

      await expectLater(
        activation,
        throwsA(isA<AccountActivationIdentityMismatch>()),
      );
      expect(
        container.read(exV2AccountProvider).requireValue?.bootstrap.account.id,
        'account-a',
      );
    },
  );

  test('market feed disconnection does not block REST activation', () async {
    final repository = _OutOfOrderActivationRepository();
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(false),
        accountMutationsConnectedProvider.overrideWithValue(false),
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
            idempotencyKey: 'activate-with-feed-offline',
            correlationId: 'activate-with-feed-offline-correlation',
          ),
        );
    repository.complete('account-b', version: 1);

    expect((await activation).accepted, isTrue);
  });
}

Future<void> _waitFor(bool Function() condition, String description) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

final class _UnexpectedActivationRepository implements AccountLinkRepository {
  var activateCalls = 0;

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) {
    activateCalls += 1;
    throw StateError('Activation repository should not be called');
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

final class _RecordingHubConnection implements HubConnection {
  _RecordingHubConnection({this.startGate});

  final Completer<void>? startGate;
  HubConnectionState? _state = HubConnectionState.disconnected;
  final invocations = <String>[];
  int stopCalls = 0;

  @override
  HubConnectionState? get state => _state;

  @override
  void on(String methodName, void Function(List<Object?>?) handler) {}

  @override
  Future<Object?> invoke(String methodName, {List<Object?>? args}) async {
    invocations.add(methodName);
    return null;
  }

  @override
  Future<void> start() async {
    if (startGate case final gate?) await gate.future;
    _state = HubConnectionState.connected;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    _state = HubConnectionState.disconnected;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
