enum TabReferenceState {
  prices,
  chart,
  trade,
  historyPositions,
  historyOrders,
  historyOrdersSummary,
  historyDeals,
}

class ReferenceSize {
  const ReferenceSize(this.width, this.height);

  final double width;
  final double height;
}

class ReferencePixelRect {
  const ReferencePixelRect(this.left, this.top, this.width, this.height);

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width;
  int get bottom => top + height;

  bool contains(int x, int y) =>
      x >= left && x < right && y >= top && y < bottom;

  @override
  String toString() => '[$left:$top:$right:$bottom]';
}

class ReferenceInk {
  const ReferenceInk(this.red, this.green, this.blue);

  final int red;
  final int green;
  final int blue;
}

class StaticTextRegion {
  const StaticTextRegion({
    required this.name,
    required this.referenceRect,
    required this.candidateRect,
    required this.ink,
    this.geometryInk,
    this.geometryColorTolerance = 112,
    this.semanticColorTolerance = 6,
    this.measureLargestGeometryComponent = false,
  });

  final String name;
  final ReferencePixelRect referenceRect;
  final ReferencePixelRect candidateRect;
  final ReferenceInk ink;
  final ReferenceInk? geometryInk;
  final int geometryColorTolerance;
  final int semanticColorTolerance;
  final bool measureLargestGeometryComponent;
}

const referencePrimaryInk = ReferenceInk(17, 17, 17);
const referenceSecondaryInk = ReferenceInk(92, 92, 96);
const referenceBlueInk = ReferenceInk(0, 127, 255);
const referenceRedInk = ReferenceInk(228, 45, 48);
const referenceWhiteInk = ReferenceInk(255, 255, 255);
const referenceNavigationInk = ReferenceInk(48, 48, 48);
const referenceHistoryStatusInk = ReferenceInk(41, 70, 117);
const referenceHistorySegmentSelectedInk = ReferenceInk(237, 237, 237);
const referenceChartToolbarInk = ReferenceInk(64, 64, 64);
const referenceChartBlueInk = ReferenceInk(49, 131, 255);
const referenceBlackInk = ReferenceInk(0, 0, 0);

const _navigationPrices = StaticTextRegion(
  name: 'navigation-prices-label',
  referenceRect: ReferencePixelRect(60, 1223, 60, 21),
  candidateRect: ReferencePixelRect(60, 1223, 60, 21),
  ink: referenceNavigationInk,
);
const _navigationPricesSelected = StaticTextRegion(
  name: 'navigation-prices-label',
  referenceRect: ReferencePixelRect(60, 1223, 60, 21),
  candidateRect: ReferencePixelRect(60, 1223, 60, 21),
  ink: referenceBlueInk,
);
const _navigationChart = StaticTextRegion(
  name: 'navigation-chart-label',
  referenceRect: ReferencePixelRect(150, 1223, 110, 21),
  candidateRect: ReferencePixelRect(150, 1223, 110, 21),
  ink: referenceNavigationInk,
);
const _navigationChartSelected = StaticTextRegion(
  name: 'navigation-chart-label',
  referenceRect: ReferencePixelRect(150, 1223, 110, 21),
  candidateRect: ReferencePixelRect(150, 1223, 110, 21),
  ink: referenceBlueInk,
);
const _navigationTrade = StaticTextRegion(
  name: 'navigation-trade-label',
  referenceRect: ReferencePixelRect(255, 1223, 100, 21),
  candidateRect: ReferencePixelRect(255, 1223, 100, 21),
  ink: referenceNavigationInk,
);
const _navigationTradeSelected = StaticTextRegion(
  name: 'navigation-trade-label',
  referenceRect: ReferencePixelRect(255, 1223, 100, 21),
  candidateRect: ReferencePixelRect(255, 1223, 100, 21),
  ink: referenceBlueInk,
);
const _navigationHistory = StaticTextRegion(
  name: 'navigation-history-label',
  referenceRect: ReferencePixelRect(350, 1223, 100, 21),
  candidateRect: ReferencePixelRect(350, 1223, 100, 21),
  ink: referenceNavigationInk,
);
const _navigationHistorySelected = StaticTextRegion(
  name: 'navigation-history-label',
  referenceRect: ReferencePixelRect(350, 1223, 100, 21),
  candidateRect: ReferencePixelRect(350, 1223, 100, 21),
  ink: referenceBlueInk,
);
const _navigationSettings = StaticTextRegion(
  name: 'navigation-settings-label',
  referenceRect: ReferencePixelRect(470, 1223, 60, 12),
  candidateRect: ReferencePixelRect(470, 1223, 60, 12),
  ink: referenceNavigationInk,
);

