import 'package:flutter/material.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

class ChartHitTargets {
  double chartWidth = 0;
  double chartHeight = 0;
  double priceTop = 0;
  double priceHeight = 0;
  double minPrice = 0;
  double maxPrice = 0;
  double? pendingOrderY;
  List<({String label, double y})> positionOverlays = const [];
  List<Rect> positionLabelRects = const [];
  List<({String label, double y})> pendingOrderOverlays = const [];
  Rect chartFrameRect = Rect.zero;
  Rect priceGridRect = Rect.zero;
  Rect priceAxisRect = Rect.zero;
  Rect timeAxisRect = Rect.zero;
  List<String> timeAxisLabels = const <String>[];
  List<Offset> timeAxisLabelOrigins = const <Offset>[];
  List<({double x, String text, DateTime candleTime})> timeAxisLabelAnchors =
      const [];
  String? crosshairTimeLabel;
  String? historyBadgeLabel;
  List<MarketCandle> visibleCandles = const <MarketCandle>[];
  double candleWidth = 0;
  double candleBodyWidth = 0;
  double firstCandleCenterX = 0;
  List<double> horizontalGridYs = const <double>[];
  List<double> verticalGridXs = const <double>[];
  List<({String text, double y})> priceAxisLabels = const [];

  int visibleCandleIndex(double localX) {
    if (visibleCandles.isEmpty || candleWidth <= 0) return 0;
    return ((localX - firstCandleCenterX) / candleWidth).round().clamp(
      0,
      visibleCandles.length - 1,
    );
  }
}
