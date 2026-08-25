import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

const chartWarmupTimeframes = <String>[
  'M1',
  'M5',
  'M15',
  'M30',
  'H1',
  'H4',
  'D1',
  'W1',
  'MN',
];

/// Starts every chart-history request for one symbol without blocking UI.
/// Watching the provider futures keeps the warmed histories available for an
/// immediate timeframe switch and shares in-flight requests with ChartScreen.
final chartSymbolMarketWarmupProvider = FutureProvider.autoDispose
    .family<void, String>((ref, symbol) async {
      if (!ref.watch(marketApiConfigProvider).enabled) return;

      await Future.wait([
        for (final timeframe in chartWarmupTimeframes)
          ref.watch(
            marketCandlesProvider(MarketDataRequest(symbol, timeframe)).future,
          ),
      ]);
    });

/// Starts the default XAUUSD warmup while the user is still on another tab.
final chartMarketWarmupProvider = FutureProvider.autoDispose<void>((ref) async {
  await ref.watch(chartSymbolMarketWarmupProvider('XAUUSD+').future);
});
