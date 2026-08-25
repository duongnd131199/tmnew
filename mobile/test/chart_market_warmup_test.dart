import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

void main() {
  test('production warmup loads every chart timeframe once', () async {
    final requests = <MarketDataRequest>[];
    final container = ProviderContainer(
      overrides: [
        marketApiConfigProvider.overrideWithValue(
          const MarketApiConfig(baseUrl: 'https://market.example.com'),
        ),
        marketCandlesProvider.overrideWith((ref, request) {
          requests.add(request);
          return Stream.value([
            MarketCandle(
              time: DateTime.utc(2026, 8, 14),
              open: 4400,
              high: 4402,
              low: 4398,
              close: 4401,
            ),
          ]);
        }),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      chartMarketWarmupProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await container.read(chartMarketWarmupProvider.future);

    expect(requests, const [
      MarketDataRequest('XAUUSD+', 'M1'),
      MarketDataRequest('XAUUSD+', 'M5'),
      MarketDataRequest('XAUUSD+', 'M15'),
      MarketDataRequest('XAUUSD+', 'M30'),
      MarketDataRequest('XAUUSD+', 'H1'),
      MarketDataRequest('XAUUSD+', 'H4'),
      MarketDataRequest('XAUUSD+', 'D1'),
      MarketDataRequest('XAUUSD+', 'W1'),
      MarketDataRequest('XAUUSD+', 'MN'),
    ]);
  });

  test(
    'active-symbol warmup requests every timeframe for that symbol',
    () async {
      final requests = <MarketDataRequest>[];
      final container = ProviderContainer(
        overrides: [
          marketApiConfigProvider.overrideWithValue(
            const MarketApiConfig(baseUrl: 'https://market.example.com'),
          ),
          marketCandlesProvider.overrideWith((ref, request) {
            requests.add(request);
            return Stream.value([
              MarketCandle(
                time: DateTime.utc(2026, 8, 24),
                open: 65100,
                high: 65200,
                low: 65000,
                close: 65150,
              ),
            ]);
          }),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        chartSymbolMarketWarmupProvider('BTCUSD'),
        (previous, next) {},
      );
      addTearDown(subscription.close);
      await container.read(chartSymbolMarketWarmupProvider('BTCUSD').future);

      expect(requests, const [
        MarketDataRequest('BTCUSD', 'M1'),
        MarketDataRequest('BTCUSD', 'M5'),
        MarketDataRequest('BTCUSD', 'M15'),
        MarketDataRequest('BTCUSD', 'M30'),
        MarketDataRequest('BTCUSD', 'H1'),
        MarketDataRequest('BTCUSD', 'H4'),
        MarketDataRequest('BTCUSD', 'D1'),
        MarketDataRequest('BTCUSD', 'W1'),
        MarketDataRequest('BTCUSD', 'MN'),
      ]);
    },
  );

  testWidgets('Chart starts warmup for the symbol being displayed', (
    tester,
  ) async {
    final warmedSymbols = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chartSymbolMarketWarmupProvider.overrideWith((ref, symbol) async {
            warmedSymbols.add(symbol);
          }),
          marketCandlesProvider.overrideWith(
            (ref, request) => const Stream<List<MarketCandle>>.empty(),
          ),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'BTCUSD', initialTimeframe: 'M30'),
        ),
      ),
    );
    await tester.pump();

    expect(warmedSymbols, const ['BTCUSD']);
  });

  testWidgets('warmup completion does not rebuild Chart', (tester) async {
    final warmup = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chartSymbolMarketWarmupProvider.overrideWith(
            (ref, symbol) => warmup.future,
          ),
          marketCandlesProvider.overrideWith(
            (ref, request) => const Stream<List<MarketCandle>>.empty(),
          ),
          demoQuoteProvider.overrideWith(
            (ref, symbol) => const Stream<DemoQuote>.empty(),
          ),
          realtimeCandleProvider.overrideWith(
            (ref, request) => const Stream<MarketCandle>.empty(),
          ),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'BTCUSD', initialTimeframe: 'M30'),
        ),
      ),
    );
    await tester.pump();

    final chartElement = tester.element(find.byType(ChartScreen));
    var chartBuilds = 0;
    final previousRebuildHook = debugOnRebuildDirtyWidget;
    addTearDown(() => debugOnRebuildDirtyWidget = previousRebuildHook);
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousRebuildHook?.call(element, builtOnce);
      if (identical(element, chartElement)) chartBuilds++;
    };

    warmup.complete();
    await tester.pump();
    await tester.pump();
    debugOnRebuildDirtyWidget = previousRebuildHook;

    expect(chartBuilds, 0);
  });

  testWidgets('removing Chart releases every active-symbol history stream', (
    tester,
  ) async {
    final showChart = ValueNotifier(true);
    addTearDown(showChart.dispose);
    final histories = <String, StreamController<List<MarketCandle>>>{
      for (final timeframe in const [
        'M1',
        'M5',
        'M15',
        'M30',
        'H1',
        'H4',
        'D1',
        'W1',
        'MN',
      ])
        timeframe: StreamController<List<MarketCandle>>(sync: true),
    };
    addTearDown(() async {
      for (final history in histories.values) {
        await history.close();
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketApiConfigProvider.overrideWithValue(
            const MarketApiConfig(baseUrl: 'https://market.example.com'),
          ),
          marketCandlesProvider.overrideWith(
            (ref, request) => histories[request.timeframe]!.stream,
          ),
          demoQuoteProvider.overrideWith(
            (ref, symbol) => Stream.value(
              const DemoQuote(
                symbol: 'BTCUSD',
                name: 'Bitcoin',
                bid: 65100,
                ask: 65101,
                changePercent: .1,
              ),
            ),
          ),
          realtimeCandleProvider.overrideWith(
            (ref, request) => const Stream<MarketCandle>.empty(),
          ),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: showChart,
            builder: (context, visible, child) => visible
                ? const ChartScreen(symbol: 'BTCUSD', initialTimeframe: 'M30')
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(histories.values.every((history) => history.hasListener), isTrue);

    showChart.value = false;
    await tester.pump();
    await tester.pump();

    expect(histories.values.every((history) => !history.hasListener), isTrue);
  });

  test('disabled market API skips chart warmup', () async {
    final requests = <MarketDataRequest>[];
    final container = ProviderContainer(
      overrides: [
        marketApiConfigProvider.overrideWithValue(const MarketApiConfig()),
        marketCandlesProvider.overrideWith((ref, request) {
          requests.add(request);
          return const Stream<List<MarketCandle>>.empty();
        }),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      chartMarketWarmupProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await container.read(chartMarketWarmupProvider.future);

    expect(requests, isEmpty);
  });

  testWidgets('AppShell starts warmup without blocking its active branch', (
    tester,
  ) async {
    var starts = 0;
    final warmup = Completer<void>();
    final pendingWarmup = ProviderContainer(
      overrides: [
        chartMarketWarmupProvider.overrideWith((ref) async {
          starts++;
          await warmup.future;
        }),
      ],
    );
    addTearDown(pendingWarmup.dispose);
    final router = GoRouter(
      initialLocation: '/first',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
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
      UncontrolledProviderScope(
        container: pendingWarmup,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(starts, 1);
    expect(find.text('FIRST BRANCH'), findsOneWidget);

    final shellElement = tester.element(find.byType(AppShell));
    var shellBuilds = 0;
    final previousRebuildHook = debugOnRebuildDirtyWidget;
    addTearDown(() => debugOnRebuildDirtyWidget = previousRebuildHook);
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousRebuildHook?.call(element, builtOnce);
      if (identical(element, shellElement)) shellBuilds++;
    };

    warmup.complete();
    await tester.pump();
    await tester.pump();
    debugOnRebuildDirtyWidget = previousRebuildHook;

    expect(shellBuilds, 0);
  });

  testWidgets('Chart consumes H4 history completed by warmup before mount', (
    tester,
  ) async {
    final history = List<MarketCandle>.generate(48, (index) {
      final open = 4500 + index.toDouble();
      return MarketCandle(
        time: DateTime.utc(2026, 8, 16).add(Duration(hours: index * 4)),
        open: open,
        high: open + 8,
        low: open - 8,
        close: open + 2,
      );
    });
    const liveQuote = DemoQuote(
      symbol: 'XAUUSD+',
      name: 'Gold US Dollar',
      bid: 4637.22,
      ask: 4637.48,
      changePercent: 1,
    );
    final container = ProviderContainer(
      overrides: [
        marketApiConfigProvider.overrideWithValue(
          const MarketApiConfig(baseUrl: 'https://market.example.com'),
        ),
        marketCandlesProvider.overrideWith(
          (ref, request) => Stream.value(history),
        ),
        marketClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 8, 23, 21),
        ),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => Stream.value(liveQuote),
        ),
        realtimeCandleProvider.overrideWith(
          (ref, request) => const Stream<MarketCandle>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final warmupSubscription = container.listen(
      chartMarketWarmupProvider,
      (previous, next) {},
    );
    addTearDown(warmupSubscription.close);
    await container.read(chartMarketWarmupProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    final rendered = List<MarketCandle>.from(
      painter.debugResolvedCandles as Iterable,
    );

    expect(rendered, hasLength(history.length));
    expect(rendered.first.time, DateTime.utc(2026, 8, 16));
    expect(rendered.last.time, DateTime.utc(2026, 8, 23, 20));
  });
}
