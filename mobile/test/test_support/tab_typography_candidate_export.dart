import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_codec;
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/profile/presentation/screens/settings_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

import '../tab_typography_golden_test.dart' as canonical_fixture;
import 'reference_typography_role_manifest.dart';
import 'tab_reference_manifest.dart';

class TabTypographyCandidateExportRequest {
  const TabTypographyCandidateExportRequest._({
    required this.selection,
    required this.outputDirectory,
    required this.selectedCases,
  });

  final String selection;
  final Directory outputDirectory;
  final List<ReferenceTypographyCaptureCase> selectedCases;

  static TabTypographyCandidateExportRequest? fromDefineValues({
    required String selection,
    required String outputPath,
    required Directory workingDirectory,
  }) {
    final hasSelection = selection.isNotEmpty;
    final hasOutput = outputPath.isNotEmpty;
    if (!hasSelection && !hasOutput) return null;
    if (!hasSelection || !hasOutput) {
      throw ArgumentError(
        'TAB_REFERENCE_CASE and TAB_CANDIDATE_DIR must be supplied together',
      );
    }
    final resolved = outputPath.startsWith('/')
        ? Directory(outputPath).absolute
        : Directory.fromUri(workingDirectory.absolute.uri.resolve(outputPath));
    _validateCandidateOutputTarget(resolved);
    final selected = selectReferenceTypographyCaptureCases(selection);
    return TabTypographyCandidateExportRequest._(
      selection: selection,
      outputDirectory: resolved,
      selectedCases: selected,
    );
  }
}

class CandidateSourceFile {
  const CandidateSourceFile({
    required this.path,
    required this.sha256,
    required this.byteLength,
  });

  final String path;
  final String sha256;
  final int byteLength;

  Map<String, Object> toJson() => {
    'path': path,
    'sha256': sha256,
    'byteLength': byteLength,
  };
}

class CandidateCaptureEntry {
  const CandidateCaptureEntry({
    required this.id,
    required this.file,
    required this.sha256,
    required this.byteLength,
    required this.width,
    required this.height,
    required this.opaque,
    required this.rendererId,
    required this.fixture,
  });

  final String id;
  final String file;
  final String sha256;
  final int byteLength;
  final int width;
  final int height;
  final bool opaque;
  final String rendererId;
  final String fixture;

  Map<String, Object> toJson() => {
    'id': id,
    'file': file,
    'sha256': sha256,
    'byteLength': byteLength,
    'width': width,
    'height': height,
    'opaque': opaque,
    'rendererId': rendererId,
    'fixture': fixture,
  };
}

class TabTypographyCandidateManifest {
  const TabTypographyCandidateManifest({
    required this.sourceSnapshotSha256,
    required this.sourceFiles,
    required this.cases,
  });

  final String sourceSnapshotSha256;
  final List<CandidateSourceFile> sourceFiles;
  final List<CandidateCaptureEntry> cases;

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'rendererId': ReferenceRendererProfile.deterministicHost.id,
    'diagnosticOnly': true,
    'sourceSnapshotSha256': sourceSnapshotSha256,
    'sourceFiles': sourceFiles.map((item) => item.toJson()).toList(),
    'cases': cases.map((item) => item.toJson()).toList(),
  };
}

class TabTypographyCandidateExport {
  const TabTypographyCandidateExport._();

