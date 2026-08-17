import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_login/data/account_password_login_dependencies.dart';
import 'package:trading_mobile/features/account_login/data/account_password_login_repository.dart';
import 'package:trading_mobile/features/account_login/data/installation_id_store.dart';
import 'package:trading_mobile/features/account_login/domain/account_password_login_models.dart';
import 'package:trading_mobile/features/account_login/presentation/account_password_login_screen.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

void main() {
  testWidgets(
    'controllers preserve raw password and success invokes callback',
    (tester) async {
      final repository = _ScreenLoginRepository();
      var authenticated = false;
      await _pumpScreen(
        tester,
        repository: repository,
        onAuthenticated: () => authenticated = true,
      );

      await tester.enterText(
        find.byKey(const Key('account-login-field')),
        '109740422',
      );
      await tester.enterText(
        find.byKey(const Key('account-password-field')),
        ' Test-Pass_123! ',
      );
      await tester.tap(find.byKey(const Key('account-login-submit')));
      await tester.pumpAndSettle();

      expect(repository.requests.single.login, '109740422');
      expect(repository.requests.single.password, ' Test-Pass_123! ');
      expect(authenticated, isTrue);
      final passwordField = tester.widget<TextField>(
        find.byKey(const Key('account-password-field')),
      );
      expect(passwordField.controller!.text, isEmpty);
    },
  );

  testWidgets('invalid credentials clear password and preserve login', (
    tester,
  ) async {
    final repository = _ScreenLoginRepository(
      error: const ExV2RequestFailure(
        statusCode: 422,
        code: 'invalid_credentials',
        correlationId: 'corr-safe-widget',
        message: 'Unable to sign in.',
      ),
    );
    await _pumpScreen(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('account-login-field')),
      '109740422',
    );
    await tester.enterText(
      find.byKey(const Key('account-password-field')),
      'synthetic-wrong',
    );
    await tester.tap(find.byKey(const Key('account-login-submit')));
    await tester.pumpAndSettle();

    final loginField = tester.widget<TextField>(
      find.byKey(const Key('account-login-field')),
    );
    final passwordField = tester.widget<TextField>(
      find.byKey(const Key('account-password-field')),
    );
    expect(loginField.controller!.text, '109740422');
    expect(passwordField.controller!.text, isEmpty);
    expect(find.textContaining('invalid_credentials'), findsOneWidget);
    expect(find.textContaining('corr-safe-widget'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _ScreenLoginRepository repository,
  VoidCallback? onAuthenticated,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountPasswordLoginRepositoryProvider.overrideWithValue(repository),
        installationIdStoreProvider.overrideWithValue(_InstallationStore()),
        deviceTokenStoreProvider.overrideWithValue(_TokenStore()),
      ],
      child: MaterialApp(
        home: AccountPasswordLoginScreen(
          onAuthenticated: onAuthenticated ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _ScreenLoginRepository implements AccountPasswordLoginRepository {
  _ScreenLoginRepository({this.error});

  final Object? error;
  final List<AccountPasswordLoginRequest> requests =
      <AccountPasswordLoginRequest>[];

  @override
  Future<AccountPasswordLoginResult> login(
    AccountPasswordLoginRequest request, {
    required String installationId,
    required ExV2CommandMetadata metadata,
  }) async {
    requests.add(request);
    if (error case final failure?) throw failure;
    return AccountPasswordLoginResult(
      deviceToken: 'opaque-test-token',
      account: _account,
      bootstrap: ExV2Bootstrap.fromJson(_bootstrap),
    );
  }
}

final class _InstallationStore implements InstallationIdStore {
  @override
  Future<String> readOrCreate() async => '11111111-1111-4111-8111-111111111111';
}

final class _TokenStore implements DeviceTokenStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}

const _account = LinkedTradingAccount(
  id: 'account-1',
  brokerId: 'yodo-demo',
  brokerName: 'YODO Demo Markets',
  serverId: 'yodo-demo-01',
  serverName: 'YODO-Demo-01',
  login: '109740422',
  isActive: true,
);

const _bootstrap = <String, Object?>{
  'serverTime': '2026-08-17T00:00:00Z',
  'version': 1,
  'device': <String, Object?>{'id': 'device-1', 'name': 'Phone'},
  'activeAccount': <String, Object?>{
    'id': 'account-1',
    'accountCode': '109740422',
    'name': 'Virtual account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': <String, Object?>{
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 0,
    'equity': 0,
    'profit': 0,
    'margin': 0,
    'freeMargin': 0,
    'marginLevel': 0,
    'updatedAt': '2026-08-17T00:00:00Z',
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
};
