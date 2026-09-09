import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/shared/widgets/order_ticket_quote_text.dart';

void main() {
  testWidgets(
    'three-digit quote adds a pipette without changing existing digit styles',
    (tester) async {
      const quoteColor = Color(0xFF1588E8);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrderTicketQuoteText(
              formattedPrice: '4375.463',
              color: quoteColor,
              usePipette: true,
            ),
          ),
        ),
      );

      final richPrice = tester
          .widgetList<Text>(find.byType(Text))
          .singleWhere((widget) => widget.textSpan != null);
      final parts = (richPrice.textSpan! as TextSpan).children!;
      expect(parts, hasLength(3));

      final leading = parts[0] as TextSpan;
      final emphasized = parts[1] as TextSpan;
      expect(leading.text, '4375.');
      expect(leading.style?.color, quoteColor);
      expect(leading.style?.fontSize, 20.5);
      expect(leading.style?.fontWeight, FontWeight.w600);
      expect(emphasized.text, '46');
      expect(emphasized.style?.color, quoteColor);
      expect(emphasized.style?.fontSize, 26.5);
      expect(emphasized.style?.fontWeight, FontWeight.w700);

      expect(parts[2], isA<WidgetSpan>());
      final pipetteSpan = parts[2] as WidgetSpan;
      final pipetteTransform = pipetteSpan.child as Transform;
      expect(pipetteTransform.transform.getTranslation().y, -8);
      final pipette = tester.widget<Text>(find.text('3'));
      expect(pipette.style?.color, quoteColor);
      expect(pipette.style?.fontSize, 14.5);
      expect(pipette.style?.fontWeight, FontWeight.w700);
    },
  );

  testWidgets('two-digit quote keeps the original two-span rendering', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrderTicketQuoteText(
            formattedPrice: '4375.46',
            color: Color(0xFF1588E8),
          ),
        ),
      ),
    );

    final richPrice = tester
        .widgetList<Text>(find.byType(Text))
        .singleWhere((widget) => widget.textSpan != null);
    final parts = (richPrice.textSpan! as TextSpan).children!;
    expect(parts, hasLength(2));
    expect(parts.whereType<WidgetSpan>(), isEmpty);
    expect((parts[0] as TextSpan).text, '4375.');
    expect((parts[1] as TextSpan).text, '46');
  });
}
