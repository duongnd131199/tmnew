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

enum ReferenceSelectedTab { prices, chart, trade, history }

enum ReferenceScrollState { atTop, offset, atEnd }

enum ReferenceVisualRegionType {
  system,
  content,
  header,
  body,
  bottomNavigation,
  scrollbar,
}

enum ReferenceDynamicMaskKind {
  systemStatusValues,
  livePrices,
  liveTimes,
  liveProfitAndLoss,
  liveChartContent,
}

class ReferenceCaptureState {
  const ReferenceCaptureState({
    required this.description,
    required this.scrollState,
    this.scrollOffset = 0,
    this.hasVisibleScrollbar = false,
  });

  final String description;
  final ReferenceScrollState scrollState;
  final int scrollOffset;
  final bool hasVisibleScrollbar;
}

class ReferenceVisualRegion {
  const ReferenceVisualRegion({
    required this.name,
    required this.type,
    required this.rect,
    this.requiredForegroundRoles = const <String>[],
    this.foregroundRegionNames = const <String>[],
    this.shadowRegionNames = const <String>[],
  });

  final String name;
  final ReferenceVisualRegionType type;
  final ReferencePixelRect rect;
  final List<String> requiredForegroundRoles;
  final List<String> foregroundRegionNames;
  final List<String> shadowRegionNames;
}

class ReferenceForegroundInterior {
  const ReferenceForegroundInterior({required this.role, required this.rect});

  final String role;
  final ReferencePixelRect rect;
}

class ReferenceSurfaceInterior {
  const ReferenceSurfaceInterior({required this.role, required this.rect});

  final String role;
  final ReferencePixelRect rect;
}

class ReferenceSurfaceRegion {
  const ReferenceSurfaceRegion({
    required this.name,
    required this.rect,
    required this.surfaceRole,
    required this.surroundingRole,
    this.excludedRects = const <ReferencePixelRect>[],
    this.foregroundRegionNames = const <String>[],
  });

  final String name;
  final ReferencePixelRect rect;
  final String surfaceRole;
  final String surroundingRole;
  final List<ReferencePixelRect> excludedRects;
  final List<String> foregroundRegionNames;
}

enum ReferenceForegroundSelectionState { selected, unselected }

class ReferenceForegroundConsensusKey {
  const ReferenceForegroundConsensusKey({
    required this.controlIdentity,
    required this.selection,
    required this.semanticRole,
    required this.surfaceRole,
  });

  final String controlIdentity;
  final ReferenceForegroundSelectionState selection;
  final String semanticRole;
  final String surfaceRole;

  @override
  bool operator ==(Object other) =>
      other is ReferenceForegroundConsensusKey &&
      other.controlIdentity == controlIdentity &&
      other.selection == selection &&
      other.semanticRole == semanticRole &&
      other.surfaceRole == surfaceRole;

  @override
  int get hashCode =>
      Object.hash(controlIdentity, selection, semanticRole, surfaceRole);

  @override
  String toString() =>
      '$controlIdentity|${selection.name}|$semanticRole|$surfaceRole';
}

class ReferenceForegroundConsensusGroup {
  const ReferenceForegroundConsensusGroup({
    required this.key,
    required this.memberCaseIds,
  });

  final ReferenceForegroundConsensusKey key;
  final List<String> memberCaseIds;
}

class ReferenceStaticControlRegion {
  const ReferenceStaticControlRegion({
    required this.name,
    required this.rect,
    this.geometryColorTolerance = 112,
  });

  final String name;
  final ReferencePixelRect rect;
  final int geometryColorTolerance;
}

class ReferenceShadowRegion {
  const ReferenceShadowRegion({
    required this.name,
    required this.rect,
    required this.surfaceSampleRect,
  });

  final String name;
  final ReferencePixelRect rect;
  final ReferencePixelRect surfaceSampleRect;
}

class ReferenceDynamicMask {
  const ReferenceDynamicMask({
    required this.kind,
    required this.rect,
    required this.reason,
  });

  final ReferenceDynamicMaskKind kind;
  final ReferencePixelRect rect;
  final String reason;
}

class ReferenceInk {
  const ReferenceInk(this.red, this.green, this.blue);

  final int red;
  final int green;
  final int blue;
}

enum StaticTextAuditMode { static, dynamicOnly }

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
    this.measureInkDensity = true,
    this.inkDensityTolerancePercent,
    this.auditMode = StaticTextAuditMode.static,
    this.allowsDynamicMask = false,
  });

  final String name;
  final ReferencePixelRect referenceRect;
  final ReferencePixelRect candidateRect;
  final ReferenceInk ink;
  final ReferenceInk? geometryInk;
  final int geometryColorTolerance;
  final int semanticColorTolerance;
  final bool measureLargestGeometryComponent;

  /// Legacy metadata retained for manifest compatibility. The comparator
  /// always measures and enforces the global optical-density contract.
  final bool measureInkDensity;
  final double? inkDensityTolerancePercent;

  /// Static text is measured strictly. Dynamic-only text emits a reasoned
  /// SKIP row and must intersect a typed dynamic mask.
  final StaticTextAuditMode auditMode;

  /// Allows a reasoned dynamic mask to overlap this legacy text search area.
  /// Compatibility-only: use [auditMode] for new dynamic-only declarations.
  final bool allowsDynamicMask;
}

const referencePrimaryInk = ReferenceInk(0, 0, 0);
const referenceSecondaryInk = ReferenceInk(60, 60, 67);
const referenceBlueInk = ReferenceInk(0, 122, 255);
const referenceRedInk = ReferenceInk(228, 45, 48);
const referenceWhiteInk = ReferenceInk(255, 255, 255);
const referenceNavigationInk = ReferenceInk(0, 0, 0);
const referenceHistoryStatusInk = ReferenceInk(41, 70, 117);
const referenceHistorySegmentSelectedInk = ReferenceInk(237, 237, 237);
const referenceChartToolbarInk = ReferenceInk(64, 64, 64);
const referenceChartBlueInk = ReferenceInk(57, 133, 233);
const referenceBlackInk = ReferenceInk(0, 0, 0);
const navigationBlackRole = 'navigation-black';
const navigationBlueRole = 'navigation-blue';
const navigationWhiteSurfaceRole = 'navigation-white-surface';
const navigationSelectedSurfaceRole = 'navigation-selected-surface';
const navigationSurroundingWhiteRole = 'navigation-surrounding-white';
const pricesBlackRole = 'prices-black';
const pricesSecondaryRole = 'prices-secondary';
const pricesBlueRole = 'prices-blue';
const pricesRedRole = 'prices-red';
const pricesWhiteSurfaceRole = 'prices-white-surface';

const _geometryPrimaryInk = ReferenceInk(17, 17, 17);
const _geometrySecondaryInk = ReferenceInk(92, 92, 96);
const _geometryBlueInk = ReferenceInk(0, 127, 255);
const _geometryRedInk = ReferenceInk(228, 45, 48);
const _geometryNavigationInk = ReferenceInk(48, 48, 48);

ReferenceInk geometryInkFor(ReferenceInk semanticInk) {
  if (identical(semanticInk, referencePrimaryInk)) return _geometryPrimaryInk;
  if (identical(semanticInk, referenceSecondaryInk)) {
    return _geometrySecondaryInk;
  }
  if (identical(semanticInk, referenceBlueInk)) return _geometryBlueInk;
  if (identical(semanticInk, referenceRedInk)) return _geometryRedInk;
  if (identical(semanticInk, referenceNavigationInk)) {
    return _geometryNavigationInk;
  }
  return semanticInk;
}

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
  measureInkDensity: false,
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
  measureInkDensity: false,
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
  measureInkDensity: false,
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
  measureInkDensity: false,
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

const _referenceCanvas = ReferencePixelRect(0, 0, 590, 1280);

const _baseVisualRegions = <ReferenceVisualRegion>[
  ReferenceVisualRegion(
    name: 'system',
    type: ReferenceVisualRegionType.system,
    rect: ReferencePixelRect(0, 0, 590, 75),
  ),
  ReferenceVisualRegion(
    name: 'content',
    type: ReferenceVisualRegionType.content,
    rect: ReferencePixelRect(0, 75, 590, 1093),
  ),
  ReferenceVisualRegion(
    name: 'header',
    type: ReferenceVisualRegionType.header,
    rect: ReferencePixelRect(0, 75, 590, 70),
  ),
  ReferenceVisualRegion(
    name: 'body',
    type: ReferenceVisualRegionType.body,
    rect: ReferencePixelRect(0, 145, 590, 1023),
  ),
  ReferenceVisualRegion(
    name: 'bottom-navigation',
    type: ReferenceVisualRegionType.bottomNavigation,
    rect: ReferencePixelRect(28, 1169, 535, 93),
    requiredForegroundRoles: <String>[navigationBlackRole, navigationBlueRole],
    foregroundRegionNames: <String>[
      'navigation-prices-icon',
      'navigation-prices-label',
      'navigation-chart-icon',
      'navigation-chart-label',
      'navigation-trade-icon',
      'navigation-trade-label',
      'navigation-history-icon',
      'navigation-history-label',
      'navigation-settings-icon',
      'navigation-settings-label',
    ],
    shadowRegionNames: <String>[
      'bottom-navigation-shadow-left',
      'bottom-navigation-shadow-right',
      'bottom-navigation-shadow-bottom',
    ],
  ),
];

