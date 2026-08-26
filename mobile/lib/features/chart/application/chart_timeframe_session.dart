import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/chart/presentation/navigation/chart_navigation.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_price_viewport.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';

@immutable
final class ChartViewSnapshot {
  const ChartViewSnapshot({
    required this.symbol,
    required this.timeframe,
    required this.viewport,
    required this.priceViewport,
  });

  final String symbol;
  final String timeframe;
  final ChartViewport viewport;
  final ChartPriceViewport priceViewport;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartViewSnapshot &&
          other.symbol == symbol &&
          other.timeframe == timeframe &&
          other.viewport == viewport &&
          other.priceViewport == priceViewport;

  @override
  int get hashCode => Object.hash(symbol, timeframe, viewport, priceViewport);
}

@immutable
final class ChartViewSessionState {
  ChartViewSessionState({
    this.activeSymbol,
    Map<String, ChartViewSnapshot>? views,
  }) : views = Map.unmodifiable(views ?? const <String, ChartViewSnapshot>{});

  static final empty = ChartViewSessionState();

  final String? activeSymbol;
  final Map<String, ChartViewSnapshot> views;

  ChartViewSnapshot? viewFor(String symbol) => views[chartSymbolKey(symbol)];

  ChartViewSessionState remember(ChartViewSnapshot snapshot) =>
      ChartViewSessionState(
        activeSymbol: snapshot.symbol,
        views: {...views, chartSymbolKey(snapshot.symbol): snapshot},
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartViewSessionState &&
          other.activeSymbol == activeSymbol &&
          mapEquals(other.views, views);

  @override
  int get hashCode => Object.hash(
    activeSymbol,
    Object.hashAllUnordered(
      views.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

String chartSymbolKey(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  return normalized.endsWith('+')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
}

final chartViewSessionSeedProvider = Provider<ChartViewSessionState>(
  (ref) => ChartViewSessionState.empty,
);

abstract interface class ChartViewSessionStore {
  Future<ChartViewSessionState> read();

  Future<void> write(ChartViewSessionState value);
}

final class NoopChartViewSessionStore implements ChartViewSessionStore {
  const NoopChartViewSessionStore();

  @override
  Future<ChartViewSessionState> read() async => ChartViewSessionState.empty;

  @override
  Future<void> write(ChartViewSessionState value) async {}
}

final chartViewSessionStoreProvider = Provider<ChartViewSessionStore>(
  (ref) => const NoopChartViewSessionStore(),
);

final chartTimeframeSessionProvider =
    NotifierProvider<ChartTimeframeSessionController, ChartViewSessionState>(
      ChartTimeframeSessionController.new,
    );

final class ChartTimeframeSessionController
    extends Notifier<ChartViewSessionState> {
  Future<void> _pendingWrite = Future<void>.value();

  @override
  ChartViewSessionState build() => ref.watch(chartViewSessionSeedProvider);

  String? get activeSymbol => state.activeSymbol;

  ChartViewSnapshot? viewFor(String symbol) => state.viewFor(symbol);

  String timeframeFor(String symbol) {
    final key = chartSymbolKey(symbol);
    return state.views[key]?.timeframe ?? defaultChartTimeframe(key);
  }

  void remember(
    String symbol,
    String timeframe, {
    ChartViewport viewport = const ChartViewport(),
    ChartPriceViewport priceViewport = const ChartPriceViewport.auto(),
  }) {
    final next = state.remember(
      ChartViewSnapshot(
        symbol: symbol,
        timeframe: timeframe,
        viewport: viewport,
        priceViewport: priceViewport,
      ),
    );
    if (next == state) return;
    state = next;
    final store = ref.read(chartViewSessionStoreProvider);
    _pendingWrite = _pendingWrite
        .then((_) => store.write(next))
        .catchError((Object _) {});
  }

  Future<void> flush() => _pendingWrite;
}
