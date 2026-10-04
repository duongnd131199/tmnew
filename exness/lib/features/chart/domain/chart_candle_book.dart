import '../../trading/data/market_api.dart';

/// Sorted, unique candles for one symbol and timeframe. Quote updates never
/// replace the whole chart series, so the WebView can preserve its viewport.
final class ChartCandleBook {
  ChartCandleBook(this.symbol, this.timeframe);

  final String symbol;
  final String timeframe;
  final List<MarketCandle> _candles = [];
  DateTime? _lastQuoteTime;

  List<MarketCandle> get candles => List.unmodifiable(_candles);

  void replace(Iterable<MarketCandle> items) {
    final byTime = <DateTime, MarketCandle>{};
    for (final item in items) {
      if (item.symbol == symbol && item.timeframe == timeframe) {
        byTime[item.time.toUtc()] = item;
      }
    }
    _candles
      ..clear()
      ..addAll(byTime.values);
    _candles.sort((a, b) => a.time.compareTo(b.time));
    _lastQuoteTime = null;
  }

  /// Returns the candle to send through `series.update`, or null for an old
  /// quote that must not move a visible candle backwards.
  MarketCandle? acceptQuote(MarketQuote quote) {
    if (quote.symbol != symbol || !quote.bid.isFinite || quote.bid <= 0) {
      return null;
    }
    final time = quote.timestamp.toUtc();
    if (_lastQuoteTime != null && !time.isAfter(_lastQuoteTime!)) return null;
    final bucket = _bucket(time, timeframe);
    if (_candles.isNotEmpty && bucket.isBefore(_candles.last.time)) return null;
    _lastQuoteTime = time;
    if (_candles.isNotEmpty && bucket == _candles.last.time) {
      final old = _candles.last;
      final updated = MarketCandle(
        symbol: symbol,
        timeframe: timeframe,
        time: bucket,
        open: old.open,
        high: quote.bid > old.high ? quote.bid : old.high,
        low: quote.bid < old.low ? quote.bid : old.low,
        close: quote.bid,
        volume: old.volume,
      );
      _candles[_candles.length - 1] = updated;
      return updated;
    }
    final next = MarketCandle(
      symbol: symbol,
      timeframe: timeframe,
      time: bucket,
      open: quote.bid,
      high: quote.bid,
      low: quote.bid,
      close: quote.bid,
      volume: 0,
    );
    _candles.add(next);
    return next;
  }
}

DateTime _bucket(DateTime time, String timeframe) {
  final utc = time.toUtc();
  if (timeframe == 'MN') return DateTime.utc(utc.year, utc.month);
  if (timeframe == 'W1') {
    final day = DateTime.utc(utc.year, utc.month, utc.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
  if (timeframe == 'D1') return DateTime.utc(utc.year, utc.month, utc.day);
  final minutes = switch (timeframe) {
    'M1' => 1,
    'M5' => 5,
    'M15' => 15,
    'M30' => 30,
    'H1' => 60,
    'H4' => 240,
    _ => throw ArgumentError.value(timeframe, 'timeframe'),
  };
  final epochMinute =
      utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;
  return DateTime.fromMillisecondsSinceEpoch(
    (epochMinute ~/ minutes) * minutes * Duration.millisecondsPerMinute,
    isUtc: true,
  );
}
