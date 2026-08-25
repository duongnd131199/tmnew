import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_hub/signalr_client.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/realtime_market_service.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

void main() {
  test(
    'subscribes a new symbol and chart on an existing hub connection',
    () async {
      final hub = _RecordingHubConnection();
      final dio = Dio()..httpClientAdapter = _QuoteAdapter();
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: dio,
        connectionFactory: () => hub,
      );
      const fallback = DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4000,
        ask: 4000.2,
        changePercent: 0,
      );

      final goldSubscription = service
          .watchQuote('XAUUSD+', fallback)
          .listen((_) {});
      await _waitUntil(
        () => hub.hasSymbolSubscription('XAUUSD+'),
        'initial symbol subscription',
      );

      final bitcoinSubscription = service
          .watchQuote(
            'BTCUSD',
            const DemoQuote(
              symbol: 'BTCUSD',
              name: 'Bitcoin',
              bid: 62000,
              ask: 62010,
              changePercent: 0,
            ),
          )
          .listen((_) {});
      await _waitUntil(
        () => hub.hasSymbolSubscription('BTCUSD'),
        'new symbol subscription on a connected hub',
      );

      const request = MarketDataRequest('BTCUSD', 'M15');
      final candleSubscription = service.watchCandle(request).listen((_) {});
      await _waitUntil(
        () => hub.hasChartSubscription(request),
        'new chart subscription on a connected hub',
      );

      await candleSubscription.cancel();
      await bitcoinSubscription.cancel();
      await goldSubscription.cancel();
      await service.dispose();
    },
  );

  test(
    'publishes true ticks in order and rejects only older timestamps',
    () async {
      final hub = _RecordingHubConnection();
      final dio = Dio()..httpClientAdapter = _QuoteAdapter();
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: dio,
        connectionFactory: () => hub,
      );
      const fallback = DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4000,
        ask: 4000.2,
        changePercent: 0,
      );
      final quotes = <DemoQuote>[];
      final subscription = service
          .watchQuote('XAUUSD+', fallback)
          .listen(quotes.add);
      await _waitUntil(() => quotes.isNotEmpty, 'initial REST quote');
      await _waitUntil(
        () => hub.hasSymbolSubscription('XAUUSD+'),
        'SignalR symbol subscription',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final realtimeStart = quotes.length;

      hub.emitQuote(bid: 4000.01, timestamp: '2026-08-01T00:00:00.050Z');
      hub.emitQuote(bid: 4000.02, timestamp: '2026-08-01T00:00:00.100Z');
      hub.emitQuote(bid: 4000.03, timestamp: '2026-08-01T00:00:00.150Z');
      hub.emitQuote(bid: 3999.00, timestamp: '2026-08-01T00:00:00.100Z');
      hub.emitQuote(bid: 4000.04, timestamp: '2026-08-01T00:00:00.150Z');

      await _waitUntil(
        () => quotes.length == realtimeStart + 4,
        'four accepted realtime ticks',
      );
      expect(quotes.skip(realtimeStart).map((quote) => quote.bid), <double>[
        4000.01,
        4000.02,
        4000.03,
        4000.04,
      ]);
      expect(
        quotes.skip(realtimeStart).map((quote) => quote.sourceTimestamp),
        <DateTime?>[
          DateTime.utc(2026, 8, 1, 0, 0, 0, 50),
          DateTime.utc(2026, 8, 1, 0, 0, 0, 100),
          DateTime.utc(2026, 8, 1, 0, 0, 0, 150),
          DateTime.utc(2026, 8, 1, 0, 0, 0, 150),
        ],
      );

      await subscription.cancel();
      await service.dispose();
    },
  );

  test('candle events retain UTC feed boundaries', () async {
    final hub = _RecordingHubConnection();
    final service = RealtimeMarketService(
      baseUrl: 'https://market.example.com',
      dio: Dio()..httpClientAdapter = _QuoteAdapter(),
      connectionFactory: () => hub,
    );
    const request = MarketDataRequest('XAUUSD+', 'H4');
    final candles = <MarketCandle>[];
    final subscription = service.watchCandle(request).listen(candles.add);
    await _waitUntil(
      () => hub.hasChartSubscription(request),
      'H4 chart subscription',
    );

    hub.emitCandle(time: '2026-08-21T00:00:00Z');
    await _waitUntil(() => candles.isNotEmpty, 'UTC candle event');

    expect(candles.single.time.isUtc, isTrue);
    expect(candles.single.time, DateTime.utc(2026, 8, 21));

    await subscription.cancel();
    await service.dispose();
  });

  test(
    'shares one chart subscription and unsubscribes after the last listener',
    () async {
      final hub = _RecordingHubConnection();
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: () => hub,
      );
      const request = MarketDataRequest('XAUUSD+', 'H4');

      final first = service.watchCandle(request).listen((_) {});
      await _waitUntil(
        () => hub.chartInvocationCount('SubscribeChart', request) == 1,
        'first H4 chart subscription',
      );
      final second = service.watchCandle(request).listen((_) {});
      await _flushMicrotasks();

      expect(hub.chartInvocationCount('SubscribeChart', request), 1);
      await first.cancel();
      await _flushMicrotasks();
      expect(hub.chartInvocationCount('UnsubscribeChart', request), 0);

      await second.cancel();
      await _waitUntil(
        () => hub.chartInvocationCount('UnsubscribeChart', request) == 1,
        'last-listener H4 unsubscribe',
      );

      final replacement = service.watchCandle(request).listen((_) {});
      await _waitUntil(
        () => hub.chartInvocationCount('SubscribeChart', request) == 2,
        'replacement H4 chart subscription',
      );
      await replacement.cancel();
      await service.dispose();
    },
  );

  test(
    'blocked startup retires the last listener before connection completes',
    () async {
      final hub = _RecordingHubConnection()..blockStart();
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: () => hub,
      );
      addTearDown(() async {
        hub.releaseStart();
        await service.dispose();
      });
      const request = MarketDataRequest(' xauusd+ ', 'h4');

      final first = service.watchCandle(request).listen((_) {});
      final second = service.watchCandle(request).listen((_) {});
      await hub.startEntered.future;
      var firstCancelled = false;
      var secondCancelled = false;
      unawaited(first.cancel().then((_) => firstCancelled = true));
      unawaited(second.cancel().then((_) => secondCancelled = true));
      await _flushMicrotasks();

      expect(firstCancelled, isTrue);
      expect(secondCancelled, isTrue);
      expect(
        hub.chartInvocationCount(
          'SubscribeChart',
          const MarketDataRequest('XAUUSD+', 'H4'),
        ),
        0,
      );

      hub.releaseStart();
      await _flushMicrotasks();
      expect(
        hub.chartInvocationCount(
          'SubscribeChart',
          const MarketDataRequest('XAUUSD+', 'H4'),
        ),
        0,
      );
    },
  );

  test(
    'blocked subscribe balances retirement before replacement subscribes',
    () async {
      final hub = _RecordingHubConnection();
      final subscribeGate = hub.blockNextInvocation('SubscribeChart');
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: () => hub,
      );
      addTearDown(() async {
        subscribeGate.release();
        await service.dispose();
      });
      const request = MarketDataRequest('XAUUSD+', 'H4');

      final original = service.watchCandle(request).listen((_) {});
      await subscribeGate.entered.future;
      var originalCancelled = false;
      unawaited(original.cancel().then((_) => originalCancelled = true));
      await _flushMicrotasks();
      expect(originalCancelled, isTrue);

      final replacement = service.watchCandle(request).listen((_) {});
      subscribeGate.release();
      await _flushMicrotasks(30);

      expect(hub.chartInvocations(request).map((item) => item.method), [
        'SubscribeChart',
        'UnsubscribeChart',
        'SubscribeChart',
      ]);
      await replacement.cancel();
    },
  );

  test('obsolete subscribe failure stays ownership-neutral and contained', () {
    final uncaught = <Object>[];
    runZonedGuarded(() {
      fakeAsync((async) {
        final hub = _RecordingHubConnection();
        final service = RealtimeMarketService(
          baseUrl: 'https://market.example.com',
          dio: Dio()..httpClientAdapter = _QuoteAdapter(),
          connectionFactory: () => hub,
        );
        const establishedRequest = MarketDataRequest('XAUUSD+', 'H4');
        const obsoleteRequest = MarketDataRequest('XAUUSD+', 'M5');
        final statuses = <MarketConnectionStatus>[];
        final resyncs = <int>[];
        final statusSubscription = service.statuses.listen(statuses.add);
        final resyncSubscription = service.historyResyncs.listen(resyncs.add);
        final established = service
            .watchCandle(establishedRequest)
            .listen((_) {});
        async.flushMicrotasks();
        expect(
          hub.chartInvocationCount('SubscribeChart', establishedRequest),
          1,
        );
        statuses.clear();

        final obsoleteGate = hub.blockNextInvocation('SubscribeChart');
        final obsolete = service.watchCandle(obsoleteRequest).listen((_) {});
        async.flushMicrotasks();
        expect(obsoleteGate.entered.isCompleted, isTrue);

        unawaited(obsolete.cancel());
        async.flushMicrotasks();
        obsoleteGate.fail(StateError('controlled obsolete failure'));
        async.flushMicrotasks();

        expect(hub.chartInvocationCount('SubscribeChart', obsoleteRequest), 1);
        expect(
          hub.chartInvocationCount('UnsubscribeChart', obsoleteRequest),
          1,
        );
        expect(resyncs, isEmpty);
        expect(statuses, isEmpty);

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(hub.chartInvocationCount('SubscribeChart', obsoleteRequest), 1);
        expect(resyncs, isEmpty);

        unawaited(established.cancel());
        unawaited(statusSubscription.cancel());
        unawaited(resyncSubscription.cancel());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    }, (error, stackTrace) => uncaught.add(error));

    expect(uncaught, isEmpty);
  });

  test(
    'reconnect snapshots requests while ownership mutates and resyncs once',
    () {
      fakeAsync((async) {
        final hub = _RecordingHubConnection();
        final service = RealtimeMarketService(
          baseUrl: 'https://market.example.com',
          dio: Dio()..httpClientAdapter = _QuoteAdapter(),
          connectionFactory: () => hub,
        );
        const firstRequest = MarketDataRequest('XAUUSD+', 'M5');
        const retiredRequest = MarketDataRequest('XAUUSD+', 'H1');
        const addedRequest = MarketDataRequest('XAUUSD+', 'H4');
        final first = service.watchCandle(firstRequest).listen((_) {});
        final retired = service.watchCandle(retiredRequest).listen((_) {});
        async.flushMicrotasks();
        expect(hub.hasChartSubscription(firstRequest), isTrue);
        expect(hub.hasChartSubscription(retiredRequest), isTrue);
        final resyncs = <int>[];
        final resyncSubscription = service.historyResyncs.listen(resyncs.add);
        final reconnectGate = hub.blockNextInvocation('SubscribeChart');

        hub.triggerReconnected();
        async.flushMicrotasks();
        expect(reconnectGate.entered.isCompleted, isTrue);
        unawaited(retired.cancel());
        final added = service.watchCandle(addedRequest).listen((_) {});
        reconnectGate.release();
        async.flushMicrotasks();

        expect(resyncs, isEmpty);
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(resyncs, [1]);
        expect(hub.chartInvocationCount('SubscribeChart', firstRequest), 2);
        expect(hub.chartInvocationCount('SubscribeChart', retiredRequest), 1);
        // The retired request belonged only to the disconnected session and
        // was never subscribed on the replacement connection.
        expect(hub.chartInvocationCount('UnsubscribeChart', retiredRequest), 0);
        expect(hub.chartInvocationCount('SubscribeChart', addedRequest), 1);

        unawaited(added.cancel());
        unawaited(first.cancel());
        unawaited(resyncSubscription.cancel());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'dispose stops a blocked subscribe and every concurrent caller settles',
    () async {
      final hub = _RecordingHubConnection(releaseBlockedInvocationsOnStop: true)
        ..blockStop();
      final subscribeGate = hub.blockNextInvocation('SubscribeChart');
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: () => hub,
      );
      const request = MarketDataRequest('XAUUSD+', 'H4');
      final subscription = service.watchCandle(request).listen((_) {});
      await subscribeGate.entered.future;

      var firstDisposed = false;
      var secondDisposed = false;
      unawaited(service.dispose().then((_) => firstDisposed = true));
      unawaited(service.dispose().then((_) => secondDisposed = true));
      await _flushMicrotasks();

      expect(hub.stopEntered.isCompleted, isTrue);
      expect(hub.stopCount, 1);
      expect(firstDisposed, isFalse);
      expect(secondDisposed, isFalse);
      expect(hub.pendingInvocationCount, 0);

      final rejectedCandleDone = Completer<void>();
      final rejectedQuoteDone = Completer<void>();
      service
          .watchCandle(const MarketDataRequest('BTCUSD', 'M1'))
          .listen((_) {}, onDone: rejectedCandleDone.complete);
      service
          .watchQuote(
            'BTCUSD',
            const DemoQuote(
              symbol: 'BTCUSD',
              name: 'Bitcoin',
              bid: 62000,
              ask: 62010,
              changePercent: 0,
            ),
          )
          .listen((_) {}, onDone: rejectedQuoteDone.complete);
      await _flushMicrotasks();
      expect(rejectedCandleDone.isCompleted, isTrue);
      expect(rejectedQuoteDone.isCompleted, isTrue);
      expect(
        hub.chartInvocationCount(
          'SubscribeChart',
          const MarketDataRequest('BTCUSD', 'M1'),
        ),
        0,
      );

      hub.releaseStop();
      await _flushUntil(
        () => firstDisposed && secondDisposed,
        'both dispose callers',
      );
      expect(hub.stopCount, 1);
      await subscription.cancel();
    },
  );

  test(
    'reconnect and restart share one recovery per connection generation',
    () {
      fakeAsync((async) {
        final hub = _RecordingHubConnection();
        final service = RealtimeMarketService(
          baseUrl: 'https://market.example.com',
          dio: Dio()..httpClientAdapter = _QuoteAdapter(),
          connectionFactory: () => hub,
        );
        const request = MarketDataRequest('XAUUSD+', 'H4');
        final subscription = service.watchCandle(request).listen((_) {});
        final resyncs = <int>[];
        final resyncSubscription = service.historyResyncs.listen(resyncs.add);
        async.flushMicrotasks();
        expect(hub.chartInvocationCount('SubscribeChart', request), 1);

        hub.triggerClosed();
        final reconnectGate = hub.blockNextInvocation('SubscribeChart');
        hub.triggerReconnected();
        async.flushMicrotasks();
        expect(reconnectGate.entered.isCompleted, isTrue);

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        reconnectGate.release();
        async.flushMicrotasks();

        expect(hub.chartInvocationCount('SubscribeChart', request), 2);
        expect(resyncs, [1]);

        hub.triggerClosed();
        hub.restoreConnectedWithoutCallback();
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(hub.chartInvocationCount('SubscribeChart', request), 2);
        expect(resyncs, [1]);

        hub.triggerReconnected();
        async.flushMicrotasks();
        expect(hub.chartInvocationCount('SubscribeChart', request), 3);
        expect(resyncs, [1, 2]);

        unawaited(subscription.cancel());
        unawaited(resyncSubscription.cancel());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'failed owned recovery retries before one successful resync is memoized',
    () {
      fakeAsync((async) {
        final hub = _RecordingHubConnection();
        final service = RealtimeMarketService(
          baseUrl: 'https://market.example.com',
          dio: Dio()..httpClientAdapter = _QuoteAdapter(),
          connectionFactory: () => hub,
        );
        const request = MarketDataRequest('XAUUSD+', 'H4');
        final subscription = service.watchCandle(request).listen((_) {});
        final resyncs = <int>[];
        final resyncSubscription = service.historyResyncs.listen(resyncs.add);
        async.flushMicrotasks();
        expect(hub.chartInvocationCount('SubscribeChart', request), 1);

        hub.triggerClosed();
        hub.failInvocation(
          'SubscribeChart',
          StateError('controlled subscribe failure'),
        );
        hub.triggerReconnected();
        async.flushMicrotasks();

        expect(hub.chartInvocationCount('SubscribeChart', request), 2);
        expect(resyncs, isEmpty);

        hub.clearInvocationFailure('SubscribeChart');
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(hub.chartInvocationCount('SubscribeChart', request), 3);
        expect(resyncs, [1]);

        hub.triggerClosed();
        hub.restoreConnectedWithoutCallback();
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(hub.chartInvocationCount('SubscribeChart', request), 3);
        expect(resyncs, [1]);

        unawaited(subscription.cancel());
        unawaited(resyncSubscription.cancel());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test('failed activation invalidates generation success before retry', () {
    fakeAsync((async) {
      final hub = _RecordingHubConnection();
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: () => hub,
      );
      const establishedRequest = MarketDataRequest('XAUUSD+', 'H4');
      const failedRequest = MarketDataRequest('XAUUSD+', 'M5');
      final established = service
          .watchCandle(establishedRequest)
          .listen((_) {});
      final resyncs = <int>[];
      final resyncSubscription = service.historyResyncs.listen(resyncs.add);
      async.flushMicrotasks();
      expect(hub.chartInvocationCount('SubscribeChart', establishedRequest), 1);

      hub.failInvocation(
        'SubscribeChart',
        StateError('controlled activation failure'),
      );
      final failed = service.watchCandle(failedRequest).listen((_) {});
      async.flushMicrotasks();
      expect(hub.chartInvocationCount('SubscribeChart', failedRequest), 1);

      hub.clearInvocationFailure('SubscribeChart');
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      expect(hub.chartInvocationCount('SubscribeChart', failedRequest), 2);
      expect(resyncs, [1]);

      unawaited(failed.cancel());
      unawaited(established.cancel());
      unawaited(resyncSubscription.cancel());
      unawaited(service.dispose());
      async.flushMicrotasks();
    });
  });

  test(
    'failed activation invalidates an in-flight same-generation recovery',
    () {
      fakeAsync((async) {
        final hub = _RecordingHubConnection();
        final service = RealtimeMarketService(
          baseUrl: 'https://market.example.com',
          dio: Dio()..httpClientAdapter = _QuoteAdapter(),
          connectionFactory: () => hub,
        );
        const establishedRequest = MarketDataRequest('XAUUSD+', 'H4');
        const failedRequest = MarketDataRequest('XAUUSD+', 'M5');
        final statuses = <MarketConnectionStatus>[];
        final resyncs = <int>[];
        final statusSubscription = service.statuses.listen(statuses.add);
        final resyncSubscription = service.historyResyncs.listen(resyncs.add);
        final established = service
            .watchCandle(establishedRequest)
            .listen((_) {});
        async.flushMicrotasks();
        expect(
          hub.chartInvocationCount('SubscribeChart', establishedRequest),
          1,
        );
        statuses.clear();

        hub.triggerClosed();
        final recoveryGate = hub.blockNextInvocation('SubscribeChart');
        hub.triggerReconnected();
        async.flushMicrotasks();
        expect(recoveryGate.entered.isCompleted, isTrue);

        hub.failInvocation(
          'SubscribeChart',
          StateError('controlled activation failure'),
        );
        final failed = service.watchCandle(failedRequest).listen((_) {});
        async.flushMicrotasks();
        expect(hub.chartInvocationCount('SubscribeChart', failedRequest), 1);

        hub.clearInvocationFailure('SubscribeChart');
        recoveryGate.release();
        async.flushMicrotasks();

        expect(resyncs, isEmpty);
        expect(
          statuses.where(
            (status) => status == MarketConnectionStatus.connected,
          ),
          isEmpty,
        );

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(hub.chartInvocationCount('SubscribeChart', failedRequest), 2);
        expect(resyncs, [1]);
        expect(
          statuses
              .where((status) => status == MarketConnectionStatus.connected)
              .length,
          1,
        );

        hub.triggerClosed();
        hub.restoreConnectedWithoutCallback();
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(hub.chartInvocationCount('SubscribeChart', failedRequest), 2);
        expect(resyncs, [1]);

        unawaited(failed.cancel());
        unawaited(established.cancel());
        unawaited(statusSubscription.cancel());
        unawaited(resyncSubscription.cancel());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'stale invalidation cannot regress or retry a newer recovered generation',
    () {
      fakeAsync((async) {
        final quoteAdapter = _QuoteAdapter();
        final hub = _RecordingHubConnection();
        final service = RealtimeMarketService(
          baseUrl: 'https://market.example.com',
          dio: Dio()..httpClientAdapter = quoteAdapter,
          connectionFactory: () => hub,
        );
        const fallback = DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 4000,
          ask: 4000.2,
          changePercent: 0,
        );
        const addedRequest = MarketDataRequest('XAUUSD+', 'H4');
        final statuses = <MarketConnectionStatus>[];
        final resyncs = <int>[];
        final statusSubscription = service.statuses.listen(statuses.add);
        final resyncSubscription = service.historyResyncs.listen(resyncs.add);
        final quoteSubscription = service
            .watchQuote('XAUUSD+', fallback)
            .listen((_) {});
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(hub.hasSymbolSubscription('XAUUSD+'), isTrue);
        statuses.clear();

        final staleRefresh = quoteAdapter.blockNextFetch();
        hub.triggerReconnected();
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(staleRefresh.entered.isCompleted, isTrue);

        hub.triggerReconnected();
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(resyncs, [1]);

        staleRefresh.release();
        async.flushMicrotasks();
        final addedSubscription = service
            .watchCandle(addedRequest)
            .listen((_) {});
        async.flushMicrotasks();
        expect(hub.chartInvocationCount('SubscribeChart', addedRequest), 1);

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(
          statuses.where(
            (status) => status == MarketConnectionStatus.reconnecting,
          ),
          isEmpty,
        );
        expect(resyncs, [1]);

        unawaited(addedSubscription.cancel());
        unawaited(quoteSubscription.cancel());
        unawaited(statusSubscription.cancel());
        unawaited(resyncSubscription.cancel());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'hub close invalidates recovery before quote status or resync publish',
    () {
      fakeAsync((async) {
        final quoteAdapter = _QuoteAdapter();
        final hub = _RecordingHubConnection();
        final service = RealtimeMarketService(
          baseUrl: 'https://market.example.com',
          dio: Dio()..httpClientAdapter = quoteAdapter,
          connectionFactory: () => hub,
        );
        const fallback = DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 4000,
          ask: 4000.2,
          changePercent: 0,
        );
        final quotes = <DemoQuote>[];
        final statuses = <MarketConnectionStatus>[];
        final resyncs = <int>[];
        final statusSubscription = service.statuses.listen(statuses.add);
        final resyncSubscription = service.historyResyncs.listen(resyncs.add);
        final quoteSubscription = service
            .watchQuote('XAUUSD+', fallback)
            .listen(quotes.add);
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(statuses.last, MarketConnectionStatus.connected);
        quotes.clear();
        statuses.clear();

        final closedRefresh = quoteAdapter.blockNextFetch();
        hub.triggerReconnected();
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(closedRefresh.entered.isCompleted, isTrue);

        hub.triggerClosed();
        async.flushMicrotasks();
        closedRefresh.release();
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();

        expect(quotes, isEmpty);
        expect(resyncs, isEmpty);
        expect(
          statuses.where(
            (status) => status == MarketConnectionStatus.connected,
          ),
          isEmpty,
        );

        hub.triggerReconnected();
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(quotes, hasLength(1));
        expect(resyncs, [1]);
        expect(
          statuses
              .where((status) => status == MarketConnectionStatus.connected)
              .length,
          1,
        );

        unawaited(quoteSubscription.cancel());
        unawaited(statusSubscription.cancel());
        unawaited(resyncSubscription.cancel());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'recovery records stay bounded while dispose awaits a pruned flight',
    () {
      fakeAsync((async) {
        final quoteAdapter = _QuoteAdapter();
        final hub = _RecordingHubConnection();
        final service = RealtimeMarketService(
          baseUrl: 'https://market.example.com',
          dio: Dio()..httpClientAdapter = quoteAdapter,
          connectionFactory: () => hub,
        );
        const fallback = DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 4000,
          ask: 4000.2,
          changePercent: 0,
        );
        final quoteSubscription = service
            .watchQuote('XAUUSD+', fallback)
            .listen((_) {});
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(service.debugRecoveryRecordCount, lessThanOrEqualTo(1));

        for (var generation = 0; generation < 12; generation++) {
          hub.triggerReconnected();
          async.flushMicrotasks();
          async.elapse(Duration.zero);
          async.flushMicrotasks();
          expect(service.debugRecoveryRecordCount, lessThanOrEqualTo(1));
        }

        hub.failInvocation(
          'SubscribeSymbols',
          StateError('controlled recovery failure'),
        );
        hub.triggerReconnected();
        async.flushMicrotasks();
        expect(service.debugRecoveryRecordCount, 0);
        hub.clearInvocationFailure('SubscribeSymbols');
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(service.debugRecoveryRecordCount, lessThanOrEqualTo(1));

        final staleRefresh = quoteAdapter.blockNextFetch();
        hub.triggerReconnected();
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(staleRefresh.entered.isCompleted, isTrue);

        hub.triggerReconnected();
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(service.debugRecoveryRecordCount, lessThanOrEqualTo(1));

        var disposed = false;
        unawaited(service.dispose().then((_) => disposed = true));
        async.flushMicrotasks();
        expect(disposed, isFalse);

        staleRefresh.release();
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(disposed, isTrue);

        unawaited(quoteSubscription.cancel());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'candle stream created before dispose cannot acquire on late listen',
    () async {
      final hub = _RecordingHubConnection();
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: () => hub,
      );
      const request = MarketDataRequest('XAUUSD+', 'H4');
      final delayedStream = service.watchCandle(request);

      await service.dispose();
      final done = Completer<void>();
      final subscription = delayedStream.listen((_) {}, onDone: done.complete);
      addTearDown(subscription.cancel);
      await _flushMicrotasks();

      expect(done.isCompleted, isTrue);
      expect(hub.chartInvocationCount('SubscribeChart', request), 0);
    },
  );

  test(
    'paused candle consumer cannot block concurrent dispose callers',
    () async {
      final uncaught = <Object>[];
      final hub = _RecordingHubConnection();
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: () => hub,
      );
      const request = MarketDataRequest('XAUUSD+', 'H4');
      final subscription = service.watchCandle(request).listen((_) {});
      addTearDown(() async {
        await subscription.cancel();
        await service.dispose();
      });
      await _flushUntil(
        () => hub.hasChartSubscription(request),
        'paused candle ownership',
      );
      subscription.pause();
      var firstDisposed = false;
      var secondDisposed = false;

      final observed = Completer<void>();
      runZonedGuarded(() {
        unawaited(service.dispose().then((_) => firstDisposed = true));
        unawaited(service.dispose().then((_) => secondDisposed = true));
        unawaited(_flushMicrotasks(30).then((_) => observed.complete()));
      }, (error, stackTrace) => uncaught.add(error));
      await observed.future;

      expect(firstDisposed, isTrue);
      expect(secondDisposed, isTrue);
      expect(uncaught, isEmpty);
      await subscription.cancel();
      await service.dispose();
    },
  );

  test(
    'paused quote consumer cannot block concurrent dispose callers',
    () async {
      final uncaught = <Object>[];
      final hub = _RecordingHubConnection();
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: () => hub,
      );
      const fallback = DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4000,
        ask: 4000.2,
        changePercent: 0,
      );
      final subscribed = hub.nextInvocation('SubscribeSymbols');
      final subscription = service
          .watchQuote('XAUUSD+', fallback)
          .listen((_) {});
      addTearDown(() async {
        await subscription.cancel();
        await service.dispose();
      });
      await subscribed;
      subscription.pause();
      var firstDisposed = false;
      var secondDisposed = false;

      final observed = Completer<void>();
      runZonedGuarded(() {
        unawaited(service.dispose().then((_) => firstDisposed = true));
        unawaited(service.dispose().then((_) => secondDisposed = true));
        unawaited(_flushMicrotasks(30).then((_) => observed.complete()));
      }, (error, stackTrace) => uncaught.add(error));
      await observed.future;

      expect(firstDisposed, isTrue);
      expect(secondDisposed, isTrue);
      expect(uncaught, isEmpty);
      await subscription.cancel();
      await service.dispose();
    },
  );

  test(
    'paused status consumer cannot block concurrent dispose callers',
    () async {
      final uncaught = <Object>[];
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: _RecordingHubConnection.new,
      );
      final subscription = service.statuses.listen((_) {});
      addTearDown(() async {
        await subscription.cancel();
        await service.dispose();
      });
      await _flushMicrotasks();
      subscription.pause();
      var firstDisposed = false;
      var secondDisposed = false;

      final observed = Completer<void>();
      runZonedGuarded(() {
        unawaited(service.dispose().then((_) => firstDisposed = true));
        unawaited(service.dispose().then((_) => secondDisposed = true));
        unawaited(_flushMicrotasks(30).then((_) => observed.complete()));
      }, (error, stackTrace) => uncaught.add(error));
      await observed.future;

      expect(firstDisposed, isTrue);
      expect(secondDisposed, isTrue);
      expect(uncaught, isEmpty);
      await subscription.cancel();
      await service.dispose();
    },
  );

  test(
    'paused history resync consumer cannot block concurrent dispose callers',
    () async {
      final uncaught = <Object>[];
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: _RecordingHubConnection.new,
      );
      final subscription = service.historyResyncs.listen((_) {});
      addTearDown(() async {
        await subscription.cancel();
        await service.dispose();
      });
      await _flushMicrotasks();
      subscription.pause();
      var firstDisposed = false;
      var secondDisposed = false;

      final observed = Completer<void>();
      runZonedGuarded(() {
        unawaited(service.dispose().then((_) => firstDisposed = true));
        unawaited(service.dispose().then((_) => secondDisposed = true));
        unawaited(_flushMicrotasks(30).then((_) => observed.complete()));
      }, (error, stackTrace) => uncaught.add(error));
      await observed.future;

      expect(firstDisposed, isTrue);
      expect(secondDisposed, isTrue);
      expect(uncaught, isEmpty);
      await subscription.cancel();
      await service.dispose();
    },
  );

  test(
    'detached symbol cleanup contains invoke errors and releases ownership',
    () async {
      final uncaught = <Object>[];
      final hub = _RecordingHubConnection()
        ..failInvocation(
          'UnsubscribeSymbols',
          StateError('unsubscribe failed'),
        );
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: () => hub,
      );
      const fallback = DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4000,
        ask: 4000.2,
        changePercent: 0,
      );

      final zoneBodyDone = Completer<void>();
      final initialSubscribed = hub.nextInvocation('SubscribeSymbols');
      runZonedGuarded(() {
        unawaited(() async {
          try {
            final first = service
                .watchQuote('XAUUSD+', fallback)
                .listen((_) {});
            await initialSubscribed;
            await first.cancel();
            await _flushMicrotasks();

            hub.clearInvocationFailure('UnsubscribeSymbols');
            final replacementSubscribed = hub.nextInvocation(
              'SubscribeSymbols',
            );
            final replacement = service
                .watchQuote('XAUUSD+', fallback)
                .listen((_) {});
            await replacementSubscribed;
            await replacement.cancel();
            await _flushMicrotasks();
            await service.dispose();
          } finally {
            zoneBodyDone.complete();
          }
        }());
      }, (error, stackTrace) => uncaught.add(error));
      await zoneBodyDone.future;

      expect(uncaught, isEmpty);
      expect(hub.symbolInvocationCount('UnsubscribeSymbols'), 2);
    },
  );

  test(
    'detached dispose contains stop errors and closes candle ownership',
    () async {
      final uncaught = <Object>[];
      final hub = _RecordingHubConnection(stopError: StateError('stop failed'));
      final service = RealtimeMarketService(
        baseUrl: 'https://market.example.com',
        dio: Dio()..httpClientAdapter = _QuoteAdapter(),
        connectionFactory: () => hub,
      );
      const request = MarketDataRequest('XAUUSD+', 'H4');
      final candleDone = Completer<void>();
      service.watchCandle(request).listen((_) {}, onDone: candleDone.complete);
      await _flushUntil(
        () => hub.hasChartSubscription(request),
        'owned candle request',
      );
      var disposed = false;

      final zoneBodyDone = Completer<void>();
      runZonedGuarded(() {
        unawaited(() async {
          try {
            unawaited(service.dispose().then((_) => disposed = true));
            await _flushMicrotasks(30);
          } finally {
            zoneBodyDone.complete();
          }
        }());
      }, (error, stackTrace) => uncaught.add(error));
      await zoneBodyDone.future;

      expect(uncaught, isEmpty);
      expect(disposed, isTrue);
      expect(hub.stopCount, 1);
      expect(candleDone.isCompleted, isTrue);
    },
  );
}

Future<void> _flushMicrotasks([int turns = 12]) async {
  for (var index = 0; index < turns; index++) {
    await Future<void>.value();
  }
}

Future<void> _flushUntil(bool Function() condition, String description) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.value();
  }
  fail('Did not reach $description');
}

Future<void> _waitUntil(bool Function() condition, String description) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for $description');
}

class _HubInvocation {
  const _HubInvocation(this.method, this.args);

  final String method;
  final List<Object?> args;
}

class _InvocationGate {
  final Completer<void> entered = Completer<void>();
  final Completer<void> _release = Completer<void>();

  Future<void> get released => _release.future;

  void release() {
    if (!_release.isCompleted) _release.complete();
  }

  void fail(Object error) {
    if (!_release.isCompleted) _release.completeError(error);
  }
}

class _RecordingHubConnection implements HubConnection {
  _RecordingHubConnection({
    this.releaseBlockedInvocationsOnStop = false,
    this.stopError,
  });

  final bool releaseBlockedInvocationsOnStop;
  final Object? stopError;
  HubConnectionState? _state = HubConnectionState.disconnected;
  final List<_HubInvocation> invocations = [];
  final Map<String, MethodInvocationFunc> handlers = {};
  final Map<String, Queue<_InvocationGate>> _invocationGates = {};
  final Map<String, Queue<Completer<void>>> _invocationObservers = {};
  final Set<_InvocationGate> _activeInvocationGates = {};
  final Map<String, Object> _invocationFailures = {};
  final Completer<void> startEntered = Completer<void>();
  final Completer<void> stopEntered = Completer<void>();
  Completer<void>? _startRelease;
  Completer<void>? _stopRelease;
  ReconnectedCallback? _reconnected;
  ClosedCallback? _closed;
  int stopCount = 0;

  int get pendingInvocationCount => _activeInvocationGates.length;

  void blockStart() => _startRelease = Completer<void>();

  void releaseStart() {
    final release = _startRelease;
    if (release != null && !release.isCompleted) release.complete();
  }

  void blockStop() => _stopRelease = Completer<void>();

  void releaseStop() {
    final release = _stopRelease;
    if (release != null && !release.isCompleted) release.complete();
  }

  void failInvocation(String method, Object error) {
    _invocationFailures[method] = error;
  }

  void clearInvocationFailure(String method) {
    _invocationFailures.remove(method);
  }

  Future<void> nextInvocation(String method) {
    final completer = Completer<void>();
    _invocationObservers
        .putIfAbsent(method, Queue<Completer<void>>.new)
        .add(completer);
    return completer.future;
  }

  _InvocationGate blockNextInvocation(String method) {
    final gate = _InvocationGate();
    _invocationGates.putIfAbsent(method, Queue<_InvocationGate>.new).add(gate);
    return gate;
  }

  @override
  HubConnectionState? get state => _state;

  @override
  Future<void> start() async {
    if (!startEntered.isCompleted) startEntered.complete();
    final release = _startRelease;
    if (release != null) await release.future;
    _state = HubConnectionState.connected;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _state = HubConnectionState.disconnected;
    if (!stopEntered.isCompleted) stopEntered.complete();
    if (releaseBlockedInvocationsOnStop) {
      for (final gate in _activeInvocationGates.toList(growable: false)) {
        gate.fail(StateError('invocation stopped'));
      }
    }
    final release = _stopRelease;
    if (release != null) await release.future;
    final error = stopError;
    if (error != null) throw error;
  }

  @override
  Future<Object?> invoke(String methodName, {List<Object?>? args}) async {
    invocations.add(_HubInvocation(methodName, args ?? const []));
    final observers = _invocationObservers[methodName];
    if (observers != null && observers.isNotEmpty) {
      observers.removeFirst().complete();
    }
    final gates = _invocationGates[methodName];
    if (gates != null && gates.isNotEmpty) {
      final gate = gates.removeFirst();
      if (!gate.entered.isCompleted) gate.entered.complete();
      _activeInvocationGates.add(gate);
      try {
        await gate.released;
      } finally {
        _activeInvocationGates.remove(gate);
      }
    }
    final failure = _invocationFailures[methodName];
    if (failure != null) throw failure;
    return null;
  }

  @override
  void on(String methodName, MethodInvocationFunc newMethod) {
    handlers[methodName] = newMethod;
  }

  @override
  void onreconnected(ReconnectedCallback callback) => _reconnected = callback;

  @override
  void onclose(ClosedCallback callback) => _closed = callback;

  void triggerReconnected() {
    _state = HubConnectionState.connected;
    _reconnected?.call(connectionId: 'reconnected');
  }

  void triggerClosed() {
    _state = HubConnectionState.disconnected;
    _closed?.call(error: StateError('connection closed'));
  }

  void restoreConnectedWithoutCallback() {
    _state = HubConnectionState.connected;
  }

  void emitQuote({required double bid, required String timestamp}) {
    handlers['QuoteUpdated']?.call([
      <String, Object?>{
        'symbol': 'XAUUSD+',
        'bid': bid,
        'ask': bid + .2,
        'timestamp': timestamp,
      },
    ]);
  }

  void emitCandle({required String time}) {
    handlers['CandleUpdated']?.call([
      <String, Object?>{
        'symbol': 'XAUUSD+',
        'timeframe': 'H4',
        'time': time,
        'open': 4526.34,
        'high': 4527.47,
        'low': 4508.61,
        'close': 4526.21,
        'volume': 14069,
      },
    ]);
  }

  bool hasSymbolSubscription(String symbol) => invocations.any((invocation) {
    if (invocation.method != 'SubscribeSymbols' || invocation.args.isEmpty) {
      return false;
    }
    final symbols = invocation.args.first;
    return symbols is List && symbols.contains(symbol);
  });

  bool hasChartSubscription(MarketDataRequest request) => invocations.any(
    (invocation) =>
        invocation.method == 'SubscribeChart' &&
        invocation.args.length == 2 &&
        invocation.args[0] == request.symbol &&
        invocation.args[1] == request.timeframe,
  );

  int chartInvocationCount(String method, MarketDataRequest request) =>
      invocations
          .where(
            (invocation) =>
                invocation.method == method &&
                invocation.args.length == 2 &&
                invocation.args[0] == request.symbol &&
                invocation.args[1] == request.timeframe,
          )
          .length;

  int symbolInvocationCount(String method) =>
      invocations.where((invocation) => invocation.method == method).length;

  Iterable<_HubInvocation> chartInvocations(MarketDataRequest request) =>
      invocations.where(
        (invocation) =>
            (invocation.method == 'SubscribeChart' ||
                invocation.method == 'UnsubscribeChart') &&
            invocation.args.length == 2 &&
            invocation.args[0] == request.symbol &&
            invocation.args[1] == request.timeframe,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _QuoteAdapter implements HttpClientAdapter {
  final Queue<_InvocationGate> _fetchGates = Queue<_InvocationGate>();

  _InvocationGate blockNextFetch() {
    final gate = _InvocationGate();
    _fetchGates.add(gate);
    return gate;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_fetchGates.isNotEmpty) {
      final gate = _fetchGates.removeFirst();
      if (!gate.entered.isCompleted) gate.entered.complete();
      await gate.released;
    }
    final symbol = Uri.decodeComponent(options.uri.pathSegments.last);
    final bid = symbol == 'BTCUSD' ? 62000.0 : 4000.0;
    return ResponseBody.fromString(
      jsonEncode({
        'symbol': symbol,
        'bid': bid,
        'ask': bid + .2,
        'timestamp': '2026-08-01T00:00:00Z',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
