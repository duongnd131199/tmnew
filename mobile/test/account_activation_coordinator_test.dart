import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/application/account_activation_coordinator.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

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
}

final class _OutOfOrderActivationRepository implements AccountLinkRepository {
  final Map<String, Completer<ActivateLinkedAccountResult>> _requests = {};

  void complete(String accountId, {required int version}) {
    _requests[accountId]!.complete(
      ActivateLinkedAccountResult(
        account: _account(accountId),
        bootstrap: _bootstrap(accountId, version: version),
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
