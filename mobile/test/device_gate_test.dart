import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/account_sync/presentation/device_gate.dart';

void main() {
  testWidgets('missing token shows one-time activation instead of mock data', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
        ],
        child: const MaterialApp(home: DeviceGate(child: Text('SERVER APP'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kích hoạt thiết bị'), findsOneWidget);
    expect(find.text('SERVER APP'), findsNothing);
  });

  testWidgets('stored token opens the unchanged application', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
          exV2AccountProvider.overrideWithBuild(
            (ref, controller) async => _serverState,
          ),
        ],
        child: const MaterialApp(home: DeviceGate(child: Text('SERVER APP'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SERVER APP'), findsOneWidget);
  });

  testWidgets('server bootstrap loading never exposes the application', (
    tester,
  ) async {
    final bootstrapGate = Completer<ExV2AccountViewState?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
          exV2AccountProvider.overrideWithBuild(
            (ref, controller) => bootstrapGate.future,
          ),
        ],
        child: const MaterialApp(home: DeviceGate(child: Text('SERVER APP'))),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('account-bootstrap-loading')), findsOneWidget);
    expect(find.text('SERVER APP'), findsNothing);
  });

  testWidgets('server bootstrap error never exposes the application', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
          exV2AccountProvider.overrideWithBuild(
            (ref, controller) async => throw StateError('offline'),
          ),
        ],
        child: const MaterialApp(home: DeviceGate(child: Text('SERVER APP'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-bootstrap-error')), findsOneWidget);
    expect(find.text('SERVER APP'), findsNothing);
  });
}

final _serverState = ExV2AccountViewState.fromBootstrap(
  ExV2Bootstrap.fromJson(_bootstrap),
);

final _bootstrap = <String, Object?>{
  'serverTime': '2026-08-13T08:00:00Z',
  'version': 1,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-1',
    'accountCode': '109740422',
    'name': 'Mỗi Ngày Một Tỷ 🍀',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 154763.90,
    'equity': 154763.90,
    'profit': 0,
    'margin': 0,
    'freeMargin': 154763.90,
    'marginLevel': 0,
    'updatedAt': '2026-08-13T08:00:00Z',
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

final class _MemoryTokenStore implements DeviceTokenStore {
  _MemoryTokenStore([this.value]);
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}
