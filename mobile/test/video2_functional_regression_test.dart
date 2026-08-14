import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/account_detail_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/section_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/settings_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

void main() {
  void useVideoViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  String formatAccount(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final digits = parts.first;
    final grouped = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        grouped.write(' ');
      }
      grouped.write(digits[index]);
    }
    return '$grouped.${parts.last}';
  }

  testWidgets('bottom tab change fades from below one to fully visible', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/first',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/first',
                  builder: (context, state) =>
                      const Scaffold(body: Text('FIRST BRANCH')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/second',
                  builder: (context, state) =>
                      const Scaffold(body: Text('SECOND BRANCH')),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    FadeTransition fade() => tester.widget<FadeTransition>(
      find.byKey(const Key('app-shell-tab-fade')),
    );

    expect(fade().opacity.value, 1);

    await tester.tap(find.text('Bieu do'));
    await tester.pump();

    expect(find.text('SECOND BRANCH'), findsOneWidget);
    expect(fade().opacity.value, lessThan(1));

    await tester.pump(const Duration(milliseconds: 80));
    expect(fade().opacity.value, inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 80));
    expect(fade().opacity.value, closeTo(1, .001));
  });

  testWidgets('bulk modal can cancel twice without changing six positions', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = ProviderContainer(
      overrides: [
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TradeScreen()),
      ),
    );
    await tester.pump();

    for (var attempt = 0; attempt < 2; attempt++) {
      expect(container.read(demoPositionsProvider), hasLength(6));
      await tester.tap(find.byKey(const Key('trade-bulk-menu')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      await tester.tap(find.text('Huy'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(container.read(demoPositionsProvider), hasLength(6));
    }
  });

  testWidgets(
    'active settings account opens its detail instead of returning immediately',
    (tester) async {
      useVideoViewport(tester);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/account-detail',
            builder: (context, state) => const AccountDetailScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) =>
                const Scaffold(body: Text('REGISTER DESTINATION')),
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

      expect(find.text('Delete'), findsOneWidget);
      expect(
        find.textContaining('28210230 - VantageMarkets-Live 19'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('settings-account')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile');
      expect(find.byKey(const ValueKey('account-28210230')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account-28210230')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/account-detail');
      expect(find.byKey(const Key('account-detail-screen')), findsOneWidget);

      await tester.tap(find.byKey(const Key('account-detail-back')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile');

      await tester.tap(find.byKey(const Key('accounts-back')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/settings');
      expect(find.byKey(const Key('settings-account')), findsOneWidget);
    },
  );

  testWidgets(
    'server account flow resets to settings after switching bottom tabs',
    (tester) async {
      useVideoViewport(tester);
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2AccountProvider.overrideWithBuild(
            (ref, controller) => _serverAccountState,
          ),
          chartMarketWarmupProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/market',
                    builder: (context, state) =>
                        const Scaffold(body: Text('MARKET DESTINATION')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/chart',
                    builder: (context, state) =>
                        const Scaffold(body: Text('CHART DESTINATION')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/trade',
                    builder: (context, state) =>
                        const Scaffold(body: Text('TRADE DESTINATION')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/history',
                    builder: (context, state) =>
                        const Scaffold(body: Text('HISTORY DESTINATION')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/account-detail',
            builder: (context, state) => const AccountDetailScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) =>
                const Scaffold(body: Text('REGISTER DESTINATION')),
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
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-account')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-broker-mark')), findsOneWidget);
      expect(find.byKey(const ValueKey('account-109740422')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account-109740422')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/account-detail');

      await tester.tap(find.byKey(const Key('account-detail-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accounts-back')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/settings');

      await tester.tap(find.byKey(const ValueKey('bottom-nav-icon-quotes')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/market');

      await tester.tap(find.byKey(const ValueKey('bottom-nav-icon-settings')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/settings');
      expect(find.byKey(const Key('settings-account')), findsOneWidget);
      expect(find.byKey(const Key('account-detail-screen')), findsNothing);
    },
  );

  testWidgets(
    'empty trade wallet button is hittable and balance dialog cancels cleanly',
    (tester) async {
      useVideoViewport(tester);
      final container = ProviderContainer(
        overrides: [
          demoQuoteProvider.overrideWith(
            (ref, symbol) => const Stream<DemoQuote>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeDemoAccountIdProvider.notifier).select('425302695');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TradeScreen()),
        ),
      );
      await tester.pump();

      expect(container.read(demoPositionsProvider), isEmpty);
      final walletButton = find.byKey(const Key('trade-balance-button'));
      expect(walletButton, findsOneWidget);
      expect(tester.getSize(walletButton), const Size.square(42.6666666667));

      await tester.tap(walletButton);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Tien nap'), findsOneWidget);
      expect(find.text('Tien rut'), findsOneWidget);
      expect(find.text('Huy'), findsOneWidget);

      await tester.tap(find.text('Huy'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('USD'), findsOneWidget);
      expect(container.read(demoPositionsProvider), isEmpty);
    },
  );

  testWidgets('populated trade keeps the video wallet button visible', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = ProviderContainer(
      overrides: [
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TradeScreen()),
      ),
    );
    await tester.pump();

    expect(container.read(demoPositionsProvider), isNotEmpty);
    final walletButton = find.byKey(const Key('trade-balance-button'));
    expect(walletButton, findsOneWidget);
    expect(tester.getSize(walletButton), const Size.square(42.6666666667));

    await tester.tap(walletButton);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Tien nap'), findsOneWidget);
    expect(find.text('Tien rut'), findsOneWidget);
  });

  testWidgets('XAU details action closes back to the Gia market tab', (
    tester,
  ) async {
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
          path: '/section',
          builder: (context, state) =>
              SectionScreen(title: state.uri.queryParameters['title'] ?? ''),
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

    expect(find.text('Gia'), findsOneWidget);
    await tester.tap(find.text('XAUUSD+'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('market-symbol-menu-XAUUSD+')),
      findsOneWidget,
    );

    await tester.tap(find.text('Chi tiet'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/section');
    expect(find.text('XAUUSD+'), findsOneWidget);
    expect(find.text('Gold US Dollar'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/market');
    expect(find.text('Gia'), findsOneWidget);
    expect(find.text('XAUUSD+'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('market-symbol-menu-XAUUSD+')),
      findsNothing,
    );
  });

  testWidgets(
    'trade quote tick updates six rows and all derived account metrics',
    (tester) async {
      useVideoViewport(tester);
      final quoteController = StreamController<DemoQuote>();
      addTearDown(quoteController.close);
      final container = ProviderContainer(
        overrides: [
          demoQuoteProvider.overrideWith(
            (ref, symbol) => quoteController.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TradeScreen()),
        ),
      );
      await tester.pump();

      const tick = DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4110,
        ask: 4110.13,
        changePercent: .2,
      );
      quoteController.add(tick);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final positions = container.read(demoPositionsProvider);
      final account = container.read(demoAccountProvider);
      expect(positions, hasLength(6));
      expect(
        positions.every(
          (position) =>
              position.currentPrice == tick.bid && position.side == 'BUY',
        ),
        isTrue,
      );

      final expectedProfit = positions.fold<double>(
        0,
        (total, position) => total + position.profit,
      );
      expect(account.profit, closeTo(expectedProfit, .000001));
      expect(
        account.equity,
        closeTo(account.balance + expectedProfit, .000001),
      );
      expect(
        account.freeMargin,
        closeTo(account.equity - account.margin, .000001),
      );
      expect(
        account.marginLevel,
        closeTo(account.equity / account.margin * 100, .000001),
      );

      for (final position in positions) {
        final row = find.byKey(ValueKey('trade-position-${position.id}'));
        expect(row, findsOneWidget);
        final rowText = tester
            .widgetList<Text>(
              find.descendant(of: row, matching: find.byType(Text)),
            )
            .map((text) => text.data ?? text.textSpan?.toPlainText())
            .whereType<String>()
            .toList();
        expect(
          rowText,
          contains(
            '${position.openPrice.toStringAsFixed(2)} → '
            '${position.currentPrice.toStringAsFixed(2)}',
          ),
        );
        expect(rowText, contains(position.profit.toStringAsFixed(2)));
      }

      expect(
        find.text('${account.profit.toStringAsFixed(2)} USD'),
        findsOneWidget,
      );
      for (final value in [
        account.equity,
        account.margin,
        account.freeMargin,
        account.marginLevel,
      ]) {
        expect(find.text(formatAccount(value)), findsOneWidget);
      }
    },
  );

  testWidgets('one-click chevrons and SELL/Buy create matching positions', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        marketCandlesProvider.overrideWith(
          (ref, request) => Stream.value(const <MarketCandle>[]),
        ),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => Stream.value(
            const DemoQuote(
              symbol: 'XAUUSD+',
              name: 'Gold US Dollar',
              bid: 4104.09,
              ask: 4104.22,
              changePercent: .2,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final initialCount = container.read(demoPositionsProvider).length;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    final downChevron = tester.widget<Icon>(
      find.byIcon(CupertinoIcons.chevron_down),
    );
    expect(downChevron.color, Colors.white);
    expect(downChevron.size, 12);

    await tester.tap(find.text('SELL'));
    await tester.pump();
    expect(container.read(demoPositionsProvider), hasLength(initialCount + 1));
    expect(container.read(demoPositionsProvider).first.side, 'SELL');

    await tester.tap(find.text('Buy'));
    await tester.pump();
    final positions = container.read(demoPositionsProvider);
    expect(positions, hasLength(initialCount + 2));
    expect(positions[0].side, 'BUY');
    expect(positions[1].side, 'SELL');
  });
}

final _serverAccountState = ExV2AccountViewState.fromBootstrap(
  ExV2Bootstrap.fromJson(_serverBootstrap),
);

final _serverBootstrap = <String, Object?>{
  'serverTime': '2026-08-14T08:00:00Z',
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
    'updatedAt': '2026-08-14T08:00:00Z',
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
