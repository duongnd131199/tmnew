import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/profile/presentation/screens/section_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  testWidgets(
    'symbol properties use account source and mark unavailable contract data',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          demoAccountCatalogProvider.overrideWithValue(const [
            DemoAccountProfile(
              id: 'test-account',
              name: 'Test Account',
              company: 'Current Broker Ltd',
              server: 'Current-Live-01',
              accessPoint: '',
              balance: 0,
              brand: DemoBrokerBrand.unknown,
              historyDeposit: 0,
              historyWithdrawal: 0,
              historyProfit: 0,
              historySwap: 0,
              historyCommission: 0,
              historyBalance: 0,
            ),
          ]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SectionScreen(title: 'Thuộc tính XAUUSD'),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('symbol-property-swap-long-value')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('symbol-property-swap-long-value')),
            )
            .data,
        '—',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('symbol-property-swap-short-value')),
            )
            .data,
        '—',
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('symbol-property-blocked-margin-value')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('symbol-property-blocked-margin-value')),
            )
            .data,
        '—',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('symbol-property-margin-rate-value')),
            )
            .data,
        '—',
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('symbol-property-price-source-value')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('symbol-property-price-source-value')),
            )
            .data,
        'Current Broker Ltd',
      );
    },
  );

  testWidgets('market statistics leave unavailable session fields neutral', (
    tester,
  ) async {
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

    expect(find.text('4200.12'), findsOneWidget);
    expect(find.text('4200.34'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(6));
  });
}
