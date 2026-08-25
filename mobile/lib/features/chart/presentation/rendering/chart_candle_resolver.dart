import 'dart:math' as math;

import 'package:trading_mobile/features/chart/data/market_data_service.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

/// Resolves history/reference contours before a render snapshot is published.
///
/// Callers cache the returned sequence by request/history and split its final
/// candle from the stable prefix. This class is deliberately independent from
/// [Mt5CandlePainter], whose constructor and paint path only consume snapshots.
final class ChartCandleResolver {
  const ChartCandleResolver({
    required this.symbol,
    required this.referencePrice,
    required this.currentPrice,
    required this.timeframe,
    required this.loadingPlaceholder,
    required this.useRealtimeCandles,
  });

  final String symbol;
  final double referencePrice;
  final double currentPrice;
  final String timeframe;
  final bool loadingPlaceholder;
  final bool useRealtimeCandles;

  List<MarketCandle> resolve(
    List<MarketCandle> sourceCandles,
    List<MarketCandle> settledLiveTail,
  ) {
    if (useRealtimeCandles) return sourceCandles;
    final base = _usesReferenceSeries(sourceCandles.length)
        ? _fallbackCandles()
        : sourceCandles;
    return MarketDataService.mergeLiveTail(
      base,
      settledLiveTail,
      timeframe: timeframe,
      maxCandles: 360,
    );
  }

  bool _usesReferenceSeries(int sourceLength) =>
      !useRealtimeCandles &&
      ((currentPrice >= 1000 && currentPrice < 10000) ||
          _isAudNokReference ||
          _isVideo2Reference ||
          sourceLength < 20);

  List<MarketCandle> _fallbackCandles() {
    const count = 360;
    final fallbackAnchorPrice = _fallbackAnchorPrice();
    final seed = timeframe.codeUnits.fold<int>(
      0,
      (value, item) => value + item,
    );
    final duration = _timeframeDuration();
    final isReferenceAudNok = _isAudNokReference;
    final referenceVisible = _referenceVisibleCount();
    final visibleStart = count - referenceVisible;
    final closes = List<double>.generate(count, (index) {
      if (index < visibleStart) {
        final lead = index / math.max(1, visibleStart - 1);
        if (isReferenceAudNok) {
          final step = _referencePriceStep();
          return fallbackAnchorPrice +
              step * 14 +
              math.sin(index * .17 + seed) * step * .65 +
              math.cos(index * .43) * step * .3 -
              lead * step * .6;
        }
        return fallbackAnchorPrice +
            11 +
            math.sin(index * .17 + seed) * 7 +
            math.cos(index * .43) * 3 -
            lead * 3;
      }
      final progress = (index - visibleStart) / (referenceVisible - 1);
      final base = _interpolateReferencePath(progress);
      final detailScale = _isBtcUsdVideo2Reference && timeframe == 'H4'
          ? 90.0
          : _isXauUsdVideo2Reference && timeframe == 'H4'
          ? 24.0
          : _isXauUsdVideo2Reference && timeframe == 'H1'
          ? 2.0
          : isReferenceAudNok
          ? _audNokDetailScale()
          : timeframe == 'D1'
          ? (_isXauUsdVideo2Reference ? 7.5 : 0.0)
          : timeframe == 'W1'
          ? 35.0
          : timeframe == 'MN'
          ? 70.0
          : timeframe == 'M1' ||
                timeframe == 'M2' ||
                timeframe == 'M3' ||
                timeframe == 'M4'
          ? symbol == 'XAUEUR'
                ? 0
                : .10
          : symbol == 'XAUEUR' &&
                const {'M5', 'M6', 'M10', 'M12'}.contains(timeframe)
          ? .02
          : .12 * _intradayRangeScale();
      final detail =
          (math.sin(index * 1.83 + seed) + math.sin(index * .47 + .8) * .65) *
          detailScale *
          (1 - progress * .35);
      if (index == count - 1) return currentPrice;
      return fallbackAnchorPrice + base + detail;
    }, growable: false);
    final referenceEnd = MarketDataService.bucketStart(
      _referenceEndTime(),
      timeframe,
    );
    final fallbackTimes = _fallbackTimes(count, referenceEnd, duration);
    return List<MarketCandle>.generate(count, (index) {
      final close = closes[index];
      var open = index == 0 ? close : closes[index - 1];
      final wickBase = _isBtcUsdVideo2Reference && timeframe == 'H4'
          ? 180.0
          : _isXauUsdVideo2Reference && timeframe == 'H4'
          ? 6.5
          : _isXauUsdVideo2Reference && timeframe == 'H1'
          ? 2.4
          : isReferenceAudNok
          ? _audNokWickBase()
          : switch (timeframe) {
              'D1' => _isXauUsdVideo2Reference ? 8.5 : 5.5,
              'W1' => 45.0,
              'MN' => 90.0,
              'H1' || 'H2' || 'H3' || 'H4' || 'H6' || 'H8' || 'H12' => 4.2,
              'M15' || 'M20' || 'M30' => 2.8,
              'M5' || 'M6' || 'M10' || 'M12' => .34,
              _ => .14,
            };
      var wick = wickBase * (1 + ((index + seed) % 4) * .28);
      var high = math.max(open, close) + wick;
      var low = math.min(open, close) - wick;
      if (index == visibleStart &&
          !const {'M1', 'M2', 'M3', 'M4'}.contains(timeframe)) {
        open = symbol == 'XAUEUR' && timeframe == 'D1'
            ? close + 70
            : symbol == 'XAUEUR' &&
                  const {'M5', 'M6', 'M10', 'M12'}.contains(timeframe)
            ? close + 1.8
            : close - wickBase * 1.4;
        high = math.max(open, close) + wick;
        low = math.min(open, close) - wick;
      }
      if (index == visibleStart &&
          const {'M1', 'M2', 'M3', 'M4'}.contains(timeframe)) {
        if (_isAudNokM1Reference) {
          open = close - .0012;
          high = math.max(open, close) + .0015;
          low = math.min(open, close) - .0018;
        } else {
          open = close + 1.2;
          high = math.max(open, close) + .28;
          low = math.min(open, close) - .24;
        }
      }
      if (_isXauUsdVideo2Reference && timeframe == 'H1') {
        final shock =
            Mt5CandlePainter.fallbackXauUsdH1WickShocks[index - visibleStart];
        if (shock != null) {
          high = math.max(high, math.max(open, close) + shock.upper);
          low = math.min(low, math.min(open, close) - shock.lower);
        }
      }
      if (_isXauUsdVideo2Reference && timeframe == 'H4') {
        final shock =
            Mt5CandlePainter.fallbackXauUsdH4WickShocks[index - visibleStart];
        if (shock != null) {
          high = math.max(high, math.max(open, close) + shock.upper);
          low = math.min(low, math.min(open, close) - shock.lower);
        }
      }
      return MarketCandle(
        time: fallbackTimes[index],
        open: open,
        high: high,
        low: low,
        close: close,
      );
    }, growable: false);
  }

