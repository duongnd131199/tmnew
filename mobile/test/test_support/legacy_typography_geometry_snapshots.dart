import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/reference_typography_profile.dart';

@immutable
final class LegacyTypographyGeometrySnapshot {
  const LegacyTypographyGeometrySnapshot({
    required this.metricRole,
    required this.variant,
    required this.platform,
    required this.brightness,
    required this.geometry,
  });

  final ReferenceTextRole metricRole;
  final TypographyVariantId variant;
  final TargetPlatform platform;
  final Brightness brightness;
  final TypographyTextGeometry geometry;

  TypographyStyleKey get styleKey => TypographyStyleKey(metricRole, variant);
}

// This fixture is deliberately hand-authored instead of being derived from
// AppTypography.legacyTokens or AppTypography.legacyGeometry. It captures the
// pre-profile geometry contract independently so resolver tests can catch a
// missing variant or an accidental transform.
final List<LegacyTypographyGeometrySnapshot> legacyTypographyGeometrySnapshots =
    List<LegacyTypographyGeometrySnapshot>.unmodifiable(
      <LegacyTypographyGeometrySnapshot>[
        for (final key in _capturedStyleKeys)
          for (final platform in const <TargetPlatform>[
            TargetPlatform.android,
            TargetPlatform.iOS,
          ])
            LegacyTypographyGeometrySnapshot(
              metricRole: key.role,
              variant: key.variant,
              platform: platform,
              brightness: Brightness.light,
              geometry: _capturedGeometry(key),
            ),
      ],
    );

