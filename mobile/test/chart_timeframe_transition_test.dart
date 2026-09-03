import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

void main() {
  testWidgets(
    'a cached target timeframe matches the latest quote on the next pump',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const m5Request = MarketDataRequest('XAUUSD+', 'M5');
      final m1 = _candles(
        start: DateTime.utc(2026, 8, 24, 8),
        count: 48,
        step: const Duration(minutes: 1),
        base: 4100,
      );
      final m5 = _candles(
        start: DateTime.utc(2026, 8, 24, 4),
        count: 48,
        step: const Duration(minutes: 5),
        base: 4200,
      );
      final cache = MarketCandleHistoryCache()..store(m5Request, m5);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketApiConfigProvider.overrideWithValue(
              const MarketApiConfig(baseUrl: 'https://market.example.com'),
            ),
            marketCandleHistoryCacheProvider.overrideWithValue(cache),
            marketCandlesProvider.overrideWith((ref, request) {
              if (request.timeframe == 'M1') return Stream.value(m1);
              return const Stream<List<MarketCandle>>.empty();
            }),
            demoQuoteProvider.overrideWith(
              (ref, symbol) => Stream.value(
                const DemoQuote(
                  symbol: 'XAUUSD+',
                  name: 'Gold US Dollar',
                  bid: 4639,
                  ask: 4639.2,
                  changePercent: .1,
                ),
              ),
            ),
            realtimeCandleProvider.overrideWith(
              (ref, request) => const Stream<MarketCandle>.empty(),
            ),
          ],
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(_painter(tester).timeframe, 'M1');

      await _switchTimeframe(tester, from: 'M1', to: 'M5');

      final painter = _painter(tester);
      expect(painter.timeframe, 'M5');
      expect(painter.debugResolvedCandles.first.time, m5.first.time);
      expect(painter.currentPrice, 4639);
      expect(painter.debugResolvedCandles.last.close, 4639);
    },
  );

  testWidgets(
    'a pinned cached timeframe never collapses to its live-only candle',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const h4Request = MarketDataRequest('XAUUSD+', 'H4');
      final histories = <String, List<MarketCandle>>{
        'H1': _candles(
          start: DateTime.utc(2026, 8, 20),
          count: 48,
          step: const Duration(hours: 1),
          base: 4300,
        ),
        'H4': _candles(
          start: DateTime.utc(2026, 8, 16),
          count: 48,
          step: const Duration(hours: 4),
          base: 4400,
        ),
      };
      final quotes = StreamController<DemoQuote>(sync: true);
      addTearDown(quotes.close);
      final container = ProviderContainer(
        overrides: [
          marketApiConfigProvider.overrideWithValue(
            const MarketApiConfig(baseUrl: 'https://market.example.com'),
          ),
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(histories[request.timeframe]!),
          ),
          realtimeCandleProvider.overrideWith(
            (ref, request) => const Stream<MarketCandle>.empty(),
          ),
          marketClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 8, 24, 11, 30),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) => quotes.stream),
        ],
      );
      addTearDown(container.dispose);
      final pinnedH4 = container.listen(
        marketCandlesProvider(h4Request),
        (previous, next) {},
      );
      addTearDown(pinnedH4.close);
      await container.read(marketCandlesProvider(h4Request).future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(_painter(tester).debugResolvedCandles, hasLength(48));

      await _switchTimeframe(tester, from: 'H1', to: 'H4');
      expect(_painter(tester).timeframe, 'H4');
      expect(_painter(tester).debugResolvedCandles, hasLength(48));

      quotes.add(
        const DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 4639,
          ask: 4639.25,
          changePercent: .1,
          sourceTimestamp: null,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        container.read(liveMarketCandlesProvider(h4Request)).lastTickAt,
        DateTime.utc(2026, 8, 24, 11, 30),
        reason: 'A quote without source time must fall back to marketClock.',
      );
      final painter = _painter(tester);
      expect(painter.timeframe, 'H4');
      expect(painter.debugResolvedCandles, hasLength(48));
      expect(
        painter.debugResolvedCandles.first.time,
        DateTime.utc(2026, 8, 16),
      );
    },
  );

  testWidgets(
    'rapid M1 to M5 to H1 to H4 keeps one last-valid frame until H4 wins',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      final realtime = <String, StreamController<MarketCandle>>{
        for (final timeframe in const ['M1', 'M5', 'H1', 'H4'])
          timeframe: StreamController<MarketCandle>(sync: true),
      };
      final quotes = StreamController<DemoQuote>(sync: true);
      var queuedH1HistoryDeliveries = 0;
      addTearDown(() {
        for (final controller in histories.values) {
          unawaited(controller.close());
        }
        for (final controller in realtime.values) {
          unawaited(controller.close());
        }
        unawaited(quotes.close());
      });

      final m1 = _candles(
        start: DateTime.utc(2026, 8, 1),
        count: 24,
        step: const Duration(minutes: 1),
        base: 4100,
      );
      final m5 = _candles(
        start: DateTime.utc(2026, 8, 2),
        count: 24,
        step: const Duration(minutes: 5),
        base: 4200,
      );
      final h1 = _candles(
        start: DateTime.utc(2026, 8, 3),
        count: 24,
        step: const Duration(hours: 1),
        base: 4300,
      );
      final h4 = _candles(
        start: DateTime.utc(2026, 8, 4),
        count: 24,
        step: const Duration(hours: 4),
        base: 4400,
      );
      final tickAt = m1.last.time.add(const Duration(seconds: 30));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketApiConfigProvider.overrideWithValue(
              const MarketApiConfig(baseUrl: 'https://market.example.com'),
            ),
            marketCandlesProvider.overrideWith(
              (ref, request) =>
                  histories[request.timeframe]!.stream.map((data) {
                    if (request.timeframe == 'H1') queuedH1HistoryDeliveries++;
                    return data;
                  }),
            ),
            realtimeCandleProvider.overrideWith(
              (ref, request) => realtime[request.timeframe]!.stream,
            ),
            marketClockProvider.overrideWithValue(() => tickAt),
            demoQuoteProvider.overrideWith((ref, symbol) => quotes.stream),
          ],
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M1'),
          ),
        ),
      );
      await tester.pump();
      quotes.add(
        DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: m1.last.close,
          ask: m1.last.close + .2,
          changePercent: 0,
          sourceTimestamp: tickAt,
        ),
      );
      await tester.pump();
      histories['M1']!.add(m1);
      await tester.pump();
      await tester.pump();

      var painter = _painter(tester);
      expect(painter.timeframe, 'M1');
      expect(painter.debugResolvedCandles, isNotEmpty);
      expect(painter.debugResolvedCandles.first.time, m1.first.time);

      final chart = find.byKey(const Key('chart-gesture-area'));
      final center = tester.getCenter(chart);
      final first = await tester.startGesture(
        center - const Offset(100, 0),
        pointer: 11,
      );
      final second = await tester.startGesture(
        center + const Offset(100, 0),
        pointer: 12,
      );
      await first.moveTo(center - const Offset(140, 0));
      await second.moveTo(center + const Offset(140, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pump();
      final retainedSpacing = _painter(tester).viewport.barSpacing;
      expect(retainedSpacing, greaterThan(32));

      await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('chart-one-click-volume-up-chevron')),
      );
      await tester.pump();
      expect(find.text('0.26'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chart-crosshair-button')));
      await tester.pump();
      await tester.tapAt(center);
      await tester.pump();
      expect(_painter(tester).crosshairPosition, isNotNull);

      await _switchTimeframe(tester, from: 'M1', to: 'M5');
      await _expectHeldFrame(
        tester,
        selectedTimeframe: 'M5',
        heldTimeframe: 'M1',
        heldFirstTime: m1.first.time,
        retainedSpacing: retainedSpacing,
      );
      await _switchTimeframe(tester, from: 'M5', to: 'H1');
      await _expectHeldFrame(
        tester,
        selectedTimeframe: 'H1',
        heldTimeframe: 'M1',
        heldFirstTime: m1.first.time,
        retainedSpacing: retainedSpacing,
      );
      await tester.tap(find.text('H1').first);
      await tester.pump();
      expect(histories['H1']!.hasListener, isTrue);
      var queuedOldEventsSent = false;
      Timer.run(() {
        queuedOldEventsSent = true;
        histories['H1']!.add(h1);
        realtime['H1']!.add(
          MarketCandle(
            time: h1.last.time,
            open: 9990,
            high: 9999,
            low: 9980,
            close: 9995,
          ),
        );
      });
      await tester.tap(find.text('H4').first);
      await tester.pump(const Duration(milliseconds: 1));
      expect(queuedOldEventsSent, isTrue);
      expect(queuedH1HistoryDeliveries, 1);
      await _expectHeldFrame(
        tester,
        selectedTimeframe: 'H4',
        heldTimeframe: 'M1',
        heldFirstTime: m1.first.time,
        retainedSpacing: retainedSpacing,
      );
      await tester.pump();
      expect(histories['M1']!.hasListener, isTrue);
      expect(histories['M5']!.hasListener, isTrue);
      expect(histories['H1']!.hasListener, isTrue);
      expect(histories['H4']!.hasListener, isTrue);
      expect(realtime['M1']!.hasListener, isFalse);
      expect(realtime['M5']!.hasListener, isFalse);
      expect(realtime['H1']!.hasListener, isFalse);
      expect(realtime['H4']!.hasListener, isTrue);

      histories['M5']!.add(m5);
      realtime['M5']!.add(
        MarketCandle(
          time: m5.last.time,
          open: 9990,
          high: 9999,
          low: 9980,
          close: 9995,
        ),
      );
      await tester.pump();
      await tester.pump();
      await _expectHeldFrame(
        tester,
        selectedTimeframe: 'H4',
        heldTimeframe: 'M1',
        heldFirstTime: m1.first.time,
        retainedSpacing: retainedSpacing,
      );

      final h4Quote = h4.last.close + 5;
      quotes.add(
        DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: h4Quote,
          ask: h4Quote + .2,
          changePercent: .1,
          sourceTimestamp: h4.last.time.add(const Duration(minutes: 30)),
        ),
      );
      await tester.pump();
      await tester.pump();
      await _expectHeldFrame(
        tester,
        selectedTimeframe: 'H4',
        heldTimeframe: 'M1',
        heldFirstTime: m1.first.time,
        retainedSpacing: retainedSpacing,
      );
      final h4Request = MarketDataRequest('XAUUSD+', 'H4');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChartScreen)),
      );
      final preHistoryH4State = container.read(
        liveMarketCandlesProvider(h4Request),
      );
      expect(preHistoryH4State.activeCandle?.high, h4Quote);
      expect(preHistoryH4State.activeCandle?.close, h4Quote);

      histories['H4']!.add(h4);
      await tester.pump();
      await tester.pump();

      final reconciledH4State = container.read(
        liveMarketCandlesProvider(h4Request),
      );
      expect(reconciledH4State.activeCandle?.high, h4Quote);
      expect(reconciledH4State.activeCandle?.close, h4Quote);

      painter = _painter(tester);
      expect(painter.timeframe, 'H4');
      expect(painter.debugResolvedCandles.first.time, h4.first.time);
      expect(painter.debugResolvedCandles, hasLength(h4.length));
      expect(painter.debugResolvedCandles.last.time, h4.last.time);
      expect(painter.debugResolvedCandles.last.open, h4.last.open);
      expect(painter.debugResolvedCandles.last.high, h4Quote);
      expect(painter.debugResolvedCandles.last.low, h4.last.low);
      expect(painter.debugResolvedCandles.last.close, h4Quote);
      expect(painter.debugResolvedCandles.last.volume, h4.last.volume);
      expect(painter.viewport.barSpacing, retainedSpacing);
      expect(painter.viewport.scrollOffset, 0);
      final visible = painter.hitTargets.visibleCandles;
      final newestCenter =
          painter.hitTargets.firstCandleCenterX +
          (visible.length - 1) * painter.hitTargets.candleWidth;
      expect(
        newestCenter,
        closeTo(
          painter.hitTargets.chartWidth - painter.hitTargets.candleWidth,
          .01,
        ),
      );
      expect(painter.theme.background, const Color(0xFFFFFFFF));
      expect(painter.crosshairEnabled, isTrue);
      expect(painter.crosshairPosition, isNull);
      expect(find.text('0.26'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
    },
  );
}