  int _referenceVisibleCount() => 128;

  double _fallbackAnchorPrice() {
    if (!currentPrice.isFinite || currentPrice <= 0) return referencePrice;
    final comparisonScale = math.max(
      1.0,
      math.max(referencePrice.abs(), currentPrice.abs()),
    );
    final domainMismatch =
        !referencePrice.isFinite ||
        referencePrice <= 0 ||
        (referencePrice - currentPrice).abs() / comparisonScale > .25;
    return domainMismatch ? currentPrice : referencePrice;
  }

  double _intradayRangeScale() => switch (timeframe) {
    'M1' || 'M2' || 'M3' || 'M4' => 1,
    'M5' || 'M6' || 'M10' || 'M12' => 2.7,
    'M15' || 'M20' => 4,
    'M30' => 4.7,
    'H1' || 'H2' || 'H3' => 6,
    'H4' || 'H6' || 'H8' || 'H12' => 8,
    _ => 1,
  };

  bool get _normalisesXauUsdFallbackContour =>
      _isXauUsdVideo2Reference &&
      const {
        'M1',
        'M2',
        'M3',
        'M4',
        'M5',
        'M6',
        'M10',
        'M12',
        'H2',
        'H3',
        'H6',
        'H8',
        'H12',
      }.contains(timeframe);

  double _xauUsdFallbackPathScale(List<(double, double)> path) {
    var minimum = path.first.$2;
    var maximum = minimum;
    for (final point in path.skip(1)) {
      minimum = math.min(minimum, point.$2);
      maximum = math.max(maximum, point.$2);
    }
    final span = math.max(.0001, maximum - minimum);
    final axisRange = _fallbackContourPriceStep() * 17;
    return axisRange * .64 / span;
  }

