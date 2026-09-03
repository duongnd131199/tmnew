import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
class ChartViewport {
  const ChartViewport({
    this.barSpacing = defaultBarSpacing,
    this.scrollOffset = 0,
    this.rightPadding = defaultRightPadding,
  });

  static const double minimumBarSpacing = 4;
  static const double maximumBarSpacing = 48;
  static const double defaultBarSpacing = 28;
  static const double defaultRightPadding = defaultBarSpacing;
  static const int maximumFutureCandleSlots = 4;

  final double barSpacing;
  final double scrollOffset;
  final double rightPadding;

  ChartViewport copyWith({
    double? barSpacing,
    double? scrollOffset,
    double? rightPadding,
  }) {
    return ChartViewport(
      barSpacing: barSpacing ?? this.barSpacing,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      rightPadding: rightPadding ?? this.rightPadding,
    );
  }

  ChartViewport bounded({required double plotWidth, required int candleCount}) {
    final spacing = _finite(
      barSpacing,
      defaultBarSpacing,
    ).clamp(minimumBarSpacing, maximumBarSpacing);
    final padding = spacing;
    final candidate = ChartViewport(
      barSpacing: spacing,
      scrollOffset: _finite(scrollOffset, 0),
      rightPadding: padding,
    );
    return candidate.copyWith(
      scrollOffset: candidate.scrollOffset.clamp(
        candidate.minScrollOffset,
        candidate.maxScrollOffset(
          plotWidth: plotWidth,
          candleCount: candleCount,
        ),
      ),
    );
  }

  double get minScrollOffset {
    final spacing = _finite(
      barSpacing,
      defaultBarSpacing,
    ).clamp(minimumBarSpacing, maximumBarSpacing);
    return -(maximumFutureCandleSlots - 1) * spacing;
  }

  double maxScrollOffset({
    required double plotWidth,
    required int candleCount,
  }) {
    if (candleCount <= 1) return 0;
    final width = math.max(0.0, _finite(plotWidth, 0));
    final spacing = _finite(
      barSpacing,
      defaultBarSpacing,
    ).clamp(minimumBarSpacing, maximumBarSpacing);
    final padding = spacing;
    return math.max(0.0, (candleCount - 1) * spacing - (width - padding));
  }

