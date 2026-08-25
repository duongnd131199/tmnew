import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_hit_targets.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_render_snapshot.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/chart/presentation/theme/chart_reference_theme.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

void main() {
  const request = MarketDataRequest('XAUUSD+', 'M5');

  test('120 unchanged in-bucket prices emit no render state or revision', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var notifications = 0;
    final subscription = container.listen(
      liveMarketCandlesProvider(request),
      (previous, next) => notifications++,
    );
    addTearDown(subscription.close);
    final notifier = container.read(
      liveMarketCandlesProvider(request).notifier,
    );
    notifier.seedHistory(_history());
    notifier.applyTick(
      price: 100.5,
      receivedAt: DateTime.utc(2026, 8, 23, 10, 1),
    );
    final baseline = container.read(liveMarketCandlesProvider(request));
    notifications = 0;

    for (var index = 0; index < 120; index++) {
      notifier.applyTick(
        price: 100.5,
        receivedAt: DateTime.utc(2026, 8, 23, 10, 1, 1, index),
      );
    }

    final current = container.read(liveMarketCandlesProvider(request));
    printOnFailure(
      '120 unchanged ticks: provider notifications=$notifications',
    );
    expect(notifications, 0);
    expect(identical(current, baseline), isTrue);
    expect(current.liveCandleRevision, baseline.liveCandleRevision);
    expect(current.historyRevision, baseline.historyRevision);
    expect(identical(current.history, baseline.history), true);
  });

  test(
    '120 changing in-bucket prices retain history identity and replace only the active candle',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var notifications = 0;
      final subscription = container.listen(
        liveMarketCandlesProvider(request),
        (previous, next) => notifications++,
      );
      addTearDown(subscription.close);
      final notifier = container.read(
        liveMarketCandlesProvider(request).notifier,
      );
      notifier.seedHistory(_history());
      notifier.applyTick(
        price: 100.5,
        receivedAt: DateTime.utc(2026, 8, 23, 10, 1),
      );
      final baseline = container.read(liveMarketCandlesProvider(request));
      notifications = 0;

      for (var index = 0; index < 120; index++) {
        notifier.applyTick(
          price: 100.51 + index / 100,
          receivedAt: DateTime.utc(
            2026,
            8,
            23,
            10,
            1,
          ).add(Duration(seconds: index + 1)),
        );
      }

      final current = container.read(liveMarketCandlesProvider(request));
      printOnFailure(
        '120 changing ticks: provider notifications=$notifications',
      );
      expect(notifications, 120);
      expect(identical(current.history, baseline.history), isTrue);
      expect(current.historyRevision, baseline.historyRevision);
      expect(current.liveCandleRevision, baseline.liveCandleRevision + 120);
      expect(current.candles, hasLength(baseline.candles.length));
      for (var index = 0; index < current.candles.length - 1; index++) {
        expect(
          identical(current.candles[index], baseline.candles[index]),
          isTrue,
          reason: 'settled candle $index must retain object identity',
        );
      }
      expect(identical(current.candles.last, baseline.candles.last), isFalse);
      expect(current.candles.last.close, closeTo(101.70, .0000001));
    },
  );

  test('120 changed ticks do not enumerate the resolved history series', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      liveMarketCandlesProvider(request).notifier,
    );
    notifier.seedHistory(_history());
    notifier.applyTick(
      price: 100.5,
      receivedAt: DateTime.utc(2026, 8, 23, 10, 1),
    );
    var state = container.read(liveMarketCandlesProvider(request));
    var fullSeriesIterations = 0;
    var snapshot = ChartRenderSnapshot.evolve(
      history: state.history,
      liveTail: state.liveTail,
      resolvedCandles: _IterationCountingCandleList(
        state.candles,
        () => fullSeriesIterations++,
      ),
      historyRevision: state.historyRevision,
      liveCandleRevision: state.liveCandleRevision,
      viewport: const ChartViewport(),
      overlayValues: const <Object?>[],
      theme: ChartReferenceTheme.light,
    );
    fullSeriesIterations = 0;
    ChartRenderSnapshot.debugResetFullSeriesWork();
    final settledPrefix = snapshot.history;
    final resolvedPrefix = snapshot.resolvedHistory;

    for (var index = 0; index < 120; index++) {
      notifier.applyTick(
        price: 100.51 + index / 100,
        receivedAt: DateTime.utc(
          2026,
          8,
          23,
          10,
          1,
        ).add(Duration(seconds: index + 1)),
      );
      state = container.read(liveMarketCandlesProvider(request));
      snapshot = ChartRenderSnapshot.evolve(
        previous: snapshot,
        history: state.history,
        liveTail: state.liveTail,
        resolvedCandles: _IterationCountingCandleList(
          state.candles,
          () => fullSeriesIterations++,
        ),
        historyRevision: state.historyRevision,
        liveCandleRevision: state.liveCandleRevision,
        viewport: const ChartViewport(),
        overlayValues: const <Object?>[],
        theme: ChartReferenceTheme.light,
      );
    }

    expect(fullSeriesIterations, 0);
    expect(ChartRenderSnapshot.debugFullHistoryResolutionCount, 0);
    expect(ChartRenderSnapshot.debugResolvedHistoryCopyCount, 0);
    expect(identical(snapshot.history, settledPrefix), isTrue);
    expect(identical(snapshot.resolvedHistory, resolvedPrefix), isTrue);
    for (var index = 0; index < resolvedPrefix.length; index++) {
      expect(
        identical(snapshot.resolvedHistory[index], resolvedPrefix[index]),
        isTrue,
      );
    }
    expect(snapshot.resolvedCandles.last.close, closeTo(101.70, .0000001));
  });

  for (final correction in <({String name, int index, MarketCandle value})>[
    (
      name: 'first OHLC',
      index: 0,
      value: _copyCandle(_history()[0], open: 97.25),
    ),
    (
      name: 'interior timestamp',
      index: 1,
      value: _copyCandle(_history()[1], time: DateTime.utc(2026, 8, 23, 9, 56)),
    ),
    (
      name: 'last volume',
      index: 2,
      value: _copyCandle(_history()[2], volume: 99),
    ),
  ]) {
    test(
      'history ${correction.name} correction advances semantic revision',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(
          liveMarketCandlesProvider(request).notifier,
        );
        final history = _history();
        notifier.seedHistory(history);
        final baseline = container.read(liveMarketCandlesProvider(request));
        final corrected = List<MarketCandle>.of(history);
        corrected[correction.index] = correction.value;

        notifier.seedHistory(corrected);

        final current = container.read(liveMarketCandlesProvider(request));
        expect(current.historyRevision, baseline.historyRevision + 1);
        expect(identical(current.history, baseline.history), isFalse);
        expect(
          current.candles.any(
            (candle) => _sameCandle(candle, correction.value),
          ),
          isTrue,
        );
      },
    );
  }

  test('value-identical history keeps state identity and revisions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      liveMarketCandlesProvider(request).notifier,
    );
    final history = _history();
    notifier.seedHistory(history);
    final baseline = container.read(liveMarketCandlesProvider(request));

    notifier.seedHistory(history.map(_copyCandle).toList());

    final current = container.read(liveMarketCandlesProvider(request));
    expect(identical(current, baseline), isTrue);
    expect(identical(current.history, baseline.history), isTrue);
    expect(current.historyRevision, baseline.historyRevision);
    expect(current.liveCandleRevision, baseline.liveCandleRevision);
  });

  test(
    'render snapshots are defensive and preserve history identity across live revisions',
    () {
      final mutableHistory = _history();
      final mutableLiveTail = <MarketCandle>[
        mutableHistory[1],
        mutableHistory.last,
      ];
      final mutableResolved = List<MarketCandle>.of(mutableHistory);
      final first = ChartRenderSnapshot.evolve(
        history: mutableHistory,
        liveTail: mutableLiveTail,
        resolvedCandles: mutableResolved,
        historyRevision: 3,
        liveCandleRevision: 7,
        viewport: const ChartViewport(),
        overlayValues: const <Object?>['orders:0', 'crosshair:none'],
        theme: ChartReferenceTheme.light,
      );
      mutableHistory.clear();
      mutableLiveTail.clear();
      mutableResolved
        ..clear()
        ..add(_copyCandle(_history().first, close: -1));

      expect(first.history, hasLength(3));
      expect(first.liveTail, hasLength(2));
      expect(first.liveTail.first.close, 100.25);
      expect(first.liveCandle?.close, 100.5);
      expect(first.resolvedCandles, hasLength(3));
      expect(first.resolvedCandles.last.close, 100.5);
      expect(() => first.history.clear(), throwsUnsupportedError);
      expect(() => first.liveTail.clear(), throwsUnsupportedError);
      expect(
        () => first.resolvedCandles.add(first.liveCandle!),
        throwsUnsupportedError,
      );
      for (final series in <List<MarketCandle>>[
        first.liveTail,
        first.resolvedCandles,
      ]) {
        expect(() => series.length = 0, throwsUnsupportedError);
        expect(() => series[0] = _history().first, throwsUnsupportedError);
        expect(
          () => series.insert(0, _history().first),
          throwsUnsupportedError,
        );
        expect(() => series.removeAt(0), throwsUnsupportedError);
        expect(
          () => series.setRange(0, 1, <MarketCandle>[_history().first]),
          throwsUnsupportedError,
        );
        expect(
          () => series.sort((left, right) => left.time.compareTo(right.time)),
          throwsUnsupportedError,
        );
        expect(() => series.shuffle(), throwsUnsupportedError);
        expect(
          () => series.addAll(const <MarketCandle>[]),
          throwsUnsupportedError,
        );
        expect(
          () => series.insertAll(0, const <MarketCandle>[]),
          throwsUnsupportedError,
        );
        expect(
          () => series.removeWhere((candle) => false),
          throwsUnsupportedError,
        );
        expect(
          () => series.retainWhere((candle) => true),
          throwsUnsupportedError,
        );
        expect(() => series.removeRange(0, 0), throwsUnsupportedError);
        expect(
          () => series.replaceRange(0, 0, const <MarketCandle>[]),
          throwsUnsupportedError,
        );
      }

      final nextLive = MarketCandle(
        time: first.liveCandle!.time,
        open: first.liveCandle!.open,
        high: first.liveCandle!.high + 1,
        low: first.liveCandle!.low,
        close: first.liveCandle!.close + 1,
        volume: first.liveCandle!.volume,
      );
      final second = ChartRenderSnapshot.evolve(
        previous: first,
        history: _history(),
        liveTail: <MarketCandle>[nextLive],
        resolvedCandles: <MarketCandle>[..._history().take(2), nextLive],
        historyRevision: 3,
        liveCandleRevision: 8,
        viewport: const ChartViewport(),
        overlayValues: const <Object?>['orders:0', 'crosshair:none'],
        theme: ChartReferenceTheme.light,
      );

      expect(identical(second.history, first.history), isTrue);
      expect(second.historyRevision, 3);
      expect(second.liveCandleRevision, 8);
      expect(second.viewportRevision, first.viewportRevision);
      expect(second.overlaysRevision, first.overlaysRevision);
      expect(second.themeRevision, first.themeRevision);
    },
  );

  test(
    'painter repaint decisions use render revisions instead of list allocation identity',
    () {
      final first = ChartRenderSnapshot.evolve(
        history: _history().take(2).toList(),
        liveTail: <MarketCandle>[_history().last],
        resolvedCandles: _history(),
        historyRevision: 1,
        liveCandleRevision: 1,
        viewport: const ChartViewport(),
        overlayValues: const <Object?>['none'],
        theme: ChartReferenceTheme.light,
      );
      final equalRevisionWithFreshLists = ChartRenderSnapshot.evolve(
        history: _history().take(2).toList(),
        liveTail: <MarketCandle>[_history().last],
        resolvedCandles: _history(),
        historyRevision: 1,
        liveCandleRevision: 1,
        viewport: const ChartViewport(),
        overlayValues: const <Object?>['none'],
        theme: ChartReferenceTheme.light,
      );
      final changedLiveRevision = ChartRenderSnapshot.evolve(
        previous: equalRevisionWithFreshLists,
        history: _history().take(2).toList(),
        liveTail: <MarketCandle>[_history().last],
        resolvedCandles: _history(),
        historyRevision: 1,
        liveCandleRevision: 2,
        viewport: const ChartViewport(),
        overlayValues: const <Object?>['none'],
        theme: ChartReferenceTheme.light,
      );

      final originalPainter = _painterForSnapshot(first);
      expect(
        _painterForSnapshot(
          equalRevisionWithFreshLists,
        ).shouldRepaint(originalPainter),
        isFalse,
      );
      expect(
        _painterForSnapshot(
          changedLiveRevision,
        ).shouldRepaint(_painterForSnapshot(equalRevisionWithFreshLists)),
        isTrue,
      );
      expect(
        _painterForSnapshot(
          equalRevisionWithFreshLists,
          symbol: 'BTCUSD',
        ).shouldRepaint(originalPainter),
        isTrue,
      );
    },
  );

  test(
    'painter constructor consumes an already-resolved snapshot unchanged',
    () {
      final snapshot = ChartRenderSnapshot.evolve(
        history: _history(),
        liveTail: <MarketCandle>[_history().last],
        resolvedCandles: _history(),
        historyRevision: 1,
        liveCandleRevision: 1,
        viewport: const ChartViewport(),
        overlayValues: const <Object?>[],
        theme: ChartReferenceTheme.light,
      );

      final painter = _painterForSnapshot(snapshot, useRealtimeCandles: false);

      expect(identical(painter.snapshot, snapshot), isTrue);
      expect(
        identical(painter.resolvedCandles, snapshot.resolvedCandles),
        isTrue,
      );
      expect(painter.resolvedCandles, hasLength(_history().length));
    },
  );

  testWidgets('identical history refresh performs no chart rebuild or paint', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final histories = StreamController<List<MarketCandle>>(sync: true);
    addTearDown(histories.close);
    final history = _widgetHistory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketApiConfigProvider.overrideWithValue(
            const MarketApiConfig(baseUrl: 'https://market.example.com'),
          ),
          marketCandlesProvider.overrideWith(
            (ref, request) => histories.stream,
          ),
          realtimeCandleProvider.overrideWith(
            (ref, request) => const Stream<MarketCandle>.empty(),
          ),
          demoQuoteProvider.overrideWith(
            (ref, symbol) => Stream.value(
              DemoQuote(
                symbol: 'XAUUSD+',
                name: 'Gold US Dollar',
                bid: history.last.close,
                ask: history.last.close + .2,
                changePercent: 0,
                sourceTimestamp: history.last.time,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M5'),
        ),
      ),
    );
    await tester.pump();
    histories.add(history);
    await tester.pump();
    await tester.pump();

    final chartElement = tester.element(find.byType(ChartScreen));
    final appBarElement = tester.element(find.byType(AppBar));
    final scaffoldElement = tester.element(find.byType(Scaffold).first);
    final canvasRenderObject = tester.renderObject<RenderCustomPaint>(
      find.byKey(const Key('chart-canvas')),
    );
    var chartBuilds = 0;
    var appBarBuilds = 0;
    var scaffoldBuilds = 0;
    var canvasPaints = 0;
    final previousRebuildHook = debugOnRebuildDirtyWidget;
    final previousPaintHook = debugOnProfilePaint;
    addTearDown(() {
      debugOnRebuildDirtyWidget = previousRebuildHook;
      debugOnProfilePaint = previousPaintHook;
    });
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousRebuildHook?.call(element, builtOnce);
      if (identical(element, chartElement)) chartBuilds++;
      if (identical(element, appBarElement)) appBarBuilds++;
      if (identical(element, scaffoldElement)) scaffoldBuilds++;
    };
    debugOnProfilePaint = (renderObject) {
      previousPaintHook?.call(renderObject);
      if (identical(renderObject, canvasRenderObject)) canvasPaints++;
    };

    histories.add(List<MarketCandle>.of(history));
    await tester.pump();
    await tester.pump();
    debugOnRebuildDirtyWidget = previousRebuildHook;
    debugOnProfilePaint = previousPaintHook;

    expect(chartBuilds, 0);
    expect(appBarBuilds, 0);
    expect(scaffoldBuilds, 0);
    expect(canvasPaints, 0);
  });

  testWidgets(
    '120 quote ticks isolate static chrome and paint canvas once per delivered frame',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final quotes = StreamController<DemoQuote>(sync: true);
      addTearDown(quotes.close);
      final history = _widgetHistory();
      final firstTickAt = DateTime.utc(2026, 8, 23, 9, 56);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketApiConfigProvider.overrideWithValue(
              const MarketApiConfig(baseUrl: 'https://market.example.com'),
            ),
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(history),
            ),
            realtimeCandleProvider.overrideWith(
              (ref, request) => const Stream<MarketCandle>.empty(),
            ),
            marketClockProvider.overrideWithValue(() => firstTickAt),
            demoQuoteProvider.overrideWith((ref, symbol) => quotes.stream),
          ],
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M5'),
          ),
        ),
      );
      await tester.pump();
      quotes.add(
        DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: history.last.close,
          ask: history.last.close + .2,
          changePercent: 0,
          sourceTimestamp: firstTickAt,
        ),
      );
      await tester.pump();
      await tester.pump();
      ChartRenderSnapshot.debugResetFullSeriesWork();

      final chartElement = tester.element(find.byType(ChartScreen));
      final appBarElement = tester.element(find.byType(AppBar));
      final scaffoldElement = tester.element(find.byType(Scaffold).first);
      final canvasRenderObject = tester.renderObject<RenderCustomPaint>(
        find.byKey(const Key('chart-canvas')),
      );
      var chartBuilds = 0;
      var appBarBuilds = 0;
      var scaffoldBuilds = 0;
      var canvasBuilds = 0;
      var canvasPaints = 0;
      final previousRebuildHook = debugOnRebuildDirtyWidget;
      final previousPaintHook = debugOnProfilePaint;
      addTearDown(() {
        debugOnRebuildDirtyWidget = previousRebuildHook;
        debugOnProfilePaint = previousPaintHook;
      });
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previousRebuildHook?.call(element, builtOnce);
        if (identical(element, chartElement)) chartBuilds++;
        if (identical(element, appBarElement)) appBarBuilds++;
        if (identical(element, scaffoldElement)) scaffoldBuilds++;
        if (element.widget.key == const Key('chart-canvas')) canvasBuilds++;
      };
      debugOnProfilePaint = (renderObject) {
        previousPaintHook?.call(renderObject);
        if (identical(renderObject, canvasRenderObject)) canvasPaints++;
      };

      const deliveredFrames = 12;
      const ticksPerFrame = 10;
      var finalBid = history.last.close;
      for (var frame = 0; frame < deliveredFrames; frame++) {
        for (var offset = 0; offset < ticksPerFrame; offset++) {
          final index = frame * ticksPerFrame + offset;
          final bid = history.last.close + (index + 1) / 100;
          finalBid = bid;
          quotes.add(
            DemoQuote(
              symbol: 'XAUUSD+',
              name: 'Gold US Dollar',
              bid: bid,
              ask: bid + .2,
              changePercent: .01,
              sourceTimestamp: firstTickAt.add(Duration(seconds: index + 1)),
            ),
          );
        }
        await tester.pump();
      }
      debugOnRebuildDirtyWidget = previousRebuildHook;
      debugOnProfilePaint = previousPaintHook;

      printOnFailure(
        '120 ticks/12 frames before-after counts: ChartScreen=$chartBuilds, '
        'AppBar=$appBarBuilds, Scaffold=$scaffoldBuilds, '
        'canvasBuild=$canvasBuilds, canvasPaint=$canvasPaints',
      );
      expect(chartBuilds, 0);
      expect(appBarBuilds, 0);
      expect(scaffoldBuilds, 0);
      expect(canvasBuilds, 0);
      expect(canvasPaints, deliveredFrames);
      expect(ChartRenderSnapshot.debugFullHistoryResolutionCount, 0);
      expect(ChartRenderSnapshot.debugResolvedHistoryCopyCount, 0);
      final boundaryFinder = find.byKey(
        const Key('chart-plot-repaint-boundary'),
      );
      expect(boundaryFinder, findsOneWidget);
      expect(tester.widget(boundaryFinder), isA<RepaintBoundary>());
      expect(tester.renderObject(boundaryFinder).isRepaintBoundary, isTrue);
      final finalPainter = _chartPainter(tester);
      expect(finalPainter.currentPrice, closeTo(finalBid, .0000001));
      expect(
        finalPainter.snapshot.liveCandle?.close,
        closeTo(finalBid, .0000001),
      );
      expect(
        finalPainter.debugResolvedCandles.last.close,
        closeTo(finalBid, .0000001),
      );
    },
  );

  testWidgets(
    'complete position and pending projections update painter without semantic no-op rebuilds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final history = _widgetHistory();
      final quote = DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: history.last.close,
        ask: history.last.close + .2,
        changePercent: 0,
        sourceTimestamp: history.last.time,
      );
      final initialPosition = _position();
      final initialPending = _pendingOrder();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketApiConfigProvider.overrideWithValue(
              const MarketApiConfig(baseUrl: 'https://market.example.com'),
            ),
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(history),
            ),
            realtimeCandleProvider.overrideWith(
              (ref, request) => const Stream<MarketCandle>.empty(),
            ),
            demoQuoteProvider.overrideWith(
              (ref, symbol) => Stream.value(quote),
            ),
            demoPositionsProvider.overrideWith(
              (ref) => ref.watch(_testPositionsProvider),
            ),
            demoPendingOrdersProvider.overrideWith(
              (ref) => ref.watch(_testPendingOrdersProvider),
            ),
          ],
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M5'),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChartScreen)),
      );
      container.read(_testPositionsProvider.notifier).replace(<DemoPosition>[
        initialPosition,
      ]);
      container.read(_testPendingOrdersProvider.notifier).replace(
        <DemoPendingOrder>[initialPending],
      );
      await tester.pump();
      await tester.pump();

      var painter = _chartPainter(tester);
      var revision = painter.snapshot.overlaysRevision;
      expect(painter.hitTargets.positionOverlays.single.label, 'BUY 1.00');
      expect(
        painter.hitTargets.pendingOrderOverlays.single.label,
        'BUY LIMIT 0.25',
      );
      final initialPositionY = painter.hitTargets.positionOverlays.single.y;
      final consumerElement = tester.element(find.byType(Consumer).first);
      var reactiveBuilds = 0;
      final previousRebuildHook = debugOnRebuildDirtyWidget;
      addTearDown(() => debugOnRebuildDirtyWidget = previousRebuildHook);
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previousRebuildHook?.call(element, builtOnce);
        if (identical(element, consumerElement)) reactiveBuilds++;
      };

      container.read(_testPositionsProvider.notifier).replace(<DemoPosition>[
        _position(),
      ]);
      container.read(_testPendingOrdersProvider.notifier).replace(
        <DemoPendingOrder>[_pendingOrder()],
      );
      await tester.pump();
      expect(reactiveBuilds, 0);
      expect(_chartPainter(tester).snapshot.overlaysRevision, revision);

      container.read(_testPositionsProvider.notifier).replace(<DemoPosition>[
        _position(volume: 2),
      ]);
      await tester.pump();
      painter = _chartPainter(tester);
      expect(reactiveBuilds, 1);
      expect(painter.snapshot.overlaysRevision, revision + 1);
      expect(painter.positions.single.volume, 2);
      expect(painter.hitTargets.positionOverlays.single.label, 'BUY 2.00');
      revision = painter.snapshot.overlaysRevision;

      container.read(_testPositionsProvider.notifier).replace(<DemoPosition>[
        _position(volume: 2, openPrice: history.last.close - 4),
      ]);
      await tester.pump();
      painter = _chartPainter(tester);
      expect(painter.snapshot.overlaysRevision, revision + 1);
      expect(painter.positions.single.openPrice, history.last.close - 4);
      expect(
        painter.hitTargets.positionOverlays.single.y,
        isNot(initialPositionY),
      );
      revision = painter.snapshot.overlaysRevision;

      container.read(_testPositionsProvider.notifier).replace(<DemoPosition>[
        _position(side: 'SELL', volume: 2, openPrice: history.last.close - 4),
      ]);
      await tester.pump();
      painter = _chartPainter(tester);
      expect(painter.snapshot.overlaysRevision, revision + 1);
      expect(painter.positions.single.side, 'SELL');
      expect(painter.hitTargets.positionOverlays.single.label, 'SELL 2.00');
      revision = painter.snapshot.overlaysRevision;

      container.read(_testPendingOrdersProvider.notifier).replace(
        <DemoPendingOrder>[_pendingOrder(type: 'Sell Stop')],
      );
      await tester.pump();
      painter = _chartPainter(tester);
      expect(painter.snapshot.overlaysRevision, revision + 1);
      expect(painter.pendingOrderType, 'Sell Stop');
      expect(
        painter.hitTargets.pendingOrderOverlays.single.label,
        'SELL STOP 0.25',
      );
      revision = painter.snapshot.overlaysRevision;

      container.read(_testPendingOrdersProvider.notifier).replace(
        <DemoPendingOrder>[
          _pendingOrder(type: 'Sell Stop', status: 'suspended'),
        ],
      );
      await tester.pump();
      painter = _chartPainter(tester);
      expect(painter.snapshot.overlaysRevision, revision + 1);
      expect(painter.pendingOrders.single.status, 'suspended');
    },
  );
}

