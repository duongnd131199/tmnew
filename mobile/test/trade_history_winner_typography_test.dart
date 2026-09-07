import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/reference_typography_profile.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/load_test_fonts.dart';
import 'test_support/video_reference_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMt5TestFonts);

  test('Trade and History roles keep the audited static metrics', () {
    _expectStaticToken(
      AppTypography.tradeMetric,
      family: AppTypography.referenceCondensedFamily,
      size: 16,
      weight: FontWeight.w400,
      tracking: .5,
      height: 1.15,
      tabularFigures: true,
    );
    _expectStaticToken(
      AppTypography.tradeMetricValue,
      family: AppTypography.referenceCondensedFamily,
      size: 16,
      weight: FontWeight.w400,
      tracking: .2,
      height: 1.15,
      tabularFigures: true,
    );
    _expectStaticToken(
      AppTypography.tradePositionPrimary,
      family: AppTypography.referenceCondensedFamily,
      size: 15.3,
      weight: FontWeight.w700,
      tracking: 0,
      height: 1,
    );
    expect(AppTypography.historyPrimary, AppTypography.tradePositionPrimary);
    _expectStaticToken(
      AppTypography.historyBalancePrimary,
      family: AppTypography.referenceCondensedFamily,
      size: 15.3,
      weight: FontWeight.w700,
      tracking: 0,
      height: 1,
    );
    _expectStaticToken(
      AppTypography.historyAction,
      family: AppTypography.referencePlainFamily,
      size: 15.3,
      weight: FontWeight.w700,
      tracking: 0,
      height: 1,
    );

    for (final style in <TextStyle>[
      AppTypography.historySecondary,
      AppTypography.historyPriceRange,
      AppTypography.historyBalanceSecondary,
      AppTypography.historyTrailingSecondary,
    ]) {
      _expectStaticToken(
        style,
        family: AppTypography.referenceCondensedFamily,
        size: 14,
        weight: FontWeight.w400,
        tracking: 0,
        height: 1,
        tabularFigures: true,
      );
    }

    for (final style in <TextStyle>[
      AppTypography.historySegment,
      AppTypography.historyDealsSegment,
    ]) {
      _expectStaticToken(
        style,
        family: AppTypography.referencePlainFamily,
        size: 14,
        weight: FontWeight.w400,
        tracking: 0,
        height: 1,
      );
    }

    for (final style in <TextStyle>[
      AppTypography.historySummary,
      AppTypography.historyOrderSummaryTotal,
      AppTypography.historySummaryValue,
    ]) {
      _expectStaticToken(
        style,
        family: AppTypography.referencePlainFamily,
        size: 14.5,
        weight: FontWeight.w400,
        tracking: 0,
        height: 1,
        tabularFigures: true,
      );
    }
  });

  testWidgets(
    'Trade resolves winner roles without local width axes or text transforms',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: videoReferenceOverrides,
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: const TradeScreen(),
          ),
        ),
      );
      await tester.pump();

      final metricLabel = tester.widget<Text>(
        find.byKey(const ValueKey('trade-metric-label-Số dư:')),
      );
      final metricValue = tester.widget<Text>(
        find.byKey(const ValueKey('trade-metric-value-Số dư:')),
      );
      final section = tester.widget<Text>(
        find.byKey(const Key('trade-section-label')),
      );
      _expectRole(metricLabel.style!, AppTypography.tradeMetric);
      _expectRole(metricValue.style!, AppTypography.tradeMetricValue);
      _expectRole(section.style!, AppTypography.tradeSection);
      _expectNoLocalTransform(
        tester,
        find.byKey(const ValueKey('trade-metric-label-Số dư:')),
        boundaryKeyPrefix: 'trade-account-metrics',
      );
      _expectNoLocalTransform(
        tester,
        find.byKey(const ValueKey('trade-metric-value-Số dư:')),
        boundaryKeyPrefix: 'trade-account-metrics',
      );
      _expectNoLocalFittedBox(
        tester,
        find.byKey(const ValueKey('trade-metric-value-Số dư:')),
        boundaryKeyPrefix: 'trade-account-metrics',
      );
      _expectNoLocalFittedBox(
        tester,
        find.byKey(const ValueKey('trade-metric-label-Số dư:')),
        boundaryKeyPrefix: 'trade-account-metrics',
      );

      final primaryFinder = _textWithKeyPrefix('trade-position-primary-').first;
      final secondaryFinder = _textWithKeyPrefix(
        'trade-position-secondary-',
      ).first;
      final profitFinder = _textWithKeyPrefix('trade-position-profit-').first;
      final primary = tester.widget<Text>(primaryFinder);
      final spans = (primary.textSpan! as TextSpan).children!.cast<TextSpan>();
      final symbolStyle = primary.style!.merge(spans[0].style);
      final sideStyle = primary.style!.merge(spans[1].style);
      _expectRole(symbolStyle, AppTypography.tradePositionPrimary);
      expect(
        symbolStyle.fontWeight,
        FontWeight.w700,
        reason: 'Trade symbols match the bold XAUUSD label in Prices.',
      );
      _expectRole(
        sideStyle,
        AppTypography.tradePositionPrimary.merge(
          AppTypography.tradePositionSide,
        ),
      );
      _expectRole(
        tester.widget<Text>(secondaryFinder).style!,
        AppTypography.tradePositionSecondary,
      );
      _expectRole(
        tester.widget<Text>(profitFinder).style!,
        AppTypography.tradePositionProfit,
      );

      for (final finder in [primaryFinder, secondaryFinder, profitFinder]) {
        _expectNoLocalTransform(
          tester,
          finder,
          boundaryKeyPrefix: 'trade-position-content-',
        );
        _expectNoLocalFittedBox(
          tester,
          finder,
          boundaryKeyPrefix: 'trade-position-content-',
        );
      }
    },
  );

  testWidgets('Empty Trade header keeps the locked profit role for USD', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...videoReferenceOverrides,
          demoPositionsProvider.overrideWithValue(const []),
          demoPendingOrdersProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const TradeScreen(),
        ),
      ),
    );
    await tester.pump();

    final profit = tester.widget<Text>(
      find.byKey(const Key('trade-header-profit')),
    );
    final currency = tester.widget<Text>(
      find.byKey(const Key('trade-header-currency')),
    );
    expect(profit.data, isEmpty);
    expect(currency.data, 'USD');
    _expectRole(profit.style!, AppTypography.tradeHeaderProfit);
    _expectRole(currency.style!, AppTypography.tradeHeaderProfit);
    expect(profit.style?.color, AppColors.textPrimary);
    expect(currency.style?.color, AppColors.textPrimary);
  });

  testWidgets(
    'Trade reference profile renders locked semantic colors and exact copy',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: videoReferenceOverrides,
          child: MaterialApp(
            theme: withTypographyProfile(
              ThemeData(platform: TargetPlatform.iOS),
              TypographyProfile.reference,
            ),
            home: const TradeScreen(),
          ),
        ),
      );
      await tester.pump();

      for (final label in const <String>[
        'Số dư:',
        'Von:',
        'Tien ky quy:',
        'Ky quy du:',
        'Muc ky quy (%):',
        'Lenh co trang thai',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      final primary = tester.widget<Text>(
        _textWithKeyPrefix('trade-position-primary-').first,
      );
      final spans = (primary.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.first.style?.color, const Color(0xFF000000));
      expect(spans.last.style?.color, const Color(0xFF007AFF));
      expect(
        tester
            .widget<Text>(_textWithKeyPrefix('trade-position-secondary-').first)
            .style
            ?.color,
        AppColors.tradePositionSecondaryText,
      );
      expect(
        tester
            .widget<Text>(_textWithKeyPrefix('trade-position-profit-').first)
            .style
            ?.color,
        AppColors.tradeNegative,
      );
    },
  );

  testWidgets(
    'History keeps all four reference states on semantic winner roles',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: videoReferenceOverrides,
          child: MaterialApp(
            theme: withTypographyProfile(
              ThemeData(platform: TargetPlatform.iOS),
              TypographyProfile.reference,
            ),
            home: const HistoryScreen(),
          ),
        ),
      );
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump();
      }

      for (var index = 0; index < 3; index++) {
        final segmentFinder = find.byKey(
          ValueKey('history-segment-label-$index'),
        );
        final segment = tester.widget<Text>(segmentFinder);
        expect(
          segment.data,
          const ['Lenh co trang thai', 'Cac lenh', 'Cac giao dich'][index],
        );
        _expectResolvedHistoryRole(
          tester,
          segmentFinder,
          actual: segment.style!,
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
        _expectNoLocalTransform(
          tester,
          segmentFinder,
          boundaryKeyPrefix: 'history-tab-$index',
        );
        _expectNoLocalFittedBox(
          tester,
          segmentFinder,
          boundaryKeyPrefix: 'history-tab-$index',
        );
      }

      _expectHistoryRowRoles(
        tester,
        state: 'positions',
        boundaryKeyPrefix: 'history-position-',
        variant: TypographyVariantId.historyPositions,
      );

      final positionsSummaryLabelFinder = find.byKey(
        const ValueKey('history-summary-label-Tien nap'),
      );
      final positionsSummaryValueFinder = find.byKey(
        const ValueKey('history-summary-value-Tien nap'),
      );
      final positionsSummaryLabel = tester.widget<Text>(
        positionsSummaryLabelFinder,
      );
      expect(positionsSummaryLabel.data, 'Tien nap');
      _expectResolvedHistoryRole(
        tester,
        positionsSummaryLabelFinder,
        actual: positionsSummaryLabel.style!,
        role: ReferenceTextRole.historySummary,
        colorRole: ReferenceTextColorRole.primary,
        variant: TypographyVariantId.historyBalance,
      );
      _expectResolvedHistoryRole(
        tester,
        positionsSummaryValueFinder,
        actual: tester.widget<Text>(positionsSummaryValueFinder).style!,
        role: ReferenceTextRole.historySummaryValue,
        colorRole: ReferenceTextColorRole.primary,
        variant: TypographyVariantId.historyBalance,
      );
      _expectHistoryAccountSummaryKeepsSizeAndTradeInk(tester);

      await tester.tap(find.byKey(const ValueKey('history-tab-1')));
      await tester.pump();
      _expectHistoryRowRoles(
        tester,
        state: 'orders',
        boundaryKeyPrefix: 'history-order-',
        variant: TypographyVariantId.historyOrders,
      );

      final ordersList = tester.widget<ListView>(
        find.byKey(const PageStorageKey('history-orders-list')),
      );
      ordersList.controller!.jumpTo(
        ordersList.controller!.position.maxScrollExtent,
      );
      await tester.pump();
      final summaryLabel = tester.widget<Text>(
        find.byKey(const ValueKey('history-summary-label-Tong cong')),
      );
      final summaryValue = tester.widget<Text>(
        find.byKey(const ValueKey('history-summary-value-Tong cong')),
      );
      expect(summaryLabel.data, 'Tong cong');
      expect(find.text('Bi huy'), findsOneWidget);
      expect(
        summaryLabel.style?.fontFamily,
        AppTypography.referencePlainFamily,
      );
      expect(summaryLabel.style?.fontSize, 14.5);
      expect(
        summaryValue.style?.fontFamily,
        AppTypography.referencePlainFamily,
      );
      expect(summaryValue.style?.fontSize, 14.5);
      _expectResolvedHistoryRole(
        tester,
        find.byKey(const ValueKey('history-summary-label-Tong cong')),
        actual: summaryLabel.style!,
        role: ReferenceTextRole.historyOrderSummaryTotal,
        colorRole: ReferenceTextColorRole.primary,
        variant: TypographyVariantId.historyOrders,
      );
      _expectResolvedHistoryRole(
        tester,
        find.byKey(const ValueKey('history-summary-value-Tong cong')),
        actual: summaryValue.style!,
        role: ReferenceTextRole.historySummaryValue,
        colorRole: ReferenceTextColorRole.primary,
        variant: TypographyVariantId.historyOrders,
      );
      final summaryRowRect = tester.getRect(
        find.byKey(const ValueKey('history-summary-Tong cong')),
      );
      final summaryValueRect = tester.getRect(
        find.byKey(const ValueKey('history-summary-value-Tong cong')),
      );
      expect(
        summaryValueRect.right,
        closeTo(summaryRowRect.right, .1),
        reason: 'History summary values must stay in the right-aligned slot.',
      );
      _expectNoLocalTransform(
        tester,
        find.byKey(const ValueKey('history-summary-label-Tong cong')),
        boundaryKeyPrefix: 'history-summary-Tong cong',
      );
      for (final finder in <Finder>[
        find.byKey(const ValueKey('history-summary-label-Tong cong')),
        find.byKey(const ValueKey('history-summary-value-Tong cong')),
      ]) {
        _expectNoLocalFittedBox(
          tester,
          finder,
          boundaryKeyPrefix: 'history-summary-Tong cong',
        );
      }

      await tester.tap(find.byKey(const ValueKey('history-tab-2')));
      await tester.pump();
      _expectHistoryRowRoles(
        tester,
        state: 'deals',
        boundaryKeyPrefix: 'history-deal-',
        variant: TypographyVariantId.historyDeals,
      );

      final dealsList = tester.widget<ListView>(
        find.byKey(const PageStorageKey('history-deals-list')),
      );
      dealsList.controller!.jumpTo(
        dealsList.controller!.position.maxScrollExtent,
      );
      await tester.pump();
      for (final entry in const <(String, String)>[
        ('Tien nap', 'Tien nap'),
        ('Loi nhuan', 'Loi nhuan'),
        ('Phi qua dem', 'Phi qua dem'),
        ('Hoa hong', 'Hoa hong'),
      ]) {
        final labelFinder = find.byKey(
          ValueKey('history-summary-label-${entry.$1}'),
        );
        expect(tester.widget<Text>(labelFinder).data, entry.$2);
        _expectResolvedHistoryRole(
          tester,
          labelFinder,
          actual: tester.widget<Text>(labelFinder).style!,
          role: ReferenceTextRole.historySummary,
          colorRole: ReferenceTextColorRole.primary,
          variant: TypographyVariantId.historyDeals,
        );
      }
      _expectHistoryAccountSummaryKeepsSizeAndTradeInk(tester);
    },
  );
}

