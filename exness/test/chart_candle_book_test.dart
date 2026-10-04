import 'package:exness/features/chart/domain/chart_candle_book.dart';
import 'package:exness/features/trading/data/market_api.dart';
import 'package:flutter_test/flutter_test.dart';

MarketCandle candle(int minute, double open, double close) => MarketCandle(
  symbol: 'XAUUSD+',
  timeframe: 'M1',
  time: DateTime.utc(2026, 9, 18, 20, minute),
  open: open,
  high: open > close ? open : close,
  low: open < close ? open : close,
  close: close,
  volume: 10,
);

MarketQuote quote(int minute, int second, double bid) => MarketQuote(
  symbol: 'XAUUSD+',
  bid: bid,
  ask: bid + 0.25,
  timestamp: DateTime.utc(2026, 9, 18, 20, minute, second),
  source: 'test',
);

void main() {
  test('sorts candles and keeps the latest duplicate timestamp', () {
    final book = ChartCandleBook('XAUUSD+', 'M1');
    book.replace([candle(2, 11, 12), candle(1, 9, 10), candle(2, 11, 13)]);

    expect(book.candles.map((item) => item.time.minute), [1, 2]);
    expect(book.candles.last.close, 13);
  });

  test('updates only the current candle from a newer quote', () {
    final book = ChartCandleBook('XAUUSD+', 'M1');
    book.replace([candle(57, 4378.4, 4378.1)]);

    final changed = book.acceptQuote(quote(57, 58, 4377.8));
    expect(changed?.time.minute, 57);
    expect(book.candles.single.open, 4378.4);
    expect(book.candles.single.low, 4377.8);
    expect(book.candles.single.close, 4377.8);
    expect(book.acceptQuote(quote(57, 57, 4400)), isNull);
    expect(book.candles.single.high, 4378.4);
  });

  test('starts a new timeframe bucket and ignores old or wrong symbols', () {
    final book = ChartCandleBook('XAUUSD+', 'M5');
    book.replace([
      MarketCandle(
        symbol: 'XAUUSD+',
        timeframe: 'M5',
        time: DateTime.utc(2026, 9, 18, 20, 55),
        open: 4378,
        high: 4379,
        low: 4377,
        close: 4378.5,
        volume: 5,
      ),
    ]);

    expect(book.acceptQuote(quote(56, 3, 4378.7))?.time.minute, 55);
    expect(book.acceptQuote(quote(59, 59, 4378.8))?.time.minute, 55);
    expect(book.acceptQuote(quote(0, 1, 4379)), isNull);
    final next = MarketQuote(
      symbol: 'XAUUSD+',
      bid: 4379,
      ask: 4379.25,
      timestamp: DateTime.utc(2026, 9, 18, 21),
      source: 'test',
    );
    expect(book.acceptQuote(next)?.time.hour, 21);
    expect(book.candles.last.open, 4379);
    expect(book.candles.length, 2);
  });
}