const _pricesNavigationRegions = <StaticTextRegion>[
  _navigationPricesSelected,
  _navigationChart,
  _navigationTrade,
  _navigationHistory,
  _navigationSettings,
];
const _chartNavigationRegions = <StaticTextRegion>[
  _navigationPrices,
  _navigationChartSelected,
  _navigationTrade,
  _navigationHistory,
  _navigationSettings,
];
const _tradeNavigationRegions = <StaticTextRegion>[
  _navigationPrices,
  _navigationChart,
  _navigationTradeSelected,
  _navigationHistory,
  _navigationSettings,
];
const _historyNavigationRegions = <StaticTextRegion>[
  _navigationPrices,
  _navigationChart,
  _navigationTrade,
  _navigationHistorySelected,
  _navigationSettings,
];

class TabReferenceCase {
  const TabReferenceCase({
    required this.id,
    required this.fileName,
    required this.state,
    this.staticTextRegions = const <StaticTextRegion>[],
    this.dynamicMasks = const <ReferencePixelRect>[],
  });

  final String id;
  final String fileName;
  final TabReferenceState state;
  final List<StaticTextRegion> staticTextRegions;
  final List<ReferencePixelRect> dynamicMasks;

  String get referencePath => '../iconMau/anhmau/$fileName';
}

const tabReferenceLogicalSize = ReferenceSize(393.3333333333, 853.3333333333);
const tabReferenceDevicePixelRatio = 1.5;

