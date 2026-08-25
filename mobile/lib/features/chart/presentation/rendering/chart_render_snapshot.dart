import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:trading_mobile/features/chart/presentation/theme/chart_reference_theme.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_price_viewport.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

/// Immutable inputs consumed by the chart painter for one render revision.
///
/// History and resolved series are defensively frozen. [evolve] reuses the
/// exact history snapshot while its explicit history revision is unchanged,
/// so live ticks cannot accidentally turn history identity into repaint work.
@immutable
final class ChartRenderSnapshot {
  @visibleForTesting
  static int debugFullHistoryResolutionCount = 0;

  @visibleForTesting
  static int debugResolvedHistoryCopyCount = 0;

  @visibleForTesting
  static void debugResetFullSeriesWork() {
    debugFullHistoryResolutionCount = 0;
    debugResolvedHistoryCopyCount = 0;
  }

  static void recordFullHistoryResolution() {
    assert(() {
      debugFullHistoryResolutionCount++;
      return true;
    }());
  }

  factory ChartRenderSnapshot.evolve({
    ChartRenderSnapshot? previous,
    required List<MarketCandle> history,
    required List<MarketCandle> liveTail,
    required List<MarketCandle> resolvedCandles,
    required int historyRevision,
    required int liveCandleRevision,
    Object? historyIdentity,
    required ChartViewport viewport,
    ChartPriceViewport priceViewport = const ChartPriceViewport.auto(),
    required Iterable<Object?> overlayValues,
    required ChartReferenceTheme theme,
  }) {
    final effectiveHistoryIdentity = historyIdentity ?? historyRevision;
    final reuseResolvedHistory =
        previous != null &&
        previous.historyRevision == historyRevision &&
        previous._historyIdentity == effectiveHistoryIdentity;
    final frozenHistory = reuseResolvedHistory
        ? previous.history
        : List<MarketCandle>.unmodifiable(history);
    final resolvedActive = resolvedCandles.isNotEmpty
        ? resolvedCandles[resolvedCandles.length - 1]
        : liveTail.isEmpty
        ? null
        : liveTail[liveTail.length - 1];
    final liveActive = liveTail.isEmpty ? null : liveTail[liveTail.length - 1];
    final frozenSettledLiveTail = reuseResolvedHistory
        ? previous._settledLiveTail
        : List<MarketCandle>.unmodifiable(
            liveTail.take(liveTail.isEmpty ? 0 : liveTail.length - 1),
          );
    final frozenResolvedHistory = reuseResolvedHistory
        ? previous.resolvedHistory
        : List<MarketCandle>.unmodifiable(
            resolvedCandles.take(
              resolvedCandles.isEmpty ? 0 : resolvedCandles.length - 1,
            ),
          );
    assert(() {
      if (!reuseResolvedHistory && resolvedCandles.length > 1) {
        debugResolvedHistoryCopyCount++;
      }
      return true;
    }());
    final frozenLiveTail = _ImmutableCandleSeries(
      frozenSettledLiveTail,
      liveActive,
    );
    final frozenResolved = _ImmutableCandleSeries(
      frozenResolvedHistory,
      resolvedActive,
    );
    final frozenOverlayValues = List<Object?>.unmodifiable(overlayValues);
    final viewportRevision = previous == null
        ? 0
        : previous.viewport == viewport
        ? previous.viewportRevision
        : previous.viewportRevision + 1;
    final priceViewportRevision = previous == null
        ? 0
        : previous.priceViewport == priceViewport
        ? previous.priceViewportRevision
        : previous.priceViewportRevision + 1;
    final overlaysRevision = previous == null
        ? 0
        : listEquals(previous._overlayValues, frozenOverlayValues)
        ? previous.overlaysRevision
        : previous.overlaysRevision + 1;
    final themeRevision = previous == null
        ? 0
        : _sameTheme(previous.theme, theme)
        ? previous.themeRevision
        : previous.themeRevision + 1;
    return ChartRenderSnapshot._(
      effectiveHistoryIdentity,
      frozenOverlayValues,
      frozenSettledLiveTail,
      history: frozenHistory,
      resolvedHistory: frozenResolvedHistory,
      liveTail: frozenLiveTail,
      resolvedCandles: frozenResolved,
      historyRevision: historyRevision,
      liveCandleRevision: liveCandleRevision,
      viewportRevision: viewportRevision,
      priceViewportRevision: priceViewportRevision,
      overlaysRevision: overlaysRevision,
      themeRevision: themeRevision,
      viewport: viewport,
      priceViewport: priceViewport,
      theme: theme,
    );
  }

