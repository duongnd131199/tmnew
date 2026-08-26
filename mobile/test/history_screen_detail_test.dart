import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_wallet_history_mapper.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/mt_price_range_text.dart';

import 'test_support/load_test_fonts.dart';
import 'test_support/video_reference_fixtures.dart';

void main() {
  setUpAll(loadMt5TestFonts);

  Widget testApp() {
    return ProviderScope(
      overrides: videoReferenceOverrides,
      child: const MaterialApp(
        home: RepaintBoundary(
          key: Key('history-icon-reference-capture'),
          child: HistoryScreen(),
        ),
      ),
    );
  }

  Future<void> pumpBottomAnchor(WidgetTester tester) async {
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump();
    }
  }

  testWidgets('reference typography is shared across history modes', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());

    expect(find.text('Cac giao d...'), findsOneWidget);
    await pumpBottomAnchor(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-segment-label-0')))
          .data,
      'Lenh co tr...',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-segment-label-0')))
          .style,
      AppTypography.historySegment,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-segment-label-2')))
          .style,
      AppTypography.historyDealsSegment,
    );
    final summary = tester.widget<Text>(
      find.byKey(const ValueKey('history-summary-label-Tien nap')),
    );
    expect(summary.style, AppTypography.historySummary);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('history-summary-value-Tien nap')),
          )
          .style,
      AppTypography.historySummaryValue,
    );

    final positionsList = tester.widget<ListView>(
      find.byKey(const PageStorageKey('history-positions-list')),
    );
    positionsList.controller!.jumpTo(0);
    await tester.pump();

    void expectRowTypography(String tab) {
      final primaryFinder = find.byKey(ValueKey('history-$tab-primary-0'));
      final secondaryFinder = find.byKey(ValueKey('history-$tab-secondary-0'));
      expect(
        tester.widget<Text>(primaryFinder).style,
        AppTypography.historyPrimary,
        reason: tab,
      );
      expect(
        tester.widget<Text>(secondaryFinder).style,
        tab == 'positions'
            ? AppTypography.historyPriceRange
            : AppTypography.historySecondary,
        reason: tab,
      );
      expect(
        tester.getTopLeft(secondaryFinder).dy,
        closeTo(
          tester.getTopLeft(primaryFinder).dy +
              (tab == 'positions'
                  ? TabReferenceMetrics.historyPriceRangeTop
                  : tab == 'deals'
                  ? TabReferenceMetrics.historyDealSecondaryTop
                  : TabReferenceMetrics.historySecondaryTop) -
              TabReferenceMetrics.historyPrimaryTop,
          .1,
        ),
        reason: tab,
      );
    }

    expectRowTypography('positions');
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('history-positions-action-0')),
          )
          .style
          ?.letterSpacing,
      AppTypography.historyAction.letterSpacing,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('history-positions-trailing-primary-0')),
          )
          .style
          ?.letterSpacing,
      -.2,
    );
    expect(AppTypography.historySecondary.letterSpacing, closeTo(.1, .01));
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('history-positions-trailing-secondary-0'),
            ),
          )
          .style,
      AppTypography.historyTrailingSecondary,
    );
    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();
    expectRowTypography('orders');
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('history-orders-trailing-primary-0')),
          )
          .style
          ?.color,
      AppColors.historyOrderStatus,
    );
    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();
    expectRowTypography('deals');
  });

  testWidgets('history rows use the compact precision from the references', (
    tester,
  ) async {
    const position = DemoHistoryPosition(
      id: 'reference-format-position',
      title: 'XAUUSD+',
      side: 'BUY',
      volume: 1,
      openPrice: 4622.83,
      closePrice: 4631.37,
      profit: 854,
      time: '2026.08.24 10:45:11',
    );
    const fractionalPosition = DemoHistoryPosition(
      id: 'production-format-position',
      title: 'EURUSD',
      side: 'SELL',
      volume: 1.5,
      openPrice: 1.23456,
      closePrice: 1.23457,
      profit: 1,
      time: '2026.08.24 10:46:11',
    );
    const order = DemoOrder(
      id: 'reference-format-order',
      symbol: 'XAUUSD+',
      side: 'BUY',
      type: 'Market',
      volume: 1,
      requestedPrice: 4637.05,
      executedPrice: 4637.05,
      status: 'filled',
      time: '2026.08.24 11:58:13',
    );
    const fractionalOrder = DemoOrder(
      id: 'production-format-order',
      symbol: 'EURUSD',
      side: 'SELL',
      type: 'Sell Limit',
      volume: 1.5,
      requestedPrice: 1.23456,
      executedPrice: 1.23456,
      status: 'filled',
      time: '2026.08.24 11:59:13',
    );
    const deal = DemoDeal(
      id: 'reference-format-deal',
      orderId: 'reference-format-order',
      symbol: 'XAUUSD+',
      side: 'BUY',
      volume: 1,
      price: 4637.05,
      profit: 0,
      time: '2026.08.24 11:58:13',
    );
    const fractionalDeal = DemoDeal(
      id: 'production-format-deal',
      orderId: 'production-format-order',
      symbol: 'EURUSD',
      side: 'SELL',
      volume: 1.5,
      price: 1.23456,
      profit: 1,
      time: '2026.08.24 11:59:13',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoHistoryPositionsProvider.overrideWithValue(const [
            position,
            fractionalPosition,
          ]),
          demoOrdersProvider.overrideWithValue(const [order, fractionalOrder]),
          demoDealsProvider.overrideWithValue(const [deal, fractionalDeal]),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await pumpBottomAnchor(tester);

    expect(_priceRange('4622.83', '4631.37'), findsOneWidget);
    expect(_priceRange('1.23456', '1.23457'), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();
    expect(find.text('1 / 1 at market'), findsOneWidget);
    expect(find.text('1.5 / 1.5 at 1.23456'), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();
    expect(find.text('1 at 4637.05'), findsOneWidget);
    expect(find.text('1.5 at 1.23456'), findsOneWidget);
  });

  testWidgets('History toolbar icon ink matches the measured references', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp());
    await pumpBottomAnchor(tester);

    final sort = await _historyButtonInkMetrics(
      tester,
      const Key('history-sort-button'),
    );
    final clock = await _historyButtonInkMetrics(
      tester,
      const Key('history-period-button'),
    );

    expect(sort.bounds, const Rect.fromLTWH(14, 14, 16, 14));
    expect(sort.pixels, inInclusiveRange(70, 95));
    expect(clock.bounds, const Rect.fromLTWH(12, 12, 19, 19));
    expect(clock.pixels, inInclusiveRange(95, 125));
  });

  testWidgets('History header fade stays white through its transparent edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp());
    await pumpBottomAnchor(tester);

    final minimumChannel = await _historyHeaderEdgeMinimumChannel(tester);

    expect(minimumChannel, greaterThanOrEqualTo(245));
  });

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
    expect(_priceRange('4325.41', '—'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'history-position-production-position-without-close-price',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'wallet history Balance rows match the deposit and withdrawal reference',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final entries = ExV2WalletHistoryMapper.entries(
        historyTransactions: const [],
        deposits: const [
          {
            'id': 'deposit-1',
            'amount': 518.54,
            'status': 'pending',
            'reference': 'D-ALLINT-USD-INT-924750483461',
            'createdAt': '2026-07-21T02:28:53',
          },
        ],
        withdrawals: const [
          {
            'id': 'withdrawal-1',
            'amount': 2000,
            'status': 'rejected',
            'reference': 'W-BANKVNGT-USD-1475391737862',
            'createdAt': '2026-07-21T06:49:19',
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...videoReferenceOverrides,
            demoHistoryPositionsProvider.overrideWithValue(entries),
          ],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await pumpBottomAnchor(tester);

      final depositRow = find.byKey(
        const ValueKey('history-position-wallet-deposit-1'),
      );
      final withdrawalRow = find.byKey(
        const ValueKey('history-position-wallet-withdrawal-1'),
      );
      expect(find.text('Balance'), findsNWidgets(2));
      expect(find.text('D-ALLINT-USD-INT-924750483461'), findsOneWidget);
      expect(find.text('2026.07.21 02:28:53'), findsOneWidget);
      expect(find.text('W-BANKVNGT-USD-1475391737862'), findsOneWidget);
      expect(find.text('2026.07.21 06:49:19'), findsOneWidget);
      expect(tester.getSize(depositRow).height, 52);
      expect(
        tester.getTopLeft(withdrawalRow).dy - tester.getTopLeft(depositRow).dy,
        52,
      );
      expect(
        tester.widget<Text>(find.text('518.54')).style?.color,
        AppColors.primary,
      );
      expect(
        tester.widget<Text>(find.text('-2 000.00')).style?.color,
        AppColors.negative,
      );
    },
  );

  testWidgets('position history typography matches the compact reference', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await pumpBottomAnchor(tester);

    final summaryLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('history-summary-Tien nap')),
        matching: find.text('Tien nap'),
      ),
    );
    expect(summaryLabel.style?.fontSize, 14.5);
    expect(summaryLabel.style?.fontWeight, FontWeight.w400);

    final listFinder = find.byKey(
      const PageStorageKey('history-positions-list'),
    );
    tester.widget<ListView>(listFinder).controller!.jumpTo(0);
    await tester.pump();

    final row = find.byKey(const Key('history-position-small-history-0'));
    final texts = tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .toList();
    String labelOf(Text text) =>
        text.data ?? text.textSpan?.toPlainText() ?? '';
    final title = tester.widget<Text>(
      find.byKey(const ValueKey('history-positions-primary-0')),
    );
    final profit = texts.firstWhere((text) => labelOf(text) == '-2.05');
    final price = texts.firstWhere((text) => labelOf(text).contains('4061.39'));
    final time = texts.firstWhere((text) => labelOf(text).startsWith('2026.'));

    expect(title.style?.fontSize, 16);
    expect(profit.style?.fontSize, 16);
    expect(price.style?.fontSize, 14);
    expect(time.style?.fontSize, 14);
    expect(
      tester.getTopLeft(find.byWidget(price)).dy -
          tester.getTopLeft(find.byWidget(title)).dy,
      closeTo(
        TabReferenceMetrics.historyPriceRangeTop -
            TabReferenceMetrics.historyPrimaryTop,
        .1,
      ),
    );
  });

  testWidgets('order and deal rows use the compact reference typography', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();
    final order = find.byKey(const Key('history-order-57360798130'));
    final orderTexts = tester
        .widgetList<Text>(
          find.descendant(of: order, matching: find.byType(Text)),
        )
        .toList();
    expect(orderTexts.first.style?.fontSize, 16);
    expect(orderTexts.last.style?.fontSize, 14);

    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();
    final deal = find.byKey(const Key('history-deal-57016800413'));
    final dealTexts = tester
        .widgetList<Text>(
          find.descendant(of: deal, matching: find.byType(Text)),
        )
        .toList();
    expect(dealTexts.first.style?.fontSize, 16);
    expect(dealTexts.last.style?.fontSize, 14);
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
      closeTo(21.3333333333, .1),
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
      expect(title.textSpan!.toPlainText(), 'XAUUSD sell 0.01');
      expect(
        find.descendant(
          of: detail,
          matching: _priceRange('4061.39', '4063.44'),
        ),
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
    'reference history header overlays a bouncing 78px physical row list',
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
      expect(sort.top, closeTo(30, .01));
      expect(sort.width, closeTo(42.6666666667, .01));
      expect(sort.height, closeTo(42.6666666667, .01));
      expect(segments.left, closeTo(70.5, .01));
      expect(segments.top, closeTo(30, .01));
      expect(segments.width, closeTo(247.6666666667, .01));
      expect(segments.height, closeTo(44, .01));
      expect(period.left, closeTo(328.3333333333, .01));
      expect(period.top, closeTo(30, .01));
      expect(period.width, closeTo(42.6666666667, .01));
      expect(period.height, closeTo(42.6666666667, .01));
      final selectedTab = tester.getRect(
        find.byKey(const Key('history-tab-0')),
      );
      final firstLabel = tester.getRect(
        find.byKey(const ValueKey('history-segment-label-0')),
      );
      expect(selectedTab.top, closeTo(31.9333333333, .01));
      expect(selectedTab.width, closeTo(80, .01));
      expect(selectedTab.height, closeTo(39.4666666667, .01));
      expect(
        firstLabel.center.dx,
        closeTo(111.7666666667, .01),
        reason: 'The first label is optically left-aligned in the reference.',
      );
      expect(find.byKey(const Key('history-header-overlay')), findsOneWidget);

      final listFinder = find.byKey(
        const PageStorageKey('history-positions-list'),
      );
      final list = tester.widget<ListView>(listFinder);
      expect((list.padding! as EdgeInsets).right, 5.3333333333);
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
      expect(tester.getTopLeft(secondRow).dy - firstTop, closeTo(52, .1));
      final headerTop = segmentsFinder.evaluate().single.renderObject;

      await tester.drag(listFinder, const Offset(0, -100));
      await tester.pump();

      expect(tester.getTopLeft(firstRow).dy, lessThan(segments.bottom));
      expect(
        (headerTop as RenderBox).localToGlobal(Offset.zero).dy,
        closeTo(30, .1),
      );
    },
  );

  testWidgets('orders and deals keep the reference 78px physical row pitch', (
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
      closeTo(52, .1),
    );
    expect(find.byKey(const Key('history-deals-scrollbar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('history-order-57360797890'))).dy -
          tester
              .getTopLeft(find.byKey(const Key('history-order-57360798130')))
              .dy,
      closeTo(52, .1),
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
      expect(find.text('0.25 at 4105.05'), findsWidgets);

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

    expect(gap, inInclusiveRange(0, 13));
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

Finder _priceRange(String openPrice, String closePrice) =>
    find.byWidgetPredicate(
      (widget) =>
          widget is MtPriceRangeText &&
          widget.openPrice == openPrice &&
          widget.closePrice == closePrice,
    );

Future<({Rect bounds, int pixels})> _historyButtonInkMetrics(
  WidgetTester tester,
  Key buttonKey,
) async {
  final buttonRect = tester.getRect(find.byKey(buttonKey));
  final iconKey = buttonKey == const Key('history-sort-button')
      ? const Key('history-sort-icon')
      : const Key('history-period-icon');
  final iconSearchRect = tester.getRect(find.byKey(iconKey)).inflate(1);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('history-icon-reference-capture')),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
    final result = (width: image.width, height: image.height, bytes: bytes);
    image.dispose();
    return result;
  });
  if (captured == null || captured.bytes == null) {
    throw StateError('Unable to read History toolbar pixels');
  }

  var minX = captured.width;
  var minY = captured.height;
  var maxX = -1;
  var maxY = -1;
  var pixels = 0;
  for (
    var y = iconSearchRect.top.floor();
    y < iconSearchRect.bottom.ceil();
    y++
  ) {
    for (
      var x = iconSearchRect.left.floor();
      x < iconSearchRect.right.ceil();
      x++
    ) {
      final offset = (y * captured.width + x) * 4;
      final red = captured.bytes!.getUint8(offset);
      final green = captured.bytes!.getUint8(offset + 1);
      final blue = captured.bytes!.getUint8(offset + 2);
      final alpha = captured.bytes!.getUint8(offset + 3);
      if (alpha < 128 || (red + green + blue) / 3 >= 100) continue;
      pixels++;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  if (maxX < minX || maxY < minY) {
    throw StateError('No dark icon ink found for $buttonKey');
  }
  final origin = Offset(
    buttonRect.left.floorToDouble(),
    buttonRect.top.floorToDouble(),
  );
  return (
    bounds: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    ).shift(-origin),
    pixels: pixels,
  );
}

Future<int> _historyHeaderEdgeMinimumChannel(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('history-icon-reference-capture')),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
    final result = (width: image.width, height: image.height, bytes: bytes);
    image.dispose();
    return result;
  });
  if (captured == null || captured.bytes == null) {
    throw StateError('Unable to read History header pixels');
  }

  var minimumChannel = 255;
  for (final x in [1, captured.width - 2]) {
    for (var y = 60; y < 82; y++) {
      final offset = (y * captured.width + x) * 4;
      minimumChannel = math.min(
        minimumChannel,
        captured.bytes!.getUint8(offset),
      );
      minimumChannel = math.min(
        minimumChannel,
        captured.bytes!.getUint8(offset + 1),
      );
      minimumChannel = math.min(
        minimumChannel,
        captured.bytes!.getUint8(offset + 2),
      );
    }
  }
  return minimumChannel;
}