  static Future<TabTypographyCandidateManifest> capture({
    required WidgetTester tester,
    required String selection,
    required Directory outputDirectory,
    bool allowExistingEmptyOutput = false,
  }) async {
    final selectedCases = selectReferenceTypographyCaptureCases(selection);
    _validateCandidateOutputTarget(outputDirectory);
    if (outputDirectory.existsSync() &&
        (!allowExistingEmptyOutput ||
            outputDirectory.listSync(followLinks: false).isNotEmpty)) {
      throw StateError(
        'Candidate output already exists and is immutable: '
        '${outputDirectory.absolute.path}',
      );
    }
    final parent = outputDirectory.absolute.parent;
    parent.createSync(recursive: true);
    final leaf = outputDirectory.absolute.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    final staging = Directory(
      '${parent.path}/.$leaf.staging-$pid-'
      '${DateTime.now().microsecondsSinceEpoch}',
    );
    staging.createSync();

    try {
      final sourceFiles = _sourceSnapshotFiles();
      final sourceSnapshotSha256 = _sourceSnapshotSha256(sourceFiles);
      final entries = <CandidateCaptureEntry>[];
      for (final captureCase in selectedCases) {
        final captured = await _captureCase(tester, captureCase);
        try {
          final bytes = captured.pngBytes;
          final file = File('${staging.path}/${captureCase.candidateFileName}');
          file.writeAsBytesSync(bytes, flush: true);
          entries.add(
            CandidateCaptureEntry(
              id: captureCase.id,
              file: captureCase.candidateFileName,
              sha256: sha256.convert(bytes).toString(),
              byteLength: bytes.length,
              width: captured.image.width,
              height: captured.image.height,
              opaque: captured.opaque,
              rendererId: ReferenceRendererProfile.deterministicHost.id,
              fixture: captureCase.fixtureDescription,
            ),
          );
        } finally {
          captured.image.dispose();
        }
      }

      final manifest = TabTypographyCandidateManifest(
        sourceSnapshotSha256: sourceSnapshotSha256,
        sourceFiles: List<CandidateSourceFile>.unmodifiable(sourceFiles),
        cases: List<CandidateCaptureEntry>.unmodifiable(entries),
      );
      final manifestFile = File('${staging.path}/manifest.json');
      manifestFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n',
        flush: true,
      );
      _validateStagedExport(
        directory: staging,
        selectedCases: selectedCases,
        manifest: manifest,
      );
      Directory? emptyPlaceholder;
      if (outputDirectory.existsSync()) {
        if (!allowExistingEmptyOutput ||
            outputDirectory.listSync(followLinks: false).isNotEmpty) {
          throw StateError(
            'Candidate output appeared during capture: '
            '${outputDirectory.absolute.path}',
          );
        }
        emptyPlaceholder = Directory(
          '${parent.path}/.$leaf.empty-$pid-'
          '${DateTime.now().microsecondsSinceEpoch}',
        );
        outputDirectory.renameSync(emptyPlaceholder.path);
      }
      try {
        staging.renameSync(outputDirectory.absolute.path);
      } catch (_) {
        if (emptyPlaceholder != null &&
            emptyPlaceholder.existsSync() &&
            !outputDirectory.existsSync()) {
          emptyPlaceholder.renameSync(outputDirectory.absolute.path);
        }
        rethrow;
      }
      if (emptyPlaceholder != null && emptyPlaceholder.existsSync()) {
        emptyPlaceholder.deleteSync();
      }
      return manifest;
    } catch (_) {
      if (staging.existsSync()) staging.deleteSync(recursive: true);
      rethrow;
    }
  }
}

class _CapturedCandidate {
  const _CapturedCandidate({
    required this.image,
    required this.pngBytes,
    required this.opaque,
  });

  final ui.Image image;
  final Uint8List pngBytes;
  final bool opaque;
}

Future<_CapturedCandidate> _captureCase(
  WidgetTester tester,
  ReferenceTypographyCaptureCase captureCase,
) async {
  tester.view.devicePixelRatio = captureCase.devicePixelRatio;
  await tester.binding.setSurfaceSize(
    Size(captureCase.logicalSize.width, captureCase.logicalSize.height),
  );
  try {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpCaptureCase(tester, captureCase);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('tab-reference-root')),
    );
    final captured = await boundary.toImage(
      pixelRatio: captureCase.devicePixelRatio,
    );
    if (captured.width != captureCase.physicalWidth ||
        captured.height != captureCase.physicalHeight) {
      captured.dispose();
      throw StateError(
        '${captureCase.id} encoded ${captured.width}x${captured.height}; '
        'expected ${captureCase.physicalWidth}x${captureCase.physicalHeight}',
      );
    }
    final raw = await tester.runAsync(
      () => captured.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    if (raw == null) {
      captured.dispose();
      throw StateError('Unable to encode ${captureCase.id}');
    }
    var opaque = true;
    final rgba = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    for (var index = 3; index < rgba.length; index += 4) {
      if (rgba[index] != 255) {
        opaque = false;
        break;
      }
    }
    if (!opaque) {
      captured.dispose();
      throw StateError('${captureCase.id} contains non-opaque pixels');
    }
    final encodedImage = image_codec.Image.fromBytes(
      width: captured.width,
      height: captured.height,
      bytes: raw.buffer,
      bytesOffset: raw.offsetInBytes,
      numChannels: 4,
      order: image_codec.ChannelOrder.rgba,
    );
    final png = image_codec.encodePng(encodedImage);
    return _CapturedCandidate(image: captured, pngBytes: png, opaque: true);
  } finally {
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  }
}

