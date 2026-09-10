import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_spacing.dart';

abstract final class TabReferenceMetrics {
  static const viewportWidth = 393.3333333333;
  static const viewportHeight = 853.3333333333;
  static const devicePixelRatio = 1.5;
  static const topSafeInset = 24.0;

  // Video 3 was captured at 384 logical pixels. Trade uses this width as its
  // own visual canvas so wider iPhones preserve the recorded proportions.
  static const tradeViewportWidth = 384.0;

  static const bottomNavigationHeight = 79.0;
  static const bottomNavigationFadeHeight = 103.0;
  static const bottomNavigationLeftInset = 18.6666666667;
  static const bottomNavigationTopInset = 2.1666666667;
  static const bottomNavigationRightInset = 0.0;
  static const bottomNavigationBottomInset = 19.6333333333;
  static const bottomNavigationCapsuleWidth = 356.0;
  static const bottomNavigationCapsuleRadius = 31.0;
  static const bottomNavigationContentHorizontalInset = 7.3333333333;
  static const bottomNavigationItemVerticalInset = 3.2;
  static const bottomNavigationInteractionRadius = 29.0;
  static const bottomNavigationSelectionRadius = 27.0;
  static double bottomNavigationSelectionTopInset(int selectedIndex) => 2.0;
  static double bottomNavigationSelectionBottomInset(int selectedIndex) =>
      switch (selectedIndex) {
        1 => 0.0,
        3 => .3333333333,
        _ => .6666666667,
      };
  static const bottomNavigationIconTop = 8.7666666667;
  static const bottomNavigationIconSize = 23.0;
  static const bottomNavigationLabelTop = 34.3333333333;
  static const bottomNavigationHistoryLabelOffsetX = -.6666666667;

  static double bottomNavigationLabelWeight(int itemIndex, bool selected) =>
      (selected
      ? const <double>[300, 281, 288, 280, 350]
      : const <double>[325, 342, 350, 313, 329])[itemIndex];

  static ({double x, double y}) bottomNavigationLabelOffset(
    int itemIndex,
    bool selected,
  ) => switch ((itemIndex, selected)) {
    (0, true) => (x: .6666666667, y: 0),
    (2, true) => (x: 0, y: .6666666667),
    (4, _) => (x: -.6666666667, y: 0),
    _ => (x: itemIndex == 3 ? bottomNavigationHistoryLabelOffsetX : 0, y: 0),
  };

  static ({double left, double right}) bottomNavigationSelectionOverhangs(
    int selectedIndex,
  ) => switch (selectedIndex) {
    0 => (left: 3.3333333333, right: 4.0),
    1 => (left: 2.6666666667, right: 3.3333333333),
    2 => (left: 3.3333333333, right: 2.6666666667),
    3 => (left: 4.0, right: 2.6666666667),
    _ => (left: 4.0, right: 4.0),
  };

  static const bottomNavigationSettingsIconOffsetX = .6666666667;
  static const bottomNavigationSettingsIconOffsetY = .3333333333;
  static const bottomNavigationSettingsIconScaleX = .90;
  static const bottomNavigationSettingsIconScaleY = .90;
  static const bottomNavigationChartIconOffsetX = .1666666667;
  static const bottomNavigationChartIconOffsetY = 1.3333333333;
  static const bottomNavigationChartIconScaleX = .93;
  static const bottomNavigationChartIconScaleY = .87;
  static const bottomNavigationTradeIconOffsetY = -1.3333333333;
  static const bottomNavigationTradeIconScaleX = .98;
  static const bottomNavigationTradeIconScaleY = 1.08;
  static const bottomNavigationHistoryIconOffsetX = -.8333333333;
  static const bottomNavigationHistoryIconOffsetY = -.3333333333;
  static const bottomNavigationHistoryIconScaleX = .96;
  static const bottomNavigationQuotesIconOffsetX = -.3333333333;
  static const bottomNavigationQuotesIconScaleX = .90;
  static const bottomNavigationQuotesIconScaleY = .94;
  static const chartTicketPipetteOffsetY = -11.5;

  static const quoteHeaderHeight = 91.6666666667;
  static const quoteHeaderControlTop = 40.0;
  static const quoteHeaderTitleTop = 49.0;
  static const quoteHeaderButtonSize = 44.0;
  static const quoteHeaderVisualDiameter = 43.3333333333;
  static const quoteRowHeight = 72.0;
  static const quotePricePipetteOffsetY = -11.0;
  static const quoteBtcRangeOffsetY = 1.3333333333;
  // Legacy compatibility values are no longer consumed by Prices.
  static const quoteBtcMetaTop = 46.0;
  static const quoteBtcPriceScaleY = 1.07;
  static const quoteBtcPriceOffsetY = -1.3333333333;
  static const quoteBtcHighOffsetX = 0.0;
  static const quoteCornerWidth = 8.0;
  static const quoteCornerHeight = 9.6666666667;
  static const quoteCornerOffsetY = .6666666667;

