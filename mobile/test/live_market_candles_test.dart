import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/data/market_data_service.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/realtime_market_service.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

const _supportedChartTimeframes = <String>[
  'M1',
  'M2',
  'M3',
  'M4',
  'M5',
  'M6',
  'M10',
  'M12',
  'M15',
  'M20',
  'M30',
  'H1',
  'H2',
  'H3',
  'H4',
  'H6',
  'H8',
  'H12',
  'D1',
  'W1',
  'MN',
];

void main() {
  test('history cache retains every supported timeframe for one symbol', () {
    final cache = MarketCandleHistoryCache();
    for (var index = 0; index < _supportedChartTimeframes.length; index++) {
      cache.store(
        MarketDataRequest('XAUUSD+', _supportedChartTimeframes[index]),
        [_candleAt(index + 1)],
      );
    }

    expect(cache.length, _supportedChartTimeframes.length);
    for (final timeframe in _supportedChartTimeframes) {
      expect(
        cache[MarketDataRequest('XAUUSD+', timeframe)],
        isNotNull,
        reason: '$timeframe must remain ready for an atomic revisit',
      );
    }
  });

  test('live-only candles are never history-ready on any timeframe', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscriptions = <ProviderSubscription<LiveMarketCandleState>>[];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });

    for (final timeframe in _supportedChartTimeframes) {
      final request = MarketDataRequest('XAUUSD+', timeframe);
      subscriptions.add(
        container.listen(
          liveMarketCandlesProvider(request),
          (previous, next) {},
        ),
      );
      final controller = container.read(
        liveMarketCandlesProvider(request).notifier,
      );
      final tickAt = DateTime.utc(2026, 8, 24, 11, 30);

      controller.applyTick(price: 4639, receivedAt: tickAt);
      expect(
        container.read(liveMarketCandlesProvider(request)).hasHistorySnapshot,
        isFalse,
        reason: '$timeframe live-only state cannot replace a full frame',
      );

      controller.seedHistory([
        MarketCandle(
          time: MarketDataService.bucketStart(tickAt, timeframe),
          open: 4630,
          high: 4645,
          low: 4625,
          close: 4635,
        ),
      ]);
      expect(
        container.read(liveMarketCandlesProvider(request)).hasHistorySnapshot,
        isTrue,
        reason: '$timeframe becomes ready only after history is seeded',
      );
    }
  });

  test('history cache normalizes immutable LRU nonempty snapshots', () {
    final cache = MarketCandleHistoryCache(capacity: 3);
    const m1 = MarketDataRequest('XAUUSD+', 'M1');
    const m5 = MarketDataRequest('XAUUSD+', 'M5');
    const h1 = MarketDataRequest('XAUUSD+', 'H1');
    const h4 = MarketDataRequest('XAUUSD+', 'H4');
    final source = <MarketCandle>[
      MarketCandle(
        time: DateTime.utc(2026, 8, 1),
        open: 100,
        high: 101,
        low: 99,
        close: 100.5,
      ),
    ];

    cache.store(m1, source);
    source
      ..clear()
      ..add(
        MarketCandle(
          time: DateTime.utc(2030),
          open: 999,
          high: 999,
          low: 999,
          close: 999,
        ),
      );
    final normalized = cache[const MarketDataRequest(' xauusd+ ', 'm1')];
    expect(normalized, hasLength(1));
    expect(normalized!.single.close, 100.5);
    expect(
      () => normalized.add(
        MarketCandle(
          time: DateTime.utc(2031),
          open: 1,
          high: 1,
          low: 1,
          close: 1,
        ),
      ),
      throwsUnsupportedError,
    );

    cache.store(m5, [_candleAt(5)]);
    cache.store(h1, [_candleAt(60)]);
    expect(cache[m1], same(normalized), reason: 'read promotes M1');
    cache.store(h4, [_candleAt(240)]);

    expect(cache.length, 3);
    expect(cache[m5], isNull, reason: 'M5 is least-recent after M1 promotion');
    expect(cache[m1], same(normalized));
    cache.store(m1, const <MarketCandle>[]);
    expect(cache[m1], same(normalized), reason: 'empty cannot replace valid');
  });

  test('local 200ms history polling stops after its last listener', () {
    fakeAsync((async) {
      const request = MarketDataRequest('XAUUSD+', 'M1');
      final service = _PollingMarketDataService();
      final container = ProviderContainer(
        overrides: [marketDataServiceProvider.overrideWithValue(service)],
      );
      final subscription = container.listen(
        marketCandlesProvider(request),
        (_, _) {},
        fireImmediately: true,
      );
      async.flushMicrotasks();
      expect(service.fetchCount, 1);
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      expect(service.fetchCount, 2);

      subscription.close();
      async.flushMicrotasks();
      final countAfterClose = service.fetchCount;
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(service.fetchCount, countAfterClose);
      container.dispose();
      async.flushMicrotasks();
    });
  });

  test('in-flight REST history cancels after its last listener', () async {
    const request = MarketDataRequest('XAUUSD+', 'H4');
    final service = _DeferredMarketDataService();
    final container = ProviderContainer(
      overrides: [marketDataServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      marketCandlesProvider(request),
      (_, _) {},
      fireImmediately: true,
    );
    await service.started.future;
    subscription.close();
    await service.cancelled.future;
    await service.settled.future;

    expect(service.cancelToken?.isCancelled, isTrue);
    expect(service.activeRequests, 0);
  });

  test('realtime history resync listener disposes with its request', () async {
    const request = MarketDataRequest('XAUUSD+', 'H4');
    final marketData = _ImmediateRealtimeMarketDataService();
    final realtime = _HistoryResyncRealtimeService();
    final container = ProviderContainer(
      overrides: [
        marketDataServiceProvider.overrideWithValue(marketData),
        realtimeMarketServiceProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await realtime.closeTestStreams();
    });

    final subscription = container.listen(
      marketCandlesProvider(request),
      (_, _) {},
      fireImmediately: true,
    );
    await marketData.fetched.future;
    await _flushMicrotasks();
    expect(realtime.resyncs.hasListener, isTrue);

    subscription.close();
    await container.pump();
    expect(realtime.resyncs.hasListener, isFalse);
  });

  test('live provider retains the full realtime REST history window', () {
    const request = MarketDataRequest('XAUUSD+', 'M1');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      liveMarketCandlesProvider(request),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final history = List<MarketCandle>.generate(
      1200,
      (index) => MarketCandle(
        time: DateTime.utc(2026, 7, 1).add(Duration(minutes: index)),
        open: 4000 + index / 100,
        high: 4001 + index / 100,
        low: 3999 + index / 100,
        close: 4000.5 + index / 100,
        volume: index.toDouble(),
      ),
    );

    container
        .read(liveMarketCandlesProvider(request).notifier)
        .seedHistory(history);

    final state = container.read(liveMarketCandlesProvider(request));
    expect(state.candles, hasLength(MarketDataService.realtimeHistoryLimit));
    expect(state.candles.first.time, history[200].time);
    expect(state.candles.last.volume, history.last.volume);
  });

  test(
    'live provider replays pre-history ticks and advances the H4 candle',
    () {
      const request = MarketDataRequest('XAUUSD+', 'H4');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        liveMarketCandlesProvider(request),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final controller = container.read(
        liveMarketCandlesProvider(request).notifier,
      );

      controller.applyTick(
        price: 4105,
        receivedAt: DateTime(2026, 7, 27, 9, 20),
      );
      controller.applyTick(
        price: 4106,
        receivedAt: DateTime(2026, 7, 27, 9, 21),
      );
      controller.applyTick(
        price: 4104,
        receivedAt: DateTime(2026, 7, 27, 9, 22),
      );
      controller.seedHistory([
        MarketCandle(
          time: DateTime(2026, 7, 27, 8),
          open: 4100,
          high: 4101,
          low: 4099,
          close: 4100.5,
          volume: 179,
        ),
      ]);

      var state = container.read(liveMarketCandlesProvider(request));
      expect(state.liveTail, hasLength(1));
      expect(state.liveTail.single.open, 4100);
      expect(state.liveTail.single.high, 4106);
      expect(state.liveTail.single.low, 4099);
      expect(state.liveTail.single.close, 4104);
      expect(state.liveTail.single.volume, 179);
      expect(state.candles, hasLength(1));
      expect(state.candles.single.open, 4100);
      expect(state.candles.single.high, 4106);
      expect(state.candles.single.low, 4099);
      expect(state.candles.single.close, 4104);

      controller.applyTick(price: 4107, receivedAt: DateTime(2026, 7, 27, 12));
      state = container.read(liveMarketCandlesProvider(request));
      expect(state.liveTail, hasLength(2));
      expect(state.candles, hasLength(2));
      expect(state.candles.last.time, DateTime(2026, 7, 27, 12));
      expect(state.candles.last.open, 4107);
      expect(state.candles.last.high, 4107);
      expect(state.candles.last.low, 4107);
      expect(state.candles.last.close, 4107);
      expect(state.nextBoundary, DateTime(2026, 7, 27, 16));

      final currentState = state;
      controller.applyTick(
        price: 4000,
        receivedAt: DateTime(2026, 7, 27, 11, 59),
      );
      expect(container.read(liveMarketCandlesProvider(request)), currentState);
    },
  );

  test('a same-bucket remote candle cannot roll back a newer quote', () {
    const request = MarketDataRequest('XAUUSD+', 'M30');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      liveMarketCandlesProvider(request),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(
      liveMarketCandlesProvider(request).notifier,
    );
    final quoteAt = DateTime.utc(2026, 8, 24, 15, 20);

    controller.seedHistory([
      MarketCandle(
        time: DateTime.utc(2026, 8, 24, 15),
        open: 100,
        high: 105,
        low: 95,
        close: 101,
        volume: 100,
      ),
    ]);
    controller.applyTick(price: 110, receivedAt: quoteAt);
    controller.applyRemoteCandle(
      MarketCandle(
        time: DateTime.utc(2026, 8, 24, 15),
        open: 100,
        high: 108,
        low: 94,
        close: 107,
        volume: 120,
      ),
      receivedAt: DateTime.utc(2026, 8, 24, 15, 21),
    );

    final state = container.read(liveMarketCandlesProvider(request));
    expect(state.currentPrice, 110);
    expect(state.lastTickAt, quoteAt);
    expect(state.activeCandle?.open, 100);
    expect(state.activeCandle?.high, 110);
    expect(state.activeCandle?.low, 94);
    expect(state.activeCandle?.close, 110);
    expect(state.activeCandle?.volume, 120);
  });

  test('remote UTC candle keeps the active clock on UTC boundaries', () {
    const request = MarketDataRequest('XAUUSD+', 'H4');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      liveMarketCandlesProvider(request),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final receivedAt = DateTime(2026, 8, 21, 8, 33);

    container
        .read(liveMarketCandlesProvider(request).notifier)
        .applyRemoteCandle(
          MarketCandle(
            time: DateTime.utc(2026, 8, 21),
            open: 4526.34,
            high: 4535.41,
            low: 4508.61,
            close: 4534.76,
            volume: 15923,
          ),
          receivedAt: receivedAt,
        );

    final state = container.read(liveMarketCandlesProvider(request));
    final alignedReceivedAt = receivedAt.toUtc();
    expect(state.lastTickAt, alignedReceivedAt);
    expect(state.lastTickAt?.isUtc, isTrue);
    expect(
      state.nextBoundary,
      MarketDataService.nextBoundary(alignedReceivedAt, 'H4'),
    );
  });

  testWidgets(
    'source-before-clock stays authoritative while Bid remains visible',
    (tester) async {
      final quotes = StreamController<DemoQuote>(sync: true);
      addTearDown(quotes.close);
      final marketNow = DateTime.utc(2026, 8, 24, 16, 13);
      final history = [
        MarketCandle(
          time: DateTime.utc(2026, 8, 24, 16),
          open: 4655,
          high: 4665,
          low: 4650,
          close: 4659,
          volume: 120,
        ),
      ];

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
            marketClockProvider.overrideWithValue(() => marketNow),
            demoQuoteProvider.overrideWith((ref, symbol) => quotes.stream),
          ],
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M30'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      quotes.add(
        DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 4668,
          ask: 4668.2,
          changePercent: .1,
          sourceTimestamp: DateTime.utc(2026, 8, 24, 15, 58),
        ),
      );
      await tester.pump();
      await tester.pump();

      var painter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as dynamic;
      var active = (painter.debugResolvedCandles as List<MarketCandle>).last;
      expect(painter.currentPrice, 4668);
      expect(active.high, 4668);
      expect(active.close, 4668);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChartScreen)),
      );
      const request = MarketDataRequest('XAUUSD+', 'M30');
      expect(
        container.read(liveMarketCandlesProvider(request)).lastTickAt,
        isNull,
      );

      quotes.add(
        DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 4648,
          ask: 4648.2,
          changePercent: -.1,
          sourceTimestamp: DateTime.utc(2026, 8, 24, 15, 59),
        ),
      );
      await tester.pump();
      await tester.pump();

      painter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as dynamic;
      active = (painter.debugResolvedCandles as List<MarketCandle>).last;
      expect(painter.currentPrice, 4648);
      expect(active.high, 4665);
      expect(active.low, 4648);
      expect(active.close, 4648);
      expect(
        container.read(liveMarketCandlesProvider(request)).lastTickAt,
        isNull,
      );
    },
  );

  testWidgets(
    'latest Bid stays drawn when a future candle arrives before its quote',
    (tester) async {
      final quotes = StreamController<DemoQuote>(sync: true);
      final remoteCandles = StreamController<MarketCandle>(sync: true);
      addTearDown(quotes.close);
      addTearDown(remoteCandles.close);
      final marketNow = DateTime.utc(2026, 8, 24, 16, 13);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketApiConfigProvider.overrideWithValue(
              const MarketApiConfig(baseUrl: 'https://market.example.com'),
            ),
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value([
                MarketCandle(
                  time: DateTime.utc(2026, 8, 24, 16),
                  open: 4655,
                  high: 4665,
                  low: 4650,
                  close: 4659,
                  volume: 120,
                ),
              ]),
            ),
            realtimeCandleProvider.overrideWith(
              (ref, request) => remoteCandles.stream,
            ),
            marketClockProvider.overrideWithValue(() => marketNow),
            demoQuoteProvider.overrideWith((ref, symbol) => quotes.stream),
          ],
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M30'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      quotes.add(
        DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 4668,
          ask: 4668.2,
          changePercent: .1,
          sourceTimestamp: DateTime.utc(2026, 8, 24, 16, 13),
        ),
      );
      await tester.pump();
      await tester.pump();
      remoteCandles.add(
        MarketCandle(
          time: DateTime.utc(2026, 8, 24, 16, 30),
          open: 4690,
          high: 4705,
          low: 4685,
          close: 4700,
          volume: 140,
        ),
      );
      await tester.pump();
      await tester.pump();

      final painter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as dynamic;
      final active = (painter.debugResolvedCandles as List<MarketCandle>).last;
      expect(painter.currentPrice, 4668);
      expect(active.open, 4690);
      expect(active.high, 4705);
      expect(active.low, 4668);
      expect(active.close, 4668);
    },
  );

  testWidgets(
    'production quote immediately updates the active candle before candle event',
    (tester) async {
      final quotes = StreamController<DemoQuote>();
      addTearDown(quotes.close);
      final tickAt = DateTime(2026, 8, 21, 6, 58);
      final history = [
        MarketCandle(
          time: DateTime(2026, 8, 21, 6, 55),
          open: 4527.42,
          high: 4527.63,
          low: 4525.87,
          close: 4527.31,
          volume: 191,
        ),
      ];

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
            marketClockProvider.overrideWithValue(() => tickAt),
            demoQuoteProvider.overrideWith((ref, symbol) => quotes.stream),
          ],
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M5'),
          ),
        ),
      );
      await tester.pump();

      quotes.add(
        const DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 4526.65,
          ask: 4526.91,
          changePercent: .1,
        ),
      );
      await tester.pump();
      await tester.pump();

      final dynamic painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      final resolved = painter.debugResolvedCandles as List<MarketCandle>;

      expect(painter.currentPrice, 4526.65);
      expect(resolved, hasLength(1));
      expect(resolved.single.open, 4527.42);
      expect(resolved.single.high, 4527.63);
      expect(resolved.single.low, 4525.87);
      expect(resolved.single.close, 4526.65);
      expect(resolved.single.volume, 191);
    },
  );

  for (final testCase
      in <
        ({String symbol, double open, double high, double low, double rollover})
      >[
        (symbol: 'XAUUSD+', open: 4105, high: 4106, low: 4104, rollover: 4107),
        (
          symbol: 'BTCUSD',
          open: 65100,
          high: 65200,
          low: 64900,
          rollover: 65300,
        ),
      ]) {
    testWidgets(
      '${testCase.symbol} painter overlays live OHLC and rolls at the tick boundary',
      (tester) async {
        final quotes = StreamController<DemoQuote>();
        addTearDown(quotes.close);
        var tickAt = DateTime(2026, 7, 27, 9, 25, 30);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              marketCandlesProvider.overrideWith(
                (ref, request) => Stream.value(const <MarketCandle>[]),
              ),
              marketClockProvider.overrideWith(
                (ref) =>
                    () => tickAt,
              ),
              demoQuoteProvider.overrideWith((ref, symbol) => quotes.stream),
            ],
            child: MaterialApp(
              home: ChartScreen(
                symbol: testCase.symbol,
                initialTimeframe: 'H4',
              ),
            ),
          ),
        );
        await tester.pump();

        Future<void> emit(double bid) async {
          quotes.add(
            DemoQuote(
              symbol: testCase.symbol,
              name: testCase.symbol,
              bid: bid,
              ask: bid + (testCase.symbol == 'BTCUSD' ? 17.12 : .13),
              changePercent: .1,
            ),
          );
          await tester.pump();
          await tester.pump();
        }

        await emit(testCase.open);
        await emit(testCase.high);
        await emit(testCase.low);

        dynamic painter = tester
            .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
            .painter;
        var tail = painter.liveTail as List<MarketCandle>;
        var resolved = painter.debugResolvedCandles as List<MarketCandle>;
        expect(painter.currentPrice, testCase.low);
        expect(painter.tickTime, tickAt);
        expect(tail, hasLength(1));
        expect(tail.single.time, DateTime(2026, 7, 27, 8));
        expect(tail.single.open, testCase.open);
        expect(tail.single.high, testCase.high);
        expect(tail.single.low, testCase.low);
        expect(tail.single.close, testCase.low);
        expect(resolved, hasLength(360));
        expect(resolved.last.time, DateTime(2026, 7, 27, 8));
        expect(resolved.last.open, testCase.open);
        expect(resolved.last.high, testCase.high);
        expect(resolved.last.low, testCase.low);
        expect(resolved.last.close, testCase.low);

        tickAt = DateTime(2026, 7, 27, 12);
        await emit(testCase.rollover);

        painter = tester
            .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
            .painter;
        tail = painter.liveTail as List<MarketCandle>;
        resolved = painter.debugResolvedCandles as List<MarketCandle>;
        expect(painter.currentPrice, testCase.rollover);
        expect(tail, hasLength(2));
        expect(tail.last.time, DateTime(2026, 7, 27, 12));
        expect(tail.last.open, testCase.rollover);
        expect(tail.last.high, testCase.rollover);
        expect(tail.last.low, testCase.rollover);
        expect(tail.last.close, testCase.rollover);
        expect(resolved.last.time, DateTime(2026, 7, 27, 12));
        expect(resolved.last.close, testCase.rollover);
      },
    );
  }
}

