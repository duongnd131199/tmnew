import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_hub/signalr_client.dart';

const marketApiBaseUrl = String.fromEnvironment(
  'MARKET_API_BASE_URL',
  defaultValue: 'https://trochoi.top',
);

String marketSymbol(String label) => switch (label.toUpperCase()) {
  'XAU/USD' || 'XAUUSD' => 'XAUUSD+',
  'BTC' => 'BTCUSD',
  'ETH' => 'ETHUSD',
  _ => label.toUpperCase().replaceAll('/', ''),
};

String marketLabel(String symbol) => switch (symbol.toUpperCase()) {
  'XAUUSD+' => 'XAU/USD',
  'BTCUSD' => 'BTC',
  'ETHUSD' => 'ETH',
  _ => symbol,
};

final class MarketQuote {
  const MarketQuote({
    required this.symbol,
    required this.bid,
    required this.ask,
    required this.timestamp,
    required this.source,
  });

  factory MarketQuote.fromJson(Map<String, dynamic> json) => MarketQuote(
    symbol: _string(json, 'symbol'),
    bid: _number(json, 'bid'),
    ask: _number(json, 'ask'),
    timestamp: _date(json, 'timestamp'),
    source: _string(json, 'source'),
  );

  final String symbol;
  final double bid;
  final double ask;
  final DateTime timestamp;
  final String source;

  double get mid => (bid + ask) / 2;
}

