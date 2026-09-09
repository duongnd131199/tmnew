import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/trade/presentation/screens/position_detail_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/order_ticket_quote_text.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  testWidgets('BTC position detail uses the approved display copy', (
    tester,
  ) async {
    const position = DemoPosition(
      id: '2891570754',
      symbol: 'BTCUSD',
      side: 'BUY',
      volume: .01,
      openPrice: 79718.86,
      currentPrice: 79725.86,
      profit: 7,
    );
    final container = createVideoReferenceContainer(
      overrides: [
        demoPositionsProvider.overrideWithValue(const [position]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PositionDetailScreen(positionId: '2891570754'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('BTCUSDT'), findsOneWidget);
    expect(find.text('Bitcoin vs US Dollar Tether'), findsOneWidget);
    expect(find.text('#2891570754 buy 0.01 BTCUSDT'), findsOneWidget);

    final warning = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('position-detail-lower-surface')),
        matching: find.byType(Text),
      ),
    );
    expect(
      warning.data,
      'Chot Loi/ Cat Lo phai duoc dat it nhat 0 điểm so voi gia thi\n'
      'truong. Qua trinh Chot Loi/ Cat Lo se duoc thuc hien boi\n'
      'broker.',
    );
    expect(warning.maxLines, 3);
    expect(warning.softWrap, isFalse);
  });

  testWidgets('server GUID is hidden behind a short numeric position ticket', (
    tester,
  ) async {
    const position = DemoPosition(
      id: '894faaa5-5d41-49bd-8a52-5daf0281d948',
      symbol: 'XAUUSD',
      side: 'BUY',
      volume: .25,
      openPrice: 4102.125,
      currentPrice: 4102.396,
      profit: 6.78,
    );
    final container = createVideoReferenceContainer(
      overrides: [
        demoPositionsProvider.overrideWithValue(const [position]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PositionDetailScreen(positionId: position.id)),
      ),
    );
    await tester.pump();

    expect(find.textContaining('#11615687251 buy 0.25 XAUUSD'), findsOneWidget);
    expect(find.textContaining(position.id), findsNothing);
  });

  testWidgets(
    'Exness position detail uses live bid ask and three price digits',
    (tester) async {
      final container = createVideoReferenceContainer(
        overrides: [
          demoQuoteProvider.overrideWith(
            (ref, symbol) => Stream.value(
              const DemoQuote(
                symbol: 'XAUUSD',
                name: 'Gold US Dollar',
                bid: 4102.396,
                ask: 4102.520,
                changePercent: -.1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeDemoAccountIdProvider.notifier).select('10001002');
      final position = container.read(demoPositionsProvider).first;
      final router = GoRouter(
        initialLocation: '/trade',
        routes: [
          GoRoute(
            path: '/trade',
            builder: (context, state) =>
                const Scaffold(body: Text('Trade destination')),
          ),
          GoRoute(
            path: '/position',
            builder: (context, state) =>
                PositionDetailScreen(positionId: position.id),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.push('/position');
      await tester.pumpAndSettle();

      expect(find.text('Gold vs US Dollar'), findsOneWidget);
      expect(find.textContaining('buy 179 XAUUSD'), findsOneWidget);
      expect(
        tester
            .widgetList<OrderTicketQuoteText>(find.byType(OrderTicketQuoteText))
            .map((quote) => quote.formattedPrice),
        ['4102.396', '4102.520'],
      );

      await tester.tap(find.text('+').first);
      await tester.pump();
      expect(find.text('4102.397'), findsOneWidget);

      await tester.tap(find.text('Chinh sua'));
      await tester.pump();
      final modified = container
          .read(demoPositionsProvider)
          .where((item) => item.id == position.id)
          .single;
      expect(modified.stopLoss, closeTo(4102.397, .000001));
    },
  );

  testWidgets('suffixed gold position keeps all three quote digits', (
    tester,
  ) async {
    const position = DemoPosition(
      id: 'gold-suffixed-position',
      symbol: 'XAUUSD+',
      side: 'SELL',
      volume: .01,
      openPrice: 4373.328,
      currentPrice: 4377.441,
      profit: -4.11,
    );
    final container = createVideoReferenceContainer(
      overrides: [
        demoPositionsProvider.overrideWithValue(const [position]),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => Stream.value(
            const DemoQuote(
              symbol: 'XAUUSD+',
              name: 'Gold US Dollar',
              bid: 4374.728,
              ask: 4374.910,
              changePercent: -.1,
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
          home: PositionDetailScreen(positionId: 'gold-suffixed-position'),
        ),
      ),
    );
    await tester.pump();

    final quotes = tester.widgetList<OrderTicketQuoteText>(
      find.byType(OrderTicketQuoteText),
    );
    expect(quotes.map((quote) => quote.formattedPrice), [
      '4374.728',
      '4374.910',
    ]);
    expect(quotes.map((quote) => quote.usePipette), everyElement(isTrue));
  });
}