MarketCandle _candleAt(int minute) => MarketCandle(
  time: DateTime.utc(2026, 8, 1).add(Duration(minutes: minute)),
  open: 100,
  high: 101,
  low: 99,
  close: 100.5,
);

Future<void> _flushMicrotasks([int turns = 12]) async {
  for (var index = 0; index < turns; index++) {
    await Future<void>.value();
  }
}

class _PollingMarketDataService extends MarketDataService {
  _PollingMarketDataService() : super(Dio());

  int fetchCount = 0;

  @override
  bool get usesRealtimeApi => false;

  @override
  Future<bool> hasLocalMt5History(String symbol) async => true;

  @override
  Future<List<MarketCandle>> fetchCandles(
    String symbol,
    String timeframe, {
    CancelToken? cancelToken,
  }) async {
    fetchCount++;
    return [
      MarketCandle(
        time: DateTime.utc(2026, 8, 1, 0, fetchCount),
        open: 4000,
        high: 4001,
        low: 3999,
        close: 4000.5,
      ),
    ];
  }
}

class _DeferredMarketDataService extends MarketDataService {
  _DeferredMarketDataService()
    : super(Dio(), marketApiBaseUrl: 'https://market.example.com');

  CancelToken? cancelToken;
  final Completer<void> started = Completer<void>();
  final Completer<void> cancelled = Completer<void>();
  final Completer<void> settled = Completer<void>();
  int activeRequests = 0;