const _baseStyleKeys = <TypographyStyleKey>[
  TypographyStyleKey(
    ReferenceTextRole.navigationLabel,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.settingsToolbarTitle,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.settingsAccountName,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.settingsAccountCompany,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.settingsAccountMeta,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.settingsAccountMetaMultiline,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.settingsRowTitle,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.settingsRowSubtitle,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.settingsNotificationBadge,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.pricesToolbarTitle,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(ReferenceTextRole.quoteChange, TypographyVariantId.base),
  TypographyStyleKey(ReferenceTextRole.quoteSymbol, TypographyVariantId.base),
  TypographyStyleKey(ReferenceTextRole.quoteMeta, TypographyVariantId.base),
  TypographyStyleKey(ReferenceTextRole.quoteTimeMeta, TypographyVariantId.base),
  TypographyStyleKey(
    ReferenceTextRole.quoteSpreadMeta,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.quoteRangeMeta,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.quoteRangeLabel,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.quoteRangeValue,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.quoteBtcHighMeta,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.quotePriceMajor,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.quotePriceMinor,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.quotePriceBtcMajor,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.quotePriceBtcMinor,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.quotePricePipette,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(ReferenceTextRole.chartToolbar, TypographyVariantId.base),
  TypographyStyleKey(
    ReferenceTextRole.chartTimeframe,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.chartDialogTimeframe,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.chartTimeframeHint,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.chartOneClickVolume,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.chartTicketLabel,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.chartTicketPriceMajor,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.chartTicketPriceMinor,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.chartAnnotation,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(ReferenceTextRole.chartAxis, TypographyVariantId.base),
  TypographyStyleKey(ReferenceTextRole.chartTimeAxis, TypographyVariantId.base),
  TypographyStyleKey(
    ReferenceTextRole.tradeHeaderProfit,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.tradeMetricLabel,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.tradeMetricValue,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(ReferenceTextRole.tradeSection, TypographyVariantId.base),
  TypographyStyleKey(
    ReferenceTextRole.tradePositionSymbol,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.tradePositionSide,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.tradePositionSecondary,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.tradePositionProfit,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historySegment,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historyDealsSegment,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historyPrimary,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(ReferenceTextRole.historyAction, TypographyVariantId.base),
  TypographyStyleKey(
    ReferenceTextRole.historyTrailingPrimary,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historySecondary,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historyPriceRange,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historyBalancePrimary,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historyBalanceTrailingPrimary,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historyBalanceSecondary,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historyTrailingSecondary,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historySummary,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historyOrderSummaryTotal,
    TypographyVariantId.base,
  ),
  TypographyStyleKey(
    ReferenceTextRole.historySummaryValue,
    TypographyVariantId.base,
  ),
];

const _quoteVariants = <TypographyVariantId>[
  TypographyVariantId.quoteXau,
  TypographyVariantId.quoteBtc,
  TypographyVariantId.quoteOther,
];

const _quoteSharedRoles = <ReferenceTextRole>[
  ReferenceTextRole.quoteChange,
  ReferenceTextRole.quoteSymbol,
  ReferenceTextRole.quoteMeta,
  ReferenceTextRole.quoteTimeMeta,
  ReferenceTextRole.quoteSpreadMeta,
  ReferenceTextRole.quoteRangeMeta,
  ReferenceTextRole.quoteRangeLabel,
  ReferenceTextRole.quoteRangeValue,
];

const _quoteRegularPriceRoles = <ReferenceTextRole>[
  ReferenceTextRole.quotePriceMajor,
  ReferenceTextRole.quotePriceMinor,
];

const _quoteBtcPriceRoles = <ReferenceTextRole>[
  ReferenceTextRole.quoteBtcHighMeta,
  ReferenceTextRole.quotePriceBtcMajor,
  ReferenceTextRole.quotePriceBtcMinor,
];

const _historyVariants = <TypographyVariantId>[
  TypographyVariantId.historyPositions,
  TypographyVariantId.historyOrders,
  TypographyVariantId.historyDeals,
];

const _historySharedRoles = <ReferenceTextRole>[
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

const _historyBalanceRoles = <ReferenceTextRole>[
  ReferenceTextRole.historyBalancePrimary,
  ReferenceTextRole.historyBalanceTrailingPrimary,
  ReferenceTextRole.historyBalanceSecondary,
  ReferenceTextRole.historySummary,
  ReferenceTextRole.historySummaryValue,
];

const _navigationVariants = <TypographyVariantId>[
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

const _settingsNewAccount = TypographyVariantId('settings.row.newAccount');
const _settingsMailbox = TypographyVariantId('settings.row.mailbox');
const _settingsNews = TypographyVariantId('settings.row.news');
const _settingsTradays = TypographyVariantId('settings.row.tradays');
const _settingsCommunity = TypographyVariantId('settings.row.community');
const _settingsTraderCommunity = TypographyVariantId(
  'settings.row.traderCommunity',
);
const _settingsAlgoTrading = TypographyVariantId('settings.row.algoTrading');
const _settingsOtp = TypographyVariantId('settings.row.otp');
const _settingsLanguage = TypographyVariantId('settings.row.language');
const _settingsEmbeddedCharts = TypographyVariantId(
  'settings.row.embeddedCharts',
);
const _settingsJournal = TypographyVariantId('settings.row.journal');
const _settingsFinal = TypographyVariantId('settings.row.final');

const _settingsTitleVariants = <TypographyVariantId>[
  _settingsNewAccount,
  _settingsMailbox,
  _settingsNews,
  _settingsTradays,
  _settingsCommunity,
  _settingsTraderCommunity,
  _settingsAlgoTrading,
  _settingsOtp,
  _settingsLanguage,
  _settingsEmbeddedCharts,
  _settingsJournal,
  _settingsFinal,
];

const _settingsSubtitleVariants = <TypographyVariantId>[
  _settingsMailbox,
  _settingsTradays,
  _settingsCommunity,
  _settingsOtp,
  _settingsLanguage,
];

final _settingsTitleGeometry = <TypographyVariantId, TypographyTextGeometry>{
  _settingsNewAccount: TypographyTextGeometry(dx: -.6666666667, dy: .3),
  _settingsMailbox: TypographyTextGeometry(dx: -.6666666667, dy: -.9666666667),
  _settingsNews: TypographyTextGeometry(dx: -.6666666667, dy: -1.3),
  _settingsTradays: TypographyTextGeometry(dx: -.6666666667, dy: -1.3),
  _settingsCommunity: TypographyTextGeometry(
    dx: -.6666666667,
    dy: -1.6633333333,
  ),
  _settingsTraderCommunity: TypographyTextGeometry(dx: -.6666666667, dy: -.1),
  _settingsAlgoTrading: TypographyTextGeometry(
    dx: -.6666666667,
    dy: -.6333333333,
  ),
  _settingsOtp: TypographyTextGeometry(dx: -.6666666667, dy: -.6333333333),
  _settingsLanguage: TypographyTextGeometry(dx: -.6666666667, dy: -.3),
  _settingsEmbeddedCharts: TypographyTextGeometry(dx: -.6666666667),
  _settingsJournal: TypographyTextGeometry(dx: -.6666666667),
  _settingsFinal: TypographyTextGeometry(dx: -.6666666667),
};

final _settingsSubtitleGeometry = <TypographyVariantId, TypographyTextGeometry>{
  _settingsMailbox: TypographyTextGeometry(dx: -.6666666667, dy: -1.6333333333),
  _settingsTradays: TypographyTextGeometry(dx: -.6666666667, dy: -1.6333333333),
  _settingsCommunity: TypographyTextGeometry(
    dx: -.6666666667,
    dy: -.6633333333,
  ),
  _settingsOtp: TypographyTextGeometry(dx: -.6666666667, dy: -1.6333333333),
  _settingsLanguage: TypographyTextGeometry(dx: -.6666666667, dy: -2.3),
};

final List<TypographyStyleKey> _capturedStyleKeys = <TypographyStyleKey>[
  ..._baseStyleKeys,
  for (final role in _quoteSharedRoles)
    for (final variant in _quoteVariants) TypographyStyleKey(role, variant),
  for (final role in _quoteRegularPriceRoles)
    for (final variant in const <TypographyVariantId>[
      TypographyVariantId.quoteXau,
      TypographyVariantId.quoteOther,
    ])
      TypographyStyleKey(role, variant),
  for (final role in _quoteBtcPriceRoles)
    TypographyStyleKey(role, TypographyVariantId.quoteBtc),
  for (final variant in _quoteVariants)
    TypographyStyleKey(ReferenceTextRole.quotePricePipette, variant),
  for (final role in _historySharedRoles)
    for (final variant in _historyVariants) TypographyStyleKey(role, variant),
  for (final variant in const <TypographyVariantId>[
    TypographyVariantId.historyPositions,
    TypographyVariantId.historyOrders,
  ])
    TypographyStyleKey(ReferenceTextRole.historySegment, variant),
  const TypographyStyleKey(
    ReferenceTextRole.historyDealsSegment,
    TypographyVariantId.historyDeals,
  ),
  for (final role in _historyBalanceRoles)
    TypographyStyleKey(role, TypographyVariantId.historyBalance),
  for (final variant in _settingsTitleVariants)
    TypographyStyleKey(ReferenceTextRole.settingsRowTitle, variant),
  for (final variant in _settingsSubtitleVariants)
    TypographyStyleKey(ReferenceTextRole.settingsRowSubtitle, variant),
  for (final variant in _navigationVariants)
    TypographyStyleKey(ReferenceTextRole.navigationLabel, variant),
  const TypographyStyleKey(
    ReferenceTextRole.chartTicketLabel,
    TypographyVariantId.chartTicketBuy,
  ),
  const TypographyStyleKey(
    ReferenceTextRole.chartTicketLabel,
    TypographyVariantId.chartTicketSell,
  ),
];

TypographyTextGeometry _capturedGeometry(TypographyStyleKey key) {
  if (key.role == ReferenceTextRole.navigationLabel) {
    return switch (key.variant.value) {
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
  }
  if (key.role == ReferenceTextRole.settingsAccountName) {
    return const TypographyTextGeometry(dy: 1.6666666667);
  }
  if (key.role == ReferenceTextRole.settingsAccountCompany) {
    return const TypographyTextGeometry(dx: .6666666667, dy: 1.3333333333);
  }
  if (key.role == ReferenceTextRole.settingsAccountMetaMultiline) {
    return const TypographyTextGeometry(dx: .6666666667);
  }
  if (key.role == ReferenceTextRole.settingsRowTitle) {
    return _settingsTitleGeometry[key.variant] ??
        const TypographyTextGeometry();
  }
  if (key.role == ReferenceTextRole.settingsRowSubtitle) {
    return _settingsSubtitleGeometry[key.variant] ??
        const TypographyTextGeometry();
  }
  return const TypographyTextGeometry();
}
