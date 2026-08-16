import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/data/account_reconnect_grant_store.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

void main() {
  test('repeat submit is rejected while the first link is in flight', () async {
    final gate = Completer<void>();
    final repository = _FakeRepository(linkGate: gate);
    final harness = await _harness(repository: repository);
    addTearDown(harness.dispose);

    final first = harness.controller.submit();
    await Future<void>.delayed(Duration.zero);
    harness.controller.updateLogin('100002');
    final second = await harness.controller.submit();

    expect(second, isNull);
    expect(repository.linkCalls, 1);
    expect(harness.state.phase, AccountLinkPhase.editing);
    gate.complete();
    await first;
  });

  test('edit during activation cannot bypass the operation lock', () async {
    final activateGate = Completer<void>();
    final repository = _FakeRepository(activateGate: activateGate);
    final harness = await _harness(repository: repository);
    addTearDown(harness.dispose);

    final first = harness.controller.submit();
    while (repository.activateCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    harness.controller.updatePassword('edited-password');
    final second = await harness.controller.submit();

    expect(second, isNull);
    expect(repository.linkCalls, 1);
    expect(repository.activateCalls, 1);
    expect(harness.state.phase, AccountLinkPhase.editing);
    activateGate.complete();
    await first;
  });

  test('invalid credentials clear only the password field', () async {
    final repository = _FakeRepository(
      linkError: const ExV2RequestFailure(
        statusCode: 401,
        code: 'invalid_credentials',
        message: 'Invalid credentials',
      ),
    );
    final harness = await _harness(repository: repository);
    addTearDown(harness.dispose);

    await harness.controller.submit();

    expect(harness.state.phase, AccountLinkPhase.failed);
    expect(harness.state.selectedBroker?.id, 'broker-1');
    expect(harness.state.selectedServer?.id, 'server-1');
    expect(harness.state.login, '100001');
    expect(harness.state.password, isEmpty);
    expect(harness.state.savePassword, isTrue);
  });

  test('an already-linked result is activated instead of duplicated', () async {
    final repository = _FakeRepository(alreadyLinked: true);
    final harness = await _harness(repository: repository);
    addTearDown(harness.dispose);

    await harness.controller.submit();

    expect(repository.linkCalls, 1);
    expect(repository.activateCalls, 1);
    expect(repository.activatedAccountIds, ['account-1']);
    expect(harness.state.phase, AccountLinkPhase.succeeded);
  });

  test('save-password persists only the opaque reconnect grant', () async {
    final repository = _FakeRepository(reconnectGrant: 'opaque-grant-1');
    final grantStore = _MemoryGrantStore();
    final harness = await _harness(
      repository: repository,
      grantStore: grantStore,
    );
    addTearDown(harness.dispose);

    await harness.controller.submit();

    expect(grantStore.values, {'account-1': 'opaque-grant-1'});
    expect(grantStore.allWrittenValues, ['opaque-grant-1']);
    expect(grantStore.allWrittenValues, isNot(contains('transient-password')));
  });

  test('disabled save-password keeps the grant in memory only', () async {
    final repository = _FakeRepository(reconnectGrant: 'opaque-grant-1');
    final grantStore = _MemoryGrantStore()..values['account-1'] = 'old-grant';
    final harness = await _harness(
      repository: repository,
      grantStore: grantStore,
      savePassword: false,
    );
    addTearDown(harness.dispose);

    await harness.controller.submit();

    expect(grantStore.values, isEmpty);
    expect(grantStore.allWrittenValues, isEmpty);
    expect(harness.state.reconnectGrant, 'opaque-grant-1');
  });

  test('activation publishes one complete bootstrap before success', () async {
    final events = <String>[];
    final repository = _FakeRepository(events: events);
    final harness = await _harness(
      repository: repository,
      onBootstrap: (bootstrap) {
        expect(bootstrap.account.id, bootstrap.summary.accountId);
        events.add('publish:${bootstrap.account.id}');
      },
    );
    addTearDown(harness.dispose);

    await harness.controller.submit();
    events.add('state:${harness.state.phase.name}');

    expect(events, [
      'link',
      'activate:account-1',
      'publish:account-1',
      'state:succeeded',
    ]);
  });

  test('a slower broker query cannot overwrite a newer query', () async {
    final repository = _CatalogRepository();
    final container = ProviderContainer(
      overrides: [accountLinkRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(accountLinkControllerProvider.future);
    final controller = container.read(accountLinkControllerProvider.notifier);

    final older = controller.loadCatalog(query: 'old');
    final newer = controller.loadCatalog(query: 'new');
    repository.brokerRequests['new']!.complete(const [
      MobileBroker(id: 'broker-new', name: 'New Broker'),
    ]);
    await newer;
    repository.brokerRequests['old']!.complete(const [
      MobileBroker(id: 'broker-old', name: 'Old Broker'),
    ]);
    await older;

    final state = container.read(accountLinkControllerProvider).requireValue;
    expect(state.brokers.single.id, 'broker-new');
  });

  test('servers from a previously selected broker are discarded', () async {
    final repository = _CatalogRepository();
    final container = ProviderContainer(
      overrides: [accountLinkRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(accountLinkControllerProvider.future);
    final controller = container.read(accountLinkControllerProvider.notifier);
    const brokerA = MobileBroker(id: 'broker-a', name: 'Broker A');
    const brokerB = MobileBroker(id: 'broker-b', name: 'Broker B');

    controller.selectBroker(brokerA);
    final older = controller.loadServers('broker-a');
    controller.selectBroker(brokerB);
    final newer = controller.loadServers('broker-b');
    repository.serverRequests['broker-b']!.complete(const [
      MobileTradingServer(
        id: 'server-b',
        name: 'Server B',
        brokerId: 'broker-b',
      ),
    ]);
    await newer;
    repository.serverRequests['broker-a']!.complete(const [
      MobileTradingServer(
        id: 'server-a',
        name: 'Server A',
        brokerId: 'broker-a',
      ),
    ]);
    await older;

    final state = container.read(accountLinkControllerProvider).requireValue;
    expect(state.selectedBroker?.id, 'broker-b');
    expect(state.servers.single.id, 'server-b');
  });
}

Future<_Harness> _harness({
  required _FakeRepository repository,
  AccountReconnectGrantStore? grantStore,
  bool savePassword = true,
  void Function(ExV2Bootstrap bootstrap)? onBootstrap,
}) async {
  final container = ProviderContainer(
    overrides: [
      accountLinkRepositoryProvider.overrideWithValue(repository),
      accountReconnectGrantStoreProvider.overrideWithValue(
        grantStore ?? _MemoryGrantStore(),
      ),
      accountLinkBootstrapPublisherProvider.overrideWithValue(
        onBootstrap ?? (_) {},
      ),
    ],
  );
  await container.read(accountLinkControllerProvider.future);
  final controller = container.read(accountLinkControllerProvider.notifier);
  controller.selectBroker(
    const MobileBroker(id: 'broker-1', name: 'Example Markets'),
  );
  controller.selectServer(
    const MobileTradingServer(id: 'server-1', name: 'Example-Demo'),
  );
  controller.updateLogin('100001');
  controller.updatePassword('transient-password');
  controller.updateSavePassword(savePassword);
  return _Harness(container, controller);
}

final class _Harness {
  const _Harness(this.container, this.controller);

  final ProviderContainer container;
  final AccountLinkController controller;

  AccountLinkState get state =>
      container.read(accountLinkControllerProvider).requireValue;

  void dispose() => container.dispose();
}

final class _FakeRepository implements AccountLinkRepository {
  _FakeRepository({
    this.linkGate,
    this.activateGate,
    this.linkError,
    this.alreadyLinked = false,
    this.reconnectGrant = 'opaque-grant-1',
    this.events,
  });

  final Completer<void>? linkGate;
  final Completer<void>? activateGate;
  final Object? linkError;
  final bool alreadyLinked;
  final String? reconnectGrant;
  final List<String>? events;
  int linkCalls = 0;
  int activateCalls = 0;
  final List<String> activatedAccountIds = <String>[];

  @override
  Future<List<LinkedTradingAccount>> accounts() async => const [];

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) async {
    activateCalls += 1;
    activatedAccountIds.add(accountId);
    events?.add('activate:$accountId');
    if (activateGate != null) await activateGate!.future;
    return ActivateLinkedAccountResult(
      account: _account,
      bootstrap: ExV2Bootstrap.fromJson(_bootstrapJson),
    );
  }

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) async => const [];

  @override
  Future<LinkAccountResult> link(
    LinkAccountRequest request, {
    required ExV2CommandMetadata metadata,
  }) async {
    linkCalls += 1;
    events?.add('link');
    if (linkGate != null) await linkGate!.future;
    if (linkError case final error?) throw error;
    return LinkAccountResult(
      account: _account,
      reconnectGrant: reconnectGrant,
      alreadyLinked: alreadyLinked,
    );
  }

  @override
  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) async => const [];
}

final class _CatalogRepository implements AccountLinkRepository {
  final Map<String, Completer<List<MobileBroker>>> brokerRequests = {};
  final Map<String, Completer<List<MobileTradingServer>>> serverRequests = {};

  @override
  Future<List<LinkedTradingAccount>> accounts() async => const [];

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) {
    final request = Completer<List<MobileBroker>>();
    brokerRequests[query] = request;
    return request.future;
  }

  @override
  Future<LinkAccountResult> link(
    LinkAccountRequest request, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();

  @override
  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) {
    final request = Completer<List<MobileTradingServer>>();
    serverRequests[brokerId] = request;
    return request.future;
  }
}

final class _MemoryGrantStore implements AccountReconnectGrantStore {
  final Map<String, String> values = <String, String>{};
  final List<String> allWrittenValues = <String>[];

  @override
  Future<void> delete(String accountId) async => values.remove(accountId);

  @override
  Future<String?> read(String accountId) async => values[accountId];

  @override
  Future<void> write(String accountId, String grant) async {
    values[accountId] = grant;
    allWrittenValues.add(grant);
  }
}

const _account = LinkedTradingAccount(
  id: 'account-1',
  brokerId: 'broker-1',
  brokerName: 'Example Markets',
  serverId: 'server-1',
  serverName: 'Example-Demo',
  login: '100001',
  isActive: true,
);

const _bootstrapJson = <String, Object?>{
  'serverTime': '2026-08-15T08:00:00Z',
  'version': 2,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-1',
    'accountCode': '100001',
    'name': 'Demo account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 0,
    'equity': 0,
    'profit': 0,
    'margin': 0,
    'freeMargin': 0,
    'marginLevel': 0,
    'updatedAt': '2026-08-15T08:00:00Z',
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
};
