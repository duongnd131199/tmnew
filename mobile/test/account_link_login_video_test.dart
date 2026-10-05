import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
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
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/realtime_market_service.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

void main() {
  testWidgets('remembered account route prefills login and selected server', (
    tester,
  ) async {
    await _openForm(tester, repository: _LoginRepository());

    appRouter.go('/accounts/add/exness?login=109740422&serverId=real-15');
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('existing-account-login-field')),
          )
          .controller
          ?.text,
      '109740422',
    );
    expect(find.text('Exness-MT5Real15'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('existing-account-password-field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets(
    'entered login and password values render blue with medium weight',
    (tester) async {
      await _openForm(tester, repository: _LoginRepository());

      await tester.enterText(
        find.byKey(const Key('existing-account-login-field')),
        '124685005',
      );
      await tester.enterText(
        find.byKey(const Key('existing-account-password-field')),
        'secret-password',
      );
      await tester.pump();

      const referenceValueColor = Color(0xFF007AFF);
      final loginField = tester.widget<TextField>(
        find.byKey(const Key('existing-account-login-field')),
      );
      final passwordField = tester.widget<TextField>(
        find.byKey(const Key('existing-account-password-field')),
      );

      expect(loginField.style?.color, referenceValueColor);
      expect(passwordField.style?.color, referenceValueColor);
      expect(loginField.style?.fontWeight, FontWeight.w500);
      expect(passwordField.style?.fontWeight, FontWeight.w500);
    },
  );

  testWidgets(
    'reference remembered route keeps the Exness server presentation',
    (tester) async {
      await _openForm(
        tester,
        repository: _LoginRepository(referenceCatalog: true),
        brokerKey: 'exness',
        brokerId: 'yodo-demo',
      );

      appRouter.go(
        '/accounts/add/yodo-demo?login=109740422&serverId=yodo-demo-01',
      );
      await tester.pumpAndSettle();

      expect(find.text('Exness-MT5Trial5'), findsOneWidget);
      expect(find.text('YODO-Demo-01'), findsNothing);
    },
  );

  testWidgets('12 second frame keeps the reference copy and vertical order', (
    tester,
  ) async {
    await _openForm(tester, repository: _LoginRepository());

    const orderedKeys = [
      'existing-account-header',
      'new-account-section-title',
      'real-account-row',
      'demo-account-row',
      'existing-account-section-title',
      'existing-account-server-row',
      'existing-account-login-field',
      'existing-account-password-field',
      'existing-account-forgot-password',
      'existing-account-login-button',
    ];
    final verticalCenters = orderedKeys
        .map((key) => tester.getCenter(find.byKey(Key(key))).dy)
        .toList();

    expect(verticalCenters, orderedEquals([...verticalCenters]..sort()));
    for (final copy in const [
      'Exness Technologies Ltd',
      'Đăng ký tài khoản mới',
      'Tài khoản thật',
      'Tạo tài khoản thật bằng cách điền vào mẫu đơn sau và gửi các giấy tờ yêu cầu',
      'Tài khoản dùng thử',
      'Đăng ký tài khoản để học giao dịch và kiểm tra chiến lược',
      'Sử dụng tài khoản hiện có',
      'Máy chủ',
      'Mật khẩu',
      'Quên mật khẩu',
    ]) {
      expect(find.text(copy), findsOneWidget);
    }
    expect(find.text('Đăng nhập'), findsNWidgets(2));
    expect(find.text('Exness-MT5Real20'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('existing-account-login-field')),
          )
          .keyboardType,
      TextInputType.number,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('existing-account-password-field')),
          )
          .obscureText,
      isTrue,
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const Key('existing-account-section-title')),
          )
          .color,
      AppColors.accountLinkBackground,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('existing-account-login-button')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    '20 to 28 second route sequence preserves fields and enables login',
    (tester) async {
      final repository = _LoginRepository();
      await _openForm(tester, repository: repository);

      await tester.enterText(
        find.byKey(const Key('existing-account-login-field')),
        '425297911',
      );
      await tester.enterText(
        find.byKey(const Key('existing-account-password-field')),
        'secret-password',
      );
      await tester.tap(find.byKey(const Key('existing-account-server-row')));
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.path, '/accounts/add/exness/servers');
      await tester.tap(find.byKey(const Key('server-row-real-15')));
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.path, '/accounts/add/exness');
      expect(find.text('Exness-MT5Real15'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('existing-account-login-field')),
            )
            .controller
            ?.text,
        '425297911',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('existing-account-password-field')),
            )
            .controller
            ?.text,
        'secret-password',
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('existing-account-login-button')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('existing-account-login-button')));
      await tester.pumpAndSettle();

      expect(repository.loginRequests, isEmpty);
      expect(repository.linkRequests, hasLength(1));
      expect(repository.linkRequests.single.serverId, 'real-15');
      expect(repository.linkRequests.single.login, '425297911');
      expect(repository.linkRequests.single.password, 'secret-password');
    },
  );

  testWidgets('invalid credentials clear only password and stay on the form', (
    tester,
  ) async {
    await _openForm(
      tester,
      repository: _LoginRepository(
        authError: const ExV2RequestFailure(
          statusCode: 401,
          code: 'invalid_credentials',
          correlationId: 'corr-safe-widget',
          message: 'Thông tin đăng nhập không hợp lệ',
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('existing-account-login-field')),
      '425297911',
    );
    await tester.enterText(
      find.byKey(const Key('existing-account-password-field')),
      'wrong-password',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('existing-account-login-button')));
    await tester.pump();
    await tester.pump();

    expect(appRouter.state.uri.path, '/accounts/add/exness');
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('invalid_credentials'), findsNothing);
    expect(find.textContaining('corr-safe-widget'), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('existing-account-login-field')),
          )
          .controller
          ?.text,
      '425297911',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('existing-account-password-field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.text('Exness-MT5Real20'), findsOneWidget);
  });

  testWidgets(
    'an unknown broker route cannot expose or submit stale form state',
    (tester) async {
      final repository = _LoginRepository();
      await _openForm(tester, repository: repository);
      await tester.enterText(
        find.byKey(const Key('existing-account-login-field')),
        '425297911',
      );
      await tester.enterText(
        find.byKey(const Key('existing-account-password-field')),
        'stale-password',
      );
      await tester.pump();

      appRouter.go('/accounts/add/unknown-broker');
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.path, '/accounts/add');
      expect(
        find.byKey(const Key('existing-account-login-screen')),
        findsNothing,
      );
      expect(repository.linkRequests, isEmpty);
    },
  );

  testWidgets(
    'anchored login action clears keyboard and system bottom insets',
    (tester) async {
      await _openForm(tester, repository: _LoginRepository());
      addTearDown(() {
        tester.view.resetPadding();
        tester.view.resetViewInsets();
        tester.view.resetViewPadding();
      });
      final pixelRatio = tester.view.devicePixelRatio;
      tester.view.padding = FakeViewPadding(top: 24 * pixelRatio);
      tester.view.viewPadding = FakeViewPadding(
        top: 24 * pixelRatio,
        bottom: 24 * pixelRatio,
      );
      tester.view.viewInsets = FakeViewPadding(bottom: 300 * pixelRatio);
      await tester.pump();

      final logicalHeight = tester
          .getSize(find.byKey(const Key('existing-account-login-screen')))
          .height;
      var actionBottom = tester
          .getBottomRight(
            find.byKey(const Key('existing-account-login-button')),
          )
          .dy;
      var media = MediaQuery.of(
        tester.element(find.byKey(const Key('existing-account-login-screen'))),
      );
      expect(
        actionBottom,
        lessThanOrEqualTo(logicalHeight - media.viewInsets.bottom),
      );

      tester.view.padding = FakeViewPadding(
        top: 24 * pixelRatio,
        bottom: 24 * pixelRatio,
      );
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();

      actionBottom = tester
          .getBottomRight(
            find.byKey(const Key('existing-account-login-button')),
          )
          .dy;
      media = MediaQuery.of(
        tester.element(find.byKey(const Key('existing-account-login-screen'))),
      );
      expect(
        actionBottom,
        lessThanOrEqualTo(logicalHeight - media.padding.bottom),
      );
    },
  );

  testWidgets(
    'initial server failure stays silent and retries the real catalog',
    (tester) async {
      final repository = _LoginRepository(serverFailures: 1);
      await _openForm(tester, repository: repository);

      expect(
        find.byKey(const Key('existing-account-server-error')),
        findsOneWidget,
      );
      expect(find.text('Unable to link this account'), findsNothing);
      expect(repository.serverCalls, 1);

      await tester.tap(find.byKey(const Key('existing-account-server-retry')));
      await tester.pumpAndSettle();

      expect(repository.serverCalls, 2);
      expect(
        find.byKey(const Key('existing-account-server-error')),
        findsNothing,
      );
      expect(find.text('Exness-MT5Real20'), findsOneWidget);
    },
  );

  testWidgets('navigation waits for linked-account activation', (tester) async {
    final sessionCommitGate = Completer<void>();
    final events = <String>[];
    await _openForm(
      tester,
      repository: _LoginRepository(
        sessionCommitGate: sessionCommitGate,
        events: events,
      ),
    );
    await tester.enterText(
      find.byKey(const Key('existing-account-login-field')),
      '425297911',
    );
    await tester.enterText(
      find.byKey(const Key('existing-account-password-field')),
      'correct-password',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('existing-account-login-button')));
    await tester.pump();

    expect(events, ['link', 'activate:start']);
    expect(appRouter.state.uri.path, '/accounts/add/exness');
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('existing-account-password-field')),
          )
          .controller
          ?.text,
      'correct-password',
    );

    sessionCommitGate.complete();
    await tester.pumpAndSettle();

    expect(events, ['link', 'activate:start', 'activate:complete']);
    expect(appRouter.state.uri.path, '/trade');
  });

  testWidgets('market feed disconnection does not block REST account login', (
    tester,
  ) async {
    final statuses = Stream.value(MarketConnectionStatus.disconnected);
    final repository = _LoginRepository();
    await _openForm(
      tester,
      repository: repository,
      connectionStatuses: statuses,
    );
    await tester.enterText(
      find.byKey(const Key('existing-account-login-field')),
      '100001',
    );
    await tester.enterText(
      find.byKey(const Key('existing-account-password-field')),
      'correct-password',
    );
    await tester.pump();

    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('existing-account-login-button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('existing-account-login-button')));
    await tester.pump();
    await tester.pump();
    expect(repository.loginRequests, isEmpty);
    expect(repository.linkRequests, hasLength(1));
    expect(appRouter.state.uri.path, '/trade');
  });

  testWidgets('registration, recovery and QR rows stay silent', (tester) async {
    await _openForm(tester, repository: _LoginRepository());

    for (final entry in const {
      'real-account-row': 'Đăng ký tài khoản thật chưa được hỗ trợ',
      'demo-account-row': 'Đăng ký tài khoản dùng thử chưa được hỗ trợ',
      'existing-account-forgot-password': 'Khôi phục mật khẩu chưa được hỗ trợ',
    }.entries) {
      await tester.tap(find.byKey(Key(entry.key)));
      await tester.pump();
      expect(find.text(entry.value), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(appRouter.state.uri.path, '/accounts/add/exness');
    }

    appRouter.go('/register');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-link-qr-button')));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Nhập tài khoản bằng QR chưa được hỗ trợ'), findsNothing);
    expect(appRouter.state.uri.path, '/register');
  });
}

