import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/realtime_market_service.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

final marketApiConfigProvider = Provider<MarketApiConfig>(
  (ref) => const MarketApiConfig(),
);

final realtimeMarketServiceProvider = Provider<RealtimeMarketService>((ref) {
  final config = ref.watch(marketApiConfigProvider);
  final service = RealtimeMarketService(
    baseUrl: config.normalizedBaseUrl,
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    ),
  );
  ref.onDispose(() => guardRealtimeCleanup(service.dispose()));
  return service;
});

final marketConnectionStatusProvider = StreamProvider<MarketConnectionStatus>((
  ref,
) {
  final config = ref.watch(marketApiConfigProvider);
  if (!config.enabled) {
    return Stream.value(MarketConnectionStatus.disconnected);
  }
  return ref.watch(realtimeMarketServiceProvider).statuses;
});

final realtimeCandleProvider = StreamProvider.autoDispose
    .family<MarketCandle, MarketDataRequest>((ref, request) {
      final config = ref.watch(marketApiConfigProvider);
      if (!config.enabled) return const Stream.empty();
      return ref.watch(realtimeMarketServiceProvider).watchCandle(request);
    });