  double _interpolateReferencePath(double progress) {
    final path = _isVideo2Reference
        ? switch ((symbol, timeframe)) {
            ('BTCUSD', 'H4') => Mt5CandlePainter.fallbackBtcUsdH4Video2Path,
            (_, 'H1') => Mt5CandlePainter.fallbackXauUsdH1Video2Path,
            _ => Mt5CandlePainter.fallbackXauUsdH4Video2Path,
          }
        : _isAudNokM1Reference
        ? Mt5CandlePainter.fallbackAudNokM1ReferencePath
        : switch (timeframe) {
            'D1' || 'W1' || 'MN' => Mt5CandlePainter.fallbackDailyReferencePath,
            'M5' ||
            'M6' ||
            'M10' ||
            'M12' => Mt5CandlePainter.fallbackM5ReferencePath,
            'M15' ||
            'M20' ||
            'M30' => Mt5CandlePainter.fallbackM30ReferencePath,
            _ => Mt5CandlePainter.fallbackM1ReferencePath,
          };
    final scale = _isVideo2Reference
        ? 1.0
        : _isAudNokM1Reference
        ? 1.0
        : _isAudNokReference
        ? _audNokPathScale()
        : _normalisesXauUsdFallbackContour
        ? _xauUsdFallbackPathScale(path)
        : switch (timeframe) {
            'D1' => _isXauUsdVideo2Reference ? 1.42 : 1.0,
            'M5' || 'M6' || 'M10' || 'M12' || 'M30' => 1.0,
            'M15' || 'M20' => .86,
            'W1' => 1.0,
            'MN' => 2.0,
            _ => _intradayRangeScale(),
          };
    for (var index = 1; index < path.length; index++) {
      final previous = path[index - 1];
      final next = path[index];
      if (progress <= next.$1) {
        final segment =
            (progress - previous.$1) / math.max(.0001, next.$1 - previous.$1);
        return (previous.$2 + (next.$2 - previous.$2) * segment) * scale;
      }
    }
    return path.last.$2 * scale;
  }

  DateTime _referenceEndTime() {
    if (_isAudNokM1Reference) return DateTime(2026, 7, 1, 19, 37);
    if (_isBtcUsdVideo2Reference && timeframe == 'H4') {
      return DateTime(2026, 7, 27, 4);
    }
    if (_isXauUsdVideo2Reference && timeframe == 'H4') {
      return DateTime(2026, 7, 27, 4);
    }
    if (_isXauUsdVideo2Reference && timeframe == 'H1') {
      return DateTime(2026, 7, 27, 5);
    }
    return switch (timeframe) {
      'M1' || 'M2' || 'M3' || 'M4' => DateTime(2026, 7, 24, 22, 59),
      'M5' || 'M6' || 'M10' || 'M12' => DateTime(2026, 7, 24, 22, 59),
      'M15' || 'M20' || 'M30' => DateTime(2026, 7, 24, 22, 59),
      'D1' => DateTime(2026, 7, 24),
      'W1' => DateTime(2026, 6, 14),
      'MN' => DateTime(2026, 6),
      _ => DateTime(2026, 7, 8, 19, 30),
    };
  }