Future<void> _openForm(
  WidgetTester tester, {
  required _LoginRepository repository,
  Stream<MarketConnectionStatus>? connectionStatuses,
  String brokerKey = 'exness',
  String brokerId = 'exness',
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountLinkRepositoryProvider.overrideWithValue(repository),
        accountPasswordLoginRepositoryProvider.overrideWithValue(
          _PasswordLoginRepository(repository),
        ),
        installationIdStoreProvider.overrideWithValue(_InstallationStore()),
        accountSessionCommitterProvider.overrideWithValue(
          _SessionCommitter(repository),
        ),
        linkedAccountPresentationStoreProvider.overrideWithValue(
          _MemoryPresentationStore(),
        ),
        removedAccountStoreProvider.overrideWithValue(
          _MemoryRemovedAccountStore(),
        ),
        if (connectionStatuses != null) ...[
          exV2EnabledProvider.overrideWithValue(true),
          marketConnectionStatusProvider.overrideWith(
            (ref) => connectionStatuses,
          ),
          exV2AccountProvider.overrideWithBuild(
            (ref, controller) => ExV2AccountViewState.fromBootstrap(
              ExV2Bootstrap.fromJson(_bootstrapJson),
            ),
          ),
        ],
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: appRouter),
    ),
  );
  addTearDown(() => appRouter.go('/'));
  appRouter.go('/accounts/add');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('broker-row-$brokerKey')));
  await tester.pumpAndSettle();

  expect(appRouter.state.uri.path, '/accounts/add/$brokerId');
  expect(
    find.byKey(const Key('existing-account-login-screen')),
    findsOneWidget,
  );
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

