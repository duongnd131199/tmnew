import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/core/utils/trading_price_precision.dart';

class MarketQuoteDisplay {
  const MarketQuoteDisplay({
    required this.timestamp,
    required this.digits,
    required this.previousClose,
    required this.pointChange,
    required this.percentChange,
    required this.low,
    required this.high,
    required this.spreadPoints,
  });

  final DateTime timestamp;
  final int digits;
  final double? previousClose;
  final int? pointChange;
  final double? percentChange;
  final double? low;
  final double? high;
  final int spreadPoints;
}

MarketQuoteDisplay buildMarketQuoteDisplay({
  required DemoQuote quote,
  required List<MarketCandle> dailyCandles,
  required DateTime receivedAt,
  MarketQuoteDisplay? retainedDisplay,
}) {
  if (!quote.bid.isFinite || quote.bid <= 0) {
    throw ArgumentError.value(
      quote.bid,
      'quote.bid',
      'must be positive and finite',
    );
  }
  if (!quote.ask.isFinite || quote.ask <= 0) {
    throw ArgumentError.value(
      quote.ask,
      'quote.ask',
      'must be positive and finite',
    );
  }
  if (quote.ask < quote.bid) {
    throw ArgumentError.value(
      quote.ask,
      'quote.ask',
      'must be greater than or equal to quote.bid',
    );
  }

  final timestamp = (quote.sourceTimestamp ?? receivedAt).toUtc();
  final digits = marketQuoteDigits(quote);
  final factor = _priceFactor(digits);
  final candles =
      dailyCandles
          .where(_hasValidOhlc)
          .where((candle) => !_isAfterUtcDate(candle.time, timestamp))
          .toList()
        ..sort((left, right) => left.time.compareTo(right.time));

  MarketCandle? currentCandle;
  MarketCandle? precedingCandle;
  for (final candle in candles) {
    if (_isSameUtcDate(candle.time, timestamp)) {
      currentCandle = candle;
    } else {
      precedingCandle = candle;
    }
  }

  double? previousClose;
  double? low;
  double? high;
  if (currentCandle != null) {
    previousClose = _validPreviousClose(
      precedingCandle?.close ?? quote.previousClose,
    );
    low = _minimum(<double>[currentCandle.low, quote.bid, quote.ask]);
    high = _maximum(<double>[currentCandle.high, quote.bid, quote.ask]);
  } else if (precedingCandle != null) {
    previousClose = _validPreviousClose(precedingCandle.close);
    low = _minimum(<double>[quote.bid, quote.ask]);
    high = _maximum(<double>[quote.bid, quote.ask]);
  } else {
    previousClose = _validPreviousClose(quote.previousClose);
    final explicitRange = _validDailyRange(quote.dailyLow, quote.dailyHigh);
    low = explicitRange?.$1;
    high = explicitRange?.$2;
  }

  if (retainedDisplay != null &&
      _isSameUtcDate(retainedDisplay.timestamp, timestamp)) {
    final retainedRange = _validDailyRange(
      retainedDisplay.low,
      retainedDisplay.high,
    );
    if (retainedRange != null) {
      low = low == null
          ? retainedRange.$1
          : _minimum(<double>[low, retainedRange.$1]);
      high = high == null
          ? retainedRange.$2
          : _maximum(<double>[high, retainedRange.$2]);
    }
  }

  final priceChange = previousClose == null ? null : quote.bid - previousClose;
  final scaledPointChange = priceChange == null ? null : priceChange * factor;
  final pointChange = scaledPointChange != null && scaledPointChange.isFinite
      ? scaledPointChange.round()
      : null;
  final calculatedPercentChange = priceChange == null
      ? null
      : priceChange / previousClose! * 100;
  final percentChange = calculatedPercentChange?.isFinite ?? false
      ? calculatedPercentChange
      : null;
  final scaledSpread = (quote.ask - quote.bid) * factor;
  if (!scaledSpread.isFinite) {
    throw ArgumentError('The live quote spread must be finite.');
  }

  return MarketQuoteDisplay(
    timestamp: timestamp,
    digits: digits,
    previousClose: previousClose,
    pointChange: pointChange,
    percentChange: percentChange,
    low: low,
    high: high,
    spreadPoints: scaledSpread.round(),
  );
}

bool isUsableMarketQuote(DemoQuote quote) =>
    quote.bid.isFinite &&
    quote.bid > 0 &&
    quote.ask.isFinite &&
    quote.ask > 0 &&
    quote.ask >= quote.bid;

MarketQuoteDisplay buildUnavailableMarketQuoteDisplay({
  required DemoQuote quote,
  required DateTime receivedAt,
}) => MarketQuoteDisplay(
  timestamp: (quote.sourceTimestamp ?? receivedAt).toUtc(),
  digits: marketQuoteDigits(quote),
  previousClose: null,
  pointChange: null,
  percentChange: null,
  low: null,
  high: null,
  spreadPoints: 0,
);

bool _hasValidOhlc(MarketCandle candle) {
  final prices = <double>[candle.open, candle.high, candle.low, candle.close];
  if (prices.any((price) => !price.isFinite || price <= 0)) return false;
  return candle.low <= candle.open &&
      candle.low <= candle.close &&
      candle.high >= candle.open &&
      candle.high >= candle.close;
}

double? _validPreviousClose(double? value) {
  return value != null && value.isFinite && value > 0 ? value : null;
}

(double, double)? _validDailyRange(double? low, double? high) {
  if (low == null || high == null) return null;
  if (!low.isFinite || !high.isFinite || low <= 0 || high <= 0) return null;
  return low <= high ? (low, high) : null;
}

int marketQuoteDigits(DemoQuote quote) {
  final symbol = quote.symbol.toUpperCase();
  if (isGoldTradingSymbol(symbol)) return goldPriceFractionDigits;
  if (symbol.startsWith('XAU')) return 2;
  if (symbol.startsWith('BTC')) return 2;
  if (quote.bid.abs() >= 100) return 3;
  return 5;
}

double _priceFactor(int digits) => switch (digits) {
  2 => 100,
  3 => 1000,
  4 => 10000,
  _ => 100000,
};

bool _isAfterUtcDate(DateTime candidate, DateTime reference) {
  return _utcDate(candidate).isAfter(_utcDate(reference));
}

bool _isSameUtcDate(DateTime left, DateTime right) {
  return _utcDate(left) == _utcDate(right);
}

DateTime _utcDate(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

double _minimum(List<double> values) {
  return values.reduce((value, next) => value < next ? value : next);
}

double _maximum(List<double> values) {
  return values.reduce((value, next) => value > next ? value : next);
}
