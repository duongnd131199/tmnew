import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_shadows.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';

void main() {
  test('covered tabs use deterministic measured ink and font roles', () {
    expect(AppColors.primary, const Color(0xFF007AFF));
    expect(AppColors.negative, const Color(0xFFE42D30));
    expect(AppColors.textPrimary, const Color(0xFF000000));
    expect(AppColors.textSecondary, const Color(0xFF3C3C43));
    expect(AppColors.historyOrderStatus, const Color(0xFF294675));
    expect(AppColors.historySegmentSelected, const Color(0xFFEDEDED));
    expect(AppTypography.plainFamily, 'Mt5Roboto');
    expect(AppTypography.condensedFamily, 'Mt5RobotoCondensed');
    expect(AppTypography.tabPlainFamily, 'Mt5RobotoVariable');
    expect(AppTypography.tabCondensedFamily, 'Mt5RobotoCondensedVariable');
    expect(AppTypography.navigationLabel.fontSize, 9.5);
    expect(AppTypography.navigationLabel.height, 1);
    expect(AppTypography.quoteSymbol.fontSize, 16.5);
    expect(AppTypography.quoteSymbol.fontWeight, FontWeight.w500);
    expect(AppTypography.quoteSymbol.letterSpacing, -1.15);
    expect(AppTypography.quoteMeta.fontSize, 13.2);
    expect(AppTypography.quoteMeta.letterSpacing, .2);
    expect(AppTypography.quoteTimeMeta.letterSpacing, .05);
    expect(AppTypography.quoteRangeMeta.letterSpacing, .55);
    expect(AppTypography.quoteBtcHighMeta.letterSpacing, -.1);
    expect(AppTypography.quotePriceMajor.fontSize, 16.5);
    expect(AppTypography.quotePriceMajor.letterSpacing, .35);
    expect(AppTypography.quotePriceMinor.fontSize, 26);
    expect(AppTypography.quotePriceMinor.letterSpacing, .35);
    expect(AppTypography.chartTicketPriceMajor.fontSize, 16);
    expect(AppTypography.chartTicketPriceMajor.letterSpacing, -.4);
    expect(AppTypography.chartTicketPriceMinor.fontSize, 24);
    expect(AppTypography.chartTicketPriceMinor.letterSpacing, -.4);
    expect(AppTypography.tradeHeaderProfit.fontSize, 20);
    expect(AppTypography.tradeHeaderProfit.letterSpacing, 0);
    expect(AppTypography.tradeMetric.fontSize, 16);
    expect(AppTypography.tradeMetricValue.letterSpacing, .5);
    expect(AppTypography.tradePositionPrimary.fontSize, 15.3);
    expect(AppTypography.tradePositionSecondary.fontSize, 16);
    expect(AppTypography.tradePositionSecondary.letterSpacing, .98);
    expect(AppTypography.tradePositionSecondary.color, const Color(0xFF201F21));
    expect(
      AppTypography.tradePositionSecondary.fontVariations,
      const <FontVariation>[FontVariation('wght', 250)],
    );
    expect(AppTypography.tradePositionProfit.fontSize, 21);
    expect(AppTypography.tradePositionProfit.letterSpacing, .17);
    expect(AppTypography.historyPrimary.fontSize, 16);
    expect(AppTypography.historyDealsSegment.fontSize, 14);
    expect(AppTypography.historyDealsSegment.letterSpacing, .235);
    expect(AppTypography.historyAction.letterSpacing, -.1);
    expect(AppTypography.historyAction.fontVariations, const <FontVariation>[
      FontVariation('wght', 326),
    ]);
    expect(AppTypography.historyTrailingPrimary.letterSpacing, -.2);
    expect(
      AppTypography.historyTrailingPrimary.fontVariations,
      const <FontVariation>[FontVariation('wght', 370)],
    );
    expect(AppTypography.historySecondary.fontSize, 14);
    expect(AppTypography.historySecondary.letterSpacing, .22);
    expect(AppTypography.historyPriceRange.letterSpacing, .16);
    expect(
      AppTypography.historyPriceRange.fontVariations,
      const <FontVariation>[FontVariation('wght', 270)],
    );
    expect(AppTypography.historyTrailingSecondary.letterSpacing, .4);
    expect(AppTypography.historySummary.fontSize, 14.5);
    expect(AppTypography.historySummary.fontWeight, FontWeight.w400);
    expect(AppTypography.historySummary.fontVariations, const <FontVariation>[
      FontVariation('wght', 315),
    ]);
    expect(AppTypography.historySummaryValue.fontWeight, FontWeight.w400);
    expect(
      AppTypography.historySummaryValue.fontVariations,
      const <FontVariation>[FontVariation('wght', 420)],
    );
    expect(AppTypography.historySummaryValue.letterSpacing, .63);
    expect(AppTypography.historyOrderSummaryTotal.letterSpacing, .22);
    expect(
      AppTypography.historyOrderSummaryTotal.fontVariations,
      const <FontVariation>[FontVariation('wght', 340)],
    );
  });

  test('canonical tab geometry remains explicit', () {
    expect(TabReferenceMetrics.viewportWidth, closeTo(393.3333333333, .0001));
    expect(TabReferenceMetrics.bottomNavigationLeftInset, 18.6666666667);
    expect(TabReferenceMetrics.bottomNavigationCapsuleWidth, 356.0);
    expect(
      TabReferenceMetrics.bottomNavigationContentHorizontalInset,
      7.3333333333,
    );
    expect(TabReferenceMetrics.quoteRowHeight, 66.6666666667);
    expect(TabReferenceMetrics.quoteBtcMetaTop, 46);
    expect(TabReferenceMetrics.quoteBtcPriceScaleY, 1.07);
    expect(TabReferenceMetrics.quoteBtcPriceOffsetY, -1.3333333333);
    expect(TabReferenceMetrics.quoteBtcHighOffsetX, 0);
    expect(TabReferenceMetrics.quoteCornerWidth, 8);
    expect(TabReferenceMetrics.quoteCornerHeight, 9.6666666667);
    expect(TabReferenceMetrics.quoteCornerOffsetY, .6666666667);
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
    expect(TabReferenceMetrics.historySecondaryTop, 26);
    expect(TabReferenceMetrics.historyPriceRangeTop, 26.6666666667);
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
    expect(AppShadows.navigation, const <BoxShadow>[
      BoxShadow(color: Color(0x0D000000), blurRadius: 30, offset: Offset.zero),
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
        weight: 300.0,
      ),
    );
    expect(
      TabReferenceMetrics.tradeMetricRasterAdjustment(TargetPlatform.iOS),
      (
        offsetX: -.6666666667,
        offsetY: 0.0,
        scaleX: 1.032,
        scaleY: 1.08,
        weight: 335.0,
      ),
    );
  });
}