const _pricesSelectedPillVisual = ReferenceVisualRegion(
  name: 'bottom-navigation-selected-pill',
  type: ReferenceVisualRegionType.bottomNavigation,
  rect: ReferencePixelRect(34, 1171, 114, 75),
  requiredForegroundRoles: <String>[navigationBlueRole],
  foregroundRegionNames: <String>[
    'navigation-prices-icon',
    'navigation-prices-label',
  ],
);
const _pricesHeaderForegroundVisual = ReferenceVisualRegion(
  name: 'prices-header-foreground',
  type: ReferenceVisualRegionType.header,
  rect: ReferencePixelRect(0, 75, 590, 70),
  requiredForegroundRoles: <String>[pricesBlackRole],
  foregroundRegionNames: <String>[
    'prices-toolbar-list',
    'prices-toolbar-edit',
    'prices-toolbar-search',
  ],
);
const _pricesBodyForegroundVisual = ReferenceVisualRegion(
  name: 'prices-body-foreground',
  type: ReferenceVisualRegionType.body,
  rect: ReferencePixelRect(0, 145, 590, 220),
  requiredForegroundRoles: <String>[
    pricesBlackRole,
    pricesSecondaryRole,
    pricesBlueRole,
    pricesRedRole,
  ],
  foregroundRegionNames: <String>[
    'quote-corner',
    'quote-symbol',
    'second-quote-symbol',
    'prices-first-change-accent',
    'prices-second-change-accent',
    'first-quote-low-label',
    'first-quote-high-label',
    'second-quote-low-label',
    'second-quote-high-label',
  ],
);
const _chartSelectedPillVisual = ReferenceVisualRegion(
  name: 'bottom-navigation-selected-pill',
  type: ReferenceVisualRegionType.bottomNavigation,
  rect: ReferencePixelRect(136, 1171, 114, 75),
  requiredForegroundRoles: <String>[navigationBlueRole],
  foregroundRegionNames: <String>[
    'navigation-chart-icon',
    'navigation-chart-label',
  ],
);
const _tradeSelectedPillVisual = ReferenceVisualRegion(
  name: 'bottom-navigation-selected-pill',
  type: ReferenceVisualRegionType.bottomNavigation,
  rect: ReferencePixelRect(238, 1171, 114, 75),
  requiredForegroundRoles: <String>[navigationBlueRole],
  foregroundRegionNames: <String>[
    'navigation-trade-icon',
    'navigation-trade-label',
  ],
);
const _historySelectedPillVisual = ReferenceVisualRegion(
  name: 'bottom-navigation-selected-pill',
  type: ReferenceVisualRegionType.bottomNavigation,
  rect: ReferencePixelRect(339, 1171, 115, 75),
  requiredForegroundRoles: <String>[navigationBlueRole],
  foregroundRegionNames: <String>[
    'navigation-history-icon',
    'navigation-history-label',
  ],
);

const _allNavigationForegroundNames = <String>[
  'navigation-prices-icon',
  'navigation-prices-label',
  'navigation-chart-icon',
  'navigation-chart-label',
  'navigation-trade-icon',
  'navigation-trade-label',
  'navigation-history-icon',
  'navigation-history-label',
  'navigation-settings-icon',
  'navigation-settings-label',
];

const _navigationCapsuleRect = ReferencePixelRect(60, 1176, 477, 65);

const _pricesNavigationSurfaceRegions = <ReferenceSurfaceRegion>[
  ReferenceSurfaceRegion(
    name: 'bottom-navigation-capsule-surface',
    rect: _navigationCapsuleRect,
    surfaceRole: navigationWhiteSurfaceRole,
    surroundingRole: navigationWhiteSurfaceRole,
    excludedRects: [ReferencePixelRect(60, 1176, 88, 65)],
    foregroundRegionNames: _allNavigationForegroundNames,
  ),
  ReferenceSurfaceRegion(
    name: 'bottom-navigation-selected-pill-surface',
    rect: ReferencePixelRect(34, 1171, 114, 75),
    surfaceRole: navigationSelectedSurfaceRole,
    surroundingRole: navigationWhiteSurfaceRole,
    foregroundRegionNames: [
      'navigation-prices-icon',
      'navigation-prices-label',
    ],
  ),
];

const _chartNavigationSurfaceRegions = <ReferenceSurfaceRegion>[
  ReferenceSurfaceRegion(
    name: 'bottom-navigation-capsule-surface',
    rect: _navigationCapsuleRect,
    surfaceRole: navigationWhiteSurfaceRole,
    surroundingRole: navigationWhiteSurfaceRole,
    excludedRects: [ReferencePixelRect(136, 1176, 114, 65)],
    foregroundRegionNames: _allNavigationForegroundNames,
  ),
  ReferenceSurfaceRegion(
    name: 'bottom-navigation-selected-pill-surface',
    rect: ReferencePixelRect(136, 1171, 114, 75),
    surfaceRole: navigationSelectedSurfaceRole,
    surroundingRole: navigationWhiteSurfaceRole,
    foregroundRegionNames: ['navigation-chart-icon', 'navigation-chart-label'],
  ),
];

const _tradeNavigationSurfaceRegions = <ReferenceSurfaceRegion>[
  ReferenceSurfaceRegion(
    name: 'bottom-navigation-capsule-surface',
    rect: _navigationCapsuleRect,
    surfaceRole: navigationWhiteSurfaceRole,
    surroundingRole: navigationWhiteSurfaceRole,
    excludedRects: [ReferencePixelRect(238, 1176, 114, 65)],
    foregroundRegionNames: _allNavigationForegroundNames,
  ),
  ReferenceSurfaceRegion(
    name: 'bottom-navigation-selected-pill-surface',
    rect: ReferencePixelRect(238, 1171, 114, 75),
    surfaceRole: navigationSelectedSurfaceRole,
    surroundingRole: navigationWhiteSurfaceRole,
    foregroundRegionNames: ['navigation-trade-icon', 'navigation-trade-label'],
  ),
];

const _historyNavigationSurfaceRegions = <ReferenceSurfaceRegion>[
  ReferenceSurfaceRegion(
    name: 'bottom-navigation-capsule-surface',
    rect: _navigationCapsuleRect,
    surfaceRole: navigationWhiteSurfaceRole,
    surroundingRole: navigationWhiteSurfaceRole,
    excludedRects: [ReferencePixelRect(339, 1176, 115, 65)],
    foregroundRegionNames: _allNavigationForegroundNames,
  ),
  ReferenceSurfaceRegion(
    name: 'bottom-navigation-selected-pill-surface',
    rect: ReferencePixelRect(339, 1171, 115, 75),
    surfaceRole: navigationSelectedSurfaceRole,
    surroundingRole: navigationWhiteSurfaceRole,
    foregroundRegionNames: [
      'navigation-history-icon',
      'navigation-history-label',
    ],
  ),
];

