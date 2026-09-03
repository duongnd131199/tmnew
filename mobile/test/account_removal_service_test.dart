import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sessions/application/account_removal_service.dart';
import 'package:trading_mobile/features/account_sessions/data/removed_account_store.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';

void main() {
  test(
    'remove activates the first remaining account before hiding the active ID',
    () async {
      final fixture = _Fixture(accounts: _accounts);

      final result = await fixture.service.removeActiveAccount();

      expect(result, AccountRemovalResult.switched);
      expect(fixture.activatedIds, ['account-b']);
      expect(await fixture.removedStore.read(), {'account-a'});
      expect(fixture.tokenStore.value, 'device-token');
      expect(fixture.catalogRefreshes, 1);
      expect(fixture.sessionResets, 0);
    },
  );

  test('activation failure restores the pending removed marker', () async {
    final fixture = _Fixture(
      accounts: _accounts,
      activationError: StateError('activation failed'),
    );

    await expectLater(
      fixture.service.removeActiveAccount(),
      throwsA(isA<StateError>()),
    );

    expect(fixture.activatedIds, ['account-b']);
    expect(await fixture.removedStore.read(), isEmpty);
    expect(fixture.tokenStore.value, 'device-token');
    expect(fixture.catalogRefreshes, 0);
  });

  test('rejected replacement activation restores the removed marker', () async {
    final fixture = _Fixture(accounts: _accounts, activationAccepted: false);

    await expectLater(
      fixture.service.removeActiveAccount(),
      throwsA(isA<AccountReplacementActivationRejected>()),
    );

    expect(await fixture.removedStore.read(), isEmpty);
    expect(fixture.catalogRefreshes, 0);
  });

  test('remove last account deletes token and resets device session', () async {
    final fixture = _Fixture(accounts: [_accounts.first]);

    final result = await fixture.service.removeActiveAccount();

    expect(result, AccountRemovalResult.signedOut);
    expect(fixture.activatedIds, isEmpty);
    expect(await fixture.removedStore.read(), {'account-a'});
    expect(fixture.tokenStore.value, isNull);
    expect(fixture.catalogRefreshes, 1);
    expect(fixture.sessionResets, 1);
  });

  test('token deletion failure restores the removed marker', () async {
    final fixture = _Fixture(accounts: [_accounts.first], deleteFails: true);

    await expectLater(
      fixture.service.removeActiveAccount(),
      throwsA(isA<StateError>()),
    );

    expect(await fixture.removedStore.read(), isEmpty);
    expect(fixture.tokenStore.value, 'device-token');
    expect(fixture.sessionResets, 0);
  });

  test('a concurrent remove is rejected without a second activation', () async {
    final gate = Completer<void>();
    final fixture = _Fixture(accounts: _accounts, activationGate: gate);

    final first = fixture.service.removeActiveAccount();
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      fixture.service.removeActiveAccount(),
      throwsA(isA<AccountRemovalInProgress>()),
    );
    expect(fixture.activatedIds, ['account-b']);

    gate.complete();
    expect(await first, AccountRemovalResult.switched);
  });

  test('missing active bootstrap cannot remove an arbitrary account', () async {
    final fixture = _Fixture(accounts: _accounts, activeAccountId: null);

    await expectLater(
      fixture.service.removeActiveAccount(),
      throwsA(isA<AccountRemovalUnavailable>()),
    );

    expect(fixture.activatedIds, isEmpty);
    expect(await fixture.removedStore.read(), isEmpty);
  });
}

final class _Fixture {
  _Fixture({
    required this.accounts,
    this.activeAccountId = 'account-a',
    this.activationAccepted = true,
    this.activationError,
    this.activationGate,
    bool deleteFails = false,
  }) : tokenStore = _MemoryTokenStore('device-token', deleteFails: deleteFails),
       removedStore = _MemoryRemovedAccountStore() {
    service = LocalAccountRemovalService(
      activeAccountId: () => activeAccountId,
      accounts: () async => accounts,
      activate: (accountId) async {
        activatedIds.add(accountId);
        if (activationGate != null) await activationGate!.future;
        if (activationError != null) throw activationError!;
        return activationAccepted;
      },
      removedAccountStore: removedStore,
      tokenStore: tokenStore,
      onCatalogChanged: () => catalogRefreshes += 1,
      onSignedOut: () => sessionResets += 1,
    );
  }

  final List<LinkedTradingAccount> accounts;
  final String? activeAccountId;
  final bool activationAccepted;
  final Object? activationError;
  final Completer<void>? activationGate;
  final List<String> activatedIds = [];
  final _MemoryTokenStore tokenStore;
  final _MemoryRemovedAccountStore removedStore;
  late final LocalAccountRemovalService service;
  int catalogRefreshes = 0;
  int sessionResets = 0;
}

final class _MemoryRemovedAccountStore implements RemovedAccountStore {
  final Set<String> _values = {};

  @override
  Future<void> add(String accountId) async => _values.add(accountId);

  @override
  Future<Set<String>> read() async => {..._values};

  @override
  Future<void> remove(String accountId) async => _values.remove(accountId);
}

final class _MemoryTokenStore implements DeviceTokenStore {
  _MemoryTokenStore(this.value, {required this.deleteFails});

  String? value;
  final bool deleteFails;

  @override
  Future<void> delete() async {
    if (deleteFails) throw StateError('token delete failed');
    value = null;
  }

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}

final _accounts = [
  _account('account-a', '100001', isActive: true),
  _account('account-b', '100002'),
  _account('account-c', '100003'),
];

LinkedTradingAccount _account(
  String id,
  String login, {
  bool isActive = false,
}) => LinkedTradingAccount(
  id: id,
  brokerId: 'broker-$id',
  brokerName: 'Broker $id',
  serverId: 'server-$id',
  serverName: 'Server $id',
  login: login,
  isActive: isActive,
  currency: 'USD',
  status: 'active',
);