void _expectHistoryAccountSummaryKeepsSizeAndTradeInk(WidgetTester tester) {
  const expectedWeightVariation = <FontVariation>[FontVariation('wght', 600)];
  for (final keyId in const <String>[
    'Tien nap',
    'Loi nhuan',
    'Phi qua dem',
    'Hoa hong',
    'Số dư',
  ]) {
    final label = tester.widget<Text>(
      find.byKey(ValueKey('history-summary-label-$keyId')),
    );
    expect(
      label.style?.fontFamily,
      AppTypography.referenceCondensedVariableFamily,
      reason: '$keyId label uses the intermediate-weight condensed face.',
    );
    expect(label.style?.fontSize, 15, reason: '$keyId label size');
    expect(label.style?.fontWeight, FontWeight.w600, reason: '$keyId label');
    expect(
      label.style?.fontVariations,
      expectedWeightVariation,
      reason: '$keyId label renders a real intermediate weight.',
    );
    expect(label.style?.letterSpacing, 0, reason: '$keyId label tracking');
    expect(label.style?.height, 1, reason: '$keyId label height');
    expect(label.style?.color, const Color(0xFF000000), reason: '$keyId label');
  }

  for (final keyId in const <String>[
    'Tien nap',
    'Phi qua dem',
    'Hoa hong',
    'Số dư',
  ]) {
    final value = tester.widget<Text>(
      find.byKey(ValueKey('history-summary-value-$keyId')),
    );
    expect(
      value.style?.fontFamily,
      AppTypography.referenceCondensedVariableFamily,
      reason: '$keyId value uses the intermediate-weight condensed face.',
    );
    expect(value.style?.fontSize, 15, reason: '$keyId value size');
    expect(value.style?.fontWeight, FontWeight.w600, reason: '$keyId value');
    expect(
      value.style?.fontVariations,
      expectedWeightVariation,
      reason: '$keyId value renders a real intermediate weight.',
    );
    expect(value.style?.letterSpacing, 0, reason: '$keyId value tracking');
    expect(value.style?.height, 1, reason: '$keyId value height');
    expect(value.style?.color, const Color(0xFF000000), reason: '$keyId value');
  }
}

