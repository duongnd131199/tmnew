import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/chart/presentation/geometry/chart_geometry.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_hit_targets.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_render_snapshot.dart';
import 'package:trading_mobile/features/chart/presentation/theme/chart_reference_theme.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_price_viewport.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

class Mt5CandlePainter extends CustomPainter {
  static final LinkedHashMap<Object, ui.Picture> _gridPictureCache =
      LinkedHashMap<Object, ui.Picture>();
  static const _maxGridPictureCacheEntries = 32;
  static const geometry = ChartGeometry.canonical;

  Mt5CandlePainter({
    required this.snapshot,
    required this.symbol,
    required this.referencePrice,
    required this.currentPrice,
    required this.tickTime,
    required this.crosshairEnabled,
    required this.crosshairPosition,
    required this.measurementStart,
    required this.measurementEnd,
    required this.timeframe,
    required this.positions,
    required this.pendingOrders,
    required this.indicators,
    required this.chartObjects,
    required this.pendingOrderType,
    required this.pendingOrderPrice,
    required this.pendingOrderVolume,
    required this.pendingStopLoss,
    required this.pendingTakeProfit,
    required this.focusedChartPrice,
    required this.loadingPlaceholder,
    required this.oneClickTrading,
    required this.h4ExpandedScaleSeen,
    required this.showHistoryBadge,
    required this.useRealtimeCandles,
    required this.hitTargets,
  });

  final ChartRenderSnapshot snapshot;
  final String symbol;
  final double referencePrice;
  final double currentPrice;
  final DateTime tickTime;
  final bool crosshairEnabled;
  final Offset? crosshairPosition;
  final Offset? measurementStart;
  final Offset? measurementEnd;
  final String timeframe;
  final List<DemoPosition> positions;
  final List<DemoPendingOrder> pendingOrders;
  final Set<String> indicators;
  final List<DemoChartObject> chartObjects;
  final String? pendingOrderType;
  final double? pendingOrderPrice;
  final double pendingOrderVolume;
  final double? pendingStopLoss;
  final double? pendingTakeProfit;
  final double? focusedChartPrice;
  final bool loadingPlaceholder;
  final bool oneClickTrading;
  final bool h4ExpandedScaleSeen;
  final bool showHistoryBadge;
  final bool useRealtimeCandles;
  final ChartHitTargets hitTargets;
  final String referenceTextFamily = AppTypography.referencePlainFamily;
  List<MarketCandle> get candles => snapshot.resolvedCandles;
  List<MarketCandle> get liveTail => snapshot.liveTail;
  ChartViewport get viewport => snapshot.viewport;
  ChartPriceViewport get priceViewport => snapshot.priceViewport;
  ChartReferenceTheme get theme => snapshot.theme;
  Rect? _currentPriceBadgeRect;

  double? get pendingOrderY => hitTargets.pendingOrderY;
  double get chartMinPrice => hitTargets.minPrice;
  double get chartMaxPrice => hitTargets.maxPrice;
  Rect get chartFrameRect => hitTargets.chartFrameRect;
  Rect get priceGridRect => hitTargets.priceGridRect;
  Rect get priceAxisRect => hitTargets.priceAxisRect;
  Rect get timeAxisRect => hitTargets.timeAxisRect;
  TextStyle get debugTimeAxisTextStyle => _timeAxisTextStyle;
  List<MarketCandle> get debugResolvedCandles => resolvedCandles;
  Rect? get debugCurrentPriceBadgeRect => _currentPriceBadgeRect;
  int get visibleCandleCount => hitTargets.visibleCandles.length;
  int get visibleStartIndex => _visibleStartIndex;
  List<MarketCandle> get resolvedCandles => snapshot.resolvedCandles;
  int _visibleStartIndex = 0;

  static const _m1ReferencePath = <(double, double)>[
    (0, 4.37),
    (.010526, 3.17),
    (.021053, 3.33),
    (.031579, 3.33),
    (.042105, 2.35),
    (.052632, 2.24),
    (.063158, 1.34),
    (.073684, 1.31),
    (.084211, 1.31),
    (.094737, 1.87),
    (.105263, .49),
    (.115789, .49),
    (.126316, .67),
    (.136842, .79),
    (.147368, .82),
    (.157895, 1.98),
    (.168421, 1.72),
    (.178947, 1.72),
    (.189474, 2.06),
    (.2, .74),
    (.210526, .16),
    (.221053, -.22),
    (.231579, -.27),
    (.242105, -1.62),
    (.252632, -1.05),
    (.263158, -.31),
    (.273684, .44),
    (.284211, -.27),
    (.294737, -.27),
    (.305263, -.1),
    (.315789, -.1),
    (.326316, .48),
    (.336842, .46),
    (.347368, .67),
    (.357895, .66),
    (.368421, .64),
    (.378947, .66),
    (.389474, .7),
    (.4, .7),
    (.410526, .53),
    (.421053, -1.36),
    (.431579, -1.15),
    (.442105, -.9),
    (.452632, .91),
    (.463158, 1.32),
    (.473684, .48),
    (.484211, .3),
    (.494737, .3),
    (.505263, -.38),
    (.515789, -.27),
    (.526316, -.29),
    (.536842, -1.04),
    (.547368, .16),
    (.557895, -.07),
    (.568421, -.6),
    (.578947, -1.31),
    (.589474, -1.31),
    (.6, -1.31),
    (.610526, -2.32),
    (.621053, -2.22),
    (.631579, -2.1),
    (.642105, -2.99),
    (.652632, -3.17),
    (.663158, -3.29),
    (.673684, -2.44),
    (.684211, -3.29),
    (.694737, -3.44),
    (.705263, -3.44),
    (.715789, -2.5),
    (.726316, -2.09),
    (.736842, -1.87),
    (.747368, -1.8),
    (.757895, -1.8),
    (.768421, -1.8),
    (.778947, -1.53),
    (.789474, -.53),
    (.8, -.15),
    (.810526, -.15),
    (.821053, -.1),
    (.831579, 1.54),
    (.842105, .25),
    (.852632, 1.04),
    (.863158, .63),
    (.873684, .52),
    (.884211, 2.95),
    (.894737, 1.67),
    (.905263, 2.38),
    (.915789, 2.05),
    (.926316, 1.94),
    (.936842, 2.18),
    (.947368, 1.36),
    (.957895, 1.2),
    (.968421, .89),
    (.978947, .82),
    (.989474, .82),
    (1, -.3),
  ];

  static const _audNokM1ReferencePath = <(double, double)>[
    (0, .02210),
    (.015, .02178),
    (.048, .01934),
    (.081, .01817),
    (.113, .01701),
    (.146, .01858),
    (.179, .01925),
    (.212, .01867),
    (.244, .01861),
    (.277, .01685),
    (.310, .01202),
    (.343, .01128),
    (.375, .00865),
    (.408, .00885),
    (.441, .00973),
    (.473, .00724),
    (.506, .00736),
    (.539, .00867),
    (.572, .00730),
    (.604, .00741),
    (.637, .00630),
    (.670, .00703),
    (.702, .00577),
    (.735, .00618),
    (.768, .00598),
    (.801, .00610),
    (.833, .00481),
    (.866, .00299),
    (.899, .00100),
    (.931, .00073),
    (.964, -.00111),
    (.985, -.00045),
    (1, 0),
  ];

