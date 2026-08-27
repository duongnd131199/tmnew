import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

DemoTradingState _scrollableTradeSeed(String accountId) => DemoTradingState(
  balance: 100000,
  positions: List<DemoPosition>.generate(
    30,
    (index) => DemoPosition(
      id: 'responsive-position-$index',
      symbol: 'XAUUSD',
      side: index.isEven ? 'BUY' : 'SELL',
      volume: .01,
      openPrice: 4600 + index.toDouble(),
      currentPrice: 4601 + index.toDouble(),
      profit: index.isEven ? 1 : -1,
    ),
  ),
  deals: const [],
);

ScrollbarPainter _tradeScrollbarPainter(WidgetTester tester) {
  final scrollbar = find.byKey(const Key('trade-position-scrollbar'));
  final painters = tester
      .widgetList<CustomPaint>(
        find.descendant(of: scrollbar, matching: find.byType(CustomPaint)),
      )
      .expand((paint) => [paint.painter, paint.foregroundPainter])
      .whereType<ScrollbarPainter>();
  return painters.single;
}

void main() {
  testWidgets('Trade scrollbar thumb can move on a short supported viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 900);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        demoTradingSeedProvider.overrideWithValue(_scrollableTradeSeed),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(393.3333333333, 600),
              devicePixelRatio: 1.5,
              padding: EdgeInsets.only(top: 24),
              viewPadding: EdgeInsets.only(top: 24),
            ),
            child: TradeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final list = tester.widget<ListView>(find.byType(ListView));
    final controller = list.controller!;
    expect(controller.position.maxScrollExtent, greaterThan(0));

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(
      _tradeScrollbarPainter(tester).getThumbScrollOffset(),
      greaterThan(0),
    );
  });
}
