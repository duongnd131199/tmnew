import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/dev_device_token_import.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/account_sync/presentation/device_gate.dart';

void main() {
  testWidgets('missing token shows the token activation screen', (
    tester,
  ) async {
    await _pumpGate(tester, store: _MemoryTokenStore());

    expect(
      find.byKey(const Key('dev-device-token-import-screen')),
      findsOneWidget,
    );
    expect(find.text('Kích hoạt thiết bị'), findsOneWidget);
    final brandingImage = tester.widget<Image>(
      find.byKey(const Key('dev-device-token-branding')),
    );
    expect(
      (brandingImage.image as AssetImage).assetName,
      'assets/images/metatrader5_splash.png',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('dev-device-token-field')))
          .obscureText,
      isTrue,
    );
    expect(
      find.byKey(const Key('account-password-login-screen')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('dev-device-token-visibility')));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('dev-device-token-field')))
          .obscureText,
      isFalse,
    );
  });

  testWidgets('valid token is validated, stored, and opens the app', (
    tester,
  ) async {
    final store = _MemoryTokenStore();
    final validatedTokens = <String>[];
    await _pumpGate(
      tester,
      store: store,
      validator: (token) async => validatedTokens.add(token),
      account: _serverState,
    );

    await tester.enterText(
      find.byKey(const Key('dev-device-token-field')),
      '  widget-test-device-token  ',
    );
    await tester.tap(find.byKey(const Key('dev-device-token-submit')));
    await tester.pumpAndSettle();

    expect(validatedTokens, <String>['widget-test-device-token']);
    expect(store.value, 'widget-test-device-token');
    expect(find.text('SERVER APP'), findsOneWidget);
    expect(
      find.byKey(const Key('dev-device-token-import-screen')),
      findsNothing,
    );
  });

  testWidgets('invalid token is deleted, cleared, and cannot open the app', (
    tester,
  ) async {
    final store = _MemoryTokenStore();
    await _pumpGate(
      tester,
      store: store,
      validator: (_) async => throw StateError('backend rejected request'),
      account: _serverState,
    );

    await tester.enterText(
      find.byKey(const Key('dev-device-token-field')),
      'rejected-widget-token',
    );
    await tester.tap(find.byKey(const Key('dev-device-token-submit')));
    await tester.pumpAndSettle();

    expect(store.value, isNull);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('dev-device-token-field')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.byKey(const Key('dev-device-token-error')), findsOneWidget);
    expect(find.textContaining('backend rejected request'), findsNothing);
    expect(find.text('rejected-widget-token'), findsNothing);
    expect(find.text('SERVER APP'), findsNothing);
  });

  testWidgets('existing token bypasses token activation', (tester) async {
    await _pumpGate(
      tester,
      store: _MemoryTokenStore('stored-widget-token'),
      account: _serverState,
    );

    expect(find.text('SERVER APP'), findsOneWidget);
    expect(
      find.byKey(const Key('dev-device-token-import-screen')),
      findsNothing,
    );
  });
}

Future<void> _pumpGate(
  WidgetTester tester, {
  required _MemoryTokenStore store,
  DeviceTokenBootstrapValidator? validator,
  ExV2AccountViewState? account,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        deviceTokenStoreProvider.overrideWithValue(store),
        if (validator != null)
          deviceTokenBootstrapValidatorProvider.overrideWithValue(validator),
        exV2AccountProvider.overrideWithBuild(
          (ref, controller) async => account,
        ),
      ],
      child: const MaterialApp(
        home: DeviceGate(
          enableDevelopmentTokenImport: true,
          child: Text('SERVER APP'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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

final _serverState = ExV2AccountViewState.fromBootstrap(
  ExV2Bootstrap.fromJson(<String, Object?>{
    'serverTime': '2026-08-25T08:00:00Z',
    'version': 1,
    'device': <String, Object?>{'id': 'device-1', 'name': 'iPhone Simulator'},
    'activeAccount': <String, Object?>{
      'id': 'account-1',
      'accountCode': '100000001',
      'name': 'Widget Test Account',
      'currency': 'USD',
      'status': 'active',
    },
    'summary': <String, Object?>{
      'accountId': 'account-1',
      'currency': 'USD',
      'balance': 1000,
      'equity': 1000,
      'profit': 0,
      'margin': 0,
      'freeMargin': 1000,
      'marginLevel': 0,
      'updatedAt': '2026-08-25T08:00:00Z',
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
  }),
);