  static const _m5ReferencePath = <(double, double)>[
    (0, 3.98),
    (.0159, 10.95),
    (.0317, 14.32),
    (.0476, 14.32),
    (.0635, 11.94),
    (.0794, 12.75),
    (.0952, 12.00),
    (.1111, 13.91),
    (.1270, 10.58),
    (.1429, 10.92),
    (.1587, 13.02),
    (.1746, 14.86),
    (.1905, 14.59),
    (.2063, 14.04),
    (.2222, 12.75),
    (.2381, 12.41),
    (.2540, 15.47),
    (.2698, 12.41),
    (.2857, 11.19),
    (.3016, 8.67),
    (.3175, 8.26),
    (.3333, 6.53),
    (.3492, 6.53),
    (.3651, 8.26),
    (.3810, 9.59),
    (.3968, 9.62),
    (.4127, 8.81),
    (.4286, 8.13),
    (.4444, 10.24),
    (.4603, 12.28),
    (.4762, 11.19),
    (.4921, 11.56),
    (.5079, 11.60),
    (.5238, 10.64),
    (.5397, 10.64),
    (.5556, 8.13),
    (.5714, 7.92),
    (.5873, 7.69),
    (.6032, 7.65),
    (.6190, 6.39),
    (.6349, 5.13),
    (.6508, 3.30),
    (.6667, 3.33),
    (.6825, 1.26),
    (.6984, 1.94),
    (.7143, -1.05),
    (.7302, -.41),
    (.7460, .27),
    (.7619, .65),
    (.7778, .51),
    (.7937, .48),
    (.8095, -1.05),
    (.8254, -1.33),
    (.8413, -2.96),
    (.8571, -3.43),
    (.8730, -1.46),
    (.8889, .27),
    (.9048, .51),
    (.9206, 1.94),
    (.9365, .78),
    (.9524, 1.05),
    (.9683, -.03),
    (.9841, 0),
    (1, 0),
  ];

  static const _m30ReferencePath = <(double, double)>[
    (0, 111),
    (.05, 145),
    (.10, 105),
    (.18, 120),
    (.26, 94),
    (.34, 135),
    (.42, 104),
    (.50, 61),
    (.58, 91),
    (.66, 68),
    (.74, 7),
    (.82, 1),
    (.88, 35),
    (.93, 10),
    (1, 0),
  ];

  static const _dailyReferencePath = <(double, double)>[
    (0, 293.98),
    (.016949, 323.43),
    (.033898, 421.89),
    (.050847, 435.7),
    (.067797, 436.62),
    (.084746, 446.74),
    (.101695, 443.98),
    (.118644, 432.02),
    (.135593, 415.45),
    (.152542, 339.99),
    (.169492, 340.92),
    (.186441, 293.06),
    (.20339, 338.15),
    (.220339, 338.15),
    (.237288, 314.23),
    (.254237, 353.8),
    (.271186, 305.03),
    (.288136, 257.18),
    (.305085, 291.22),
    (.322034, 326.19),
    (.338983, 282.02),
    (.355932, 287.54),
    (.372881, 261.78),
    (.389831, 287.54),
    (.40678, 178.04),
    (.423729, 183.56),
    (.440678, 121.91),
    (.457627, -28.09),
    (.474576, 67.61),
    (.491525, 71.29),
    (.508475, 160.55),
    (.525424, 164.23),
    (.542373, 117.3),
    (.559322, 112.7),
    (.576271, 56.57),
    (.59322, 99.82),
    (.610169, 47.37),
    (.627119, -52.01),
    (.644068, -25.33),
    (.661017, 6.88),
    (.677966, -52.93),
    (.694915, -52.01),
    (.711864, -18.89),
    (.728814, 36.33),
    (.745763, 80.5),
    (.762712, 70.37),
    (.779661, 35.41),
    (.79661, 2.28),
    (.813559, 38.17),
    (.830508, 30.8),
    (.847458, -52.01),
    (.864407, -17.05),
    (.881356, -28.09),
    (.898305, -87.9),
    (.915254, -58.46),
    (.932203, -55.7),
    (.949153, 15.16),
    (.966102, 52.89),
    (.983051, -6),
    (1, 0),
  ];

  // Contours sampled from the H4/H1 viewports in the second reference video.
  // Values are price offsets from the live quote, not normalized pixels.
  static const _xauUsdH4Video2Path = <(double, double)>[
    (0.0000, 90.2),
    (.0182, 53.2),
    (.0547, 85.0),
    (.0693, 79.4),
    (.1204, -28.5),
    (.1350, -106.1),
    (.1430, -128.5),
    (.1720, -87.2),
    (.2007, -85.8),
    (.2226, -34.2),
    (.2445, -51.5),
    (.2737, -106.9),
    (.2956, -77.0),
    (.3175, -113.7),
    (.3321, -72.9),
    (.3467, -63.0),
    (.3905, 47.2),
    (.4197, 70.0),
    (.4416, 37.0),
    (.4781, 30.1),
    (.5219, -44.2),
    (.5584, 10.3),
    (.5730, 14.4),
    (.6095, -20.8),
    (.6460, -93.1),
    (.6533, -94.1),
    (.6752, -40.0),
    (.6898, -56.8),
    (.7263, -59.7),
    (.7701, -115.5),
    (.8139, -76.8),
    (.8358, -79.4),
    (.9015, 39.3),
    (.9234, 12.8),
    (.9453, -37.8),
    (.9599, -54.4),
    (.9818, -29.2),
    (1.0000, 0.0),
  ];

  static const _xauUsdH1Video2Path = <(double, double)>[
    (0, -77.5),
    (.0377, -67.6),
    (.0440, -102.8),
    (.0503, -112.5),
    (.0881, -130.5),
    (.1132, -114.4),
    (.1384, -123.4),
    (.1635, -106.3),
    (.1950, -130.6),
    (.2075, -87.2),
    (.2579, -110.9),
    (.2704, -77.7),
    (.2893, -83.0),
    (.2956, -97.3),
    (.3208, -79.8),
    (.3459, -99.0),
    (.4025, -98.4),
    (.4088, -71.5),
    (.4403, -26.1),
    (.4843, -49.1),
    (.4969, -27.1),
    (.5472, -21.5),
    (.5660, 28.5),
    (.5786, 28.2),
    (.5849, 11.5),
    (.6101, 12.8),
    (.6372, 30.6),
    (.6435, 52.8),
    (.6561, 52.8),
    (.6792, 16.5),
    (.7358, 10.6),
    (.7421, -13.4),
    (.7610, -16.1),
    (.7736, -57.9),
    (.8239, -53.8),
    (.8636, -78.7),
    (.8825, -79.0),
    (.8888, -53.9),
    (.9182, -50.5),
    (.9245, -36.5),
    (.9686, -51.3),
    (.9811, -9.1),
    (1, 0),
  ];

  // The H1 reference contains a handful of characteristic long wicks that
  // cannot be reproduced by a uniform procedural wick. Values are price
  // distances beyond the candle body for the 160-candle canonical window.
  static const _xauUsdH1Video2WickShocks =
      <int, ({double upper, double lower})>{
        8: (upper: 42.3, lower: 18.0),
        14: (upper: 21.0, lower: 0),
        22: (upper: 22.8, lower: 0),
        31: (upper: 30.6, lower: 18.8),
        32: (upper: 30.6, lower: 22.3),
        42: (upper: 19.5, lower: 10.3),
        52: (upper: 17.0, lower: 0),
        67: (upper: 0, lower: 17.9),
        70: (upper: 0, lower: 17.2),
        79: (upper: 0, lower: 17.4),
        82: (upper: 0, lower: 11.2),
        100: (upper: 0, lower: 18.6),
        102: (upper: 16.0, lower: 23.0),
        111: (upper: 20.9, lower: 0),
        112: (upper: 21.6, lower: 0),
        123: (upper: 31.4, lower: 5.5),
        124: (upper: 32.6, lower: 5.5),
        141: (upper: 0, lower: 14.9),
        147: (upper: 14.0, lower: 10.5),
        157: (upper: 19.5, lower: 0),
      };

