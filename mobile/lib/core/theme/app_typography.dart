import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const plainFamily = 'Mt5Roboto';
  static const condensedFamily = 'Mt5RobotoCondensed';

  static const _base = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: condensedFamily,
  );

  static const caption = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
  );
  static const bodySmall = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 12.5,
  );
  static const bodyMedium = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 14,
  );
  static const bodyLarge = TextStyle(fontFamily: condensedFamily, fontSize: 16);
  static const titleSmall = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );
  static const titleMedium = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const referenceServerName = TextStyle(
    fontFamily: plainFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const titleLarge = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 26,
    fontWeight: FontWeight.w600,
  );
  static const numberSmall = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numberMedium = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numberLarge = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const toolbarTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: plainFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w500,
    letterSpacing: -.5,
    height: 1,
  );
  static const toolbarControl = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: plainFamily,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    height: 1,
  );
  static const navigationLabel = TextStyle(
    fontFamily: plainFamily,
    fontSize: 9.5,
    fontWeight: FontWeight.w400,
    height: 1,
  );
  static const navigationLabelSelected = TextStyle(
    fontFamily: plainFamily,
    fontSize: 9.5,
    fontWeight: FontWeight.w500,
    height: 1,
  );
  static const quoteChange = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 14,
    letterSpacing: .1,
    height: 1,
  );
  static const quoteSymbol = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: condensedFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.45,
    height: 1,
  );
  static const quoteMeta = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 13.2,
    letterSpacing: .2,
    height: 1,
  );
  static const quoteTimeMeta = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 13.2,
    letterSpacing: -.15,
    height: 1,
  );
  static const quoteRangeMeta = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 13.2,
    letterSpacing: .55,
    height: 1,
  );
  static const quotePriceMajor = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w500,
    letterSpacing: .2,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const quoteBtcHighMeta = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 13.2,
    letterSpacing: .15,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const quotePriceMinor = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: .2,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const chartToolbar = TextStyle(
    fontFamily: plainFamily,
    fontSize: 14.3,
    fontWeight: FontWeight.w500,
    letterSpacing: -1.2,
    height: 1,
  );
  static const chartTicketLabel = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 8.7,
    height: 1,
  );
  static const chartTicketPriceMajor = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -.8,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const chartTicketPriceMinor = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -.8,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const chartAnnotation = TextStyle(
    fontFamily: plainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1,
  );
  static const chartAxis = TextStyle(
    fontFamily: plainFamily,
    fontSize: 12.5,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const chartTimeAxis = TextStyle(
    fontFamily: plainFamily,
    fontSize: 11.5,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tradeHeaderProfit = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: -.3,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tradeMetric = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: condensedFamily,
    fontSize: 16,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tradeMetricValue = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: condensedFamily,
    fontSize: 16,
    letterSpacing: .5,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tradeSection = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: condensedFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1,
  );
  static const tradePositionPrimary = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 15.3,
    letterSpacing: -.6,
    height: 1,
  );
  static const tradePositionSecondary = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 16,
    letterSpacing: .78,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tradePositionProfit = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 21,
    fontWeight: FontWeight.w500,
    letterSpacing: -.1,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historySegment = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: plainFamily,
    fontSize: 14.5,
    letterSpacing: -.15,
    height: 1,
  );
  static const historyDealsSegment = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: plainFamily,
    fontSize: 14,
    letterSpacing: .15,
    height: 1,
  );
  static const historyPrimary = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 16,
    letterSpacing: -1,
    height: 1,
  );
  static const historyAction = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 16,
    letterSpacing: -.1,
    height: 1,
  );
  static const historyTrailingPrimary = TextStyle(
    fontFamily: condensedFamily,
    fontSize: 16,
    letterSpacing: -.2,
    height: 1,
  );
  static const historySecondary = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 14,
    letterSpacing: .1,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historyPriceRange = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 14,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historyTrailingSecondary = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 14,
    letterSpacing: .2,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historySummary = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: plainFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    letterSpacing: .05,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historyOrderSummaryTotal = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: plainFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    letterSpacing: .22,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historySummaryValue = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: plainFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    letterSpacing: .55,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextTheme get textTheme =>
      const TextTheme(
        bodySmall: bodySmall,
        bodyMedium: bodyMedium,
        bodyLarge: bodyLarge,
        titleSmall: titleSmall,
        titleMedium: titleMedium,
        titleLarge: titleLarge,
        labelSmall: caption,
        headlineSmall: numberLarge,
      ).apply(
        bodyColor: _base.color,
        displayColor: _base.color,
        fontFamily: _base.fontFamily,
      );
}
