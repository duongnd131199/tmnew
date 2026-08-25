import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/mock_quote_service.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  const service = MockQuoteService();
  const quote = DemoQuote(
    symbol: 'XAUUSD',
    name: 'Gold / US Dollar',
    bid: 3345.20,
    ask: 3345.65,
    changePercent: 0.42,
  );

  test('next tick changes price and preserves spread', () {
    final next = service.nextQuote(quote, 0.8);

    expect(next.bid, greaterThan(quote.bid));
    expect(next.ask - next.bid, closeTo(quote.ask - quote.bid, 0.000001));
  });

  test('default quote cadence matches the fast video feed', () {
    expect(service.tickInterval, const Duration(milliseconds: 350));
  });

  test('quote stream emits initial quote and a following tick', () async {
    const fastService = MockQuoteService(
      tickInterval: Duration(milliseconds: 1),
    );
    final ticks = await fastService.watchQuote(quote).take(2).toList();

    expect(ticks.first.bid, quote.bid);
    expect(ticks.last.bid, isNot(quote.bid));
  });

  test('application demo feed is not frozen by the host calendar', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(mockQuoteServiceProvider).freezeWhenMarketClosed,
      isFalse,
    );
  });
}
