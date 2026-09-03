import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/account_sync/presentation/device_gate.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('token read timeout exits loading without exposing the app', (
    tester,
  ) async {
    final store = _SequencedTokenStore([() => Completer<String?>().future]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          deviceTokenStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: DeviceGate(
            startupTimeout: Duration(milliseconds: 100),
            child: Text('SERVER APP'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 101));

    expect(find.byKey(const Key('device-token-read-error')), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('SERVER APP'), findsNothing);
  });

  testWidgets('token read retry starts a fresh read and reaches token entry', (
    tester,
  ) async {
    final store = _SequencedTokenStore([
      () => Completer<String?>().future,
      () async => null,
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          deviceTokenStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: DeviceGate(
            startupTimeout: Duration(milliseconds: 100),
            child: Text('SERVER APP'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 101));

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(store.readCalls, 2);
    expect(
      find.byKey(const Key('dev-device-token-import-screen')),
      findsOneWidget,
    );
    expect(find.text('SERVER APP'), findsNothing);
  });

  testWidgets(
    'missing token shows token activation without EX2 password login',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exV2EnabledProvider.overrideWithValue(true),
            deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
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

      expect(
        find.byKey(const Key('dev-device-token-import-screen')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dev-device-token-field')), findsOneWidget);
      expect(
        find.byKey(const Key('account-password-login-screen')),
        findsNothing,
      );
      expect(find.byKey(const Key('account-login-field')), findsNothing);
      expect(find.byKey(const Key('account-password-field')), findsNothing);
      expect(find.text('SERVER APP'), findsNothing);
    },
  );

  testWidgets(
    'release missing token opens the real account login flow instead of token import',
    (tester) async {
      var addAccountCalls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exV2EnabledProvider.overrideWithValue(true),
            deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          ],
          child: MaterialApp(
            home: DeviceGate(
              enableDevelopmentTokenImport: false,
              onAddAccount: () => addAccountCalls += 1,
              child: const Text('SERVER APP'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account-login-required')), findsOneWidget);
      expect(
        find.byKey(const Key('dev-device-token-import-screen')),
        findsNothing,
      );
      expect(find.text('Đăng nhập'), findsOneWidget);

      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(addAccountCalls, 1);
      expect(find.text('SERVER APP'), findsOneWidget);
    },
  );

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

  testWidgets('bootstrap timeout exits loading and keeps the device token', (
    tester,
  ) async {
    final bootstrapGate = Completer<ExV2AccountViewState?>();
    final store = _MemoryTokenStore('test-token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          deviceTokenStoreProvider.overrideWithValue(store),
          exV2AccountProvider.overrideWithBuild(
            (ref, controller) => bootstrapGate.future,
          ),
        ],
        child: const MaterialApp(
          home: DeviceGate(
            startupTimeout: Duration(milliseconds: 100),
            child: Text('SERVER APP'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 101));

    expect(find.byKey(const Key('account-bootstrap-timeout')), findsOneWidget);
    expect(await store.read(), 'test-token');
    expect(find.text('SERVER APP'), findsNothing);
  });

  testWidgets('bootstrap timeout retry starts a fresh provider build', (
    tester,
  ) async {
    final bootstrapGate = Completer<ExV2AccountViewState?>();
    var builds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
          exV2AccountProvider.overrideWithBuild((ref, controller) {
            builds += 1;
            return builds == 1
                ? bootstrapGate.future
                : Future.value(_serverState);
          }),
        ],
        child: const MaterialApp(
          home: DeviceGate(
            startupTimeout: Duration(milliseconds: 100),
            child: Text('SERVER APP'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 101));

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(builds, 2);
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
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const Key('account-bootstrap-loading')),
          )
          .color,
      AppColors.background,
    );
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

  testWidgets('bootstrap HTTP error shows safe production diagnostics', (
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
            (ref, controller) async => throw const ExV2RequestFailure(
              statusCode: 502,
              code: 'BOOTSTRAP_UNAVAILABLE',
              correlationId: '11111111-1111-4111-8111-111111111111',
              message: 'upstream detail must stay hidden',
            ),
          ),
        ],
        child: const MaterialApp(home: DeviceGate(child: Text('SERVER APP'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Không thể tải tài khoản.'), findsOneWidget);
    expect(find.textContaining('HTTP 502'), findsOneWidget);
    expect(
      find.textContaining('Mã lỗi: BOOTSTRAP_UNAVAILABLE'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Mã tra cứu: 11111111-1111-4111-8111-111111111111'),
      findsOneWidget,
    );
    expect(find.textContaining('upstream detail'), findsNothing);
    expect(find.text('SERVER APP'), findsNothing);
  });

  testWidgets('rejected device token returns to token activation explicitly', (
    tester,
  ) async {
    final store = _MemoryTokenStore('expired-token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          deviceTokenStoreProvider.overrideWithValue(store),
          exV2AccountProvider.overrideWithBuild(
            (ref, controller) async => throw const ExV2RequestFailure(
              statusCode: 401,
              code: 'INVALID_DEVICE_TOKEN',
              message: 'Invalid device token',
            ),
          ),
        ],
        child: const MaterialApp(home: DeviceGate(child: Text('SERVER APP'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('device-authentication-error')),
      findsOneWidget,
    );
    await tester.tap(find.text('Đăng nhập lại'));
    await tester.pumpAndSettle();

    expect(await store.read(), isNull);
    expect(
      find.byKey(const Key('dev-device-token-import-screen')),
      findsOneWidget,
    );
    expect(find.text('SERVER APP'), findsNothing);
  });

  testWidgets(
    'release rejected token deletes it and continues to real account login',
    (tester) async {
      final store = _MemoryTokenStore('expired-token');
      var addAccountCalls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exV2EnabledProvider.overrideWithValue(true),
            deviceTokenStoreProvider.overrideWithValue(store),
            exV2AccountProvider.overrideWithBuild(
              (ref, controller) async => throw const ExV2RequestFailure(
                statusCode: 401,
                code: 'INVALID_DEVICE_TOKEN',
                message: 'Invalid device token',
              ),
            ),
          ],
          child: MaterialApp(
            home: DeviceGate(
              enableDevelopmentTokenImport: false,
              onAddAccount: () => addAccountCalls += 1,
              child: const Text('SERVER APP'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('device-authentication-error')),
        findsOneWidget,
      );
      await tester.tap(find.text('Đăng nhập lại'));
      await tester.pumpAndSettle();

      expect(await store.read(), isNull);
      expect(find.byKey(const Key('account-login-required')), findsOneWidget);
      expect(
        find.byKey(const Key('dev-device-token-import-screen')),
        findsNothing,
      );

      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(addAccountCalls, 1);
      expect(find.text('SERVER APP'), findsOneWidget);
    },
  );

  testWidgets('bootstrap error retry remains protected by the watchdog', (
    tester,
  ) async {
    final retryGate = Completer<ExV2AccountViewState?>();
    var builds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
          exV2AccountProvider.overrideWithBuild((ref, controller) {
            builds += 1;
            return builds == 1
                ? Future<ExV2AccountViewState?>.error(StateError('offline'))
                : retryGate.future;
          }),
        ],
        child: const MaterialApp(
          home: DeviceGate(
            startupTimeout: Duration(milliseconds: 100),
            child: Text('SERVER APP'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 101));

    expect(builds, 2);
    expect(find.byKey(const Key('account-bootstrap-timeout')), findsOneWidget);
    expect(find.text('SERVER APP'), findsNothing);
  });

  testWidgets(
    'account-not-configured keeps token and opens real add-account flow',
    (tester) async {
      final store = _MemoryTokenStore('test-token');
      var addAccountCalls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exV2EnabledProvider.overrideWithValue(true),
            deviceTokenStoreProvider.overrideWithValue(store),
            exV2AccountProvider.overrideWithBuild(
              (ref, controller) async => throw const ExV2RequestFailure(
                statusCode: 409,
                code: 'ACTIVE_ACCOUNT_NOT_CONFIGURED',
                message: 'No active account',
              ),
            ),
          ],
          child: MaterialApp(
            home: DeviceGate(
              onAddAccount: () => addAccountCalls += 1,
              child: const Text('SERVER APP'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('account-bootstrap-accountless')),
        findsOneWidget,
      );
      expect(find.text('Thêm tài khoản'), findsOneWidget);
      expect(find.byKey(const Key('account-bootstrap-error')), findsNothing);
      expect(await store.read(), 'test-token');

      await tester.tap(find.text('Thêm tài khoản'));
      await tester.pumpAndSettle();

      expect(addAccountCalls, 1);
      expect(find.text('SERVER APP'), findsOneWidget);
    },
  );

  testWidgets('an unrelated bootstrap conflict remains fail closed', (
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
            (ref, controller) async => throw const ExV2RequestFailure(
              statusCode: 409,
              code: 'BOOTSTRAP_VERSION_CONFLICT',
              message: 'Version conflict',
            ),
          ),
        ],
        child: const MaterialApp(home: DeviceGate(child: Text('SERVER APP'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-bootstrap-error')), findsOneWidget);
    expect(
      find.byKey(const Key('account-bootstrap-accountless')),
      findsNothing,
    );
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

final class _SequencedTokenStore implements DeviceTokenStore {
  _SequencedTokenStore(this._reads);

  final List<Future<String?> Function()> _reads;
  int readCalls = 0;

  @override
  Future<void> delete() async {}

  @override
  Future<String?> read() {
    final index = readCalls++;
    return _reads[index]();
  }

  @override
  Future<void> write(String token) async {}
}
