import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  void useLdPlayerViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(590, 1280);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<ProviderContainer> pumpProductionApp(WidgetTester tester) async {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    addTearDown(() => appRouter.go('/market'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: appRouter,
        ),
      ),
    );
    appRouter.go('/trade');
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Trade add opens the full-width reference order ticket', (
    tester,
  ) async {
    useLdPlayerViewport(tester);
    await pumpProductionApp(tester);

    await tester.tap(find.byKey(const Key('trade-add-button')));
    await tester.pumpAndSettle();

    final ticket = find.byKey(const Key('trade-add-order-ticket'));
    expect(ticket, findsOneWidget);
    final ticketRect = tester.getRect(ticket);
    expect(ticketRect.left, 0);
    expect(ticketRect.width, closeTo(590 / 1.5, .01));
    expect(find.byType(MtBottomNavigationBar), findsNothing);

    expect(find.text('1.00'), findsOneWidget);
    expect(find.text('-5'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);

    final typeRow = find.byKey(const Key('order-type-field'));
    final quoteStrip = find.byKey(const Key('order-quote-strip'));
    expect(tester.getRect(typeRow).left, 0);
    expect(tester.getRect(typeRow).width, closeTo(590 / 1.5, .01));
    expect(tester.getRect(quoteStrip).left, 0);
    expect(tester.getRect(quoteStrip).width, closeTo(590 / 1.5, .01));

    final backRect = tester.getRect(find.byKey(const Key('order-back-button')));
    expect(backRect.left, closeTo(17.3333333333, .75));
    expect(backRect.width, 40);

    final titleRect = tester.getRect(
      find.byKey(const Key('order-header-title')),
    );
    expect(titleRect.center.dx, closeTo((590 / 1.5) / 2, .75));

    final stopLossDecrease = tester.getRect(
      find.byKey(const Key('order-sl-decrease')),
    );
    final stopLossIncrease = tester.getRect(
      find.byKey(const Key('order-sl-increase')),
    );
    expect(stopLossDecrease.center.dx, closeTo(288.5 / 1.5, .75));
    expect(stopLossIncrease.center.dx, closeTo(564.5 / 1.5, .75));

    final prices = tester
        .widgetList<Text>(
          find.descendant(of: quoteStrip, matching: find.byType(Text)),
        )
        .toList(growable: false);
    expect(prices, hasLength(2));
    expect(
      prices.map((price) => price.style?.color),
      everyElement(const Color(0xFF007FFF)),
    );

    final sell = tester.widget<Material>(
      find.byKey(const Key('order-market-sell')),
    );
    final buy = tester.widget<Material>(
      find.byKey(const Key('order-market-buy')),
    );
    expect(sell.color, const Color(0xFFDD5E4F));
    expect(buy.color, const Color(0xFF4A92F4));

    final typeText = tester.widget<Text>(find.text('Vào lệnh thị trường'));
    expect(typeText.style?.fontFamily, 'sans-serif');
    expect(
      find.text(
        'Chú ý !!! Giao dịch được thực thi ở các điều kiện thị trường, '
        'có thể có sự khác biệt về giá so với giá yêu cầu.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('non-Trade order entry retains the compatibility shell', (
    tester,
  ) async {
    useLdPlayerViewport(tester);
    await pumpProductionApp(tester);

    appRouter.go('/order?symbol=XAUUSD%2B');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trade-add-order-ticket')), findsNothing);
    expect(find.byType(MtBottomNavigationBar), findsOneWidget);
  });
}
