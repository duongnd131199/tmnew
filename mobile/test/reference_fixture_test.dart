import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/mock_quote_service.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = createVideoReferenceContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('video two watchlist contains XAUUSD+ and BTCUSD fixtures', () {
    final symbols = container.read(marketSymbolsProvider);
    final quotes = {
      for (final quote in container.read(demoQuotesProvider))
        quote.symbol: quote,
    };

    expect(symbols, const ['XAUUSD+', 'BTCUSD']);
    expect(quotes['XAUUSD+']!.name, 'Gold US Dollar');
    expect(quotes['XAUUSD+']!.bid, 4104.09);
    expect(quotes['XAUUSD+']!.ask, 4104.22);
    expect(quotes['BTCUSD']!.name, 'Bitcoin');
    expect(quotes['BTCUSD']!.bid, 65175.98);
    expect(quotes['BTCUSD']!.ask, 65193.10);
  });

  test('account list and default Vantage positions match video two', () {
    final accounts = container.read(demoAccountsProvider);
    final state = container.read(demoTradingProvider);

    expect(accounts.map((account) => account.id), const [
      '10001001',
      '10001002',
      '10001003',
      '10001004',
    ]);
    expect(state.positions, hasLength(6));
    expect(state.positions.map((position) => position.openPrice), const [
      4104.46,
      4105.03,
      4105.05,
      4105.04,
      4105.04,
      4105.04,
    ]);
    expect(
      state.positions.every(
        (position) =>
            position.symbol == 'XAUUSD+' &&
            position.side == 'BUY' &&
            position.volume == .25,
      ),
      isTrue,
    );
  });

  test('initial Vantage account metrics match video two', () {
    final account = container.read(demoAccountProvider);

    expect(account.balance.toStringAsFixed(2), '2292.60');
    expect(account.profit.toStringAsFixed(2), '-128.00');
    expect(account.equity.toStringAsFixed(2), '2164.60');
    expect(account.margin.toStringAsFixed(2), '1231.48');
    expect(account.freeMargin.toStringAsFixed(2), '933.12');
    expect(account.marginLevel.toStringAsFixed(2), '175.77');
  });

  test('switching accounts atomically swaps trade and history fixtures', () {
    container.read(activeDemoAccountIdProvider.notifier).select('10001002');
    final huge = container.read(demoTradingProvider);
    final hugeSnapshot = container.read(demoAccountProvider);

    expect(container.read(activeDemoAccountProvider).name, 'Demo Account Two');
    expect(huge.positions, hasLength(10));
    expect(huge.positions.first.volume, 179);
    expect(hugeSnapshot.balance, 27297978.10);
    expect(hugeSnapshot.profit.toStringAsFixed(2), '-1013283.20');
    expect(container.read(demoHistoryPositionsProvider).length, 37);

    container.read(activeDemoAccountIdProvider.notifier).select('10001003');
    expect(container.read(demoTradingProvider).positions, isEmpty);
    expect(container.read(demoAccountProvider).balance, 0);
    expect(container.read(demoHistoryPositionsProvider), isEmpty);
  });

  test('mock tick changes bid while preserving spread and daily change', () {
    final initial = container
        .read(demoQuotesProvider)
        .firstWhere((quote) => quote.symbol == 'XAUUSD+');
    final next = const MockQuoteService().nextQuote(initial, 0.8);

    expect(next.bid, isNot(initial.bid));
    expect(
      next.ask - next.bid,
      closeTo(initial.ask - initial.bid, 0.000000001),
    );
    expect(next.changePercent, initial.changePercent);
  });

  test(
    'live XAU stream visibly ticks while staying in the video range',
    () async {
      final initial = container
          .read(demoQuotesProvider)
          .firstWhere((quote) => quote.symbol == 'XAUUSD+');
      final ticks = await const MockQuoteService(
        tickInterval: Duration(milliseconds: 1),
      ).watchQuote(initial).take(60).toList();

      expect(
        ticks.map((quote) => quote.bid.toStringAsFixed(2)).toSet().length,
        greaterThan(1),
      );
      for (final tick in ticks) {
        expect((tick.bid - initial.bid).abs(), lessThanOrEqualTo(2.800000001));
        expect(
          tick.ask - tick.bid,
          closeTo(initial.ask - initial.bid, 0.000000001),
        );
      }
    },
  );
}
