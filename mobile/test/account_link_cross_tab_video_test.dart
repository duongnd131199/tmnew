import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

void main() {
  testWidgets('account generation recreates account-scoped branch state', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2AccountProvider.overrideWithBuild(
          (ref, controller) => ExV2AccountViewState.fromBootstrap(
            ExV2Bootstrap.fromJson(_bootstrap('account-a', 'LOGIN-A')),
          ),
        ),
        chartMarketWarmupProvider.overrideWith((ref) async {}),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/market',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/market',
                  builder: (context, state) => const _AccountScopedProbe(),
                ),
              ],
            ),
          ],
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
    expect(find.text('captured:LOGIN-A'), findsOneWidget);

    container
        .read(exV2AccountProvider.notifier)
        .publishBootstrap(
          ExV2Bootstrap.fromJson(_bootstrap('account-b', 'LOGIN-B')),
        );
    await tester.pump();

    expect(find.text('captured:LOGIN-A'), findsNothing);
    expect(find.byKey(const Key('account-scope-resetting')), findsOneWidget);
    await tester.pump();
    expect(find.text('captured:LOGIN-B'), findsOneWidget);
  });

  testWidgets('B bootstrap removes A data from every account-scoped adapter', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2AccountProvider.overrideWithBuild(
          (ref, controller) =>
              ExV2AccountViewState.fromBootstrap(
                ExV2Bootstrap.fromJson(_bootstrap('account-a', 'LOGIN-A')),
              ).copyWith(
                historyPositions: const [
                  DemoHistoryPosition(
                    id: 'history-a',
                    title: 'A-HISTORY',
                    profit: 1,
                    time: '2026.08.16 08:00:00',
                  ),
                ],
                notifications: const [
                  {'id': 'notification-a'},
                ],
                settings: const {'scope': 'A'},
              ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: _CrossTabDataProbe()),
      ),
    );
    await tester.pump();
    expect(find.text('account:LOGIN-A'), findsOneWidget);
    expect(find.text('positions:position-a'), findsOneWidget);
    expect(find.text('history:history-a'), findsOneWidget);
    expect(find.text('wallet:10.0'), findsOneWidget);
    expect(find.text('notifications:notification-a'), findsOneWidget);
    expect(find.text('settings:A'), findsOneWidget);

    container
        .read(exV2AccountProvider.notifier)
        .publishBootstrap(
          ExV2Bootstrap.fromJson(_bootstrap('account-b', 'LOGIN-B')),
        );
    await tester.pump();

    for (final oldValue in const [
      'account:LOGIN-A',
      'positions:position-a',
      'history:history-a',
      'wallet:10.0',
      'notifications:notification-a',
      'settings:A',
    ]) {
      expect(find.text(oldValue), findsNothing, reason: oldValue);
    }
    expect(find.text('account:LOGIN-B'), findsOneWidget);
    expect(find.text('positions:position-b'), findsOneWidget);
    expect(find.text('history:'), findsOneWidget);
    expect(find.text('wallet:20.0'), findsOneWidget);
    expect(find.text('notifications:'), findsOneWidget);
    expect(find.text('settings:'), findsOneWidget);
  });
}

class _CrossTabDataProbe extends ConsumerWidget {
  const _CrossTabDataProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exV2AccountProvider).requireValue!;
    final positions = ref.watch(demoPositionsProvider);
    final history = ref.watch(demoHistoryPositionsProvider);
    final wallet = ref.watch(exV2WalletViewProvider).requireValue;
    final notifications = ref.watch(exV2NotificationsProvider).requireValue;
    return Scaffold(
      body: Column(
        children: [
          Text('account:${state.accountCode}'),
          Text('positions:${positions.map((item) => item.id).join(',')}'),
          Text('history:${history.map((item) => item.id).join(',')}'),
          Text('wallet:${wallet.wallet.totalBalance}'),
          Text(
            'notifications:'
            '${notifications.map((item) => item['id']).join(',')}',
          ),
          Text('settings:${state.settings['scope'] ?? ''}'),
        ],
      ),
    );
  }
}

class _AccountScopedProbe extends ConsumerStatefulWidget {
  const _AccountScopedProbe();

  @override
  ConsumerState<_AccountScopedProbe> createState() =>
      _AccountScopedProbeState();
}

class _AccountScopedProbeState extends ConsumerState<_AccountScopedProbe> {
  String? _captured;

  @override
  Widget build(BuildContext context) {
    _captured ??= ref
        .read(exV2AccountProvider)
        .value
        ?.bootstrap
        .account
        .accountCode;
    return Scaffold(body: Text('captured:$_captured'));
  }
}

Map<String, Object?> _bootstrap(String id, String code) => {
  'serverTime': '2026-08-16T08:00:00Z',
  'version': id == 'account-a' ? 1 : 2,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': id,
    'accountCode': code,
    'name': code,
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': id,
    'currency': 'USD',
    'balance': id == 'account-a' ? 100 : 200,
    'equity': id == 'account-a' ? 100 : 200,
    'profit': 0,
    'margin': 0,
    'freeMargin': id == 'account-a' ? 100 : 200,
    'marginLevel': 0,
    'updatedAt': '2026-08-16T08:00:00Z',
  },
  'positions': [
    {
      'id': id == 'account-a' ? 'position-a' : 'position-b',
      'symbol': id == 'account-a' ? 'A-SYMBOL' : 'B-SYMBOL',
      'side': 'BUY',
      'initialVolume': 0.01,
      'remainingVolume': 0.01,
      'entryPrice': id == 'account-a' ? 100 : 200,
      'realizedProfit': 0,
      'status': 'open',
      'createdAt': '2026-08-16T08:00:00Z',
    },
  ],
  'pendingOrders': <Object?>[],
  'recentDeals': <Object?>[],
  'wallet': {
    'currency': 'USD',
    'availableBalance': id == 'account-a' ? 10 : 20,
    'lockedBalance': 0,
    'totalBalance': id == 'account-a' ? 10 : 20,
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
