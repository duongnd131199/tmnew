import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'reference_typography_profile.dart';

abstract final class AppTypography {
  static const plainFamily = 'Mt5Roboto';
  static const condensedFamily = 'Mt5RobotoCondensed';
  static const tabPlainFamily = 'Mt5RobotoVariable';
  static const tabCondensedFamily = 'Mt5RobotoCondensedVariable';
  static const referencePlainFamily = 'Mt5ReferenceRoboto';
  static const referenceCondensedFamily = 'Mt5ReferenceRobotoCondensed';
  static const referenceCondensedVariableFamily =
      'Mt5ReferenceRobotoCondensedVariable';
  static const tabWidth = 90.0;

  static const _width90 = <FontVariation>[FontVariation('wdth', tabWidth)];
  static const _weight400 = <FontVariation>[
    FontVariation('wght', 400),
    FontVariation('wdth', tabWidth),
  ];
  static const _weight500 = <FontVariation>[
    FontVariation('wght', 500),
    FontVariation('wdth', tabWidth),
  ];
  static const _weight600 = <FontVariation>[
    FontVariation('wght', 600),
    FontVariation('wdth', tabWidth),
  ];
  static const _referenceWeight600 = <FontVariation>[
    FontVariation('wght', 600),
  ];
  static const _referenceWeight700 = <FontVariation>[
    FontVariation('wght', 700),
  ];
  static const _iosTabColorWeight = 400.0;
  static const _iosTabEmphasizedColorWeight = 450.0;
  static const _iosQuoteChangeAccentWeight = 500.0;

  static TextStyle platformInk(
    BuildContext context,
    TextStyle style, {
    required double iosWeight,
  }) {
    if (Theme.of(context).platform != TargetPlatform.iOS) return style;
    if (_isLockedReferenceFamily(style.fontFamily)) return style;
    return style.copyWith(
      fontVariations: <FontVariation>[
        FontVariation('wght', iosWeight),
        const FontVariation('wdth', tabWidth),
      ],
    );
  }

  static bool _isLockedReferenceFamily(String? family) =>
      family == referencePlainFamily ||
      family == referenceCondensedFamily ||
      family == referenceCondensedVariableFamily;

  static TextStyle tabColorInk(
    BuildContext context,
    TextStyle style, {
    bool emphasized = false,
  }) => platformInk(
    context,
    style,
    iosWeight: emphasized ? _iosTabEmphasizedColorWeight : _iosTabColorWeight,
  );

  static TextStyle quoteChangeAccentInk(
    BuildContext context,
    TextStyle style,
  ) => platformInk(context, style, iosWeight: _iosQuoteChangeAccentWeight);