void _expectHistoryRowRoles(
  WidgetTester tester, {
  required String state,
  required String boundaryKeyPrefix,
  required TypographyVariantId variant,
}) {
  final primaryFinder = _textWithKeyPrefix('history-$state-primary-').first;
  final secondaryFinder = _textWithKeyPrefix('history-$state-secondary-').first;
  final trailingSecondaryFinder = _textWithKeyPrefix(
    'history-$state-trailing-secondary-',
  ).first;
  final actionFinder = _textWithKeyPrefix('history-$state-action-').first;
  final trailingPrimaryCandidates = _textWithKeyPrefix(
    'history-$state-trailing-primary-',
  );
  final primary = tester.widget<Text>(primaryFinder);
  final symbolSpan =
      (primary.textSpan! as TextSpan).children!.first as TextSpan;
  final action = tester.widget<Text>(actionFinder);

  _expectResolvedHistoryRole(
    tester,
    primaryFinder,
    actual: primary.style!.merge(symbolSpan.style),
    role: ReferenceTextRole.historyPrimary,
    colorRole: ReferenceTextColorRole.primary,
    variant: variant,
  );
  expect(
    primary.style!.merge(symbolSpan.style).fontWeight,
    FontWeight.w700,
    reason: 'History symbols match the bold XAUUSD label in Prices.',
  );
  _expectResolvedHistoryRole(
    tester,
    actionFinder,
    actual: action.style!,
    role: ReferenceTextRole.historyAction,
    colorRole: action.data!.contains('sell')
        ? ReferenceTextColorRole.negative
        : ReferenceTextColorRole.blueAction,
    variant: variant,
  );
  if (trailingPrimaryCandidates.evaluate().isNotEmpty) {
    final trailingPrimaryFinder = trailingPrimaryCandidates.first;
    final trailingPrimary = tester.widget<Text>(trailingPrimaryFinder);
    _expectResolvedHistoryRole(
      tester,
      trailingPrimaryFinder,
      actual: trailingPrimary.style!,
      role: ReferenceTextRole.historyTrailingPrimary,
      colorRole: state == 'orders'
          ? ReferenceTextColorRole.historyStatus
          : trailingPrimary.data!.startsWith('-')
          ? ReferenceTextColorRole.negative
          : ReferenceTextColorRole.positive,
      variant: variant,
    );
  }
  _expectResolvedHistoryRole(
    tester,
    secondaryFinder,
    actual: tester.widget<Text>(secondaryFinder).style!,
    role: state == 'positions'
        ? ReferenceTextRole.historyPriceRange
        : ReferenceTextRole.historySecondary,
    colorRole: ReferenceTextColorRole.secondary,
    variant: variant,
  );
  _expectResolvedHistoryRole(
    tester,
    trailingSecondaryFinder,
    actual: tester.widget<Text>(trailingSecondaryFinder).style!,
    role: ReferenceTextRole.historyTrailingSecondary,
    colorRole: ReferenceTextColorRole.secondary,
    variant: variant,
  );

  for (final finder in [
    primaryFinder,
    actionFinder,
    secondaryFinder,
    trailingSecondaryFinder,
  ]) {
    _expectNoLocalTransform(
      tester,
      finder,
      boundaryKeyPrefix: boundaryKeyPrefix,
    );
    _expectNoLocalFittedBox(
      tester,
      finder,
      boundaryKeyPrefix: boundaryKeyPrefix,
    );
  }
}

