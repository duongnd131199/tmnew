import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_spacing.dart';

abstract final class TabReferenceMetrics {
  static const viewportWidth = 393.3333333333;
  static const viewportHeight = 853.3333333333;
  static const devicePixelRatio = 1.5;
  static const topSafeInset = 24.0;

  static const bottomNavigationHeight = 79.0;
  static const bottomNavigationLabelTop = 34.3333333333;

  static const quoteHeaderHeight = 78.6666666667;
  static const quoteRowHeight = 69.3333333333;
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
  static const tradePositionRowHeight = 53.3333333333;
  static const tradePositionSecondaryTop = 22.0;

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
      weight: 300,
    ),
    TargetPlatform.iOS => (
      offsetX: -.6666666667,
      offsetY: 0,
      scaleX: 1.032,
      scaleY: 1.08,
      weight: 335,
    ),
    _ => (offsetX: 0, offsetY: -.6666666667, scaleX: 1, scaleY: 1, weight: 300),
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
  static const historySecondaryTop = 26.0;
  static const historyPriceRangeTop = 26.6666666667;
  static const historyDealSecondaryTop = 27.3333333333;
  static const historyDealSecondaryScaleY = .9;
  static const historyActionOffsetY = .6666666667;
  static const historyOrderStatusScaleY = .85;
  static const historyOrderStatusOffsetX = -.6666666667;
  static const historyOrderStatusOffsetY = .6666666667;
  static const historyOrderSummaryTotalOffsetY = -.6666666667;

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
