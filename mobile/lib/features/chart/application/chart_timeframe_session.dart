import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/chart/presentation/navigation/chart_navigation.dart';

final chartTimeframeSessionProvider =
    NotifierProvider<ChartTimeframeSessionController, Map<String, String>>(
      ChartTimeframeSessionController.new,
    );

final class ChartTimeframeSessionController
    extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  String timeframeFor(String symbol) {
    final key = _symbolKey(symbol);
    return state[key] ?? defaultChartTimeframe(key);
  }

  void remember(String symbol, String timeframe) {
    final key = _symbolKey(symbol);
    if (state[key] == timeframe) return;
    state = {...state, key: timeframe};
  }

  String _symbolKey(String symbol) {
    final normalized = symbol.trim().toUpperCase();
    return normalized.endsWith('+')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }
}
