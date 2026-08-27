import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/features/trade/presentation/widgets/position_bulk_actions_dialog.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/mt_price_range_text.dart';

import 'test_support/load_test_fonts.dart';

const _allPositionIds = {'x-buy-win', 'x-buy-loss', 'x-sell-win', 'e-buy-win'};
const _allPositionIdOrder = [
  'x-buy-win',
  'x-buy-loss',
  'x-sell-win',
  'e-buy-win',
];

const _expectedClosedIds = {
  PositionBulkActionScope.all: {
    'x-buy-win',
    'x-buy-loss',
    'x-sell-win',
    'e-buy-win',
  },
  PositionBulkActionScope.profitable: {'x-buy-win', 'x-sell-win', 'e-buy-win'},
  PositionBulkActionScope.sameSide: {'x-buy-win', 'x-buy-loss', 'e-buy-win'},
  PositionBulkActionScope.sameSymbol: {'x-buy-win', 'x-buy-loss', 'x-sell-win'},
  PositionBulkActionScope.sameSymbolAndSide: {'x-buy-win', 'x-buy-loss'},
};

DemoTradingState _bulkFlowSeed(String accountId) => const DemoTradingState(
  balance: 100000,
  positions: [
    DemoPosition(
      id: 'x-buy-win',
      symbol: 'XAUUSD',
      side: 'BUY',
      volume: 1,
      openPrice: 4622.83,
      currentPrice: 4623.10,
      profit: 27,
    ),
    DemoPosition(
      id: 'x-buy-loss',
      symbol: 'XAUUSD',
      side: 'BUY',
      volume: 2,
      openPrice: 4624,
      currentPrice: 4623.10,
      profit: -90,
    ),
    DemoPosition(
      id: 'x-sell-win',
      symbol: 'XAUUSD',
      side: 'SELL',
      volume: .5,
      openPrice: 4624.10,
      currentPrice: 4623.10,
      profit: 50,
    ),
    DemoPosition(
      id: 'e-buy-win',
      symbol: 'EURUSD',
      side: 'BUY',
      volume: .1,
      openPrice: 1.10,
      currentPrice: 1.11,
      profit: 10,
    ),
  ],
  deals: [],
);

ProviderContainer _createContainer() => ProviderContainer(
  overrides: [
    demoTradingSeedProvider.overrideWithValue(_bulkFlowSeed),
    demoQuoteProvider.overrideWith(
      (ref, symbol) => const Stream<DemoQuote>.empty(),
    ),
  ],
);

Future<void> _pumpTrade(
  WidgetTester tester,
  ProviderContainer container, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view.physicalSize = const Size(384, 848);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: const TradeScreen(),
      ),
    ),
  );
  await tester.pump();
}

double _variableWeight(TextStyle? style) {
  final weights = style?.fontVariations
      ?.where((variation) => variation.axis == 'wght')
      .toList();
  expect(weights, isNotNull);
  expect(weights, hasLength(1));
  return weights!.single.value;
}

Future<void> _openContextualBulkDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('trade-position-x-buy-win')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hoạt động hàng loạt...'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('position-bulk-actions-dialog')), findsOneWidget);
}