List<MarketCandle> _history() => <MarketCandle>[
  MarketCandle(
    time: DateTime.utc(2026, 8, 23, 9, 50),
    open: 99.8,
    high: 100.1,
    low: 99.7,
    close: 100,
    volume: 10,
  ),
  MarketCandle(
    time: DateTime.utc(2026, 8, 23, 9, 55),
    open: 100,
    high: 100.4,
    low: 99.9,
    close: 100.25,
    volume: 12,
  ),
  MarketCandle(
    time: DateTime.utc(2026, 8, 23, 10),
    open: 100.25,
    high: 100.75,
    low: 100.2,
    close: 100.5,
    volume: 14,
  ),
];

MarketCandle _copyCandle(
  MarketCandle source, {
  DateTime? time,
  double? open,
  double? high,
  double? low,
  double? close,
  double? volume,
}) => MarketCandle(
  time: time ?? source.time,
  open: open ?? source.open,
  high: high ?? source.high,
  low: low ?? source.low,
  close: close ?? source.close,
  volume: volume ?? source.volume,
);

bool _sameCandle(MarketCandle left, MarketCandle right) =>
    left.time == right.time &&
    left.open == right.open &&
    left.high == right.high &&
    left.low == right.low &&
    left.close == right.close &&
    left.volume == right.volume;

