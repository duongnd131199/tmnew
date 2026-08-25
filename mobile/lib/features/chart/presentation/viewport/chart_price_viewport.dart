import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
final class ChartPriceRange {
  const ChartPriceRange({required this.minPrice, required this.maxPrice});

  final double minPrice;
  final double maxPrice;

  double get centerPrice {
    if (minPrice.isFinite && maxPrice.isFinite) {
      return minPrice / 2 + maxPrice / 2;
    }
    if (minPrice.isFinite) return minPrice;
    if (maxPrice.isFinite) return maxPrice;
    return 0;
  }

  double get range {
    if (!minPrice.isFinite || !maxPrice.isFinite || maxPrice <= minPrice) {
      return 0;
    }
    final difference = maxPrice - minPrice;
    return difference.isFinite ? difference : double.maxFinite;
  }

  double priceAt({
    required double y,
    required double priceTop,
    required double priceHeight,
  }) {
    final safeHeight = priceHeight.isFinite && priceHeight > 0
        ? priceHeight
        : 1.0;
    final safeTop = priceTop.isFinite ? priceTop : 0.0;
    final safeY = y.isFinite ? y : safeTop + safeHeight / 2;
    final fraction = ((safeY - safeTop) / safeHeight).clamp(0.0, 1.0);
    final safeRange = range;
    final safeCenter = centerPrice;
    if (safeRange <= 0) return safeCenter;
    final safeMax = _saturatingAdd(safeCenter, safeRange / 2);
    return _saturatingAdd(safeMax, -fraction * safeRange);
  }
}

@immutable
final class ChartPriceViewport {
  const ChartPriceViewport.auto() : centerPrice = null, range = null;

  const ChartPriceViewport.manual({
    required this.centerPrice,
    required this.range,
  });

  final double? centerPrice;
  final double? range;

  bool get isAuto => centerPrice == null || range == null;

  ChartPriceRange resolve(ChartPriceRange automatic) {
    final fallback = _normalizedRange(automatic);
    if (isAuto || !centerPrice!.isFinite || !range!.isFinite || range! <= 0) {
      return fallback;
    }
    final safeRange = range!.clamp(
      ChartPriceViewportController.minimumRange,
      ChartPriceViewportController.maximumRange,
    );
    return _finiteRangeAround(centerPrice!, safeRange);
  }

  static ChartPriceRange _normalizedRange(ChartPriceRange candidate) {
    final directRange = candidate.maxPrice - candidate.minPrice;
    if (candidate.minPrice.isFinite &&
        candidate.maxPrice.isFinite &&
        candidate.maxPrice > candidate.minPrice &&
        directRange.isFinite &&
        directRange > 0) {
      return candidate;
    }
    final finiteCenter = candidate.centerPrice;
    final desiredRange = math.max(
      finiteCenter.abs() * 2e-6,
      candidate.range > 0 ? candidate.range : 1.0,
    );
    return _finiteRangeAround(finiteCenter, desiredRange);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartPriceViewport &&
          other.centerPrice == centerPrice &&
          other.range == range;

  @override
  int get hashCode => Object.hash(centerPrice, range);
}

final class ChartPriceViewportController {
  static const double dragExponentPerLogicalPixel = .00104;
  static const double minimumRange = 1e-12;
  static const double maximumRange = 1e15;
  static const double maximumAbsolutePrice = 1e15;

  double _startRange = 1;
  double _anchorFraction = .5;
  double _anchorPrice = 0;

  void beginDrag({
    required ChartPriceViewport viewport,
    required double focalY,
    required double priceTop,
    required double priceHeight,
    required ChartPriceRange displayedRange,
  }) {
    final resolved = viewport.resolve(displayedRange);
    _startRange = resolved.range.clamp(minimumRange, maximumRange);
    final safeHeight = priceHeight.isFinite && priceHeight > 0
        ? priceHeight
        : 1.0;
    final safeTop = priceTop.isFinite ? priceTop : 0.0;
    final safeFocal = focalY.isFinite ? focalY : safeTop + safeHeight / 2;
    _anchorFraction = ((safeFocal - safeTop) / safeHeight).clamp(0.0, 1.0);
    _anchorPrice = resolved.maxPrice - _anchorFraction * resolved.range;
    if (!_anchorPrice.isFinite) _anchorPrice = 0;
  }

  ChartPriceViewport updateDrag({required double deltaY}) {
    final safeDelta = deltaY.isNaN ? 0.0 : deltaY;
    final minimumExponent = math.log(minimumRange / _startRange);
    final maximumExponent = math.log(maximumRange / _startRange);
    final exponent = (safeDelta * dragExponentPerLogicalPixel).clamp(
      minimumExponent,
      maximumExponent,
    );
    final nextRange = exponent <= minimumExponent
        ? minimumRange
        : exponent >= maximumExponent
        ? maximumRange
        : _startRange * math.exp(exponent);
    final nextCenter = _saturatingAdd(
      _anchorPrice,
      (_anchorFraction - .5) * nextRange,
    );
    return ChartPriceViewport.manual(centerPrice: nextCenter, range: nextRange);
  }

  ChartPriceViewport reset() => const ChartPriceViewport.auto();
}

ChartPriceRange _finiteRangeAround(double center, double requestedRange) {
  final safeCenter = center.isFinite ? center : 0.0;
  var safeRange = requestedRange.isFinite && requestedRange > 0
      ? requestedRange
      : 1.0;
  safeRange = math.min(safeRange, double.maxFinite / 2);

  var minPrice = safeCenter - safeRange / 2;
  var maxPrice = safeCenter + safeRange / 2;
  if (minPrice.isFinite &&
      maxPrice.isFinite &&
      maxPrice > minPrice &&
      (maxPrice - minPrice).isFinite) {
    return ChartPriceRange(minPrice: minPrice, maxPrice: maxPrice);
  }

  final representableRange = math.min(
    double.maxFinite / 2,
    math.max(safeRange, safeCenter.abs() * 2e-6),
  );
  if (safeCenter >= 0) {
    maxPrice = math.min(safeCenter, double.maxFinite);
    minPrice = maxPrice - representableRange;
  } else {
    minPrice = math.max(safeCenter, -double.maxFinite);
    maxPrice = minPrice + representableRange;
  }
  if (minPrice.isFinite && maxPrice.isFinite && maxPrice > minPrice) {
    return ChartPriceRange(minPrice: minPrice, maxPrice: maxPrice);
  }
  return const ChartPriceRange(minPrice: -.5, maxPrice: .5);
}

double _saturatingAdd(double left, double right) {
  final result = left + right;
  if (result.isFinite) return result;
  if (result.isNaN) return 0;
  return result.isNegative ? -double.maxFinite : double.maxFinite;
}