  const ChartRenderSnapshot._(
    this._historyIdentity,
    this._overlayValues,
    this._settledLiveTail, {
    required this.history,
    required this.resolvedHistory,
    required this.liveTail,
    required this.resolvedCandles,
    required this.historyRevision,
    required this.liveCandleRevision,
    required this.viewportRevision,
    required this.priceViewportRevision,
    required this.overlaysRevision,
    required this.themeRevision,
    required this.viewport,
    required this.priceViewport,
    required this.theme,
  });

  final List<MarketCandle> history;
  final List<MarketCandle> resolvedHistory;
  final List<MarketCandle> liveTail;
  final List<MarketCandle> resolvedCandles;
  final int historyRevision;
  final int liveCandleRevision;
  final int viewportRevision;
  final int priceViewportRevision;
  final int overlaysRevision;
  final int themeRevision;
  final Object _historyIdentity;
  final List<MarketCandle> _settledLiveTail;
  final ChartViewport viewport;
  final ChartPriceViewport priceViewport;
  final List<Object?> _overlayValues;
  final ChartReferenceTheme theme;

  MarketCandle? get liveCandle => liveTail.isEmpty ? null : liveTail.last;

  bool requiresRepaintComparedTo(ChartRenderSnapshot previous) =>
      historyRevision != previous.historyRevision ||
      liveCandleRevision != previous.liveCandleRevision ||
      viewportRevision != previous.viewportRevision ||
      priceViewportRevision != previous.priceViewportRevision ||
      overlaysRevision != previous.overlaysRevision ||
      themeRevision != previous.themeRevision ||
      viewport != previous.viewport ||
      priceViewport != previous.priceViewport ||
      !_sameTheme(theme, previous.theme);

  static bool _sameTheme(ChartReferenceTheme left, ChartReferenceTheme right) =>
      left.background == right.background &&
      left.foreground == right.foreground &&
      left.grid == right.grid &&
      left.bullish == right.bullish &&
      left.bearish == right.bearish &&
      left.tradeBlue == right.tradeBlue &&
      left.axisBorder == right.axisBorder &&
      left.priceLine == right.priceLine;
}

/// An O(1) immutable view over a stable candle prefix and one active candle.
final class _ImmutableCandleSeries extends ListBase<MarketCandle> {
  _ImmutableCandleSeries(this._history, this._active);

  final List<MarketCandle> _history;
  final MarketCandle? _active;

  @override
  int get length => _history.length + (_active == null ? 0 : 1);

  @override
  set length(int value) => throw UnsupportedError('Immutable candle series');

  @override
  MarketCandle operator [](int index) {
    RangeError.checkValidIndex(index, this);
    if (index < _history.length) return _history[index];
    return _active!;
  }

  @override
  void operator []=(int index, MarketCandle value) =>
      throw UnsupportedError('Immutable candle series');

  Never _rejectMutation() => throw UnsupportedError('Immutable candle series');

  @override
  void add(MarketCandle value) => _rejectMutation();

  @override
  void addAll(Iterable<MarketCandle> iterable) => _rejectMutation();

  @override
  void insert(int index, MarketCandle element) => _rejectMutation();

  @override
  void insertAll(int index, Iterable<MarketCandle> iterable) =>
      _rejectMutation();

  @override
  void setAll(int index, Iterable<MarketCandle> iterable) => _rejectMutation();

  @override
  void setRange(
    int start,
    int end,
    Iterable<MarketCandle> iterable, [
    int skipCount = 0,
  ]) => _rejectMutation();

  @override
  void fillRange(int start, int end, [MarketCandle? fillValue]) =>
      _rejectMutation();

  @override
  void replaceRange(int start, int end, Iterable<MarketCandle> replacements) =>
      _rejectMutation();

  @override
  bool remove(Object? value) => _rejectMutation();

  @override
  MarketCandle removeAt(int index) => _rejectMutation();

  @override
  MarketCandle removeLast() => _rejectMutation();

  @override
  void removeRange(int start, int end) => _rejectMutation();

  @override
  void removeWhere(bool Function(MarketCandle element) test) =>
      _rejectMutation();

  @override
  void retainWhere(bool Function(MarketCandle element) test) =>
      _rejectMutation();

  @override
  void clear() => _rejectMutation();

  @override
  void sort([int Function(MarketCandle a, MarketCandle b)? compare]) =>
      _rejectMutation();

  @override
  void shuffle([math.Random? random]) => _rejectMutation();
}
