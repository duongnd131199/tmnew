import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/market_watch/domain/market_quote_display.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

void main() {
  group('buildMarketQuoteDisplay', () {
    test('XAUG ETF retains its legacy two-digit Market Watch precision', () {
      for (final bid in <double>[42.12345, 142.12345]) {
        final quote = DemoQuote(
          symbol: 'XAUG',
          name: 'US Goldmining ETF',
          bid: bid,
          ask: bid + .01,
          changePercent: 0,
        );

        expect(marketQuoteDigits(quote), 2);
      }
    });

    test(
      'uses the preceding D1 close and includes live XAU prices in the range',
      () {
        final quote = DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold',
          bid: 1999.500,
          ask: 2001.250,
          changePercent: 88.88,
          sourceTimestamp: DateTime.parse('2026-08-31T20:15:42+07:00'),
        );
        final candles = <MarketCandle>[
          MarketCandle(
            time: DateTime.utc(2026, 8, 31),
            open: 2000.000,
            high: 2001.000,
            low: 2000.000,
            close: 2000.750,
          ),
          MarketCandle(
            time: DateTime.utc(2026, 8, 30),
            open: 1998.000,
            high: 2002.000,
            low: 1997.000,
            close: 2000.000,
          ),
        ];

        final display = buildMarketQuoteDisplay(
          quote: quote,
          dailyCandles: candles,
          receivedAt: DateTime.utc(2026, 8, 31, 13, 16),
        );

        expect(display.timestamp, DateTime.utc(2026, 8, 31, 13, 15, 42));
        expect(display.digits, 3);
        expect(display.previousClose, 2000.000);
        expect(display.pointChange, -500);
        expect(display.percentChange, closeTo(-0.025, 0.000000001));
        expect(display.low, 1999.500);
        expect(display.high, 2001.250);
        expect(display.spreadPoints, 1750);
      },
    );

    test('treats a stale latest D1 candle as the previous session', () {
      final quote = DemoQuote(
        symbol: 'EURUSD',
        name: 'Euro vs US Dollar',
        bid: 1.10255,
        ask: 1.10265,
        changePercent: -77.77,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 9, 8, 7),
      );
      final candles = <MarketCandle>[
        MarketCandle(
          time: DateTime.utc(2026, 8, 30),
          open: 1.09500,
          high: 1.10500,
          low: 1.09000,
          close: 1.10000,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 28),
          open: 1.09000,
          high: 1.10000,
          low: 1.08500,
          close: 1.09500,
        ),
      ];

      final display = buildMarketQuoteDisplay(
        quote: quote,
        dailyCandles: candles,
        receivedAt: DateTime.utc(2026, 8, 31, 9, 9),
      );

      expect(display.digits, 5);
      expect(display.previousClose, 1.10000);
      expect(display.pointChange, 255);
      expect(display.percentChange, closeTo(0.2318181818, 0.0000000001));
      expect(display.low, 1.10255);
      expect(display.high, 1.10265);
      expect(display.spreadPoints, 10);
    });

    test(
      'uses BTC precision and explicit statistics when D1 is unavailable',
      () {
        final quote = DemoQuote(
          symbol: 'BTCUSD',
          name: 'Bitcoin',
          bid: 65000.25,
          ask: 65000.75,
          changePercent: 55.55,
          previousClose: 65000.00,
          dailyLow: 64000.00,
          dailyHigh: 66000.00,
        );

        final display = buildMarketQuoteDisplay(
          quote: quote,
          dailyCandles: const <MarketCandle>[],
          receivedAt: DateTime.parse('2026-08-31T20:15:42+07:00'),
        );

        expect(display.timestamp, DateTime.utc(2026, 8, 31, 13, 15, 42));
        expect(display.digits, 2);
        expect(display.previousClose, 65000.00);
        expect(display.pointChange, 25);
        expect(display.percentChange, closeTo(0.0003846154, 0.0000000001));
        expect(display.low, 64000.00);
        expect(display.high, 66000.00);
        expect(display.spreadPoints, 50);
      },
    );

    test(
      'does not manufacture missing statistics from demo change percent',
      () {
        final quote = DemoQuote(
          symbol: 'GBPUSD',
          name: 'British Pound vs US Dollar',
          bid: 1.35000,
          ask: 1.35020,
          changePercent: 12.34,
          sourceTimestamp: DateTime.utc(2026, 8, 31, 12),
        );

        final display = buildMarketQuoteDisplay(
          quote: quote,
          dailyCandles: const <MarketCandle>[],
          receivedAt: DateTime.utc(2026, 8, 31, 12, 1),
        );

        expect(display.previousClose, isNull);
        expect(display.pointChange, isNull);
        expect(display.percentChange, isNull);
        expect(display.low, isNull);
        expect(display.high, isNull);
      },
    );

    test('rejects non-finite live bid and ask prices', () {
      DemoQuote quote({required double bid, required double ask}) => DemoQuote(
        symbol: 'EURUSD',
        name: 'Euro vs US Dollar',
        bid: bid,
        ask: ask,
        changePercent: 0,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 12),
      );

      expect(
        () => buildMarketQuoteDisplay(
          quote: quote(bid: double.nan, ask: 1.10020),
          dailyCandles: const <MarketCandle>[],
          receivedAt: DateTime.utc(2026, 8, 31, 12, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => buildMarketQuoteDisplay(
          quote: quote(bid: 1.10000, ask: double.infinity),
          dailyCandles: const <MarketCandle>[],
          receivedAt: DateTime.utc(2026, 8, 31, 12, 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive and crossed live prices', () {
      DemoQuote quote({required double bid, required double ask}) => DemoQuote(
        symbol: 'EURUSD',
        name: 'Euro vs US Dollar',
        bid: bid,
        ask: ask,
        changePercent: 0,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 12),
      );

      for (final prices in <(double, double)>[
        (0, 1.10020),
        (-1, 1.10020),
        (1.10000, 0),
        (1.10000, -1),
        (1.10020, 1.10000),
      ]) {
        expect(
          () => buildMarketQuoteDisplay(
            quote: quote(bid: prices.$1, ask: prices.$2),
            dailyCandles: const <MarketCandle>[],
            receivedAt: DateTime.utc(2026, 8, 31, 12, 1),
          ),
          throwsArgumentError,
          reason: 'bid=${prices.$1}, ask=${prices.$2}',
        );
      }
    });

    test('ignores non-finite explicit statistics', () {
      final quote = DemoQuote(
        symbol: 'EURUSD',
        name: 'Euro vs US Dollar',
        bid: 1.10000,
        ask: 1.10020,
        changePercent: 0,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 12),
        previousClose: double.nan,
        dailyLow: double.negativeInfinity,
        dailyHigh: double.infinity,
      );

      final display = buildMarketQuoteDisplay(
        quote: quote,
        dailyCandles: const <MarketCandle>[],
        receivedAt: DateTime.utc(2026, 8, 31, 12, 1),
      );

      expect(display.previousClose, isNull);
      expect(display.pointChange, isNull);
      expect(display.percentChange, isNull);
      expect(display.low, isNull);
      expect(display.high, isNull);
    });

    test('ignores zero and negative explicit previous closes', () {
      for (final previousClose in <double>[0, -1]) {
        final display = buildMarketQuoteDisplay(
          quote: DemoQuote(
            symbol: 'EURUSD',
            name: 'Euro vs US Dollar',
            bid: 1.10000,
            ask: 1.10020,
            changePercent: 0,
            sourceTimestamp: DateTime.utc(2026, 8, 31, 12),
            previousClose: previousClose,
            dailyLow: 1.09000,
            dailyHigh: 1.11000,
          ),
          dailyCandles: const <MarketCandle>[],
          receivedAt: DateTime.utc(2026, 8, 31, 12, 1),
        );

        expect(display.previousClose, isNull, reason: '$previousClose');
        expect(display.pointChange, isNull, reason: '$previousClose');
        expect(display.percentChange, isNull, reason: '$previousClose');
        expect(display.low, 1.09000);
        expect(display.high, 1.11000);
      }
    });

    test('keeps explicit daily low and high only as a valid pair', () {
      for (final range in <(double?, double?)>[
        (0, 1.11000),
        (-1, 1.11000),
        (1.09000, 0),
        (1.09000, -1),
        (1.12000, 1.11000),
        (null, 1.11000),
        (1.09000, null),
      ]) {
        final display = buildMarketQuoteDisplay(
          quote: DemoQuote(
            symbol: 'EURUSD',
            name: 'Euro vs US Dollar',
            bid: 1.10000,
            ask: 1.10020,
            changePercent: 0,
            sourceTimestamp: DateTime.utc(2026, 8, 31, 12),
            previousClose: 1.09500,
            dailyLow: range.$1,
            dailyHigh: range.$2,
          ),
          dailyCandles: const <MarketCandle>[],
          receivedAt: DateTime.utc(2026, 8, 31, 12, 1),
        );

        expect(display.low, isNull, reason: '$range');
        expect(display.high, isNull, reason: '$range');
      }
    });

    test('ignores D1 candles with invalid OHLC values', () {
      final invalidCurrentCandles = <MarketCandle>[
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: double.nan,
          high: 1.12000,
          low: 1.09000,
          close: 1.11000,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 1.10000,
          high: double.infinity,
          low: 1.09000,
          close: 1.11000,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 1.10000,
          high: 1.12000,
          low: double.negativeInfinity,
          close: 1.11000,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 1.10000,
          high: 1.12000,
          low: 1.09000,
          close: double.nan,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 1.10000,
          high: 1.12000,
          low: 1.09000,
          close: 0,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 1.10000,
          high: 1.12000,
          low: 1.09000,
          close: -1,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 1.10000,
          high: 1.08000,
          low: 1.09000,
          close: 1.09500,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 1.13000,
          high: 1.12000,
          low: 1.09000,
          close: 1.11000,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 1.10000,
          high: 1.12000,
          low: 1.09000,
          close: 1.08000,
        ),
      ];
      final previous = MarketCandle(
        time: DateTime.utc(2026, 8, 30),
        open: 1.09000,
        high: 1.11000,
        low: 1.08000,
        close: 1.10000,
      );
      final quote = DemoQuote(
        symbol: 'EURUSD',
        name: 'Euro vs US Dollar',
        bid: 1.10500,
        ask: 1.10600,
        changePercent: 0,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 12),
      );

      for (final invalidCurrent in invalidCurrentCandles) {
        final display = buildMarketQuoteDisplay(
          quote: quote,
          dailyCandles: <MarketCandle>[previous, invalidCurrent],
          receivedAt: DateTime.utc(2026, 8, 31, 12, 1),
        );

        expect(display.previousClose, 1.10000);
        expect(display.pointChange, 500);
        expect(display.low, 1.10500);
        expect(display.high, 1.10600);
      }
    });

    test(
      'classifies offset timestamps by UTC date and excludes future UTC D1',
      () {
        final quote = DemoQuote(
          symbol: 'EURUSD',
          name: 'Euro vs US Dollar',
          bid: 1.10500,
          ask: 1.10600,
          changePercent: 0,
          sourceTimestamp: DateTime.parse('2026-08-31T01:30:00+07:00'),
        );
        final candles = <MarketCandle>[
          MarketCandle(
            time: DateTime.parse('2026-08-31T07:00:00+07:00'),
            open: 8.00000,
            high: 9.00000,
            low: 7.00000,
            close: 8.50000,
          ),
          MarketCandle(
            time: DateTime.parse('2026-08-31T00:30:00+07:00'),
            open: 1.10000,
            high: 1.12000,
            low: 1.09000,
            close: 1.11000,
          ),
          MarketCandle(
            time: DateTime.parse('2026-08-30T06:00:00+07:00'),
            open: 1.09000,
            high: 1.11000,
            low: 1.08000,
            close: 1.10000,
          ),
        ];

        final display = buildMarketQuoteDisplay(
          quote: quote,
          dailyCandles: candles,
          receivedAt: DateTime.utc(2026, 8, 30, 18, 31),
        );

        expect(display.timestamp, DateTime.utc(2026, 8, 30, 18, 30));
        expect(display.previousClose, 1.10000);
        expect(display.pointChange, 500);
        expect(display.low, 1.09000);
        expect(display.high, 1.12000);
      },
    );

    test('retains live session extrema until the UTC trading date changes', () {
      final candles = <MarketCandle>[
        MarketCandle(
          time: DateTime.utc(2026, 8, 30),
          open: 99,
          high: 101,
          low: 98,
          close: 100,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 100,
          high: 102,
          low: 99,
          close: 101,
        ),
      ];
      final first = buildMarketQuoteDisplay(
        quote: DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold',
          bid: 105,
          ask: 105.1,
          changePercent: 0,
          sourceTimestamp: DateTime.utc(2026, 8, 31, 12),
        ),
        dailyCandles: candles,
        receivedAt: DateTime.utc(2026, 8, 31, 12),
      );

      final second = buildMarketQuoteDisplay(
        quote: DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold',
          bid: 104,
          ask: 104.1,
          changePercent: 0,
          sourceTimestamp: DateTime.utc(2026, 8, 31, 12, 0, 1),
        ),
        dailyCandles: candles,
        receivedAt: DateTime.utc(2026, 8, 31, 12, 0, 1),
        retainedDisplay: first,
      );

      expect(first.high, 105.1);
      expect(second.high, 105.1);
      expect(second.low, 99);
    });
  });
}