final class MarketCandle {
  const MarketCandle({
    required this.symbol,
    required this.timeframe,
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory MarketCandle.fromJson(Map<String, dynamic> json) => MarketCandle(
    symbol: _string(json, 'symbol'),
    timeframe: _string(json, 'timeframe'),
    time: _date(json, 'time'),
    open: _number(json, 'open'),
    high: _number(json, 'high'),
    low: _number(json, 'low'),
    close: _number(json, 'close'),
    volume: _number(json, 'volume'),
  );

  final String symbol;
  final String timeframe;
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  bool get isDown => close < open;
}

final class MarketApi {
  const MarketApi(this._dio);

  final Dio _dio;

  Future<List<MarketQuote>> quotes() async {
    final response = await _dio.get<dynamic>('/api/market/quotes');
    final data = response.data;
    if (data is! List) throw const FormatException('Expected quote array');
    return data.map((item) => MarketQuote.fromJson(_map(item))).toList();
  }

  Future<List<MarketCandle>> candles(
    String symbol, {
    String timeframe = 'M1',
    int limit = 200,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/market/candles',
      queryParameters: {
        'symbol': marketSymbol(symbol),
        'timeframe': timeframe,
        'limit': limit,
      },
    );
    final data = response.data;
    if (data is! List) throw const FormatException('Expected candle array');
    final candles = data
        .map((item) => MarketCandle.fromJson(_map(item)))
        .toList();
    candles.sort((a, b) => a.time.compareTo(b.time));
    return candles;
  }
}

enum MarketFeedStatus { connecting, connected, reconnecting, disconnected }

final class MarketFeedState {
  const MarketFeedState({
    required this.quotes,
    required this.status,
    this.loadError = false,
    this.staleSymbols = const {},
  });

  final List<MarketQuote> quotes;
  final MarketFeedStatus status;
  final bool loadError;
  final Set<String> staleSymbols;

  bool isStale(String symbol) => staleSymbols.contains(symbol);

  MarketQuote? quoteFor(String symbol) {
    for (final quote in quotes) {
      if (quote.symbol == symbol) return quote;
    }
    return null;
  }
}

final class MarketQuoteFeed {
  MarketQuoteFeed({
    required this.loadQuotes,
    required this.connectionFactory,
    this.defaultSymbols = const ['XAUUSD+', 'BTCUSD', 'ETHUSD'],
    DateTime Function()? now,
    this.maxQuoteAge = const Duration(seconds: 5),
    this.freshnessInterval = const Duration(seconds: 1),
  }) : now = now ?? DateTime.now;

  final Future<List<MarketQuote>> Function() loadQuotes;
  final HubConnection Function() connectionFactory;
  final List<String> defaultSymbols;
  final DateTime Function() now;
  final Duration maxQuoteAge;
  final Duration freshnessInterval;

  final _quotes = <String, MarketQuote>{};
  StreamController<MarketFeedState>? _states;
  HubConnection? _connection;
  Timer? _retry;
  Timer? _freshnessTimer;
  Set<String> _lastStaleSymbols = const {};
  MarketFeedStatus _status = MarketFeedStatus.connecting;
  bool _loadError = false;
  bool _connecting = false;
  bool _disposed = false;

  Stream<MarketFeedState> watch() {
    if (_states != null) {
      throw StateError('Market quote feed is already watched');
    }
    _states = StreamController<MarketFeedState>(
      onListen: () {
        _freshnessTimer = Timer.periodic(freshnessInterval, (_) {
          final stale = _staleSymbols();
          if (stale.length != _lastStaleSymbols.length ||
              !stale.containsAll(_lastStaleSymbols)) {
            _publish();
          }
        });
        unawaited(_start());
      },
      onCancel: dispose,
    );
    return _states!.stream;
  }

  Future<void> _start() async {
    await _reload();
    await _connect();
  }

  Future<void> _reload() async {
    try {
      final snapshot = await loadQuotes();
      if (_disposed) return;
      for (final quote in snapshot) {
        final old = _quotes[quote.symbol];
        if (old == null || !quote.timestamp.isBefore(old.timestamp)) {
          _quotes[quote.symbol] = quote;
        }
      }
      _loadError = false;
    } catch (_) {
      if (_disposed) return;
      _loadError = true;
    }
    _publish();
  }

  Future<void> _connect() async {
    if (_disposed || _connecting) return;
    _connecting = true;
    try {
      final connection = _connection ??= _buildConnection();
      if (connection.state != HubConnectionState.connected) {
        _status = _quotes.isEmpty
            ? MarketFeedStatus.connecting
            : MarketFeedStatus.reconnecting;
        _publish();
        await connection.start();
      }
      if (_disposed) return;
      final subscribed = {...defaultSymbols, ..._quotes.keys};
      await _subscribe();
      await _reload();
      if (_disposed) return;
      await _subscribeNewSymbolsAfterReload(subscribed);
      if (_disposed) return;
      _retry?.cancel();
      _status = MarketFeedStatus.connected;
      _publish();
    } catch (_) {
      if (_disposed) return;
      _status = MarketFeedStatus.disconnected;
      _publish();
      _scheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  HubConnection _buildConnection() {
    final connection = connectionFactory();
    connection.on('QuoteUpdated', _handleQuote);
    connection.onreconnecting(({error}) {
      if (_disposed) return;
      _status = MarketFeedStatus.reconnecting;
      _publish();
    });
    connection.onreconnected(({connectionId}) {
      if (_disposed) return;
      _status = MarketFeedStatus.reconnecting;
      _publish();
      unawaited(_resumeAfterReconnect());
    });
    connection.onclose(({error}) {
      if (_disposed) return;
      _status = MarketFeedStatus.disconnected;
      _publish();
      _scheduleRetry();
    });
    return connection;
  }

  Future<void> _resumeAfterReconnect() async {
    try {
      final subscribed = {...defaultSymbols, ..._quotes.keys};
      await _subscribe();
      await _reload();
      await _subscribeNewSymbolsAfterReload(subscribed);
      if (_disposed) return;
      _retry?.cancel();
      _status = MarketFeedStatus.connected;
      _publish();
    } catch (_) {
      if (_disposed) return;
      _status = MarketFeedStatus.disconnected;
      _publish();
      _scheduleRetry();
    }
  }

  Future<void> _subscribeNewSymbolsAfterReload(Set<String> subscribed) async {
    final added = {...defaultSymbols, ..._quotes.keys}.difference(subscribed);
    if (added.isNotEmpty && !_disposed) {
      await _connection?.invoke('SubscribeSymbols', args: [added.toList()]);
    }
  }

  Future<void> _subscribe() async {
    final symbols = {...defaultSymbols, ..._quotes.keys}.toList();
    if (symbols.isEmpty || _disposed) return;
    await _connection?.invoke('SubscribeSymbols', args: [symbols]);
  }

  void _handleQuote(List<Object?>? arguments) {
    if (_disposed || arguments == null || arguments.isEmpty) return;
    final payload = arguments.first;
    if (payload is! Map) return;
    try {
      final data = payload.cast<String, dynamic>();
      final symbol = data['symbol'];
      if (symbol is! String ||
          !{...defaultSymbols, ..._quotes.keys}.contains(symbol)) {
        return;
      }
      final quote = MarketQuote.fromJson({
        ...data,
        'source': data['source'] ?? _quotes[symbol]?.source ?? 'market',
      });
      final old = _quotes[symbol];
      if (old != null && !quote.timestamp.isAfter(old.timestamp)) return;
      _quotes[symbol] = quote;
      _loadError = false;
      _publish();
    } on FormatException {
      // Ignore a malformed event and retain the last valid price.
    } on TypeError {
      // Ignore a malformed event and retain the last valid price.
    }
  }

  void _scheduleRetry() {
    if (_disposed || _retry?.isActive == true) return;
    _retry = Timer(const Duration(seconds: 3), () => unawaited(_connect()));
  }

  void _publish() {
    if (_disposed) return;
    final stale = _staleSymbols();
    _lastStaleSymbols = stale;
    _states?.add(
      MarketFeedState(
        quotes: List.unmodifiable(_quotes.values),
        status: _status,
        loadError: _loadError,
        staleSymbols: Set.unmodifiable(stale),
      ),
    );
  }

  Set<String> _staleSymbols() {
    final current = now().toUtc();
    return {
      for (final quote in _quotes.values)
        if (current.difference(quote.timestamp) > maxQuoteAge) quote.symbol,
    };
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    _freshnessTimer?.cancel();
    await _connection?.stop();
    await _states?.close();
  }
}

final marketApiProvider = Provider<MarketApi>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: marketApiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
  ref.onDispose(() => dio.close());
  return MarketApi(dio);
});

final marketQuotesProvider = StreamProvider.autoDispose<MarketFeedState>((ref) {
  final feed = MarketQuoteFeed(
    loadQuotes: ref.watch(marketApiProvider).quotes,
    connectionFactory: () => (HubConnectionBuilder()
        .withUrl(
          '${marketApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/hubs/market',
          options: HttpConnectionOptions(
            requestTimeout: 8000,
            logMessageContent: false,
          ),
        )
        .withAutomaticReconnect(retryDelays: const [0, 1000, 2000, 5000, 10000])
        .build()),
  );
  return feed.watch();
});

final marketCandlesProvider =
    FutureProvider.family<List<MarketCandle>, (String, String)>(
      (ref, request) => ref
          .watch(marketApiProvider)
          .candles(request.$1, timeframe: request.$2),
    );

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw const FormatException('Expected JSON object');
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing $key');
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Invalid $key');
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(_string(json, key));
  if (value == null) throw FormatException('Invalid $key');
  return value.toUtc();
}
