import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/reference_typography_profile.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_wallet_history_mapper.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_detail_screen.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/mt_price_range_text.dart';

import 'test_support/load_test_fonts.dart';
import 'test_support/video_reference_fixtures.dart';

TextStyle _resolvedHistoryRole(
  WidgetTester tester,
  Finder finder, {
  required ReferenceTextRole role,
  required ReferenceTextColorRole colorRole,
  required TypographyVariantId variant,
}) => AppTypography.forRole(
  tester.element(finder),
  role,
  colorRole: colorRole,
  variant: variant,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMt5TestFonts);

  Widget testApp({TargetPlatform platform = TargetPlatform.android}) {
    return ProviderScope(
      overrides: videoReferenceOverrides,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: const RepaintBoundary(
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

  testWidgets('history deal and linked order hide server GUIDs', (
    tester,
  ) async {
    const deal = DemoDeal(
      id: '894faaa5-5d41-49bd-8a52-5daf0281d948',
      orderId: '5ff94719-e61a-4c05-bbab-bb6f81c15369',
      symbol: 'XAUUSD',
      side: 'BUY',
      volume: .25,
      profit: 6.78,
      time: '2026.09.01 10:00:00',
      price: 4102.125,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...videoReferenceOverrides,
          demoDealsProvider.overrideWithValue(const [deal]),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('history-deal-${deal.id}')));
    await tester.pumpAndSettle();

    expect(find.text('#11615687251'), findsOneWidget);
    expect(find.text('71383708458'), findsOneWidget);
    expect(find.textContaining(deal.id), findsNothing);
    expect(find.textContaining(deal.orderId), findsNothing);
  });

  testWidgets('history order and position hide server GUIDs', (tester) async {
    const order = DemoOrder(
      id: '5ff94719-e61a-4c05-bbab-bb6f81c15369',
      symbol: 'XAUUSD',
      side: 'BUY',
      type: 'market',
      volume: .25,
      requestedPrice: 4102.125,
      status: 'filled',
      time: '2026.09.01 10:00:00',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...videoReferenceOverrides,
          demoOrdersProvider.overrideWithValue(const [order]),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('history-order-${order.id}')));
    await tester.pumpAndSettle();

    expect(find.text('#71383708458'), findsOneWidget);
    expect(find.textContaining(order.id), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...videoReferenceOverrides,
          demoHistoryPositionsProvider.overrideWithValue(const [
            DemoHistoryPosition(
              id: '894faaa5-5d41-49bd-8a52-5daf0281d948',
              title: 'XAUUSD',
              side: 'BUY',
              volume: .25,
              openPrice: 4102.125,
              closePrice: 4102.396,
              profit: 6.78,
              time: '2026.09.01 10:00:00',
            ),
          ]),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await pumpBottomAnchor(tester);
    await tester.tap(
      find.byKey(
        const ValueKey('history-position-894faaa5-5d41-49bd-8a52-5daf0281d948'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#11615687251'), findsOneWidget);
    expect(
      find.textContaining('894faaa5-5d41-49bd-8a52-5daf0281d948'),
      findsNothing,
    );
  });

  testWidgets('standalone history detail title hides a server GUID', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryDetailScreen(
          dealId: '894faaa5-5d41-49bd-8a52-5daf0281d948',
        ),
      ),
    );

    expect(find.text('11615687251'), findsOneWidget);
    expect(find.text('894faaa5-5d41-49bd-8a52-5daf0281d948'), findsNothing);
  });

  testWidgets('History trade rows use synchronized compact trailing values', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...videoReferenceOverrides,
          demoHistoryPositionsProvider.overrideWithValue(const [
            DemoHistoryPosition(
              id: 'history-buy',
              title: 'XAUUSD+',
              side: 'BUY',
              volume: .25,
              openPrice: 4600,
              closePrice: 4610,
              profit: 250,
              time: '2026.08.28 08:00:00',
            ),
            DemoHistoryPosition(
              id: 'history-sell',
              title: 'XAUUSD+',
              side: 'SELL',
              volume: .25,
              openPrice: 4600,
              closePrice: 4610,
              profit: -250,
              time: '2026.08.28 08:01:00',
            ),
          ]),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await pumpBottomAnchor(tester);

    final actions = tester
        .widgetList<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'history-positions-action-',
                ),
          ),
        )
        .toList();
    final buyAction = actions.singleWhere((text) => text.data!.contains('buy'));
    final sellAction = actions.singleWhere(
      (text) => text.data!.contains('sell'),
    );
    for (final action in actions) {
      expect(action.style?.fontFamily, AppTypography.historyAction.fontFamily);
      expect(action.style?.fontSize, AppTypography.historyAction.fontSize);
      expect(action.style?.fontWeight, AppTypography.historyAction.fontWeight);
      expect(
        action.style?.fontVariations,
        AppTypography.historyAction.fontVariations,
      );
      expect(
        action.style?.letterSpacing,
        AppTypography.historyAction.letterSpacing,
      );
    }
    expect(buyAction.style?.color, const Color(0xFF007AFF));
    expect(sellAction.style?.color, const Color(0xFFE42D30));

    final titles = tester
        .widgetList<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'history-positions-primary-',
                ),
          ),
        )
        .toList();
    for (final title in titles) {
      final rootSpan = title.textSpan! as TextSpan;
      final symbolSpan = rootSpan.children!.first as TextSpan;
      expect(
        symbolSpan.style?.fontFamily,
        AppTypography.historyPrimary.fontFamily,
      );
      expect(
        symbolSpan.style?.fontWeight,
        AppTypography.historyPrimary.fontWeight,
      );
      expect(symbolSpan.style?.fontVariations, isNull);
    }

    final profits = tester
        .widgetList<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'history-positions-trailing-primary-',
                ),
          ),
        )
        .toList();
    final positiveProfit = profits.singleWhere(
      (text) => !text.data!.startsWith('-'),
    );
    final negativeProfit = profits.singleWhere(
      (text) => text.data!.startsWith('-'),
    );
    for (final profit in profits) {
      expect(
        profit.style?.fontFamily,
        AppTypography.historyTrailingPrimary.fontFamily,
      );
      expect(
        profit.style?.fontSize,
        AppTypography.historyTrailingPrimary.fontSize,
      );
      expect(
        profit.style?.fontWeight,
        AppTypography.historyTrailingPrimary.fontWeight,
      );
      expect(profit.style?.fontVariations, isNull);
      expect(
        profit.style?.letterSpacing,
        AppTypography.historyTrailingPrimary.letterSpacing,
      );
    }
    expect(positiveProfit.style?.color, const Color(0xFF007AFF));
    expect(negativeProfit.style?.color, const Color(0xFFE42D30));

    final timestamp = tester.widget<Text>(
      find.byKey(const ValueKey('history-positions-trailing-secondary-0')),
    );
    expect(timestamp.style?.color, const Color(0xFF3C3C43));
    expect(
      timestamp.style?.fontSize,
      AppTypography.historyTrailingSecondary.fontSize,
    );
    expect(
      timestamp.style?.fontWeight,
      AppTypography.historyTrailingSecondary.fontWeight,
    );
    expect(timestamp.style?.fontVariations, isNull);

    final priceRanges = tester
        .widgetList<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'history-positions-secondary-',
                ),
          ),
        )
        .toList();
    for (final priceRange in priceRanges) {
      expect(priceRange.style?.color, const Color(0xFF3C3C43));
      expect(
        priceRange.style?.fontSize,
        AppTypography.historyPriceRange.fontSize,
      );
      expect(
        priceRange.style?.fontWeight,
        AppTypography.historyPriceRange.fontWeight,
      );
      expect(priceRange.style?.fontVariations, isNull);
      expect(
        priceRange.style?.letterSpacing,
        AppTypography.historyPriceRange.letterSpacing,
      );
    }
  });

  testWidgets('History Trade-equivalent glyphs keep unscaled paint geometry', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await pumpBottomAnchor(tester);

    final positionsList = tester.widget<ListView>(
      find.byKey(const PageStorageKey('history-positions-list')),
    );
    positionsList.controller!.jumpTo(0);
    await tester.pump();

    double paintScaleY(Finder finder) {
      final box = tester.renderObject<RenderBox>(finder);
      final origin = box.localToGlobal(Offset.zero);
      final edge = box.localToGlobal(Offset(0, box.size.height));
      return (edge.dy - origin.dy) / box.size.height;
    }

    expect(
      paintScaleY(find.byKey(const ValueKey('history-positions-action-0'))),
      closeTo(1, .001),
    );
    expect(
      paintScaleY(
        find.byKey(const ValueKey('history-positions-trailing-primary-0')),
      ),
      closeTo(1, .001),
    );
    expect(
      paintScaleY(find.byKey(const ValueKey('history-positions-secondary-0'))),
      closeTo(1, .001),
    );
    expect(
      paintScaleY(
        find.byKey(const ValueKey('history-positions-trailing-secondary-0')),
      ),
      closeTo(1, .001),
      reason: 'The timestamp must paint at the same 16px scale as the price.',
    );

    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();
    expect(
      paintScaleY(find.byKey(const ValueKey('history-orders-action-0'))),
      closeTo(1, .001),
    );
    expect(
      paintScaleY(
        find.byKey(const ValueKey('history-orders-trailing-primary-0')),
      ),
      closeTo(1, .001),
    );

    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();
    expect(
      paintScaleY(find.byKey(const ValueKey('history-deals-action-0'))),
      closeTo(1, .001),
    );
    expect(
      paintScaleY(find.byKey(const ValueKey('history-deals-secondary-0'))),
      closeTo(1, .001),
    );
  });

  testWidgets(
    'iOS History accent text keeps the locked winner role in every mode',
    (tester) async {
      await tester.pumpWidget(testApp(platform: TargetPlatform.iOS));
      await pumpBottomAnchor(tester);

      final positionsList = tester.widget<ListView>(
        find.byKey(const PageStorageKey('history-positions-list')),
      );
      positionsList.controller!.jumpTo(0);
      await tester.pump();

      final positionAction = tester.widget<Text>(
        find.byKey(const ValueKey('history-positions-action-0')),
      );
      final positionProfit = tester.widget<Text>(
        find.byKey(const ValueKey('history-positions-trailing-primary-0')),
      );
      expect(
        positionAction.style?.fontFamily,
        AppTypography.historyAction.fontFamily,
      );
      expect(
        positionAction.style?.fontWeight,
        AppTypography.historyAction.fontWeight,
      );
      expect(positionAction.style?.fontVariations, isNull);
      expect(
        positionProfit.style?.fontFamily,
        AppTypography.historyTrailingPrimary.fontFamily,
      );
      expect(
        positionProfit.style?.fontWeight,
        AppTypography.historyTrailingPrimary.fontWeight,
      );
      expect(positionProfit.style?.fontVariations, isNull);

      await tester.tap(find.byKey(const Key('history-tab-1')));
      await tester.pump();
      final orderAction = tester.widget<Text>(
        find.byKey(const ValueKey('history-orders-action-0')),
      );
      expect(
        orderAction.style?.fontFamily,
        AppTypography.historyAction.fontFamily,
      );
      expect(
        orderAction.style?.fontWeight,
        AppTypography.historyAction.fontWeight,
      );
      expect(orderAction.style?.fontVariations, isNull);

      await tester.tap(find.byKey(const Key('history-tab-2')));
      await tester.pump();
      final dealAction = tester.widget<Text>(
        find.byKey(const ValueKey('history-deals-action-0')),
      );
      expect(
        dealAction.style?.fontFamily,
        AppTypography.historyAction.fontFamily,
      );
      expect(
        dealAction.style?.fontWeight,
        AppTypography.historyAction.fontWeight,
      );
      expect(dealAction.style?.fontVariations, isNull);
    },
  );

  testWidgets('reference typography is shared across history modes', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());

    expect(find.text('Cac giao dich'), findsOneWidget);
    await pumpBottomAnchor(tester);

    final positionsSegmentFinder = find.byKey(
      const ValueKey('history-segment-label-0'),
    );
    final dealsSegmentFinder = find.byKey(
      const ValueKey('history-segment-label-2'),
    );
    expect(
      tester.widget<Text>(positionsSegmentFinder).data,
      'Lenh co trang thai',
    );
    expect(
      tester.widget<Text>(positionsSegmentFinder).style,
      _resolvedHistoryRole(
        tester,
        positionsSegmentFinder,
        role: ReferenceTextRole.historySegment,
        colorRole: ReferenceTextColorRole.primary,
        variant: TypographyVariantId.historyPositions,
      ),
    );
    expect(
      tester.widget<Text>(dealsSegmentFinder).style,
      _resolvedHistoryRole(
        tester,
        dealsSegmentFinder,
        role: ReferenceTextRole.historyDealsSegment,
        colorRole: ReferenceTextColorRole.primary,
        variant: TypographyVariantId.historyDeals,
      ),
    );
    final summaryFinder = find.byKey(
      const ValueKey('history-summary-label-Tien nap'),
    );
    final summary = tester.widget<Text>(summaryFinder);
    expect(summary.data, 'Tien nap');
    expect(
      summary.style,
      _resolvedHistoryRole(
        tester,
        summaryFinder,
        role: ReferenceTextRole.historySummary,
        colorRole: ReferenceTextColorRole.primary,
        variant: TypographyVariantId.historyBalance,
      ),
    );
    expect(summary.style?.fontSize, 15);
    expect(summary.style?.fontWeight, FontWeight.w600);
    expect(summary.style?.fontVariations, const <FontVariation>[
      FontVariation('wght', 600),
    ]);
    final summaryValueFinder = find.byKey(
      const ValueKey('history-summary-value-Tien nap'),
    );
    final summaryValue = tester.widget<Text>(summaryValueFinder);
    expect(
      summaryValue.style,
      _resolvedHistoryRole(
        tester,
        summaryValueFinder,
        role: ReferenceTextRole.historySummaryValue,
        colorRole: ReferenceTextColorRole.primary,
        variant: TypographyVariantId.historyBalance,
      ),
    );
    expect(summaryValue.style?.fontSize, 15);
    expect(summaryValue.style?.fontWeight, FontWeight.w600);
    expect(summaryValue.style?.fontVariations, const <FontVariation>[
      FontVariation('wght', 600),
    ]);

    final positionsList = tester.widget<ListView>(
      find.byKey(const PageStorageKey('history-positions-list')),
    );
    positionsList.controller!.jumpTo(0);
    await tester.pump();

    void expectRowTypography(String tab) {
      final primaryFinder = find.byKey(ValueKey('history-$tab-primary-0'));
      final secondaryFinder = find.byKey(ValueKey('history-$tab-secondary-0'));
      final variant = switch (tab) {
        'positions' => TypographyVariantId.historyPositions,
        'orders' => TypographyVariantId.historyOrders,
        'deals' => TypographyVariantId.historyDeals,
        _ => throw ArgumentError.value(tab),
      };
      expect(
        tester.widget<Text>(primaryFinder).style,
        _resolvedHistoryRole(
          tester,
          primaryFinder,
          role: ReferenceTextRole.historyPrimary,
          colorRole: ReferenceTextColorRole.primary,
          variant: variant,
        ),
        reason: tab,
      );
      expect(
        tester.widget<Text>(secondaryFinder).style,
        _resolvedHistoryRole(
          tester,
          secondaryFinder,
          role: tab == 'positions'
              ? ReferenceTextRole.historyPriceRange
              : ReferenceTextRole.historySecondary,
          colorRole: ReferenceTextColorRole.secondary,
          variant: variant,
        ),
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
    expect(AppTypography.historySecondary.letterSpacing, 0);
    final positionsTimestampFinder = find.byKey(
      const ValueKey('history-positions-trailing-secondary-0'),
    );
    expect(
      tester.widget<Text>(positionsTimestampFinder).style,
      _resolvedHistoryRole(
        tester,
        positionsTimestampFinder,
        role: ReferenceTextRole.historyTrailingSecondary,
        colorRole: ReferenceTextColorRole.secondary,
        variant: TypographyVariantId.historyPositions,
      ),
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

  testWidgets('entry deals keep their price without showing zero profit', (
    tester,
  ) async {
    const deals = <DemoDeal>[
      DemoDeal(
        id: 'reference-exit-deal',
        orderId: 'reference-exit-order',
        symbol: 'XAUUSD+',
        side: 'SELL',
        volume: 1,
        price: 4631.37,
        profit: 814,
        entry: 'out',
        time: '2026.08.24 10:45:11',
      ),
      DemoDeal(
        id: 'reference-entry-deal',
        orderId: 'reference-entry-order',
        symbol: 'XAUUSD+',
        side: 'BUY',
        volume: 1,
        price: 4637.05,
        profit: 0,
        time: '2026.08.24 11:58:13',
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: videoReferenceOverrides,
        child: ProviderScope(
          overrides: [demoDealsProvider.overrideWithValue(deals)],
          child: MaterialApp(home: const HistoryScreen()),
        ),
      ),
    );
    await pumpBottomAnchor(tester);
    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();

    final profit = tester.widget<Text>(
      find.byKey(const ValueKey('history-deals-trailing-primary-0')),
    );
    expect(profit.data, '814.00');
    expect(profit.style?.color, const Color(0xFF007AFF));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-deals-secondary-0')))
          .style
          ?.color,
      const Color(0xFF3C3C43),
    );
    expect(find.text('1 at 4637.05'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('history-deals-trailing-primary-1')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('history-deal-reference-entry-deal')),
        matching: find.text('0.00'),
      ),
      findsNothing,
    );
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
    'sort-revealed wallet history keeps order ink with synchronized metadata',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
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
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: const HistoryScreen(),
          ),
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
        tester.getRect(find.text('D-ALLINT-USD-INT-924750483461')).right,
        lessThanOrEqualTo(
          tester.getRect(find.text('2026.07.21 02:28:53')).left - 4,
        ),
      );
      expect(
        tester.getRect(find.text('W-BANKVNGT-USD-1475391737862')).right,
        lessThanOrEqualTo(
          tester.getRect(find.text('2026.07.21 06:49:19')).left - 4,
        ),
      );
      expect(
        tester.widget<Text>(find.text('518.54')).style?.color,
        const Color(0xFF007AFF),
      );
      expect(
        tester.widget<Text>(find.text('-2 000.00')).style?.color,
        const Color(0xFFE42D30),
      );

      await tester.tap(find.byKey(const Key('history-sort-button')));
      await tester.pump();

      final balanceTitles = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'history-positions-primary-',
                  ),
            ),
          )
          .toList();
      expect(balanceTitles, hasLength(2));
      for (final title in balanceTitles) {
        final titleFinder = find.byWidget(title);
        expect(
          title.style,
          _resolvedHistoryRole(
            tester,
            titleFinder,
            role: ReferenceTextRole.historyBalancePrimary,
            colorRole: ReferenceTextColorRole.primary,
            variant: TypographyVariantId.historyBalance,
          ),
        );
        final rootSpan = title.textSpan! as TextSpan;
        final balanceSpan = rootSpan.children!.first as TextSpan;
        expect(balanceSpan.style?.color, const Color(0xFF000000));
        expect(
          balanceSpan.style?.fontFamily,
          AppTypography.historyBalancePrimary.fontFamily,
        );
        expect(
          balanceSpan.style?.fontWeight,
          AppTypography.historyBalancePrimary.fontWeight,
        );
        expect(
          balanceSpan.style?.fontWeight,
          AppTypography.historyPrimary.fontWeight,
          reason:
              'Sort-revealed Balance titles must be as bold as XAUUSD titles.',
        );
        expect(balanceSpan.style?.fontVariations, isNull);
      }

      final references = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'history-positions-secondary-',
                  ),
            ),
          )
          .toList();
      expect(references, hasLength(2));
      for (final reference in references) {
        final referenceFinder = find.byWidget(reference);
        expect(reference.style?.color, const Color(0xFF3C3C43));
        expect(
          reference.style,
          _resolvedHistoryRole(
            tester,
            referenceFinder,
            role: ReferenceTextRole.historyBalanceSecondary,
            colorRole: ReferenceTextColorRole.secondary,
            variant: TypographyVariantId.historyBalance,
          ),
        );
      }

      final dates = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'history-positions-trailing-secondary-',
                  ),
            ),
          )
          .toList();
      expect(dates, hasLength(2));
      for (final date in dates) {
        final dateFinder = find.byWidget(date);
        expect(date.style?.color, const Color(0xFF3C3C43));
        expect(
          date.style,
          _resolvedHistoryRole(
            tester,
            dateFinder,
            role: ReferenceTextRole.historyBalanceSecondary,
            colorRole: ReferenceTextColorRole.secondary,
            variant: TypographyVariantId.historyBalance,
          ),
        );
        final intrinsicDate = TextPainter(
          text: TextSpan(text: date.data, style: date.style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(tester.element(dateFinder)),
          maxLines: 1,
        )..layout();
        expect(
          tester.getSize(dateFinder).width,
          closeTo(intrinsicDate.width, .01),
          reason:
              'Sort-revealed Balance dates must stay shrink-wrapped at the '
              'right edge instead of occupying a flexible middle slot.',
        );
      }

      final amounts = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'history-positions-trailing-primary-',
                  ),
            ),
          )
          .toList();
      expect(amounts, hasLength(2));
      for (final amount in amounts) {
        final amountFinder = find.byWidget(amount);
        final expectedAmountStyle = _resolvedHistoryRole(
          tester,
          amountFinder,
          role: ReferenceTextRole.historyBalanceTrailingPrimary,
          colorRole: amount.data!.startsWith('-')
              ? ReferenceTextColorRole.negative
              : ReferenceTextColorRole.positive,
          variant: TypographyVariantId.historyBalance,
        );
        expect(amount.style?.fontFamily, expectedAmountStyle.fontFamily);
        expect(amount.style?.fontSize, expectedAmountStyle.fontSize);
        expect(amount.style?.fontWeight, expectedAmountStyle.fontWeight);
        expect(amount.style?.fontVariations, isNull);
        expect(amount.style?.letterSpacing, expectedAmountStyle.letterSpacing);
        expect(amount.style?.height, expectedAmountStyle.height);
        expect(amount.style?.color, expectedAmountStyle.color);
      }

      double paintScaleY(Text text) {
        final box = tester.renderObject<RenderBox>(find.byWidget(text));
        final origin = box.localToGlobal(Offset.zero);
        final edge = box.localToGlobal(Offset(0, box.size.height));
        return (edge.dy - origin.dy) / box.size.height;
      }

      for (final text in [
        ...balanceTitles,
        ...references,
        ...dates,
        ...amounts,
      ]) {
        expect(paintScaleY(text), closeTo(1, .001));
      }
    },
  );

  testWidgets('position history uses compact synchronized profit values', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await pumpBottomAnchor(tester);

    final summaryLabelFinder = find.byKey(
      const ValueKey('history-summary-label-Tien nap'),
    );
    final summaryLabel = tester.widget<Text>(summaryLabelFinder);
    expect(summaryLabel.data, 'Tien nap');
    expect(
      summaryLabel.style,
      _resolvedHistoryRole(
        tester,
        summaryLabelFinder,
        role: ReferenceTextRole.historySummary,
        colorRole: ReferenceTextColorRole.primary,
        variant: TypographyVariantId.historyBalance,
      ),
    );

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

    final titleFinder = find.byWidget(title);
    final profitFinder = find.byWidget(profit);
    final priceFinder = find.byWidget(price);
    final timeFinder = find.byWidget(time);
    expect(
      title.style,
      _resolvedHistoryRole(
        tester,
        titleFinder,
        role: ReferenceTextRole.historyPrimary,
        colorRole: ReferenceTextColorRole.primary,
        variant: TypographyVariantId.historyPositions,
      ),
    );
    final expectedProfitStyle = _resolvedHistoryRole(
      tester,
      profitFinder,
      role: ReferenceTextRole.historyTrailingPrimary,
      colorRole: ReferenceTextColorRole.negative,
      variant: TypographyVariantId.historyPositions,
    );
    expect(profit.style?.fontFamily, expectedProfitStyle.fontFamily);
    expect(profit.style?.fontWeight, expectedProfitStyle.fontWeight);
    expect(profit.style?.color, expectedProfitStyle.color);
    expect(
      price.style,
      _resolvedHistoryRole(
        tester,
        priceFinder,
        role: ReferenceTextRole.historyPriceRange,
        colorRole: ReferenceTextColorRole.secondary,
        variant: TypographyVariantId.historyPositions,
      ),
    );
    expect(
      time.style,
      _resolvedHistoryRole(
        tester,
        timeFinder,
        role: ReferenceTextRole.historyTrailingSecondary,
        colorRole: ReferenceTextColorRole.secondary,
        variant: TypographyVariantId.historyPositions,
      ),
    );
    expect(
      tester.getTopLeft(find.byWidget(price)).dy -
          tester.getTopLeft(find.byWidget(title)).dy,
      closeTo(
        TabReferenceMetrics.historyPriceRangeTop -
            TabReferenceMetrics.historyPrimaryTop,
        .1,
      ),
    );
    expect(
      tester.getBottomLeft(find.byWidget(title)).dy,
      lessThan(tester.getTopLeft(find.byWidget(price)).dy),
    );
  });

  testWidgets('order and deal rows use the shared winner typography', (
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
    expect(
      orderTexts.first.style?.fontFamily,
      AppTypography.historyPrimary.fontFamily,
    );
    expect(
      orderTexts.first.style?.fontWeight,
      AppTypography.historyPrimary.fontWeight,
    );
    expect(
      orderTexts.last.style?.fontFamily,
      AppTypography.historyTrailingSecondary.fontFamily,
    );
    expect(
      orderTexts.last.style?.fontWeight,
      AppTypography.historyTrailingSecondary.fontWeight,
    );

    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();
    final deal = find.byKey(const Key('history-deal-57016800413'));
    final dealTexts = tester
        .widgetList<Text>(
          find.descendant(of: deal, matching: find.byType(Text)),
        )
        .toList();
    expect(
      dealTexts.first.style?.fontFamily,
      AppTypography.historyPrimary.fontFamily,
    );
    expect(
      dealTexts.first.style?.fontWeight,
      AppTypography.historyPrimary.fontWeight,
    );
    expect(
      dealTexts.last.style?.fontFamily,
      AppTypography.historyTrailingSecondary.fontFamily,
    );
    expect(
      dealTexts.last.style?.fontWeight,
      AppTypography.historyTrailingSecondary.fontWeight,
    );
  });

  testWidgets('history segment labels use deterministic compact styles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp());
    await pumpBottomAnchor(tester);

    const labelValues = ['Lenh co trang thai', 'Cac lenh', 'Cac giao dich'];
    final labelFinders = <Finder>[
      for (var index = 0; index < labelValues.length; index++)
        find.byKey(ValueKey('history-segment-label-$index')),
    ];
    final labels = <Text>[
      for (final finder in labelFinders) tester.widget<Text>(finder),
    ];

    for (final (index, label) in labels.indexed) {
      expect(label.data, labelValues[index]);
      final expectedStyle = _resolvedHistoryRole(
        tester,
        labelFinders[index],
        role: index == 2
            ? ReferenceTextRole.historyDealsSegment
            : ReferenceTextRole.historySegment,
        colorRole: ReferenceTextColorRole.primary,
        variant: const [
          TypographyVariantId.historyPositions,
          TypographyVariantId.historyOrders,
          TypographyVariantId.historyDeals,
        ][index],
      );
      expect(label.style?.fontFamily, expectedStyle.fontFamily);
      expect(label.style?.fontSize, 14);
      expect(label.style?.height, 1);
      expect(label.style?.color, const Color(0xFF000000));
    }

    final firstRect = tester.getRect(labelFinders[0]);
    final secondRect = tester.getRect(labelFinders[1]);
    final thirdRect = tester.getRect(labelFinders[2]);
    expect(firstRect.right, lessThanOrEqualTo(secondRect.left));
    expect(secondRect.right, lessThanOrEqualTo(thirdRect.left));
  });

  testWidgets('history rows keep both lines separate at larger text scales', (
    tester,
  ) async {
    const position = DemoHistoryPosition(
      id: 'scaled-history-position',
      title: 'XAUUSD+',
      side: 'SELL',
      volume: 0.25,
      openPrice: 4000,
      closePrice: 4001,
      profit: -20,
      time: '2026.08.26 08:35:00',
    );
    const walletEntry = DemoHistoryPosition(
      id: 'scaled-wallet-entry',
      title: 'Balance',
      profit: 518.54,
      time: '2026.08.26 08:36:00',
      subtitle: 'D-ALLINT-USD-INT-924750483461',
    );

    for (final width in <double>[360, 430]) {
      for (final scale in <double>[1.3, 2]) {
        tester.view.physicalSize = Size(width, 848);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...videoReferenceOverrides,
              demoHistoryPositionsProvider.overrideWithValue(const [
                position,
                walletEntry,
              ]),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 848),
                  textScaler: TextScaler.linear(scale),
                ),
                child: HistoryScreen(key: ValueKey('history-$width-$scale')),
              ),
            ),
          ),
        );
        await pumpBottomAnchor(tester);

        final row = find.byKey(
          const ValueKey('history-position-scaled-history-position'),
        );
        expect(row, findsOneWidget, reason: 'width=$width scale=$scale');
        Finder roleText(String role) => find.descendant(
          of: row,
          matching: find.byWidgetPredicate((widget) {
            final key = widget.key;
            return widget is Text &&
                key is ValueKey<String> &&
                key.value.startsWith(role);
          }),
        );
        final primary = roleText('history-positions-primary-');
        final trailingPrimary = roleText('history-positions-trailing-primary-');
        final secondary = roleText('history-positions-secondary-');
        final trailingSecondary = roleText(
          'history-positions-trailing-secondary-',
        );
        final firstSummary = find.text('Tien nap');
        final secondSummary = find.text('Loi nhuan');

        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(primary).bottom,
          lessThanOrEqualTo(tester.getRect(secondary).top),
          reason: 'width=$width scale=$scale',
        );
        expect(
          tester.getRect(firstSummary).bottom,
          lessThanOrEqualTo(tester.getRect(secondSummary).top),
          reason: 'width=$width scale=$scale',
        );
        expect(
          tester.getRect(primary).overlaps(tester.getRect(trailingPrimary)),
          isFalse,
          reason: 'position primary width=$width scale=$scale',
        );
        expect(
          tester.getRect(secondary).overlaps(tester.getRect(trailingSecondary)),
          isFalse,
          reason: 'position secondary width=$width scale=$scale',
        );
        final walletRow = find.byKey(
          const ValueKey('history-position-scaled-wallet-entry'),
        );
        Finder walletRoleText(String role) => find.descendant(
          of: walletRow,
          matching: find.byWidgetPredicate((widget) {
            final key = widget.key;
            return widget is Text &&
                key is ValueKey<String> &&
                key.value.startsWith(role);
          }),
        );
        final walletReference = walletRoleText('history-positions-secondary-');
        final walletTime = walletRoleText(
          'history-positions-trailing-secondary-',
        );
        expect(
          tester.getRect(walletReference).overlaps(tester.getRect(walletTime)),
          isFalse,
          reason: 'wallet secondary width=$width scale=$scale',
        );

        if (width == 360 && scale == 2) {
          await tester.tap(find.byKey(const Key('history-tab-1')));
          await tester.pump();
          final order = find.byKey(const Key('history-order-57360798130'));
          Finder orderRoleText(String role) => find.descendant(
            of: order,
            matching: find.byWidgetPredicate((widget) {
              final key = widget.key;
              return widget is Text &&
                  key is ValueKey<String> &&
                  key.value.startsWith(role);
            }),
          );
          expect(
            tester
                .getRect(orderRoleText('history-orders-primary-'))
                .overlaps(
                  tester.getRect(
                    orderRoleText('history-orders-trailing-primary-'),
                  ),
                ),
            isFalse,
          );
          expect(
            tester
                .getRect(orderRoleText('history-orders-secondary-'))
                .overlaps(
                  tester.getRect(
                    orderRoleText('history-orders-trailing-secondary-'),
                  ),
                ),
            isFalse,
          );

          await tester.tap(find.byKey(const Key('history-tab-2')));
          await tester.pump();
          final deal = find.byKey(const Key('history-deal-57016800413'));
          Finder dealRoleText(String role) => find.descendant(
            of: deal,
            matching: find.byWidgetPredicate((widget) {
              final key = widget.key;
              return widget is Text &&
                  key is ValueKey<String> &&
                  key.value.startsWith(role);
            }),
          );
          expect(
            tester
                .getRect(dealRoleText('history-deals-secondary-'))
                .overlaps(
                  tester.getRect(
                    dealRoleText('history-deals-trailing-secondary-'),
                  ),
                ),
            isFalse,
          );
        }
      }
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
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
    final navigationFadeTop =
        listRect.bottom - TabReferenceMetrics.bottomNavigationFadeHeight;
    expect(footerRect.top, greaterThan(listRect.top));
    expect(
      footerRect.bottom,
      closeTo(navigationFadeTop, .01),
      reason: 'The initial balance footer must sit above the navigation fade.',
    );

    await tester.drag(listFinder, const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(find.byKey(const ValueKey('history-summary-Số dư')))
          .bottom,
      greaterThan(navigationFadeTop),
      reason: 'The footer may enter the fade only after the user scrolls.',
    );
    expect(find.text('2 301.60'), findsOneWidget);
  });

  testWidgets('a newly closed position appears at the bottom immediately', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        demoHistoryPositionsProvider.overrideWith(
          (ref) => ref.watch(_liveHistoryRowsProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    final existing = List<DemoHistoryPosition>.generate(
      40,
      (index) => DemoHistoryPosition(
        id: 'existing-$index',
        title: 'XAUUSD+',
        side: 'BUY',
        volume: 1 + index.toDouble(),
        openPrice: 4200,
        closePrice: 4201,
        profit: 1 + index.toDouble(),
        time:
            '2026.08.${(index % 28 + 1).toString().padLeft(2, '0')} '
            '10:00:00',
      ),
    );
    container.read(_liveHistoryRowsProvider.notifier).replace(existing);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await pumpBottomAnchor(tester);

    const newest = DemoHistoryPosition(
      id: 'just-closed',
      title: 'XAUUSD+',
      side: 'SELL',
      volume: 0.01,
      openPrice: 4400,
      closePrice: 4399,
      profit: -1,
      time: '2026.09.01 12:00:00',
    );
    container.read(_liveHistoryRowsProvider.notifier).replace([
      ...existing,
      newest,
    ]);
    await pumpBottomAnchor(tester);

    final list = tester.widget<ListView>(
      find.byKey(const PageStorageKey('history-positions-list')),
    );
    expect(
      list.controller!.position.pixels,
      closeTo(list.controller!.position.maxScrollExtent, .01),
    );
    expect(
      find.byKey(const ValueKey('history-position-just-closed')),
      findsOneWidget,
    );
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
        closeTo(selectedTab.center.dx, 1),
        reason: 'The winner font is centered without a text-only transform.',
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
    'orders and deals own persistent scrollbars while positions stays transient',
    (tester) async {
      await tester.pumpWidget(testApp());
      await pumpBottomAnchor(tester);

      final positionsList = tester.widget<ListView>(
        find.byKey(const PageStorageKey('history-positions-list')),
      );
      final positionsScrollbar = tester.widget<Scrollbar>(
        find.byKey(const Key('history-positions-scrollbar')),
      );
      expect(positionsScrollbar.thumbVisibility, isFalse);
      expect(positionsScrollbar.controller, same(positionsList.controller));

      await tester.tap(find.byKey(const Key('history-tab-1')));
      await tester.pump();
      final ordersList = tester.widget<ListView>(
        find.byKey(const PageStorageKey('history-orders-list')),
      );
      final ordersScrollbar = tester.widget<RawScrollbar>(
        find.byKey(const Key('history-orders-scrollbar')),
      );
      expect(ordersList.controller, isNotNull);
      expect(ordersScrollbar.controller, same(ordersList.controller));
      expect(ordersScrollbar.thumbVisibility, isTrue);
      expect(ordersScrollbar.fadeDuration, Duration.zero);
      expect(ordersScrollbar.thickness, 3.3333333333);
      expect(ordersScrollbar.crossAxisMargin, 2.6666666667);
      expect(ordersScrollbar.thumbColor, AppColors.transparent);

      await tester.tap(find.byKey(const Key('history-tab-2')));
      await tester.pump();
      final dealsList = tester.widget<ListView>(
        find.byKey(const PageStorageKey('history-deals-list')),
      );
      final dealsScrollbar = tester.widget<RawScrollbar>(
        find.byKey(const Key('history-deals-scrollbar')),
      );
      expect(dealsList.controller, isNotNull);
      expect(dealsScrollbar.controller, same(dealsList.controller));
      expect(dealsScrollbar.thumbVisibility, isTrue);
      expect(dealsScrollbar.fadeDuration, Duration.zero);
      expect(dealsScrollbar.thickness, 3.3333333333);
      expect(dealsScrollbar.crossAxisMargin, 2.6666666667);
      expect(dealsScrollbar.thumbColor, AppColors.transparent);
    },
  );

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

final _liveHistoryRowsProvider =
    NotifierProvider<_LiveHistoryRowsController, List<DemoHistoryPosition>>(
      _LiveHistoryRowsController.new,
    );

final class _LiveHistoryRowsController
    extends Notifier<List<DemoHistoryPosition>> {
  @override
  List<DemoHistoryPosition> build() => const [];

  void replace(List<DemoHistoryPosition> rows) => state = rows;
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