void _expectResolvedHistoryRole(
  WidgetTester tester,
  Finder finder, {
  required TextStyle actual,
  required ReferenceTextRole role,
  required ReferenceTextColorRole colorRole,
  required TypographyVariantId variant,
}) {
  final expected = AppTypography.forRole(
    tester.element(finder),
    role,
    colorRole: colorRole,
    variant: variant,
  );
  _expectRole(actual, expected);
  expect(actual.color, expected.color);
}

Finder _textWithKeyPrefix(String prefix) => find.byWidgetPredicate((widget) {
  if (widget is! Text) return false;
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
});

void _expectRole(TextStyle actual, TextStyle expected) {
  expect(actual.fontFamily, expected.fontFamily);
  expect(actual.fontSize, expected.fontSize);
  expect(actual.fontWeight, expected.fontWeight);
  expect(actual.height, expected.height);
  expect(actual.letterSpacing, expected.letterSpacing);
  expect(actual.fontFeatures, expected.fontFeatures);
  expect(actual.fontVariations, expected.fontVariations);
  expect(
    actual.fontVariations?.where((variation) => variation.axis == 'wdth') ??
        const <FontVariation>[],
    isEmpty,
  );
}

void _expectStaticToken(
  TextStyle actual, {
  required String family,
  required double size,
  required FontWeight weight,
  required double tracking,
  required double height,
  bool tabularFigures = false,
}) {
  expect(actual.fontFamily, family);
  expect(actual.fontSize, size);
  expect(actual.fontWeight, weight);
  expect(actual.letterSpacing, tracking);
  expect(actual.height, height);
  expect(
    actual.fontFeatures,
    tabularFigures ? const [FontFeature.tabularFigures()] : isNull,
  );
  expect(actual.fontVariations, isNull);
}

