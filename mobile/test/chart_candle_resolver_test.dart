import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_candle_resolver.dart';

void main() {
  test('H4 fallback stays in the live quote price domain', () {
    final resolved = const ChartCandleResolver(
      symbol: 'XAUUSD+',
      referencePrice: 2000,
      currentPrice: 4637.22,
      timeframe: 'H4',
      loadingPlaceholder: false,
      useRealtimeCandles: false,
    ).resolve(const [], const []);

    final largestBody = resolved
        .map((candle) => (candle.close - candle.open).abs())
        .reduce((left, right) => left > right ? left : right);

    expect(resolved, hasLength(360));
    expect(largestBody, lessThan(500));
    expect(resolved.last.close, 4637.22);
  });
}