Future<void> _pumpCaptureCase(
  WidgetTester tester,
  ReferenceTypographyCaptureCase captureCase,
) async {
  switch (captureCase.fixture) {
    case ReferenceTypographyCaptureFixture.canonicalTab:
      await canonical_fixture.pumpTabReference(
        tester,
        captureCase.tabCase!.state,
      );
    case ReferenceTypographyCaptureFixture.settingsPrimary ||
        ReferenceTypographyCaptureFixture.settingsSecondary:
      await _pumpSettings(tester, captureCase);
    case ReferenceTypographyCaptureFixture.darkTrade:
      await _pumpDarkTrade(tester, captureCase);
  }
}

const _settingsReferenceAccount = DemoAccountProfile(
  id: '111500232',
  name: 'HaiAa NamAa',
  company: 'MetaQuotes Ltd.',
  server: 'MetaQuotes-Demo',
  accessPoint: 'Access Point HK 1',
  balance: 0,
  brand: DemoBrokerBrand.metaquotes,
  historyDeposit: 0,
  historyWithdrawal: 0,
  historyProfit: 0,
  historySwap: 0,
  historyCommission: 0,
  historyBalance: 0,
  isDemo: true,
);

Future<void> _pumpSettings(
  WidgetTester tester,
  ReferenceTypographyCaptureCase captureCase,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        demoAccountCatalogProvider.overrideWithValue(const [
          _settingsReferenceAccount,
        ]),
        activeDemoAccountProvider.overrideWithValue(_settingsReferenceAccount),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: _captureScaffold(
          captureCase,
          const SettingsScreen(),
          selectedNavigationIndex: 4,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  if (captureCase.settingsScrollOffset > 0) {
    final listFinder = find.byKey(const Key('settings-scroll-view'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: listFinder, matching: find.byType(Scrollable)),
    );
    scrollable.position.jumpTo(captureCase.settingsScrollOffset);
    await tester.pump();
  }
}

const _darkTradePositions = <DemoPosition>[
  DemoPosition(
    id: 'dark-01',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4482.62,
    currentPrice: 4580.63,
    profit: 2450.25,
  ),
  DemoPosition(
    id: 'dark-02',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4482.62,
    currentPrice: 4580.63,
    profit: 2450.25,
  ),
  DemoPosition(
    id: 'dark-03',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4482.56,
    currentPrice: 4580.63,
    profit: 2451.62,
  ),
  DemoPosition(
    id: 'dark-04',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4482.56,
    currentPrice: 4580.63,
    profit: 2451.62,
  ),
  DemoPosition(
    id: 'dark-05',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4482.56,
    currentPrice: 4580.63,
    profit: 2451.62,
  ),
  DemoPosition(
    id: 'dark-06',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4482.56,
    currentPrice: 4580.63,
    profit: 2451.62,
  ),
  DemoPosition(
    id: 'dark-07',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4482.56,
    currentPrice: 4580.63,
    profit: 2451.62,
  ),
  DemoPosition(
    id: 'dark-08',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4482.57,
    currentPrice: 4580.63,
    profit: 2451.42,
  ),
  DemoPosition(
    id: 'dark-09',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4481.35,
    currentPrice: 4580.63,
    profit: 2482,
  ),
  DemoPosition(
    id: 'dark-10',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4481.35,
    currentPrice: 4580.63,
    profit: 2482,
  ),
  DemoPosition(
    id: 'dark-11',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4481.35,
    currentPrice: 4580.63,
    profit: 2482,
  ),
  DemoPosition(
    id: 'dark-12',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4481.35,
    currentPrice: 4580.63,
    profit: 2482,
  ),
  DemoPosition(
    id: 'dark-13',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4481.35,
    currentPrice: 4580.63,
    profit: 2482,
  ),
  DemoPosition(
    id: 'dark-14',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4481.35,
    currentPrice: 4580.63,
    profit: 2482,
  ),
  DemoPosition(
    id: 'dark-15',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: .25,
    openPrice: 4481.35,
    currentPrice: 4580.63,
    profit: 2482,
  ),
];

Future<void> _pumpDarkTrade(
  WidgetTester tester,
  ReferenceTypographyCaptureCase captureCase,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        demoPositionsProvider.overrideWithValue(_darkTradePositions),
        demoPendingOrdersProvider.overrideWithValue(const []),
        demoAccountProvider.overrideWithValue(
          const DemoAccountSnapshot(
            balance: 6083552.48,
            equity: 6120536.51,
            margin: 0,
            freeMargin: 6120536.51,
            marginLevel: 0,
            profit: 36984.02,
          ),
        ),
        demoQuotesProvider.overrideWithValue(const [
          DemoQuote(
            symbol: 'XAUUSD+',
            name: 'Gold US Dollar',
            bid: 4580.63,
            ask: 4580.65,
            changePercent: 0,
          ),
        ]),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: _captureScaffold(
          captureCase,
          const TradeScreen(),
          selectedNavigationIndex: 2,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Widget _captureScaffold(
  ReferenceTypographyCaptureCase captureCase,
  Widget screen, {
  required int selectedNavigationIndex,
}) => MediaQuery(
  data: MediaQueryData(
    size: Size(captureCase.logicalSize.width, captureCase.logicalSize.height),
    devicePixelRatio: captureCase.devicePixelRatio,
    textScaler: TextScaler.noScaling,
    padding: const EdgeInsets.only(top: 24),
    viewPadding: const EdgeInsets.only(top: 24),
  ),
  child: RepaintBoundary(
    key: const Key('tab-reference-root'),
    child: Scaffold(
      extendBody: true,
      body: MtTabTextScope(child: screen),
      bottomNavigationBar: MtBottomNavigationBar(
        selectedIndex: selectedNavigationIndex,
        onTap: (_) {},
      ),
    ),
  ),
);

List<CandidateSourceFile> _sourceSnapshotFiles() {
  final paths = <String>{'pubspec.yaml', 'pubspec.lock'};
  for (final directoryPath in <String>['assets', 'lib', 'test/test_support']) {
    final directory = Directory(directoryPath);
    for (final entity in directory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) paths.add(entity.path);
    }
  }
  paths.addAll(const [
    'test/tab_typography_golden_test.dart',
    'test/tab_typography_candidate_export_test.dart',
  ]);
  final sorted = paths.toList()..sort();
  return List<CandidateSourceFile>.unmodifiable([
    for (final path in sorted)
      CandidateSourceFile(
        path: path,
        sha256: sha256.convert(File(path).readAsBytesSync()).toString(),
        byteLength: File(path).lengthSync(),
      ),
  ]);
}

String _sourceSnapshotSha256(List<CandidateSourceFile> files) {
  final builder = BytesBuilder(copy: false);
  for (final file in files) {
    builder.add(utf8.encode(file.path));
    builder.addByte(0);
    builder.add(hexToBytes(file.sha256));
    builder.addByte(0);
  }
  return sha256.convert(builder.takeBytes()).toString();
}

List<int> hexToBytes(String value) => [
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
];

void _validateCandidateOutputTarget(Directory directory) {
  final absolute = directory.absolute;
  if (FileSystemEntity.typeSync(absolute.path, followLinks: false) ==
      FileSystemEntityType.link) {
    throw ArgumentError.value(
      directory.path,
      'outputDirectory',
      'Candidate output cannot itself be a symbolic link',
    );
  }
  final paths = <String>{
    absolute.path,
    _canonicalPathThroughExistingAncestor(absolute),
  };
  if (paths.any((path) => path == '/')) {
    throw ArgumentError.value(directory.path, 'outputDirectory', 'Unsafe root');
  }
  bool containsSequence(String path, List<String> sequence) {
    final segments = Directory(path).absolute.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    for (
      var index = 0;
      index <= segments.length - sequence.length;
      index += 1
    ) {
      if (List.generate(
        sequence.length,
        (offset) => segments[index + offset] == sequence[offset],
      ).every((matches) => matches)) {
        return true;
      }
    }
    return false;
  }

  if (paths.any(
    (path) =>
        containsSequence(path, const ['test', 'goldens']) ||
        containsSequence(path, const ['iconMau', 'anhmau']) ||
        containsSequence(path, const ['assets', 'fonts', 'mt5-reference']),
  )) {
    throw ArgumentError.value(
      directory.path,
      'outputDirectory',
      'Candidate output cannot be inside goldens or source-reference inputs',
    );
  }
}

String _canonicalPathThroughExistingAncestor(Directory directory) {
  var cursor = directory.absolute;
  final missingSegments = <String>[];
  while (FileSystemEntity.typeSync(cursor.path, followLinks: false) ==
      FileSystemEntityType.notFound) {
    missingSegments.add(
      cursor.uri.pathSegments.where((segment) => segment.isNotEmpty).last,
    );
    final parent = cursor.parent;
    if (parent.path == cursor.path) break;
    cursor = parent;
  }
  final type = FileSystemEntity.typeSync(cursor.path, followLinks: false);
  if (type != FileSystemEntityType.directory &&
      type != FileSystemEntityType.link) {
    throw ArgumentError.value(
      directory.path,
      'outputDirectory',
      'Existing output ancestor must be a directory',
    );
  }
  var resolved = Directory(cursor.resolveSymbolicLinksSync());
  for (final segment in missingSegments.reversed) {
    resolved = Directory.fromUri(resolved.uri.resolve('$segment/'));
  }
  return resolved.absolute.path;
}

void _validateStagedExport({
  required Directory directory,
  required List<ReferenceTypographyCaptureCase> selectedCases,
  required TabTypographyCandidateManifest manifest,
}) {
  final expectedNames = <String>{
    'manifest.json',
    for (final captureCase in selectedCases) captureCase.candidateFileName,
  };
  final actualNames = {
    for (final entity in directory.listSync(followLinks: false))
      entity.uri.pathSegments.where((segment) => segment.isNotEmpty).last,
  };
  if (actualNames.length != expectedNames.length ||
      !actualNames.containsAll(expectedNames)) {
    throw StateError(
      'Staged export inventory differs: expected=$expectedNames '
      'actual=$actualNames',
    );
  }
  if (manifest.cases.length != selectedCases.length ||
      !manifest.cases
          .map((entry) => entry.id)
          .toSet()
          .containsAll(selectedCases.map((captureCase) => captureCase.id))) {
    throw StateError('Staged manifest case set is incomplete');
  }
  for (final entry in manifest.cases) {
    final bytes = File('${directory.path}/${entry.file}').readAsBytesSync();
    if (bytes.length != entry.byteLength ||
        sha256.convert(bytes).toString() != entry.sha256) {
      throw StateError('${entry.id} staged PNG hash/length mismatch');
    }
    final decoded = image_codec.decodePng(bytes);
    if (decoded == null ||
        decoded.width != entry.width ||
        decoded.height != entry.height ||
        !decoded.every((pixel) => pixel.a.toInt() == 255)) {
      throw StateError('${entry.id} staged PNG raster contract mismatch');
    }
  }
  final decodedManifest =
      jsonDecode(File('${directory.path}/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  if (decodedManifest['sourceSnapshotSha256'] !=
      manifest.sourceSnapshotSha256) {
    throw StateError('Staged manifest source snapshot mismatch');
  }
  for (final source in manifest.sourceFiles) {
    final file = File(source.path);
    if (!file.existsSync() ||
        file.lengthSync() != source.byteLength ||
        sha256.convert(file.readAsBytesSync()).toString() != source.sha256) {
      throw StateError('Source changed during export: ${source.path}');
    }
    if (source.path.contains('goldens/')) {
      throw StateError('Golden path entered candidate source snapshot');
    }
  }
  if (_sourceSnapshotSha256(manifest.sourceFiles) !=
      manifest.sourceSnapshotSha256) {
    throw StateError('Staged source snapshot digest mismatch');
  }
}
