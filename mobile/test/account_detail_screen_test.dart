import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/profile/presentation/screens/account_detail_screen.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  testWidgets('account detail route renders the account detail screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: appRouter)),
    );

    appRouter.go('/account-detail');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-detail-screen')), findsOneWidget);
  });

  testWidgets('account detail exposes every row visible in the reference', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDemoAccountProvider.overrideWithValue(_exnessAccount),
        ],
        child: const MaterialApp(home: AccountDetailScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Mỗi Ngày Một Tỷ 🍀'), findsWidgets);
    expect(find.text('109740422 - Exness-MT5Real20'), findsOneWidget);
    expect(find.text('154 763.90 USD'), findsOneWidget);
    expect(find.text('Master'), findsOneWidget);
    expect(find.text('Hedge'), findsOneWidget);
    expect(find.text('Exness Technologies Ltd'), findsOneWidget);
    expect(find.text('active'), findsNothing);
    expect(find.textContaining('trochoi.top'), findsNothing);
    expect(find.text('EX V2'), findsNothing);

    final back = find.byKey(const Key('account-round-back-button'));
    final mark = find.byKey(const Key('account-broker-mark'));
    expect(back, findsOneWidget);
    expect(mark, findsOneWidget);
    expect(tester.getSize(back), const Size.square(43));
    expect(tester.getSize(mark), const Size.square(60));
    expect(find.byKey(const Key('account-detail-hero')), findsOneWidget);
    expect(
      find.byKey(const Key('account-detail-company-group')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-detail-money-group')), findsOneWidget);
    expect(
      find.byKey(const Key('account-detail-profile-group')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account-detail-security-group')),
      findsOneWidget,
    );
    expect(find.text('Công ty'), findsOneWidget);
    expect(find.text('Tiền nạp'), findsOneWidget);
    expect(find.text('Tiền rút'), findsOneWidget);
    expect(find.text('Tên'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Điện thoại'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Máy chủ'), findsOneWidget);
    expect(find.text('Đã kết nối'), findsOneWidget);
    expect(find.text('Access Point #9'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));

    await tester.drag(
      find.byKey(const Key('account-detail-scroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thông báo giao dịch'), findsOneWidget);
    expect(find.text('Kết nối từ thiết bị khác'), findsOneWidget);
    expect(find.text('Thay đổi mật khẩu'), findsOneWidget);
    expect(find.text('Xóa tài khoản'), findsOneWidget);
  });

  testWidgets('trade notifications switch changes immediately when tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AccountDetailScreen())),
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('account-detail-scroll')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const Key('trade-notifications-switch'));
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pump();

    expect(tester.widget<Switch>(switchFinder).value, isTrue);
  });

  testWidgets('trade notification failure restores confirmed server value', (
    tester,
  ) async {
    final adapter = _DeferredFailingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final serverState = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(_bootstrap),
    ).copyWith(settings: const {'tradeNotificationsEnabled': false});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDemoAccountProvider.overrideWithValue(_exnessAccount),
          exV2AccountProvider.overrideWithBuild(
            (ref, controller) async => serverState,
          ),
          exV2ApiClientProvider.overrideWithValue(
            ExV2ApiClient(dio: dio, tokenReader: () async => 'test-token'),
          ),
        ],
        child: const MaterialApp(home: AccountDetailScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('account-detail-scroll')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const Key('trade-notifications-switch'));
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    await tester.tap(switchFinder);
    await tester.pump();
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    adapter.releaseFailure();
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
  });

  testWidgets('deposit row opens the existing deposit route', (tester) async {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) => const AccountDetailScreen(),
        ),
        GoRoute(
          path: '/deposit',
          builder: (context, state) =>
              const Scaffold(body: Text('DEPOSIT DESTINATION')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('account-deposit-row')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/deposit');
  });

  testWidgets('withdraw row opens the existing withdraw route', (tester) async {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) => const AccountDetailScreen(),
        ),
        GoRoute(
          path: '/withdraw',
          builder: (context, state) =>
              const Scaffold(body: Text('WITHDRAW DESTINATION')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('account-withdraw-row')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/withdraw');
  });
}

const _exnessAccount = DemoAccountProfile(
  id: '109740422',
  name: 'Mỗi Ngày Một Tỷ 🍀',
  company: 'Exness Technologies Ltd',
  server: 'Exness-MT5Real20',
  accessPoint: 'Access Point #9',
  balance: 154763.90,
  brand: DemoBrokerBrand.exness,
  historyDeposit: 0,
  historyWithdrawal: 0,
  historyProfit: 0,
  historySwap: 0,
  historyCommission: 0,
  historyBalance: 154763.90,
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

final class _DeferredFailingAdapter implements HttpClientAdapter {
  final Completer<void> _gate = Completer<void>();

  void releaseFailure() => _gate.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await _gate.future;
    return ResponseBody.fromString(
      '{"error":"settings unavailable"}',
      500,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
