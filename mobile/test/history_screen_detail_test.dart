import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  Widget testApp() {
    return ProviderScope(
      overrides: videoReferenceOverrides,
      child: const MaterialApp(home: HistoryScreen()),
    );
  }

  Future<void> pumpBottomAnchor(WidgetTester tester) async {
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump();
    }
  }

  testWidgets('closed position without close price renders unavailable', (
    tester,
  ) async {
    const position = DemoHistoryPosition(
      id: 'production-position-without-close-price',
      title: 'XAUUSD+',
      side: 'SELL',
      volume: 0.25,
      openPrice: 4325.409,
      profit: -22.05,
      time: '2026.08.14 11:12:11',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoHistoryPositionsProvider.overrideWithValue(const [position]),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await pumpBottomAnchor(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('4325.409 → —'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'history-position-production-position-without-close-price',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('positions history initially anchors the video footer', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await pumpBottomAnchor(tester);

    final listFinder = find.byKey(
      const PageStorageKey('history-positions-list'),
    );
    final list = tester.widget<ListView>(listFinder);
    final controller = list.controller;
    expect(controller, isNotNull);
    expect(controller!.hasClients, isTrue);
    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(
      controller.position.pixels,
      closeTo(controller.position.maxScrollExtent, .01),
    );

    final listRect = tester.getRect(listFinder);
    final footerRect = tester.getRect(
      find.byKey(const ValueKey('history-summary-Số dư')),
    );
    expect(footerRect.top, greaterThan(listRect.top));
    expect(footerRect.bottom, lessThanOrEqualTo(listRect.bottom));
    expect(find.text('2 301.60'), findsOneWidget);
  });

  testWidgets(
    'positions history reanchors the new account footer after user scroll',
    (tester) async {
      tester.view.physicalSize = const Size(384, 848);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = createVideoReferenceContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await pumpBottomAnchor(tester);

      final listFinder = find.byKey(
        const PageStorageKey('history-positions-list'),
      );
      var controller = tester.widget<ListView>(listFinder).controller!;
      expect(
        controller.position.pixels,
        closeTo(controller.position.maxScrollExtent, .01),
      );

      await tester.drag(listFinder, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(
        controller.position.pixels,
        lessThan(controller.position.maxScrollExtent - 100),
      );

      container.read(activeDemoAccountIdProvider.notifier).select('10001002');
      await pumpBottomAnchor(tester);

      controller = tester.widget<ListView>(listFinder).controller!;
      expect(
        controller.position.pixels,
        closeTo(controller.position.maxScrollExtent, .01),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('history-report-profit-value')))
            .data,
        '15 297 859.10',
      );
      final listRect = tester.getRect(listFinder);
      final footerRect = tester.getRect(
        find.byKey(const ValueKey('history-summary-Số dư')),
      );
      expect(footerRect.top, greaterThan(listRect.top));
      expect(footerRect.bottom, lessThanOrEqualTo(listRect.bottom));
      expect(find.text('27 297 978.10'), findsOneWidget);
    },
  );

  testWidgets('positions history scrolls to the account-specific summary', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await pumpBottomAnchor(tester);

    final listFinder = find.byKey(
      const PageStorageKey('history-positions-list'),
    );
    tester.widget<ListView>(listFinder).controller!.jumpTo(0);
    await tester.pump();

    expect(
      find.byKey(const Key('history-position-small-history-0')),
      findsOneWidget,
    );
    await tester.dragUntilVisible(
      find.byKey(const Key('history-report-profit-value')),
      listFinder,
      const Offset(0, -500),
    );
    final profit = tester.widget<Text>(
      find.byKey(const Key('history-report-profit-value')),
    );
    expect(profit.data, '21 081.96');
    expect(
      tester
              .getTopLeft(
                find.byKey(const ValueKey('history-summary-Tien rut')),
              )
              .dy -
          tester
              .getTopLeft(
                find.byKey(const ValueKey('history-summary-Tien nap')),
              )
              .dy,
      closeTo(25.3333333333, .1),
    );
    expect(find.text('2 301.60'), findsOneWidget);
  });

  testWidgets('realized trade changes update history profit and balance', (
    tester,
  ) async {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await pumpBottomAnchor(tester);

    final position = container.read(demoPositionsProvider).first;
    expect(
      container
          .read(demoTradingProvider.notifier)
          .closePosition(position.id, realizedProfit: 12.50),
      isTrue,
    );
    await tester.pump();
    final list = tester.widget<ListView>(
      find.byKey(const PageStorageKey('history-positions-list')),
    );
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('history-report-profit-value')))
          .data,
      '21 094.46',
    );
    expect(find.text('2 314.10'), findsOneWidget);
  });

  testWidgets('a close appends a row and keeps the footer anchored', (
    tester,
  ) async {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await pumpBottomAnchor(tester);

    final listFinder = find.byKey(
      const PageStorageKey('history-positions-list'),
    );
    final controller = tester.widget<ListView>(listFinder).controller!;
    final position = container.read(demoPositionsProvider).first;

    expect(
      container
          .read(demoTradingProvider.notifier)
          .closePosition(position.id, realizedProfit: 12.50),
      isTrue,
    );
    await pumpBottomAnchor(tester);

    final closedEntry = container.read(demoHistoryPositionsProvider).last;
    expect(closedEntry.id, startsWith('closed-${position.id}-'));
    expect(
      controller.position.pixels,
      closeTo(controller.position.maxScrollExtent, .01),
    );
    expect(
      find.byKey(ValueKey('history-position-${closedEntry.id}')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('history-summary-Số dư')), findsOneWidget);
  });

  testWidgets('bulk close does not move history when user is reading above', (
    tester,
  ) async {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await pumpBottomAnchor(tester);

    final listFinder = find.byKey(
      const PageStorageKey('history-positions-list'),
    );
    final controller = tester.widget<ListView>(listFinder).controller!;
    controller.jumpTo(0);
    await tester.pump();
    final initialHistoryLength = container
        .read(demoHistoryPositionsProvider)
        .length;
    final positionIds = container
        .read(demoPositionsProvider)
        .map((position) => position.id)
        .toList(growable: false);

    expect(
      container.read(demoTradingProvider.notifier).closeAllPositions(),
      positionIds.length,
    );
    await pumpBottomAnchor(tester);

    expect(controller.position.pixels, closeTo(0, .01));
    expect(container.read(demoPositionsProvider), isEmpty);
    expect(
      container.read(demoHistoryPositionsProvider),
      hasLength(initialHistoryLength + positionIds.length),
    );
    final appended = container
        .read(demoHistoryPositionsProvider)
        .skip(
          container.read(demoHistoryPositionsProvider).length -
              positionIds.length,
        )
        .toList(growable: false);
    for (var index = 0; index < positionIds.length; index++) {
      expect(appended[index].id, startsWith('closed-${positionIds[index]}-'));
    }
  });

  testWidgets(
    'position history details use row data and chart returns to positions',
    (tester) async {
      await tester.pumpWidget(testApp());
      await pumpBottomAnchor(tester);

      final listFinder = find.byKey(
        const PageStorageKey('history-positions-list'),
      );
      tester.widget<ListView>(listFinder).controller!.jumpTo(0);
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('history-position-small-history-0')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-detail-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('history-position-detail-small-history-0')),
        findsOneWidget,
      );
      final detail = find.byKey(
        const Key('history-position-detail-small-history-0'),
      );
      final title = tester.widget<Text>(
        find.byKey(const Key('history-detail-title')),
      );
      expect(title.textSpan!.toPlainText(), 'XAUUSD+ sell 0.01');
      expect(
        find.descendant(of: detail, matching: find.text('4061.390 → 4063.440')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: detail, matching: find.text('-2.05')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: detail, matching: find.text('đã đóng')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('history-detail-chart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byKey(const Key('history-detail-sheet')), findsNothing);
      final chart = tester.widget<ChartScreen>(find.byType(ChartScreen));
      expect(chart.symbol, 'XAUUSD+');
      expect(chart.initialTimeframe, 'D1');

      Navigator.of(
        tester.element(find.byType(ChartScreen)),
        rootNavigator: true,
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final positionsTab = tester.widget<Semantics>(
        find.byKey(const Key('history-tab-0')),
      );
      expect(positionsTab.properties.selected, isTrue);
      expect(
        find.byKey(const Key('history-position-small-history-0')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'video two history header overlays a bouncing 90px physical row list',
    (tester) async {
      tester.view.physicalSize = const Size(384, 848);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(testApp());
      await pumpBottomAnchor(tester);

      final sort = tester.getRect(find.byKey(const Key('history-sort-button')));
      final segmentsFinder = find.byKey(const Key('history-segmented-control'));
      final segments = tester.getRect(segmentsFinder);
      final period = tester.getRect(
        find.byKey(const Key('history-period-button')),
      );
      expect(sort.left, closeTo(16, .01));
      expect(sort.top, closeTo(38, .01));
      expect(sort.width, closeTo(42.6666666667, .01));
      expect(sort.height, closeTo(42.6666666667, .01));
      expect(segments.left, closeTo(69, .01));
      expect(segments.top, closeTo(37.3333333333, .01));
      expect(segments.width, closeTo(247.6666666667, .01));
      expect(segments.height, closeTo(44, .01));
      expect(period.left, closeTo(328.3333333333, .01));
      expect(period.top, closeTo(38, .01));
      expect(period.width, closeTo(42.6666666667, .01));
      expect(period.height, closeTo(42.6666666667, .01));
      final selectedTab = tester.getRect(
        find.byKey(const Key('history-tab-0')),
      );
      expect(selectedTab.top, closeTo(39.2666666666, .01));
      expect(selectedTab.width, closeTo(75.3333333333, .01));
      expect(selectedTab.height, closeTo(39.4666666667, .01));
      expect(find.byKey(const Key('history-header-overlay')), findsOneWidget);

      final listFinder = find.byKey(
        const PageStorageKey('history-positions-list'),
      );
      final list = tester.widget<ListView>(listFinder);
      expect(list.physics, isA<BouncingScrollPhysics>());
      expect(
        (list.physics! as BouncingScrollPhysics).parent,
        isA<AlwaysScrollableScrollPhysics>(),
      );
      final scrollbar = tester.widget<Scrollbar>(
        find.byKey(const Key('history-positions-scrollbar')),
      );
      expect(scrollbar.thumbVisibility, isFalse);
      expect(scrollbar.interactive, isTrue);
      expect(scrollbar.thickness, 2);

      list.controller!.jumpTo(0);
      await tester.pump();

      final firstRow = find.byKey(
        const Key('history-position-small-history-0'),
      );
      final secondRow = find.byKey(
        const Key('history-position-small-history-1'),
      );
      final firstTop = tester.getTopLeft(firstRow).dy;
      expect(tester.getTopLeft(secondRow).dy - firstTop, closeTo(60, .1));
      final headerTop = segmentsFinder.evaluate().single.renderObject;

      await tester.drag(listFinder, const Offset(0, -100));
      await tester.pump();

      expect(tester.getTopLeft(firstRow).dy, lessThan(segments.bottom));
      expect(
        (headerTop as RenderBox).localToGlobal(Offset.zero).dy,
        closeTo(37.3333333333, .1),
      );
    },
  );

  testWidgets('orders and deals keep the video two 90px physical row pitch', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('history-deal-57016800101'))).dy -
          tester
              .getTopLeft(find.byKey(const Key('history-deal-57016800413')))
              .dy,
      closeTo(60, .1),
    );
    expect(find.byKey(const Key('history-deals-scrollbar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('history-order-57360797890'))).dy -
          tester
              .getTopLeft(find.byKey(const Key('history-order-57360798130')))
              .dy,
      closeTo(60, .1),
    );
    expect(find.byKey(const Key('history-orders-scrollbar')), findsOneWidget);
  });

  testWidgets(
    'deal detail opens the canonical sheet and chart returns to deals',
    (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pump();

      await tester.tap(find.byKey(const Key('history-tab-2')));
      await tester.pump();
      expect(find.byKey(const Key('history-deal-57016800413')), findsOneWidget);

      await tester.tap(find.byKey(const Key('history-deal-57016800413')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-detail-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('history-deal-detail-57016800413')),
        findsOneWidget,
      );
      expect(find.text('Gold US Dollar'), findsOneWidget);
      expect(find.text('#57016800413'), findsOneWidget);
      expect(find.text('57360798130'), findsOneWidget);
      expect(find.text('filled'), findsOneWidget);
      expect(find.text('0.25 at 4105.050'), findsWidgets);

      await tester.tap(find.byKey(const Key('history-detail-chart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byKey(const Key('history-detail-sheet')), findsNothing);
      final chart = tester.widget<ChartScreen>(find.byType(ChartScreen));
      expect(chart.symbol, 'XAUUSD+');
      expect(chart.initialTimeframe, 'D1');

      Navigator.of(
        tester.element(find.byType(ChartScreen)),
        rootNavigator: true,
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final dealsTab = tester.widget<Semantics>(
        find.byKey(const Key('history-tab-2')),
      );
      expect(dealsTab.properties.selected, isTrue);
      expect(find.byKey(const Key('history-deal-57016800413')), findsOneWidget);
    },
  );

  testWidgets('deal list starts directly below the video reference tabs', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    final dealsTab = find.byKey(const Key('history-tab-2'));
    await tester.tap(dealsTab);
    await tester.pump();

    final firstDeal = find.byKey(const Key('history-deal-57016800413'));
    final gap =
        tester.getTopLeft(firstDeal).dy - tester.getBottomLeft(dealsTab).dy;

    expect(gap, inInclusiveRange(0, 8.5));
  });

  testWidgets('deal detail sheet matches the recorded vertical placement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-deal-57016800413')));
    await tester.pumpAndSettle();

    final sheet = tester.getRect(find.byKey(const Key('history-detail-sheet')));
    expect(sheet.top, closeTo(611, 1));
    expect(sheet.bottom, closeTo(822, 1));
    expect(
      tester.getTopLeft(find.text('57360798130').first).dx,
      closeTo(89.3, 1),
    );
  });

  testWidgets('order rows open order details and preserve the orders tab', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-order-57360798130')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-detail-sheet')), findsOneWidget);
    expect(
      find.byKey(const Key('history-order-detail-57360798130')),
      findsOneWidget,
    );
    expect(find.text('0.25 / 0.25 at market'), findsWidgets);
    expect(find.text('S/L:'), findsOneWidget);
    expect(find.text('T/P:'), findsOneWidget);

    Navigator.of(
      tester.element(find.byKey(const Key('history-detail-sheet'))),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();

    final ordersTab = tester.widget<Semantics>(
      find.byKey(const Key('history-tab-1')),
    );
    expect(ordersTab.properties.selected, isTrue);
    expect(find.byKey(const Key('history-order-57360798130')), findsOneWidget);
  });
}