  static const _base = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: tabCondensedFamily,
    fontVariations: _width90,
  );

  static const tabDefault = TextStyle(
    fontFamily: tabCondensedFamily,
    fontVariations: _width90,
  );

  static const caption = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: tabCondensedFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    fontVariations: _weight400,
  );
  static const bodySmall = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: tabCondensedFamily,
    fontSize: 12.5,
    fontVariations: _width90,
  );
  static const bodyMedium = TextStyle(
    fontFamily: tabCondensedFamily,
    fontSize: 14,
    fontVariations: _width90,
  );
  static const bodyLarge = TextStyle(
    fontFamily: tabCondensedFamily,
    fontSize: 16,
    fontVariations: _width90,
  );
  static const titleSmall = TextStyle(
    fontFamily: tabCondensedFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontVariations: _weight500,
  );
  static const titleMedium = TextStyle(
    fontFamily: tabCondensedFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    fontVariations: _weight500,
  );
  static const referenceServerName = TextStyle(
    fontFamily: plainFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const dialogTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: plainFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );
  static const dialogSubtitle = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: condensedFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );
  static const dialogAction = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: condensedFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  static const titleLarge = TextStyle(
    fontFamily: tabCondensedFamily,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    fontVariations: _weight600,
  );
  static const numberSmall = TextStyle(
    fontFamily: tabCondensedFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    fontVariations: _weight500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numberMedium = TextStyle(
    fontFamily: tabCondensedFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w500,
    fontVariations: _weight500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numberLarge = TextStyle(
    fontFamily: tabCondensedFamily,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    fontVariations: _weight600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const toolbarTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: tabPlainFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w500,
    fontVariations: _weight500,
    letterSpacing: -.5,
    height: 1,
  );
  static const pricesToolbarTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
  );
  static const toolbarControl = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: tabPlainFamily,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    fontVariations: _weight400,
    height: 1,
  );
  static const navigationLabel = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 9.5,
    fontWeight: FontWeight.w400,
    letterSpacing: .4,
    height: 1,
  );
  static const navigationLabelSelected = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 9.5,
    fontWeight: FontWeight.w400,
    letterSpacing: .4,
    height: 1,
  );
  static const settingsToolbarTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
  );
  static const settingsAccountName = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1,
  );
  static const settingsAccountCompany = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1,
  );
  static const settingsAccountMeta = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1,
  );
  static const settingsAccountMetaMultiline = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const settingsRowTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1,
  );
  static const settingsRowSubtitle = TextStyle(
    color: AppColors.settingsRowSecondary,
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1,
  );
  static const settingsNotificationBadge = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1,
  );
  static const quoteChange = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
  );
  static const quoteSymbol = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referenceCondensedFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -.5,
    height: 1,
  );
  static const quoteMeta = TextStyle(
    color: AppColors.pricesSecondary,
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
  );
  static const quoteTimeMeta = TextStyle(
    color: AppColors.pricesSecondary,
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
  );
  static const quoteSpreadMeta = TextStyle(
    color: AppColors.pricesSecondary,
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
  );
  static const quoteRangeMeta = TextStyle(
    color: AppColors.pricesSecondary,
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
  );
  static const quoteRangeLabel = TextStyle(
    color: AppColors.pricesSecondary,
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
  );
  static const quoteRangeValue = TextStyle(
    color: AppColors.pricesSecondary,
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  // Legacy compatibility token; Prices now uses [quoteRangeValue].
  static const quoteBtcHighMeta = TextStyle(
    color: AppColors.pricesSecondary,
    fontFamily: referenceCondensedFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const quotePriceMajor = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: .85,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const quotePriceMinor = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 27,
    fontWeight: FontWeight.w700,
    letterSpacing: .85,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const quotePriceBtcMajor = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const quotePriceBtcMinor = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 27,
    fontWeight: FontWeight.w700,
    letterSpacing: .85,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const quotePricePipette = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const chartToolbar = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 14.3,
    fontWeight: FontWeight.w400,
    letterSpacing: -1.2,
    height: 1,
  );
  static const chartTimeframe = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 14.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1,
  );
  static const chartDialogTimeframe = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1,
  );
  static const chartTimeframeHint = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 14.3,
    fontWeight: FontWeight.w400,
    letterSpacing: -1.2,
    height: 1.49,
  );
  static const chartOneClickVolume = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const chartTicketLabel = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: .2,
    height: 1,
  );
  static const chartTicketPriceMajor = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -.4,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const chartTicketPriceMinor = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -.4,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const chartAnnotation = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1,
  );
  static const chartAxis = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const chartTimeAxis = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tradeHeaderProfit = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tradeMetric = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referenceCondensedFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: .5,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tradeMetricValue = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referenceCondensedFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: .2,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tradeSection = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referenceCondensedVariableFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    fontVariations: _referenceWeight700,
    letterSpacing: .32,
    height: 1,
  );
  static const tradePositionPrimary = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 15.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
  );
  static const tradePositionSide = TextStyle(
    fontFamily: referencePlainFamily,
    fontWeight: FontWeight.w700,
  );
  static const tradePositionSecondary = TextStyle(
    color: AppColors.tradingSecondaryText,
    fontFamily: referenceCondensedFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: .98,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tradePositionProfit = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 21,
    fontWeight: FontWeight.w700,
    letterSpacing: .17,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historySegment = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
  );
  static const historyDealsSegment = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
  );
  static const historyPrimary = tradePositionPrimary;
  static const historyAction = TextStyle(
    fontFamily: referencePlainFamily,
    fontSize: 15.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
  );
  static const historyTrailingPrimary = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -.2,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historySecondary = TextStyle(
    color: AppColors.tradingSecondaryText,
    fontFamily: referenceCondensedFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historyPriceRange = historySecondary;
  static const historyBalancePrimary = TextStyle(
    fontFamily: referenceCondensedFamily,
    fontSize: 15.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
  );
  static const historyBalanceTrailingPrimary = historyTrailingPrimary;
  static const historyBalanceSecondary = TextStyle(
    color: AppColors.tradingSecondaryText,
    fontFamily: referenceCondensedFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historyTrailingSecondary = TextStyle(
    color: AppColors.tradingSecondaryText,
    fontFamily: referenceCondensedFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historySummary = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historyOrderSummaryTotal = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const historySummaryValue = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: referencePlainFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static final historyAccountSummary = historySummary.copyWith(
    fontFamily: referenceCondensedVariableFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontVariations: _referenceWeight600,
  );
  static final historyAccountSummaryValue = historySummaryValue.copyWith(
    fontFamily: referenceCondensedVariableFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontVariations: _referenceWeight600,
  );

  static const referencePlainRegularSha256 =
      'f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27';
  static const referencePlainBoldSha256 =
      '9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70';
  static const referenceCondensedRegularSha256 =
      'f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8';
  static const referenceCondensedBoldSha256 =
      'ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a';
  static const referenceCondensedVariableSha256 =
      'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0';

  static final Map<ReferenceTextRole, TextStyle> _referenceRoleStyles =
      Map<ReferenceTextRole, TextStyle>.unmodifiable(<
        ReferenceTextRole,
        TextStyle
      >{
        ReferenceTextRole.navigationLabel: navigationLabel,
        ReferenceTextRole.settingsToolbarTitle: settingsToolbarTitle,
        ReferenceTextRole.settingsAccountName: settingsAccountName,
        ReferenceTextRole.settingsAccountCompany: settingsAccountCompany,
        ReferenceTextRole.settingsAccountMeta: settingsAccountMeta,
        ReferenceTextRole.settingsAccountMetaMultiline:
            settingsAccountMetaMultiline,
        ReferenceTextRole.settingsRowTitle: settingsRowTitle,
        ReferenceTextRole.settingsRowSubtitle: settingsRowSubtitle,
        ReferenceTextRole.settingsNotificationBadge: settingsNotificationBadge,
        ReferenceTextRole.pricesToolbarTitle: pricesToolbarTitle,
        ReferenceTextRole.quoteChange: quoteChange,
        ReferenceTextRole.quoteSymbol: quoteSymbol,
        ReferenceTextRole.quoteMeta: quoteMeta,
        ReferenceTextRole.quoteTimeMeta: quoteTimeMeta,
        ReferenceTextRole.quoteSpreadMeta: quoteSpreadMeta,
        ReferenceTextRole.quoteRangeMeta: quoteRangeMeta,
        ReferenceTextRole.quoteRangeLabel: quoteRangeLabel,
        ReferenceTextRole.quoteRangeValue: quoteRangeValue,
        ReferenceTextRole.quoteBtcHighMeta: quoteBtcHighMeta,
        ReferenceTextRole.quotePriceMajor: quotePriceMajor,
        ReferenceTextRole.quotePriceMinor: quotePriceMinor,
        ReferenceTextRole.quotePriceBtcMajor: quotePriceBtcMajor,
        ReferenceTextRole.quotePriceBtcMinor: quotePriceBtcMinor,
        ReferenceTextRole.quotePricePipette: quotePricePipette,
        ReferenceTextRole.chartToolbar: chartToolbar,
        ReferenceTextRole.chartTimeframe: chartTimeframe,
        ReferenceTextRole.chartDialogTimeframe: chartDialogTimeframe,
        ReferenceTextRole.chartTimeframeHint: chartTimeframeHint,
        ReferenceTextRole.chartOneClickVolume: chartOneClickVolume,
        ReferenceTextRole.chartTicketLabel: chartTicketLabel,
        ReferenceTextRole.chartTicketPriceMajor: chartTicketPriceMajor,
        ReferenceTextRole.chartTicketPriceMinor: chartTicketPriceMinor,
        ReferenceTextRole.chartAnnotation: chartAnnotation,
        ReferenceTextRole.chartAxis: chartAxis,
        ReferenceTextRole.chartTimeAxis: chartTimeAxis,
        ReferenceTextRole.tradeHeaderProfit: tradeHeaderProfit,
        ReferenceTextRole.tradeMetricLabel: tradeMetric,
        ReferenceTextRole.tradeMetricValue: tradeMetricValue,
        ReferenceTextRole.tradeSection: tradeSection,
        ReferenceTextRole.tradePositionSymbol: tradePositionPrimary,
        ReferenceTextRole.tradePositionSide: tradePositionSide,
        ReferenceTextRole.tradePositionSecondary: tradePositionSecondary,
        ReferenceTextRole.tradePositionProfit: tradePositionProfit,
        ReferenceTextRole.historySegment: historySegment,
        ReferenceTextRole.historyDealsSegment: historyDealsSegment,
        ReferenceTextRole.historyPrimary: historyPrimary,
        ReferenceTextRole.historyAction: historyAction,
        ReferenceTextRole.historyTrailingPrimary: historyTrailingPrimary,
        ReferenceTextRole.historySecondary: historySecondary,
        ReferenceTextRole.historyPriceRange: historyPriceRange,
        ReferenceTextRole.historyBalancePrimary: historyBalancePrimary,
        ReferenceTextRole.historyBalanceTrailingPrimary:
            historyBalanceTrailingPrimary,
        ReferenceTextRole.historyBalanceSecondary: historyBalanceSecondary,
        ReferenceTextRole.historyTrailingSecondary: historyTrailingSecondary,
        ReferenceTextRole.historySummary: historySummary,
        ReferenceTextRole.historyOrderSummaryTotal: historyOrderSummaryTotal,
        ReferenceTextRole.historySummaryValue: historySummaryValue,
      });

  static final Map<ReferenceTextRole, ReferenceTextToken> referenceTokens =
      Map<ReferenceTextRole, ReferenceTextToken>.unmodifiable(
        <ReferenceTextRole, ReferenceTextToken>{
          for (final entry in _referenceRoleStyles.entries)
            entry.key: ReferenceTextToken(
              faceSha256: _referenceFaceSha(entry.value),
              style: _metricsOnly(entry.value),
            ),
        },
      );

  static final Map<TypographyStyleKey, ReferenceTextToken>
  referenceVariantOverrides =
      Map<TypographyStyleKey, ReferenceTextToken>.unmodifiable(
        <TypographyStyleKey, ReferenceTextToken>{
          const TypographyStyleKey(
            ReferenceTextRole.chartTicketLabel,
            TypographyVariantId.chartTicketBuy,
          ): ReferenceTextToken(
            faceSha256: referenceCondensedBoldSha256,
            style: _metricsOnly(chartTicketLabel.copyWith(letterSpacing: 1.2)),
          ),
          const TypographyStyleKey(
            ReferenceTextRole.chartTicketLabel,
            TypographyVariantId.chartTicketSell,
          ): ReferenceTextToken(
            faceSha256: referenceCondensedBoldSha256,
            style: _metricsOnly(chartTicketLabel.copyWith(letterSpacing: .42)),
          ),
          for (final variant in const <TypographyVariantId>[
            TypographyVariantId.navigationChartSelected,
            TypographyVariantId.navigationTradeSelected,
            TypographyVariantId.navigationHistorySelected,
          ])
            TypographyStyleKey(
              ReferenceTextRole.navigationLabel,
              variant,
            ): ReferenceTextToken(
              faceSha256: referencePlainRegularSha256,
              style: _metricsOnly(
                navigationLabelSelected.copyWith(letterSpacing: .5),
              ),
            ),
          const TypographyStyleKey(
            ReferenceTextRole.navigationLabel,
            TypographyVariantId.navigationSettingsSelected,
          ): ReferenceTextToken(
            faceSha256: referencePlainRegularSha256,
            style: _metricsOnly(
              navigationLabelSelected.copyWith(letterSpacing: .3),
            ),
          ),
          for (final variant in const <TypographyVariantId>[
            TypographyVariantId.historyBalance,
            TypographyVariantId.historyDeals,
          ]) ...<TypographyStyleKey, ReferenceTextToken>{
            TypographyStyleKey(
              ReferenceTextRole.historySummary,
              variant,
            ): ReferenceTextToken(
              faceSha256: referenceCondensedVariableSha256,
              style: _metricsOnly(historyAccountSummary),
            ),
            TypographyStyleKey(
              ReferenceTextRole.historySummaryValue,
              variant,
            ): ReferenceTextToken(
              faceSha256: referenceCondensedVariableSha256,
              style: _metricsOnly(historyAccountSummaryValue),
            ),
          },
        },
      );

  static final Map<ReferenceTextRole, TypographyTextGeometry>
  referenceGeometry =
      Map<ReferenceTextRole, TypographyTextGeometry>.unmodifiable(
        <ReferenceTextRole, TypographyTextGeometry>{
          for (final role in ReferenceTextRole.values)
            role: const TypographyTextGeometry(),
        },
      );

  static final Map<TypographyStyleKey, TextStyle> legacyTokens =
      Map<TypographyStyleKey, TextStyle>.unmodifiable(
        <TypographyStyleKey, TextStyle>{
          for (final entry in referenceTokens.entries)
            TypographyStyleKey(entry.key, TypographyVariantId.base):
                entry.value.style,
          for (final role in _quoteSharedBranchRoles)
            for (final variant in _quoteVariants)
              TypographyStyleKey(role, variant): referenceTokens[role]!.style,
          for (final role in _quoteRegularPriceRoles)
            for (final variant in const <TypographyVariantId>[
              TypographyVariantId.quoteXau,
              TypographyVariantId.quoteOther,
            ])
              TypographyStyleKey(role, variant): referenceTokens[role]!.style,
          for (final role in _quoteBtcPriceRoles)
            TypographyStyleKey(role, TypographyVariantId.quoteBtc):
                referenceTokens[role]!.style,
          for (final variant in _quoteVariants)
            TypographyStyleKey(ReferenceTextRole.quotePricePipette, variant):
                referenceTokens[ReferenceTextRole.quotePricePipette]!.style,
          for (final role in _historySharedBranchRoles)
            for (final variant in _historyVariants)
              TypographyStyleKey(role, variant): referenceTokens[role]!.style,
          for (final variant in const <TypographyVariantId>[
            TypographyVariantId.historyPositions,
            TypographyVariantId.historyOrders,
          ])
            TypographyStyleKey(ReferenceTextRole.historySegment, variant):
                referenceTokens[ReferenceTextRole.historySegment]!.style,
          TypographyStyleKey(
            ReferenceTextRole.historyDealsSegment,
            TypographyVariantId.historyDeals,
          ): referenceTokens[ReferenceTextRole.historyDealsSegment]!.style,
          for (final role in _historyBalanceRoles)
            TypographyStyleKey(role, TypographyVariantId.historyBalance):
                referenceTokens[role]!.style,
          for (final variant in _settingsRowTitleVariants)
            TypographyStyleKey(ReferenceTextRole.settingsRowTitle, variant):
                referenceTokens[ReferenceTextRole.settingsRowTitle]!.style,
          for (final variant in _settingsRowSubtitleVariants)
            TypographyStyleKey(ReferenceTextRole.settingsRowSubtitle, variant):
                referenceTokens[ReferenceTextRole.settingsRowSubtitle]!.style,
          for (final variant in _navigationVariants)
            TypographyStyleKey(
              ReferenceTextRole.navigationLabel,
              variant,
            ): _metricsOnly(
              _isSelectedNavigationVariant(variant)
                  ? navigationLabelSelected
                  : navigationLabel,
            ),
          for (final entry in referenceVariantOverrides.entries)
            entry.key: entry.value.style,
        },
      );

  static final Map<TypographyStyleKey, TypographyTextGeometry> legacyGeometry =
      Map<TypographyStyleKey, TypographyTextGeometry>.unmodifiable(
        <TypographyStyleKey, TypographyTextGeometry>{
          for (final key in legacyTokens.keys)
            key: const TypographyTextGeometry(),
          const TypographyStyleKey(
            ReferenceTextRole.settingsAccountName,
            TypographyVariantId.base,
          ): const TypographyTextGeometry(
            dy: 1.6666666667,
          ),
          const TypographyStyleKey(
            ReferenceTextRole.settingsAccountCompany,
            TypographyVariantId.base,
          ): const TypographyTextGeometry(
            dx: .6666666667,
            dy: 1.3333333333,
          ),
          const TypographyStyleKey(
            ReferenceTextRole.settingsAccountMetaMultiline,
            TypographyVariantId.base,
          ): const TypographyTextGeometry(
            dx: .6666666667,
          ),
          for (final variant in _settingsRowTitleVariants)
            TypographyStyleKey(ReferenceTextRole.settingsRowTitle, variant):
                _legacySettingsTitleGeometry(variant),
          for (final variant in _settingsRowSubtitleVariants)
            TypographyStyleKey(ReferenceTextRole.settingsRowSubtitle, variant):
                _legacySettingsSubtitleGeometry(variant),
          for (final variant in _navigationVariants)
            TypographyStyleKey(ReferenceTextRole.navigationLabel, variant):
                _legacyNavigationGeometry(variant),
        },
      );

  static Map<ReferenceTextRole, ReferenceTextToken> referenceTokensFor(
    TargetPlatform platform,
  ) => referenceTokens;

  static Map<TypographyStyleKey, ReferenceTextToken>
  referenceVariantOverridesFor(TargetPlatform platform) =>
      referenceVariantOverrides;

  static TextStyle forRole(
    BuildContext context,
    ReferenceTextRole role, {
    required ReferenceTextColorRole colorRole,
    TypographyVariantId variant = TypographyVariantId.base,
  }) {
    final profile = ReferenceTypographyProfile.of(context);
    if (profile == TypographyProfile.legacy) {
      _validateLegacyEnvironment(
        Theme.of(context).platform,
        Theme.of(context).brightness,
      );
    }
    final metrics = switch (profile) {
      TypographyProfile.reference =>
        referenceVariantOverrides[TypographyStyleKey(role, variant)]?.style ??
            referenceTokens[role]?.style ??
            (throw StateError('Missing reference text role: ${role.name}')),
      TypographyProfile.legacy =>
        legacyTokens[TypographyStyleKey(role, variant)] ??
            (throw StateError(
              'Missing legacy text role: ${role.name}:${variant.value}',
            )),
    };
    final color = switch (profile) {
      TypographyProfile.reference => ReferenceTextColors.resolveReference(
        colorRole,
        variant: variant,
        brightness: Theme.of(context).brightness,
      ),
      TypographyProfile.legacy => legacyColorForRole(
        role,
        colorRole,
        variant: variant,
      ),
    };
    return metrics.copyWith(color: color);
  }

  static TypographyTextGeometry geometryForRole(
    BuildContext context,
    ReferenceTextRole role, {
    TypographyVariantId variant = TypographyVariantId.base,
  }) {
    final profile = ReferenceTypographyProfile.of(context);
    if (profile == TypographyProfile.legacy) {
      _validateLegacyEnvironment(
        Theme.of(context).platform,
        Theme.of(context).brightness,
      );
    }
    return switch (profile) {
      TypographyProfile.reference =>
        referenceGeometry[role] ??
            (throw StateError('Missing reference geometry: ${role.name}')),
      TypographyProfile.legacy =>
        legacyGeometry[TypographyStyleKey(role, variant)] ??
            (throw StateError(
              'Missing legacy geometry: ${role.name}:${variant.value}',
            )),
    };
  }

  static Color legacyColorForRole(
    ReferenceTextRole role,
    ReferenceTextColorRole colorRole, {
    TypographyVariantId variant = TypographyVariantId.base,
  }) {
    if (!legacyTokens.containsKey(TypographyStyleKey(role, variant))) {
      throw StateError(
        'Missing legacy text role: ${role.name}:${variant.value}',
      );
    }
    if (colorRole == ReferenceTextColorRole.secondary) {
      return switch (role) {
        ReferenceTextRole.settingsRowSubtitle => AppColors.settingsRowSecondary,
        ReferenceTextRole.quoteMeta ||
        ReferenceTextRole.quoteTimeMeta ||
        ReferenceTextRole.quoteSpreadMeta ||
        ReferenceTextRole.quoteRangeMeta ||
        ReferenceTextRole.quoteRangeLabel ||
        ReferenceTextRole.quoteRangeValue ||
        ReferenceTextRole.quoteBtcHighMeta => AppColors.pricesSecondary,
        ReferenceTextRole.tradePositionSecondary ||
        ReferenceTextRole.historySecondary ||
        ReferenceTextRole.historyPriceRange ||
        ReferenceTextRole.historyBalanceSecondary ||
        ReferenceTextRole.historyTrailingSecondary =>
          AppColors.tradingSecondaryText,
        _ => ReferenceTextColors.resolveLegacy(colorRole, variant),
      };
    }
    return ReferenceTextColors.resolveLegacy(colorRole, variant);
  }

  static TextStyle _metricsOnly(TextStyle style) => TextStyle(
    inherit: style.inherit,
    fontFamily: style.fontFamily,
    fontFamilyFallback: style.fontFamilyFallback,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    fontStyle: style.fontStyle,
    letterSpacing: style.letterSpacing,
    wordSpacing: style.wordSpacing,
    textBaseline: style.textBaseline,
    height: style.height,
    leadingDistribution: style.leadingDistribution,
    locale: style.locale,
    fontFeatures: style.fontFeatures,
    fontVariations: style.fontVariations,
    decoration: style.decoration,
    decorationStyle: style.decorationStyle,
    decorationThickness: style.decorationThickness,
  );

  static String _referenceFaceSha(TextStyle style) {
    final weight = style.fontWeight ?? FontWeight.w400;
    if (weight != FontWeight.w400 && weight != FontWeight.w700) {
      throw StateError(
        'Reference role requests unsupported weight ${weight.value}',
      );
    }
    return switch (style.fontFamily) {
      referencePlainFamily =>
        weight == FontWeight.w700
            ? referencePlainBoldSha256
            : referencePlainRegularSha256,
      referenceCondensedFamily =>
        weight == FontWeight.w700
            ? referenceCondensedBoldSha256
            : referenceCondensedRegularSha256,
      referenceCondensedVariableFamily => referenceCondensedVariableSha256,
      final family => throw StateError(
        'Reference role requests unlocked family $family',
      ),
    };
  }

  static const _navigationVariants = <TypographyVariantId>[
    TypographyVariantId.navigationQuotesSelected,
    TypographyVariantId.navigationQuotesUnselected,
    TypographyVariantId.navigationChartSelected,
    TypographyVariantId.navigationChartUnselected,
    TypographyVariantId.navigationTradeSelected,
    TypographyVariantId.navigationTradeUnselected,
    TypographyVariantId.navigationHistorySelected,
    TypographyVariantId.navigationHistoryUnselected,
    TypographyVariantId.navigationSettingsSelected,
    TypographyVariantId.navigationSettingsUnselected,
  ];

  static const _settingsRowTitleVariants = <TypographyVariantId>[
    TypographyVariantId.settingsRowNewAccount,
    TypographyVariantId.settingsRowMailbox,
    TypographyVariantId.settingsRowNews,
    TypographyVariantId.settingsRowTradays,
    TypographyVariantId.settingsRowCommunity,
    TypographyVariantId.settingsRowTraderCommunity,
    TypographyVariantId.settingsRowAlgoTrading,
    TypographyVariantId.settingsRowOtp,
    TypographyVariantId.settingsRowLanguage,
    TypographyVariantId.settingsRowEmbeddedCharts,
    TypographyVariantId.settingsRowJournal,
    TypographyVariantId.settingsRowFinal,
  ];

  static const _settingsRowSubtitleVariants = <TypographyVariantId>[
    TypographyVariantId.settingsRowMailbox,
    TypographyVariantId.settingsRowTradays,
    TypographyVariantId.settingsRowCommunity,
    TypographyVariantId.settingsRowOtp,
    TypographyVariantId.settingsRowLanguage,
  ];

  static TypographyTextGeometry _legacyNavigationGeometry(
    TypographyVariantId variant,
  ) => switch (variant.value) {
    'navigation.quotes.selected' => const TypographyTextGeometry(
      dx: .6666666667,
    ),
    'navigation.trade.selected' => const TypographyTextGeometry(
      dy: .6666666667,
    ),
    'navigation.history.selected' ||
    'navigation.history.unselected' ||
    'navigation.settings.selected' ||
    'navigation.settings.unselected' => const TypographyTextGeometry(
      dx: -.6666666667,
    ),
    _ => const TypographyTextGeometry(),
  };

  static TypographyTextGeometry _legacySettingsTitleGeometry(
    TypographyVariantId variant,
  ) => switch (variant.value) {
    'settings.row.newAccount' => const TypographyTextGeometry(
      dx: -.6666666667,
      dy: .3,
    ),
    'settings.row.mailbox' => const TypographyTextGeometry(
      dx: -.6666666667,
      dy: -.9666666667,
    ),
    'settings.row.news' || 'settings.row.tradays' =>
      const TypographyTextGeometry(dx: -.6666666667, dy: -1.3),
    'settings.row.community' => const TypographyTextGeometry(
      dx: -.6666666667,
      dy: -1.6633333333,
    ),
    'settings.row.traderCommunity' => const TypographyTextGeometry(
      dx: -.6666666667,
      dy: -.1,
    ),
    'settings.row.algoTrading' || 'settings.row.otp' =>
      const TypographyTextGeometry(dx: -.6666666667, dy: -.6333333333),
    'settings.row.language' => const TypographyTextGeometry(
      dx: -.6666666667,
      dy: -.3,
    ),
    'settings.row.embeddedCharts' ||
    'settings.row.journal' ||
    'settings.row.final' => const TypographyTextGeometry(dx: -.6666666667),
    _ => throw StateError('Missing Settings title geometry: ${variant.value}'),
  };

  static TypographyTextGeometry _legacySettingsSubtitleGeometry(
    TypographyVariantId variant,
  ) => switch (variant.value) {
    'settings.row.mailbox' || 'settings.row.tradays' || 'settings.row.otp' =>
      const TypographyTextGeometry(dx: -.6666666667, dy: -1.6333333333),
    'settings.row.community' => const TypographyTextGeometry(
      dx: -.6666666667,
      dy: -.6633333333,
    ),
    'settings.row.language' => const TypographyTextGeometry(
      dx: -.6666666667,
      dy: -2.3,
    ),
    _ => throw StateError(
      'Missing Settings subtitle geometry: ${variant.value}',
    ),
  };

  static const _quoteVariants = <TypographyVariantId>[
    TypographyVariantId.quoteXau,
    TypographyVariantId.quoteBtc,
    TypographyVariantId.quoteOther,
  ];

  static const _quoteSharedBranchRoles = <ReferenceTextRole>[
    ReferenceTextRole.quoteChange,
    ReferenceTextRole.quoteSymbol,
    ReferenceTextRole.quoteMeta,
    ReferenceTextRole.quoteTimeMeta,
    ReferenceTextRole.quoteSpreadMeta,
    ReferenceTextRole.quoteRangeMeta,
    ReferenceTextRole.quoteRangeLabel,
    ReferenceTextRole.quoteRangeValue,
  ];

  static const _quoteRegularPriceRoles = <ReferenceTextRole>[
    ReferenceTextRole.quotePriceMajor,
    ReferenceTextRole.quotePriceMinor,
  ];

  static const _quoteBtcPriceRoles = <ReferenceTextRole>[
    ReferenceTextRole.quoteBtcHighMeta,
    ReferenceTextRole.quotePriceBtcMajor,
    ReferenceTextRole.quotePriceBtcMinor,
  ];

  static const _historyVariants = <TypographyVariantId>[
    TypographyVariantId.historyPositions,
    TypographyVariantId.historyOrders,
    TypographyVariantId.historyDeals,
  ];

  static const _historySharedBranchRoles = <ReferenceTextRole>[
    ReferenceTextRole.historyPrimary,
    ReferenceTextRole.historyAction,
    ReferenceTextRole.historyTrailingPrimary,
    ReferenceTextRole.historySecondary,
    ReferenceTextRole.historyPriceRange,
    ReferenceTextRole.historyTrailingSecondary,
    ReferenceTextRole.historySummary,
    ReferenceTextRole.historyOrderSummaryTotal,
    ReferenceTextRole.historySummaryValue,
  ];

  static const _historyBalanceRoles = <ReferenceTextRole>[
    ReferenceTextRole.historyBalancePrimary,
    ReferenceTextRole.historyBalanceTrailingPrimary,
    ReferenceTextRole.historyBalanceSecondary,
    ReferenceTextRole.historySummary,
    ReferenceTextRole.historySummaryValue,
  ];

  static bool _isSelectedNavigationVariant(TypographyVariantId variant) =>
      variant.value.endsWith('.selected');

  static void _validateLegacyEnvironment(
    TargetPlatform platform,
    Brightness brightness,
  ) {
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      throw StateError('Uncaptured legacy typography platform: $platform');
    }
    if (brightness != Brightness.light) {
      throw StateError('Uncaptured legacy typography brightness: $brightness');
    }
  }

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

final List<LegacyTypographyCallsite> legacyTypographyCallsiteManifest =
    List<LegacyTypographyCallsite>.unmodifiable(<LegacyTypographyCallsite>[
      for (final key in AppTypography.legacyTokens.keys)
        for (final platform in const <TargetPlatform>[
          TargetPlatform.android,
          TargetPlatform.iOS,
        ])
          LegacyTypographyCallsite(
            id: '${key.role.name}:${key.variant.value}:${platform.name}:light',
            metricRole: key.role,
            colorRole: _legacyColorRoleFor(key),
            variant: key.variant,
            platform: platform,
            brightness: Brightness.light,
            currentStyleSnapshot: AppTypography.legacyTokens[key]!,
            currentColor: AppTypography.legacyColorForRole(
              key.role,
              _legacyColorRoleFor(key),
              variant: key.variant,
            ),
            currentGeometry: AppTypography.legacyGeometry[key]!,
          ),
    ]);

ResolvedTypography resolveLegacyTypography({
  required ReferenceTextRole role,
  required ReferenceTextColorRole colorRole,
  required TypographyVariantId variant,
  required TargetPlatform platform,
  required Brightness brightness,
}) {
  AppTypography._validateLegacyEnvironment(platform, brightness);
  final key = TypographyStyleKey(role, variant);
  final style = AppTypography.legacyTokens[key];
  final geometry = AppTypography.legacyGeometry[key];
  if (style == null || geometry == null) {
    throw StateError('Missing legacy typography variant: $key');
  }
  return ResolvedTypography(
    styleSnapshot: style,
    color: AppTypography.legacyColorForRole(role, colorRole, variant: variant),
    geometry: geometry,
  );
}

ReferenceTextColorRole _legacyColorRoleFor(TypographyStyleKey key) {
  if (key.role == ReferenceTextRole.navigationLabel) {
    return key.variant.value.endsWith('.selected')
        ? ReferenceTextColorRole.navigationSelected
        : ReferenceTextColorRole.navigationUnselected;
  }
  return switch (key.role) {
    ReferenceTextRole.settingsRowSubtitle ||
    ReferenceTextRole.quoteMeta ||
    ReferenceTextRole.quoteTimeMeta ||
    ReferenceTextRole.quoteSpreadMeta ||
    ReferenceTextRole.quoteRangeMeta ||
    ReferenceTextRole.quoteRangeLabel ||
    ReferenceTextRole.quoteRangeValue ||
    ReferenceTextRole.quoteBtcHighMeta ||
    ReferenceTextRole.tradePositionSecondary ||
    ReferenceTextRole.historySecondary ||
    ReferenceTextRole.historyPriceRange ||
    ReferenceTextRole.historyBalanceSecondary ||
    ReferenceTextRole.historyTrailingSecondary =>
      ReferenceTextColorRole.secondary,
    ReferenceTextRole.settingsNotificationBadge ||
    ReferenceTextRole.chartTicketLabel ||
    ReferenceTextRole.chartTicketPriceMajor ||
    ReferenceTextRole.chartTicketPriceMinor => ReferenceTextColorRole.white,
    ReferenceTextRole.quoteChange => ReferenceTextColorRole.negative,
    ReferenceTextRole.quotePriceMajor ||
    ReferenceTextRole.quotePriceMinor ||
    ReferenceTextRole.quotePriceBtcMajor ||
    ReferenceTextRole.quotePriceBtcMinor ||
    ReferenceTextRole.quotePricePipette ||
    ReferenceTextRole.tradeHeaderProfit ||
    ReferenceTextRole.tradePositionProfit ||
    ReferenceTextRole.historyTrailingPrimary ||
    ReferenceTextRole.historyBalanceTrailingPrimary ||
    ReferenceTextRole.historySummaryValue => ReferenceTextColorRole.positive,
    ReferenceTextRole.chartToolbar ||
    ReferenceTextRole.chartTimeframe ||
    ReferenceTextRole.chartDialogTimeframe ||
    ReferenceTextRole.chartTimeframeHint ||
    ReferenceTextRole.chartOneClickVolume =>
      ReferenceTextColorRole.chartToolbar,
    ReferenceTextRole.chartAnnotation ||
    ReferenceTextRole.chartAxis ||
    ReferenceTextRole.chartTimeAxis => ReferenceTextColorRole.chartPlot,
    ReferenceTextRole.tradePositionSide ||
    ReferenceTextRole.historyAction => ReferenceTextColorRole.blueAction,
    ReferenceTextRole.navigationLabel =>
      ReferenceTextColorRole.navigationUnselected,
    ReferenceTextRole.settingsToolbarTitle ||
    ReferenceTextRole.settingsAccountName ||
    ReferenceTextRole.settingsAccountCompany ||
    ReferenceTextRole.settingsAccountMeta ||
    ReferenceTextRole.settingsAccountMetaMultiline ||
    ReferenceTextRole.settingsRowTitle ||
    ReferenceTextRole.pricesToolbarTitle ||
    ReferenceTextRole.quoteSymbol ||
    ReferenceTextRole.tradeMetricLabel ||
    ReferenceTextRole.tradeMetricValue ||
    ReferenceTextRole.tradeSection ||
    ReferenceTextRole.tradePositionSymbol ||
    ReferenceTextRole.historySegment ||
    ReferenceTextRole.historyDealsSegment ||
    ReferenceTextRole.historyPrimary ||
    ReferenceTextRole.historyBalancePrimary ||
    ReferenceTextRole.historySummary ||
    ReferenceTextRole.historyOrderSummaryTotal =>
      ReferenceTextColorRole.primary,
  };
}
