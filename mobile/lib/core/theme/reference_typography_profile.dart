import 'package:flutter/material.dart';

import 'app_colors.dart';

enum TypographyProfile { legacy, reference }

enum ReferenceTextRole {
  navigationLabel,
  settingsToolbarTitle,
  settingsAccountName,
  settingsAccountCompany,
  settingsAccountMeta,
  settingsAccountMetaMultiline,
  settingsRowTitle,
  settingsRowSubtitle,
  settingsNotificationBadge,
  pricesToolbarTitle,
  quoteChange,
  quoteSymbol,
  quoteMeta,
  quoteTimeMeta,
  quoteSpreadMeta,
  quoteRangeMeta,
  quoteRangeLabel,
  quoteRangeValue,
  quoteBtcHighMeta,
  quotePriceMajor,
  quotePriceMinor,
  quotePriceBtcMajor,
  quotePriceBtcMinor,
  quotePricePipette,
  chartToolbar,
  chartTimeframe,
  chartDialogTimeframe,
  chartTimeframeHint,
  chartOneClickVolume,
  chartTicketLabel,
  chartTicketPriceMajor,
  chartTicketPriceMinor,
  chartAnnotation,
  chartAxis,
  chartTimeAxis,
  tradeHeaderProfit,
  tradeMetricLabel,
  tradeMetricValue,
  tradeSection,
  tradePositionSymbol,
  tradePositionSide,
  tradePositionSecondary,
  tradePositionProfit,
  historySegment,
  historyDealsSegment,
  historyPrimary,
  historyAction,
  historyTrailingPrimary,
  historySecondary,
  historyPriceRange,
  historyBalancePrimary,
  historyBalanceTrailingPrimary,
  historyBalanceSecondary,
  historyTrailingSecondary,
  historySummary,
  historyOrderSummaryTotal,
  historySummaryValue,
}

enum ReferenceTextColorRole {
  primary,
  secondary,
  navigationSelected,
  navigationUnselected,
  blueAction,
  positive,
  negative,
  tradeSecondary,
  tradeNegative,
  historyStatus,
  chartToolbar,
  chartPlot,
  white,
}

@immutable
final class TypographyVariantId {
  const TypographyVariantId(this.value);

  static const base = TypographyVariantId('base');
  static const chartTicketBuy = TypographyVariantId('chart.ticket.buy');
  static const chartTicketSell = TypographyVariantId('chart.ticket.sell');
  static const quoteXau = TypographyVariantId('quote.xau');
  static const quoteBtc = TypographyVariantId('quote.btc');
  static const quoteOther = TypographyVariantId('quote.other');
  static const historyPositions = TypographyVariantId('history.positions');
  static const historyOrders = TypographyVariantId('history.orders');
  static const historyDeals = TypographyVariantId('history.deals');
  static const historyBalance = TypographyVariantId('history.balance');
  static const settingsRowNewAccount = TypographyVariantId(
    'settings.row.newAccount',
  );
  static const settingsRowMailbox = TypographyVariantId('settings.row.mailbox');
  static const settingsRowNews = TypographyVariantId('settings.row.news');
  static const settingsRowTradays = TypographyVariantId('settings.row.tradays');
  static const settingsRowCommunity = TypographyVariantId(
    'settings.row.community',
  );
  static const settingsRowTraderCommunity = TypographyVariantId(
    'settings.row.traderCommunity',
  );
  static const settingsRowAlgoTrading = TypographyVariantId(
    'settings.row.algoTrading',
  );
  static const settingsRowOtp = TypographyVariantId('settings.row.otp');
  static const settingsRowLanguage = TypographyVariantId(
    'settings.row.language',
  );
  static const settingsRowEmbeddedCharts = TypographyVariantId(
    'settings.row.embeddedCharts',
  );
  static const settingsRowJournal = TypographyVariantId('settings.row.journal');
  static const settingsRowFinal = TypographyVariantId('settings.row.final');
  static const navigationQuotesSelected = TypographyVariantId(
    'navigation.quotes.selected',
  );
  static const navigationQuotesUnselected = TypographyVariantId(
    'navigation.quotes.unselected',
  );
  static const navigationChartSelected = TypographyVariantId(
    'navigation.chart.selected',
  );
  static const navigationChartUnselected = TypographyVariantId(
    'navigation.chart.unselected',
  );
  static const navigationTradeSelected = TypographyVariantId(
    'navigation.trade.selected',
  );
  static const navigationTradeUnselected = TypographyVariantId(
    'navigation.trade.unselected',
  );
  static const navigationHistorySelected = TypographyVariantId(
    'navigation.history.selected',
  );
  static const navigationHistoryUnselected = TypographyVariantId(
    'navigation.history.unselected',
  );
  static const navigationSettingsSelected = TypographyVariantId(
    'navigation.settings.selected',
  );
  static const navigationSettingsUnselected = TypographyVariantId(
    'navigation.settings.unselected',
  );

