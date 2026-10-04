import 'package:exness/features/trading/data/market_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_hub/signalr_client.dart';

void main() {
  test(
    'a newer hub tick updates its quote without changing other symbols',
    () async {
      final hub = _Hub();
      final feed = MarketQuoteFeed(
        loadQuotes: () async => [
          _quote('XAUUSD+', 4300, '2026-09-19T10:00:00Z'),
          _quote('BTCUSD', 80000, '2026-09-19T10:00:00Z'),
        ],
        connectionFactory: () => hub,
      );
      final states = <MarketFeedState>[];
      final subscription = feed.watch().listen(states.add);
      await _until(
        () => states.any((state) => state.status == MarketFeedStatus.connected),
      );

      expect(hub.subscribedSymbols, containsAll(['XAUUSD+', 'BTCUSD']));
      final btcBefore = states.last.quoteFor('BTCUSD');
      hub.emitQuote('XAUUSD+', 4301, '2026-09-19T10:00:01Z');
      await _until(() => states.last.quoteFor('XAUUSD+')?.bid == 4301);
      expect(states.last.quoteFor('BTCUSD'), same(btcBefore));

      hub.emitQuote('XAUUSD+', 4299, '2026-09-19T09:59:59Z');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(states.last.quoteFor('XAUUSD+')?.bid, 4301);

      await subscription.cancel();
      expect(hub.stopCalls, 1);
    },
  );

  test('reconnect resubscribes symbols and reports connection state', () async {
    final hub = _Hub();
    final feed = MarketQuoteFeed(
      loadQuotes: () async => [_quote('XAUUSD+', 4300, '2026-09-19T10:00:00Z')],
      connectionFactory: () => hub,
    );
    final states = <MarketFeedState>[];
    final subscription = feed.watch().listen(states.add);
    await _until(
      () =>
          states.isNotEmpty && states.last.status == MarketFeedStatus.connected,
    );
    expect(hub.subscribeCalls, 1);

    hub.reconnecting();
    await _until(() => states.last.status == MarketFeedStatus.reconnecting);
    expect(states.last.status, MarketFeedStatus.reconnecting);
    hub.reconnected();
    await _until(
      () =>
          hub.subscribeCalls == 2 &&
          states.last.status == MarketFeedStatus.connected,
    );
    expect(states.last.status, MarketFeedStatus.connected);

    await subscription.cancel();
  });

  test('reconnect subscribes symbols added by the refreshed catalog', () async {
    final hub = _Hub();
    var loads = 0;
    final feed = MarketQuoteFeed(
      loadQuotes: () async {
        loads++;
        return [
          _quote('XAUUSD+', 4300, '2026-09-19T10:00:00Z'),
          if (loads > 2) _quote('EURUSD', 1.2, '2026-09-19T10:00:01Z'),
        ];
      },
      connectionFactory: () => hub,
    );
    final states = <MarketFeedState>[];
    final subscription = feed.watch().listen(states.add);
    await _until(
      () =>
          states.isNotEmpty && states.last.status == MarketFeedStatus.connected,
    );

    hub.reconnected();
    await _until(() => states.last.quoteFor('EURUSD') != null);
    expect(hub.subscribedSymbols, contains('EURUSD'));

    await subscription.cancel();
  });

  test('a quote becomes stale while the hub remains connected', () async {
    final hub = _Hub();
    var now = DateTime.utc(2026, 9, 19, 10);
    final feed = MarketQuoteFeed(
      loadQuotes: () async => [_quote('XAUUSD+', 4300, '2026-09-19T10:00:00Z')],
      connectionFactory: () => hub,
      now: () => now,
      freshnessInterval: const Duration(milliseconds: 10),
    );
    final states = <MarketFeedState>[];
    final subscription = feed.watch().listen(states.add);
    await _until(
      () => states.any((state) => state.status == MarketFeedStatus.connected),
    );
    expect(states.last.isStale('XAUUSD+'), isFalse);

    now = now.add(const Duration(seconds: 6));
    await _until(() => states.last.isStale('XAUUSD+'));
    expect(states.last.status, MarketFeedStatus.connected);
    await subscription.cancel();
  });

  test('manual reconnect reloads missed prices after subscribing', () async {
    final hub = _Hub();
    var bid = 4300.0;
    var loads = 0;
    final feed = MarketQuoteFeed(
      loadQuotes: () async {
        loads++;
        return [_quote('XAUUSD+', bid, '2026-09-19T10:00:0${loads}Z')];
      },
      connectionFactory: () => hub,
    );
    final states = <MarketFeedState>[];
    final subscription = feed.watch().listen(states.add);
    await _until(
      () => states.any((state) => state.status == MarketFeedStatus.connected),
    );
    expect(loads, 2);

    bid = 4301;
    hub.close();
    await _until(() => states.last.status == MarketFeedStatus.disconnected);
    await _until(
      () => hub.startCalls == 2,
      timeout: const Duration(seconds: 5),
    );
    await _until(() => states.last.quoteFor('XAUUSD+')?.bid == 4301);
    expect(hub.subscribeCalls, 2);
    await subscription.cancel();
  });
}

MarketQuote _quote(String symbol, double bid, String timestamp) => MarketQuote(
  symbol: symbol,
  bid: bid,
  ask: bid + 0.2,
  timestamp: DateTime.parse(timestamp),
  source: 'test',
);

Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  for (var attempt = 0; attempt < timeout.inMilliseconds ~/ 10; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('condition did not become true');
}

final class _Hub implements HubConnection {
  final handlers = <String, MethodInvocationFunc>{};
  ReconnectingCallback? onReconnecting;
  ReconnectedCallback? onReconnected;
  ClosedCallback? onClosed;
  HubConnectionState? _state = HubConnectionState.disconnected;
  int subscribeCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  List<String> subscribedSymbols = const [];

  @override
  HubConnectionState? get state => _state;

  @override
  void on(String methodName, MethodInvocationFunc handler) {
    handlers[methodName] = handler;
  }

  @override
  void onreconnecting(ReconnectingCallback callback) =>
      onReconnecting = callback;

  @override
  void onreconnected(ReconnectedCallback callback) => onReconnected = callback;

  @override
  void onclose(ClosedCallback callback) => onClosed = callback;

  @override
  Future<void> start() async {
    startCalls++;
    _state = HubConnectionState.connected;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _state = HubConnectionState.disconnected;
  }

  @override
  Future<Object?> invoke(String methodName, {List<Object?>? args}) async {
    if (methodName == 'SubscribeSymbols') {
      subscribeCalls++;
      subscribedSymbols = (args!.single as List).cast<String>();
    }
    return null;
  }

  void emitQuote(String symbol, double bid, String timestamp) {
    handlers['QuoteUpdated']?.call([
      {
        'symbol': symbol,
        'bid': bid,
        'ask': bid + 0.2,
        'timestamp': timestamp,
        'source': 'test',
      },
    ]);
  }

  void reconnecting() => onReconnecting?.call(error: StateError('offline'));

  void reconnected() {
    _state = HubConnectionState.connected;
    onReconnected?.call(connectionId: 'new-connection');
  }

  void close() {
    _state = HubConnectionState.disconnected;
    onClosed?.call(error: StateError('offline'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
