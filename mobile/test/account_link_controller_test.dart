import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/data/linked_account_presentation_store.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/domain/linked_account_presentation.dart';
import 'package:trading_mobile/features/account_login/data/account_password_login_dependencies.dart';
import 'package:trading_mobile/features/account_login/data/account_password_login_repository.dart';
import 'package:trading_mobile/features/account_login/data/installation_id_store.dart';
import 'package:trading_mobile/features/account_login/domain/account_password_login_models.dart';
import 'package:trading_mobile/features/account_sessions/application/account_session_committer.dart';
import 'package:trading_mobile/features/account_sessions/data/removed_account_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

void main() {
  test('identity edit stales an in-flight account link', () async {
    final linkGate = Completer<void>();
    final loginGate = Completer<void>();
    final repository = _FakeRepository(linkGate: linkGate);
    final loginRepository = _FakeLoginRepository(
      account: _account,
      gate: loginGate,
    );
    final harness = await _harness(
      repository: repository,
      loginRepository: loginRepository,
    );
    addTearDown(harness.dispose);

    final first = harness.controller.submit();
    while (repository.linkRequests.isEmpty &&
        loginRepository.requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    harness.controller.updateLogin('100002');
    final second = await harness.controller.submit();
    if (!linkGate.isCompleted) linkGate.complete();
    if (!loginGate.isCompleted) loginGate.complete();
    await first;

    expect(second, isNull);
    expect(repository.linkRequests, hasLength(1));
    expect(repository.activatedAccountIds, isEmpty);
    expect(harness.state.phase, AccountLinkPhase.editing);
    expect(harness.state.login, '100002');
    expect(harness.state.password, isEmpty);
  });

  test('edit during activation cannot bypass the operation lock', () async {
    final activationGate = Completer<void>();
    final loginGate = Completer<void>();
    final repository = _FakeRepository(activationGate: activationGate);
    final loginRepository = _FakeLoginRepository(
      account: _account,
      gate: loginGate,
    );
    final harness = await _harness(
      repository: repository,
      loginRepository: loginRepository,
    );
    addTearDown(harness.dispose);

    final first = harness.controller.submit();
    while (repository.activatedAccountIds.isEmpty &&
        loginRepository.requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    harness.controller.updatePassword('edited-password');
    final second = await harness.controller.submit();
    if (!activationGate.isCompleted) activationGate.complete();
    if (!loginGate.isCompleted) loginGate.complete();
    await first;

    expect(second, isNull);
    expect(repository.linkRequests, hasLength(1));
    expect(repository.activatedAccountIds, hasLength(1));
    expect(harness.state.phase, AccountLinkPhase.succeeded);
  });

  test(
    'identity edit during activation clears the submitted password',
    () async {
      final activationGate = Completer<void>();
      final repository = _FakeRepository(activationGate: activationGate);
      final harness = await _harness(repository: repository);
      addTearDown(harness.dispose);

      final submission = harness.controller.submit();
      await _waitFor(
        () => repository.activatedAccountIds.isNotEmpty,
        'the account activation request',
      );
      harness.controller.updateLogin('100002');
      activationGate.complete();

      expect(await submission, isNull);
      expect(harness.state.phase, AccountLinkPhase.editing);
      expect(harness.state.login, '100002');
      expect(harness.state.password, isEmpty);
    },
  );

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
  });

  test('invalid credentials expose the safe error code to the UI', () async {
    final repository = _FakeRepository(
      linkError: const ExV2RequestFailure(
        statusCode: 422,
        code: 'invalid_credentials',
        correlationId: 'corr-safe-ui',
        message: 'Unable to link this virtual account.',
      ),
    );
    final harness = await _harness(repository: repository);
    addTearDown(harness.dispose);

    await harness.controller.submit();

    expect(harness.state.errorMessage, contains('invalid_credentials'));
    expect(harness.state.errorMessage, contains('corr-safe-ui'));
  });

  test('terminal link failures clear the submitted password', () async {
    final repository = _FakeRepository(
      linkError: const FormatException('Malformed link response'),
    );
    final harness = await _harness(repository: repository);
    addTearDown(harness.dispose);

    await harness.controller.submit();

    expect(harness.state.phase, AccountLinkPhase.failed);
    expect(harness.state.login, '100001');
    expect(harness.state.password, isEmpty);
  });

  test(
    'submit links selected IDs and never asks the server to save a password',
    () async {
      final repository = _FakeRepository(
        linkedAccount: const LinkedTradingAccount(
          id: 'account-109740422',
          brokerId: 'yodo-demo',
          brokerName: 'YODO Demo Markets',
          serverId: 'yodo-demo-01',
          serverName: 'YODO-Demo-01',
          login: '109740422',
          isActive: false,
        ),
      );
      final harness = await _harness(repository: repository);
      addTearDown(harness.dispose);
      harness.controller.selectBroker(
        const MobileBroker(id: 'yodo-demo', name: 'YODO Demo Markets'),
      );
      harness.controller.selectServer(
        const MobileTradingServer(
          id: 'yodo-demo-01',
          name: 'YODO-Demo-01',
          brokerId: 'yodo-demo',
        ),
      );
      harness.controller.updateLogin('109740422');
      harness.controller.updatePassword('old-password');
      harness.controller.updatePassword(' Test-Pass_123! ');

      await harness.controller.submit();

      expect(repository.linkRequests.single.toJson(), {
        'brokerId': 'yodo-demo',
        'serverId': 'yodo-demo-01',
        'login': '109740422',
        'password': ' Test-Pass_123! ',
        'savePassword': false,
      });
      expect(repository.linkRequests.single.login, isNot('2022'));
    },
  );

  test('each new submit action creates a new idempotency key', () async {
    final repository = _FakeRepository();
    final harness = await _harness(repository: repository);
    addTearDown(harness.dispose);

    await harness.controller.submit();
    harness.controller.updatePassword('new-user-input');
    await harness.controller.submit();

    expect(repository.linkMetadata, hasLength(2));
    expect(
      repository.linkMetadata[0].idempotencyKey,
      isNot(repository.linkMetadata[1].idempotencyKey),
    );
  });

  test('successful submit links then activates canonical account', () async {
    final repository = _FakeRepository();
    final harness = await _harness(repository: repository);
    addTearDown(harness.dispose);

    final result = await harness.controller.submit();

    expect(repository.linkCalls, 1);
    expect(repository.activateCalls, 1);
    expect(repository.activatedAccountIds, ['account-1']);
    expect(harness.loginRepository.requests, isEmpty);
    expect(harness.committer.results, isEmpty);
    expect(result?.account.id, 'account-1');
    expect(harness.state.phase, AccountLinkPhase.succeeded);
  });

  test('successful link restores only the explicitly added account', () async {
    final removedStore = _MemoryRemovedAccountStore({
      _account.id,
      'account-other',
    });
    final harness = await _harness(
      repository: _FakeRepository(),
      removedStore: removedStore,
    );
    addTearDown(harness.dispose);

    final result = await harness.controller.submit();

    expect(result, isNotNull);
    expect(await removedStore.read(), {'account-other'});
  });

  test('successful link remembers the exact selected server label', () async {
    final presentationStore = _MemoryPresentationStore();
    final harness = await _harness(
      repository: _FakeRepository(
        linkedAccount: const LinkedTradingAccount(
          id: 'account-1',
          brokerId: 'yodo-demo',
          brokerName: 'YODO Demo Markets',
          serverId: 'yodo-demo-01',
          serverName: 'YODO-Demo-01',
          login: '100001',
          isActive: false,
        ),
      ),
      presentationStore: presentationStore,
    );
    addTearDown(harness.dispose);
    harness.controller.selectBroker(
      const MobileBroker(id: 'yodo-demo', name: 'YODO Demo Markets'),
    );
    harness.controller.selectServer(
      const MobileTradingServer(
        id: 'yodo-demo-01',
        name: 'Exness-MT5Real26',
        brokerId: 'yodo-demo',
      ),
    );

    await harness.controller.submit();

    expect(
      presentationStore.values['account-1']?.companyName,
      'Exness Technologies Ltd',
    );
    expect(
      presentationStore.values['account-1']?.serverName,
      'Exness-MT5Real26',
    );
  });

  test('link identity mismatch does not activate', () async {
    final repository = _FakeRepository(
      linkedAccount: const LinkedTradingAccount(
        id: 'wrong-account',
        brokerId: 'broker-1',
        brokerName: 'Example Markets',
        serverId: 'server-1',
        serverName: 'Example-Demo',
        login: '999999',
        isActive: false,
      ),
    );
    final harness = await _harness(repository: repository);
    addTearDown(harness.dispose);

    final result = await harness.controller.submit();

    expect(result, isNull);
    expect(repository.activateCalls, 0);
    expect(harness.state.phase, AccountLinkPhase.failed);
    expect(harness.state.password, isEmpty);
  });

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

Future<void> _waitFor(bool Function() condition, String description) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<_Harness> _harness({
  required _FakeRepository repository,
  LinkedAccountPresentationStore? presentationStore,
  RemovedAccountStore? removedStore,
  _FakeLoginRepository? loginRepository,
}) async {
  final resolvedLoginRepository =
      loginRepository ?? _FakeLoginRepository(account: _account);
  final resolvedCommitter = _FakeCommitter();
  final container = ProviderContainer(
    overrides: [
      accountLinkRepositoryProvider.overrideWithValue(repository),
      accountPasswordLoginRepositoryProvider.overrideWithValue(
        resolvedLoginRepository,
      ),
      installationIdStoreProvider.overrideWithValue(_InstallationStore()),
      accountSessionCommitterProvider.overrideWithValue(resolvedCommitter),
      linkedAccountPresentationStoreProvider.overrideWithValue(
        presentationStore ?? _MemoryPresentationStore(),
      ),
      removedAccountStoreProvider.overrideWithValue(
        removedStore ?? _MemoryRemovedAccountStore(const {}),
      ),
    ],
  );
  await container.read(accountLinkControllerProvider.future);
  final controller = container.read(accountLinkControllerProvider.notifier);
  controller.selectBroker(
    const MobileBroker(id: 'broker-1', name: 'Example Markets'),
  );
  controller.selectServer(
    const MobileTradingServer(
      id: 'server-1',
      name: 'Example-Demo',
      brokerId: 'broker-1',
    ),
  );
  controller.updateLogin('100001');
  controller.updatePassword('transient-password');
  return _Harness(
    container,
    controller,
    loginRepository: resolvedLoginRepository,
    committer: resolvedCommitter,
  );
}

final class _Harness {
  const _Harness(
    this.container,
    this.controller, {
    required this.loginRepository,
    required this.committer,
  });

  final ProviderContainer container;
  final AccountLinkController controller;
  final _FakeLoginRepository loginRepository;
  final _FakeCommitter committer;

  AccountLinkState get state =>
      container.read(accountLinkControllerProvider).requireValue;

  void dispose() => container.dispose();
}

final class _FakeLoginRepository implements AccountPasswordLoginRepository {
  _FakeLoginRepository({required this.account, this.gate});

  final LinkedTradingAccount account;
  final Completer<void>? gate;
  final List<AccountPasswordLoginRequest> requests = [];
  final List<ExV2CommandMetadata> metadata = [];

  @override
  Future<AccountPasswordLoginResult> login(
    AccountPasswordLoginRequest request, {
    required String installationId,
    required ExV2CommandMetadata metadata,
  }) async {
    requests.add(request);
    this.metadata.add(metadata);
    expect(installationId, '11111111-1111-4111-8111-111111111111');
    if (gate != null) await gate!.future;
    return AccountPasswordLoginResult(
      deviceToken: 'token-${account.id}',
      account: account,
      bootstrap: ExV2Bootstrap.fromJson(
        account.id == 'account-1'
            ? _bootstrapJson
            : _bootstrapForAccount(account.id, account.login, version: 2),
      ),
    );
  }
}

final class _FakeCommitter implements AccountSessionCommitter {
  final List<AccountPasswordLoginResult> results = [];

  @override
  Future<ExV2BootstrapPublication> commit(
    AccountPasswordLoginResult result,
  ) async {
    results.add(result);
    return ExV2BootstrapPublication.idempotentReplay;
  }
}

final class _InstallationStore implements InstallationIdStore {
  @override
  Future<String> readOrCreate() async => '11111111-1111-4111-8111-111111111111';
}

final class _FakeRepository implements AccountLinkRepository {
  _FakeRepository({
    this.linkedAccount = _account,
    this.linkGate,
    this.activationGate,
    this.linkError,
    this.failFirstActivation = false,
  });

  final LinkedTradingAccount linkedAccount;
  final Completer<void>? linkGate;
  final Completer<void>? activationGate;
  final Object? linkError;
  final bool failFirstActivation;
  int linkCalls = 0;
  int activateCalls = 0;
  final List<LinkAccountRequest> linkRequests = [];
  final List<ExV2CommandMetadata> linkMetadata = [];
  final List<String> activatedAccountIds = [];

  @override
  Future<List<LinkedTradingAccount>> accounts() async => const [];

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) async {
    activateCalls += 1;
    activatedAccountIds.add(accountId);
    if (activationGate != null) await activationGate!.future;
    if (failFirstActivation && activateCalls == 1) {
      throw const ExV2RequestFailure(
        statusCode: 500,
        code: 'activation_failed',
        message: 'Activation failed',
      );
    }
    return ActivateLinkedAccountResult(
      account: LinkedTradingAccount(
        id: linkedAccount.id,
        brokerId: linkedAccount.brokerId,
        brokerName: linkedAccount.brokerName,
        serverId: linkedAccount.serverId,
        serverName: linkedAccount.serverName,
        login: linkedAccount.login,
        isActive: true,
        displayName: linkedAccount.displayName,
        currency: linkedAccount.currency,
        status: linkedAccount.status,
      ),
      bootstrap: ExV2Bootstrap.fromJson(
        _bootstrapForAccount(linkedAccount.id, linkedAccount.login, version: 2),
      ),
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
    linkRequests.add(request);
    linkMetadata.add(metadata);
    if (linkGate != null) await linkGate!.future;
    if (linkError case final error?) throw error;
    return LinkAccountResult(
      account: linkedAccount,
      reconnectGrant: 'opaque-grant-${linkedAccount.id}',
      alreadyLinked: false,
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

final class _MemoryPresentationStore implements LinkedAccountPresentationStore {
  final Map<String, LinkedAccountPresentation> values = {};

  @override
  Future<LinkedAccountPresentation?> read(String accountId) async =>
      values[accountId];

  @override
  Future<void> write(String accountId, LinkedAccountPresentation value) async {
    values[accountId] = value;
  }
}

final class _MemoryRemovedAccountStore implements RemovedAccountStore {
  _MemoryRemovedAccountStore(Set<String> initial) : values = {...initial};

  final Set<String> values;

  @override
  Future<void> add(String accountId) async => values.add(accountId);

  @override
  Future<Set<String>> read() async => {...values};

  @override
  Future<void> remove(String accountId) async => values.remove(accountId);
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

Map<String, Object?> _bootstrapForAccount(
  String id,
  String code, {
  required int version,
}) => {
  ..._bootstrapJson,
  'version': version,
  'activeAccount': {
    ..._bootstrapJson['activeAccount']! as Map<String, Object?>,
    'id': id,
    'accountCode': code,
  },
  'summary': {
    ..._bootstrapJson['summary']! as Map<String, Object?>,
    'accountId': id,
  },
};