List<MarketCandle> _widgetHistory() => List<MarketCandle>.generate(24, (index) {
  final open = 4500.0 + index;
  return MarketCandle(
    time: DateTime.utc(2026, 8, 23, 8).add(Duration(minutes: index * 5)),
    open: open,
    high: open + 1,
    low: open - 1,
    close: open + .5,
    volume: index.toDouble(),
  );
}, growable: false);

Mt5CandlePainter _chartPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const Key('chart-canvas'))).painter!
        as Mt5CandlePainter;

Mt5CandlePainter _painterForSnapshot(
  ChartRenderSnapshot snapshot, {
  String symbol = 'XAUUSD+',
  bool useRealtimeCandles = true,
}) => Mt5CandlePainter(
  snapshot: snapshot,
  symbol: symbol,
  referencePrice: 100.5,
  currentPrice: 100.5,
  tickTime: DateTime.utc(2026, 8, 23, 10, 1),
  crosshairEnabled: false,
  crosshairPosition: null,
  measurementStart: null,
  measurementEnd: null,
  timeframe: 'M5',
  positions: const [],
  pendingOrders: const [],
  indicators: const {},
  chartObjects: const [],
  pendingOrderType: null,
  pendingOrderPrice: null,
  pendingOrderVolume: .25,
  pendingStopLoss: null,
  pendingTakeProfit: null,
  focusedChartPrice: null,
  loadingPlaceholder: false,
  oneClickTrading: false,
  h4ExpandedScaleSeen: false,
  showHistoryBadge: false,
  useRealtimeCandles: useRealtimeCandles,
  hitTargets: ChartHitTargets(),
);

