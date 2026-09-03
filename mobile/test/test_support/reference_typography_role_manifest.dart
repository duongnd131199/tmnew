class ReferenceRendererProfile {
  const ReferenceRendererProfile._(this.id, {required this.isPrimary});

  static const ios = ReferenceRendererProfile._('ios', isPrimary: true);
  static const android = ReferenceRendererProfile._(
    'android',
    isPrimary: false,
  );
  static const deterministicHost = ReferenceRendererProfile._(
    'deterministic-host',
    isPrimary: false,
  );
  static const primary = ios;

  final String id;
  final bool isPrimary;
}

const referenceFontSpecimenRasterContract = <String, Object>{
  'colorModel': 'opaqueGrayscale',
  'alpha': 255,
  'redEqualsGreenEqualsBlue': true,
  'debugPaintBaselinesEnabledAtCapture': false,
};

class ReferenceFontSpecimenCandidate {
  const ReferenceFontSpecimenCandidate({
    required this.id,
    required this.family,
    required this.weight,
    required this.faceSha256,
    required this.selectable,
    required this.assetPath,
    required this.provenance,
    this.selectableRoleIds = const <String>{},
  });

  final String id;
  final String family;
  final int weight;
  final String faceSha256;
  final bool selectable;
  final String assetPath;
  final String provenance;
  final Set<String> selectableRoleIds;

  bool isSelectableForRole(String roleId) =>
      selectable &&
      (selectableRoleIds.isEmpty || selectableRoleIds.contains(roleId));
}

class ReferenceFontSpecimenRun {
  const ReferenceFontSpecimenRun({
    required this.key,
    required this.text,
    required this.codePoints,
    required this.usesCandidateFont,
    required this.renderingContract,
  });

  final String key;
  final String text;
  final Set<int> codePoints;
  final bool usesCandidateFont;
  final String renderingContract;
}

class ReferenceSpecimenRect {
  const ReferenceSpecimenRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;
}

enum ReferenceRunHorizontalLayout { leading, center, trailing }

enum ReferenceSourceBoundaryPolicy {
  directGuard,
  trailingBeforeScrollbar,
  leadingBeforeArrowJpegNoise,
  trailingBeforeAdjacentColoredTextJpegNoise,
}

enum ReferenceRunParameterProvenance { currentAppHypothesis }

const referenceRunParameterPolicy = <String, Object>{
  'provenance': 'currentAppHypothesis',
  'lockEligible': false,
  'requiresRasterScoreForWinner': true,
};

class ReferenceFontSpecimenOutputRun {
  const ReferenceFontSpecimenOutputRun({
    required this.comparisonId,
    required this.roleId,
    required this.text,
    required this.pointSize,
    required this.sourceNominalWeight,
    required this.candidateWeights,
    required this.physicalRect,
    required this.physicalBaseline,
    this.letterSpacing = 0,
    this.tabularFigures = false,
    this.sourceStringIndex,
    this.sourceStringStart,
    this.sourceStringEnd,
    this.horizontalLayout = ReferenceRunHorizontalLayout.leading,
    this.guardPadding = 4,
    this.parameterProvenance =
        ReferenceRunParameterProvenance.currentAppHypothesis,
    this.parameterLockEligible = false,
  });

  final String comparisonId;
  final String roleId;
  final String text;
  final double pointSize;
  final int sourceNominalWeight;
  final Set<int> candidateWeights;
  final ReferenceSpecimenRect physicalRect;
  final double physicalBaseline;
  final double letterSpacing;
  final bool tabularFigures;
  final int? sourceStringIndex;
  final int? sourceStringStart;
  final int? sourceStringEnd;
  final ReferenceRunHorizontalLayout horizontalLayout;
  final double guardPadding;
  final ReferenceRunParameterProvenance parameterProvenance;
  final bool parameterLockEligible;

  Map<String, Object> get parameterEvidence => {
    'provenance': parameterProvenance.name,
    'lockEligible': parameterLockEligible,
    'scope': 'pointSize-letterSpacing-features-sourceNominalWeight',
  };

  double get horizontalAnchor => switch (horizontalLayout) {
    ReferenceRunHorizontalLayout.leading => guardPadding,
    ReferenceRunHorizontalLayout.center => physicalRect.width / 2,
    ReferenceRunHorizontalLayout.trailing => physicalRect.width - guardPadding,
  };

