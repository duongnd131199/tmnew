class MarketCandle {
  const MarketCandle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
}

class MarketDataRequest {
  const MarketDataRequest(this.symbol, this.timeframe);

  final String symbol;
  final String timeframe;

  @override
  bool operator ==(Object other) =>
      other is MarketDataRequest &&
      other.symbol == symbol &&
      other.timeframe == timeframe;

  @override
  int get hashCode => Object.hash(symbol, timeframe);
}
