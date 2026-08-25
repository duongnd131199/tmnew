import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/chart/data/market_data_service.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

final marketDataServiceProvider = Provider<MarketDataService>((ref) {
  final config = ref.watch(marketApiConfigProvider);
  return MarketDataService(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    ),
    marketApiBaseUrl: config.normalizedBaseUrl,
  );
});

final marketClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now(),
);

class MarketCandleHistoryCache {
  MarketCandleHistoryCache({this.capacity = 21}) : assert(capacity > 0);

  final int capacity;
  final LinkedHashMap<MarketDataRequest, List<MarketCandle>> _entries =
      LinkedHashMap<MarketDataRequest, List<MarketCandle>>();

  int get length => _entries.length;

  List<MarketCandle>? operator [](MarketDataRequest request) {
    final key = _normalized(request);
    final candles = _entries.remove(key);
    if (candles == null) return null;
    _entries[key] = candles;
    return candles;
  }

  void store(MarketDataRequest request, List<MarketCandle> candles) {
    if (candles.isEmpty) return;
    final key = _normalized(request);
    final snapshot = List<MarketCandle>.unmodifiable(candles);
    _entries.remove(key);
    _entries[key] = snapshot;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  MarketDataRequest _normalized(MarketDataRequest request) => MarketDataRequest(
    request.symbol.trim().toUpperCase(),
    request.timeframe.trim().toUpperCase(),
  );
}

final marketCandleHistoryCacheProvider = Provider<MarketCandleHistoryCache>(
  (ref) => MarketCandleHistoryCache(),
);

final marketCandlesProvider = StreamProvider.autoDispose
    .family<List<MarketCandle>, MarketDataRequest>((ref, request) async* {
      final service = ref.watch(marketDataServiceProvider);
      final cache = ref.watch(marketCandleHistoryCacheProvider);
      final cancelToken = CancelToken();
      Timer? pollingDelay;
      Completer<void>? pollingWakeup;
      StreamSubscription<int>? historyResyncSubscription;
      StreamController<int>? historyResyncQueue;
      var disposed = false;

      ref.onDispose(() {
        disposed = true;
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('Market candle request is no longer observed.');
        }
        pollingDelay?.cancel();
        final wakeup = pollingWakeup;
        if (wakeup != null && !wakeup.isCompleted) wakeup.complete();
        final resyncSubscription = historyResyncSubscription;
        if (resyncSubscription != null) {
          unawaited(resyncSubscription.cancel().catchError((_) {}));
        }
        final resyncQueue = historyResyncQueue;
        if (resyncQueue != null && !resyncQueue.isClosed) {
          unawaited(resyncQueue.close().catchError((_) {}));
        }
      });

      Future<void> waitForNextPoll(Duration duration) {
        if (disposed) return Future<void>.value();
        final completer = Completer<void>();
        pollingWakeup = completer;
        pollingDelay = Timer(duration, () {
          if (!completer.isCompleted) completer.complete();
        });
        return completer.future.whenComplete(() {
          if (identical(pollingWakeup, completer)) pollingWakeup = null;
          pollingDelay = null;
        });
      }

      Future<List<MarketCandle>?> fetch() async {
        try {
          final candles = await service.fetchCandles(
            request.symbol,
            request.timeframe,
            cancelToken: cancelToken,
          );
          if (disposed || candles.isEmpty) return null;
          cache.store(request, candles);
          return cache[request];
        } on DioException catch (error) {
          if (CancelToken.isCancel(error) || disposed) return null;
          rethrow;
        }
      }

      final cached = cache[request];
      if (cached != null && cached.isNotEmpty) yield cached;
      if (service.usesRealtimeApi) {
        final realtime = ref.watch(realtimeMarketServiceProvider);
        final resyncQueue = StreamController<int>();
        historyResyncQueue = resyncQueue;
        historyResyncSubscription = realtime.historyResyncs.listen(
          resyncQueue.add,
          onError: resyncQueue.addError,
          onDone: resyncQueue.close,
        );
        final initial = await fetch();
        if (initial != null) yield initial;
        await for (final _ in resyncQueue.stream) {
          if (disposed) return;
          final refreshed = await fetch();
          if (refreshed != null) yield refreshed;
        }
        return;
      }
      final hasLocalMt5 = await service.hasLocalMt5History(request.symbol);
      while (!disposed) {
        final candles = await fetch();
        if (candles != null) yield candles;
        await waitForNextPoll(
          hasLocalMt5
              ? const Duration(milliseconds: 200)
              : const Duration(seconds: 1),
        );
      }
    });