  bool supports(ReferenceFontSpecimenCandidate candidate) =>
      candidateWeights.contains(candidate.weight);

  String keyFor(ReferenceFontSpecimenCandidate candidate) =>
      'reference-specimen-${candidate.id}-$comparisonId';
}

class ReferenceFontSpecimenSourceAnnotation {
  const ReferenceFontSpecimenSourceAnnotation({
    required this.candidateRunId,
    required this.comparisonId,
    required this.roleId,
    required this.text,
    required this.sourceId,
    required this.sourcePath,
    required this.sourceSha256,
    required this.physicalRect,
    required this.baseline,
    required this.sourceClass,
    this.candidateTextStart = 0,
    required this.candidateTextEnd,
    this.horizontalAnchor = 4,
    this.paddingLeft = 0,
    this.paddingTop = 0,
    this.paddingRight = 0,
    this.paddingBottom = 0,
    this.boundaryPolicy = ReferenceSourceBoundaryPolicy.directGuard,
    this.sourceRightExclusiveBoundaryX,
    this.lastStrongInkX,
    this.blankGuardStartX,
    this.blankGuardWidth,
    this.excludedNeighborStartX,
    this.excludedNeighborKind,
  });

  final String candidateRunId;
  final String comparisonId;
  final String roleId;
  final String text;
  final String sourceId;
  final String sourcePath;
  final String sourceSha256;
  final ReferenceSpecimenRect physicalRect;
  final double baseline;
  final String sourceClass;
  final int candidateTextStart;
  final int candidateTextEnd;
  final double horizontalAnchor;
  final int paddingLeft;
  final int paddingTop;
  final int paddingRight;
  final int paddingBottom;
  final ReferenceSourceBoundaryPolicy boundaryPolicy;
  final int? sourceRightExclusiveBoundaryX;
  final int? lastStrongInkX;
  final int? blankGuardStartX;
  final int? blankGuardWidth;
  final int? excludedNeighborStartX;
  final String? excludedNeighborKind;

  double get outputWidth => paddingLeft + physicalRect.width + paddingRight;
  double get outputHeight => paddingTop + physicalRect.height + paddingBottom;
  double get outputBaseline => paddingTop + baseline - physicalRect.top;
  double get outputHorizontalAnchor => paddingLeft + horizontalAnchor;

  bool get hasPadding =>
      paddingLeft != 0 ||
      paddingTop != 0 ||
      paddingRight != 0 ||
      paddingBottom != 0;
}

String? normalizeIosSimulatorRuntimeVersion(String sdk) {
  final runtime = RegExp(
    r'(?:SimRuntime\.iOS-|\biOS[- ])(\d+)[-.](\d+)(?:[-.](\d+))?',
    caseSensitive: false,
  ).firstMatch(sdk);
  if (runtime != null) {
    return [
      runtime.group(1)!,
      runtime.group(2)!,
      if (runtime.group(3) != null) runtime.group(3)!,
    ].join('.');
  }
  return RegExp(r'\b\d+\.\d+(?:\.\d+)?\b').firstMatch(sdk)?.group(0);
}

bool iosSimulatorRuntimeMatchesAppVersion(String sdk, String appVersion) {
  final runtime = normalizeIosSimulatorRuntimeVersion(sdk);
  if (runtime == null) return false;
  final app = RegExp(
    r'\b\d+\.\d+(?:\.\d+)?\b',
  ).firstMatch(appVersion)?.group(0);
  return app == runtime;
}

const referenceFontSpecimenStrings = <String>[
  'Giá  Biểu đồ  Giao dịch  Lịch sử  Cài đặt',
  'Số dư:  Vốn:  Tiền ký quỹ:  Mức ký quỹ (%):',
  'XAUUSD buy 1',
  '4637.05 → 4640.81',
  '376.00  -341.00  103 310.00  203.24',
  'L:  H:  M1  Orders  Deals',
];