void _expectNoLocalTransform(
  WidgetTester tester,
  Finder target, {
  required String boundaryKeyPrefix,
}) {
  final targetElement = tester.element(target);
  final transforms = <Transform>[];
  var foundBoundary = false;
  targetElement.visitAncestorElements((ancestor) {
    final key = ancestor.widget.key;
    if (key is ValueKey<String> && key.value.startsWith(boundaryKeyPrefix)) {
      foundBoundary = true;
      return false;
    }
    if (ancestor.widget is Transform) {
      transforms.add(ancestor.widget as Transform);
    }
    return true;
  });
  expect(foundBoundary, isTrue);
  expect(transforms, isEmpty);
}

void _expectNoLocalFittedBox(
  WidgetTester tester,
  Finder target, {
  required String boundaryKeyPrefix,
}) {
  final targetElement = tester.element(target);
  final fittedBoxes = <FittedBox>[];
  var foundBoundary = false;
  targetElement.visitAncestorElements((ancestor) {
    final key = ancestor.widget.key;
    if (key is ValueKey<String> && key.value.startsWith(boundaryKeyPrefix)) {
      foundBoundary = true;
      return false;
    }
    if (ancestor.widget is FittedBox) {
      fittedBoxes.add(ancestor.widget as FittedBox);
    }
    return true;
  });
  expect(foundBoundary, isTrue);
  expect(
    fittedBoxes,
    isEmpty,
    reason: 'Canonical metric text must preserve its locked point size.',
  );
}