const tabReferenceCases = <TabReferenceCase>[
  TabReferenceCase(
    id: 'prices',
    fileName: 'photo_2026-08-25_22-30-10.jpg',
    state: TabReferenceState.prices,
    staticTextRegions: [
      StaticTextRegion(
        name: 'toolbar-title',
        referenceRect: ReferencePixelRect(250, 88, 90, 50),
        candidateRect: ReferencePixelRect(245, 96, 100, 55),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'quote-corner',
        referenceRect: ReferencePixelRect(0, 150, 20, 28),
        candidateRect: ReferencePixelRect(0, 150, 20, 28),
        ink: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'quote-symbol',
        referenceRect: ReferencePixelRect(4, 184, 105, 38),
        candidateRect: ReferencePixelRect(4, 188, 120, 34),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'second-quote-symbol',
        referenceRect: ReferencePixelRect(4, 297, 120, 25),
        candidateRect: ReferencePixelRect(4, 297, 120, 25),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'first-quote-bid',
        referenceRect: ReferencePixelRect(345, 180, 130, 45),
        candidateRect: ReferencePixelRect(345, 180, 130, 45),
        ink: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'first-quote-ask',
        referenceRect: ReferencePixelRect(470, 180, 120, 45),
        candidateRect: ReferencePixelRect(470, 180, 120, 45),
        ink: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'second-quote-bid',
        referenceRect: ReferencePixelRect(365, 278, 110, 45),
        candidateRect: ReferencePixelRect(365, 278, 110, 45),
        ink: referenceRedInk,
      ),
      StaticTextRegion(
        name: 'second-quote-ask',
        referenceRect: ReferencePixelRect(485, 278, 105, 45),
        candidateRect: ReferencePixelRect(485, 278, 105, 45),
        ink: referenceRedInk,
      ),
      StaticTextRegion(
        name: 'first-quote-time',
        referenceRect: ReferencePixelRect(4, 220, 101, 38),
        candidateRect: ReferencePixelRect(4, 220, 101, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'first-quote-low',
        referenceRect: ReferencePixelRect(345, 220, 135, 38),
        candidateRect: ReferencePixelRect(345, 220, 135, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'first-quote-high',
        referenceRect: ReferencePixelRect(470, 220, 120, 38),
        candidateRect: ReferencePixelRect(470, 220, 120, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'second-quote-time',
        referenceRect: ReferencePixelRect(4, 320, 120, 38),
        candidateRect: ReferencePixelRect(4, 320, 120, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'second-quote-low',
        referenceRect: ReferencePixelRect(365, 320, 110, 38),
        candidateRect: ReferencePixelRect(365, 320, 110, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'second-quote-high',
        referenceRect: ReferencePixelRect(485, 320, 105, 38),
        candidateRect: ReferencePixelRect(485, 320, 105, 38),
        ink: referenceSecondaryInk,
      ),
      ..._pricesNavigationRegions,
    ],
    dynamicMasks: [ReferencePixelRect(0, 0, 590, 70)],
  ),
  TabReferenceCase(
    id: 'chart',
    fileName: 'photo_2026-08-25_22-30-17.jpg',
    state: TabReferenceState.chart,
    staticTextRegions: [
      StaticTextRegion(
        name: 'toolbar-timeframe',
        referenceRect: ReferencePixelRect(12, 92, 52, 42),
        candidateRect: ReferencePixelRect(12, 90, 52, 42),
        ink: referenceChartToolbarInk,
        geometryInk: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'ticket-sell-label',
        referenceRect: ReferencePixelRect(0, 144, 62, 22),
        candidateRect: ReferencePixelRect(0, 144, 62, 22),
        ink: referenceWhiteInk,
      ),
      StaticTextRegion(
        name: 'ticket-buy-label',
        referenceRect: ReferencePixelRect(418, 146, 34, 16),
        candidateRect: ReferencePixelRect(418, 146, 34, 16),
        ink: referenceWhiteInk,
      ),
      StaticTextRegion(
        name: 'ticket-sell-price',
        referenceRect: ReferencePixelRect(35, 164, 120, 31),
        candidateRect: ReferencePixelRect(35, 164, 120, 31),
        ink: referenceWhiteInk,
      ),
      StaticTextRegion(
        name: 'ticket-buy-price',
        referenceRect: ReferencePixelRect(445, 164, 135, 31),
        candidateRect: ReferencePixelRect(445, 164, 135, 31),
        ink: referenceWhiteInk,
      ),
      StaticTextRegion(
        name: 'plot-symbol',
        referenceRect: ReferencePixelRect(0, 200, 105, 20),
        candidateRect: ReferencePixelRect(0, 200, 105, 20),
        ink: referenceChartBlueInk,
        geometryInk: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'plot-subtitle',
        referenceRect: ReferencePixelRect(0, 225, 180, 35),
        candidateRect: ReferencePixelRect(0, 225, 180, 35),
        ink: referenceBlackInk,
        geometryInk: referencePrimaryInk,
      ),
      ..._chartNavigationRegions,
    ],
    dynamicMasks: [
      ReferencePixelRect(0, 0, 590, 68),
      ReferencePixelRect(177, 140, 235, 60),
    ],
  ),
  TabReferenceCase(
    id: 'trade',
    fileName: 'photo_2026-08-25_22-30-20.jpg',
    state: TabReferenceState.trade,
    staticTextRegions: [
      StaticTextRegion(
        name: 'metric-label',
        referenceRect: ReferencePixelRect(4, 157, 110, 38),
        candidateRect: ReferencePixelRect(4, 150, 120, 48),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'section-label',
        referenceRect: ReferencePixelRect(4, 327, 190, 38),
        candidateRect: ReferencePixelRect(4, 322, 210, 48),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'position-symbol',
        referenceRect: ReferencePixelRect(4, 369, 100, 40),
        candidateRect: ReferencePixelRect(4, 360, 110, 48),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'header-profit',
        referenceRect: ReferencePixelRect(190, 85, 210, 50),
        candidateRect: ReferencePixelRect(190, 85, 210, 50),
        ink: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'metric-value',
        referenceRect: ReferencePixelRect(445, 155, 145, 40),
        candidateRect: ReferencePixelRect(445, 155, 145, 40),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'position-secondary',
        referenceRect: ReferencePixelRect(4, 402, 225, 40),
        candidateRect: ReferencePixelRect(4, 402, 225, 40),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'position-profit',
        referenceRect: ReferencePixelRect(475, 375, 115, 45),
        candidateRect: ReferencePixelRect(475, 375, 115, 45),
        ink: referenceBlueInk,
      ),
      ..._tradeNavigationRegions,
    ],
    dynamicMasks: [ReferencePixelRect(0, 0, 590, 75)],
  ),
  TabReferenceCase(
    id: 'history-positions',
    fileName: 'photo_2026-08-25_22-30-23.jpg',
    state: TabReferenceState.historyPositions,
    staticTextRegions: [
      StaticTextRegion(
        name: 'selected-segment-surface',
        referenceRect: ReferencePixelRect(105, 97, 130, 6),
        candidateRect: ReferencePixelRect(105, 97, 130, 6),
        ink: referenceHistorySegmentSelectedInk,
        geometryColorTolerance: 10,
        semanticColorTolerance: 6,
        measureLargestGeometryComponent: true,
      ),
      StaticTextRegion(
        name: 'segment-orders',
        referenceRect: ReferencePixelRect(235, 91, 120, 48),
        candidateRect: ReferencePixelRect(230, 103, 125, 50),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'segment-positions',
        referenceRect: ReferencePixelRect(105, 90, 130, 48),
        candidateRect: ReferencePixelRect(105, 90, 130, 48),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'segment-deals',
        referenceRect: ReferencePixelRect(350, 90, 145, 48),
        candidateRect: ReferencePixelRect(350, 90, 145, 48),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'balance-label',
        referenceRect: ReferencePixelRect(4, 162, 105, 38),
        candidateRect: ReferencePixelRect(4, 165, 110, 42),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'position-symbol',
        referenceRect: ReferencePixelRect(4, 239, 100, 32),
        candidateRect: ReferencePixelRect(4, 243, 105, 32),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'summary-label',
        referenceRect: ReferencePixelRect(4, 552, 110, 40),
        candidateRect: ReferencePixelRect(4, 548, 120, 36),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'balance-value',
        referenceRect: ReferencePixelRect(465, 160, 125, 40),
        candidateRect: ReferencePixelRect(465, 160, 125, 40),
        ink: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'position-action',
        referenceRect: ReferencePixelRect(75, 238, 85, 38),
        candidateRect: ReferencePixelRect(75, 238, 85, 38),
        ink: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'position-secondary',
        referenceRect: ReferencePixelRect(4, 275, 190, 38),
        candidateRect: ReferencePixelRect(4, 275, 190, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'position-profit',
        referenceRect: ReferencePixelRect(505, 238, 85, 38),
        candidateRect: ReferencePixelRect(505, 238, 85, 38),
        ink: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'position-timestamp',
        referenceRect: ReferencePixelRect(390, 275, 191, 38),
        candidateRect: ReferencePixelRect(390, 275, 191, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'summary-value',
        referenceRect: ReferencePixelRect(455, 552, 135, 40),
        candidateRect: ReferencePixelRect(455, 552, 135, 40),
        ink: referencePrimaryInk,
      ),
      ..._historyNavigationRegions,
    ],
    dynamicMasks: [ReferencePixelRect(0, 0, 590, 70)],
  ),
  TabReferenceCase(
    id: 'history-orders',
    fileName: 'photo_2026-08-25_22-30-26.jpg',
    state: TabReferenceState.historyOrders,
    staticTextRegions: [
      StaticTextRegion(
        name: 'selected-segment-surface',
        referenceRect: ReferencePixelRect(230, 97, 135, 6),
        candidateRect: ReferencePixelRect(230, 97, 135, 6),
        ink: referenceHistorySegmentSelectedInk,
        geometryColorTolerance: 10,
        semanticColorTolerance: 6,
        measureLargestGeometryComponent: true,
      ),
      StaticTextRegion(
        name: 'segment-orders',
        referenceRect: ReferencePixelRect(235, 91, 120, 48),
        candidateRect: ReferencePixelRect(230, 103, 125, 50),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'segment-positions',
        referenceRect: ReferencePixelRect(105, 90, 130, 48),
        candidateRect: ReferencePixelRect(105, 90, 130, 48),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'segment-deals',
        referenceRect: ReferencePixelRect(350, 90, 145, 48),
        candidateRect: ReferencePixelRect(350, 90, 145, 48),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'order-symbol',
        referenceRect: ReferencePixelRect(4, 210, 100, 34),
        candidateRect: ReferencePixelRect(4, 208, 105, 34),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'order-action',
        referenceRect: ReferencePixelRect(75, 207, 85, 38),
        candidateRect: ReferencePixelRect(75, 207, 85, 38),
        ink: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'order-secondary',
        referenceRect: ReferencePixelRect(4, 244, 165, 38),
        candidateRect: ReferencePixelRect(4, 244, 165, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'order-status',
        referenceRect: ReferencePixelRect(530, 207, 51, 28),
        candidateRect: ReferencePixelRect(530, 207, 51, 28),
        ink: referenceHistoryStatusInk,
      ),
      StaticTextRegion(
        name: 'order-timestamp',
        referenceRect: ReferencePixelRect(390, 244, 191, 38),
        candidateRect: ReferencePixelRect(390, 244, 191, 38),
        ink: referenceSecondaryInk,
      ),
      ..._historyNavigationRegions,
    ],
    dynamicMasks: [ReferencePixelRect(0, 0, 590, 70)],
  ),
  TabReferenceCase(
    id: 'history-orders-summary',
    fileName: 'photo_2026-08-25_22-30-29.jpg',
    state: TabReferenceState.historyOrdersSummary,
    staticTextRegions: [
      StaticTextRegion(
        name: 'selected-segment-surface',
        referenceRect: ReferencePixelRect(230, 97, 135, 6),
        candidateRect: ReferencePixelRect(230, 97, 135, 6),
        ink: referenceHistorySegmentSelectedInk,
        geometryColorTolerance: 10,
        semanticColorTolerance: 6,
        measureLargestGeometryComponent: true,
      ),
      StaticTextRegion(
        name: 'segment-orders',
        referenceRect: ReferencePixelRect(235, 91, 120, 48),
        candidateRect: ReferencePixelRect(230, 103, 125, 50),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'segment-positions',
        referenceRect: ReferencePixelRect(105, 90, 130, 48),
        candidateRect: ReferencePixelRect(105, 90, 130, 48),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'segment-deals',
        referenceRect: ReferencePixelRect(350, 90, 145, 48),
        candidateRect: ReferencePixelRect(350, 90, 145, 48),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'summary-label',
        referenceRect: ReferencePixelRect(4, 1061, 130, 32),
        candidateRect: ReferencePixelRect(4, 1061, 140, 32),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'order-action',
        referenceRect: ReferencePixelRect(75, 207, 85, 38),
        candidateRect: ReferencePixelRect(75, 207, 85, 38),
        ink: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'order-secondary',
        referenceRect: ReferencePixelRect(4, 244, 165, 38),
        candidateRect: ReferencePixelRect(4, 244, 165, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'order-status',
        referenceRect: ReferencePixelRect(530, 207, 51, 28),
        candidateRect: ReferencePixelRect(530, 207, 51, 28),
        ink: referenceHistoryStatusInk,
      ),
      StaticTextRegion(
        name: 'order-timestamp',
        referenceRect: ReferencePixelRect(390, 244, 191, 38),
        candidateRect: ReferencePixelRect(390, 244, 191, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'summary-value',
        referenceRect: ReferencePixelRect(450, 1060, 140, 38),
        candidateRect: ReferencePixelRect(450, 1060, 140, 38),
        ink: referencePrimaryInk,
      ),
      ..._historyNavigationRegions,
    ],
    dynamicMasks: [ReferencePixelRect(0, 0, 590, 70)],
  ),
  TabReferenceCase(
    id: 'history-deals',
    fileName: 'photo_2026-08-25_22-30-34.jpg',
    state: TabReferenceState.historyDeals,
    staticTextRegions: [
      StaticTextRegion(
        name: 'selected-segment-surface',
        referenceRect: ReferencePixelRect(355, 97, 135, 6),
        candidateRect: ReferencePixelRect(355, 97, 135, 6),
        ink: referenceHistorySegmentSelectedInk,
        geometryColorTolerance: 10,
        semanticColorTolerance: 6,
        measureLargestGeometryComponent: true,
      ),
      StaticTextRegion(
        name: 'segment-deals',
        referenceRect: ReferencePixelRect(350, 91, 140, 48),
        candidateRect: ReferencePixelRect(345, 103, 145, 50),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'segment-positions',
        referenceRect: ReferencePixelRect(105, 90, 130, 48),
        candidateRect: ReferencePixelRect(105, 90, 130, 48),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'segment-orders',
        referenceRect: ReferencePixelRect(235, 91, 120, 48),
        candidateRect: ReferencePixelRect(230, 103, 125, 50),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'deal-symbol',
        referenceRect: ReferencePixelRect(4, 214, 100, 42),
        candidateRect: ReferencePixelRect(4, 210, 105, 36),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'summary-label',
        referenceRect: ReferencePixelRect(4, 997, 110, 32),
        candidateRect: ReferencePixelRect(4, 997, 120, 32),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'deal-action',
        referenceRect: ReferencePixelRect(75, 214, 90, 38),
        candidateRect: ReferencePixelRect(75, 214, 90, 38),
        ink: referenceBlueInk,
      ),
      StaticTextRegion(
        name: 'deal-secondary',
        referenceRect: ReferencePixelRect(4, 250, 170, 38),
        candidateRect: ReferencePixelRect(4, 250, 170, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'deal-timestamp',
        referenceRect: ReferencePixelRect(390, 250, 191, 38),
        candidateRect: ReferencePixelRect(390, 250, 191, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'summary-value',
        referenceRect: ReferencePixelRect(455, 995, 135, 40),
        candidateRect: ReferencePixelRect(455, 995, 135, 40),
        ink: referencePrimaryInk,
      ),
      ..._historyNavigationRegions,
    ],
    dynamicMasks: [ReferencePixelRect(0, 0, 590, 70)],
  ),
];