final class _PasswordLoginRepository implements AccountPasswordLoginRepository {
  _PasswordLoginRepository(this.repository);

  final _LoginRepository repository;

  @override
  Future<AccountPasswordLoginResult> login(
    AccountPasswordLoginRequest request, {
    required String installationId,
    required ExV2CommandMetadata metadata,
  }) async {
    repository.loginRequests.add(request);
    repository.events?.add('authenticate');
    if (repository.authError case final error?) throw error;
    return AccountPasswordLoginResult(
      deviceToken: 'token-account-1',
      account: _linkedAccount,
      bootstrap: ExV2Bootstrap.fromJson(_bootstrapJson),
    );
  }
}

final class _SessionCommitter implements AccountSessionCommitter {
  _SessionCommitter(this.repository);

  final _LoginRepository repository;

  @override
  Future<ExV2BootstrapPublication> commit(
    AccountPasswordLoginResult result,
  ) async {
    repository.events?.add('commit-session:start');
    if (repository.sessionCommitGate != null) {
      await repository.sessionCommitGate!.future;
    }
    repository.events?.add('commit-session:complete');
    return ExV2BootstrapPublication.idempotentReplay;
  }
}

final class _InstallationStore implements InstallationIdStore {
  @override
  Future<String> readOrCreate() async => '11111111-1111-4111-8111-111111111111';
}