const referenceFontSpecimenRuns = <ReferenceFontSpecimenRun>[
  ReferenceFontSpecimenRun(
    key: 'numeric-price-values',
    text: '4637.05 4640.81',
    codePoints: <int>{0x30, 0x31, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x2e},
    usesCandidateFont: true,
    renderingContract: 'locked-candidate-font-no-fallback',
  ),
  ReferenceFontSpecimenRun(
    key: 'numeric-price-arrow',
    text: '→',
    codePoints: <int>{0x2192},
    usesCandidateFont: false,
    renderingContract: 'keyed-deterministic-vector-shape-no-font-fallback',
  ),
];

const referenceFontSpecimenOutputRuns = <ReferenceFontSpecimenOutputRun>[
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'navigation-price-label',
    roleId: 'navigationLabel',
    text: 'Gia',
    pointSize: 9.5,
    sourceNominalWeight: 350,
    candidateWeights: <int>{400},
    physicalRect: ReferenceSpecimenRect(30, 30, 60, 35),
    physicalBaseline: 53,
    letterSpacing: .4,
    horizontalLayout: ReferenceRunHorizontalLayout.center,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'settings-title',
    roleId: 'settingsToolbarTitle',
    text: 'Cai dat',
    pointSize: 16.5,
    sourceNominalWeight: 500,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 70, 92, 35),
    physicalBaseline: 94,
    horizontalLayout: ReferenceRunHorizontalLayout.center,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'settings-row-title',
    roleId: 'settingsRowTitle',
    text: 'Tai khoan moi',
    pointSize: 16,
    sourceNominalWeight: 400,
    candidateWeights: <int>{400},
    physicalRect: ReferenceSpecimenRect(30, 118, 160, 35),
    physicalBaseline: 142,
    guardPadding: 3,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'trade-metric-balance-label',
    roleId: 'tradeMetricLabel',
    text: 'Số dư:',
    pointSize: 16,
    sourceNominalWeight: 400,
    candidateWeights: <int>{400},
    physicalRect: ReferenceSpecimenRect(30, 166, 81, 35),
    physicalBaseline: 191,
    letterSpacing: .5,
    tabularFigures: true,
    sourceStringIndex: 1,
    sourceStringStart: 0,
    sourceStringEnd: 6,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'trade-section-label',
    roleId: 'tradeSection',
    text: 'Lenh co trang thai',
    pointSize: 13,
    sourceNominalWeight: 650,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 214, 174, 33),
    physicalBaseline: 237,
    letterSpacing: .32,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'trade-position-symbol',
    roleId: 'tradePositionSymbol',
    text: 'XAUUSD',
    pointSize: 15.3,
    sourceNominalWeight: 300,
    candidateWeights: <int>{400},
    physicalRect: ReferenceSpecimenRect(30, 258, 93, 39),
    physicalBaseline: 287,
    letterSpacing: -.6,
    sourceStringIndex: 2,
    sourceStringStart: 0,
    sourceStringEnd: 6,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'trade-position-side-volume',
    roleId: 'tradePositionSide',
    text: 'buy 1',
    pointSize: 15.3,
    sourceNominalWeight: 600,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 306, 75, 39),
    physicalBaseline: 335,
    letterSpacing: -.6,
    sourceStringIndex: 2,
    sourceStringStart: 7,
    sourceStringEnd: 12,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'numeric-price-open',
    roleId: 'tradePositionSecondary',
    text: '4637.05',
    pointSize: 16,
    sourceNominalWeight: 400,
    candidateWeights: <int>{400},
    physicalRect: ReferenceSpecimenRect(30, 354, 112, 35),
    physicalBaseline: 384,
    letterSpacing: .98,
    tabularFigures: true,
    sourceStringIndex: 3,
    sourceStringStart: 0,
    sourceStringEnd: 7,
    guardPadding: 7,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'numeric-price-close',
    roleId: 'tradePositionSecondary',
    text: '4640.81',
    pointSize: 16,
    sourceNominalWeight: 400,
    candidateWeights: <int>{400},
    physicalRect: ReferenceSpecimenRect(30, 402, 112, 35),
    physicalBaseline: 432,
    letterSpacing: .98,
    tabularFigures: true,
    sourceStringIndex: 3,
    sourceStringStart: 10,
    sourceStringEnd: 17,
    guardPadding: 5,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'trade-profit-positive',
    roleId: 'tradePositionProfit',
    text: '376.00',
    pointSize: 21,
    sourceNominalWeight: 550,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 450, 115, 46),
    physicalBaseline: 484,
    letterSpacing: .17,
    tabularFigures: true,
    horizontalLayout: ReferenceRunHorizontalLayout.trailing,
    guardPadding: 8,
    sourceStringIndex: 4,
    sourceStringStart: 0,
    sourceStringEnd: 6,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'trade-profit-negative',
    roleId: 'tradePositionProfit',
    text: '-341.00',
    pointSize: 21,
    sourceNominalWeight: 550,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 504, 136, 42),
    physicalBaseline: 534,
    letterSpacing: .17,
    tabularFigures: true,
    horizontalLayout: ReferenceRunHorizontalLayout.trailing,
    guardPadding: 13,
    sourceStringIndex: 4,
    sourceStringStart: 8,
    sourceStringEnd: 15,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'trade-balance-value',
    roleId: 'tradeMetricValue',
    text: '103 310.00',
    pointSize: 16,
    sourceNominalWeight: 450,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 558, 140, 40),
    physicalBaseline: 587,
    letterSpacing: .2,
    tabularFigures: true,
    horizontalLayout: ReferenceRunHorizontalLayout.trailing,
    guardPadding: 6,
    sourceStringIndex: 4,
    sourceStringStart: 17,
    sourceStringEnd: 27,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'trade-margin-level-value',
    roleId: 'tradeMetricValue',
    text: '203.24',
    pointSize: 16,
    sourceNominalWeight: 450,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 606, 96, 37),
    physicalBaseline: 629,
    letterSpacing: .2,
    tabularFigures: true,
    horizontalLayout: ReferenceRunHorizontalLayout.trailing,
    guardPadding: 6,
    sourceStringIndex: 4,
    sourceStringStart: 29,
    sourceStringEnd: 35,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'prices-low-label',
    roleId: 'quoteRangeLabel',
    text: 'L:',
    pointSize: 13.2,
    sourceNominalWeight: 500,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 654, 20, 27),
    physicalBaseline: 679,
    letterSpacing: .45,
    sourceStringIndex: 5,
    sourceStringStart: 0,
    sourceStringEnd: 2,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'prices-high-label',
    roleId: 'quoteRangeLabel',
    text: 'H:',
    pointSize: 13.2,
    sourceNominalWeight: 500,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 698, 22, 27),
    physicalBaseline: 723,
    letterSpacing: .45,
    sourceStringIndex: 5,
    sourceStringStart: 4,
    sourceStringEnd: 6,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'chart-timeframe',
    roleId: 'chartTimeframe',
    text: 'M1',
    pointSize: 14.3,
    sourceNominalWeight: 450,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 742, 39, 39),
    physicalBaseline: 770,
    letterSpacing: -1.2,
    sourceStringIndex: 5,
    sourceStringStart: 8,
    sourceStringEnd: 10,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'history-orders-control',
    roleId: 'historySegment',
    text: 'Orders',
    pointSize: 14.5,
    sourceNominalWeight: 425,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 788, 530, 36),
    physicalBaseline: 815,
    letterSpacing: .05,
    sourceStringIndex: 5,
    sourceStringStart: 12,
    sourceStringEnd: 18,
  ),
  ReferenceFontSpecimenOutputRun(
    comparisonId: 'history-deals-control',
    roleId: 'historyDealsSegment',
    text: 'Deals',
    pointSize: 14,
    sourceNominalWeight: 425,
    candidateWeights: <int>{400, 700},
    physicalRect: ReferenceSpecimenRect(30, 834, 530, 36),
    physicalBaseline: 861,
    letterSpacing: .235,
    sourceStringIndex: 5,
    sourceStringStart: 20,
    sourceStringEnd: 25,
  ),
];

