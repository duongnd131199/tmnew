import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_login/domain/account_password_login_models.dart';
import 'package:trading_mobile/features/account_sessions/application/account_session_committer.dart';
import 'package:trading_mobile/features/account_sessions/application/account_switch_guard.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('commit stores only the global device token', () async {
    const storage = FlutterSecureStorage();
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);

    final publication = await fixture.committer.commit(
      _loginResult('account-b', 'token-b'),
    );

    expect(publication, ExV2BootstrapPublication.committed);
    expect(fixture.tokenStore.value, 'token-b');
    expect(await storage.read(key: 'ex_v2_account_sessions_v1'), isNull);
  });

  test('commit publishes the authenticated account', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);

    final publication = await fixture.committer.commit(
      _loginResult('account-b', 'token-b'),
    );

    expect(publication, ExV2BootstrapPublication.committed);
    expect(fixture.tokenStore.value, 'token-b');
    expect(
      fixture.container
          .read(exV2AccountProvider)
          .requireValue
          ?.bootstrap
          .account
          .id,
      'account-b',
    );
  });

  test('rejected publication restores the previous active token', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    fixture.container
        .read(exV2AccountProvider.notifier)
        .publishBootstrap(
          _bootstrap('account-a', version: 1),
          operationAuthority: 10,
        );

    final publication = await fixture.committer.commit(
      _loginResult('account-b', 'token-b'),
    );

    expect(publication, ExV2BootstrapPublication.rejectedStale);
    expect(fixture.tokenStore.value, 'token-a');
    expect(
      fixture.container
          .read(exV2AccountProvider)
          .requireValue
          ?.bootstrap
          .account
          .id,
      'account-a',
    );
  });

  test(
    'failed token write leaves the previous account and token intact',
    () async {
      final fixture = await _Fixture.create(tokenWriteFails: true);
      addTearDown(fixture.dispose);

      await expectLater(
        fixture.committer.commit(_loginResult('account-b', 'token-b')),
        throwsA(isA<StateError>()),
      );

      expect(fixture.tokenStore.value, 'token-a');
      expect(
        fixture.container
            .read(exV2AccountProvider)
            .requireValue
            ?.bootstrap
            .account
            .id,
        'account-a',
      );
    },
  );

  test('guard refuses a second account switch until lease release', () {
    final guard = AccountSwitchGuard();
    final first = guard.tryAcquire();

    expect(first, isNotNull);
    expect(guard.tryAcquire(), isNull);

    guard.release(first!);
    final second = guard.tryAcquire();
    expect(second, isNotNull);
    expect(second!.authority, greaterThan(first.authority));
  });
}

final class _Fixture {
  _Fixture({
    required this.container,
    required this.tokenStore,
    required this.committer,
  });

  static Future<_Fixture> create({bool tokenWriteFails = false}) async {
    final tokenStore = _MemoryTokenStore(
      'token-a',
      writeFails: tokenWriteFails,
    );
    final container = ProviderContainer(
      overrides: [
        deviceTokenStoreProvider.overrideWithValue(tokenStore),
        exV2AccountProvider.overrideWithBuild(
          (ref, controller) async => ExV2AccountViewState.fromBootstrap(
            _bootstrap('account-a', version: 1),
          ),
        ),
      ],
    );
    await container.read(exV2AccountProvider.future);
    final committer = SecureAccountSessionCommitter(
      guard: AccountSwitchGuard(),
      tokenStore: tokenStore,
      publisher: container.read(exV2AccountProvider.notifier),
    );
    return _Fixture(
      container: container,
      tokenStore: tokenStore,
      committer: committer,
    );
  }

  final ProviderContainer container;
  final _MemoryTokenStore tokenStore;
  final SecureAccountSessionCommitter committer;

  void dispose() => container.dispose();
}

final class _MemoryTokenStore implements DeviceTokenStore {
  _MemoryTokenStore(this.value, {this.writeFails = false});

  String? value;
  final bool writeFails;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async {
    if (writeFails && token == 'token-b') {
      throw StateError('token write failed');
    }
    value = token;
  }
}

AccountPasswordLoginResult _loginResult(String accountId, String token) =>
    AccountPasswordLoginResult(
      deviceToken: token,
      account: LinkedTradingAccount(
        id: accountId,
        brokerId: 'metaquotes-demo',
        brokerName: 'MetaQuotes Ltd.',
        serverId: 'metaquotes-demo',
        serverName: 'MetaQuotes-Demo',
        login: accountId == 'account-a' ? '10001' : '10002',
        isActive: true,
        displayName: 'Account $accountId',
        currency: 'USD',
        status: 'active',
      ),
      bootstrap: _bootstrap(accountId, version: 1),
    );

ExV2Bootstrap _bootstrap(String accountId, {required int version}) =>
    ExV2Bootstrap.fromJson(<String, Object?>{
      'serverTime': '2026-08-24T00:00:00Z',
      'version': version,
      'device': <String, Object?>{'id': 'device-1', 'name': 'Phone'},
      'activeAccount': <String, Object?>{
        'id': accountId,
        'accountCode': accountId == 'account-a' ? '10001' : '10002',
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
        'updatedAt': '2026-08-24T00:00:00Z',
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
      },
      'integrityWarnings': 0,
    });