  static const all = <TypographyVariantId>[
    base,
    chartTicketBuy,
    chartTicketSell,
    quoteXau,
    quoteBtc,
    quoteOther,
    historyPositions,
    historyOrders,
    historyDeals,
    historyBalance,
    settingsRowNewAccount,
    settingsRowMailbox,
    settingsRowNews,
    settingsRowTradays,
    settingsRowCommunity,
    settingsRowTraderCommunity,
    settingsRowAlgoTrading,
    settingsRowOtp,
    settingsRowLanguage,
    settingsRowEmbeddedCharts,
    settingsRowJournal,
    settingsRowFinal,
    navigationQuotesSelected,
    navigationQuotesUnselected,
    navigationChartSelected,
    navigationChartUnselected,
    navigationTradeSelected,
    navigationTradeUnselected,
    navigationHistorySelected,
    navigationHistoryUnselected,
    navigationSettingsSelected,
    navigationSettingsUnselected,
  ];

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographyVariantId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TypographyVariantId($value)';
}

@immutable
final class TypographyStyleKey {
  const TypographyStyleKey(this.role, this.variant);

  final ReferenceTextRole role;
  final TypographyVariantId variant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographyStyleKey &&
          other.role == role &&
          other.variant == variant;

  @override
  int get hashCode => Object.hash(role, variant);

  @override
  String toString() => '${role.name}:${variant.value}';
}

@immutable
final class TypographyColorKey {
  const TypographyColorKey(this.role, this.variant);

  final ReferenceTextColorRole role;
  final TypographyVariantId variant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographyColorKey &&
          other.role == role &&
          other.variant == variant;

  @override
  int get hashCode => Object.hash(role, variant);
}

@immutable
final class ReferenceTextToken {
  const ReferenceTextToken({required this.faceSha256, required this.style});

  final String faceSha256;
  final TextStyle style;
}

@immutable
final class TypographyTextGeometry {
  const TypographyTextGeometry({
    this.scaleX = 1,
    this.scaleY = 1,
    this.dx = 0,
    this.dy = 0,
  });

  final double scaleX;
  final double scaleY;
  final double dx;
  final double dy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographyTextGeometry &&
          other.scaleX == scaleX &&
          other.scaleY == scaleY &&
          other.dx == dx &&
          other.dy == dy;

  @override
  int get hashCode => Object.hash(scaleX, scaleY, dx, dy);
}

@immutable
final class ResolvedTypography {
  const ResolvedTypography({
    required this.styleSnapshot,
    required this.color,
    required this.geometry,
  });

  final TextStyle styleSnapshot;
  final Color color;
  final TypographyTextGeometry geometry;
}

@immutable
final class LegacyTypographyCallsite {
  const LegacyTypographyCallsite({
    required this.id,
    required this.metricRole,
    required this.colorRole,
    required this.variant,
    required this.platform,
    required this.brightness,
    required this.currentStyleSnapshot,
    required this.currentColor,
    required this.currentGeometry,
  });

  final String id;
  final ReferenceTextRole metricRole;
  final ReferenceTextColorRole colorRole;
  final TypographyVariantId variant;
  final TargetPlatform platform;
  final Brightness brightness;
  final TextStyle currentStyleSnapshot;
  final Color currentColor;
  final TypographyTextGeometry currentGeometry;

  TypographyStyleKey get styleKey => TypographyStyleKey(metricRole, variant);
}

const bool referenceTypographyEnabled = bool.fromEnvironment(
  'REFERENCE_TYPOGRAPHY',
  defaultValue: true,
);

const TypographyProfile defaultTypographyProfile = referenceTypographyEnabled
    ? TypographyProfile.reference
    : TypographyProfile.legacy;

@immutable
final class ReferenceTypographyProfile
    extends ThemeExtension<ReferenceTypographyProfile> {
  const ReferenceTypographyProfile({required this.profile});

  final TypographyProfile profile;

  static ReferenceTypographyProfile? maybeOf(BuildContext context) =>
      Theme.of(context).extension<ReferenceTypographyProfile>();

  static TypographyProfile of(BuildContext context) =>
      maybeOf(context)?.profile ?? defaultTypographyProfile;

  @override
  ReferenceTypographyProfile copyWith({TypographyProfile? profile}) =>
      ReferenceTypographyProfile(profile: profile ?? this.profile);

  @override
  ReferenceTypographyProfile lerp(
    covariant ThemeExtension<ReferenceTypographyProfile>? other,
    double t,
  ) {
    if (other is! ReferenceTypographyProfile) return this;
    return t < .5 ? this : other;
  }
}

