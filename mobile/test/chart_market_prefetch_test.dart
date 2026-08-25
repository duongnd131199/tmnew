import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

void main() {
  test('production warmup prefetches every chart timeframe', () async {
    final requests = <MarketDataRequest>[];
    final container = ProviderContainer(
      overrides: [
        marketApiConfigProvider.overrideWithValue(
          const MarketApiConfig(baseUrl: 'https://market.example.com'),
        ),
        marketCandlesProvider.overrideWith((ref, request) {
          requests.add(request);
          return Stream.value([
            MarketCandle(
              time: DateTime.utc(2026, 8, 24),
              open: 4600,
              high: 4610,
              low: 4590,
              close: 4605,
            ),
          ]);
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      chartMarketWarmupProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    await container.read(chartMarketWarmupProvider.future);

    expect(requests, const [
      MarketDataRequest('XAUUSD+', 'M1'),
      MarketDataRequest('XAUUSD+', 'M5'),
      MarketDataRequest('XAUUSD+', 'M15'),
      MarketDataRequest('XAUUSD+', 'M30'),
      MarketDataRequest('XAUUSD+', 'H1'),
      MarketDataRequest('XAUUSD+', 'H4'),
      MarketDataRequest('XAUUSD+', 'D1'),
      MarketDataRequest('XAUUSD+', 'W1'),
      MarketDataRequest('XAUUSD+', 'MN'),
    ]);
  });
}
