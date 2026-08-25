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
    expect(AppTypography.navigationLabel.fontSize, 9.5);
    expect(AppTypography.navigationLabel.height, 1);
    expect(AppTypography.quoteSymbol.fontSize, 16.5);
    expect(AppTypography.quoteSymbol.fontWeight, FontWeight.w700);
    expect(AppTypography.quoteSymbol.letterSpacing, -1.45);
    expect(AppTypography.quoteMeta.fontSize, 14);
    expect(AppTypography.quotePriceMajor.fontSize, 15);
    expect(AppTypography.quotePriceMinor.fontSize, 24);
    expect(AppTypography.tradeMetric.fontSize, 16);
    expect(AppTypography.tradePositionPrimary.fontSize, 15.3);
    expect(AppTypography.tradePositionSecondary.fontSize, 15);
    expect(AppTypography.tradePositionProfit.fontSize, 20.5);
    expect(AppTypography.historyPrimary.fontSize, 16);
    expect(AppTypography.historySecondary.fontSize, 14);
    expect(AppTypography.historySummary.fontSize, 14.5);
  });

  test('canonical tab geometry remains explicit', () {
    expect(TabReferenceMetrics.viewportWidth, closeTo(393.3333333333, .0001));
    expect(TabReferenceMetrics.quoteRowHeight, 69.3333333333);
    expect(TabReferenceMetrics.tradeMetricRowHeight, 22);
    expect(TabReferenceMetrics.tradePositionRowHeight, 53.3333333333);
    expect(TabReferenceMetrics.historyRowHeight, 52);
    expect(TabReferenceMetrics.historyPrimaryTop, 4);
    expect(TabReferenceMetrics.historySecondaryTop, 26);
  });
}