  static const _xauUsdH4Video2WickShocks =
      <int, ({double upper, double lower})>{
        2: (upper: 27.0, lower: 40.0),
        10: (upper: 0, lower: 25.0),
        19: (upper: 0, lower: 31.0),
        40: (upper: 32.5, lower: 37.0),
        52: (upper: 0, lower: 32.0),
        67: (upper: 0, lower: 69.5),
        80: (upper: 0, lower: 19.0),
        91: (upper: 23.0, lower: 51.0),
        108: (upper: 35.0, lower: 23.0),
        124: (upper: 20.0, lower: 0),
      };

  static List<(double, double)> get fallbackM1ReferencePath => _m1ReferencePath;
  static List<(double, double)> get fallbackAudNokM1ReferencePath =>
      _audNokM1ReferencePath;
  static List<(double, double)> get fallbackM5ReferencePath => _m5ReferencePath;
  static List<(double, double)> get fallbackM30ReferencePath =>
      _m30ReferencePath;
  static List<(double, double)> get fallbackDailyReferencePath =>
      _dailyReferencePath;
  static List<(double, double)> get fallbackXauUsdH1Video2Path =>
      _xauUsdH1Video2Path;
  static List<(double, double)> get fallbackXauUsdH4Video2Path =>
      _xauUsdH4Video2Path;
  static List<(double, double)> get fallbackBtcUsdH4Video2Path =>
      _btcUsdH4Video2Path;
  static Map<int, ({double upper, double lower})>
  get fallbackXauUsdH1WickShocks => _xauUsdH1Video2WickShocks;
  static Map<int, ({double upper, double lower})>
  get fallbackXauUsdH4WickShocks => _xauUsdH4Video2WickShocks;

