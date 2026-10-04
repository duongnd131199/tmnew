import 'package:exness/features/trading/data/market_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quote and candle parse the production market contract', () {
    final quote = MarketQuote.fromJson({
      'symbol': 'XAUUSD+',
      'bid': 4378.062,
      'ask': 4378.322,
      'timestamp': '2026-09-18T20:57:57.371+00:00',
      'source': 'Exness-MT5Trial7',
    });
    final candle = MarketCandle.fromJson({
      'symbol': 'XAUUSD+',
      'timeframe': 'M1',
      'time': '2026-09-18T20:57:00+00:00',
      'open': 4378.496,
      'high': 4378.694,
      'low': 4377.447,
      'close': 4378.062,
      'volume': 135,
    });

    expect(quote.mid, closeTo(4378.192, 0.000001));
    expect(candle.isDown, isTrue);
    expect(candle.time.isUtc, isTrue);
    expect(marketSymbol('XAU/USD'), 'XAUUSD+');
    expect(marketLabel('XAUUSD+'), 'XAU/USD');
  });
}