void main() {
  setUpAll(loadMt5TestFonts);

  testWidgets('trade renders the measured reference foreground colors', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await _pumpTrade(tester, container);

    final header = tester.widget<Text>(
      find.byKey(const Key('trade-header-profit')),
    );
    expect(find.byKey(const Key('trade-header-currency')), findsOneWidget);
    expect(header.style?.color, const Color(0xFFE42D30));

    final winningPrimary = tester.widget<Text>(
      find.byKey(const ValueKey('trade-position-primary-x-buy-win')),
    );
    final winningSpans = (winningPrimary.textSpan! as TextSpan).children!;
    expect(winningSpans.first.style?.color, const Color(0xFF000000));
    expect(winningSpans.last.style?.color, const Color(0xFF007AFF));

    final losingProfit = tester.widget<Text>(
      find.byKey(const ValueKey('trade-position-profit-x-buy-loss')),
    );
    expect(losingProfit.style?.color, const Color(0xFFE42D30));
  });

  testWidgets('iOS trade text compensates its lighter raster coverage', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await _pumpTrade(tester, container, platform: TargetPlatform.iOS);

    final header = tester.widget<Text>(
      find.byKey(const Key('trade-header-profit')),
    );
    final section = tester.widget<Text>(
      find.byKey(const Key('trade-section-label')),
    );
    final primary = tester.widget<Text>(
      find.byKey(const ValueKey('trade-position-primary-x-buy-win')),
    );
    final secondary = tester.widget<Text>(
      find.byKey(const ValueKey('trade-position-secondary-x-buy-win')),
    );
    final profit = tester.widget<Text>(
      find.byKey(const ValueKey('trade-position-profit-x-buy-win')),
    );

    expect(_variableWeight(header.style), 450);
    expect(_variableWeight(section.style), 850);
    expect(_variableWeight(primary.style), 400);
    final primarySpans = (primary.textSpan! as TextSpan).children!;
    expect(_variableWeight(primarySpans.first.style), 500);
    expect(_variableWeight(secondary.style), 350);
    expect(_variableWeight(profit.style), 450);
  });

  testWidgets('trade reference typography keeps measured baselines', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await _pumpTrade(tester, container);

    final header = tester.widget<Text>(
      find.byKey(const Key('trade-header-profit')),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('trade-header-profit'))).dy,
      closeTo(40, .1),
    );
    expect(
      header.style,
      AppTypography.tradeHeaderProfit.copyWith(color: AppColors.negative),
    );
    final metric = tester.widget<Text>(
      find.byKey(const ValueKey('trade-metric-label-Số dư:')),
    );
    expect(metric.style, AppTypography.tradeMetric);
    final metricValue = tester.widget<Text>(
      find.byKey(const ValueKey('trade-metric-value-Số dư:')),
    );
    expect(metricValue.style, AppTypography.tradeMetricValue);
    expect(
      tester.getSize(find.byKey(const Key('trade-account-metrics'))).height,
      closeTo(
        TabReferenceMetrics.tradeMetricRowHeight * 5 + 10.6666666667,
        .001,
      ),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('trade-section-label'))).style,
      AppTypography.tradeSection,
    );

    final primaryFinder = find.byKey(
      const ValueKey('trade-position-primary-x-buy-win'),
    );
    final secondaryFinder = find.byKey(
      const ValueKey('trade-position-secondary-x-buy-win'),
    );
    final profitFinder = find.byKey(
      const ValueKey('trade-position-profit-x-buy-win'),
    );
    expect(
      tester.widget<Text>(primaryFinder).style,
      AppTypography.tradePositionPrimary,
    );
    expect(
      tester.widget<Text>(secondaryFinder).style,
      AppTypography.tradePositionSecondary,
    );
    expect(
      tester.widget<Text>(profitFinder).style,
      AppTypography.tradePositionProfit.copyWith(color: AppColors.primary),
    );
    expect(
      tester.getTopLeft(secondaryFinder).dy,
      closeTo(
        tester.getTopLeft(primaryFinder).dy +
            TabReferenceMetrics.tradePositionSecondaryTop,
        .75,
      ),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('trade-position-x-buy-win')))
          .height,
      TabReferenceMetrics.tradePositionRowHeight,
    );
  });

  testWidgets('trade position price range uses the reference black text', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await _pumpTrade(tester, container);

    final row = find.byKey(const ValueKey('trade-position-x-buy-win'));
    final priceRange = find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is MtPriceRangeText &&
            widget.openPrice == '4622.830' &&
            widget.closePrice == '4623.100',
      ),
    );

    expect(priceRange, findsOneWidget);
    expect(find.text('↑'), findsNothing);
    expect(
      find.descendant(
        of: priceRange,
        matching: find.byKey(const Key('mt-price-range-arrow')),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<MtPriceRangeText>(priceRange).style.color,
      AppTypography.tradePositionSecondary.color,
    );
  });

  testWidgets('trade virtualizes a 30-position batch', (tester) async {
    final positions = List<DemoPosition>.generate(
      30,
      (index) => DemoPosition(
        id: 'performance-position-$index',
        symbol: 'XAUUSD',
        side: index.isEven ? 'BUY' : 'SELL',
        volume: 0.01,
        openPrice: 4600 + index.toDouble(),
        currentPrice: 4601 + index.toDouble(),
        profit: index.isEven ? 1 : -1,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        demoTradingSeedProvider.overrideWithValue(
          (_) => DemoTradingState(
            balance: 100000,
            positions: positions,
            deals: const [],
          ),
        ),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _pumpTrade(tester, container);

    final scrollbar = tester.widget<RawScrollbar>(
      find.byKey(const Key('trade-position-scrollbar')),
    );
    expect(scrollbar.thumbVisibility, isTrue);
    expect(scrollbar.thickness, 3.3333333333);
    expect(scrollbar.fadeDuration, Duration.zero);
    expect(scrollbar.radius, const Radius.circular(1.4));
    expect(
      scrollbar.padding,
      const EdgeInsets.only(
        top: TabReferenceMetrics.tradeScrollbarTopInset,
        bottom: TabReferenceMetrics.tradeScrollbarBottomInset,
      ),
    );
    expect(
      scrollbar.minThumbLength,
      TabReferenceMetrics.tradeScrollbarThumbExtent,
    );

    final sliverLists = tester.widgetList<SliverList>(find.byType(SliverList));
    expect(sliverLists, isNotEmpty);
    expect(
      sliverLists.every(
        (sliver) => sliver.delegate is SliverChildBuilderDelegate,
      ),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('trade-position-performance-position-29')),
      findsNothing,
    );
  });

  for (final scope in PositionBulkActionScope.values) {
    testWidgets(
      'contextual bulk ${scope.name} closes only its position scope',
      (tester) async {
        final container = _createContainer();
        addTearDown(container.dispose);
        await _pumpTrade(tester, container);
        await _openContextualBulkDialog(tester);

        await tester.tap(
          find.byKey(ValueKey('position-bulk-action-${scope.name}')),
        );
        await tester.pumpAndSettle();

        final expectedClosed = _expectedClosedIds[scope]!;
        final expectedClosedOrder = _allPositionIdOrder
            .where(expectedClosed.contains)
            .toList(growable: false);
        final expectedRemaining = _allPositionIds.difference(expectedClosed);
        expect(
          container.read(demoPositionsProvider).map((item) => item.id).toSet(),
          expectedRemaining,
        );
        final closedHistoryIds = container
            .read(demoTradingProvider)
            .historyPositions
            .map((item) => item.id)
            .where((id) => id.startsWith('closed-'))
            .map((id) => expectedClosed.singleWhere(id.contains))
            .toList(growable: false);
        expect(closedHistoryIds, orderedEquals(expectedClosedOrder));
        expect(closedHistoryIds, hasLength(expectedClosed.length));
        expect(
          find.byKey(const Key('position-bulk-actions-dialog')),
          findsNothing,
        );
      },
    );
  }

  testWidgets('contextual bulk cancel keeps every position', (tester) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await _pumpTrade(tester, container);
    await _openContextualBulkDialog(tester);

    await tester.tap(find.byKey(const Key('position-bulk-cancel')));
    await tester.pumpAndSettle();

    expect(
      container.read(demoPositionsProvider).map((item) => item.id).toSet(),
      _allPositionIds,
    );
  });

  testWidgets('contextual bulk evaluates current state when action is tapped', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await _pumpTrade(tester, container);
    await _openContextualBulkDialog(tester);

    expect(
      container.read(demoTradingProvider.notifier).closePosition('x-buy-loss'),
      isTrue,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('position-bulk-action-sameSymbolAndSide')),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(demoPositionsProvider).map((item) => item.id),
      orderedEquals(['x-sell-win', 'e-buy-win']),
    );
    expect(container.read(demoTradingProvider).historyPositions, hasLength(2));
  });
}
