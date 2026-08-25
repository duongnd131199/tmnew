import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/authentication/presentation/screens/login_screen.dart';
import 'package:trading_mobile/features/authentication/presentation/screens/register_screen.dart';
import 'package:trading_mobile/features/authentication/presentation/screens/splash_screen.dart';
import 'package:trading_mobile/features/account_link/presentation/screens/broker_list_screen.dart';
import 'package:trading_mobile/features/account_link/presentation/screens/existing_account_login_screen.dart';
import 'package:trading_mobile/features/account_link/presentation/screens/trading_server_screen.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_indicators_screen.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_objects_screen.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_detail_screen.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/symbol_search_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/symbol_edit_screen.dart';
import 'package:trading_mobile/features/messages/presentation/screens/messages_screen.dart';
import 'package:trading_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:trading_mobile/features/order/presentation/screens/new_order_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/account_detail_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/settings_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/section_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/position_detail_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/features/wallet/presentation/screens/wallet_request_screen.dart';
import 'package:trading_mobile/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/accounts/add',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          _iosSlidePage(state, const BrokerListScreen()),
    ),
    GoRoute(
      path: '/accounts/add/:brokerId',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _iosSlidePage(
        state,
        ExistingAccountLoginScreen(
          brokerId: state.pathParameters['brokerId']!,
          initialLogin: state.uri.queryParameters['login'],
          initialServerId: state.uri.queryParameters['serverId'],
        ),
      ),
    ),
    GoRoute(
      path: '/accounts/add/:brokerId/servers',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _iosSlidePage(
        state,
        TradingServerScreen(brokerId: state.pathParameters['brokerId']!),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/market',
              builder: (context, state) => const MarketWatchScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const SymbolEditScreen(),
                ),
                GoRoute(
                  path: 'search',
                  builder: (context, state) => const SymbolSearchScreen(),
                ),
                GoRoute(
                  path: 'columns',
                  builder: (context, state) => const MarketColumnsScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chart',
              builder: (context, state) {
                final symbol = state.uri.queryParameters['symbol'] ?? 'XAUUSD+';
                final timeframe =
                    state.uri.queryParameters['timeframe'] ?? 'H4';
                return ChartScreen(
                  key: ValueKey('chart-route-$symbol-$timeframe'),
                  symbol: symbol,
                  initialTimeframe: timeframe,
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/trade',
              builder: (context, state) => const TradeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
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
      path: '/chart-indicators',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => ChartIndicatorsScreen(
        symbol: state.uri.queryParameters['symbol'] ?? 'EURUSD',
        timeframe: state.uri.queryParameters['timeframe'] ?? 'M15',
      ),
    ),
    GoRoute(
      path: '/chart-objects',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => ChartObjectsScreen(
        symbol: state.uri.queryParameters['symbol'] ?? 'XAUUSD',
        timeframe: state.uri.queryParameters['timeframe'] ?? 'M1',
      ),
    ),
    GoRoute(
      path: '/symbols',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => SymbolSearchScreen(
        selectForChart: state.uri.queryParameters['mode'] == 'chart',
        chartTimeframe: state.uri.queryParameters['timeframe'],
      ),
    ),
    GoRoute(
      path: '/symbols/edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SymbolEditScreen(),
    ),
    GoRoute(
      path: '/order',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        opaque: state.uri.queryParameters['source'] == 'trade-add',
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 210),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    ),
                  ),
              child: child,
            ),
        child: NewOrderScreen(
          symbol: state.uri.queryParameters['symbol'] ?? 'XAUUSD+',
          initialSide: state.uri.queryParameters['side'] ?? 'buy',
          closePositionId: state.uri.queryParameters['positionId'],
          tradeAddReferenceLayout:
              state.uri.queryParameters['source'] == 'trade-add',
        ),
      ),
    ),
    GoRoute(
      path: '/position/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          PositionDetailScreen(positionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/history/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          HistoryDetailScreen(dealId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/wallet',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WalletScreen(),
    ),
    GoRoute(
      path: '/deposit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WalletRequestScreen(isDeposit: true),
    ),
    GoRoute(
      path: '/withdraw',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WalletRequestScreen(isDeposit: false),
    ),
    GoRoute(
      path: '/section',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _iosSlidePage(
        state,
        SectionScreen(title: state.uri.queryParameters['title'] ?? 'Thông tin'),
      ),
    ),
    GoRoute(
      path: '/profile',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          _iosSlidePage(state, const ProfileScreen()),
    ),
    GoRoute(
      path: '/account-detail',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          _iosSlidePage(state, const AccountDetailScreen()),
    ),
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/messages',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MessagesScreen(),
    ),
  ],
);

CustomTransitionPage<void> _iosSlidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 210),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                ),
              ),
          child: child,
        ),
    child: child,
  );
}