  static const tradeHeaderHeight = 72.6666666667;
  static const tradeMetricRowHeight = 22.0;
  static const tradeSectionHeight = 25.0;
  static const tradePositionRowHeight = 53.1111111111;
  static const tradePositionSecondaryTop = 22.0;
  static const positionDetailControlDividerHeight = 1.3333333333;
  static const positionDetailProtectionRowHeight = 36.3333333333;
  static const positionDetailModifyButtonHeight = 38.0;
  static const orderTicketCloseBannerGap = 4.0;
  static const orderTicketCloseBannerHeight = 38.0;
  static const orderTicketCloseBannerVerticalPadding = 4.0;
  static const tradeScrollbarTopInset = 115.3333333333;
  static const tradeScrollbarBottomInset = 24.0;
  static const tradeScrollbarThumbExtent = 526.6666666667;

  static double tradeScrollbarThumbExtentFor(double viewportExtent) {
    final trackExtent = math.max(
      0,
      viewportExtent - tradeScrollbarTopInset - tradeScrollbarBottomInset,
    );
    const referenceViewportExtent =
        viewportHeight - topSafeInset - tradeHeaderHeight;
    const referenceTrackExtent =
        referenceViewportExtent -
        tradeScrollbarTopInset -
        tradeScrollbarBottomInset;
    return tradeScrollbarThumbExtent *
        math.min(1, trackExtent / referenceTrackExtent);
  }

  static ({
    double offsetX,
    double offsetY,
    double scaleX,
    double scaleY,
    double weight,
  })
  tradeMetricRasterAdjustment(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android => (
      offsetX: -.6666666667,
      offsetY: -.6666666667,
      scaleX: 1.049,
      scaleY: 1.03,
      weight: 400,
    ),
    TargetPlatform.iOS => (
      offsetX: -.6666666667,
      offsetY: 0,
      scaleX: 1.032,
      scaleY: 1.08,
      weight: 400,
    ),
    _ => (offsetX: 0, offsetY: -.6666666667, scaleX: 1, scaleY: 1, weight: 400),
  };

  static const historyHeaderExtent = 80.0;
  static const historyHeaderHeight = historyHeaderExtent;
  static const historySelectedSideInset = 3.0;
  static const historyDealsSelectedRightInset = 1.0;
  static const historyFirstSelectedLeftOffset = -1.3333333333;
  static const historyFirstSelectedRightInset = 2.6666666667;
  static const historyListTopGap = 4.0;
  static const historyRowHeight = 52.0;
  static const historySummaryRowHeight = 21.3333333333;
  static const historyPrimaryTop = 4.0;
  static const historyPrimaryScaleY = 1.03;
  static const historyPrimaryOffsetY = -.6666666667;
  static const historySecondaryTop = 26.0;
  static const historyPriceRangeTop = 26.6666666667;
  static const historyPositionSecondaryScaleY = .88;
  static const historyPositionSecondaryOffsetY = .6666666667;
  static const historyDealSecondaryTop = 27.3333333333;
  static const historyDealSecondaryScaleY = .99;
  static const historyDealSecondaryOffsetY = -.6666666667;
  static const historyActionOffsetY = .6666666667;
  static const historyOrderStatusScaleY = .85;
  static const historyOrderStatusOffsetX = -.6666666667;
  static const historyOrderStatusOffsetY = .6666666667;
  static const historyOrderSummaryTotalOffsetY = -.6666666667;
  static const historyScrollbarBottomInset = 78.6666666667;
  static const historyScrollbarWidth = 3.3333333333;
  static const historyScrollbarRightInset = 2.6666666667;
  static const historyOrdersThumbExtent = 457.3333333333;
  static const historyOrdersEndThumbGrowth = 1.3333333333;
  static const historyDealsThumbExtent = 424.6666666667;
  static const historyScrollbarEndEdgeInset = .48;

  static const _historyPrimaryFontSize = 16.0;
  static const _historySecondaryFontSize = 14.0;
  static const _historySummaryFontSize = 14.5;
  static const _historyLineGap =
      historySecondaryTop - historyPrimaryTop - _historyPrimaryFontSize;
  static const _historyRowBottomInset =
      historyRowHeight - historySecondaryTop - _historySecondaryFontSize;
  static const _historySummaryVerticalInset =
      historySummaryRowHeight - _historySummaryFontSize;

  static double historySecondaryTopFor(TextScaler textScaler) =>
      historyPrimaryTop +
      textScaler.scale(_historyPrimaryFontSize) +
      _historyLineGap +
      (historyStacksSecondary(textScaler) ? 1 : 0);

  static bool historyStacksSecondary(TextScaler textScaler) =>
      textScaler.scale(_historySecondaryFontSize) >
      _historySecondaryFontSize + 0.01;

  static double historyTrailingSecondaryTopFor(TextScaler textScaler) =>
      historySecondaryTopFor(textScaler) +
      textScaler.scale(_historySecondaryFontSize) +
      AppSpacing.xxs;

  static double historyRowHeightFor(TextScaler textScaler) {
    final lastLineTop = historyStacksSecondary(textScaler)
        ? historyTrailingSecondaryTopFor(textScaler)
        : historySecondaryTopFor(textScaler);
    return math.max(
      historyRowHeight,
      lastLineTop +
          textScaler.scale(_historySecondaryFontSize) +
          _historyRowBottomInset,
    );
  }

  static double historySummaryRowHeightFor(TextScaler textScaler) => math.max(
    historySummaryRowHeight,
    textScaler.scale(_historySummaryFontSize) + _historySummaryVerticalInset,
  );
}