  List<DateTime> _fallbackTimes(
    int count,
    DateTime referenceEnd,
    Duration duration,
  ) {
    if (timeframe == 'MN') {
      return List<DateTime>.generate(
        count,
        (index) => DateTime(
          referenceEnd.year,
          referenceEnd.month - (count - 1 - index),
        ),
        growable: false,
      );
    }
    if (timeframe != 'D1') {
      return List<DateTime>.generate(
        count,
        (index) => referenceEnd.subtract(duration * (count - 1 - index)),
        growable: false,
      );
    }
    final reversed = <DateTime>[];
    var cursor = referenceEnd;
    while (reversed.length < count) {
      if (cursor.weekday != DateTime.saturday &&
          cursor.weekday != DateTime.sunday) {
        reversed.add(cursor);
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return reversed.reversed.toList(growable: false);
  }

  Duration _timeframeDuration() => switch (timeframe) {
    'M1' => const Duration(minutes: 1),
    'M2' => const Duration(minutes: 2),
    'M3' => const Duration(minutes: 3),
    'M4' => const Duration(minutes: 4),
    'M5' => const Duration(minutes: 5),
    'M6' => const Duration(minutes: 6),
    'M10' => const Duration(minutes: 10),
    'M12' => const Duration(minutes: 12),
    'M15' => const Duration(minutes: 15),
    'M20' => const Duration(minutes: 20),
    'M30' => const Duration(minutes: 30),
    'H1' => const Duration(hours: 1),
    'H2' => const Duration(hours: 2),
    'H3' => const Duration(hours: 3),
    'H4' => const Duration(hours: 4),
    'H6' => const Duration(hours: 6),
    'H8' => const Duration(hours: 8),
    'H12' => const Duration(hours: 12),
    'D1' => const Duration(days: 1),
    'W1' => const Duration(days: 7),
    'MN' => const Duration(days: 30),
    _ => const Duration(minutes: 15),
  };

  double _fallbackContourPriceStep() => switch (timeframe) {
    'M1' || 'M2' || 'M3' || 'M4' => 4.08,
    'M5' || 'M6' || 'M10' || 'M12' => 6.37,
    'M15' || 'M20' => 9.04,
    'M30' => 10.32,
    'H1' || 'H2' || 'H3' => 18.72,
    'H4' || 'H6' || 'H8' || 'H12' => 37.64,
    'D1' => 47.23,
    'W1' => 94.09,
    'MN' => 188.18,
    _ => 4.08,
  };

  double _referencePriceStep() {
    if (_isAudNokReference) {
      return switch (timeframe) {
        'M1' ||
        'M2' ||
        'M3' ||
        'M4' ||
        'M5' ||
        'M6' ||
        'M10' ||
        'M12' => .00165,
        'M15' || 'M20' || 'M30' || 'H1' || 'H2' || 'H3' => .00350,
        'H4' || 'H6' || 'H8' || 'H12' => .00750,
        'D1' => .01000,
        'W1' => .03500,
        'MN' => .10000,
        _ => .00350,
      };
    }
    return switch (timeframe) {
      'M1' || 'M2' || 'M3' || 'M4' => .00005,
      'M5' => .00010,
      'M6' => .000075,
      'M10' || 'M12' || 'M15' || 'M30' => .00015,
      'M20' => .00020,
      'H1' => .00025,
      'H2' || 'H3' || 'H6' || 'H8' => .00075,
      'H4' => .00050,
      'H12' => .00150,
      'D1' => .00165,
      'W1' || 'MN' => .00345,
      _ => .00015,
    };
  }

  bool get _isXauUsdVideo2Reference =>
      symbol == 'XAUUSD' || symbol == 'XAUUSD+';

  bool get _isBtcUsdVideo2Reference => symbol == 'BTCUSD';

  bool get _isVideo2Reference =>
      loadingPlaceholder ||
      (_isXauUsdVideo2Reference && (timeframe == 'H1' || timeframe == 'H4')) ||
      (_isBtcUsdVideo2Reference && timeframe == 'H4');

  bool get _isAudNokReference => symbol == 'AUDNOK';

  bool get _isAudNokM1Reference =>
      _isAudNokReference && const {'M1', 'M2', 'M3', 'M4'}.contains(timeframe);

  double _audNokPathScale() => switch (timeframe) {
    'M5' || 'M6' || 'M10' || 'M12' => .00025,
    'M15' || 'M20' || 'M30' => .00035,
    'H1' || 'H2' || 'H3' => .00180,
    'H4' || 'H6' || 'H8' || 'H12' => .00400,
    'D1' => .00010,
    'W1' => .00035,
    'MN' => .00100,
    _ => .00025,
  };

  double _audNokDetailScale() => switch (timeframe) {
    'M1' || 'M2' || 'M3' || 'M4' => .00034,
    'M5' || 'M6' || 'M10' || 'M12' => .00045,
    'M15' || 'M20' || 'M30' => .00100,
    'H1' || 'H2' || 'H3' => .00120,
    'H4' || 'H6' || 'H8' || 'H12' => .00250,
    'D1' => .00300,
    'W1' => .01000,
    'MN' => .03000,
    _ => .00100,
  };

  double _audNokWickBase() => switch (timeframe) {
    'M1' || 'M2' || 'M3' || 'M4' => .00038,
    'M5' || 'M6' || 'M10' || 'M12' => .00055,
    'M15' || 'M20' || 'M30' => .00120,
    'H1' || 'H2' || 'H3' => .00140,
    'H4' || 'H6' || 'H8' || 'H12' => .00300,
    'D1' => .00400,
    'W1' => .01200,
    'MN' => .03000,
    _ => .00120,
  };
}