  double candleIndexAt(
    double localX, {
    required double plotWidth,
    required int candleCount,
  }) {
    if (candleCount <= 1) return 0;
    final boundedViewport = bounded(
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    final width = math.max(0.0, _finite(plotWidth, 0));
    final x = _finite(localX, 0);
    final index =
        candleCount -
        1 +
        (x -
                (width - boundedViewport.rightPadding) -
                boundedViewport.scrollOffset) /
            boundedViewport.barSpacing;
    return index.clamp(0.0, candleCount - 1.0);
  }

  double candleCenterX({
    required int candleIndex,
    required double plotWidth,
    required int candleCount,
  }) {
    final boundedViewport = bounded(
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    final width = math.max(0.0, _finite(plotWidth, 0));
    final newestIndex = math.max(0, candleCount - 1);
    return width -
        boundedViewport.rightPadding -
        (newestIndex - candleIndex) * boundedViewport.barSpacing +
        boundedViewport.scrollOffset;
  }

  int visibleStartIndex({required double plotWidth, required int candleCount}) {
    if (candleCount <= 0) return 0;
    final boundedViewport = bounded(
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    final first = boundedViewport._unclampedCandleIndexAt(
      -boundedViewport.barSpacing / 2,
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    return first.ceil().clamp(0, candleCount - 1);
  }

  int visibleEndIndex({required double plotWidth, required int candleCount}) {
    if (candleCount <= 0) return -1;
    final boundedViewport = bounded(
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    final width = math.max(0.0, _finite(plotWidth, 0));
    final last = boundedViewport._unclampedCandleIndexAt(
      width + boundedViewport.barSpacing / 2,
      plotWidth: width,
      candleCount: candleCount,
    );
    return last.floor().clamp(0, candleCount - 1);
  }

  double _unclampedCandleIndexAt(
    double localX, {
    required double plotWidth,
    required int candleCount,
  }) {
    final width = math.max(0.0, _finite(plotWidth, 0));
    return candleCount -
        1 +
        (_finite(localX, 0) - (width - rightPadding) - scrollOffset) /
            barSpacing;
  }

  static double _finite(double value, double fallback) =>
      value.isFinite ? value : fallback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartViewport &&
          other.barSpacing == barSpacing &&
          other.scrollOffset == scrollOffset &&
          other.rightPadding == rightPadding;

  @override
  int get hashCode => Object.hash(barSpacing, scrollOffset, rightPadding);

  @override
  String toString() =>
      'ChartViewport(barSpacing: $barSpacing, scrollOffset: $scrollOffset, '
      'rightPadding: $rightPadding)';
}

class ChartViewportController {
  static const double inertiaProjectionSeconds = .18;

  ChartViewport? _panStartViewport;
  double _panStartFocalPoint = 0;
  ChartViewport? _scaleStartViewport;
  double _scaleFocalCandle = 0;
  double _scaleStartGestureScale = 1;

  void beginPan({
    required ChartViewport viewport,
    required double focalPoint,
    required double plotWidth,
    required int candleCount,
  }) {
    _panStartViewport = viewport.bounded(
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    _panStartFocalPoint = focalPoint.isFinite ? focalPoint : 0;
  }

  ChartViewport updatePan({
    required double focalPoint,
    required double plotWidth,
    required int candleCount,
  }) {
    final start = (_panStartViewport ?? const ChartViewport()).bounded(
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    final currentFocalPoint = focalPoint.isFinite ? focalPoint : 0;
    return start
        .copyWith(
          scrollOffset:
              start.scrollOffset + currentFocalPoint - _panStartFocalPoint,
        )
        .bounded(plotWidth: plotWidth, candleCount: candleCount);
  }

  void beginScale({
    required ChartViewport viewport,
    required double focalPoint,
    required double plotWidth,
    required int candleCount,
    double gestureScale = 1,
  }) {
    _scaleStartViewport = viewport.bounded(
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    _scaleFocalCandle = _scaleStartViewport!.candleIndexAt(
      focalPoint,
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    _scaleStartGestureScale = gestureScale.isFinite && gestureScale > 0
        ? gestureScale
        : 1;
  }

  ChartViewport updateScale({
    required double scale,
    required double focalPoint,
    required double plotWidth,
    required int candleCount,
  }) {
    final start = (_scaleStartViewport ?? const ChartViewport()).bounded(
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    final finiteScale = scale.isFinite
        ? math.max(0.0, scale / _scaleStartGestureScale)
        : 1.0;
    final spacing = (start.barSpacing * finiteScale).clamp(
      ChartViewport.minimumBarSpacing,
      ChartViewport.maximumBarSpacing,
    );
    final width = math.max(0.0, plotWidth.isFinite ? plotWidth : 0.0);
    final focal = focalPoint.isFinite ? focalPoint : 0;
    final newestIndex = math.max(0, candleCount - 1);
    final currentFutureSlotCount = (1 - start.scrollOffset / start.barSpacing)
        .clamp(1.0, ChartViewport.maximumFutureCandleSlots.toDouble());
    final focalOffset =
        focal - (width - spacing) + (newestIndex - _scaleFocalCandle) * spacing;
    final preservedFutureOffset = -(currentFutureSlotCount - 1) * spacing;
    final offset = math.max(focalOffset, preservedFutureOffset);
    return start
        .copyWith(
          barSpacing: spacing,
          scrollOffset: offset,
          rightPadding: spacing,
        )
        .bounded(plotWidth: width, candleCount: candleCount);
  }

  ChartViewport panBy({
    required ChartViewport viewport,
    required double delta,
    required double plotWidth,
    required int candleCount,
  }) {
    final bounded = viewport.bounded(
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
    final finiteDelta = delta.isFinite ? delta : 0;
    return bounded
        .copyWith(scrollOffset: bounded.scrollOffset + finiteDelta)
        .bounded(plotWidth: plotWidth, candleCount: candleCount);
  }

  ChartViewport endPan({
    required ChartViewport viewport,
    required double velocity,
    required double plotWidth,
    required int candleCount,
  }) {
    final finiteVelocity = velocity.isFinite ? velocity : 0;
    return panBy(
      viewport: viewport,
      delta: finiteVelocity * inertiaProjectionSeconds,
      plotWidth: plotWidth,
      candleCount: candleCount,
    );
  }

  ChartViewport reset() => const ChartViewport();
}
