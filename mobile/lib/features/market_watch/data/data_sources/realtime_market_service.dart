import 'dart:async';

import 'package:dio/dio.dart';
import 'package:signalr_hub/signalr_client.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

enum MarketConnectionStatus {
  connecting,
  connected,
  reconnecting,
  disconnected,
}

void guardRealtimeCleanup(Future<void> operation) {
  unawaited(operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
}

class RealtimeMarketService {
  RealtimeMarketService({
    required String baseUrl,
    Dio? dio,
    this.connectionFactory,
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 8),
             ),
           );

  final String _baseUrl;
  final HubConnection Function()? connectionFactory;
  final Dio _dio;
  final Map<String, StreamController<DemoQuote>> _quoteControllers = {};
  final Map<MarketDataRequest, _CandleRequestSlot> _candleSlots = {};
  final Map<String, DemoQuote> _quoteSeeds = {};
  final Map<String, DemoQuote> _latestQuotes = {};
  final Map<String, int> _quoteSubscribers = {};
  final StreamController<MarketConnectionStatus> _statusController =
      StreamController<MarketConnectionStatus>.broadcast();
  final StreamController<int> _historyResyncController =
      StreamController<int>.broadcast();

  HubConnection? _connection;
  Future<void>? _startFuture;
  Future<void>? _disposeFuture;
  Timer? _restartTimer;
  bool _disposed = false;
  bool _hasConnected = false;
  int _connectionGeneration = 0;
  int? _connectedSessionGeneration;
  int _candleRequestGeneration = 0;
  int _candleOwnershipEpoch = 0;
  int _recoveryFlightToken = 0;
  int _historyResyncGeneration = 0;
  final Map<int, _ConnectionRecoveryFlight> _connectionRecoveries = {};
  final Set<Future<void>> _pendingRecoverySettlements = {};
  MarketConnectionStatus _status = MarketConnectionStatus.disconnected;

  Stream<MarketConnectionStatus> get statuses async* {
    yield _status;
    yield* _statusController.stream;
  }

  Stream<int> get historyResyncs => _historyResyncController.stream;

  int get debugRecoveryRecordCount => _connectionRecoveries.length;

  Stream<DemoQuote> watchQuote(String symbol, DemoQuote fallback) async* {
    if (_disposed) return;
    final normalized = _normalizeSymbol(symbol);
    _quoteSeeds[normalized] = fallback;
    _quoteSubscribers[normalized] = (_quoteSubscribers[normalized] ?? 0) + 1;
    final controller = _quoteControllers.putIfAbsent(
      normalized,
      () => StreamController<DemoQuote>.broadcast(),
    );

    try {
      final snapshot = await _fetchQuote(normalized, fallback);
      if (snapshot != null && _acceptQuote(snapshot, publish: false)) {
        yield snapshot;
      }
      try {
        final wasConnected = _connection?.state == HubConnectionState.connected;
        await _ensureConnected();
        if (wasConnected) {
          await _subscribeSymbols([normalized]);
        }
      } catch (_) {
        // Keep the REST snapshot visible while the scheduled reconnect runs.
        _scheduleRestart();
      }
      final latest = _latestQuotes[normalized];
      if (latest != null && latest != snapshot) {
        yield latest;
      }
      yield* controller.stream;
    } finally {
      final remaining = (_quoteSubscribers[normalized] ?? 1) - 1;
      if (remaining <= 0) {
        _quoteSubscribers.remove(normalized);
        guardRealtimeCleanup(_unsubscribeSymbols([normalized]));
      } else {
        _quoteSubscribers[normalized] = remaining;
      }
    }
  }

  Stream<MarketCandle> watchCandle(MarketDataRequest request) {
    if (_disposed) return const Stream<MarketCandle>.empty();
    final normalized = MarketDataRequest(
      _normalizeSymbol(request.symbol),
      request.timeframe.toUpperCase(),
    );
    late StreamController<MarketCandle> outward;
    StreamSubscription<MarketCandle>? relay;
    _CandleRequestRecord? record;
    var released = false;

    outward = StreamController<MarketCandle>(
      sync: true,
      onListen: () {
        if (_disposed) {
          released = true;
          guardRealtimeCleanup(outward.close());
          return;
        }
        record = _acquireCandleRequest(normalized);
        final activeRecord = record!;
        relay = activeRecord.controller.stream.listen(
          outward.add,
          onError: outward.addError,
          onDone: () {
            if (!outward.isClosed) {
              guardRealtimeCleanup(outward.close());
            }
          },
        );
      },
      onPause: () => relay?.pause(),
      onResume: () => relay?.resume(),
      onCancel: () {
        if (!released) {
          released = true;
          final activeRecord = record;
          if (activeRecord != null) _releaseCandleRequest(activeRecord);
        }
        return relay?.cancel();
      },
    );
    return outward.stream;
  }

  _CandleRequestRecord _acquireCandleRequest(MarketDataRequest request) {
    final slot = _candleSlots.putIfAbsent(
      request,
      () => _CandleRequestSlot(request),
    );
    final existing = slot.active;
    if (existing != null && !existing.retired) {
      existing.listeners++;
      return existing;
    }
    final record = _CandleRequestRecord(
      slot: slot,
      generation: ++_candleRequestGeneration,
    );
    slot.active = record;
    _recordCandleOwnershipChange();
    guardRealtimeCleanup(_activateCandleRequest(record));
    return record;
  }

  void _releaseCandleRequest(_CandleRequestRecord record) {
    if (record.retired || record.listeners <= 0) return;
    record.listeners--;
    if (record.listeners == 0) _retireCandleRequest(record);
  }

  void _retireCandleRequest(_CandleRequestRecord record) {
    if (record.retired) return;
    record.retired = true;
    record.listeners = 0;
    if (identical(record.slot.active, record)) {
      record.slot.active = null;
    }
    _recordCandleOwnershipChange();
    if (!record.controller.isClosed) {
      guardRealtimeCleanup(record.controller.close());
    }
    guardRealtimeCleanup(
      _serializeCandleOperation(
        record,
        () => _cleanupRetiredCandleRequest(record),
      ),
    );
  }

  bool _ownsCandleRequest(_CandleRequestRecord record) =>
      !_disposed &&
      !record.retired &&
      record.listeners > 0 &&
      identical(record.slot.active, record) &&
      identical(_candleSlots[record.request], record.slot) &&
      record.slot.active?.generation == record.generation;

  Future<void> _activateCandleRequest(_CandleRequestRecord record) async {
    try {
      await _ensureConnected();
    } catch (_) {
      if (_ownsCandleRequest(record)) _scheduleRestart();
      return;
    }
    if (!_ownsCandleRequest(record)) return;
    final connectionGeneration = _connectionGeneration;
    final outcome = await _serializeCandleOperation(
      record,
      () => _subscribeOwnedCandleRequest(record, connectionGeneration),
    );
    if (outcome == _CandleSubscribeOutcome.failed &&
        _ownsCandleRequest(record) &&
        connectionGeneration == _connectionGeneration) {
      _invalidateRecovery(connectionGeneration);
    }
  }

  void _recordCandleOwnershipChange() {
    _candleOwnershipEpoch++;
    _invalidateRecovery(_connectionGeneration);
  }

  void _invalidateRecovery(int connectionGeneration) {
    final flight = _connectionRecoveries[connectionGeneration];
    if (flight == null) return;
    flight.dirty = true;
    if (flight.state == _RecoveryFlightState.inFlight) return;
    flight.state = _RecoveryFlightState.invalidated;
    if (identical(_connectionRecoveries[connectionGeneration], flight)) {
      _connectionRecoveries.remove(connectionGeneration);
    }
  }

  Future<T> _serializeCandleOperation<T>(
    _CandleRequestRecord record,
    Future<T> Function() operation,
  ) {
    final completer = Completer<T>();
    record.slot.operationTail = record.slot.operationTail.then((_) async {
      try {
        final result = await operation();
        if (!completer.isCompleted) completer.complete(result);
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    });
    return completer.future;
  }

  Future<_CandleSubscribeOutcome> _subscribeOwnedCandleRequest(
    _CandleRequestRecord record,
    int connectionGeneration,
  ) async {
    if (!_ownsCandleRequest(record) ||
        connectionGeneration != _connectionGeneration) {
      return _CandleSubscribeOutcome.noLongerOwned;
    }
    if (record.subscribedConnectionGeneration == connectionGeneration) {
      return _CandleSubscribeOutcome.subscribed;
    }
    if (_connection?.state != HubConnectionState.connected) {
      _scheduleRestart();
      return _CandleSubscribeOutcome.failed;
    }
    record.pendingSubscribeConnectionGeneration = connectionGeneration;
    var subscribeSent = false;
    try {
      if (!_ownsCandleRequest(record) ||
          connectionGeneration != _connectionGeneration) {
        return _CandleSubscribeOutcome.noLongerOwned;
      }
      subscribeSent = true;
      await _connection?.invoke(
        'SubscribeChart',
        args: [record.request.symbol, record.request.timeframe],
      );
      if (_ownsCandleRequest(record) &&
          connectionGeneration == _connectionGeneration &&
          _connection?.state == HubConnectionState.connected) {
        record.subscribedConnectionGeneration = connectionGeneration;
        return _CandleSubscribeOutcome.subscribed;
      }
      if (connectionGeneration == _connectionGeneration &&
          _connection?.state == HubConnectionState.connected) {
        await _unsubscribeRetiredCandleRequest(record, connectionGeneration);
      }
      return _CandleSubscribeOutcome.noLongerOwned;
    } catch (_) {
      if (subscribeSent &&
          !_ownsCandleRequest(record) &&
          connectionGeneration == _connectionGeneration &&
          _connection?.state == HubConnectionState.connected) {
        await _unsubscribeRetiredCandleRequest(record, connectionGeneration);
        return _CandleSubscribeOutcome.noLongerOwned;
      }
      if (_ownsCandleRequest(record) &&
          connectionGeneration == _connectionGeneration) {
        _scheduleRestart();
        return _CandleSubscribeOutcome.failed;
      }
      return _CandleSubscribeOutcome.noLongerOwned;
    } finally {
      if (record.pendingSubscribeConnectionGeneration == connectionGeneration) {
        record.pendingSubscribeConnectionGeneration = null;
      }
    }
  }

  Future<void> _cleanupRetiredCandleRequest(_CandleRequestRecord record) async {
    final subscribedGeneration = record.subscribedConnectionGeneration;
    if (subscribedGeneration != null &&
        subscribedGeneration == _connectionGeneration &&
        _connection?.state == HubConnectionState.connected) {
      await _unsubscribeRetiredCandleRequest(record, subscribedGeneration);
    }
    if (record.slot.active == null &&
        identical(_candleSlots[record.request], record.slot)) {
      _candleSlots.remove(record.request);
    }
  }

  Future<void> _unsubscribeRetiredCandleRequest(
    _CandleRequestRecord record,
    int connectionGeneration,
  ) async {
    if (connectionGeneration != _connectionGeneration ||
        _connection?.state != HubConnectionState.connected) {
      return;
    }
    record.subscribedConnectionGeneration = null;
    try {
      await _connection?.invoke(
        'UnsubscribeChart',
        args: [record.request.symbol, record.request.timeframe],
      );
    } catch (_) {
      // Ownership is already retired. A later connection cannot carry this
      // generation, so there is no state to resurrect or retry.
    }
  }

  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    final completer = Completer<void>();
    _disposeFuture = completer.future;
    guardRealtimeCleanup(() async {
      try {
        await _disposeResources();
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    }());
    return completer.future;
  }

  Future<void> _disposeResources() async {
    _disposed = true;
    _connectedSessionGeneration = null;
    _restartTimer?.cancel();
    _restartTimer = null;
    final activeRecords = [
      for (final slot in _candleSlots.values) ?slot.active,
    ];
    final slots = _candleSlots.values.toList(growable: false);
    for (final record in activeRecords) {
      _retireCandleRequest(record);
    }
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      await _settleCleanup(connection.stop());
    }
    await Future.wait([
      for (final slot in slots) _settleCleanup(slot.operationTail),
      for (final recovery in _pendingRecoverySettlements.toList(
        growable: false,
      ))
        _settleCleanup(recovery),
      if (_startFuture case final start?) _settleCleanup(start),
    ]);
    for (final controller in _quoteControllers.values.toList(growable: false)) {
      guardRealtimeCleanup(controller.close());
    }
    guardRealtimeCleanup(_statusController.close());
    guardRealtimeCleanup(_historyResyncController.close());
    _candleSlots.clear();
    _quoteControllers.clear();
    _quoteSubscribers.clear();
    _connectionRecoveries.clear();
    _pendingRecoverySettlements.clear();
  }

  Future<void> _settleCleanup(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // Cleanup is best effort after ownership has already been retired.
    }
  }

  Future<DemoQuote?> _fetchQuote(String symbol, DemoQuote fallback) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/market/quotes/${Uri.encodeComponent(symbol)}',
      );
      final data = response.data;
      return data == null ? null : _parseQuote(data, fallback);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      return null;
    }
  }

  Future<void> _ensureConnected() {
    if (_disposed) return Future<void>.value();
    final connection = _connection;
    if (connection?.state == HubConnectionState.connected) {
      return Future<void>.value();
    }
    return _startFuture ??= _startConnection().whenComplete(() {
      _startFuture = null;
    });
  }

  Future<void> _startConnection() async {
    if (_disposed) return;
    _setStatus(
      _connection == null
          ? MarketConnectionStatus.connecting
          : MarketConnectionStatus.reconnecting,
    );
    _connection ??= _buildConnection();
    try {
      await _connection!.start();
      if (_disposed) return;
      final connectionGeneration = _beginConnectedSession();
      final shouldResyncHistory = _hasConnected;
      _hasConnected = true;
      await _recoverConnectedSession(
        resyncHistory: shouldResyncHistory,
        connectionGeneration: connectionGeneration,
      );
    } catch (_) {
      _setStatus(
        _connection?.state == HubConnectionState.connected
            ? MarketConnectionStatus.reconnecting
            : MarketConnectionStatus.disconnected,
      );
      _scheduleRestart();
      rethrow;
    }
  }

  HubConnection _buildConnection() {
    final connection =
        connectionFactory?.call() ??
        (HubConnectionBuilder()
            .withUrl(
              '$_baseUrl/hubs/market',
              options: HttpConnectionOptions(
                requestTimeout: 8000,
                logMessageContent: false,
              ),
            )
            .withAutomaticReconnect(
              retryDelays: const [0, 1000, 2000, 5000, 10000],
            )
            .build());
    connection.on('QuoteUpdated', _handleQuoteUpdated);
    connection.on('CandleUpdated', _handleCandleUpdated);
    connection.onreconnecting(({error}) {
      _setStatus(MarketConnectionStatus.reconnecting);
    });
    connection.onreconnected(({connectionId}) {
      if (_disposed) return;
      final connectionGeneration = _beginConnectedSession();
      guardRealtimeCleanup(
        _recoverConnectedSession(
          resyncHistory: true,
          connectionGeneration: connectionGeneration,
        ).catchError((_) {
          if (_isCurrentConnectedSession(connectionGeneration)) {
            _setStatus(MarketConnectionStatus.reconnecting);
            _scheduleRestart();
          }
        }),
      );
    });
    connection.onclose(({error}) {
      if (_disposed) return;
      _invalidateConnectedSession();
      _setStatus(MarketConnectionStatus.disconnected);
      _scheduleRestart();
    });
    return connection;
  }

  void _handleQuoteUpdated(List<Object?>? arguments) {
    final data = _firstMap(arguments);
    if (data == null) return;
    final symbol = _normalizeSymbol(data['symbol']?.toString() ?? '');
    final seed = _quoteSeeds[symbol];
    if (seed == null) return;
    final quote = _parseQuote(data, seed);
    _acceptQuote(quote);
  }

  void _handleCandleUpdated(List<Object?>? arguments) {
    final data = _firstMap(arguments);
    if (data == null) return;
    final request = MarketDataRequest(
      _normalizeSymbol(data['symbol']?.toString() ?? ''),
      data['timeframe']?.toString().toUpperCase() ?? '',
    );
    final time = DateTime.tryParse(data['time']?.toString() ?? '');
    if (time == null) return;
    final candle = MarketCandle(
      time: time.toUtc(),
      open: _asDouble(data['open']),
      high: _asDouble(data['high']),
      low: _asDouble(data['low']),
      close: _asDouble(data['close']),
      volume: _asDoubleOrZero(data['volume']),
    );
    final record = _candleSlots[request]?.active;
    if (record != null && _ownsCandleRequest(record)) {
      record.controller.add(candle);
    }
  }

  DemoQuote _parseQuote(Map<String, dynamic> data, DemoQuote fallback) {
    final symbol = _normalizeSymbol(
      data['symbol']?.toString() ?? fallback.symbol,
    );
    final bid = _asDouble(data['bid']);
    final ask = _asDouble(data['ask']);
    final previous = _latestQuotes[symbol];
    final statistics = previous ?? fallback;
    return DemoQuote(
      symbol: symbol,
      name: fallback.name,
      bid: bid,
      ask: ask,
      changePercent:
          _asOptionalDouble(data['changePercent']) ?? statistics.changePercent,
      sourceTimestamp: DateTime.tryParse(
        data['timestamp']?.toString() ?? '',
      )?.toUtc(),
      previousClose:
          _asOptionalDouble(data['previousClose']) ?? statistics.previousClose,
      dailyLow: _asOptionalDouble(data['dailyLow']) ?? statistics.dailyLow,
      dailyHigh: _asOptionalDouble(data['dailyHigh']) ?? statistics.dailyHigh,
    );
  }

  bool _acceptQuote(DemoQuote quote, {bool publish = true}) {
    final previous = _latestQuotes[quote.symbol];
    final previousTimestamp = previous?.sourceTimestamp;
    final incomingTimestamp = quote.sourceTimestamp;
    if (previousTimestamp != null &&
        incomingTimestamp != null &&
        incomingTimestamp.isBefore(previousTimestamp)) {
      return false;
    }

    _latestQuotes[quote.symbol] = quote;
    if (publish) {
      _quoteControllers[quote.symbol]?.add(quote);
    }
    return true;
  }

  Future<void> _resubscribe(_ConnectionRecoveryFlight flight) async {
    _requireCurrentRecoveryFlight(flight);
    final connectionGeneration = flight.connectionGeneration;
    final symbols = _quoteSubscribers.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (symbols.isNotEmpty) {
      await _subscribeSymbols(symbols);
      _requireCurrentRecoveryFlight(flight);
    }
    final records = [for (final slot in _candleSlots.values) ?slot.active];
    for (final record in records) {
      _requireCurrentRecoveryFlight(flight);
      if (!_ownsCandleRequest(record)) continue;
      final outcome = await _serializeCandleOperation(
        record,
        () => _subscribeOwnedCandleRequest(record, connectionGeneration),
      );
      _requireCurrentRecoveryFlight(flight);
      if (!_ownsCandleRequest(record)) continue;
      if (outcome != _CandleSubscribeOutcome.subscribed) {
        throw StateError(
          'Failed to subscribe ${record.request.symbol} '
          '${record.request.timeframe} for connection generation '
          '$connectionGeneration.',
        );
      }
    }
    _requireCurrentRecoveryFlight(flight, requireSubscribedRecords: true);
  }

  Future<void> _recoverConnectedSession({
    required bool resyncHistory,
    required int connectionGeneration,
  }) {
    final existing = _connectionRecoveries[connectionGeneration];
    if (existing != null) {
      if (existing.state == _RecoveryFlightState.inFlight) {
        return existing.future;
      }
      if (existing.state == _RecoveryFlightState.succeeded &&
          !existing.dirty &&
          existing.ownershipEpoch == _candleOwnershipEpoch) {
        return existing.future;
      }
      if (identical(_connectionRecoveries[connectionGeneration], existing)) {
        _connectionRecoveries.remove(connectionGeneration);
      }
    }
    final flight = _ConnectionRecoveryFlight(
      connectionGeneration: connectionGeneration,
      token: ++_recoveryFlightToken,
      ownershipEpoch: _candleOwnershipEpoch,
      resyncHistory: resyncHistory,
    );
    _connectionRecoveries[connectionGeneration] = flight;
    flight.future = _performConnectedSessionRecovery(flight).then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        final invalidated = error is _RecoveryFlightInvalidated;
        final isCurrentGeneration =
            _isCurrentConnectedSession(flight.connectionGeneration) &&
            identical(
              _connectionRecoveries[flight.connectionGeneration],
              flight,
            );
        flight.state = invalidated
            ? _RecoveryFlightState.invalidated
            : _RecoveryFlightState.failed;
        if (identical(_connectionRecoveries[connectionGeneration], flight)) {
          _connectionRecoveries.remove(connectionGeneration);
        }
        if (invalidated && isCurrentGeneration) {
          _setStatus(MarketConnectionStatus.reconnecting);
          _scheduleRestart();
          return;
        }
        if (invalidated) return;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _trackRecoverySettlement(flight.future);
    return flight.future;
  }

  void _trackRecoverySettlement(Future<void> recovery) {
    _pendingRecoverySettlements.add(recovery);
    unawaited(
      recovery.then<void>(
        (_) => _pendingRecoverySettlements.remove(recovery),
        onError: (Object _, StackTrace _) {
          _pendingRecoverySettlements.remove(recovery);
        },
      ),
    );
  }

  Future<void> _performConnectedSessionRecovery(
    _ConnectionRecoveryFlight flight,
  ) async {
    _requireCurrentRecoveryFlight(flight);
    await _resubscribe(flight);
    _requireCurrentRecoveryFlight(flight, requireSubscribedRecords: true);
    await _refreshSubscribedQuotes(flight);
    _requireCurrentRecoveryFlight(flight, requireSubscribedRecords: true);
    flight.state = _RecoveryFlightState.succeeded;
    if (flight.resyncHistory) {
      _historyResyncGeneration++;
      _historyResyncController.add(_historyResyncGeneration);
    }
    _setStatus(MarketConnectionStatus.connected);
  }

  void _requireCurrentRecoveryFlight(
    _ConnectionRecoveryFlight flight, {
    bool requireSubscribedRecords = false,
  }) {
    final current = _connectionRecoveries[flight.connectionGeneration];
    final isCurrent =
        _isCurrentConnectedSession(flight.connectionGeneration) &&
        identical(current, flight) &&
        current?.token == flight.token &&
        flight.state == _RecoveryFlightState.inFlight &&
        !flight.dirty &&
        flight.ownershipEpoch == _candleOwnershipEpoch;
    if (!isCurrent ||
        (requireSubscribedRecords &&
            !_allCurrentCandleRequestsSubscribed(
              flight.connectionGeneration,
            ))) {
      throw _RecoveryFlightInvalidated();
    }
  }

  bool _allCurrentCandleRequestsSubscribed(int connectionGeneration) {
    for (final slot in _candleSlots.values) {
      final record = slot.active;
      if (record != null &&
          _ownsCandleRequest(record) &&
          record.subscribedConnectionGeneration != connectionGeneration) {
        return false;
      }
    }
    return true;
  }

  Future<void> _refreshSubscribedQuotes(
    _ConnectionRecoveryFlight flight,
  ) async {
    final symbols = _quoteSubscribers.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList(growable: false);
    await Future.wait([
      for (final symbol in symbols)
        () async {
          final seed = _quoteSeeds[symbol];
          if (seed == null) return;
          final quote = await _fetchQuote(symbol, seed);
          _requireCurrentRecoveryFlight(flight, requireSubscribedRecords: true);
          if (quote == null) return;
          _acceptQuote(quote);
        }(),
    ]);
  }

  int _beginConnectedSession() {
    final connectionGeneration = ++_connectionGeneration;
    _connectedSessionGeneration = connectionGeneration;
    _pruneRecoveryRecords();
    return connectionGeneration;
  }

  void _invalidateConnectedSession() {
    _connectedSessionGeneration = null;
    _connectionGeneration++;
    _pruneRecoveryRecords();
  }

  void _pruneRecoveryRecords() {
    _connectionRecoveries.removeWhere(
      (connectionGeneration, _) =>
          connectionGeneration != _connectionGeneration,
    );
  }

  bool _isCurrentConnectedSession(int connectionGeneration) =>
      !_disposed &&
      connectionGeneration == _connectionGeneration &&
      _connectedSessionGeneration == connectionGeneration &&
      _connection?.state == HubConnectionState.connected;

  Future<void> _unsubscribeSymbols(List<String> symbols) async {
    if (_connection?.state != HubConnectionState.connected) return;
    if (symbols.any((symbol) => (_quoteSubscribers[symbol] ?? 0) > 0)) return;
    await _connection?.invoke('UnsubscribeSymbols', args: [symbols]);
  }

  Future<void> _subscribeSymbols(List<String> symbols) async {
    if (_connection?.state != HubConnectionState.connected || symbols.isEmpty) {
      return;
    }
    await _connection?.invoke('SubscribeSymbols', args: [symbols]);
  }

  void _scheduleRestart() {
    if (_disposed || _restartTimer?.isActive == true) return;
    _restartTimer = Timer(const Duration(seconds: 3), () {
      final recovery = _connection?.state == HubConnectionState.connected
          ? _recoverConnectedSession(
              resyncHistory: _hasConnected,
              connectionGeneration: _connectionGeneration,
            )
          : _ensureConnected();
      guardRealtimeCleanup(
        recovery.catchError((_) {
          _scheduleRestart();
        }),
      );
    });
  }

  void _setStatus(MarketConnectionStatus value) {
    if (_status == value || _disposed) return;
    _status = value;
    _statusController.add(value);
  }

  static Map<String, dynamic>? _firstMap(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty || arguments.first is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(arguments.first! as Map);
  }

  static String _normalizeSymbol(String symbol) => symbol.trim().toUpperCase();

  static double _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.parse(value.toString());

  static double? _asOptionalDouble(Object? value) => value == null
      ? null
      : value is num
      ? value.toDouble()
      : double.tryParse(value.toString());

  static double _asDoubleOrZero(Object? value) =>
      value == null ? 0 : _asDouble(value);
}

