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
  });

  final String name;
  final ReferencePixelRect referenceRect;
  final ReferencePixelRect candidateRect;
  final ReferenceInk ink;
}

const referencePrimaryInk = ReferenceInk(17, 17, 17);
const referenceSecondaryInk = ReferenceInk(92, 92, 96);
const referenceBlueInk = ReferenceInk(0, 127, 255);
const referenceWhiteInk = ReferenceInk(255, 255, 255);

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
        name: 'quote-symbol',
        referenceRect: ReferencePixelRect(4, 184, 105, 38),
        candidateRect: ReferencePixelRect(4, 188, 120, 34),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'navigation-selected-label',
        referenceRect: ReferencePixelRect(60, 1219, 55, 25),
        candidateRect: ReferencePixelRect(60, 1219, 55, 25),
        ink: referenceBlueInk,
      ),
    ],
    dynamicMasks: [
      ReferencePixelRect(0, 0, 590, 70),
      ReferencePixelRect(0, 150, 590, 34),
      ReferencePixelRect(330, 178, 260, 180),
    ],
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
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'ticket-sell-label',
        referenceRect: ReferencePixelRect(0, 144, 62, 22),
        candidateRect: ReferencePixelRect(0, 144, 62, 22),
        ink: referenceWhiteInk,
      ),
      StaticTextRegion(
        name: 'navigation-selected-label',
        referenceRect: ReferencePixelRect(150, 1219, 105, 25),
        candidateRect: ReferencePixelRect(150, 1219, 105, 25),
        ink: referenceBlueInk,
      ),
    ],
    dynamicMasks: [
      ReferencePixelRect(0, 0, 590, 68),
      ReferencePixelRect(62, 140, 528, 60),
      ReferencePixelRect(0, 200, 590, 950),
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
    ],
    dynamicMasks: [
      ReferencePixelRect(0, 0, 590, 75),
      ReferencePixelRect(190, 80, 400, 245),
      ReferencePixelRect(450, 365, 140, 790),
    ],
  ),
  TabReferenceCase(
    id: 'history-positions',
    fileName: 'photo_2026-08-25_22-30-23.jpg',
    state: TabReferenceState.historyPositions,
    staticTextRegions: [
      StaticTextRegion(
        name: 'segment-orders',
        referenceRect: ReferencePixelRect(235, 91, 120, 48),
        candidateRect: ReferencePixelRect(230, 103, 125, 50),
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
        name: 'navigation-selected-label',
        referenceRect: ReferencePixelRect(350, 1224, 100, 20),
        candidateRect: ReferencePixelRect(350, 1224, 100, 20),
        ink: referenceBlueInk,
      ),
    ],
    dynamicMasks: [
      ReferencePixelRect(0, 0, 590, 70),
      ReferencePixelRect(185, 155, 405, 390),
      ReferencePixelRect(185, 550, 405, 170),
    ],
  ),
  TabReferenceCase(
    id: 'history-orders',
    fileName: 'photo_2026-08-25_22-30-26.jpg',
    state: TabReferenceState.historyOrders,
    staticTextRegions: [
      StaticTextRegion(
        name: 'segment-orders',
        referenceRect: ReferencePixelRect(235, 91, 120, 48),
        candidateRect: ReferencePixelRect(230, 103, 125, 50),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'order-symbol',
        referenceRect: ReferencePixelRect(4, 210, 100, 34),
        candidateRect: ReferencePixelRect(4, 208, 105, 34),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'navigation-selected-label',
        referenceRect: ReferencePixelRect(350, 1224, 100, 20),
        candidateRect: ReferencePixelRect(350, 1224, 100, 20),
        ink: referenceBlueInk,
      ),
    ],
    dynamicMasks: [
      ReferencePixelRect(0, 0, 590, 70),
      ReferencePixelRect(150, 130, 440, 1025),
    ],
  ),
  TabReferenceCase(
    id: 'history-orders-summary',
    fileName: 'photo_2026-08-25_22-30-29.jpg',
    state: TabReferenceState.historyOrdersSummary,
    staticTextRegions: [
      StaticTextRegion(
        name: 'segment-orders',
        referenceRect: ReferencePixelRect(235, 91, 120, 48),
        candidateRect: ReferencePixelRect(230, 103, 125, 50),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'summary-label',
        referenceRect: ReferencePixelRect(4, 1061, 130, 32),
        candidateRect: ReferencePixelRect(4, 1061, 140, 32),
        ink: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'navigation-selected-label',
        referenceRect: ReferencePixelRect(350, 1224, 100, 20),
        candidateRect: ReferencePixelRect(350, 1224, 100, 20),
        ink: referenceBlueInk,
      ),
    ],
    dynamicMasks: [
      ReferencePixelRect(0, 0, 590, 70),
      ReferencePixelRect(150, 130, 440, 930),
      ReferencePixelRect(380, 1060, 210, 100),
    ],
  ),
  TabReferenceCase(
    id: 'history-deals',
    fileName: 'photo_2026-08-25_22-30-34.jpg',
    state: TabReferenceState.historyDeals,
    staticTextRegions: [
      StaticTextRegion(
        name: 'segment-deals',
        referenceRect: ReferencePixelRect(350, 91, 140, 48),
        candidateRect: ReferencePixelRect(345, 103, 145, 50),
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
        name: 'navigation-selected-label',
        referenceRect: ReferencePixelRect(350, 1224, 100, 20),
        candidateRect: ReferencePixelRect(350, 1224, 100, 20),
        ink: referenceBlueInk,
      ),
    ],
    dynamicMasks: [
      ReferencePixelRect(0, 0, 590, 70),
      ReferencePixelRect(150, 130, 440, 830),
      ReferencePixelRect(185, 995, 405, 170),
    ],
  ),
];