ThemeData withTypographyProfile(ThemeData theme, TypographyProfile profile) {
  final extensions = theme.extensions.values
      .where((extension) => extension is! ReferenceTypographyProfile)
      .toList(growable: true);
  extensions.add(ReferenceTypographyProfile(profile: profile));
  return theme.copyWith(extensions: extensions);
}

abstract final class ReferenceTextColors {
  static const reference = <ReferenceTextColorRole, Color>{
    ReferenceTextColorRole.primary: AppColors.textPrimary,
    ReferenceTextColorRole.secondary: AppColors.textSecondary,
    ReferenceTextColorRole.navigationSelected: AppColors.primary,
    ReferenceTextColorRole.navigationUnselected: AppColors.navigationUnselected,
    ReferenceTextColorRole.blueAction: AppColors.primary,
    ReferenceTextColorRole.positive: AppColors.positive,
    ReferenceTextColorRole.negative: AppColors.negative,
    ReferenceTextColorRole.tradeSecondary: AppColors.tradingSecondaryText,
    ReferenceTextColorRole.tradeNegative: AppColors.tradeNegative,
    ReferenceTextColorRole.historyStatus: AppColors.historyOrderStatus,
    ReferenceTextColorRole.chartToolbar: AppColors.textSecondary,
    ReferenceTextColorRole.chartPlot: AppColors.chartPlotTitleBlue,
    ReferenceTextColorRole.white: Colors.white,
  };

  static const referenceDark = <ReferenceTextColorRole, Color>{
    ReferenceTextColorRole.primary: AppColors.tradeDarkPrimary,
    ReferenceTextColorRole.secondary: AppColors.tradeDarkSecondary,
    ReferenceTextColorRole.navigationSelected: AppColors.primary,
    ReferenceTextColorRole.navigationUnselected:
        AppColors.darkNavigationUnselected,
    ReferenceTextColorRole.blueAction: AppColors.tradeDarkBlueAction,
    ReferenceTextColorRole.positive: AppColors.tradeDarkPositive,
    ReferenceTextColorRole.negative: AppColors.negative,
    ReferenceTextColorRole.tradeSecondary: AppColors.tradeDarkSecondary,
    ReferenceTextColorRole.tradeNegative: AppColors.negative,
    ReferenceTextColorRole.historyStatus: AppColors.historyOrderStatus,
    ReferenceTextColorRole.chartToolbar: AppColors.textSecondary,
    ReferenceTextColorRole.chartPlot: AppColors.chartPlotTitleBlue,
    ReferenceTextColorRole.white: Colors.white,
  };

  static final Map<TypographyColorKey, Color> legacy =
      Map<TypographyColorKey, Color>.unmodifiable(<TypographyColorKey, Color>{
        for (final role in ReferenceTextColorRole.values)
          for (final variant in TypographyVariantId.all)
            TypographyColorKey(role, variant): reference[role]!,
      });

  static final Map<TypographyColorKey, Color> referenceVariantOverrides =
      Map<TypographyColorKey, Color>.unmodifiable(<TypographyColorKey, Color>{
        for (final variant in TypographyVariantId.all)
          if (variant.value.startsWith('settings.row.'))
            TypographyColorKey(ReferenceTextColorRole.secondary, variant):
                AppColors.settingsRowSecondary,
      });

  static Map<ReferenceTextColorRole, Color> referenceFor(
    TargetPlatform platform, {
    Brightness brightness = Brightness.light,
  }) => brightness == Brightness.dark ? referenceDark : reference;

  static Map<TypographyColorKey, Color> referenceVariantOverridesFor(
    TargetPlatform platform,
  ) => referenceVariantOverrides;

  static Color resolveReference(
    ReferenceTextColorRole role, {
    TypographyVariantId variant = TypographyVariantId.base,
    Brightness brightness = Brightness.light,
  }) {
    final colors = brightness == Brightness.dark ? referenceDark : reference;
    return referenceVariantOverrides[TypographyColorKey(role, variant)] ??
        colors[role] ??
        (throw StateError('Missing reference color role: ${role.name}'));
  }

  static Color resolveLegacy(
    ReferenceTextColorRole role,
    TypographyVariantId variant,
  ) {
    final direct = legacy[TypographyColorKey(role, variant)];
    if (direct != null) return direct;
    throw StateError(
      'Missing legacy color role: ${role.name}:${variant.value}',
    );
  }
}