final class _LoginRepository implements AccountLinkRepository {
  _LoginRepository({
    this.authError,
    this.sessionCommitGate,
    this.events,
    this.serverFailures = 0,
    this.referenceCatalog = false,
  });

  final Object? authError;
  final Completer<void>? sessionCommitGate;
  final List<String>? events;
  final int serverFailures;
  final bool referenceCatalog;
  final List<AccountPasswordLoginRequest> loginRequests =
      <AccountPasswordLoginRequest>[];
  final List<LinkAccountRequest> linkRequests = <LinkAccountRequest>[];
  final Map<String, LinkedTradingAccount> linkedAccounts = {};
  int serverCalls = 0;

  @override
  Future<List<LinkedTradingAccount>> accounts() async => const [];

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) async {
    events?.add('activate:start');
    if (sessionCommitGate != null) await sessionCommitGate!.future;
    final account = linkedAccounts[accountId];
    if (account == null) throw StateError('Account was not linked');
    events?.add('activate:complete');
    return ActivateLinkedAccountResult(
      account: LinkedTradingAccount(
        id: account.id,
        brokerId: account.brokerId,
        brokerName: account.brokerName,
        serverId: account.serverId,
        serverName: account.serverName,
        login: account.login,
        isActive: true,
      ),
      bootstrap: ExV2Bootstrap.fromJson(
        _bootstrapForAccount(account.id, account.login),
      ),
    );
  }

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) async => [
    MobileBroker(
      id: referenceCatalog ? 'yodo-demo' : 'exness',
      name: referenceCatalog ? 'YODO Demo Markets' : 'Exness Technologies Ltd',
      companyName: referenceCatalog ? 'YODO' : 'Exness',
    ),
  ];

  @override
  Future<LinkAccountResult> link(
    LinkAccountRequest request, {
    required ExV2CommandMetadata metadata,
  }) async {
    linkRequests.add(request);
    events?.add('link');
    if (authError case final error?) throw error;
    final account = LinkedTradingAccount(
      id: 'account-1',
      brokerId: request.brokerId,
      brokerName: request.brokerId == 'exness'
          ? 'Exness Technologies Ltd'
          : 'YODO Demo Markets',
      serverId: request.serverId,
      serverName: switch (request.serverId) {
        'real-15' => 'Exness-MT5Real15',
        'real-20' => 'Exness-MT5Real20',
        _ => 'YODO-Demo-01',
      },
      login: request.login,
      isActive: false,
    );
    linkedAccounts[account.id] = account;
    return LinkAccountResult(
      account: account,
      reconnectGrant: 'opaque-grant-account-1',
      alreadyLinked: false,
    );
  }

  @override
  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) async {
    serverCalls += 1;
    if (serverCalls <= serverFailures) {
      throw StateError('server catalog unavailable');
    }
    if (referenceCatalog) {
      return const [
        MobileTradingServer(
          id: 'yodo-demo-01',
          name: 'YODO-Demo-01',
          brokerId: 'yodo-demo',
        ),
      ];
    }
    return const [
      MobileTradingServer(
        id: 'real-20',
        name: 'Exness-MT5Real20',
        brokerId: 'exness',
      ),
      MobileTradingServer(
        id: 'real-15',
        name: 'Exness-MT5Real15',
        brokerId: 'exness',
      ),
    ];
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

const _linkedAccount = LinkedTradingAccount(
  id: 'account-1',
  brokerId: 'exness',
  brokerName: 'Exness Technologies Ltd',
  serverId: 'real-20',
  serverName: 'Exness-MT5Real20',
  login: '425297911',
  isActive: true,
);

const _bootstrapJson = <String, Object?>{
  'serverTime': '2026-08-15T08:00:00Z',
  'version': 2,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-1',
    'accountCode': '425297911',
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

Map<String, Object?> _bootstrapForAccount(String accountId, String login) => {
  ..._bootstrapJson,
  'activeAccount': {
    ...(_bootstrapJson['activeAccount']! as Map<String, Object?>),
    'id': accountId,
    'accountCode': login,
  },
  'summary': {
    ...(_bootstrapJson['summary']! as Map<String, Object?>),
    'accountId': accountId,
  },
};
