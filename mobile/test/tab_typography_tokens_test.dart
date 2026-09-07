import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_shadows.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';

void main() {
  test('legacy general tokens retain their existing width profile', () {
    final legacyStyles = <TextStyle>[
      AppTypography.tabDefault,
      AppTypography.caption,
      AppTypography.bodySmall,
      AppTypography.bodyMedium,
      AppTypography.bodyLarge,
      AppTypography.titleSmall,
      AppTypography.titleMedium,
      AppTypography.titleLarge,
      AppTypography.numberSmall,
      AppTypography.numberMedium,
      AppTypography.numberLarge,
      AppTypography.toolbarTitle,
      AppTypography.toolbarControl,
    ];

    for (final style in legacyStyles) {
      expect(
        _fontAxis(style, 'wdth'),
        90,
        reason: 'Unmigrated general tokens keep their legacy rendering.',
      );
    }
  });

  test('covered tabs use deterministic measured ink and font roles', () {
    expect(AppColors.primary, const Color(0xFF007AFF));
    expect(AppColors.negative, const Color(0xFFE42D30));
    expect(AppColors.textPrimary, const Color(0xFF000000));
    expect(AppColors.textSecondary, const Color(0xFF3C3C43));
    expect(AppColors.historyOrderStatus, const Color(0xFF294476));
    expect(AppColors.historyPositiveText, const Color(0xFF006FE6));
    expect(AppColors.chartPlotTitleBlue, const Color(0xFF3D87EA));
    expect(AppColors.historySegmentSelected, const Color(0xFFEDEDED));
    expect(AppColors.pricesSecondary, const Color(0xFF4D4D50));
    expect(AppColors.pricesSpread, const Color(0xFFADAFB0));
    expect(AppColors.pricesNegativeText, const Color(0xFFE43C2F));
    expect(AppTypography.plainFamily, 'Mt5Roboto');
    expect(AppTypography.condensedFamily, 'Mt5RobotoCondensed');
    expect(AppTypography.tabPlainFamily, 'Mt5RobotoVariable');
    expect(AppTypography.tabCondensedFamily, 'Mt5RobotoCondensedVariable');
    expect(AppTypography.referencePlainFamily, 'Mt5ReferenceRoboto');
    expect(
      AppTypography.referenceCondensedFamily,
      'Mt5ReferenceRobotoCondensed',
    );
    expect(
      AppTypography.referenceCondensedVariableFamily,
      'Mt5ReferenceRobotoCondensedVariable',
    );
    expect(AppTypography.navigationLabel.fontSize, 9.5);
    expect(AppTypography.navigationLabel.height, 1);
    expect(AppTypography.pricesToolbarTitle.fontSize, 16);
    expect(AppTypography.pricesToolbarTitle.fontWeight, FontWeight.w700);
    expect(
      AppTypography.pricesToolbarTitle.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(AppTypography.pricesToolbarTitle.fontVariations, isNull);
    expect(AppTypography.quoteChange.fontSize, 14);
    expect(AppTypography.quoteChange.fontWeight, FontWeight.w400);
    expect(
      AppTypography.quoteChange.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(AppTypography.quoteChange.fontVariations, isNull);
    expect(AppTypography.quoteSymbol.fontSize, 16);
    expect(AppTypography.quoteSymbol.fontWeight, FontWeight.w700);
    expect(AppTypography.quoteSymbol.letterSpacing, -.5);
    expect(AppTypography.quoteSymbol.fontVariations, isNull);
    expect(AppTypography.quoteMeta.fontSize, 14);
    expect(AppTypography.quoteMeta.letterSpacing, 0);
    expect(
      AppTypography.quoteMeta.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(AppTypography.quoteTimeMeta.fontWeight, FontWeight.w400);
    expect(
      AppTypography.quoteTimeMeta.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(AppTypography.quoteTimeMeta.fontVariations, isNull);
    expect(
      AppTypography.quoteSpreadMeta.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(AppTypography.quoteRangeMeta.letterSpacing, 0);
    expect(
      AppTypography.quoteRangeValue.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(AppTypography.quotePriceMajor.fontSize, 16);
    expect(AppTypography.quotePriceMajor.letterSpacing, .85);
    expect(AppTypography.quotePriceMinor.fontSize, 27);
    expect(AppTypography.quotePriceMinor.letterSpacing, .85);
    expect(AppTypography.quotePricePipette.fontSize, 14.5);
    expect(AppTypography.quotePricePipette.fontWeight, FontWeight.w700);
    expect(AppTypography.quotePricePipette.fontVariations, isNull);
    expect(AppTypography.chartTicketPriceMajor.fontSize, 16);
    expect(AppTypography.chartTicketLabel.fontSize, 10);
    expect(AppTypography.chartTicketLabel.fontWeight, FontWeight.w700);
    expect(AppTypography.chartTicketLabel.fontVariations, isNull);
    expect(
      AppTypography.chartTicketLabel.fontSize,
      lessThan(AppTypography.chartTicketPriceMajor.fontSize!),
    );
    expect(AppTypography.chartTicketPriceMajor.letterSpacing, -.4);
    expect(AppTypography.chartTicketPriceMajor.fontWeight, FontWeight.w700);
    expect(AppTypography.chartTicketPriceMajor.fontVariations, isNull);
    expect(AppTypography.chartTicketPriceMinor.fontSize, 24);
    expect(AppTypography.chartTicketPriceMinor.letterSpacing, -.4);
    expect(AppTypography.chartTicketPriceMinor.fontWeight, FontWeight.w700);
    expect(AppTypography.chartTicketPriceMinor.fontVariations, isNull);
    expect(AppTypography.chartTimeframe.fontSize, 14.3);
    expect(AppTypography.chartTimeframe.fontWeight, FontWeight.w700);
    expect(
      AppTypography.chartTimeframe.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(AppTypography.chartTimeframe.fontVariations, isNull);
    expect(AppTypography.chartAxis.fontWeight, FontWeight.w400);
    expect(AppTypography.chartAxis.fontVariations, isNull);
    expect(AppTypography.tradeHeaderProfit.fontSize, 20);
    expect(AppTypography.tradeHeaderProfit.letterSpacing, 0);
    expect(AppTypography.tradeMetric.fontSize, 16);
    expect(AppTypography.tradeMetric.fontWeight, FontWeight.w400);
    expect(
      AppTypography.tradeMetric.fontFamily,
      AppTypography.referenceCondensedFamily,
    );
    expect(AppTypography.tradeMetric.fontVariations, isNull);
    expect(AppTypography.tradeMetricValue.letterSpacing, .2);
    expect(AppTypography.tradeMetricValue.fontWeight, FontWeight.w400);
    expect(
      AppTypography.tradeMetricValue.fontFamily,
      AppTypography.referenceCondensedFamily,
    );
    expect(AppTypography.tradeMetricValue.fontVariations, isNull);
    expect(AppTypography.tradePositionPrimary.fontSize, 15.3);
    expect(AppTypography.tradePositionPrimary.fontWeight, FontWeight.w700);
    expect(AppTypography.tradePositionPrimary.letterSpacing, 0);
    expect(AppTypography.tradePositionSecondary.fontSize, 16);
    expect(AppTypography.tradePositionSecondary.letterSpacing, .98);
    expect(
      AppTypography.tradePositionSecondary.color,
      AppColors.tradePositionSecondaryText,
    );
    expect(AppTypography.tradePositionSecondary.fontWeight, FontWeight.w400);
    expect(AppTypography.tradePositionSecondary.fontVariations, isNull);
    expect(AppTypography.tradePositionProfit.fontSize, 21);
    expect(AppTypography.tradePositionProfit.letterSpacing, .17);
    expect(AppTypography.tradePositionProfit.fontWeight, FontWeight.w700);
    expect(AppTypography.tradePositionProfit.fontVariations, isNull);
    expect(AppTypography.tradeHeaderProfit.fontWeight, FontWeight.w700);
    expect(AppTypography.tradeHeaderProfit.fontVariations, isNull);
    expect(AppTypography.historyPrimary.fontSize, 15.3);
    expect(AppTypography.historyPrimary.fontWeight, FontWeight.w700);
    expect(AppTypography.historyPrimary.letterSpacing, 0);
    expect(AppTypography.historyBalancePrimary.fontWeight, FontWeight.w700);
    expect(AppTypography.historySegment.fontSize, 14);
    expect(AppTypography.historySegment.letterSpacing, 0);
    expect(AppTypography.historyDealsSegment.fontSize, 14);
    expect(AppTypography.historyDealsSegment.letterSpacing, 0);
    expect(AppTypography.historyAction.fontSize, 15.3);
    expect(AppTypography.historyAction.fontWeight, FontWeight.w700);
    expect(AppTypography.historyAction.letterSpacing, 0);
    expect(
      AppTypography.historyAction.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(AppTypography.historyAction.fontVariations, isNull);
    expect(AppTypography.historyTrailingPrimary.fontSize, 16);
    expect(AppTypography.historyTrailingPrimary.letterSpacing, -.2);
    expect(AppTypography.historyTrailingPrimary.fontWeight, FontWeight.w700);
    expect(AppTypography.historyTrailingPrimary.fontVariations, isNull);
    expect(AppTypography.historyBalanceTrailingPrimary.fontVariations, isNull);
    expect(
      AppTypography.historyBalanceTrailingPrimary,
      AppTypography.historyTrailingPrimary,
    );
    expect(AppTypography.historySecondary.fontSize, 14);
    expect(AppTypography.historySecondary.letterSpacing, 0);
    expect(AppTypography.historyPriceRange.letterSpacing, 0);
    expect(AppTypography.historyPriceRange.fontVariations, isNull);
    expect(AppTypography.historyBalanceSecondary.letterSpacing, 0);
    expect(AppTypography.historyTrailingSecondary.letterSpacing, 0);
    expect(AppTypography.historyTrailingSecondary.fontSize, 14);
    expect(
      AppTypography.historyTrailingSecondary.fontWeight,
      AppTypography.tradePositionSecondary.fontWeight,
    );
    expect(
      AppTypography.historyTrailingSecondary.fontVariations,
      AppTypography.tradePositionSecondary.fontVariations,
    );
    expect(AppTypography.historySummary.fontSize, 14.5);
    expect(AppTypography.historySummary.fontWeight, FontWeight.w400);
    expect(
      AppTypography.historySummary.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(AppTypography.historySummary.fontVariations, isNull);
    expect(AppTypography.historySummaryValue.fontWeight, FontWeight.w400);
    expect(AppTypography.historySummaryValue.fontVariations, isNull);
    expect(AppTypography.historySummaryValue.letterSpacing, 0);
    expect(AppTypography.historyOrderSummaryTotal.letterSpacing, 0);
    expect(AppTypography.historyOrderSummaryTotal.fontVariations, isNull);
  });

  test('canonical tab geometry remains explicit', () {
    expect(TabReferenceMetrics.viewportWidth, closeTo(393.3333333333, .0001));
    expect(TabReferenceMetrics.bottomNavigationLeftInset, 18.6666666667);
    expect(TabReferenceMetrics.bottomNavigationCapsuleWidth, 356.0);
    expect(
      TabReferenceMetrics.bottomNavigationContentHorizontalInset,
      7.3333333333,
    );
    expect(TabReferenceMetrics.quoteHeaderHeight, closeTo(91.6666666667, .001));
    expect(TabReferenceMetrics.quoteHeaderControlTop, 40);
    expect(TabReferenceMetrics.quoteHeaderTitleTop, 49);
    expect(TabReferenceMetrics.quoteHeaderButtonSize, 44);
    expect(TabReferenceMetrics.quoteHeaderVisualDiameter, 43.3333333333);
    expect(TabReferenceMetrics.quoteRowHeight, 72);
    expect(TabReferenceMetrics.tradeMetricRowHeight, 22);
    expect(TabReferenceMetrics.tradePositionRowHeight, 53.1111111111);
    expect(TabReferenceMetrics.tradePositionSecondaryTop, 22);
    expect(TabReferenceMetrics.tradeScrollbarTopInset, 115.3333333333);
    expect(TabReferenceMetrics.tradeScrollbarBottomInset, 24);
    expect(TabReferenceMetrics.tradeScrollbarThumbExtent, 526.6666666667);
    expect(TabReferenceMetrics.historyRowHeight, 52);
    expect(TabReferenceMetrics.historySelectedSideInset, 3);
    expect(TabReferenceMetrics.historyDealsSelectedRightInset, 1);
    expect(TabReferenceMetrics.historyFirstSelectedLeftOffset, -1.3333333333);
    expect(TabReferenceMetrics.historyFirstSelectedRightInset, 2.6666666667);
    expect(TabReferenceMetrics.historyPrimaryTop, 4);
    expect(TabReferenceMetrics.historyPrimaryScaleY, 1.03);
    expect(TabReferenceMetrics.historyPrimaryOffsetY, -.6666666667);
    expect(TabReferenceMetrics.historySecondaryTop, 26);
    expect(TabReferenceMetrics.historyPriceRangeTop, 26.6666666667);
    expect(TabReferenceMetrics.historyPositionSecondaryScaleY, .88);
    expect(TabReferenceMetrics.historyPositionSecondaryOffsetY, .6666666667);
    expect(TabReferenceMetrics.historyDealSecondaryTop, 27.3333333333);
    expect(TabReferenceMetrics.historyDealSecondaryScaleY, .99);
    expect(TabReferenceMetrics.historyDealSecondaryOffsetY, -.6666666667);
    expect(TabReferenceMetrics.historyActionOffsetY, .6666666667);
    expect(TabReferenceMetrics.historyOrderStatusScaleY, .85);
    expect(TabReferenceMetrics.historyOrderStatusOffsetX, -.6666666667);
    expect(TabReferenceMetrics.historyOrderStatusOffsetY, .6666666667);
    expect(TabReferenceMetrics.historyOrderSummaryTotalOffsetY, -.6666666667);
    expect(TabReferenceMetrics.bottomNavigationSelectionOverhangs(0), (
      left: 3.3333333333,
      right: 4.0,
    ));
    expect(TabReferenceMetrics.bottomNavigationSelectionOverhangs(2), (
      left: 3.3333333333,
      right: 2.6666666667,
    ));
    expect(TabReferenceMetrics.bottomNavigationSelectionOverhangs(3), (
      left: 4.0,
      right: 2.6666666667,
    ));
    expect(AppShadows.circularControl, const <BoxShadow>[
      BoxShadow(color: Color(0x19000000), blurRadius: 30, offset: Offset(0, 4)),
    ]);
    expect(AppShadows.navigation, const <BoxShadow>[
      BoxShadow(
        color: Color(0x0D000000),
        blurRadius: 30,
        spreadRadius: 9.6666666667,
        offset: Offset(0, 4),
      ),
    ]);
  });

  test('Trade metric labels compensate each mobile text rasterizer', () {
    expect(
      TabReferenceMetrics.tradeMetricRasterAdjustment(TargetPlatform.android),
      (
        offsetX: -.6666666667,
        offsetY: -.6666666667,
        scaleX: 1.049,
        scaleY: 1.03,
        weight: 400.0,
      ),
    );
    expect(
      TabReferenceMetrics.tradeMetricRasterAdjustment(TargetPlatform.iOS),
      (
        offsetX: -.6666666667,
        offsetY: 0.0,
        scaleX: 1.032,
        scaleY: 1.08,
        weight: 400.0,
      ),
    );
  });
}

double? _fontAxis(TextStyle style, String axis) {
  for (final variation in style.fontVariations ?? const <FontVariation>[]) {
    if (variation.axis == axis) return variation.value;
  }
  return null;
}
