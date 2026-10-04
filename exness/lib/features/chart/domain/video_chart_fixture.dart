import '../../trading/data/market_api.dart';

/// Fixed chart snapshot from the visual reference. Kept separate from all
/// account and market services so it cannot be mistaken for a tradable quote.
List<MarketCandle> videoChartCandles(String symbol, String timeframe) {
  if (symbol == 'XAUUSD+' && timeframe == 'M1') {
    return [
      for (var i = 0; i < _videoGoldMinuteOhlc.length; i++)
        MarketCandle(
          symbol: symbol,
          timeframe: timeframe,
          time: DateTime.utc(2026, 9, 20, 19, 59).add(Duration(minutes: i)),
          open: _videoGoldMinuteOhlc[i].$1,
          high: _videoGoldMinuteOhlc[i].$2,
          low: _videoGoldMinuteOhlc[i].$3,
          close: _videoGoldMinuteOhlc[i].$4,
          volume: 0,
        ),
    ];
  }
  final stepMinutes = switch (timeframe) {
    'M5' => 5,
    'M15' => 15,
    'M30' => 30,
    'H1' => 60,
    'H4' => 240,
    'D1' => 1440,
    'W1' => 10080,
    'MN' => 43200,
    _ => 1,
  };
  final base = switch (symbol) {
    'BTCUSD' => 81424.77,
    'ETHUSD' => 2649.81,
    _ => 4378.2,
  };
  final scale = symbol == 'BTCUSD'
      ? 55.0
      : symbol == 'ETHUSD'
      ? 4.0
      : 1.0;
  const nodes = <(int, double)>[
    (0, 0.2),
    (5, 0.6),
    (9, 1.2),
    (13, 3.9),
    (18, 0.6),
    (23, 1.6),
    (28, 4.0),
    (33, 2.7),
    (37, 3.8),
    (41, 1.8),
    (46, 0.0),
    (49, -2.4),
    (52, 0.0),
    (55, 0.0),
  ];
  double offsetAt(int index) {
    for (var i = 1; i < nodes.length; i++) {
      final before = nodes[i - 1];
      final after = nodes[i];
      if (index <= after.$1) {
        final fraction = (index - before.$1) / (after.$1 - before.$1);
        return before.$2 + (after.$2 - before.$2) * fraction;
      }
    }
    return nodes.last.$2;
  }

  final result = <MarketCandle>[];
  var previous = base + offsetAt(0) * scale;
  for (var i = 0; i <= 55; i++) {
    final jitter = ((i * 17) % 9 - 4) * 0.073 * scale;
    final close = base + offsetAt(i) * scale + (i == 55 ? 0 : jitter);
    final open = i == 0 ? close - 0.22 * scale : previous;
    final wickTop = (0.17 + (i % 5) * 0.07) * scale;
    final wickBottom = (0.19 + (i % 4) * 0.085) * scale;
    result.add(
      MarketCandle(
        symbol: symbol,
        timeframe: timeframe,
        time: DateTime.utc(
          2026,
          9,
          20,
          20,
          3,
        ).add(Duration(minutes: i * stepMinutes)),
        open: open,
        high: (open > close ? open : close) + wickTop,
        low: (open < close ? open : close) - wickBottom,
        close: close,
        volume: 0,
      ),
    );
    previous = close;
  }
  return result;
}

