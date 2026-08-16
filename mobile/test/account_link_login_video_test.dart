import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/data/account_reconnect_grant_store.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/realtime_market_service.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

void main() {
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
      'existing-account-save-switch',
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
      'Lưu mật khẩu',
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
    final saveSwitch = tester.widget<Switch>(
      find.byKey(const Key('existing-account-save-switch')),
    );
    expect(saveSwitch.value, isTrue);
    expect(saveSwitch.activeTrackColor, AppColors.savePasswordEnabled);
    expect(AppColors.savePasswordEnabled, const Color(0xFF30D158));
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
        linkError: const ExV2RequestFailure(
          statusCode: 401,
          code: 'invalid_credentials',
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
    expect(find.text('Thông tin đăng nhập không hợp lệ'), findsOneWidget);
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
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('existing-account-save-switch')))
          .value,
      isTrue,
    );
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
    'initial server failure is visible and retries the real catalog',
    (tester) async {
      final repository = _LoginRepository(serverFailures: 1);
      await _openForm(tester, repository: repository);

      expect(
        find.byKey(const Key('existing-account-server-error')),
        findsOneWidget,
      );
      expect(find.text('Unable to link this account'), findsOneWidget);
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

  testWidgets(
    'navigation waits for link activation and bootstrap publication',
    (tester) async {
      final activationGate = Completer<void>();
      final events = <String>[];
      await _openForm(
        tester,
        repository: _LoginRepository(
          activationGate: activationGate,
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
      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('existing-account-login-screen'))),
      );

      await tester.tap(find.byKey(const Key('existing-account-login-button')));
      await tester.pump();

      expect(events, ['link', 'activate:start']);
      expect(appRouter.state.uri.path, '/accounts/add/exness');

      activationGate.complete();
      await tester.pumpAndSettle();

      expect(events, ['link', 'activate:start', 'activate:complete']);
      expect(
        providerContainer
            .read(exV2AccountProvider)
            .requireValue
            ?.bootstrap
            .account
            .id,
        'account-1',
      );
      expect(appRouter.state.uri.path, '/trade');
    },
  );

  testWidgets('offline link stays disabled and reconnect enables it', (
    tester,
  ) async {
    final statuses = StreamController<MarketConnectionStatus>()
      ..add(MarketConnectionStatus.disconnected);
    addTearDown(statuses.close);
    final repository = _LoginRepository(activationGate: Completer<void>());
    await _openForm(
      tester,
      repository: repository,
      connectionStatuses: statuses.stream,
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
      isNull,
    );
    expect(repository.linkRequests, isEmpty);

    statuses.add(MarketConnectionStatus.connected);
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
    expect(repository.linkRequests, hasLength(1));
  });

  testWidgets('registration and forgot-password rows provide safe feedback', (
    tester,
  ) async {
    await _openForm(tester, repository: _LoginRepository());

    for (final entry in const {
      'real-account-row': 'Đăng ký tài khoản thật chưa được hỗ trợ',
      'demo-account-row': 'Đăng ký tài khoản dùng thử chưa được hỗ trợ',
      'existing-account-forgot-password': 'Khôi phục mật khẩu chưa được hỗ trợ',
    }.entries) {
      await tester.tap(find.byKey(Key(entry.key)));
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
      expect(appRouter.state.uri.path, '/accounts/add/exness');
      ScaffoldMessenger.of(
        tester.element(find.byKey(Key(entry.key))),
      ).hideCurrentSnackBar();
      await tester.pump();
    }

    appRouter.go('/register');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-link-qr-button')));
    await tester.pump();

    expect(
      find.text('Nhập tài khoản bằng QR chưa được hỗ trợ'),
      findsOneWidget,
    );
    expect(appRouter.state.uri.path, '/register');
  });
}

Future<void> _openForm(
  WidgetTester tester, {
  required _LoginRepository repository,
  Stream<MarketConnectionStatus>? connectionStatuses,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountLinkRepositoryProvider.overrideWithValue(repository),
        accountReconnectGrantStoreProvider.overrideWithValue(
          _MemoryGrantStore(),
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
      child: MaterialApp.router(theme: AppTheme.dark, routerConfig: appRouter),
    ),
  );
  addTearDown(() => appRouter.go('/'));
  appRouter.go('/accounts/add');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('broker-row-exness')));
  await tester.pumpAndSettle();

  expect(appRouter.state.uri.path, '/accounts/add/exness');
  expect(
    find.byKey(const Key('existing-account-login-screen')),
    findsOneWidget,
  );
}

final class _LoginRepository implements AccountLinkRepository {
  _LoginRepository({
    this.linkError,
    this.activationGate,
    this.events,
    this.serverFailures = 0,
  });

  final Object? linkError;
  final Completer<void>? activationGate;
  final List<String>? events;
  final int serverFailures;
  final List<LinkAccountRequest> linkRequests = <LinkAccountRequest>[];
  int serverCalls = 0;

  @override
  Future<List<LinkedTradingAccount>> accounts() async => const [];

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) async {
    events?.add('activate:start');
    if (activationGate != null) await activationGate!.future;
    events?.add('activate:complete');
    return ActivateLinkedAccountResult(
      account: _linkedAccount,
      bootstrap: ExV2Bootstrap.fromJson(_bootstrapJson),
    );
  }

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) async => const [
    MobileBroker(
      id: 'exness',
      name: 'Exness Technologies Ltd',
      companyName: 'Exness',
    ),
  ];

  @override
  Future<LinkAccountResult> link(
    LinkAccountRequest request, {
    required ExV2CommandMetadata metadata,
  }) async {
    events?.add('link');
    linkRequests.add(request);
    if (linkError case final error?) throw error;
    return const LinkAccountResult(
      account: _linkedAccount,
      reconnectGrant: 'opaque-grant',
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

final class _MemoryGrantStore implements AccountReconnectGrantStore {
  @override
  Future<void> delete(String accountId) async {}

  @override
  Future<String?> read(String accountId) async => null;

  @override
  Future<void> write(String accountId, String grant) async {}
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