const referenceFontSpecimenSourceAnnotations =
    <ReferenceFontSpecimenSourceAnnotation>[
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'navigation-price-label',
        comparisonId: 'navigation-price-label',
        roleId: 'navigationLabel',
        text: 'Gia',
        sourceId: 'prices',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-10.jpg',
        sourceSha256:
            '6739a1668fa87ca745f5e43ea472c2413ef0434fa1074c3b180c7278ea658db5',
        physicalRect: ReferenceSpecimenRect(60, 1218, 60, 31),
        baseline: 1241,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 3,
        horizontalAnchor: 30,
        paddingBottom: 4,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'settings-title',
        comparisonId: 'settings-title',
        roleId: 'settingsToolbarTitle',
        text: 'Cai dat',
        sourceId: 'settings-secondary',
        sourcePath: '../iconMau/anhmau/photo_2026-08-27_21-13-34.jpg',
        sourceSha256:
            'bf67307f7e12f378ac2bf6abbbdf3b351d1e5492d59a50f0a0233b9a8955d092',
        physicalRect: ReferenceSpecimenRect(250, 96, 92, 31),
        baseline: 120,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 7,
        horizontalAnchor: 46,
        paddingBottom: 4,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'settings-row-title',
        comparisonId: 'settings-row-title',
        roleId: 'settingsRowTitle',
        text: 'Tai khoan moi',
        sourceId: 'settings-primary',
        sourcePath: '../iconMau/anhmau/image.png',
        sourceSha256:
            '4c4f508369707ef576521c220e918bc0db5c9f3bdb900334ff5a5a859fcfcf9c',
        physicalRect: ReferenceSpecimenRect(112, 232, 160, 35),
        baseline: 256,
        sourceClass: 'pngLossless',
        candidateTextEnd: 13,
        horizontalAnchor: 3,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'trade-metric-balance-label',
        comparisonId: 'trade-metric-balance-label',
        roleId: 'tradeMetricLabel',
        text: 'Số dư:',
        sourceId: 'trade-light',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        sourceSha256:
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        physicalRect: ReferenceSpecimenRect(3, 160, 71, 35),
        baseline: 185,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 6,
        paddingRight: 10,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'trade-section-label',
        comparisonId: 'trade-section-label',
        roleId: 'tradeSection',
        text: 'Lenh co trang thai',
        sourceId: 'trade-light',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        sourceSha256:
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        physicalRect: ReferenceSpecimenRect(3, 329, 165, 33),
        baseline: 352,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 18,
        paddingRight: 9,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'trade-position-symbol',
        comparisonId: 'trade-position-symbol',
        roleId: 'tradePositionSymbol',
        text: 'XAUUSD',
        sourceId: 'trade-light',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        sourceSha256:
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        physicalRect: ReferenceSpecimenRect(3, 369, 79, 35),
        baseline: 398,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 6,
        paddingRight: 14,
        paddingBottom: 4,
        boundaryPolicy: ReferenceSourceBoundaryPolicy
            .trailingBeforeAdjacentColoredTextJpegNoise,
        sourceRightExclusiveBoundaryX: 82,
        lastStrongInkX: 80,
        blankGuardStartX: 81,
        blankGuardWidth: 1,
        excludedNeighborStartX: 82,
        excludedNeighborKind: 'tradePositionSideVolume',
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'trade-position-side-volume',
        comparisonId: 'trade-position-side-volume',
        roleId: 'tradePositionSide',
        text: 'buy 1',
        sourceId: 'trade-light',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        sourceSha256:
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        physicalRect: ReferenceSpecimenRect(82, 369, 75, 35),
        baseline: 398,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 5,
        paddingBottom: 4,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'numeric-price-open',
        comparisonId: 'numeric-price-open',
        roleId: 'tradePositionSecondary',
        text: '4637.05',
        sourceId: 'trade-light',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        sourceSha256:
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        physicalRect: ReferenceSpecimenRect(1, 401, 99, 35),
        baseline: 431,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 7,
        horizontalAnchor: 7,
        paddingRight: 13,
        boundaryPolicy:
            ReferenceSourceBoundaryPolicy.leadingBeforeArrowJpegNoise,
        sourceRightExclusiveBoundaryX: 100,
        lastStrongInkX: 90,
        blankGuardStartX: 91,
        blankGuardWidth: 9,
        excludedNeighborStartX: 100,
        excludedNeighborKind: 'vectorArrow',
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'numeric-price-close',
        comparisonId: 'numeric-price-close',
        roleId: 'tradePositionSecondary',
        text: '4640.81',
        sourceId: 'trade-light',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        sourceSha256:
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        physicalRect: ReferenceSpecimenRect(123, 401, 107, 35),
        baseline: 431,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 7,
        horizontalAnchor: 5,
        paddingRight: 5,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'trade-profit-positive',
        comparisonId: 'trade-profit-positive',
        roleId: 'tradePositionProfit',
        text: '376.00',
        sourceId: 'trade-light',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        sourceSha256:
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        physicalRect: ReferenceSpecimenRect(475, 375, 107, 46),
        baseline: 409,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 6,
        horizontalAnchor: 107,
        paddingRight: 8,
        boundaryPolicy: ReferenceSourceBoundaryPolicy.trailingBeforeScrollbar,
        sourceRightExclusiveBoundaryX: 582,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'trade-profit-negative',
        comparisonId: 'trade-profit-negative',
        roleId: 'tradePositionProfit',
        text: '-341.00',
        sourceId: 'trade-light',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        sourceSha256:
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        physicalRect: ReferenceSpecimenRect(467, 857, 115, 42),
        baseline: 887,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 7,
        horizontalAnchor: 115,
        paddingLeft: 8,
        paddingRight: 13,
        boundaryPolicy: ReferenceSourceBoundaryPolicy.trailingBeforeScrollbar,
        sourceRightExclusiveBoundaryX: 582,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'trade-balance-value',
        comparisonId: 'trade-balance-value',
        roleId: 'tradeMetricValue',
        text: '103 310.00',
        sourceId: 'trade-light',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        sourceSha256:
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        physicalRect: ReferenceSpecimenRect(448, 156, 134, 40),
        baseline: 185,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 10,
        horizontalAnchor: 134,
        paddingRight: 6,
        boundaryPolicy: ReferenceSourceBoundaryPolicy.trailingBeforeScrollbar,
        sourceRightExclusiveBoundaryX: 582,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'trade-margin-level-value',
        comparisonId: 'trade-margin-level-value',
        roleId: 'tradeMetricValue',
        text: '203.24',
        sourceId: 'trade-light',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        sourceSha256:
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        physicalRect: ReferenceSpecimenRect(492, 291, 90, 37),
        baseline: 314,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 6,
        horizontalAnchor: 90,
        paddingRight: 6,
        boundaryPolicy: ReferenceSourceBoundaryPolicy.trailingBeforeScrollbar,
        sourceRightExclusiveBoundaryX: 582,
      ),
      ReferenceFontSpecimenSourceAnnotation(
        candidateRunId: 'chart-timeframe',
        comparisonId: 'chart-timeframe',
        roleId: 'chartTimeframe',
        text: 'M1',
        sourceId: 'chart',
        sourcePath: '../iconMau/anhmau/photo_2026-08-25_22-30-17.jpg',
        sourceSha256:
            'e5d878286e76f843fec97ac2fc14de68d219fd20475a381a2bda941226854e31',
        physicalRect: ReferenceSpecimenRect(13, 93, 39, 35),
        baseline: 121,
        sourceClass: 'jpegDiagnostic',
        candidateTextEnd: 2,
        paddingBottom: 4,
      ),
    ];

