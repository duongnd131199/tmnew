import 'package:exness/features/chart/domain/video_chart_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video XAU chart has a stable 1m snapshot and bid/ask', () {
    final candles = videoChartCandles('XAUUSD+', 'M1');
    expect(candles, hasLength(60));
    expect(candles.first.time, DateTime.utc(2026, 9, 20, 19, 59));
    expect(candles.last.time, DateTime.utc(2026, 9, 20, 20, 58));
    expect(candles[24].high, greaterThan(4383));
    expect(candles[53].close, lessThan(4377));
    expect(candles.last.close, closeTo(4378.2, 0.2));
    expect(
      candles.map((c) => c.high).reduce((a, b) => a > b ? a : b),
      greaterThan(4382),
    );
    expect(
      candles.map((c) => c.low).reduce((a, b) => a < b ? a : b),
      lessThan(4376),
    );
    expect(videoChartQuote('XAUUSD+').bid, 4378.101);
    expect(videoChartQuote('XAUUSD+').ask, 4378.283);
  });
}
