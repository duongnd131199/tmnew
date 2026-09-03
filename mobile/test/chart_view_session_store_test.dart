import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/app/bootstrap.dart';
import 'package:trading_mobile/features/chart/application/chart_timeframe_session.dart';
import 'package:trading_mobile/features/chart/data/chart_view_session_store.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_price_viewport.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('secure chart session round-trips the complete selected view', () async {
    const store = SecureChartViewSessionStore(FlutterSecureStorage());
    final expected = ChartViewSessionState(
      activeSymbol: 'XAUUSD+',
      views: const {
        'XAUUSD': ChartViewSnapshot(
          symbol: 'XAUUSD+',
          timeframe: 'M15',
          viewport: ChartViewport(
            barSpacing: 11.2,
            scrollOffset: 64,
            rightPadding: 8,
          ),
          priceViewport: ChartPriceViewport.manual(
            centerPrice: 4650.25,
            range: 42.5,
          ),
        ),
      },
    );

    await store.write(expected);

    expect(await store.read(), expected);
  });

  test(
    'corrupt chart session falls back without blocking app startup',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureChartViewSessionStore.storageKey: '{not-json',
      });
      const store = SecureChartViewSessionStore(FlutterSecureStorage());

      expect(await store.read(), ChartViewSessionState.empty);
    },
  );

  test('chart session controller persists the latest complete view', () async {
    final store = _MemoryChartViewSessionStore();
    final container = ProviderContainer(
      overrides: [chartViewSessionStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final controller = container.read(chartTimeframeSessionProvider.notifier);

    controller.remember(
      'XAUUSD+',
      'M30',
      viewport: const ChartViewport(barSpacing: 12, scrollOffset: 20),
    );
    controller.remember(
      'XAUUSD+',
      'M15',
      viewport: const ChartViewport(barSpacing: 8, scrollOffset: 40),
      priceViewport: const ChartPriceViewport.manual(
        centerPrice: 4600,
        range: 30,
      ),
    );
    await controller.flush();

    expect(store.value.activeSymbol, 'XAUUSD+');
    final restored = store.value.viewFor('XAUUSD+');
    expect(restored?.timeframe, 'M15');
    expect(
      restored?.viewport,
      const ChartViewport(barSpacing: 8, scrollOffset: 40),
    );
    expect(
      restored?.priceViewport,
      const ChartPriceViewport.manual(centerPrice: 4600, range: 30),
    );
  });

  testWidgets('bootstrap hydrates the chart session before the first frame', (
    tester,
  ) async {
    final expected = ChartViewSessionState(
      activeSymbol: 'BTCUSD',
      views: const {
        'BTCUSD': ChartViewSnapshot(
          symbol: 'BTCUSD',
          timeframe: 'M30',
          viewport: ChartViewport(barSpacing: 9, scrollOffset: 36),
          priceViewport: ChartPriceViewport.auto(),
        ),
      },
    );
    final store = _MemoryChartViewSessionStore(expected);
    final root = await createBootstrapScope(
      chartViewSessionStore: store,
      child: Consumer(
        builder: (context, ref, child) => Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            ref
                    .watch(chartTimeframeSessionProvider)
                    .viewFor('BTCUSD')
                    ?.timeframe ??
                'missing',
          ),
        ),
      ),
    );

    await tester.pumpWidget(root);

    expect(find.text('M30'), findsOneWidget);
  });
}

final class _MemoryChartViewSessionStore implements ChartViewSessionStore {
  _MemoryChartViewSessionStore([ChartViewSessionState? value])
    : value = value ?? ChartViewSessionState.empty;

  ChartViewSessionState value;

  @override
  Future<ChartViewSessionState> read() async => value;

  @override
  Future<void> write(ChartViewSessionState value) async {
    await Future<void>.delayed(Duration.zero);
    this.value = value;
  }
}