  static const _btcUsdH4Video2Path = <(double, double)>[
    (0, -5800),
    (.025, -4800),
    (.055, -3900),
    (.10, -2800),
    (.15, -2200),
    (.20, -1500),
    (.25, -3600),
    (.30, -2500),
    (.35, -1700),
    (.40, -1000),
    (.47, -3300),
    (.52, -1700),
    (.56, 200),
    (.60, -1500),
    (.64, -2500),
    (.69, -700),
    (.75, -100),
    (.80, 1400),
    (.84, 900),
    (.88, -900),
    (.91, -2200),
    (.95, -1300),
    (1, 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _currentPriceBadgeRect = null;
    final legacyAxisWidth = loadingPlaceholder
        ? 62 + 2 / 3
        : _isBtcUsdVideo2Reference && timeframe == 'H4'
        ? 72.0
        : _isXauUsdVideo2Reference && timeframe == 'H1'
        ? 63 + 1 / 3
        : _usesVideo2ChartChrome
        ? 67 + 1 / 3
        : 55.0;
    final usesM1ReferenceChrome = _isXauUsdVideo2Reference && timeframe == 'M1';
    final axisWidth = _usesVideo2ChartChrome
        ? usesM1ReferenceChrome
              ? geometry.m1PriceAxisWidthFor(size.width)
              : geometry.priceAxisWidthFor(size.width)
        : legacyAxisWidth;
    final bottomAxis = _usesVideo2ChartChrome ? geometry.timeAxisHeight : 20.0;
    final chartWidth = size.width - axisWidth;
    final chartHeight = size.height - bottomAxis;
    final gridPitch = usesM1ReferenceChrome
        ? geometry.m1TargetGridPitch
        : geometry.targetGridPitch;
    final priceTop = _usesVideo2ChartChrome
        ? usesM1ReferenceChrome
              ? geometry.m1HeaderHeight
              : geometry.headerHeight
        : 0.0;
    final horizontalDivisions = math.max(
      2,
      ((chartHeight - priceTop) / gridPitch).round(),
    );
    final priceScaleDivisions = math.max(
      2,
      ((chartHeight - priceTop) / (gridPitch / ChartGeometry.gridCellScale))
          .round(),
    );
    // The native chart keeps a header strip inside the canvas. Its visible
    // price scale starts 38 physical pixels below the frame and the final
    // (17th) interval continues below the clipped viewport.
    final priceHeight = _usesVideo2ChartChrome
        ? chartHeight - priceTop
        : chartHeight;
    hitTargets
      ..chartWidth = chartWidth
      ..chartHeight = chartHeight
      ..priceTop = priceTop
      ..priceHeight = priceHeight
      ..chartFrameRect = Rect.fromLTWH(0, 0, chartWidth, chartHeight)
      ..priceGridRect = Rect.fromLTWH(
        0,
        priceTop,
        chartWidth,
        chartHeight - priceTop,
      )
      ..priceAxisRect = Rect.fromLTWH(chartWidth, 0, axisWidth, chartHeight)
      ..timeAxisRect = Rect.fromLTWH(0, chartHeight, size.width, bottomAxis)
      ..crosshairTimeLabel = null
      ..historyBadgeLabel = null
      ..pendingOrderY = null;
    hitTargets
      ..positionOverlays = const []
      ..positionLabelRects = const []
      ..positionPriceTagLayouts = const []
      ..pendingOrderOverlays = const []
      ..horizontalGridYs = const []
      ..verticalGridXs = const []
      ..priceAxisLabels = const [];
    final grid = Paint()
      ..color = theme.grid.withValues(alpha: ChartGeometry.gridOpacity)
      ..strokeWidth = .65;
    final gridDash = _usesVideo2ChartChrome ? 3.0 : 4.0;
    final gridGap = _usesVideo2ChartChrome ? 2.5 : 4.0;

    final firstVerticalGrid = _usesVideo2ChartChrome
        ? (usesM1ReferenceChrome
                  ? geometry.m1GridOriginInset
                  : geometry.gridOriginInset) /
              chartWidth
        : .048;
    final verticalGridStep = _usesVideo2ChartChrome
        ? gridPitch / chartWidth
        : .130;
    hitTargets
      ..horizontalGridYs = List<double>.unmodifiable([
        for (var row = 0; row < horizontalDivisions; row++)
          priceTop + priceHeight * row / horizontalDivisions,
      ])
      ..verticalGridXs = List<double>.unmodifiable([
        for (
          var x = chartWidth * firstVerticalGrid;
          x < chartWidth;
          x += chartWidth * verticalGridStep
        )
          x,
      ]);
    _drawCachedBackgroundAndGrid(
      canvas: canvas,
      size: size,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      priceTop: priceTop,
      priceHeight: priceHeight,
      horizontalDivisions: horizontalDivisions,
      firstVerticalGrid: firstVerticalGrid,
      verticalGridStep: verticalGridStep,
      grid: grid,
      gridDash: gridDash,
      gridGap: gridGap,
    );

    // Preserve the supplied contour as the visual seed, then overlay the
    // quote-built tail so the active candle and rollover are truly live.
    final resolved = resolvedCandles;
    final allCandles = resolved.isEmpty
        ? <MarketCandle>[
            MarketCandle(
              time: tickTime,
              open: currentPrice,
              high: currentPrice,
              low: currentPrice,
              close: currentPrice,
            ),
          ]
        : resolved;
    final boundedViewport = viewport.bounded(
      plotWidth: chartWidth,
      candleCount: allCandles.length,
    );
    final start = boundedViewport.visibleStartIndex(
      plotWidth: chartWidth,
      candleCount: allCandles.length,
    );
    final end = boundedViewport.visibleEndIndex(
      plotWidth: chartWidth,
      candleCount: allCandles.length,
    );
    _visibleStartIndex = start;
    final visible = allCandles.sublist(start, end + 1);
    final dataMin = visible.map((item) => item.low).reduce(math.min);
    final dataMax = visible.map((item) => item.high).reduce(math.max);
    final visibleMagnitude = math.max(dataMin.abs(), dataMax.abs());
    final rawRange = math.max(dataMax - dataMin, visibleMagnitude * .0004);
    final priceStep = _nicePriceStep(rawRange * 1.12 / priceScaleDivisions);
    final axisRange = priceStep * priceScaleDivisions;
    final scaleCenter = focusedChartPrice ?? (dataMin + dataMax) * .5;
    final automaticMaxPrice = scaleCenter + axisRange * .5;
    final automaticMinPrice = automaticMaxPrice - axisRange;
    final resolvedPriceRange = priceViewport.resolve(
      ChartPriceRange(minPrice: automaticMinPrice, maxPrice: automaticMaxPrice),
    );
    final maxPrice = resolvedPriceRange.maxPrice;
    final minPrice = resolvedPriceRange.minPrice;
    hitTargets
      ..minPrice = minPrice
      ..maxPrice = maxPrice;
    final priceRange = maxPrice - minPrice;
    double priceToY(double price) =>
        priceTop + (maxPrice - price) / priceRange * priceHeight;

    final values = visible
        .map((item) => priceToY(item.close) / chartHeight)
        .toList();
    final candleWidth = boundedViewport.barSpacing;
    final firstCandleCenterX = boundedViewport.candleCenterX(
      candleIndex: start,
      plotWidth: chartWidth,
      candleCount: allCandles.length,
    );
    hitTargets
      ..visibleCandles = List<MarketCandle>.unmodifiable(visible)
      ..candleWidth = candleWidth
      ..candleBodyWidth = candleWidth * geometry.candleBodyRatio
      ..firstCandleCenterX = firstCandleCenterX;
    if (!loadingPlaceholder) {
      for (var i = 0; i < visible.length; i++) {
        final candle = visible[i];
        final rising = candle.close >= candle.open;
        final paint = Paint()..color = rising ? theme.bullish : theme.bearish;
        final x = firstCandleCenterX + candleWidth * i;
        final openY = priceToY(candle.open);
        final closeY = priceToY(candle.close);
        canvas.drawLine(
          Offset(x, priceToY(candle.high)),
          Offset(x, priceToY(candle.low)),
          paint..strokeWidth = geometry.wickWidth,
        );
        canvas.drawRect(
          Rect.fromLTRB(
            x - hitTargets.candleBodyWidth / 2,
            math.min(openY, closeY),
            x + hitTargets.candleBodyWidth / 2,
            math.max(openY, closeY) + 1.2,
          ),
          paint,
        );
      }
    }

    final visiblePositions = <(DemoPosition, double)>[];
    final visiblePositionLabels = <Rect>[];
    for (final position
        in loadingPlaceholder ? const <DemoPosition>[] : positions) {
      final y = priceToY(position.openPrice);
      if (y < 0 || y > chartHeight) continue;
      visiblePositions.add((position, y));
      visiblePositionLabels.add(_positionLine(canvas, chartWidth, y, position));
      if (!_usesVideo2ChartChrome) {
        final color = position.side == 'BUY' ? theme.tradeBlue : theme.tradeRed;
        _positionMarker(canvas, chartWidth - 8, y, color, position.side);
      }
    }
    hitTargets.positionOverlays = List.unmodifiable(
      visiblePositions.map(
        (entry) => (
          label: '${entry.$1.side} ${entry.$1.volume.toStringAsFixed(2)}',
          y: entry.$2,
        ),
      ),
    );
    hitTargets.positionLabelRects = List.unmodifiable(visiblePositionLabels);

    final visiblePendingLevels = <(double, double)>[];
    final visiblePendingOverlays = <({String label, double y})>[];
    void drawPendingLevel(
      String type,
      double price,
      double orderVolume, {
      required bool interactive,
    }) {
      final rawY = priceToY(price);
      final y = rawY
          .clamp(priceTop, math.max(priceTop, chartHeight - 1))
          .toDouble();
      if (y >= 0 && y <= chartHeight) {
        visiblePendingLevels.add((y, price));
        visiblePendingOverlays.add((
          label: '${type.toUpperCase()} ${orderVolume.toStringAsFixed(2)}',
          y: y,
        ));
        if (interactive) hitTargets.pendingOrderY = y;
        canvas.drawLine(
          Offset(0, y),
          Offset(chartWidth, y),
          Paint()
            ..color = theme.tradeBlue
            ..strokeWidth = .8,
        );
        _text(
          canvas,
          '${type.toUpperCase()} ${orderVolume.toStringAsFixed(2)}',
          Offset(
            _usesVideo2ChartChrome ? 5 : 2,
            y - (_usesVideo2ChartChrome ? 16.3333333333 : 11),
          ),
          AppTypography.chartAnnotation.copyWith(
            color: theme.tradeBlue,
            fontSize: _usesVideo2ChartChrome ? 14 : 9,
          ),
        );
        canvas.drawCircle(
          Offset(chartWidth / 2, y),
          4.5,
          Paint()
            ..color = theme.background
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(chartWidth / 2, y),
          4.5,
          Paint()
            ..color = theme.tradeBlue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    if (pendingOrderType != null && pendingOrderPrice != null) {
      drawPendingLevel(
        pendingOrderType!,
        pendingOrderPrice!,
        pendingOrderVolume,
        interactive: true,
      );
    }
    for (final order in pendingOrders.skip(1)) {
      drawPendingLevel(
        order.type,
        order.price,
        order.volume,
        interactive: false,
      );
    }
    hitTargets.pendingOrderOverlays = List.unmodifiable(visiblePendingOverlays);
    final visiblePendingProtections = <(double, double, String, Color)>[];
    void drawPendingProtection(double? price, String label, Color color) {
      if (price == null) return;
      final y = priceToY(price);
      if (y < 0 || y > chartHeight) return;
      visiblePendingProtections.add((y, price, label, color));
      _dashedLine(
        canvas,
        Offset(0, y),
        Offset(chartWidth, y),
        Paint()
          ..color = color
          ..strokeWidth = 1,
        5,
        3,
      );
      _text(
        canvas,
        '$label ${price >= 1000 ? price.toStringAsFixed(2) : price.toStringAsFixed(5)}',
        Offset(_usesVideo2ChartChrome ? 5 : 2, y - 15),
        AppTypography.chartAnnotation.copyWith(
          color: color,
          fontSize: _usesVideo2ChartChrome ? 12.5 : 9,
        ),
      );
    }

    if (pendingOrderType != null && pendingOrderPrice != null) {
      drawPendingProtection(pendingStopLoss, 'SL', theme.tradeRed);
      drawPendingProtection(pendingTakeProfit, 'TP', theme.tradeBlue);
    }
    for (final order in pendingOrders.skip(1)) {
      drawPendingProtection(order.stopLoss, 'SL', theme.tradeRed);
      drawPendingProtection(order.takeProfit, 'TP', theme.tradeBlue);
    }

    if (indicators.contains('Moving Average')) {
      _movingAverage(
        canvas,
        values,
        firstCandleCenterX,
        candleWidth,
        chartHeight,
      );
    }
    if (indicators.contains('Bollinger Bands')) {
      _bollingerBands(
        canvas,
        values,
        firstCandleCenterX,
        candleWidth,
        chartHeight,
      );
    }
    if (indicators.contains('Relative Strength Index')) {
      _rsi(canvas, chartWidth, chartHeight);
    }
    if (chartObjects.isNotEmpty) {
      _drawChartObjects(canvas, chartWidth, priceTop, priceHeight);
    }

    final currentY = priceToY(currentPrice);
    final currentPriceIsVisible =
        currentPrice >= minPrice && currentPrice <= maxPrice;
    final currentPricePaint = Paint()
      ..color = theme.priceLine
      ..strokeWidth = .67;
    if (!loadingPlaceholder &&
        currentPriceIsVisible &&
        _usesVideo2ChartChrome) {
      _dashedLine(
        canvas,
        Offset(0, currentY),
        Offset(chartWidth, currentY),
        currentPricePaint,
        1.5,
        1.5,
      );
    } else if (!loadingPlaceholder && currentPriceIsVisible) {
      canvas.drawLine(
        Offset(0, currentY),
        Offset(chartWidth, currentY),
        currentPricePaint,
      );
    }
    _axisLabels(
      canvas,
      chartWidth,
      chartHeight,
      priceTop,
      priceHeight,
      minPrice,
      maxPrice,
    );
    final positionPriceTagLayouts = <({Rect frame, Offset textOrigin})>[];
    if (!loadingPlaceholder) {
      for (final pendingLevel in visiblePendingLevels) {
        positionPriceTagLayouts.add(
          _positionPriceTag(
            canvas,
            chartWidth,
            pendingLevel.$1,
            pendingLevel.$2,
            theme.tradeBlue,
          ),
        );
      }
    }
    if (!loadingPlaceholder) {
      for (final protection in visiblePendingProtections) {
        positionPriceTagLayouts.add(
          _positionPriceTag(
            canvas,
            chartWidth,
            protection.$1,
            protection.$2,
            protection.$4,
          ),
        );
      }
    }
    for (final entry
        in loadingPlaceholder
            ? const <(DemoPosition, double)>[]
            : visiblePositions) {
      final position = entry.$1;
      final y = entry.$2;
      positionPriceTagLayouts.add(
        _positionPriceTag(
          canvas,
          chartWidth,
          y,
          position.openPrice,
          position.side == 'BUY' ? theme.tradeBlue : theme.tradeRed,
        ),
      );
    }
    hitTargets.positionPriceTagLayouts = List.unmodifiable(
      positionPriceTagLayouts,
    );
    if (!loadingPlaceholder && currentPriceIsVisible) {
      _priceTag(canvas, chartWidth, currentY);
    }
    _timeLabels(canvas, chartWidth, chartHeight, visible);
    _chartFrameBorders(canvas, chartWidth, chartHeight);
    if (crosshairEnabled) {
      if (measurementStart != null && measurementEnd != null) {
        _drawMeasurement(
          canvas,
          chartWidth,
          chartHeight,
          priceTop,
          priceHeight,
          minPrice,
          maxPrice,
          visible,
        );
      }
      _drawCrosshair(
        canvas,
        chartWidth,
        chartHeight,
        priceTop,
        priceHeight,
        minPrice,
        maxPrice,
        visible,
      );
    }
  }

  void _movingAverage(
    Canvas canvas,
    List<double> values,
    double firstCandleCenterX,
    double candleWidth,
    double height,
  ) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final from = math.max(0, i - 4);
      final average =
          values.sublist(from, i + 1).reduce((a, b) => a + b) / (i - from + 1);
      final point = Offset(
        firstCandleCenterX + candleWidth * i,
        average * height,
      );
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = theme.tradeBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _bollingerBands(
    Canvas canvas,
    List<double> values,
    double firstCandleCenterX,
    double candleWidth,
    double height,
  ) {
    for (final offset in const [-.08, .08]) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final point = Offset(
          firstCandleCenterX + candleWidth * i,
          (values[i] + offset).clamp(.03, .97) * height,
        );
        i == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(theme.tradeBlue, theme.bearish, .42)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = .9,
      );
    }
  }

  void _rsi(Canvas canvas, double width, double height) {
    final top = height * .87;
    canvas.drawRect(
      Rect.fromLTWH(0, top, width, height - top),
      Paint()..color = theme.tradeBlue.withValues(alpha: .06),
    );
    final path = Path()..moveTo(0, top + 18);
    for (var i = 1; i < 20; i++) {
      path.lineTo(width * i / 19, top + 16 + math.sin(i * .8) * 10);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(theme.tradeBlue, theme.bearish, .5)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    _text(
      canvas,
      'RSI(14)',
      Offset(5, top + 3),
      AppTypography.chartAnnotation.copyWith(
        color: Color.lerp(theme.tradeBlue, theme.bearish, .5),
        fontSize: 9,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  void _drawChartObjects(
    Canvas canvas,
    double width,
    double priceTop,
    double priceHeight,
  ) {
    final objectPaint = Paint()
      ..color = theme.tradeBlue.withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final handleFill = Paint()
      ..color = theme.background
      ..style = PaintingStyle.fill;
    final handleStroke = Paint()
      ..color = theme.tradeBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var index = 0; index < chartObjects.length; index++) {
      final object = chartObjects[index];
      final lane = index % 5;
      final x1 = width * (.16 + lane * .055);
      final x2 = width * (.72 + lane * .035);
      final y1 = priceTop + priceHeight * (.22 + lane * .09);
      final y2 = priceTop + priceHeight * (.56 - lane * .035);
      final type = object.type.toLowerCase();
      final handles = <Offset>[];

      if (type.contains('ngang')) {
        final y = priceTop + priceHeight * (.28 + lane * .11);
        canvas.drawLine(Offset(0, y), Offset(width, y), objectPaint);
        handles.addAll([Offset(x1, y), Offset(x2, y)]);
      } else if (type.contains('dọc')) {
        final x = width * (.24 + lane * .12);
        canvas.drawLine(
          Offset(x, priceTop),
          Offset(x, priceTop + priceHeight),
          objectPaint,
        );
        handles.addAll([Offset(x, y1), Offset(x, y2)]);
      } else if (type.contains('chữ nhật')) {
        final rect = Rect.fromPoints(Offset(x1, y1), Offset(x2, y2));
        canvas.drawRect(rect, objectPaint);
        handles.addAll([rect.topLeft, rect.bottomRight]);
      } else if (type.contains('đa đoạn')) {
        final midpoint = Offset((x1 + x2) / 2, y1 - priceHeight * .11);
        canvas.drawPath(
          Path()
            ..moveTo(x1, y2)
            ..lineTo(midpoint.dx, midpoint.dy)
            ..lineTo(x2, y2 - priceHeight * .08),
          objectPaint,
        );
        handles.addAll([Offset(x1, y2), midpoint, Offset(x2, y2)]);
      } else if (type.contains('thước')) {
        const separation = 7.0;
        canvas
          ..drawLine(Offset(x1, y2 - separation), Offset(x2, y1), objectPaint)
          ..drawLine(
            Offset(x1, y2 + separation),
            Offset(x2, y1 + separation * 2),
            objectPaint,
          );
        handles.addAll([Offset(x1, y2), Offset(x2, y1 + separation)]);
      } else if (type.contains('mũi tên')) {
        final start = Offset(x1, y2);
        final end = Offset(x2, y1);
        canvas.drawLine(start, end, objectPaint);
        final direction = (end - start) / (end - start).distance;
        final normal = Offset(-direction.dy, direction.dx);
        canvas.drawPath(
          Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(
              end.dx - direction.dx * 10 + normal.dx * 4,
              end.dy - direction.dy * 10 + normal.dy * 4,
            )
            ..moveTo(end.dx, end.dy)
            ..lineTo(
              end.dx - direction.dx * 10 - normal.dx * 4,
              end.dy - direction.dy * 10 - normal.dy * 4,
            ),
          objectPaint,
        );
        handles.addAll([start, end]);
      } else if (type.contains('văn bản')) {
        _text(
          canvas,
          object.type,
          Offset(x1, y1),
          AppTypography.chartAnnotation.copyWith(
            color: theme.tradeBlue,
            fontSize: 11,
          ),
        );
        handles.add(Offset(x1, y1));
      } else {
        canvas.drawLine(Offset(x1, y2), Offset(x2, y1), objectPaint);
        handles.addAll([Offset(x1, y2), Offset(x2, y1)]);
      }

      if (!object.locked) {
        for (final handle in handles) {
          canvas
            ..drawCircle(handle, 3.25, handleFill)
            ..drawCircle(handle, 3.25, handleStroke);
        }
      }
    }
  }

  void _chartFrameBorders(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
  ) {
    final border = Paint()
      ..color = theme.axisBorder
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chartWidth - .5, 0),
      Offset(chartWidth - .5, chartHeight),
      border,
    );
    canvas.drawLine(Offset(.5, 0), Offset(.5, chartHeight), border);
    canvas.drawLine(Offset(0, .5), Offset(chartWidth, .5), border);
    canvas.drawLine(
      Offset(0, chartHeight - .5),
      Offset(chartWidth, chartHeight - .5),
      border,
    );
  }

  void _drawCrosshair(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
    double priceTop,
    double priceHeight,
    double minPrice,
    double maxPrice,
    List<MarketCandle> visible,
  ) {
    final source =
        crosshairPosition ??
        Offset(chartWidth * .48, priceTop + priceHeight * .47);
    final point = Offset(
      source.dx.clamp(0, chartWidth),
      source.dy.clamp(0, chartHeight),
    );
    final paint = Paint()
      ..color = theme.foreground.withValues(alpha: .65)
      ..strokeWidth = .7;
    _dashedLine(
      canvas,
      Offset(point.dx, 0),
      Offset(point.dx, chartHeight),
      paint,
      4,
      3,
    );
    _dashedLine(
      canvas,
      Offset(0, point.dy),
      Offset(chartWidth, point.dy),
      paint,
      4,
      3,
    );
    final blue = Paint()
      ..color = theme.tradeBlue
      ..strokeWidth = 1.2;
    canvas.drawLine(point.translate(-10, 0), point.translate(-3, 0), blue);
    canvas.drawLine(point.translate(3, 0), point.translate(10, 0), blue);
    canvas.drawLine(point.translate(0, -10), point.translate(0, -3), blue);
    canvas.drawLine(point.translate(0, 3), point.translate(0, 10), blue);
    final price =
        maxPrice -
        ((point.dy.clamp(priceTop, chartHeight) - priceTop) / priceHeight) *
            (maxPrice - minPrice);
    final formattedPrice = price >= 1000
        ? price.toStringAsFixed(2)
        : price >= 100
        ? price.toStringAsFixed(3)
        : price.toStringAsFixed(5);
    canvas.drawRect(
      Rect.fromLTWH(chartWidth + 2, point.dy - 10, 67, 21),
      Paint()..color = theme.foreground.withValues(alpha: .62),
    );
    _text(
      canvas,
      formattedPrice,
      Offset(chartWidth + 5, point.dy - 7),
      AppTypography.chartAxis.copyWith(color: theme.background, fontSize: 10.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(point.dx - 58, chartHeight + 3, 116, 20),
      Paint()..color = theme.foreground.withValues(alpha: .62),
    );
    final timeIndex = hitTargets.visibleCandleIndex(point.dx);
    final timeLabel = _formatCrosshairTime(visible[timeIndex].time);
    hitTargets.crosshairTimeLabel = timeLabel;
    _text(
      canvas,
      timeLabel,
      Offset(point.dx - 54, chartHeight + 5),
      AppTypography.chartTimeAxis.copyWith(
        color: theme.background,
        fontSize: 10,
      ),
    );
  }

  void _drawMeasurement(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
    double priceTop,
    double priceHeight,
    double minPrice,
    double maxPrice,
    List<MarketCandle> visible,
  ) {
    final start = Offset(
      measurementStart!.dx.clamp(0, chartWidth),
      measurementStart!.dy.clamp(0, chartHeight),
    );
    final end = Offset(
      measurementEnd!.dx.clamp(0, chartWidth),
      measurementEnd!.dy.clamp(0, chartHeight),
    );
    final rectangle = Rect.fromPoints(start, end);
    if (rectangle.width < 2 || rectangle.height < 2) return;

    canvas.drawRect(
      rectangle,
      Paint()..color = theme.tradeBlue.withValues(alpha: .2),
    );
    final border = Paint()
      ..color = theme.tradeBlue
      ..strokeWidth = .8;
    _dashedLine(canvas, rectangle.topLeft, rectangle.topRight, border, 3, 2);
    _dashedLine(
      canvas,
      rectangle.bottomLeft,
      rectangle.bottomRight,
      border,
      3,
      2,
    );
    _dashedLine(canvas, rectangle.topLeft, rectangle.bottomLeft, border, 3, 2);
    _dashedLine(
      canvas,
      rectangle.topRight,
      rectangle.bottomRight,
      border,
      3,
      2,
    );

    double priceAt(double y) =>
        maxPrice -
        ((y.clamp(priceTop, chartHeight) - priceTop) / priceHeight) *
            (maxPrice - minPrice);
    final startPrice = priceAt(start.dy);
    final endPrice = priceAt(end.dy);
    final difference = endPrice - startPrice;
    final multiplier = currentPrice >= 1000
        ? 100
        : currentPrice >= 100
        ? 1000
        : 100000;
    final points = (difference.abs() * multiplier).round();
    final percent = startPrice == 0 ? 0 : difference / startPrice * 100;
    final bars = math.max(
      1,
      (rectangle.width / chartWidth * math.max(1, visible.length - 1)).round(),
    );
    final sign = percent >= 0 ? '+' : '';
    _text(
      canvas,
      '$points points ($sign${percent.toStringAsFixed(2)}%), $bars bars',
      Offset(rectangle.left + 3, math.max(2, rectangle.top + 3)),
      AppTypography.chartAnnotation.copyWith(
        color: theme.foreground.withValues(alpha: .62),
        fontSize: 8.5,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  void _axisLabels(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
    double priceTop,
    double priceHeight,
    double minPrice,
    double maxPrice,
  ) {
    final usesM1ReferenceChrome = _isXauUsdVideo2Reference && timeframe == 'M1';
    canvas.drawRect(
      Rect.fromLTWH(chartWidth, 0, 80, chartHeight),
      Paint()..color = theme.background,
    );
    final labels = <({String text, double y})>[];
    for (var index = 0; index < ChartGeometry.priceAxisTickCount; index++) {
      final y =
          priceTop + priceHeight * index / ChartGeometry.priceAxisTickCount;
      final fraction = ((y - priceTop) / priceHeight).clamp(0.0, 1.0);
      final value = maxPrice - (maxPrice - minPrice) * fraction;
      final text = value >= 1000
          ? value.toStringAsFixed(2)
          : value >= 100
          ? value.toStringAsFixed(3)
          : value.toStringAsFixed(5);
      _text(
        canvas,
        text,
        Offset(
          chartWidth +
              (usesM1ReferenceChrome
                  ? geometry.m1AxisLabelInset
                  : geometry.axisLabelInset),
          y -
              (_usesVideo2ChartChrome
                  ? usesM1ReferenceChrome
                        ? 3.5
                        : 7.5
                  : 6),
        ),
        AppTypography.chartAxis.copyWith(
          color: _axisTextColor,
          fontSize: _usesVideo2ChartChrome ? 12.5 : 9,
          letterSpacing: usesM1ReferenceChrome ? .2 : null,
        ),
      );
      labels.add((text: text, y: y));
    }
    hitTargets.priceAxisLabels = List.unmodifiable(labels);
  }

  void _timeLabels(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
    List<MarketCandle> visible,
  ) {
    if (_usesVideo2ChartChrome) {
      final usesM1ReferenceChrome =
          _isXauUsdVideo2Reference && timeframe == 'M1';
      final timeLabelInset = usesM1ReferenceChrome
          ? geometry.m1TimeLabelInset
          : geometry.timeLabelInset;
      final timeLabelPitch = usesM1ReferenceChrome
          ? geometry.m1TimeLabelPitch
          : geometry.timeLabelPitch;
      final labelXs = <double>[
        for (var x = timeLabelInset; x < chartWidth; x += timeLabelPitch) x,
      ];
      final labels = <String>[];
      final labelOrigins = <Offset>[];
      final anchors = <({double x, String text, DateTime candleTime})>[];
      for (var index = 0; index < labelXs.length; index++) {
        final x = labelXs[index];
        final candleIndex = hitTargets.visibleCandleIndex(x);
        final label = _formatCompactAxisTime(visible[candleIndex].time, index);
        final labelOrigin = Offset(
          x,
          chartHeight + (usesM1ReferenceChrome ? 0 : 2),
        );
        labels.add(label);
        labelOrigins.add(labelOrigin);
        anchors.add((x: x, text: label, candleTime: visible[candleIndex].time));
        _text(canvas, label, labelOrigin, _timeAxisTextStyle);
      }
      hitTargets.timeAxisLabels = List<String>.unmodifiable(labels);
      hitTargets.timeAxisLabelOrigins = List<Offset>.unmodifiable(labelOrigins);
      hitTargets.timeAxisLabelAnchors = List.unmodifiable(anchors);
      return;
    }
    final xFractions = loadingPlaceholder
        ? const [0.0, 2 / 7, 4 / 7, 6 / 7]
        : _isBtcUsdVideo2Reference && timeframe == 'H4'
        ? const [.07180, .36764, .66348, .95932]
        : _isXauUsdVideo2Reference && timeframe == 'H4'
        ? const [.072895, .365, .652895, .946316]
        : _usesVideo2ChartChrome
        ? const [.075, .365, .655, .94]
        : const [.016, .276, .536, .796];
    final usesXauVideo2TimeLabels =
        _isXauUsdVideo2Reference && (timeframe == 'H1' || timeframe == 'H4');
    final usesCompactVideo2TimeLabels =
        loadingPlaceholder || (_isBtcUsdVideo2Reference && timeframe == 'H4');
    final standardTimeLabelStyle = AppTypography.chartTimeAxis.copyWith(
      color: _axisTextColor,
      fontSize: _usesVideo2ChartChrome
          ? usesCompactVideo2TimeLabels
                ? 11.5
                : 14
          : 9,
      letterSpacing: _usesVideo2ChartChrome && !usesCompactVideo2TimeLabels
          ? .45
          : null,
    );
    final standardTimeLabelY =
        chartHeight +
        (_usesVideo2ChartChrome
            ? usesXauVideo2TimeLabels
                  ? 1.6666666667
                  : usesCompactVideo2TimeLabels
                  ? loadingPlaceholder
                        ? 3
                        : 2.3
                  : 1.6666666667
            : 7);
    final labelXs = timeframe == 'MN'
        ? <double>[chartWidth * .65]
        : timeframe == 'W1'
        ? <double>[chartWidth / 8, chartWidth * 3 / 8, chartWidth * 5 / 8]
        : <double>[
            for (final fraction in xFractions) chartWidth * fraction + 3,
          ];
    final labels = <String>[];
    final labelOrigins = <Offset>[];
    final anchors = <({double x, String text, DateTime candleTime})>[];
    for (var i = 0; i < labelXs.length; i++) {
      final x = labelXs[i];
      final index = hitTargets.visibleCandleIndex(x);
      final label = _formatAxisTime(visible[index].time, first: i == 0);
      final labelOrigin = Offset(x, standardTimeLabelY);
      labels.add(label);
      labelOrigins.add(labelOrigin);
      anchors.add((x: x, text: label, candleTime: visible[index].time));
      _text(canvas, label, labelOrigin, standardTimeLabelStyle);
    }
    hitTargets.timeAxisLabels = List<String>.unmodifiable(labels);
    hitTargets.timeAxisLabelOrigins = List<Offset>.unmodifiable(labelOrigins);
    hitTargets.timeAxisLabelAnchors = List.unmodifiable(anchors);
  }

  double _nicePriceStep(double required) {
    const steps = <double>[
      .00001,
      .00002,
      .000025,
      .00005,
      .000075,
      .00010,
      .00015,
      .00020,
      .00025,
      .00030,
      .00040,
      .00050,
      .00060,
      .00075,
      .00100,
      .00125,
      .00150,
      .00165,
      .00200,
      .00250,
      .00300,
      .00345,
      .00400,
      .00500,
      .00750,
      .01000,
      .01500,
      .02000,
      .02500,
      .05000,
      .07500,
      .10000,
    ];
    for (final step in steps) {
      if (step >= required) return step;
    }
    final magnitude = math.pow(10, (math.log(required) / math.ln10).floor());
    return (required / magnitude).ceil() * magnitude.toDouble();
  }

  bool get _isXauUsdVideo2Reference =>
      symbol == 'XAUUSD' || symbol == 'XAUUSD+';

  bool get _isBtcUsdVideo2Reference => symbol == 'BTCUSD';

  // The video-two chart chrome is shared by every chart. Reference-series
  // detection above remains deliberately narrower so other timeframes keep
  // their own market data instead of inheriting the H4 fixture contour.
  bool get _usesVideo2ChartChrome => true;

  Color get _axisTextColor => theme.axisText;

  TextStyle get _timeAxisTextStyle => AppTypography.chartTimeAxis.copyWith(
    color: _axisTextColor,
    fontSize: 11.5,
    letterSpacing: _isXauUsdVideo2Reference && timeframe == 'M1' ? .25 : .1,
  );

  String _formatAxisTime(DateTime time, {bool first = false}) {
    final displayTime = time.isUtc ? time.toLocal() : time;
    String two(int value) => value.toString().padLeft(2, '0');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[displayTime.month - 1];
    if (timeframe == 'D1' || timeframe == 'W1' || timeframe == 'MN') {
      return '${displayTime.day} $month ${displayTime.year}';
    }
    final clock = '${two(displayTime.hour)}:${two(displayTime.minute)}';
    return '${displayTime.day} $month $clock';
  }

  String _formatCompactAxisTime(DateTime time, int labelIndex) {
    final displayTime = time.isUtc ? time.toLocal() : time;
    String two(int value) => value.toString().padLeft(2, '0');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[displayTime.month - 1];
    if (timeframe == 'MN') return '$month ${displayTime.year}';
    if (_isXauUsdVideo2Reference && timeframe == 'M1') {
      return '${displayTime.day} $month '
          '${two(displayTime.hour)}:${two(displayTime.minute)}';
    }
    if (timeframe == 'D1' || timeframe == 'W1' || labelIndex.isOdd) {
      return '${displayTime.day} $month';
    }
    return '${two(displayTime.hour)}:${two(displayTime.minute)}';
  }

  String _formatCrosshairTime(DateTime time) {
    if (timeframe == 'D1' || timeframe == 'W1' || timeframe == 'MN') {
      return _formatAxisTime(time);
    }
    final displayTime = time.isUtc ? time.toLocal() : time;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(displayTime.day)}.${two(displayTime.month)}.'
        '${displayTime.year} '
        '${two(displayTime.hour)}:${two(displayTime.minute)}';
  }

  Rect _positionLine(
    Canvas canvas,
    double width,
    double y,
    DemoPosition position,
  ) {
    final editingPending = pendingOrderPrice != null;
    final sideColor = editingPending
        ? theme.axisBorder
        : position.side == 'BUY'
        ? theme.tradeBlue
        : theme.tradeRed;
    final profitColor = editingPending
        ? theme.axisBorder
        : position.profit >= 0
        ? theme.tradeBlue
        : theme.tradeRed;
    final paint = Paint()
      ..color = sideColor
      ..strokeWidth = 1;
    _dashedLine(canvas, Offset(1.3, y), Offset(width, y), paint, 4, 3);
    final style = AppTypography.chartAnnotation.copyWith(
      fontSize: _usesVideo2ChartChrome ? 12.5 : 9,
    );
    return _richText(
      canvas,
      TextSpan(
        children: [
          TextSpan(
            text:
                '${position.side} ${position.volume.toStringAsFixed(2)}'
                '${editingPending ? '' : ', '}',
            style: style.copyWith(color: sideColor),
          ),
          if (!editingPending)
            TextSpan(
              text:
                  '${position.profit >= 0 ? '+' : ''}${position.profit.toStringAsFixed(2)} USD',
              style: style.copyWith(color: profitColor),
            ),
        ],
      ),
      Offset(
        _usesVideo2ChartChrome ? 5 : 9,
        y -
            (_usesVideo2ChartChrome
                ? _isXauUsdVideo2Reference && timeframe == 'M1'
                      ? 10.5
                      : 16.5
                : 10),
      ),
    );
  }

  void _positionMarker(
    Canvas canvas,
    double x,
    double y,
    Color color,
    String side,
  ) {
    final upward = side == 'BUY';
    final direction = upward ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(x, y + 7 * direction)
      ..lineTo(x - 6, y + direction)
      ..lineTo(x - 3, y + direction)
      ..lineTo(x - 3, y - 6 * direction)
      ..lineTo(x + 3, y - 6 * direction)
      ..lineTo(x + 3, y + direction)
      ..lineTo(x + 6, y + direction)
      ..close();
    canvas.drawPath(path, Paint()..color = theme.background);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
  }

  void _priceTag(Canvas canvas, double chartWidth, double y) {
    final formatted = currentPrice >= 1000
        ? currentPrice.toStringAsFixed(2)
        : currentPrice >= 100
        ? currentPrice.toStringAsFixed(3)
        : currentPrice.toStringAsFixed(5);
    const width = 67.0;
    final height = _usesVideo2ChartChrome ? 20.0 : 11.5;
    final xOffset = _isXauUsdVideo2Reference && timeframe == 'H1'
        ? 3.3333333333
        : 2.0;
    final rawTagY = y;
    final tagY = _usesVideo2ChartChrome
        ? rawTagY
              .clamp(
                hitTargets.priceTop + height / 2,
                hitTargets.chartHeight - height / 2,
              )
              .toDouble()
        : rawTagY;
    final badgeRect = Rect.fromLTWH(
      chartWidth + xOffset,
      tagY - height / 2,
      width,
      height,
    );
    _currentPriceBadgeRect = badgeRect;
    canvas.drawRect(badgeRect, Paint()..color = theme.priceLine);
    _text(
      canvas,
      formatted,
      Offset(
        chartWidth + xOffset + 3,
        tagY - (_usesVideo2ChartChrome ? 7 : 5.5),
      ),
      AppTypography.chartAnnotation.copyWith(
        color: theme.background,
        fontSize: _usesVideo2ChartChrome ? 14 : 9,
        fontWeight: FontWeight.normal,
      ),
    );
  }

  ({Rect frame, Offset textOrigin}) _positionPriceTag(
    Canvas canvas,
    double chartWidth,
    double y,
    double price,
    Color color,
  ) {
    final formatted = price >= 1000
        ? price.toStringAsFixed(2)
        : price >= 100
        ? price.toStringAsFixed(3)
        : price.toStringAsFixed(5);
    final rect = Rect.fromLTWH(
      chartWidth + 2,
      y - 7.5,
      _usesVideo2ChartChrome ? 61 : 56,
      15,
    );
    canvas.drawRect(rect, Paint()..color = theme.background);
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final textOrigin = Offset(chartWidth + 5, y - 6);
    _text(
      canvas,
      formatted,
      textOrigin,
      AppTypography.chartAxis.copyWith(
        color: color,
        fontSize: _usesVideo2ChartChrome ? 11.5 : 9,
      ),
    );
    return (frame: rect, textOrigin: textOrigin);
  }

  static void _dashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dash,
    double gap,
  ) {
    final distance = (end - start).distance;
    if (distance == 0) return;
    final direction = (end - start) / distance;
    final path = Path();
    for (double offset = 0; offset < distance; offset += dash + gap) {
      path
        ..moveTo(
          (start + direction * offset).dx,
          (start + direction * offset).dy,
        )
        ..lineTo(
          (start + direction * math.min(offset + dash, distance)).dx,
          (start + direction * math.min(offset + dash, distance)).dy,
        );
    }
    final originalStyle = paint.style;
    paint.style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
    paint.style = originalStyle;
  }

  void _drawCachedBackgroundAndGrid({
    required Canvas canvas,
    required Size size,
    required double chartWidth,
    required double chartHeight,
    required double priceTop,
    required double priceHeight,
    required int horizontalDivisions,
    required double firstVerticalGrid,
    required double verticalGridStep,
    required Paint grid,
    required double gridDash,
    required double gridGap,
  }) {
    final key = (
      size.width,
      size.height,
      chartWidth,
      chartHeight,
      priceTop,
      priceHeight,
      horizontalDivisions,
      firstVerticalGrid,
      verticalGridStep,
      _usesVideo2ChartChrome,
      theme.background.toARGB32(),
      theme.grid.toARGB32(),
    );
    final cached = _gridPictureCache.remove(key);
    if (cached != null) {
      _gridPictureCache[key] = cached;
      canvas.drawPicture(cached);
      return;
    }

    final recorder = ui.PictureRecorder();
    final pictureCanvas = Canvas(recorder);
    pictureCanvas.drawRect(
      Offset.zero & size,
      Paint()..color = theme.background,
    );
    if (_usesVideo2ChartChrome) {
      for (var row = 0; row < horizontalDivisions; row++) {
        final y = priceTop + priceHeight * row / horizontalDivisions;
        _dashedLine(
          pictureCanvas,
          Offset(0, y),
          Offset(chartWidth, y),
          grid,
          gridDash,
          gridGap,
        );
      }
    } else {
      const gridTopOffset = 5.0;
      for (var row = 1; row < horizontalDivisions; row++) {
        final y = gridTopOffset + chartHeight * row / horizontalDivisions;
        _dashedLine(
          pictureCanvas,
          Offset(0, y),
          Offset(chartWidth, y),
          grid,
          4,
          4,
        );
      }
    }
    for (
      var fraction = firstVerticalGrid;
      fraction < 1;
      fraction += verticalGridStep
    ) {
      _dashedLine(
        pictureCanvas,
        Offset(chartWidth * fraction, priceTop),
        Offset(chartWidth * fraction, chartHeight),
        grid,
        gridDash,
        gridGap,
      );
    }
    final picture = recorder.endRecording();
    _gridPictureCache[key] = picture;
    if (_gridPictureCache.length > _maxGridPictureCacheEntries) {
      _gridPictureCache.remove(_gridPictureCache.keys.first)?.dispose();
    }
    canvas.drawPicture(picture);
  }

  static void _text(
    Canvas canvas,
    String value,
    Offset offset,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  static Rect _richText(Canvas canvas, InlineSpan value, Offset offset) {
    final painter = TextPainter(text: value, textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(canvas, offset);
    return offset & painter.size;
  }

  @override
  bool shouldRepaint(covariant Mt5CandlePainter oldDelegate) =>
      snapshot.requiresRepaintComparedTo(oldDelegate.snapshot) ||
      oldDelegate.symbol != symbol ||
      oldDelegate.currentPrice != currentPrice ||
      oldDelegate.referencePrice != referencePrice ||
      oldDelegate.tickTime != tickTime ||
      oldDelegate.crosshairEnabled != crosshairEnabled ||
      oldDelegate.crosshairPosition != crosshairPosition ||
      oldDelegate.measurementStart != measurementStart ||
      oldDelegate.measurementEnd != measurementEnd ||
      oldDelegate.timeframe != timeframe ||
      oldDelegate.pendingOrderType != pendingOrderType ||
      oldDelegate.pendingOrderPrice != pendingOrderPrice ||
      oldDelegate.pendingOrderVolume != pendingOrderVolume ||
      oldDelegate.pendingStopLoss != pendingStopLoss ||
      oldDelegate.pendingTakeProfit != pendingTakeProfit ||
      oldDelegate.focusedChartPrice != focusedChartPrice ||
      oldDelegate.loadingPlaceholder != loadingPlaceholder ||
      oldDelegate.oneClickTrading != oneClickTrading ||
      oldDelegate.h4ExpandedScaleSeen != h4ExpandedScaleSeen ||
      oldDelegate.showHistoryBadge != showHistoryBadge ||
      oldDelegate.useRealtimeCandles != useRealtimeCandles;
}