// Approximate candle OHLC values measured from the reference video's chart
// frame. They are display-only data and never enter the market service.
const _videoGoldMinuteOhlc = <(double, double, double, double)>[
  (4378.744, 4378.961, 4375.597, 4376.961),
  (4377.178, 4377.752, 4376.031, 4376.651),
  (4376.527, 4377.690, 4376.527, 4377.690),
  (4377.736, 4378.000, 4377.736, 4378.000),
  (4378.806, 4378.806, 4377.271, 4377.271),
  (4377.876, 4377.876, 4376.744, 4376.760),
  (4377.287, 4378.775, 4377.209, 4377.736),
  (4377.628, 4378.248, 4376.992, 4378.047),
  (4378.016, 4378.837, 4378.016, 4378.806),
  (4378.822, 4378.837, 4378.760, 4378.760),
  (4378.775, 4378.775, 4378.481, 4378.481),
  (4377.829, 4378.837, 4377.829, 4378.837),
  (4378.481, 4380.884, 4378.388, 4379.535),
  (4379.442, 4380.047, 4378.791, 4379.907),
  (4379.504, 4382.434, 4379.504, 4382.419),
  (4382.341, 4382.357, 4381.488, 4381.488),
  (4381.504, 4381.504, 4381.364, 4381.364),
  (4381.535, 4381.690, 4381.271, 4381.271),
  (4381.225, 4381.442, 4380.620, 4381.442),
  (4381.411, 4381.783, 4379.163, 4379.411),
  (4379.442, 4380.295, 4379.132, 4379.752),
  (4379.628, 4379.860, 4379.628, 4379.860),
  (4379.597, 4381.349, 4379.597, 4381.349),
  (4381.209, 4381.349, 4381.209, 4381.349),
  (4381.271, 4383.054, 4381.271, 4383.054),
  (4383.008, 4383.054, 4382.016, 4382.915),
  (4382.992, 4383.039, 4382.450, 4382.713),
  (4382.713, 4383.023, 4382.481, 4382.481),
  (4382.527, 4382.527, 4382.016, 4382.031),
  (4382.651, 4382.651, 4381.984, 4381.984),
  (4382.279, 4382.279, 4380.930, 4380.930),
  (4381.271, 4381.535, 4381.054, 4381.054),
  (4381.054, 4382.279, 4381.054, 4382.279),
  (4382.326, 4382.341, 4381.736, 4381.783),
  (4381.798, 4382.016, 4381.798, 4382.000),
  (4382.078, 4382.651, 4381.984, 4382.651),
  (4383.070, 4383.070, 4381.767, 4381.767),
  (4382.248, 4382.279, 4381.457, 4381.488),
  (4381.504, 4381.566, 4380.651, 4381.457),
  (4381.194, 4381.194, 4380.140, 4380.155),
  (4380.217, 4380.233, 4380.217, 4380.233),
  (4380.171, 4380.202, 4380.000, 4380.031),
  (4379.984, 4379.984, 4379.132, 4379.132),
  (4379.550, 4380.264, 4379.535, 4380.233),
  (4380.078, 4380.822, 4379.628, 4380.682),
  (4380.899, 4380.915, 4380.310, 4380.667),
  (4380.651, 4380.977, 4380.651, 4380.977),
  (4380.977, 4380.977, 4379.535, 4379.566),
  (4379.860, 4379.860, 4378.977, 4378.977),
  (4379.519, 4379.535, 4377.581, 4377.581),
  (4378.078, 4378.589, 4376.775, 4378.434),
  (4378.527, 4378.527, 4377.302, 4378.062),
  (4378.078, 4378.186, 4378.078, 4378.186),
  (4378.186, 4378.186, 4376.961, 4376.961),
  (4377.116, 4378.093, 4377.085, 4378.062),
  (4377.767, 4378.527, 4377.767, 4378.527),
  (4378.062, 4378.558, 4377.581, 4378.233),
  (4378.233, 4378.558, 4377.581, 4378.186),
  (4378.124, 4378.620, 4377.984, 4378.605),
  (4378.279, 4378.434, 4378.109, 4378.109),
];

MarketQuote videoChartQuote(String symbol) {
  final (bid, ask) = switch (symbol) {
    'BTCUSD' => (81424.77, 81425.12),
    'ETHUSD' => (2649.81, 2650.02),
    _ => (4378.101, 4378.283),
  };
  return MarketQuote(
    symbol: symbol,
    bid: bid,
    ask: ask,
    timestamp: DateTime.utc(2026, 9, 20, 20, 58),
    source: 'video-demo',
  );
}
