import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/trade/presentation/screens/position_detail_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
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
      expect(find.text('4102.396'), findsOneWidget);
      expect(find.text('4102.520'), findsOneWidget);

      await tester.tap(find.text('+').first);
      await tester.pump();
      expect(find.text('4102.397'), findsOneWidget);

      await tester.tap(find.text('Chỉnh sửa'));
      await tester.pump();
      final modified = container
          .read(demoPositionsProvider)
          .where((item) => item.id == position.id)
          .single;
      expect(modified.stopLoss, closeTo(4102.397, .000001));
    },
  );
}
