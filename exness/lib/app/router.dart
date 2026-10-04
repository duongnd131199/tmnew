import 'package:go_router/go_router.dart';

import '../features/account/presentation/account_screen.dart';
import '../features/chart/presentation/chart_screen.dart';
import '../features/insights/presentation/insights_screen.dart';
import '../features/performance/presentation/performance_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/trading/presentation/trading_screen.dart';
import 'app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/account',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/account',
              builder: (context, state) => const AccountScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/trading',
              builder: (context, state) => const TradingScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/insights',
              builder: (context, state) => const InsightsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/performance',
              builder: (context, state) => const PerformanceScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/chart/:symbol',
      builder: (context, state) =>
          ChartScreen(symbol: state.pathParameters['symbol'] ?? 'XAUUSD+'),
    ),
  ],
);