const referenceFontScoredRunIds = <String>{
  'navigation-price-label',
  'settings-title',
  'settings-row-title',
  'trade-metric-balance-label',
  'trade-section-label',
  'trade-position-symbol',
  'trade-position-side-volume',
  'numeric-price-open',
  'numeric-price-close',
  'trade-profit-positive',
  'trade-profit-negative',
  'trade-balance-value',
  'trade-margin-level-value',
  'chart-timeframe',
};

class ReferenceFontCoverageRun {
  const ReferenceFontCoverageRun({
    required this.index,
    required this.text,
    required this.physicalRect,
  });

  final int index;
  final String text;
  final ReferenceSpecimenRect physicalRect;

  String keyFor(ReferenceFontSpecimenCandidate candidate) =>
      'reference-coverage-${candidate.id}-$index';
}

const referenceFontCoverageRuns = <ReferenceFontCoverageRun>[
  ReferenceFontCoverageRun(
    index: 0,
    text: 'Giá  Biểu đồ  Giao dịch  Lịch sử  Cài đặt',
    physicalRect: ReferenceSpecimenRect(30, 30, 530, 40),
  ),
  ReferenceFontCoverageRun(
    index: 1,
    text: 'Số dư:  Vốn:  Tiền ký quỹ:  Mức ký quỹ (%):',
    physicalRect: ReferenceSpecimenRect(30, 90, 530, 40),
  ),
  ReferenceFontCoverageRun(
    index: 2,
    text: 'XAUUSD buy 1',
    physicalRect: ReferenceSpecimenRect(30, 150, 530, 40),
  ),
  ReferenceFontCoverageRun(
    index: 3,
    text: '4637.05 → 4640.81',
    physicalRect: ReferenceSpecimenRect(30, 210, 530, 40),
  ),
  ReferenceFontCoverageRun(
    index: 4,
    text: '376.00  -341.00  103 310.00  203.24',
    physicalRect: ReferenceSpecimenRect(30, 270, 530, 40),
  ),
  ReferenceFontCoverageRun(
    index: 5,
    text: 'L:  H:  M1  Orders  Deals',
    physicalRect: ReferenceSpecimenRect(30, 330, 530, 40),
  ),
];

