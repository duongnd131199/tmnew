import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/realtime_market_service.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

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

  testWidgets(
    'initial account bootstrap preserves offstage chart timeframe and zoom',
    (tester) async {
      tester.view.physicalSize = const Size(384, 848);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          ...videoReferenceOverrides,
          exV2EnabledProvider.overrideWithValue(false),
          exV2AccountProvider.overrideWithBuild((ref, controller) => null),
          chartMarketWarmupProvider.overrideWith((ref) async {}),
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith(
            (ref, symbol) => const Stream<DemoQuote>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/chart',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
            branches: [
              _branch(
                '/market',
                const Scaffold(body: Text('MARKET')),
                'Market',
              ),
              _branch(
                '/chart',
                const ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
                'Chart',
              ),
              _branch('/trade', const Scaffold(body: Text('TRADE')), 'Trade'),
              _branch(
                '/history',
                const Scaffold(body: Text('HISTORY')),
                'History',
              ),
              _branch(
                '/settings',
                const Scaffold(body: Text('SETTINGS')),
                'Settings',
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

      await tester.tap(find.text('H4').first);
      await tester.pump();
      await tester.tap(find.text('H1').first);
      await tester.pump();

      final chart = find.byKey(const Key('chart-gesture-area'));
      final center = tester.getCenter(chart);
      final firstPointer = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 41,
      );
      final secondPointer = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 42,
      );
      await tester.pump();
      await firstPointer.moveTo(center - const Offset(100, 0));
      await secondPointer.moveTo(center + const Offset(100, 0));
      await tester.pump();
      await firstPointer.up();
      await secondPointer.up();
      await tester.pump();

      var painter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter;
      final retainedViewport = painter.viewport;
      expect(painter.timeframe, 'H1');
      expect(
        retainedViewport.barSpacing,
        isNot(ChartViewport.defaultBarSpacing),
      );

      await tester.tap(find.text('Giao dich'));
      await tester.pumpAndSettle();
      container
          .read(exV2AccountProvider.notifier)
          .publishBootstrap(
            ExV2Bootstrap.fromJson(_bootstrap('account-a', 'LOGIN-A')),
          );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Bieu do'));
      await tester.pumpAndSettle();
      painter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter;
      expect(painter.timeframe, 'H1');
      expect(painter.viewport, retainedViewport);
    },
  );

  testWidgets(
    'UI activation clears A data and retained stacks from every production branch',
    (tester) async {
      tester.view.physicalSize = const Size(384, 848);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adapter = _CrossTabApiAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          chartMarketWarmupProvider.overrideWith((ref) async {}),
          marketConnectionStatusProvider.overrideWith(
            (ref) => Stream.value(MarketConnectionStatus.connected),
          ),
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
                    {'id': 'notification-a', 'scope': 'A'},
                  ],
                  settings: const {'scope': 'A'},
                ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/market',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
            branches: [
              _branch('/market', const MarketWatchScreen(), 'Market'),
              _branch('/chart', const _ChartProbe(), 'Chart'),
              _branch('/trade', const _TradeProbe(), 'Trade'),
              _branch('/history', const _HistoryProbe(), 'History'),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/settings',
                    builder: (context, state) => const _SettingsProbe(),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/account-detail',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const Scaffold(body: Text('DETAIL')),
          ),
          GoRoute(
            path: '/wallet',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const _WalletProbe(),
          ),
          GoRoute(
            path: '/notifications',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const _NotificationsProbe(),
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

      container.read(marketSymbolsProvider.notifier).add('AUDNOK');
      await tester.pump();
      expect(find.text('AUDNOK'), findsOneWidget);

      for (final deepPath in const [
        '/market/deep',
        '/chart/deep',
        '/trade/deep',
        '/history/deep',
      ]) {
        router.go(deepPath);
        await tester.pumpAndSettle();
        expect(find.textContaining('deep:LOGIN-A'), findsOneWidget);
      }
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.text('Settings:A'), findsOneWidget);

      router.push('/profile');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-account-b')));
      await tester.pumpAndSettle();

      expect(adapter.activationCalls, 1);
      expect(router.state.uri.path, '/settings');
      expect(find.text('Settings:B'), findsOneWidget);

      for (final tab in const [
        ('Gia', '/market', 'XAUUSD'),
        ('Bieu do', '/chart', 'Chart:LOGIN-B'),
        ('Giao dich', '/trade', 'Trade:position-b'),
        ('Lich su', '/history', 'History:'),
        ('Cai dat', '/settings', 'Settings:B'),
      ]) {
        await tester.tap(find.text(tab.$1));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, tab.$2, reason: tab.$1);
        expect(find.text(tab.$3), findsOneWidget, reason: tab.$1);
        expect(find.textContaining('deep:LOGIN-A'), findsNothing);
        if (tab.$2 == '/market') {
          expect(find.text('AUDNOK'), findsNothing);
        }
      }

      router.push('/wallet');
      await tester.pumpAndSettle();
      expect(find.text('Wallet:20.0'), findsOneWidget);
      expect(find.text('Wallet:10.0'), findsNothing);
      router.pop();
      await tester.pumpAndSettle();

      router.push('/notifications');
      await tester.pumpAndSettle();
      expect(find.text('Notifications:notification-b'), findsOneWidget);
      expect(find.textContaining('notification-a'), findsNothing);

      final state = container.read(exV2AccountProvider).requireValue!;
      expect(state.bootstrap.account.id, 'account-b');
      expect(state.positions.any((item) => item.id == 'position-a'), isFalse);
      expect(
        state.historyPositions.any((item) => item.id == 'history-a'),
        isFalse,
      );
      expect(state.settings['scope'], 'B');
    },
  );
}

