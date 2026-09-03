import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/data/account_link_dependencies.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sessions/application/account_removal_service.dart';
import 'package:trading_mobile/features/account_sessions/data/removed_account_store.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  test('catalog hides removed inactive accounts in server order', () async {
    final removedStore = _MemoryRemovedAccountStore({'account-b'});
    final fixture = await _Fixture.create(removedStore: removedStore);
    addTearDown(fixture.dispose);

    final visible = await fixture.container.read(
      linkedTradingAccountsProvider.future,
    );

    expect(visible.map((account) => account.id), ['account-a', 'account-c']);
  });

  test(
    'catalog retains active recovery row while hiding other removed IDs',
    () async {
      final removedStore = _MemoryRemovedAccountStore({
        'account-a',
        'account-b',
      });
      final fixture = await _Fixture.create(removedStore: removedStore);
      addTearDown(fixture.dispose);

      final visible = await fixture.container.read(
        linkedTradingAccountsProvider.future,
      );

      expect(visible.map((account) => account.id), ['account-a', 'account-c']);
    },
  );

  test(
    'production removal wiring activates first remaining account and hides old row',
    () async {
      final removedStore = _MemoryRemovedAccountStore({});
      final fixture = await _Fixture.create(removedStore: removedStore);
      addTearDown(fixture.dispose);

      expect(
        (await fixture.container.read(
          linkedTradingAccountsProvider.future,
        )).map((account) => account.id),
        ['account-a', 'account-b', 'account-c'],
      );

      final result = await fixture.container
          .read(accountRemovalServiceProvider)
          .removeActiveAccount();

      expect(result, AccountRemovalResult.switched);
      expect(
        fixture.container
            .read(exV2AccountProvider)
            .requireValue!
            .bootstrap
            .account
            .id,
        'account-b',
      );
      expect(await removedStore.read(), {'account-a'});
      expect(
        (await fixture.container.read(
          linkedTradingAccountsProvider.future,
        )).map((account) => account.id),
        ['account-b', 'account-c'],
      );
    },
  );
}

final class _Fixture {
  const _Fixture(this.container);

  static Future<_Fixture> create({
    required RemovedAccountStore removedStore,
  }) async {
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        removedAccountStoreProvider.overrideWithValue(removedStore),
        deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
        accountLinkRepositoryProvider.overrideWithValue(_AccountRepository()),
        exV2AccountProvider.overrideWithBuild(
          (ref, controller) async => ExV2AccountViewState.fromBootstrap(
            _bootstrap('account-a', version: 1),
          ),
        ),
      ],
    );
    await container.read(exV2AccountProvider.future);
    return _Fixture(container);
  }

  final ProviderContainer container;

  void dispose() => container.dispose();
}

final class _MemoryTokenStore implements DeviceTokenStore {
  String? value = 'device-token';

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
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

final class _AccountRepository implements AccountLinkRepository {
  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) async => ActivateLinkedAccountResult(
    account: _account(accountId, isActive: true),
    bootstrap: _bootstrap(accountId, version: 2),
  );

  @override
  Future<List<LinkedTradingAccount>> accounts() async => [
    _account('account-a', isActive: true),
    _account('account-b'),
    _account('account-c'),
  ];

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

LinkedTradingAccount _account(String id, {bool isActive = false}) =>
    LinkedTradingAccount(
      id: id,
      brokerId: 'broker-$id',
      brokerName: 'Broker $id',
      serverId: 'server-$id',
      serverName: 'Server $id',
      login: id == 'account-a'
          ? '100001'
          : id == 'account-b'
          ? '100002'
          : '100003',
      isActive: isActive,
      displayName: 'Account $id',
      currency: 'USD',
      status: 'active',
    );

ExV2Bootstrap _bootstrap(String accountId, {required int version}) =>
    ExV2Bootstrap.fromJson(<String, Object?>{
      'serverTime': '2026-09-04T00:00:00Z',
      'version': version,
      'device': <String, Object?>{'id': 'device-1', 'name': 'Phone'},
      'activeAccount': <String, Object?>{
        'id': accountId,
        'accountCode': accountId == 'account-a' ? '100001' : '100002',
        'name': 'Account $accountId',
        'currency': 'USD',
        'status': 'active',
      },
      'summary': <String, Object?>{
        'accountId': accountId,
        'currency': 'USD',
        'balance': 100,
        'equity': 100,
        'profit': 0,
        'margin': 0,
        'freeMargin': 100,
        'marginLevel': 0,
        'updatedAt': '2026-09-04T00:00:00Z',
      },
      'positions': <Object?>[],
      'pendingOrders': <Object?>[],
      'recentDeals': <Object?>[],
      'wallet': <String, Object?>{
        'currency': 'USD',
        'availableBalance': 100,
        'lockedBalance': 0,
        'totalBalance': 100,
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
        'tradingEnabled': true,
      },
      'integrityWarnings': 0,
    });
