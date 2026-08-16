import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  void useVideoViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  ProviderContainer createStableContainer() {
    return ProviderContainer(
      overrides: [
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
      ],
    );
  }

  testWidgets(
    'video two account list switches zero, huge and Vantage trade states',
    (tester) async {
      useVideoViewport(tester);
      final container = createStableContainer();
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/trade',
        routes: [
          GoRoute(
            path: '/trade',
            builder: (context, state) => const TradeScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const Scaffold(body: Text('REGISTER')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      expect(container.read(activeDemoAccountIdProvider), '10001001');
      expect(container.read(demoPositionsProvider), hasLength(6));
      expect(find.text('-128.00 USD'), findsOneWidget);
      expect(find.text('2 292.60'), findsOneWidget);

      router.push('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Tài khoản'), findsOneWidget);
      expect(
        find.byKey(const Key('account-round-back-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('account-round-add-button')), findsOneWidget);
      expect(find.byKey(const Key('account-broker-mark')), findsNWidgets(4));
      expect(find.byKey(const Key('account-chevron-glyph')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('account-round-back-button'))),
        const Size.square(43),
      );
      expect(
        tester.getSize(find.byKey(const Key('account-broker-mark')).first),
        const Size.square(31),
      );
      expect(find.textContaining('10001001 - Demo-Live-01'), findsOneWidget);
      expect(find.textContaining('10001002 - Demo-Trial-02'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account-10001003')));
      await tester.pumpAndSettle();
      expect(container.read(activeDemoAccountIdProvider), '10001003');
      expect(container.read(demoPositionsProvider), isEmpty);
      expect(container.read(demoAccountProvider).balance, 0);
      expect(find.text('USD'), findsOneWidget);
      expect(find.byKey(const Key('trade-bulk-menu')), findsNothing);

      router.push('/profile');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-10001002')));
      await tester.pumpAndSettle();
      expect(container.read(activeDemoAccountIdProvider), '10001002');
      expect(container.read(demoPositionsProvider), hasLength(10));
      expect(container.read(demoHistoryPositionsProvider), hasLength(37));
      expect(container.read(demoAccountProvider).balance, 27297978.10);
      expect(find.text('-1 013 283.20 USD'), findsOneWidget);
      expect(find.text('27 297 978.10'), findsOneWidget);
      expect(find.text('4108.117 → 4102.396'), findsOneWidget);
      expect(find.text('-102 405.90'), findsOneWidget);

      router.push('/profile');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-10001001')));
      await tester.pumpAndSettle();
      expect(container.read(activeDemoAccountIdProvider), '10001001');
      expect(container.read(demoPositionsProvider), hasLength(6));
      expect(container.read(demoAccountProvider).balance, 2292.60);
      expect(find.text('-128.00 USD'), findsOneWidget);
      expect(find.text('2 292.60'), findsOneWidget);
    },
  );

  testWidgets('video two trade balance dialog exposes its recorded actions', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = createStableContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/trade',
      routes: [
        GoRoute(
          path: '/trade',
          builder: (context, state) => const TradeScreen(),
        ),
        GoRoute(
          path: '/deposit',
          builder: (context, state) =>
              const Scaffold(body: Text('DEPOSIT DESTINATION')),
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
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('trade-account-metrics')));
    await tester.pumpAndSettle();
    expect(find.text('Số dư'), findsOneWidget);
    expect(find.textContaining('trang nạp/ rút tiền'), findsOneWidget);
    expect(find.text('Tien nap'), findsOneWidget);
    expect(find.text('Tien rut'), findsOneWidget);
    expect(find.text('Huy'), findsOneWidget);

    await tester.tap(find.text('Huy'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.byKey(const Key('trade-account-metrics')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tien nap'));
    await tester.pumpAndSettle();
    expect(find.text('DEPOSIT DESTINATION'), findsOneWidget);
  });

  testWidgets('trade add uses the enabled market symbol for Exness accounts', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = createStableContainer();
    addTearDown(container.dispose);
    container.read(activeDemoAccountIdProvider.notifier).select('10001002');
    final router = GoRouter(
      initialLocation: '/trade',
      routes: [
        GoRoute(
          path: '/trade',
          builder: (context, state) => const TradeScreen(),
        ),
        GoRoute(
          path: '/order',
          builder: (context, state) => Scaffold(
            body: Text('ORDER ${state.uri.queryParameters['symbol']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('trade-add-button')));
    await tester.pumpAndSettle();

    expect(find.text('ORDER XAUUSD+'), findsOneWidget);
  });

  testWidgets(
    'video two trade header and position pitch use physical geometry',
    (tester) async {
      tester.view.physicalSize = const Size(576, 1280);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const media = MediaQueryData(
        size: Size(384, 853.3333333333),
        devicePixelRatio: 1.5,
        padding: EdgeInsets.only(top: 24, bottom: 79),
        viewPadding: EdgeInsets.only(top: 24, bottom: 79),
      );
      final container = createStableContainer();
      addTearDown(container.dispose);
      final positions = container.read(demoPositionsProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MediaQuery(data: media, child: TradeScreen()),
          ),
        ),
      );
      await tester.pump();

      Rect physical(Rect logical) => Rect.fromLTRB(
        logical.left * 1.5,
        logical.top * 1.5,
        logical.right * 1.5,
        logical.bottom * 1.5,
      );
      final addButton = physical(
        tester.getRect(find.byKey(const Key('trade-add-button'))),
      );
      expect(addButton.left, closeTo(492, .01));
      expect(addButton.top, closeTo(91.5, .01));
      expect(addButton.right, closeTo(556, .01));
      expect(addButton.bottom, closeTo(155.5, .01));

      final first = tester.getRect(
        find.byKey(ValueKey('trade-position-${positions[0].id}')),
      );
      final second = tester.getRect(
        find.byKey(ValueKey('trade-position-${positions[1].id}')),
      );
      expect((second.top - first.top) * 1.5, closeTo(92.625, .01));
    },
  );

  testWidgets(
    'video two bulk actions close profit, loss and all position subsets',
    (tester) async {
      useVideoViewport(tester);
      final container = createStableContainer();
      addTearDown(container.dispose);

      void resetSmallAccountWithMixedProfit() {
        container
            .read(demoTradingProvider.notifier)
            .resetActiveAccountFixture();
        container
            .read(demoTradingProvider.notifier)
            .updateMarketPrice(symbol: 'XAUUSD+', bid: 4104.80, ask: 4104.93);
      }

      resetSmallAccountWithMixedProfit();
      expect(
        container.read(demoPositionsProvider).where((item) => item.profit > 0),
        hasLength(1),
      );
      expect(
        container.read(demoPositionsProvider).where((item) => item.profit < 0),
        hasLength(5),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TradeScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('trade-bulk-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Hoạt động hàng loạt'), findsOneWidget);
      expect(find.text('Đóng Tất Cả Lệnh Có Trạng Thái'), findsOneWidget);
      expect(
        find.text('Đóng Các Lệnh Có Trạng Thái Đang Có Lời'),
        findsOneWidget,
      );
      expect(find.text('Đóng Các Lệnh Có Trạng Thái Đang Lỗ'), findsOneWidget);

      await tester.tap(find.text('Đóng Các Lệnh Có Trạng Thái Đang Có Lời'));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Đã đóng'), findsNothing);
      await tester.pumpAndSettle();
      expect(container.read(demoPositionsProvider), hasLength(5));
      expect(
        container.read(demoPositionsProvider).every((item) => item.profit < 0),
        isTrue,
      );

      resetSmallAccountWithMixedProfit();
      await tester.pump();
      await tester.tap(find.byKey(const Key('trade-bulk-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đóng Các Lệnh Có Trạng Thái Đang Lỗ'));
      await tester.pumpAndSettle();
      expect(container.read(demoPositionsProvider), hasLength(1));
      expect(
        container.read(demoPositionsProvider).single.profit,
        greaterThan(0),
      );

      resetSmallAccountWithMixedProfit();
      await tester.pump();
      await tester.tap(find.byKey(const Key('trade-bulk-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đóng Tất Cả Lệnh Có Trạng Thái'));
      await tester.pumpAndSettle();
      expect(container.read(demoPositionsProvider), isEmpty);
      expect(find.text('USD'), findsOneWidget);
      expect(find.byKey(const Key('trade-bulk-menu')), findsNothing);
    },
  );

  testWidgets(
    'video two market swipe buttons and symbol menus are symbol specific',
    (tester) async {
      useVideoViewport(tester);
      final container = ProviderContainer(
        overrides: [
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere((item) => item.symbol == symbol);
            return Stream.value(quote);
          }),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/market',
        routes: [
          GoRoute(
            path: '/market',
            builder: (context, state) => const MarketWatchScreen(),
          ),
          GoRoute(
            path: '/order',
            builder: (context, state) => Scaffold(
              body: Text('ORDER ${state.uri.queryParameters['symbol']}'),
            ),
          ),
          GoRoute(
            path: '/chart',
            builder: (context, state) => Scaffold(
              body: Text('CHART ${state.uri.queryParameters['symbol']}'),
            ),
          ),
          GoRoute(
            path: '/section',
            builder: (context, state) => Scaffold(
              body: Text('SECTION ${state.uri.queryParameters['title']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      await tester.drag(find.text('XAUUSD+'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      final xauAnimatedRow = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('XAUUSD+'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(xauAnimatedRow.transform?.storage[12], -142);
      expect(
        find.byKey(const ValueKey('market-order-XAUUSD+')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('market-chart-XAUUSD+')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('market-order-XAUUSD+')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/order');
      expect(router.state.uri.queryParameters['symbol'], 'XAUUSD+');
      expect(find.text('ORDER XAUUSD+'), findsOneWidget);

      router.go('/market');
      await tester.pumpAndSettle();
      await tester.drag(find.text('BTCUSD'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('market-chart-BTCUSD')));
      await tester.pumpAndSettle();
      expect(find.text('CHART BTCUSD'), findsOneWidget);
      expect(router.state.uri.queryParameters['timeframe'], 'H1');

      router.go('/market');
      await tester.pumpAndSettle();
      await tester.tap(find.text('XAUUSD+'));
      await tester.pumpAndSettle();
      expect(find.text('XAUUSD+: Gold US Dollar'), findsOneWidget);
      expect(find.text('Giao dich'), findsOneWidget);
      expect(find.text('Bieu do'), findsOneWidget);
      expect(find.text('Chi tiet'), findsOneWidget);
      expect(find.text('Thống kê thị trường'), findsOneWidget);
      expect(find.text('Depth of Market'), findsOneWidget);
      expect(find.text('Xoa'), findsNothing);

      await tester.tap(find.text('Huy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BTCUSD'));
      await tester.pumpAndSettle();
      expect(find.text('BTCUSD: Bitcoin'), findsOneWidget);
      expect(find.text('Depth of Market'), findsNothing);
      expect(find.text('Xoa'), findsOneWidget);

      await tester.tap(find.text('Xoa'));
      await tester.pumpAndSettle();
      expect(container.read(marketSymbolsProvider), const ['XAUUSD+']);
      expect(find.text('BTCUSD'), findsNothing);

      container.read(marketSymbolsProvider.notifier).add('AUDNOK');
      await tester.pump();
      await tester.tap(find.text('AUDNOK'));
      await tester.pumpAndSettle();
      expect(find.text('Xoa'), findsOneWidget);
      await tester.tap(find.text('Huy'));
      await tester.pumpAndSettle();

      await tester.drag(find.text('AUDNOK'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('market-delete-AUDNOK')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('market-delete-AUDNOK')));
      await tester.pump();
      expect(container.read(marketSymbolsProvider), const ['XAUUSD+']);
    },
  );
}