class _CandleRequestSlot {
  _CandleRequestSlot(this.request);

  final MarketDataRequest request;
  _CandleRequestRecord? active;
  Future<void> operationTail = Future<void>.value();
}

enum _RecoveryFlightState { inFlight, succeeded, failed, invalidated }

class _RecoveryFlightInvalidated implements Exception {}

class _ConnectionRecoveryFlight {
  _ConnectionRecoveryFlight({
    required this.connectionGeneration,
    required this.token,
    required this.ownershipEpoch,
    required this.resyncHistory,
  });

  final int connectionGeneration;
  final int token;
  final int ownershipEpoch;
  final bool resyncHistory;
  late Future<void> future;
  _RecoveryFlightState state = _RecoveryFlightState.inFlight;
  bool dirty = false;
}

enum _CandleSubscribeOutcome { subscribed, noLongerOwned, failed }

class _CandleRequestRecord {
  _CandleRequestRecord({required this.slot, required this.generation});

  final _CandleRequestSlot slot;
  final int generation;
  final StreamController<MarketCandle> controller =
      StreamController<MarketCandle>.broadcast(sync: true);
  int listeners = 1;
  bool retired = false;
  int? pendingSubscribeConnectionGeneration;
  int? subscribedConnectionGeneration;

  MarketDataRequest get request => slot.request;
}
