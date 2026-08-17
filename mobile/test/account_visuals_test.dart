import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/profile/domain/account_presentation_profile.dart';
import 'package:trading_mobile/features/profile/presentation/widgets/account_visuals.dart';

void main() {
  testWidgets('account visuals keep the reference sizes and hit targets', (
    tester,
  ) async {
    var backTaps = 0;
    var addTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const AccountBrokerMark(brand: DemoBrokerBrand.exness),
              AccountRoundBackButton(onTap: () => backTaps++),
              AccountRoundAddButton(onTap: () => addTaps++),
              const AccountChevronRight(),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('account-broker-mark'))),
      const Size.square(31),
    );
    expect(find.text('exness'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('account-round-back-button'))),
      const Size.square(43),
    );
    expect(
      tester.getSize(find.byKey(const Key('account-round-add-button'))),
      const Size.square(43),
    );
    expect(
      tester.getSize(find.byKey(const Key('account-chevron-glyph'))),
      const Size(10, 14),
    );

    await tester.tap(find.byKey(const Key('account-round-back-button')));
    await tester.tap(find.byKey(const Key('account-round-add-button')));

    expect(backTaps, 1);
    expect(addTaps, 1);
  });

  testWidgets('unknown broker does not render an Exness wordmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AccountBrokerMark(brand: DemoBrokerBrand.unknown)),
      ),
    );

    expect(find.text('exness'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('account-broker-mark'))),
      const Size.square(31),
    );
  });

  testWidgets('technical YODO broker uses a neutral yellow mark without text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AccountBrokerMark(brand: DemoBrokerBrand.yodo)),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('account-broker-mark'))),
      const Size.square(31),
    );
    expect(find.text('yodo'), findsNothing);
    expect(find.text('exness'), findsNothing);
    final mark = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const Key('account-broker-mark')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(mark.color, const Color(0xFFFFE500));
  });

  testWidgets('hero broker marks scale every brand to 60 pixels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AccountBrokerMark(
                key: Key('hero-vantage-mark'),
                brand: DemoBrokerBrand.vantage,
                size: 60,
              ),
              AccountBrokerMark(
                key: Key('hero-unknown-mark'),
                brand: DemoBrokerBrand.unknown,
                size: 60,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('hero-vantage-mark'))),
      const Size.square(60),
    );
    expect(
      tester.getSize(find.byKey(const Key('hero-unknown-mark'))),
      const Size.square(60),
    );
    final unknownIcon = tester.widget<Icon>(find.byType(Icon));
    expect(unknownIcon.size, 34.8);
  });
}
