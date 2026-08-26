import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/features/chart/application/chart_timeframe_session.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/navigation/chart_navigation.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_price_viewport.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  test('all chart entry points share the same symbol timeframe defaults', () {
    expect(
      chartLocationForSymbol('BTCUSD'),
      '/chart?symbol=BTCUSD&timeframe=H1',
    );
    expect(
      chartLocationForSymbol('XAUUSD+'),
      '/chart?symbol=XAUUSD%2B&timeframe=H4',
    );
    expect(
      chartLocationForSymbol('EURUSD'),
      '/chart?symbol=EURUSD&timeframe=H4',
    );
  });

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
        marketCandlesProvider.overrideWith(
          (ref, request) => const Stream<List<MarketCandle>>.empty(),
        ),
      ],
    );
  }

  testWidgets('Market displays XAUUSD while routing canonical XAUUSD+ H4', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = createStableContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/market',
      routes: [
        GoRoute(
          path: '/market',
          builder: (context, state) => const MarketWatchScreen(),
        ),
        GoRoute(
          path: '/chart',
          builder: (context, state) => Scaffold(
            body: Text(
              'CHART ${state.uri.queryParameters['symbol']} '
              '${state.uri.queryParameters['timeframe']}',
            ),
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

    expect(find.text('XAUUSD'), findsOneWidget);
    expect(find.text('XAUUSD+'), findsNothing);
    await tester.tap(find.text('XAUUSD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bieu do'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/chart');
    expect(router.state.uri.queryParameters['symbol'], 'XAUUSD+');
    expect(router.state.uri.queryParameters['timeframe'], 'H4');
    expect(find.text('CHART XAUUSD+ H4'), findsOneWidget);

    router.go('/market');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('market-symbol-BTCUSD')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bieu do'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/chart');
    expect(router.state.uri.queryParameters['symbol'], 'BTCUSD');
    expect(router.state.uri.queryParameters['timeframe'], 'H1');
    expect(find.text('CHART BTCUSD H1'), findsOneWidget);
  });

  testWidgets('app router recreates chart state for an explicit route query', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = createStableContainer();
    addTearDown(container.dispose);
    addTearDown(() => appRouter.go('/'));

    appRouter.go('/chart?symbol=XAUUSD%2B&timeframe=H4');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();

    var chart = tester.widget<ChartScreen>(find.byType(ChartScreen));
    expect(chart.symbol, 'XAUUSD+');
    expect(chart.initialTimeframe, 'H4');

    appRouter.go('/chart?symbol=BTCUSD&timeframe=H1');
    await tester.pumpAndSettle();

    chart = tester.widget<ChartScreen>(find.byType(ChartScreen));
    expect(chart.key, const ValueKey('chart-route-BTCUSD-H1'));
    expect(chart.symbol, 'BTCUSD');
    expect(chart.initialTimeframe, 'H1');
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('BTCUSD') &&
            widget.text.toPlainText().contains('H1'),
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets(
    'Prices reopens a symbol with its last selected chart timeframe',
    (tester) async {
      useVideoViewport(tester);
      final container = createStableContainer();
      addTearDown(container.dispose);
      addTearDown(() => appRouter.go('/'));

      appRouter.go('/market');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('XAUUSD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bieu do').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('H4').first);
      await tester.pump();
      await tester.tap(find.text('M30').first);
      await tester.pump();

      final selectedPainter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter
              as dynamic;
      expect(selectedPainter.timeframe, 'M30');

      await tester.tap(find.text('Gia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('XAUUSD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bieu do').last);
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.queryParameters['timeframe'], 'M30');
      final reopenedChart = tester.widget<ChartScreen>(
        find.byType(ChartScreen),
      );
      expect(reopenedChart.initialTimeframe, 'M30');
      final reopenedPainter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter
              as dynamic;
      expect(reopenedPainter.timeframe, 'M30');
    },
  );

  testWidgets(
    'bottom chart tab preserves the chart opened from Prices on return and reselect',
    (tester) async {
      useVideoViewport(tester);
      final container = createStableContainer();
      addTearDown(container.dispose);
      addTearDown(() => appRouter.go('/'));

      appRouter.go('/market');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('market-symbol-BTCUSD')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bieu do').last);
      await tester.pumpAndSettle();

      var chart = tester.widget<ChartScreen>(find.byType(ChartScreen));
      expect(chart.symbol, 'BTCUSD');
      expect(chart.initialTimeframe, 'H1');
      final chartState = tester.state(find.byType(ChartScreen));

      await tester.tap(find.text('H1').first);
      await tester.pump();
      await tester.tap(find.text('H4').first);
      await tester.pump();
      final chartCanvas = find.byKey(const Key('chart-gesture-area'));
      final center = tester.getCenter(chartCanvas);
      final first = await tester.startGesture(
        center - const Offset(100, 0),
        pointer: 301,
      );
      final second = await tester.startGesture(
        center + const Offset(100, 0),
        pointer: 302,
      );
      await tester.pump();
      await first.moveTo(center - const Offset(25, 0));
      await second.moveTo(center + const Offset(25, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pump();
      await tester.drag(chartCanvas, const Offset(60, 0));
      await tester.pumpAndSettle();

      dynamic painterBefore = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painterBefore.timeframe, 'H4');
      expect(painterBefore.viewport, isA<ChartViewport>());
      expect(painterBefore.viewport, isNot(const ChartViewport()));
      final viewportBefore = painterBefore.viewport;
      final minBefore = painterBefore.chartMinPrice;
      final maxBefore = painterBefore.chartMaxPrice;

      await tester.tap(find.text('Gia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bieu do'));
      await tester.pumpAndSettle();

      chart = tester.widget<ChartScreen>(find.byType(ChartScreen));
      expect(chart.symbol, 'BTCUSD');
      expect(chart.initialTimeframe, 'H1');
      expect(tester.state(find.byType(ChartScreen)), same(chartState));
      painterBefore = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painterBefore.timeframe, 'H4');
      expect(painterBefore.viewport, viewportBefore);
      expect(painterBefore.chartMinPrice, minBefore);
      expect(painterBefore.chartMaxPrice, maxBefore);

      await tester.tap(find.text('Bieu do'));
      await tester.pumpAndSettle();

      chart = tester.widget<ChartScreen>(find.byType(ChartScreen));
      expect(chart.symbol, 'BTCUSD');
      expect(chart.initialTimeframe, 'H1');
      expect(tester.state(find.byType(ChartScreen)), same(chartState));
      final painterAfterReselect =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter
              as dynamic;
      expect(painterAfterReselect.timeframe, 'H4');
      expect(painterAfterReselect.viewport, viewportBefore);
    },
  );

  testWidgets('chart remount restores its selected view from the session', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = createStableContainer();
    addTearDown(container.dispose);

    Widget app(Widget home) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    );

    await tester.pumpWidget(
      app(const ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4')),
    );
    await tester.pump();
    await tester.tap(find.text('H4').first);
    await tester.pump();
    await tester.tap(find.text('M30').first);
    await tester.pump();

    final chartCanvas = find.byKey(const Key('chart-gesture-area'));
    final center = tester.getCenter(chartCanvas);
    final first = await tester.startGesture(
      center - const Offset(100, 0),
      pointer: 401,
    );
    final second = await tester.startGesture(
      center + const Offset(100, 0),
      pointer: 402,
    );
    await tester.pump();
    await first.moveTo(center - const Offset(25, 0));
    await second.moveTo(center + const Offset(25, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    final before =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter
            as dynamic;
    final retainedViewport = before.viewport as ChartViewport;
    expect(before.timeframe, 'M30');
    expect(retainedViewport, isNot(const ChartViewport()));

    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pump();
    final rememberedTimeframe = container
        .read(chartTimeframeSessionProvider.notifier)
        .timeframeFor('XAUUSD+');
    await tester.pumpWidget(
      app(
        ChartScreen(symbol: 'XAUUSD+', initialTimeframe: rememberedTimeframe),
      ),
    );
    await tester.pump();

    final restored =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter
            as dynamic;
    expect(restored.timeframe, 'M30');
    expect(restored.viewport, retainedViewport);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('process restart restores the hydrated chart route and view', (
    tester,
  ) async {
    useVideoViewport(tester);
    const retainedViewport = ChartViewport(
      barSpacing: 9,
      scrollOffset: 36,
      rightPadding: 8,
    );
    final seed = ChartViewSessionState(
      activeSymbol: 'BTCUSD',
      views: const {
        'BTCUSD': ChartViewSnapshot(
          symbol: 'BTCUSD',
          timeframe: 'M30',
          viewport: retainedViewport,
          priceViewport: ChartPriceViewport.auto(),
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        chartViewSessionSeedProvider.overrideWithValue(seed),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
        marketCandlesProvider.overrideWith(
          (ref, request) => const Stream<List<MarketCandle>>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => appRouter.go('/'));
    appRouter.go('/chart');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<ChartScreen>(find.byType(ChartScreen));
    expect(chart.symbol, 'BTCUSD');
    expect(chart.initialTimeframe, 'M30');
    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter
            as dynamic;
    expect(painter.timeframe, 'M30');
    expect(painter.viewport, retainedViewport);
  });

  testWidgets('chart remount restores its manual price scale', (tester) async {
    useVideoViewport(tester);
    final container = createStableContainer();
    addTearDown(container.dispose);

    Widget app(Widget home) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    );

    await tester.pumpWidget(
      app(const ChartScreen(symbol: 'XAUEUR', initialTimeframe: 'M1')),
    );
    await tester.pump();
    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    final canvasTopLeft = tester.getTopLeft(
      find.byKey(const Key('chart-canvas')),
    );
    final axisPoint = canvasTopLeft + (painter.priceAxisRect as Rect).center;

    await tester.dragFrom(axisPoint, const Offset(0, -160));
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    final retainedPriceViewport = painter.priceViewport as ChartPriceViewport;
    expect(retainedPriceViewport.isAuto, isFalse);

    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(
      app(const ChartScreen(symbol: 'XAUEUR', initialTimeframe: 'M1')),
    );
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;

    expect(painter.priceViewport, retainedPriceViewport);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('price-axis reset replaces the persisted manual scale', (
    tester,
  ) async {
    useVideoViewport(tester);
    final seed = ChartViewSessionState(
      activeSymbol: 'XAUEUR',
      views: const {
        'XAUEUR': ChartViewSnapshot(
          symbol: 'XAUEUR',
          timeframe: 'M1',
          viewport: ChartViewport(),
          priceViewport: ChartPriceViewport.manual(
            centerPrice: 4600,
            range: 30,
          ),
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        chartViewSessionSeedProvider.overrideWithValue(seed),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
        marketCandlesProvider.overrideWith(
          (ref, request) => const Stream<List<MarketCandle>>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    Widget app(Widget home) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    );

    await tester.pumpWidget(
      app(const ChartScreen(symbol: 'XAUEUR', initialTimeframe: 'M1')),
    );
    await tester.pump();
    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    final axisPoint =
        tester.getTopLeft(find.byKey(const Key('chart-canvas'))) +
        (painter.priceAxisRect as Rect).center;

    await tester.tapAt(axisPoint);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(axisPoint);
    await tester.pump(const Duration(milliseconds: 350));
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.priceViewport, const ChartPriceViewport.auto());

    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(
      app(const ChartScreen(symbol: 'XAUEUR', initialTimeframe: 'M1')),
    );
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;

    expect(painter.priceViewport, const ChartPriceViewport.auto());
  });

  testWidgets('pausing the app flushes the active chart viewport', (
    tester,
  ) async {
    useVideoViewport(tester);
    final store = _RecordingChartViewSessionStore();
    final container = ProviderContainer(
      overrides: [
        chartViewSessionStoreProvider.overrideWithValue(store),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
        marketCandlesProvider.overrideWith(
          (ref, request) => const Stream<List<MarketCandle>>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();
    final controller = container.read(chartTimeframeSessionProvider.notifier);
    await controller.flush();

    final chartCanvas = find.byKey(const Key('chart-gesture-area'));
    final center = tester.getCenter(chartCanvas);
    final first = await tester.startGesture(
      center - const Offset(100, 0),
      pointer: 501,
    );
    final second = await tester.startGesture(
      center + const Offset(100, 0),
      pointer: 502,
    );
    await tester.pump();
    await first.moveTo(center - const Offset(25, 0));
    await second.moveTo(center + const Offset(25, 0));
    await tester.pump();
    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter
            as dynamic;
    final activeViewport = painter.viewport as ChartViewport;
    expect(activeViewport, isNot(const ChartViewport()));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await controller.flush();

    expect(store.value.viewFor('XAUUSD+')?.viewport, activeViewport);
    await first.up();
    await second.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));
  });
}

final class _RecordingChartViewSessionStore implements ChartViewSessionStore {
  ChartViewSessionState value = ChartViewSessionState.empty;

  @override
  Future<ChartViewSessionState> read() async => value;

  @override
  Future<void> write(ChartViewSessionState value) async {
    this.value = value;
  }
}