Future<void> _switchTimeframe(
  WidgetTester tester, {
  required String from,
  required String to,
}) async {
  await tester.tap(find.text(from).first);
  await tester.pump();
  await tester.tap(find.text(to).first);
  await tester.pump();
}

Future<void> _expectHeldFrame(
  WidgetTester tester, {
  required String selectedTimeframe,
  required String heldTimeframe,
  required DateTime heldFirstTime,
  required double retainedSpacing,
}) async {
  final painter = _painter(tester);
  expect(find.text(selectedTimeframe), findsOneWidget);
  expect(painter.timeframe, heldTimeframe);
  expect(painter.debugResolvedCandles, isNotEmpty);
  expect(painter.debugResolvedCandles.first.time, heldFirstTime);
  expect(painter.viewport.barSpacing, retainedSpacing);
  expect(painter.viewport.scrollOffset, 0);
  final visible = painter.hitTargets.visibleCandles;
  final newestCenter =
      painter.hitTargets.firstCandleCenterX +
      (visible.length - 1) * painter.hitTargets.candleWidth;
  expect(
    painter.hitTargets.chartWidth - newestCenter,
    closeTo(painter.hitTargets.candleWidth, .01),
  );
  expect(painter.theme.background, const Color(0xFFFFFFFF));
  expect(painter.crosshairEnabled, isTrue);
  expect(painter.crosshairPosition, isNull);
  expect(find.text('0.26'), findsOneWidget);
}

Mt5CandlePainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const Key('chart-canvas'))).painter!
        as Mt5CandlePainter;

List<MarketCandle> _candles({
  required DateTime start,
  required int count,
  required Duration step,
  required double base,
}) => List<MarketCandle>.generate(
  count,
  (index) => MarketCandle(
    time: start.add(step * index),
    open: base + index,
    high: base + index + 2,
    low: base + index - 2,
    close: base + index + 1,
    volume: 100 + index.toDouble(),
  ),
  growable: false,
);
