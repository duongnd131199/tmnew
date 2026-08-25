import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';

void main() {
  test('covered tabs use deterministic measured ink and font roles', () {
    expect(AppColors.primary, const Color(0xFF007FFF));
    expect(AppColors.negative, const Color(0xFFE42D30));
    expect(AppColors.textPrimary, const Color(0xFF111111));
    expect(AppColors.textSecondary, const Color(0xFF5C5C60));
    expect(AppTypography.plainFamily, 'Mt5Roboto');
    expect(AppTypography.condensedFamily, 'Mt5RobotoCondensed');
    expect(AppTypography.navigationLabel.fontSize, 10.8);
    expect(AppTypography.navigationLabel.height, 1);
    expect(AppTypography.quoteSymbol.fontSize, 18);
    expect(AppTypography.quoteSymbol.fontWeight, FontWeight.w700);
    expect(AppTypography.quoteSymbol.letterSpacing, -.15);
    expect(AppTypography.quoteMeta.fontSize, 17);
    expect(AppTypography.quotePriceMajor.fontSize, 18.5);
    expect(AppTypography.quotePriceMinor.fontSize, 29);
    expect(AppTypography.tradeMetric.fontSize, 18.5);
    expect(AppTypography.tradePositionPrimary.fontSize, 17.3);
    expect(AppTypography.tradePositionSecondary.fontSize, 17.2);
    expect(AppTypography.tradePositionProfit.fontSize, 23.5);
    expect(AppTypography.historyPrimary.fontSize, 16);
    expect(AppTypography.historySecondary.fontSize, 14);
    expect(AppTypography.historySummary.fontSize, 15);
  });

  test('canonical tab geometry remains explicit', () {
    expect(TabReferenceMetrics.viewportWidth, closeTo(393.3333333333, .0001));
    expect(TabReferenceMetrics.quoteRowHeight, 78);
    expect(TabReferenceMetrics.tradeMetricRowHeight, 25);
    expect(TabReferenceMetrics.tradePositionRowHeight, 61.75);
    expect(TabReferenceMetrics.historyRowHeight, 52);
    expect(TabReferenceMetrics.historyPrimaryTop, 4);
    expect(TabReferenceMetrics.historySecondaryTop, 26);
  });
}
