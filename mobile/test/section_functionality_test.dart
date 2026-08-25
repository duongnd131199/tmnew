import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/profile/presentation/screens/section_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  testWidgets('symbol properties show contract information', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SectionScreen(title: 'Thuộc tính XAUUSD')),
      ),
    );

    expect(find.text('Gold US Dollar'), findsWidgets);
    expect(find.text('Kich thuoc hop dong'), findsOneWidget);
    final scrollbar = tester.widget<RawScrollbar>(find.byType(RawScrollbar));
    expect(scrollbar.thickness, closeTo(2.6666666667, .001));
    expect(scrollbar.mainAxisMargin, 12);
    expect(scrollbar.crossAxisMargin, closeTo(.6666666667, .001));

    await tester.scrollUntilVisible(
      find.text('Ngay hoac Huy Bo'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Ngay hoac Huy Bo'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Trang web'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Trang web'), findsOneWidget);
  });

  testWidgets('depth of market volume and price levels are interactive', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        demoQuoteProvider.overrideWith(
          (ref, symbol) => Stream.value(
            const DemoQuote(
              symbol: 'XAUUSD',
              name: 'Gold US Dollar',
              bid: 4104.09,
              ask: 4104.22,
              changePercent: .1,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SectionScreen(title: 'Depth of Market XAUUSD'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('0.01'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('0.02'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dom-level-0')));
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    final pending = container.read(demoPendingOrdersProvider);
    expect(pending, hasLength(1));
    expect(pending.single.type, 'Sell Limit');
    expect(pending.single.volume, .02);
    expect(pending.single.price, closeTo(4104.57, .001));

    await tester.tap(find.byKey(const Key('dom-volume-field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('dom-volume-input')), '1.25');
    await tester.tap(find.byKey(const Key('dom-volume-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('1.25'), findsOneWidget);
  });

  testWidgets('market statistics contain quote range fields', (tester) async {
    final container = ProviderContainer(
      overrides: [
        demoQuoteProvider.overrideWith(
          (ref, symbol) => Stream.value(
            const DemoQuote(
              symbol: 'XAUUSD',
              name: 'Gold US Dollar',
              bid: 4200.12,
              ask: 4200.34,
              changePercent: .2,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SectionScreen(title: 'Thống kê XAUUSD')),
      ),
    );
    await tester.pump();

    expect(find.text('Giá mua'), findsOneWidget);
    expect(find.text('4200.12'), findsOneWidget);
    expect(find.text('4200.34'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(6));
  });
}
