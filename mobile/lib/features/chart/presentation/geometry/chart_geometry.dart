import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
final class ChartGeometry {
  const ChartGeometry({
    required this.priceAxisWidth,
    required this.m1PriceAxisWidth,
    required this.timeAxisHeight,
    required this.headerHeight,
    required this.m1HeaderHeight,
    required this.targetGridPitch,
    required this.m1TargetGridPitch,
    required this.gridOriginInset,
    required this.m1GridOriginInset,
    required this.timeLabelInset,
    required this.m1TimeLabelInset,
    required this.timeLabelPitch,
    required this.m1TimeLabelPitch,
    required this.candleBodyRatio,
    required this.wickWidth,
    required this.axisLabelInset,
    required this.m1AxisLabelInset,
    required this.newestCandleRightPadding,
  });

  static const canonical = ChartGeometry(
    priceAxisWidth: 76,
    m1PriceAxisWidth: 55 + 1 / 3,
    timeAxisHeight: 22,
    headerHeight: 64 / 3,
    m1HeaderHeight: 78 + 2 / 3,
    targetGridPitch: 28,
    m1TargetGridPitch: 36 + 2 / 3,
    gridOriginInset: 2 / 3,
    m1GridOriginInset: 18,
    timeLabelInset: 2 / 3,
    m1TimeLabelInset: 18 + 2 / 3,
    timeLabelPitch: 42,
    m1TimeLabelPitch: 88,
    candleBodyRatio: .64,
    wickWidth: 2 / 3,
    axisLabelInset: 4,
    m1AxisLabelInset: 4 + 2 / 3,
    newestCandleRightPadding: 8,
  );

  final double priceAxisWidth;
  final double m1PriceAxisWidth;
  final double timeAxisHeight;
  final double headerHeight;
  final double m1HeaderHeight;
  final double targetGridPitch;
  final double m1TargetGridPitch;
  final double gridOriginInset;
  final double m1GridOriginInset;
  final double timeLabelInset;
  final double m1TimeLabelInset;
  final double timeLabelPitch;
  final double m1TimeLabelPitch;
  final double candleBodyRatio;
  final double wickWidth;
  final double axisLabelInset;
  final double m1AxisLabelInset;
  final double newestCandleRightPadding;

  double priceAxisWidthFor(double totalWidth) {
    if (!totalWidth.isFinite) return priceAxisWidth;
    const compactWidth = 384.0;
    const canonicalWidth = 590 / 1.5;
    const compactAxisWidth = 202 / 3;
    final progress =
        ((totalWidth - compactWidth) / (canonicalWidth - compactWidth)).clamp(
          0.0,
          1.0,
        );
    return compactAxisWidth + (priceAxisWidth - compactAxisWidth) * progress;
  }

  double m1PriceAxisWidthFor(double totalWidth) {
    if (!totalWidth.isFinite) return m1PriceAxisWidth;
    const compactWidth = 384.0;
    const canonicalWidth = 590 / 1.5;
    const compactAxisWidth = 202 / 3;
    final progress =
        ((totalWidth - compactWidth) / (canonicalWidth - compactWidth)).clamp(
          0.0,
          1.0,
        );
    return compactAxisWidth + (m1PriceAxisWidth - compactAxisWidth) * progress;
  }

  double plotWidthFor(double totalWidth) {
    if (!totalWidth.isFinite || totalWidth <= 0) return 0;
    return math.max(0, totalWidth - priceAxisWidthFor(totalWidth));
  }
}
