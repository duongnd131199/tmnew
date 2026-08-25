import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
final class ChartGeometry {
  const ChartGeometry({
    required this.priceAxisWidth,
    required this.timeAxisHeight,
    required this.headerHeight,
    required this.targetGridPitch,
    required this.candleBodyRatio,
    required this.wickWidth,
    required this.axisLabelInset,
    required this.newestCandleRightPadding,
  });

  static const canonical = ChartGeometry(
    priceAxisWidth: 76,
    timeAxisHeight: 22,
    headerHeight: 64 / 3,
    targetGridPitch: 28,
    candleBodyRatio: .64,
    wickWidth: 2 / 3,
    axisLabelInset: 4,
    newestCandleRightPadding: 8,
  );

  final double priceAxisWidth;
  final double timeAxisHeight;
  final double headerHeight;
  final double targetGridPitch;
  final double candleBodyRatio;
  final double wickWidth;
  final double axisLabelInset;
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

  double plotWidthFor(double totalWidth) {
    if (!totalWidth.isFinite || totalWidth <= 0) return 0;
    return math.max(0, totalWidth - priceAxisWidthFor(totalWidth));
  }
}
