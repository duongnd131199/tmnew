import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  testWidgets(
    'Trade preserves the 393.33 reference proportions on a 402 point iPhone',
    (tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = createVideoReferenceContainer(
        overrides: [
          demoQuoteProvider.overrideWith(
            (ref, symbol) => const Stream<DemoQuote>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final positions = container.read(demoPositionsProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(402, 874),
                devicePixelRatio: 3,
                padding: EdgeInsets.only(top: 24),
                viewPadding: EdgeInsets.only(top: 24),
              ),
              child: TradeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FittedBox), findsWidgets);
      expect(
        tester.getSize(find.byType(FittedBox).first),
        const Size(402, 874),
      );

      final first = tester.getRect(
        find.byKey(ValueKey('trade-position-${positions[0].id}')),
      );
      final second = tester.getRect(
        find.byKey(ValueKey('trade-position-${positions[1].id}')),
      );
      final referenceScale = 402 / TabReferenceMetrics.viewportWidth;

      expect(
        second.top - first.top,
        closeTo(
          TabReferenceMetrics.tradePositionRowHeight * referenceScale,
          .01,
        ),
      );
    },
  );

  test('Trade locks the decoded-reference position pitch', () {
    expect(TabReferenceMetrics.tradePositionRowHeight, 53.1111111111);
  });
}