DemoPosition _position({
  String side = 'BUY',
  double volume = 1,
  double openPrice = 4521,
}) => DemoPosition(
  id: 'position-1',
  symbol: 'XAUUSD+',
  side: side,
  volume: volume,
  openPrice: openPrice,
  currentPrice: 4523.5,
  profit: 2.5,
  stopLoss: 4510,
  takeProfit: 4540,
  openedAt: '2026.08.23 09:00',
);

DemoPendingOrder _pendingOrder({
  String type = 'Buy Limit',
  String status = 'placed',
}) => DemoPendingOrder(
  id: 'pending-1',
  symbol: 'XAUUSD+',
  side: 'BUY',
  type: type,
  volume: .25,
  price: 4518,
  stopLoss: 4500,
  takeProfit: 4550,
  createdAt: '2026.08.23 09:30',
  status: status,
);

final class _IterationCountingCandleList extends ListBase<MarketCandle> {
  _IterationCountingCandleList(this._source, this._onIterated);

  final List<MarketCandle> _source;
  final void Function() _onIterated;

  @override
  int get length => _source.length;

  @override
  set length(int value) => throw UnsupportedError('Read only');

  @override
  MarketCandle operator [](int index) => _source[index];

  @override
  void operator []=(int index, MarketCandle value) =>
      throw UnsupportedError('Read only');

  @override
  Iterator<MarketCandle> get iterator {
    _onIterated();
    return _source.iterator;
  }
}

final _testPositionsProvider =
    NotifierProvider<_TestPositionsController, List<DemoPosition>>(
      _TestPositionsController.new,
    );

final class _TestPositionsController extends Notifier<List<DemoPosition>> {
  @override
  List<DemoPosition> build() => const <DemoPosition>[];

  void replace(List<DemoPosition> value) => state = List.unmodifiable(value);
}

final _testPendingOrdersProvider =
    NotifierProvider<_TestPendingOrdersController, List<DemoPendingOrder>>(
      _TestPendingOrdersController.new,
    );

final class _TestPendingOrdersController
    extends Notifier<List<DemoPendingOrder>> {
  @override
  List<DemoPendingOrder> build() => const <DemoPendingOrder>[];

  void replace(List<DemoPendingOrder> value) =>
      state = List.unmodifiable(value);
}