const referenceFontSpecimenCandidates = <ReferenceFontSpecimenCandidate>[
  ReferenceFontSpecimenCandidate(
    id: 'reference-roboto-regular',
    family: 'Mt5ReferenceRoboto',
    weight: 400,
    faceSha256:
        'f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27',
    selectable: true,
    assetPath: 'assets/fonts/mt5-reference/Roboto-Regular.ttf',
    provenance: 'task1-locked-redistributable',
  ),
  ReferenceFontSpecimenCandidate(
    id: 'reference-roboto-bold',
    family: 'Mt5ReferenceRoboto',
    weight: 700,
    faceSha256:
        '9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70',
    selectable: true,
    assetPath: 'assets/fonts/mt5-reference/Roboto-Bold.ttf',
    provenance: 'task1-locked-redistributable',
  ),
  ReferenceFontSpecimenCandidate(
    id: 'reference-roboto-condensed-regular',
    family: 'Mt5ReferenceRobotoCondensed',
    weight: 400,
    faceSha256:
        'f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8',
    selectable: true,
    assetPath: 'assets/fonts/mt5-reference/RobotoCondensed-Regular.ttf',
    provenance: 'task1-locked-redistributable',
  ),
  ReferenceFontSpecimenCandidate(
    id: 'reference-roboto-condensed-bold',
    family: 'Mt5ReferenceRobotoCondensed',
    weight: 700,
    faceSha256:
        'ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a',
    selectable: true,
    assetPath: 'assets/fonts/mt5-reference/RobotoCondensed-Bold.ttf',
    provenance: 'task1-locked-redistributable',
  ),
  ReferenceFontSpecimenCandidate(
    id: 'control-current-roboto-variable-regular',
    family: 'Mt5RobotoVariable',
    weight: 400,
    faceSha256:
        'd7598e12c5dbef095ff8272cfc55da0250bd07fbdecbac8a530b9b277872a134',
    selectable: false,
    assetPath: 'assets/fonts/Roboto-Variable.ttf',
    provenance: 'current-repository-control-not-selectable',
  ),
  ReferenceFontSpecimenCandidate(
    id: 'control-current-roboto-variable-bold',
    family: 'Mt5RobotoVariable',
    weight: 700,
    faceSha256:
        'd7598e12c5dbef095ff8272cfc55da0250bd07fbdecbac8a530b9b277872a134',
    selectable: false,
    assetPath: 'assets/fonts/Roboto-Variable.ttf',
    provenance: 'current-repository-control-not-selectable',
  ),
  ReferenceFontSpecimenCandidate(
    id: 'reference-roboto-condensed-variable-regular',
    family: 'Mt5ReferenceRobotoCondensedVariable',
    weight: 400,
    faceSha256:
        'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0',
    selectable: true,
    assetPath: 'assets/fonts/RobotoCondensed-Variable.ttf',
    provenance: 'task2-locked-redistributable-variable',
    selectableRoleIds: <String>{
      'tradeMetricLabel',
      'historySummary',
      'historyOrderSummaryTotal',
    },
  ),
  ReferenceFontSpecimenCandidate(
    id: 'reference-roboto-condensed-variable-bold',
    family: 'Mt5ReferenceRobotoCondensedVariable',
    weight: 700,
    faceSha256:
        'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0',
    selectable: true,
    assetPath: 'assets/fonts/RobotoCondensed-Variable.ttf',
    provenance: 'task2-locked-redistributable-variable',
    selectableRoleIds: <String>{
      'tradeMetricValue',
      'tradeSection',
      'historySummaryValue',
    },
  ),
];