class LiveMarketCandleState {
  LiveMarketCandleState({
    this.history = const <MarketCandle>[],
    this.settledLiveTail = const <MarketCandle>[],
    this.activeCandle,
    this.activeCandleIsLive = false,
    this.hasHistorySnapshot = false,
    this.historyRevision = 0,
    this.liveCandleRevision = 0,
    this.currentPrice,
    this.lastTickAt,
    this.nextBoundary,
  }) : candles = _ImmutableCandleSeries(history, activeCandle),
       liveTail = _ImmutableCandleSeries(
         settledLiveTail,
         activeCandleIsLive ? activeCandle : null,
       );

  /// Settled candles. This exact list is retained for all ticks in one bucket.
  final List<MarketCandle> history;
  final List<MarketCandle> settledLiveTail;
  final MarketCandle? activeCandle;
  final bool activeCandleIsLive;
  final bool hasHistorySnapshot;
  final int historyRevision;
  final int liveCandleRevision;
  final List<MarketCandle> candles;
  final List<MarketCandle> liveTail;
  final double? currentPrice;
  final DateTime? lastTickAt;
  final DateTime? nextBoundary;
}

final liveMarketCandlesProvider = NotifierProvider.autoDispose
    .family<
      LiveMarketCandlesController,
      LiveMarketCandleState,
      MarketDataRequest
    >((request) => LiveMarketCandlesController(request));

class LiveMarketCandlesController extends Notifier<LiveMarketCandleState> {
  LiveMarketCandlesController(this.request);

  final MarketDataRequest request;
  List<MarketCandle>? _acceptedHistory;
  DateTime? _lastQuoteAt;

  @override
  LiveMarketCandleState build() => LiveMarketCandleState();

  /// Seeds or refreshes history without discarding ticks that arrived while
  /// the network/local cache was still loading.
  void seedHistory(List<MarketCandle> candles) {
    final ordered = List<MarketCandle>.of(candles)
      ..sort((left, right) => left.time.compareTo(right.time));
    final visible = ordered.length > MarketDataService.realtimeHistoryLimit
        ? ordered.sublist(
            ordered.length - MarketDataService.realtimeHistoryLimit,
          )
        : ordered;
    if (_sameCandleSeries(_acceptedHistory, visible)) return;
    _acceptedHistory = List<MarketCandle>.unmodifiable(visible);
    final priorLiveTail = List<MarketCandle>.unmodifiable(
      state.liveTail.map((live) => _reconcileHistoryCandle(visible, live)),
    );
    final merged = MarketDataService.mergeLiveTail(
      visible,
      priorLiveTail,
      timeframe: request.timeframe,
      maxCandles: MarketDataService.realtimeHistoryLimit,
    );
    if (merged.isEmpty) return;
    final active = merged.last;
    final activeIsLive =
        priorLiveTail.isNotEmpty &&
        _sameBucket(priorLiveTail.last.time, active.time);
    final history = List<MarketCandle>.unmodifiable(
      merged.take(merged.length - 1),
    );
    final settledLiveTail = activeIsLive
        ? List<MarketCandle>.unmodifiable(
            priorLiveTail.take(priorLiveTail.length - 1),
          )
        : const <MarketCandle>[];
    final activeChanged =
        !_sameCandle(state.activeCandle, active) ||
        state.activeCandleIsLive != activeIsLive;
    state = LiveMarketCandleState(
      history: history,
      settledLiveTail: settledLiveTail,
      activeCandle: active,
      activeCandleIsLive: activeIsLive,
      hasHistorySnapshot: true,
      historyRevision: state.historyRevision + 1,
      liveCandleRevision: state.liveCandleRevision + (activeChanged ? 1 : 0),
      currentPrice: state.currentPrice,
      lastTickAt: state.lastTickAt,
      nextBoundary: state.nextBoundary,
    );
  }