StatefulShellBranch _branch(String path, Widget root, String label) =>
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: path,
          builder: (context, state) => root,
          routes: [
            GoRoute(
              path: 'deep',
              builder: (context, state) => _DeepAccountProbe(label: label),
            ),
          ],
        ),
      ],
    );

class _DeepAccountProbe extends ConsumerStatefulWidget {
  const _DeepAccountProbe({required this.label});

  final String label;

  @override
  ConsumerState<_DeepAccountProbe> createState() => _DeepAccountProbeState();
}

class _DeepAccountProbeState extends ConsumerState<_DeepAccountProbe> {
  late final String _captured = ref
      .read(exV2AccountProvider)
      .requireValue!
      .accountCode;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('${widget.label} deep:$_captured'));
}

class _ChartProbe extends ConsumerWidget {
  const _ChartProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Text(
      'Chart:${ref.watch(exV2AccountProvider).requireValue!.accountCode}',
    ),
  );
}

class _TradeProbe extends ConsumerWidget {
  const _TradeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Text(
      'Trade:${ref.watch(demoPositionsProvider).map((item) => item.id).join(',')}',
    ),
  );
}

class _HistoryProbe extends ConsumerWidget {
  const _HistoryProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Text(
      'History:${ref.watch(demoHistoryPositionsProvider).map((item) => item.id).join(',')}',
    ),
  );
}

class _SettingsProbe extends ConsumerWidget {
  const _SettingsProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Text(
      'Settings:${ref.watch(exV2AccountProvider).requireValue!.settings['scope'] ?? ''}',
    ),
  );
}

class _WalletProbe extends ConsumerWidget {
  const _WalletProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(exV2WalletViewProvider).requireValue;
    return Scaffold(body: Text('Wallet:${wallet.wallet.totalBalance}'));
  }
}

class _NotificationsProbe extends ConsumerWidget {
  const _NotificationsProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(exV2NotificationsProvider).requireValue;
    return Scaffold(
      body: Text(
        'Notifications:${notifications.map((item) => item['id']).join(',')}',
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

final class _CrossTabApiAdapter implements HttpClientAdapter {
  int activationCalls = 0;
  String activeAccountId = 'account-a';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/mobile/accounts')) {
      return _json([_linkedB, _linkedA]);
    }
    if (options.method == 'PUT' &&
        path.endsWith('/mobile/accounts/account-b/activate')) {
      activationCalls += 1;
      activeAccountId = 'account-b';
      return _json({
        'account': {..._linkedB, 'isActive': true},
        'bootstrap': _bootstrap('account-b', 'LOGIN-B'),
      });
    }
    if (path.endsWith('/mobile/bootstrap')) {
      return _json(
        activeAccountId == 'account-a'
            ? _bootstrap('account-a', 'LOGIN-A')
            : _bootstrap('account-b', 'LOGIN-B'),
      );
    }
    if (path.endsWith('/settings')) {
      return _json({'scope': activeAccountId == 'account-a' ? 'A' : 'B'});
    }
    if (path.endsWith('/notifications')) {
      final suffix = activeAccountId == 'account-a' ? 'a' : 'b';
      return _json([
        {'id': 'notification-$suffix', 'scope': suffix.toUpperCase()},
      ]);
    }
    return _json(<Object?>[]);
  }

  @override
  void close({bool force = false}) {}
}

final class _MemoryTokenStore implements DeviceTokenStore {
  @override
  Future<void> delete() async {}

  @override
  Future<String?> read() async => 'device-token';

  @override
  Future<void> write(String token) async {}
}

ResponseBody _json(Object? value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _linkedA = <String, Object?>{
  'id': 'account-a',
  'brokerId': 'broker-a',
  'brokerName': 'Broker A',
  'serverId': 'server-a',
  'serverName': 'BrokerA-MT5',
  'login': 'LOGIN-A',
  'isActive': true,
  'displayName': 'Account A',
  'currency': 'USD',
  'status': 'active',
};

const _linkedB = <String, Object?>{
  'id': 'account-b',
  'brokerId': 'broker-b',
  'brokerName': 'Broker B',
  'serverId': 'server-b',
  'serverName': 'BrokerB-MT5',
  'login': 'LOGIN-B',
  'isActive': false,
  'displayName': 'Account B',
  'currency': 'USD',
  'status': 'active',
};

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