  @override
  Future<List<MarketCandle>> fetchCandles(
    String symbol,
    String timeframe, {
    CancelToken? cancelToken,
  }) async {
    this.cancelToken = cancelToken;
    activeRequests++;
    if (!started.isCompleted) started.complete();
    try {
      final error = await cancelToken!.whenCancel;
      if (!cancelled.isCompleted) cancelled.complete();
      throw error;
    } finally {
      activeRequests--;
      if (!settled.isCompleted) settled.complete();
    }
  }
}

class _ImmediateRealtimeMarketDataService extends MarketDataService {
  _ImmediateRealtimeMarketDataService()
    : super(Dio(), marketApiBaseUrl: 'https://market.example.com');

  final Completer<void> fetched = Completer<void>();

  @override
  Future<List<MarketCandle>> fetchCandles(
    String symbol,
    String timeframe, {
    CancelToken? cancelToken,
  }) async {
    if (!fetched.isCompleted) fetched.complete();
    return [_candleAt(0)];
  }
}

class _HistoryResyncRealtimeService extends RealtimeMarketService {
  _HistoryResyncRealtimeService()
    : super(baseUrl: 'https://market.example.com');

  final StreamController<int> resyncs = StreamController<int>.broadcast();

  @override
  Stream<int> get historyResyncs => resyncs.stream;

  Future<void> closeTestStreams() async {
    await resyncs.close();
    await dispose();
  }
}