  MarketCandle _reconcileHistoryCandle(
    List<MarketCandle> history,
    MarketCandle live,
  ) {
    final historyIndex = history.lastIndexWhere((candidate) {
      final alignedLiveTime = candidate.time.isUtc
          ? live.time.toUtc()
          : live.time.toLocal();
      return MarketDataService.bucketStart(candidate.time, request.timeframe) ==
          MarketDataService.bucketStart(alignedLiveTime, request.timeframe);
    });
    if (historyIndex < 0) return live;

    final historical = history[historyIndex];
    return MarketCandle(
      time: historical.time,
      open: historical.open,
      high: live.high > historical.high ? live.high : historical.high,
      low: live.low < historical.low ? live.low : historical.low,
      close: live.close,
      volume: live.volume > historical.volume ? live.volume : historical.volume,
    );
  }

  void applyTick({required double price, required DateTime receivedAt}) {
    if (_lastQuoteAt != null && receivedAt.isBefore(_lastQuoteAt!)) {
      return;
    }
    final active = state.activeCandle;
    final alignedTickTime = active == null
        ? receivedAt
        : active.time.isUtc
        ? receivedAt.toUtc()
        : receivedAt.toLocal();
    final tickBucket = MarketDataService.bucketStart(
      alignedTickTime,
      request.timeframe,
    );
    if (active != null &&
        tickBucket.isBefore(
          MarketDataService.bucketStart(active.time, request.timeframe),
        )) {
      return;
    }
    final sameBucket = active != null && _sameBucket(active.time, tickBucket);
    if (sameBucket && state.currentPrice == price) {
      _lastQuoteAt = receivedAt;
      return;
    }
    var history = state.history;
    var settledLiveTail = state.settledLiveTail;
    var historyRevision = state.historyRevision;
    late final MarketCandle nextActive;
    if (sameBucket) {
      nextActive = MarketCandle(
        time: MarketDataService.bucketStart(active.time, request.timeframe),
        open: active.open,
        high: price > active.high ? price : active.high,
        low: price < active.low ? price : active.low,
        close: price,
        volume: active.volume,
      );
    } else {
      if (active != null) {
        history = _appendSettled(history, active);
        if (state.activeCandleIsLive) {
          settledLiveTail = _appendSettled(settledLiveTail, active);
        }
        historyRevision++;
      }
      nextActive = MarketCandle(
        time: tickBucket,
        open: price,
        high: price,
        low: price,
        close: price,
      );
    }
    _lastQuoteAt = receivedAt;
    state = LiveMarketCandleState(
      history: history,
      settledLiveTail: settledLiveTail,
      activeCandle: nextActive,
      activeCandleIsLive: true,
      hasHistorySnapshot: state.hasHistorySnapshot,
      historyRevision: historyRevision,
      liveCandleRevision: state.liveCandleRevision + 1,
      currentPrice: price,
      lastTickAt: receivedAt,
      nextBoundary: MarketDataService.nextBoundary(
        receivedAt,
        request.timeframe,
      ),
    );
  }