const _pricesForegroundInteriors = <ReferenceForegroundInterior>[
  ReferenceForegroundInterior(
    role: pricesBlackRole,
    rect: ReferencePixelRect(287, 1186, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: pricesSecondaryRole,
    rect: ReferencePixelRect(373, 232, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: pricesBlueRole,
    rect: ReferencePixelRect(552, 191, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: pricesRedRole,
    rect: ReferencePixelRect(424, 300, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(287, 1186, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(386, 1198, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(552, 191, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(572, 192, 1, 1),
  ),
];

const _chartForegroundInteriors = <ReferenceForegroundInterior>[
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(82, 1209, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(497, 1211, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(148, 164, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(64, 158, 1, 1),
  ),
];

const _tradeForegroundInteriors = <ReferenceForegroundInterior>[
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(195, 1198, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(386, 1198, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(88, 384, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(130, 858, 1, 1),
  ),
];

const _historyPositionsForegroundInteriors = <ReferenceForegroundInterior>[
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(297, 1203, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(497, 1211, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(526, 181, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(397, 1211, 1, 1),
  ),
];

const _historyOrdersForegroundInteriors = <ReferenceForegroundInterior>[
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(288, 1202, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(498, 1194, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(117, 929, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(384, 1198, 1, 1),
  ),
];

const _historyOrdersSummaryForegroundInteriors = <ReferenceForegroundInterior>[
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(297, 1203, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(497, 1211, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(88, 295, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(397, 1211, 1, 1),
  ),
];

const _historyDealsForegroundInteriors = <ReferenceForegroundInterior>[
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(297, 1203, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlackRole,
    rect: ReferencePixelRect(497, 1211, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(142, 627, 1, 1),
  ),
  ReferenceForegroundInterior(
    role: navigationBlueRole,
    rect: ReferencePixelRect(137, 628, 1, 1),
  ),
];

const _pricesSurfaceInteriors = <ReferenceSurfaceInterior>[
  ReferenceSurfaceInterior(
    role: pricesWhiteSurfaceRole,
    rect: ReferencePixelRect(200, 400, 2, 2),
  ),
  ReferenceSurfaceInterior(
    role: navigationWhiteSurfaceRole,
    rect: ReferencePixelRect(460, 1238, 8, 5),
  ),
  ReferenceSurfaceInterior(
    role: navigationSelectedSurfaceRole,
    rect: ReferencePixelRect(80, 1173, 20, 8),
  ),
  ReferenceSurfaceInterior(
    role: navigationSurroundingWhiteRole,
    rect: ReferencePixelRect(20, 1170, 8, 8),
  ),
];

const _chartSurfaceInteriors = <ReferenceSurfaceInterior>[
  ReferenceSurfaceInterior(
    role: navigationWhiteSurfaceRole,
    rect: ReferencePixelRect(460, 1238, 8, 5),
  ),
  ReferenceSurfaceInterior(
    role: navigationSelectedSurfaceRole,
    rect: ReferencePixelRect(184, 1173, 18, 8),
  ),
  ReferenceSurfaceInterior(
    role: navigationSurroundingWhiteRole,
    rect: ReferencePixelRect(20, 1170, 8, 8),
  ),
];

const _tradeSurfaceInteriors = <ReferenceSurfaceInterior>[
  ReferenceSurfaceInterior(
    role: navigationWhiteSurfaceRole,
    rect: ReferencePixelRect(460, 1238, 8, 5),
  ),
  ReferenceSurfaceInterior(
    role: navigationSelectedSurfaceRole,
    rect: ReferencePixelRect(282, 1173, 22, 8),
  ),
  ReferenceSurfaceInterior(
    role: navigationSurroundingWhiteRole,
    rect: ReferencePixelRect(20, 1170, 8, 8),
  ),
];

const _historySurfaceInteriors = <ReferenceSurfaceInterior>[
  ReferenceSurfaceInterior(
    role: navigationWhiteSurfaceRole,
    rect: ReferencePixelRect(460, 1238, 8, 5),
  ),
  ReferenceSurfaceInterior(
    role: navigationSelectedSurfaceRole,
    rect: ReferencePixelRect(382, 1173, 23, 8),
  ),
  ReferenceSurfaceInterior(
    role: navigationSurroundingWhiteRole,
    rect: ReferencePixelRect(20, 1170, 8, 8),
  ),
];

const _pricesForegroundRoles = <String, String>{
  'prices-toolbar-list': pricesBlackRole,
  'prices-toolbar-edit': pricesBlackRole,
  'prices-toolbar-search': pricesBlackRole,
  'quote-corner': pricesBlueRole,
  'quote-symbol': pricesBlackRole,
  'second-quote-symbol': pricesBlackRole,
  'prices-first-change-accent': pricesRedRole,
  'prices-second-change-accent': pricesBlueRole,
  'first-quote-low-label': pricesSecondaryRole,
  'first-quote-high-label': pricesSecondaryRole,
  'second-quote-low-label': pricesSecondaryRole,
  'second-quote-high-label': pricesSecondaryRole,
  'navigation-prices-icon': navigationBlueRole,
  'navigation-prices-label': navigationBlueRole,
  'navigation-chart-icon': navigationBlackRole,
  'navigation-chart-label': navigationBlackRole,
  'navigation-trade-icon': navigationBlackRole,
  'navigation-trade-label': navigationBlackRole,
  'navigation-history-icon': navigationBlackRole,
  'navigation-history-label': navigationBlackRole,
  'navigation-settings-icon': navigationBlackRole,
  'navigation-settings-label': navigationBlackRole,
};

const _chartForegroundRoles = <String, String>{
  'navigation-prices-icon': navigationBlackRole,
  'navigation-prices-label': navigationBlackRole,
  'navigation-chart-icon': navigationBlueRole,
  'navigation-chart-label': navigationBlueRole,
  'navigation-trade-icon': navigationBlackRole,
  'navigation-trade-label': navigationBlackRole,
  'navigation-history-icon': navigationBlackRole,
  'navigation-history-label': navigationBlackRole,
  'navigation-settings-icon': navigationBlackRole,
  'navigation-settings-label': navigationBlackRole,
};

const _tradeForegroundRoles = <String, String>{
  'navigation-prices-icon': navigationBlackRole,
  'navigation-prices-label': navigationBlackRole,
  'navigation-chart-icon': navigationBlackRole,
  'navigation-chart-label': navigationBlackRole,
  'navigation-trade-icon': navigationBlueRole,
  'navigation-trade-label': navigationBlueRole,
  'navigation-history-icon': navigationBlackRole,
  'navigation-history-label': navigationBlackRole,
  'navigation-settings-icon': navigationBlackRole,
  'navigation-settings-label': navigationBlackRole,
};

const _historyForegroundRoles = <String, String>{
  'navigation-prices-icon': navigationBlackRole,
  'navigation-prices-label': navigationBlackRole,
  'navigation-chart-icon': navigationBlackRole,
  'navigation-chart-label': navigationBlackRole,
  'navigation-trade-icon': navigationBlackRole,
  'navigation-trade-label': navigationBlackRole,
  'navigation-history-icon': navigationBlueRole,
  'navigation-history-label': navigationBlueRole,
  'navigation-settings-icon': navigationBlackRole,
  'navigation-settings-label': navigationBlackRole,
};

const _pricesSurfaceRoles = <String, String>{
  'prices-toolbar-list': pricesWhiteSurfaceRole,
  'prices-toolbar-edit': pricesWhiteSurfaceRole,
  'prices-toolbar-search': pricesWhiteSurfaceRole,
  'quote-corner': pricesWhiteSurfaceRole,
  'quote-symbol': pricesWhiteSurfaceRole,
  'second-quote-symbol': pricesWhiteSurfaceRole,
  'prices-first-change-accent': pricesWhiteSurfaceRole,
  'prices-second-change-accent': pricesWhiteSurfaceRole,
  'first-quote-low-label': pricesWhiteSurfaceRole,
  'first-quote-high-label': pricesWhiteSurfaceRole,
  'second-quote-low-label': pricesWhiteSurfaceRole,
  'second-quote-high-label': pricesWhiteSurfaceRole,
  'navigation-prices-icon': navigationSelectedSurfaceRole,
  'navigation-prices-label': navigationSelectedSurfaceRole,
  'navigation-chart-icon': navigationWhiteSurfaceRole,
  'navigation-chart-label': navigationWhiteSurfaceRole,
  'navigation-trade-icon': navigationWhiteSurfaceRole,
  'navigation-trade-label': navigationWhiteSurfaceRole,
  'navigation-history-icon': navigationWhiteSurfaceRole,
  'navigation-history-label': navigationWhiteSurfaceRole,
  'navigation-settings-icon': navigationWhiteSurfaceRole,
  'navigation-settings-label': navigationWhiteSurfaceRole,
};

const _chartSurfaceRoles = <String, String>{
  'navigation-prices-icon': navigationWhiteSurfaceRole,
  'navigation-prices-label': navigationWhiteSurfaceRole,
  'navigation-chart-icon': navigationSelectedSurfaceRole,
  'navigation-chart-label': navigationSelectedSurfaceRole,
  'navigation-trade-icon': navigationWhiteSurfaceRole,
  'navigation-trade-label': navigationWhiteSurfaceRole,
  'navigation-history-icon': navigationWhiteSurfaceRole,
  'navigation-history-label': navigationWhiteSurfaceRole,
  'navigation-settings-icon': navigationWhiteSurfaceRole,
  'navigation-settings-label': navigationWhiteSurfaceRole,
};

const _tradeSurfaceRoles = <String, String>{
  'navigation-prices-icon': navigationWhiteSurfaceRole,
  'navigation-prices-label': navigationWhiteSurfaceRole,
  'navigation-chart-icon': navigationWhiteSurfaceRole,
  'navigation-chart-label': navigationWhiteSurfaceRole,
  'navigation-trade-icon': navigationSelectedSurfaceRole,
  'navigation-trade-label': navigationSelectedSurfaceRole,
  'navigation-history-icon': navigationWhiteSurfaceRole,
  'navigation-history-label': navigationWhiteSurfaceRole,
  'navigation-settings-icon': navigationWhiteSurfaceRole,
  'navigation-settings-label': navigationWhiteSurfaceRole,
};

const _historySurfaceRoles = <String, String>{
  'navigation-prices-icon': navigationWhiteSurfaceRole,
  'navigation-prices-label': navigationWhiteSurfaceRole,
  'navigation-chart-icon': navigationWhiteSurfaceRole,
  'navigation-chart-label': navigationWhiteSurfaceRole,
  'navigation-trade-icon': navigationWhiteSurfaceRole,
  'navigation-trade-label': navigationWhiteSurfaceRole,
  'navigation-history-icon': navigationSelectedSurfaceRole,
  'navigation-history-label': navigationSelectedSurfaceRole,
  'navigation-settings-icon': navigationWhiteSurfaceRole,
  'navigation-settings-label': navigationWhiteSurfaceRole,
};

const _pricesForegroundSelections = <String, ReferenceForegroundSelectionState>{
  'prices-toolbar-list': ReferenceForegroundSelectionState.unselected,
  'prices-toolbar-edit': ReferenceForegroundSelectionState.unselected,
  'prices-toolbar-search': ReferenceForegroundSelectionState.unselected,
  'quote-corner': ReferenceForegroundSelectionState.unselected,
  'quote-symbol': ReferenceForegroundSelectionState.unselected,
  'second-quote-symbol': ReferenceForegroundSelectionState.unselected,
  'prices-first-change-accent': ReferenceForegroundSelectionState.unselected,
  'prices-second-change-accent': ReferenceForegroundSelectionState.unselected,
  'first-quote-low-label': ReferenceForegroundSelectionState.unselected,
  'first-quote-high-label': ReferenceForegroundSelectionState.unselected,
  'second-quote-low-label': ReferenceForegroundSelectionState.unselected,
  'second-quote-high-label': ReferenceForegroundSelectionState.unselected,
  'navigation-prices-icon': ReferenceForegroundSelectionState.selected,
  'navigation-prices-label': ReferenceForegroundSelectionState.selected,
  'navigation-chart-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-chart-label': ReferenceForegroundSelectionState.unselected,
  'navigation-trade-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-trade-label': ReferenceForegroundSelectionState.unselected,
  'navigation-history-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-history-label': ReferenceForegroundSelectionState.unselected,
  'navigation-settings-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-settings-label': ReferenceForegroundSelectionState.unselected,
};

const _chartForegroundSelections = <String, ReferenceForegroundSelectionState>{
  'navigation-prices-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-prices-label': ReferenceForegroundSelectionState.unselected,
  'navigation-chart-icon': ReferenceForegroundSelectionState.selected,
  'navigation-chart-label': ReferenceForegroundSelectionState.selected,
  'navigation-trade-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-trade-label': ReferenceForegroundSelectionState.unselected,
  'navigation-history-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-history-label': ReferenceForegroundSelectionState.unselected,
  'navigation-settings-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-settings-label': ReferenceForegroundSelectionState.unselected,
};

const _tradeForegroundSelections = <String, ReferenceForegroundSelectionState>{
  'navigation-prices-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-prices-label': ReferenceForegroundSelectionState.unselected,
  'navigation-chart-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-chart-label': ReferenceForegroundSelectionState.unselected,
  'navigation-trade-icon': ReferenceForegroundSelectionState.selected,
  'navigation-trade-label': ReferenceForegroundSelectionState.selected,
  'navigation-history-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-history-label': ReferenceForegroundSelectionState.unselected,
  'navigation-settings-icon': ReferenceForegroundSelectionState.unselected,
  'navigation-settings-label': ReferenceForegroundSelectionState.unselected,
};

const _historyForegroundSelections =
    <String, ReferenceForegroundSelectionState>{
      'navigation-prices-icon': ReferenceForegroundSelectionState.unselected,
      'navigation-prices-label': ReferenceForegroundSelectionState.unselected,
      'navigation-chart-icon': ReferenceForegroundSelectionState.unselected,
      'navigation-chart-label': ReferenceForegroundSelectionState.unselected,
      'navigation-trade-icon': ReferenceForegroundSelectionState.unselected,
      'navigation-trade-label': ReferenceForegroundSelectionState.unselected,
      'navigation-history-icon': ReferenceForegroundSelectionState.selected,
      'navigation-history-label': ReferenceForegroundSelectionState.selected,
      'navigation-settings-icon': ReferenceForegroundSelectionState.unselected,
      'navigation-settings-label': ReferenceForegroundSelectionState.unselected,
    };

final tabReferenceForegroundConsensusGroups =
    <ReferenceForegroundConsensusGroup>[
      for (final entry in <(String, String)>[
        ('prices-toolbar-list', pricesBlackRole),
        ('prices-toolbar-edit', pricesBlackRole),
        ('prices-toolbar-search', pricesBlackRole),
        ('quote-corner', pricesBlueRole),
        ('quote-symbol', pricesBlackRole),
        ('second-quote-symbol', pricesBlackRole),
        ('prices-first-change-accent', pricesRedRole),
        ('prices-second-change-accent', pricesBlueRole),
        ('first-quote-low-label', pricesSecondaryRole),
        ('first-quote-high-label', pricesSecondaryRole),
        ('second-quote-low-label', pricesSecondaryRole),
        ('second-quote-high-label', pricesSecondaryRole),
      ])
        ReferenceForegroundConsensusGroup(
          key: ReferenceForegroundConsensusKey(
            controlIdentity: entry.$1,
            selection: ReferenceForegroundSelectionState.unselected,
            semanticRole: entry.$2,
            surfaceRole: pricesWhiteSurfaceRole,
          ),
          memberCaseIds: ['prices'],
        ),
      ReferenceForegroundConsensusGroup(
        key: ReferenceForegroundConsensusKey(
          controlIdentity: 'navigation-prices-icon',
          selection: ReferenceForegroundSelectionState.selected,
          semanticRole: navigationBlueRole,
          surfaceRole: navigationSelectedSurfaceRole,
        ),
        memberCaseIds: ['prices'],
      ),
      ReferenceForegroundConsensusGroup(
        key: ReferenceForegroundConsensusKey(
          controlIdentity: 'navigation-prices-label',
          selection: ReferenceForegroundSelectionState.selected,
          semanticRole: navigationBlueRole,
          surfaceRole: navigationSelectedSurfaceRole,
        ),
        memberCaseIds: ['prices'],
      ),
      ReferenceForegroundConsensusGroup(
        key: ReferenceForegroundConsensusKey(
          controlIdentity: 'navigation-chart-icon',
          selection: ReferenceForegroundSelectionState.selected,
          semanticRole: navigationBlueRole,
          surfaceRole: navigationSelectedSurfaceRole,
        ),
        memberCaseIds: ['chart'],
      ),
      ReferenceForegroundConsensusGroup(
        key: ReferenceForegroundConsensusKey(
          controlIdentity: 'navigation-chart-label',
          selection: ReferenceForegroundSelectionState.selected,
          semanticRole: navigationBlueRole,
          surfaceRole: navigationSelectedSurfaceRole,
        ),
        memberCaseIds: ['chart'],
      ),
      ReferenceForegroundConsensusGroup(
        key: ReferenceForegroundConsensusKey(
          controlIdentity: 'navigation-trade-icon',
          selection: ReferenceForegroundSelectionState.selected,
          semanticRole: navigationBlueRole,
          surfaceRole: navigationSelectedSurfaceRole,
        ),
        memberCaseIds: ['trade'],
      ),
      ReferenceForegroundConsensusGroup(
        key: ReferenceForegroundConsensusKey(
          controlIdentity: 'navigation-trade-label',
          selection: ReferenceForegroundSelectionState.selected,
          semanticRole: navigationBlueRole,
          surfaceRole: navigationSelectedSurfaceRole,
        ),
        memberCaseIds: ['trade'],
      ),
      ReferenceForegroundConsensusGroup(
        key: ReferenceForegroundConsensusKey(
          controlIdentity: 'navigation-history-icon',
          selection: ReferenceForegroundSelectionState.selected,
          semanticRole: navigationBlueRole,
          surfaceRole: navigationSelectedSurfaceRole,
        ),
        memberCaseIds: [
          'history-positions',
          'history-orders',
          'history-orders-summary',
          'history-deals',
        ],
      ),
      ReferenceForegroundConsensusGroup(
        key: ReferenceForegroundConsensusKey(
          controlIdentity: 'navigation-history-label',
          selection: ReferenceForegroundSelectionState.selected,
          semanticRole: navigationBlueRole,
          surfaceRole: navigationSelectedSurfaceRole,
        ),
        memberCaseIds: [
          'history-positions',
          'history-orders',
          'history-orders-summary',
          'history-deals',
        ],
      ),
      for (final control in <String>[
        'navigation-prices-icon',
        'navigation-prices-label',
      ])
        ReferenceForegroundConsensusGroup(
          key: ReferenceForegroundConsensusKey(
            controlIdentity: control,
            selection: ReferenceForegroundSelectionState.unselected,
            semanticRole: navigationBlackRole,
            surfaceRole: navigationWhiteSurfaceRole,
          ),
          memberCaseIds: [
            'chart',
            'trade',
            'history-positions',
            'history-orders',
            'history-orders-summary',
            'history-deals',
          ],
        ),
      for (final control in <String>[
        'navigation-chart-icon',
        'navigation-chart-label',
      ])
        ReferenceForegroundConsensusGroup(
          key: ReferenceForegroundConsensusKey(
            controlIdentity: control,
            selection: ReferenceForegroundSelectionState.unselected,
            semanticRole: navigationBlackRole,
            surfaceRole: navigationWhiteSurfaceRole,
          ),
          memberCaseIds: [
            'prices',
            'trade',
            'history-positions',
            'history-orders',
            'history-orders-summary',
            'history-deals',
          ],
        ),
      for (final control in <String>[
        'navigation-trade-icon',
        'navigation-trade-label',
      ])
        ReferenceForegroundConsensusGroup(
          key: ReferenceForegroundConsensusKey(
            controlIdentity: control,
            selection: ReferenceForegroundSelectionState.unselected,
            semanticRole: navigationBlackRole,
            surfaceRole: navigationWhiteSurfaceRole,
          ),
          memberCaseIds: [
            'prices',
            'chart',
            'history-positions',
            'history-orders',
            'history-orders-summary',
            'history-deals',
          ],
        ),
      for (final control in <String>[
        'navigation-history-icon',
        'navigation-history-label',
      ])
        ReferenceForegroundConsensusGroup(
          key: ReferenceForegroundConsensusKey(
            controlIdentity: control,
            selection: ReferenceForegroundSelectionState.unselected,
            semanticRole: navigationBlackRole,
            surfaceRole: navigationWhiteSurfaceRole,
          ),
          memberCaseIds: ['prices', 'chart', 'trade'],
        ),
      for (final control in <String>[
        'navigation-settings-icon',
        'navigation-settings-label',
      ])
        ReferenceForegroundConsensusGroup(
          key: ReferenceForegroundConsensusKey(
            controlIdentity: control,
            selection: ReferenceForegroundSelectionState.unselected,
            semanticRole: navigationBlackRole,
            surfaceRole: navigationWhiteSurfaceRole,
          ),
          memberCaseIds: [
            'prices',
            'chart',
            'trade',
            'history-positions',
            'history-orders',
            'history-orders-summary',
            'history-deals',
          ],
        ),
    ];

const _tradeScrollbarRegion = ReferenceVisualRegion(
  name: 'trade-scrollbar-indicator',
  type: ReferenceVisualRegionType.scrollbar,
  rect: ReferencePixelRect(581, 318, 5, 790),
);

const _historyOrdersScrollbarRegion = ReferenceVisualRegion(
  name: 'history-orders-scrollbar-indicator',
  type: ReferenceVisualRegionType.scrollbar,
  rect: ReferencePixelRect(581, 177, 5, 687),
);

const _historyOrdersSummaryScrollbarRegion = ReferenceVisualRegion(
  name: 'history-orders-summary-scrollbar-indicator',
  type: ReferenceVisualRegionType.scrollbar,
  rect: ReferencePixelRect(581, 474, 5, 688),
);

const _historyDealsScrollbarRegion = ReferenceVisualRegion(
  name: 'history-deals-scrollbar-indicator',
  type: ReferenceVisualRegionType.scrollbar,
  rect: ReferencePixelRect(581, 525, 5, 637),
);

const _baseStaticControls = <ReferenceStaticControlRegion>[
  ReferenceStaticControlRegion(
    name: 'navigation-prices-icon',
    rect: ReferencePixelRect(70, 1180, 42, 38),
  ),
  ReferenceStaticControlRegion(
    name: 'navigation-chart-icon',
    rect: ReferencePixelRect(175, 1180, 35, 38),
  ),
  ReferenceStaticControlRegion(
    name: 'navigation-trade-icon',
    rect: ReferencePixelRect(270, 1180, 45, 38),
  ),
  ReferenceStaticControlRegion(
    name: 'navigation-history-icon',
    rect: ReferencePixelRect(375, 1180, 48, 38),
  ),
  ReferenceStaticControlRegion(
    name: 'navigation-settings-icon',
    rect: ReferencePixelRect(478, 1180, 42, 38),
  ),
];

const _navigationShadowRegions = <ReferenceShadowRegion>[
  ReferenceShadowRegion(
    name: 'bottom-navigation-shadow-left',
    rect: ReferencePixelRect(28, 1174, 6, 72),
    surfaceSampleRect: ReferencePixelRect(460, 1238, 8, 5),
  ),
  ReferenceShadowRegion(
    name: 'bottom-navigation-shadow-right',
    rect: ReferencePixelRect(557, 1174, 6, 72),
    surfaceSampleRect: ReferencePixelRect(460, 1238, 8, 5),
  ),
  ReferenceShadowRegion(
    name: 'bottom-navigation-shadow-bottom',
    rect: ReferencePixelRect(28, 1246, 535, 16),
    surfaceSampleRect: ReferencePixelRect(460, 1238, 8, 5),
  ),
];

const _systemStatusMasks = <ReferenceDynamicMask>[
  ReferenceDynamicMask(
    kind: ReferenceDynamicMaskKind.systemStatusValues,
    rect: ReferencePixelRect(62, 15, 98, 41),
    reason:
        'The operating-system clock and silent indicator are capture-time values.',
  ),
  ReferenceDynamicMask(
    kind: ReferenceDynamicMaskKind.systemStatusValues,
    rect: ReferencePixelRect(406, 15, 184, 41),
    reason:
        'Carrier, signal, and battery status are supplied by the device at capture time.',
  ),
];

const _systemStatusAuditRows = <StaticTextRegion>[
  StaticTextRegion(
    name: 'system-status-clock',
    referenceRect: ReferencePixelRect(62, 15, 98, 41),
    candidateRect: ReferencePixelRect(62, 15, 98, 41),
    ink: referencePrimaryInk,
    auditMode: StaticTextAuditMode.dynamicOnly,
  ),
  StaticTextRegion(
    name: 'system-status-device',
    referenceRect: ReferencePixelRect(406, 15, 184, 41),
    candidateRect: ReferencePixelRect(406, 15, 184, 41),
    ink: referencePrimaryInk,
    auditMode: StaticTextAuditMode.dynamicOnly,
  ),
];

const _pricesStaticControls = <ReferenceStaticControlRegion>[
  ..._baseStaticControls,
  ReferenceStaticControlRegion(
    name: 'prices-toolbar-list',
    rect: ReferencePixelRect(25, 80, 66, 66),
  ),
  ReferenceStaticControlRegion(
    name: 'prices-toolbar-edit',
    rect: ReferencePixelRect(423, 80, 66, 66),
  ),
  ReferenceStaticControlRegion(
    name: 'prices-toolbar-search',
    rect: ReferencePixelRect(503, 80, 66, 66),
  ),
  ReferenceStaticControlRegion(
    name: 'prices-first-change-accent',
    rect: ReferencePixelRect(63, 158, 65, 27),
  ),
  ReferenceStaticControlRegion(
    name: 'prices-second-change-accent',
    rect: ReferencePixelRect(44, 264, 68, 27),
  ),
  ReferenceStaticControlRegion(
    name: 'prices-first-low-label',
    rect: ReferencePixelRect(372, 220, 13, 38),
  ),
  ReferenceStaticControlRegion(
    name: 'prices-first-high-label',
    rect: ReferencePixelRect(487, 220, 15, 38),
  ),
  ReferenceStaticControlRegion(
    name: 'prices-second-low-label',
    rect: ReferencePixelRect(392, 320, 13, 38),
  ),
  ReferenceStaticControlRegion(
    name: 'prices-second-high-label',
    rect: ReferencePixelRect(515, 320, 15, 38),
  ),
];

const _chartStaticControls = <ReferenceStaticControlRegion>[
  ..._baseStaticControls,
  ReferenceStaticControlRegion(
    name: 'toolbar-timeframe',
    rect: ReferencePixelRect(12, 92, 52, 42),
  ),
  ReferenceStaticControlRegion(
    name: 'ticket-sell-label',
    rect: ReferencePixelRect(0, 144, 62, 18),
  ),
  ReferenceStaticControlRegion(
    name: 'ticket-buy-label',
    rect: ReferencePixelRect(418, 146, 34, 16),
  ),
  ReferenceStaticControlRegion(
    name: 'plot-symbol',
    rect: ReferencePixelRect(0, 200, 105, 20),
  ),
  ReferenceStaticControlRegion(
    name: 'plot-subtitle',
    rect: ReferencePixelRect(0, 225, 180, 35),
  ),
  ReferenceStaticControlRegion(
    name: 'chart-plot-frame',
    rect: ReferencePixelRect(0, 260, 507, 7),
  ),
  ReferenceStaticControlRegion(
    name: 'chart-right-price-axis',
    rect: ReferencePixelRect(507, 260, 83, 880),
  ),
  ReferenceStaticControlRegion(
    name: 'chart-x-axis-labels',
    rect: ReferencePixelRect(0, 1140, 507, 28),
  ),
];

const _tradeStaticControls = <ReferenceStaticControlRegion>[
  ..._baseStaticControls,
  ReferenceStaticControlRegion(
    name: 'trade-header-currency-label',
    rect: ReferencePixelRect(315, 97, 49, 27),
  ),
  ReferenceStaticControlRegion(
    name: 'metric-label',
    rect: ReferencePixelRect(4, 157, 110, 38),
  ),
  ReferenceStaticControlRegion(
    name: 'section-label',
    rect: ReferencePixelRect(4, 327, 190, 38),
  ),
  ReferenceStaticControlRegion(
    name: 'position-symbol',
    rect: ReferencePixelRect(4, 369, 100, 40),
  ),
  ReferenceStaticControlRegion(
    name: 'trade-section-surface',
    rect: ReferencePixelRect(0, 327, 590, 38),
  ),
  ReferenceStaticControlRegion(
    name: 'trade-scrollbar-indicator',
    rect: ReferencePixelRect(581, 318, 5, 790),
  ),
];

const _historyStaticControls = <ReferenceStaticControlRegion>[
  ..._baseStaticControls,
  ReferenceStaticControlRegion(
    name: 'history-segment-control',
    rect: ReferencePixelRect(105, 90, 385, 49),
  ),
];

const _historyPositionsStaticControls = <ReferenceStaticControlRegion>[
  ..._historyStaticControls,
  ReferenceStaticControlRegion(
    name: 'history-positions-selected-segment',
    rect: ReferencePixelRect(105, 97, 130, 6),
  ),
];

const _historyOrdersStaticControls = <ReferenceStaticControlRegion>[
  ..._historyStaticControls,
  ReferenceStaticControlRegion(
    name: 'history-orders-scrollbar-indicator',
    rect: ReferencePixelRect(581, 177, 5, 687),
  ),
];

const _historyOrdersSummaryStaticControls = <ReferenceStaticControlRegion>[
  ..._historyStaticControls,
  ReferenceStaticControlRegion(
    name: 'history-orders-summary-scrollbar-indicator',
    rect: ReferencePixelRect(581, 474, 5, 688),
  ),
];

const _historyDealsStaticControls = <ReferenceStaticControlRegion>[
  ..._historyStaticControls,
  ReferenceStaticControlRegion(
    name: 'history-deals-scrollbar-indicator',
    rect: ReferencePixelRect(581, 525, 5, 637),
  ),
];

class TabReferenceCase {
  const TabReferenceCase({
    required this.id,
    required this.fileName,
    this.referenceSha256 = '',
    required this.state,
    required this.route,
    required this.selectedTab,
    required this.captureState,
    required this.staticAuditRegion,
    required this.visualRegions,
    required this.staticControlRegions,
    this.shadowRegions = const <ReferenceShadowRegion>[],
    this.staticTextRegions = const <StaticTextRegion>[],
    this.dynamicMaskRegions = const <ReferenceDynamicMask>[],
    this.referenceForegroundInteriors = const <ReferenceForegroundInterior>[],
    this.referenceSurfaceInteriors = const <ReferenceSurfaceInterior>[],
    this.foregroundRoleByRegion = const <String, String>{},
    this.surfaceRoleByRegion = const <String, String>{},
    this.surfaceRegions = const <ReferenceSurfaceRegion>[],
    this.foregroundSelectionByRegion =
        const <String, ReferenceForegroundSelectionState>{},
  });

  final String id;
  final String fileName;
  final String referenceSha256;
  final TabReferenceState state;
  final String route;
  final ReferenceSelectedTab selectedTab;
  final ReferenceCaptureState captureState;
  final ReferencePixelRect staticAuditRegion;
  final List<ReferenceVisualRegion> visualRegions;
  final List<ReferenceStaticControlRegion> staticControlRegions;
  final List<ReferenceShadowRegion> shadowRegions;
  final List<StaticTextRegion> staticTextRegions;
  final List<ReferenceDynamicMask> dynamicMaskRegions;
  final List<ReferenceForegroundInterior> referenceForegroundInteriors;
  final List<ReferenceSurfaceInterior> referenceSurfaceInteriors;
  final Map<String, String> foregroundRoleByRegion;
  final Map<String, String> surfaceRoleByRegion;
  final List<ReferenceSurfaceRegion> surfaceRegions;
  final Map<String, ReferenceForegroundSelectionState>
  foregroundSelectionByRegion;

  /// Compatibility view consumed by the existing typography comparator.
  List<ReferencePixelRect> get dynamicMasks => dynamicMaskRegions
      .map((ReferenceDynamicMask mask) => mask.rect)
      .toList(growable: false);

  String get referencePath => '../iconMau/anhmau/$fileName';
}

const tabReferenceLogicalSize = ReferenceSize(393.3333333333, 853.3333333333);
const tabReferenceDevicePixelRatio = 1.5;

const tabReferenceCases = <TabReferenceCase>[
  TabReferenceCase(
    id: 'prices',
    fileName: 'photo_2026-08-25_22-30-10.jpg',
    referenceSha256:
        '6739a1668fa87ca745f5e43ea472c2413ef0434fa1074c3b180c7278ea658db5',
    state: TabReferenceState.prices,
    route: '/prices',
    selectedTab: ReferenceSelectedTab.prices,
    captureState: ReferenceCaptureState(
      description: 'Market Watch at the initial, top-of-list position.',
      scrollState: ReferenceScrollState.atTop,
    ),
    staticAuditRegion: _referenceCanvas,
    visualRegions: [
      ..._baseVisualRegions,
      _pricesHeaderForegroundVisual,
      _pricesBodyForegroundVisual,
      _pricesSelectedPillVisual,
    ],
    surfaceRegions: _pricesNavigationSurfaceRegions,
    staticControlRegions: _pricesStaticControls,
    shadowRegions: _navigationShadowRegions,
    referenceForegroundInteriors: _pricesForegroundInteriors,
    referenceSurfaceInteriors: _pricesSurfaceInteriors,
    foregroundRoleByRegion: _pricesForegroundRoles,
    surfaceRoleByRegion: _pricesSurfaceRoles,
    foregroundSelectionByRegion: _pricesForegroundSelections,
    staticTextRegions: [
      ..._systemStatusAuditRows,
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
        referenceRect: ReferencePixelRect(361, 180, 109, 37),
        candidateRect: ReferencePixelRect(361, 180, 109, 37),
        ink: referenceBlueInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'first-quote-ask',
        referenceRect: ReferencePixelRect(481, 180, 100, 37),
        candidateRect: ReferencePixelRect(481, 180, 100, 37),
        ink: referenceBlueInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'second-quote-bid',
        referenceRect: ReferencePixelRect(385, 278, 90, 40),
        candidateRect: ReferencePixelRect(385, 278, 90, 40),
        ink: referenceRedInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'second-quote-ask',
        referenceRect: ReferencePixelRect(505, 278, 74, 40),
        candidateRect: ReferencePixelRect(505, 278, 74, 40),
        ink: referenceRedInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'first-quote-time',
        referenceRect: ReferencePixelRect(11, 226, 74, 16),
        candidateRect: ReferencePixelRect(11, 226, 74, 16),
        ink: referenceSecondaryInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'first-quote-low-label',
        referenceRect: ReferencePixelRect(372, 220, 13, 38),
        candidateRect: ReferencePixelRect(372, 220, 13, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'first-quote-low-value',
        referenceRect: ReferencePixelRect(390, 220, 70, 38),
        candidateRect: ReferencePixelRect(390, 220, 70, 38),
        ink: referenceSecondaryInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'first-quote-high-label',
        referenceRect: ReferencePixelRect(487, 220, 15, 38),
        candidateRect: ReferencePixelRect(487, 220, 15, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'first-quote-high-value',
        referenceRect: ReferencePixelRect(508, 220, 72, 38),
        candidateRect: ReferencePixelRect(508, 220, 72, 38),
        ink: referenceSecondaryInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'second-quote-time',
        referenceRect: ReferencePixelRect(31, 327, 75, 17),
        candidateRect: ReferencePixelRect(31, 327, 75, 17),
        ink: referenceSecondaryInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'second-quote-low-label',
        referenceRect: ReferencePixelRect(392, 320, 13, 38),
        candidateRect: ReferencePixelRect(392, 320, 13, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'second-quote-low-value',
        referenceRect: ReferencePixelRect(410, 320, 50, 38),
        candidateRect: ReferencePixelRect(410, 320, 50, 38),
        ink: referenceSecondaryInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'second-quote-high-label',
        referenceRect: ReferencePixelRect(515, 320, 15, 38),
        candidateRect: ReferencePixelRect(515, 320, 15, 38),
        ink: referenceSecondaryInk,
      ),
      StaticTextRegion(
        name: 'second-quote-high-value',
        referenceRect: ReferencePixelRect(536, 320, 43, 38),
        candidateRect: ReferencePixelRect(536, 320, 43, 38),
        ink: referenceSecondaryInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      ..._pricesNavigationRegions,
    ],
    dynamicMaskRegions: [
      ..._systemStatusMasks,
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.livePrices,
        rect: ReferencePixelRect(361, 180, 109, 37),
        reason: 'The first quote bid is supplied by the live market feed.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.livePrices,
        rect: ReferencePixelRect(481, 180, 100, 37),
        reason: 'The first quote ask is supplied by the live market feed.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.livePrices,
        rect: ReferencePixelRect(385, 278, 90, 40),
        reason: 'The second quote bid is supplied by the live market feed.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.livePrices,
        rect: ReferencePixelRect(505, 278, 74, 40),
        reason: 'The second quote ask is supplied by the live market feed.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.livePrices,
        rect: ReferencePixelRect(390, 220, 70, 38),
        reason: 'The first quote low is derived from the live market session.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.livePrices,
        rect: ReferencePixelRect(508, 220, 72, 38),
        reason: 'The first quote high is derived from the live market session.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.livePrices,
        rect: ReferencePixelRect(410, 320, 50, 38),
        reason: 'The second quote low is derived from the live market session.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.livePrices,
        rect: ReferencePixelRect(536, 320, 43, 38),
        reason:
            'The second quote high is derived from the live market session.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveTimes,
        rect: ReferencePixelRect(11, 226, 74, 16),
        reason: 'The first quote timestamp advances with the live market feed.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveTimes,
        rect: ReferencePixelRect(31, 327, 75, 17),
        reason:
            'The second quote timestamp advances with the live market feed.',
      ),
    ],
  ),
  TabReferenceCase(
    id: 'chart',
    fileName: 'photo_2026-08-25_22-30-17.jpg',
    referenceSha256:
        'e5d878286e76f843fec97ac2fc14de68d219fd20475a381a2bda941226854e31',
    state: TabReferenceState.chart,
    route: '/chart',
    selectedTab: ReferenceSelectedTab.chart,
    captureState: ReferenceCaptureState(
      description: 'One-click chart with the initial visible candle range.',
      scrollState: ReferenceScrollState.atTop,
    ),
    staticAuditRegion: _referenceCanvas,
    visualRegions: [..._baseVisualRegions, _chartSelectedPillVisual],
    surfaceRegions: _chartNavigationSurfaceRegions,
    staticControlRegions: _chartStaticControls,
    shadowRegions: _navigationShadowRegions,
    referenceForegroundInteriors: _chartForegroundInteriors,
    referenceSurfaceInteriors: _chartSurfaceInteriors,
    foregroundRoleByRegion: _chartForegroundRoles,
    surfaceRoleByRegion: _chartSurfaceRoles,
    foregroundSelectionByRegion: _chartForegroundSelections,
    staticTextRegions: [
      ..._systemStatusAuditRows,
      StaticTextRegion(
        name: 'toolbar-timeframe',
        referenceRect: ReferencePixelRect(12, 92, 52, 42),
        candidateRect: ReferencePixelRect(12, 90, 52, 42),
        ink: referenceChartToolbarInk,
        geometryInk: referencePrimaryInk,
      ),
      StaticTextRegion(
        name: 'ticket-sell-label',
        referenceRect: ReferencePixelRect(0, 144, 62, 18),
        candidateRect: ReferencePixelRect(0, 144, 62, 18),
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
        referenceRect: ReferencePixelRect(35, 162, 120, 33),
        candidateRect: ReferencePixelRect(35, 162, 120, 33),
        ink: referenceWhiteInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'ticket-buy-price',
        referenceRect: ReferencePixelRect(445, 162, 135, 33),
        candidateRect: ReferencePixelRect(445, 162, 135, 33),
        ink: referenceWhiteInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
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
        measureInkDensity: false,
      ),
      ..._chartNavigationRegions,
    ],
    dynamicMaskRegions: [
      ..._systemStatusMasks,
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.livePrices,
        rect: ReferencePixelRect(35, 162, 120, 33),
        reason: 'The sell quote in the order ticket is a live market value.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.livePrices,
        rect: ReferencePixelRect(445, 162, 135, 33),
        reason: 'The buy quote in the order ticket is a live market value.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveChartContent,
        rect: ReferencePixelRect(0, 267, 507, 873),
        reason:
            'Only the drawable candle plot changes as new market candles arrive.',
      ),
    ],
  ),
  TabReferenceCase(
    id: 'trade',
    fileName: 'photo_2026-08-25_22-30-20.jpg',
    referenceSha256:
        '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
    state: TabReferenceState.trade,
    route: '/trade',
    selectedTab: ReferenceSelectedTab.trade,
    captureState: ReferenceCaptureState(
      description:
          'Open Positions at the initial, top-of-list position with a visible scrollbar.',
      scrollState: ReferenceScrollState.atTop,
      hasVisibleScrollbar: true,
    ),
    staticAuditRegion: _referenceCanvas,
    visualRegions: [
      ..._baseVisualRegions,
      _tradeSelectedPillVisual,
      _tradeScrollbarRegion,
    ],
    surfaceRegions: _tradeNavigationSurfaceRegions,
    staticControlRegions: _tradeStaticControls,
    shadowRegions: _navigationShadowRegions,
    referenceForegroundInteriors: _tradeForegroundInteriors,
    referenceSurfaceInteriors: _tradeSurfaceInteriors,
    foregroundRoleByRegion: _tradeForegroundRoles,
    surfaceRoleByRegion: _tradeSurfaceRoles,
    foregroundSelectionByRegion: _tradeForegroundSelections,
    staticTextRegions: [
      ..._systemStatusAuditRows,
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
        name: 'header-profit-value',
        referenceRect: ReferencePixelRect(225, 97, 85, 27),
        candidateRect: ReferencePixelRect(225, 97, 85, 27),
        ink: referenceBlueInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      StaticTextRegion(
        name: 'header-profit-currency',
        referenceRect: ReferencePixelRect(315, 97, 49, 27),
        candidateRect: ReferencePixelRect(315, 97, 49, 27),
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
        referenceRect: ReferencePixelRect(494, 388, 87, 27),
        candidateRect: ReferencePixelRect(494, 388, 87, 27),
        ink: referenceBlueInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      ..._tradeNavigationRegions,
    ],
    dynamicMaskRegions: [
      ..._systemStatusMasks,
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(225, 97, 85, 27),
        reason:
            'The header floating profit and loss numeric value changes with live quotes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(494, 388, 87, 27),
        reason:
            'The first open-position profit and loss changes with live quotes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(494, 467, 87, 28),
        reason:
            'The second open-position profit and loss changes with live quotes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(494, 547, 87, 27),
        reason:
            'The third open-position profit and loss changes with live quotes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(494, 626, 87, 28),
        reason:
            'The fourth open-position profit and loss changes with live quotes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(494, 706, 87, 28),
        reason:
            'The fifth open-position profit and loss changes with live quotes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(494, 786, 87, 27),
        reason:
            'The sixth open-position profit and loss changes with live quotes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(486, 866, 95, 27),
        reason:
            'The seventh open-position profit and loss changes with live quotes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(486, 945, 95, 28),
        reason:
            'The eighth open-position profit and loss changes with live quotes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(486, 1025, 95, 27),
        reason:
            'The ninth open-position profit and loss changes with live quotes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(495, 1104, 86, 18),
        reason:
            'The clipped tenth open-position profit and loss changes with live quotes.',
      ),
    ],
  ),
  TabReferenceCase(
    id: 'history-positions',
    fileName: 'photo_2026-08-25_22-30-23.jpg',
    referenceSha256:
        '40bfd8ddf3e24158453da32e4318e9219d02a201b09bb2fb53d6ee95a98a5924',
    state: TabReferenceState.historyPositions,
    route: '/history/positions',
    selectedTab: ReferenceSelectedTab.history,
    captureState: ReferenceCaptureState(
      description:
          'History Positions tab at the initial, top-of-list position.',
      scrollState: ReferenceScrollState.atTop,
    ),
    staticAuditRegion: _referenceCanvas,
    visualRegions: [..._baseVisualRegions, _historySelectedPillVisual],
    surfaceRegions: _historyNavigationSurfaceRegions,
    staticControlRegions: _historyPositionsStaticControls,
    shadowRegions: _navigationShadowRegions,
    referenceForegroundInteriors: _historyPositionsForegroundInteriors,
    referenceSurfaceInteriors: _historySurfaceInteriors,
    foregroundRoleByRegion: _historyForegroundRoles,
    surfaceRoleByRegion: _historySurfaceRoles,
    foregroundSelectionByRegion: _historyForegroundSelections,
    staticTextRegions: [
      ..._systemStatusAuditRows,
      StaticTextRegion(
        name: 'selected-segment-surface',
        referenceRect: ReferencePixelRect(105, 97, 130, 6),
        candidateRect: ReferencePixelRect(105, 97, 130, 6),
        ink: referenceHistorySegmentSelectedInk,
        geometryColorTolerance: 10,
        semanticColorTolerance: 6,
        measureLargestGeometryComponent: true,
        measureInkDensity: false,
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
        referenceRect: ReferencePixelRect(505, 238, 85, 37),
        candidateRect: ReferencePixelRect(505, 238, 85, 37),
        ink: referenceBlueInk,
        auditMode: StaticTextAuditMode.dynamicOnly,
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
        auditMode: StaticTextAuditMode.dynamicOnly,
      ),
      ..._historyNavigationRegions,
    ],
    dynamicMaskRegions: [
      ..._systemStatusMasks,
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(505, 238, 85, 37),
        reason:
            'The open-position profit value changes until the position closes.',
      ),
      ReferenceDynamicMask(
        kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
        rect: ReferencePixelRect(455, 552, 135, 40),
        reason:
            'The history profit summary is recalculated from position outcomes.',
      ),
    ],
  ),
  TabReferenceCase(
    id: 'history-orders',
    fileName: 'photo_2026-08-25_22-30-26.jpg',
    referenceSha256:
        '48dbab6778e247325222bf0e10e991f0ef4d160ecf4cb4127be1e6d1b6eb83c1',
    state: TabReferenceState.historyOrders,
    route: '/history/orders',
    selectedTab: ReferenceSelectedTab.history,
    captureState: ReferenceCaptureState(
      description: 'History Orders tab after a 32 physical-pixel list offset.',
      scrollState: ReferenceScrollState.offset,
      scrollOffset: 32,
      hasVisibleScrollbar: true,
    ),
    staticAuditRegion: _referenceCanvas,
    visualRegions: [
      ..._baseVisualRegions,
      _historySelectedPillVisual,
      _historyOrdersScrollbarRegion,
    ],
    surfaceRegions: _historyNavigationSurfaceRegions,
    staticControlRegions: _historyOrdersStaticControls,
    shadowRegions: _navigationShadowRegions,
    referenceForegroundInteriors: _historyOrdersForegroundInteriors,
    referenceSurfaceInteriors: _historySurfaceInteriors,
    foregroundRoleByRegion: _historyForegroundRoles,
    surfaceRoleByRegion: _historySurfaceRoles,
    foregroundSelectionByRegion: _historyForegroundSelections,
    staticTextRegions: [
      ..._systemStatusAuditRows,
      StaticTextRegion(
        name: 'selected-segment-surface',
        referenceRect: ReferencePixelRect(230, 97, 135, 6),
        candidateRect: ReferencePixelRect(230, 97, 135, 6),
        ink: referenceHistorySegmentSelectedInk,
        geometryColorTolerance: 10,
        semanticColorTolerance: 6,
        measureLargestGeometryComponent: true,
        measureInkDensity: false,
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
    dynamicMaskRegions: _systemStatusMasks,
  ),
  TabReferenceCase(
    id: 'history-orders-summary',
    fileName: 'photo_2026-08-25_22-30-29.jpg',
    referenceSha256:
        '7f8d2fe5c086eacb5a8364435373645a4ba3e2ba3df7b852467b5a51d0ee45ee',
    state: TabReferenceState.historyOrdersSummary,
    route: '/history/orders',
    selectedTab: ReferenceSelectedTab.history,
    captureState: ReferenceCaptureState(
      description: 'History Orders tab scrolled to the end summary.',
      scrollState: ReferenceScrollState.atEnd,
      hasVisibleScrollbar: true,
    ),
    staticAuditRegion: _referenceCanvas,
    visualRegions: [
      ..._baseVisualRegions,
      _historySelectedPillVisual,
      _historyOrdersSummaryScrollbarRegion,
    ],
    surfaceRegions: _historyNavigationSurfaceRegions,
    staticControlRegions: _historyOrdersSummaryStaticControls,
    shadowRegions: _navigationShadowRegions,
    referenceForegroundInteriors: _historyOrdersSummaryForegroundInteriors,
    referenceSurfaceInteriors: _historySurfaceInteriors,
    foregroundRoleByRegion: _historyForegroundRoles,
    surfaceRoleByRegion: _historySurfaceRoles,
    foregroundSelectionByRegion: _historyForegroundSelections,
    staticTextRegions: [
      ..._systemStatusAuditRows,
      StaticTextRegion(
        name: 'selected-segment-surface',
        referenceRect: ReferencePixelRect(230, 97, 135, 6),
        candidateRect: ReferencePixelRect(230, 97, 135, 6),
        ink: referenceHistorySegmentSelectedInk,
        geometryColorTolerance: 10,
        semanticColorTolerance: 6,
        measureLargestGeometryComponent: true,
        measureInkDensity: false,
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
    dynamicMaskRegions: _systemStatusMasks,
  ),
  TabReferenceCase(
    id: 'history-deals',
    fileName: 'photo_2026-08-25_22-30-34.jpg',
    referenceSha256:
        '6fbbf3ccfc834b94052df32713a153c10518298b644844fb9482fa51a70e3bb9',
    state: TabReferenceState.historyDeals,
    route: '/history/deals',
    selectedTab: ReferenceSelectedTab.history,
    captureState: ReferenceCaptureState(
      description: 'History Deals tab scrolled to the end summary.',
      scrollState: ReferenceScrollState.atEnd,
      hasVisibleScrollbar: true,
    ),
    staticAuditRegion: _referenceCanvas,
    visualRegions: [
      ..._baseVisualRegions,
      _historySelectedPillVisual,
      _historyDealsScrollbarRegion,
    ],
    surfaceRegions: _historyNavigationSurfaceRegions,
    staticControlRegions: _historyDealsStaticControls,
    shadowRegions: _navigationShadowRegions,
    referenceForegroundInteriors: _historyDealsForegroundInteriors,
    referenceSurfaceInteriors: _historySurfaceInteriors,
    foregroundRoleByRegion: _historyForegroundRoles,
    surfaceRoleByRegion: _historySurfaceRoles,
    foregroundSelectionByRegion: _historyForegroundSelections,
    staticTextRegions: [
      ..._systemStatusAuditRows,
      StaticTextRegion(
        name: 'selected-segment-surface',
        referenceRect: ReferencePixelRect(355, 97, 135, 6),
        candidateRect: ReferencePixelRect(355, 97, 135, 6),
        ink: referenceHistorySegmentSelectedInk,
        geometryColorTolerance: 10,
        semanticColorTolerance: 6,
        measureLargestGeometryComponent: true,
        measureInkDensity: false,
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
    dynamicMaskRegions: _systemStatusMasks,
  ),
];