  void applyRemoteCandle(MarketCandle candle, {required DateTime receivedAt}) {
    final alignedReceivedAt = candle.time.isUtc
        ? receivedAt.toUtc()
        : receivedAt.toLocal();
    if (state.lastTickAt != null &&
        alignedReceivedAt.isBefore(state.lastTickAt!)) {
      return;
    }
    final bucket = MarketDataService.bucketStart(
      candle.time,
      request.timeframe,
    );
    final normalized = MarketCandle(
      time: bucket,
      open: candle.open,
      high: candle.high,
      low: candle.low,
      close: candle.close,
      volume: candle.volume,
    );
    final active = state.activeCandle;
    if (active != null &&
        bucket.isBefore(
          MarketDataService.bucketStart(active.time, request.timeframe),
        )) {
      return;
    }
    if (active != null &&
        _sameBucket(active.time, bucket) &&
        _sameCandle(active, normalized) &&
        (_lastQuoteAt == null || state.currentPrice == normalized.close)) {
      return;
    }
    var history = state.history;
    var settledLiveTail = state.settledLiveTail;
    var historyRevision = state.historyRevision;
    if (active != null &&
        bucket.isAfter(
          MarketDataService.bucketStart(active.time, request.timeframe),
        )) {
      history = _appendSettled(history, active);
      if (state.activeCandleIsLive) {
        settledLiveTail = _appendSettled(settledLiveTail, active);
      }
      historyRevision++;
    }
    final quoteOwnsBucket =
        active != null &&
        state.currentPrice != null &&
        _lastQuoteAt != null &&
        _sameBucket(active.time, bucket) &&
        _sameBucket(_lastQuoteAt!, bucket);
    final currentPrice = quoteOwnsBucket
        ? state.currentPrice!
        : normalized.close;
    final nextActive = active != null && _sameBucket(active.time, bucket)
        ? MarketCandle(
            time: bucket,
            open: normalized.open,
            high: math.max(
              currentPrice,
              math.max(active.high, normalized.high),
            ),
            low: math.min(currentPrice, math.min(active.low, normalized.low)),
            close: currentPrice,
            volume: math.max(active.volume, normalized.volume),
          )
        : normalized;
    final latestTickAt = quoteOwnsBucket
        ? state.lastTickAt ?? _lastQuoteAt!
        : alignedReceivedAt;
    state = LiveMarketCandleState(
      history: history,
      settledLiveTail: settledLiveTail,
      activeCandle: nextActive,
      activeCandleIsLive: true,
      hasHistorySnapshot: state.hasHistorySnapshot,
      historyRevision: historyRevision,
      liveCandleRevision: state.liveCandleRevision + 1,
      currentPrice: currentPrice,
      lastTickAt: latestTickAt,
      nextBoundary: MarketDataService.nextBoundary(
        latestTickAt,
        request.timeframe,
      ),
    );
  }

  bool _sameBucket(DateTime left, DateTime right) =>
      MarketDataService.bucketStart(left, request.timeframe) ==
      MarketDataService.bucketStart(right, request.timeframe);

  List<MarketCandle> _appendSettled(
    List<MarketCandle> source,
    MarketCandle candle,
  ) {
    final maximum = MarketDataService.realtimeHistoryLimit - 1;
    if (maximum <= 0) return const <MarketCandle>[];
    final start = source.length >= maximum ? source.length - maximum + 1 : 0;
    return List<MarketCandle>.unmodifiable(<MarketCandle>[
      ...source.skip(start),
      candle,
    ]);
  }

  bool _sameCandle(MarketCandle? left, MarketCandle? right) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    return left.time == right.time &&
        left.open == right.open &&
        left.high == right.high &&
        left.low == right.low &&
        left.close == right.close &&
        left.volume == right.volume;
  }

  bool _sameCandleSeries(List<MarketCandle>? left, List<MarketCandle> right) {
    if (left == null || left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_sameCandle(left[index], right[index])) return false;
    }
    return true;
  }
}

final class _ImmutableCandleSeries extends ListBase<MarketCandle> {
  _ImmutableCandleSeries(this._settled, this._active);

  final List<MarketCandle> _settled;
  final MarketCandle? _active;

  @override
  int get length => _settled.length + (_active == null ? 0 : 1);

  @override
  set length(int value) => throw UnsupportedError('Immutable candle series');

  @override
  MarketCandle operator [](int index) {
    RangeError.checkValidIndex(index, this);
    if (index < _settled.length) return _settled[index];
    return _active!;
  }

  @override
  void operator []=(int index, MarketCandle value) =>
      throw UnsupportedError('Immutable candle series');
}
