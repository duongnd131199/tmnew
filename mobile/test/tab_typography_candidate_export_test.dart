import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:trading_mobile/core/theme/app_typography.dart';

import 'test_support/reference_font_loader.dart';
import 'test_support/tab_reference_manifest.dart';
import 'test_support/tab_typography_candidate_export.dart';

const _definedSelection = String.fromEnvironment('TAB_REFERENCE_CASE');
const _definedOutputPath = String.fromEnvironment('TAB_CANDIDATE_DIR');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReferenceFonts);

  if (_definedSelection.isNotEmpty || _definedOutputPath.isNotEmpty) {
    testWidgets('dart defines export the requested persistent candidate set', (
      tester,
    ) async {
      final request = TabTypographyCandidateExportRequest.fromDefineValues(
        selection: _definedSelection,
        outputPath: _definedOutputPath,
        workingDirectory: Directory.current,
      )!;
      final manifest = await TabTypographyCandidateExport.capture(
        tester: tester,
        selection: request.selection,
        outputDirectory: request.outputDirectory,
        allowExistingEmptyOutput: true,
      );
      expect(
        manifest.cases.map((candidate) => candidate.id),
        request.selectedCases.map((captureCase) => captureCase.id),
      );
      expect(
        File('${request.outputDirectory.path}/manifest.json').existsSync(),
        isTrue,
      );
    });
    return;
  }

  test('define route validates pairing, paths, and exact selection', () {
    expect(
      TabTypographyCandidateExportRequest.fromDefineValues(
        selection: '',
        outputPath: '',
        workingDirectory: Directory.current,
      ),
      isNull,
    );
    for (final values in const [
      ('prices', ''),
      ('', '../artifacts/candidates'),
    ]) {
      expect(
        () => TabTypographyCandidateExportRequest.fromDefineValues(
          selection: values.$1,
          outputPath: values.$2,
          workingDirectory: Directory.current,
        ),
        throwsArgumentError,
      );
    }
    for (final forbidden in const [
      'test/goldens/task-2-candidates',
      '../iconMau/anhmau/task-2-candidates',
    ]) {
      expect(
        () => TabTypographyCandidateExportRequest.fromDefineValues(
          selection: 'prices',
          outputPath: forbidden,
          workingDirectory: Directory.current,
        ),
        throwsArgumentError,
      );
    }
    final exact = TabTypographyCandidateExportRequest.fromDefineValues(
      selection: 'dark-trade',
      outputPath: '../artifacts/dark-smoke',
      workingDirectory: Directory.current,
    )!;
    expect(exact.outputDirectory.isAbsolute, isTrue);
    expect(exact.selectedCases.map((item) => item.id), ['dark-trade']);
    final history = TabTypographyCandidateExportRequest.fromDefineValues(
      selection: 'history',
      outputPath: '../artifacts/history-smoke',
      workingDirectory: Directory.current,
    )!;
    expect(history.selectedCases, hasLength(4));
    final all = TabTypographyCandidateExportRequest.fromDefineValues(
      selection: 'all',
      outputPath: '../artifacts/all-smoke',
      workingDirectory: Directory.current,
    )!;
    expect(all.selectedCases, hasLength(10));
    expect(
      all.selectedCases.map((item) => item.id),
      containsAll(['settings-primary', 'settings-secondary', 'dark-trade']),
    );
    expect(
      () => TabTypographyCandidateExportRequest.fromDefineValues(
        selection: 'unknown',
        outputPath: '../artifacts/unknown-smoke',
        workingDirectory: Directory.current,
      ),
      throwsArgumentError,
    );
  });

  test('define route resolves symlinks before protected-path validation', () {
    final parent = Directory.systemTemp.createTempSync('candidate-symlink-');
    addTearDown(() => parent.deleteSync(recursive: true));
    final protected = Directory('${parent.path}/test/goldens')
      ..createSync(recursive: true);
    final ancestorLink = Link('${parent.path}/allowed-looking')
      ..createSync(protected.path);
    expect(
      () => TabTypographyCandidateExportRequest.fromDefineValues(
        selection: 'prices',
        outputPath: '${ancestorLink.path}/candidate',
        workingDirectory: Directory.current,
      ),
      throwsArgumentError,
    );
    final empty = Directory('${parent.path}/empty')..createSync();
    final leafLink = Link('${parent.path}/candidate-link')
      ..createSync(empty.path);
    expect(
      () => TabTypographyCandidateExportRequest.fromDefineValues(
        selection: 'prices',
        outputPath: leafLink.path,
        workingDirectory: Directory.current,
      ),
      throwsArgumentError,
    );
  });

  test('the current-source family raster is not the test Ahem fallback', () {
    final current = TextPainter(
      text: TextSpan(text: 'XAUUSD', style: AppTypography.quoteSymbol),
      textDirection: TextDirection.ltr,
    )..layout();
    final ahem = TextPainter(
      text: TextSpan(
        text: 'XAUUSD',
        style: AppTypography.quoteSymbol.copyWith(fontFamily: 'Ahem'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(current.width, isNot(closeTo(ahem.width, .01)));
  });

  test(
    'the capture inventory adds three cases without changing the canonical seven',
    () {
      expect(tabReferenceCases, hasLength(7));
      expect(referenceTypographyCaptureCases, hasLength(10));
      expect(
        referenceTypographyCaptureCases.map((item) => item.candidateFileName),
        const <String>[
          'prices-590x1280.png',
          'chart-590x1280.png',
          'trade-590x1280.png',
          'history-positions-590x1280.png',
          'history-orders-590x1280.png',
          'history-orders-summary-590x1280.png',
          'history-deals-590x1280.png',
          'settings-primary-590x1280.png',
          'settings-secondary-590x1280.png',
          'dark-trade-413x881.png',
        ],
      );
      expect(
        selectReferenceTypographyCaptureCases('history').map((item) => item.id),
        const <String>[
          'history-positions',
          'history-orders',
          'history-orders-summary',
          'history-deals',
        ],
      );
      expect(selectReferenceTypographyCaptureCases('all'), hasLength(10));
      final settingsPrimary = selectReferenceTypographyCaptureCases(
        'settings-primary',
      ).single;
      expect(settingsPrimary.settingsScrollOffset, 40);
      expect(settingsPrimary.fixtureValues, const <String, String>{
        'accountId': '111500232',
        'accountName': 'HaiAa NamAa',
        'company': 'MetaQuotes Ltd.',
        'server': 'MetaQuotes-Demo',
        'accessPoint': 'Access Point HK 1',
        'scrollOffsetLogical': '40',
      });
      final darkTrade = selectReferenceTypographyCaptureCases(
        'dark-trade',
      ).single;
      expect(darkTrade.logicalSize.width, 413);
      expect(darkTrade.logicalSize.height, 881);
      expect(darkTrade.devicePixelRatio, 1);
      expect((darkTrade.physicalWidth, darkTrade.physicalHeight), (413, 881));
      expect(darkTrade.fixtureValues, containsPair('profit', '36 984.02 USD'));
      expect(
        darkTrade.fixtureValues,
        containsPair('firstOpenPrices', '4482.62,4482.56,4482.57'),
      );
      expect(
        darkTrade.fixtureValues,
        containsPair('firstProfits', '2450.25,2451.62,2451.42'),
      );
      expect(
        () => selectReferenceTypographyCaptureCases('unknown'),
        throwsArgumentError,
      );
    },
  );

  testWidgets(
    'dark Trade capture uses the measured dark text and row surface colors',
    (tester) async {
      final parent = Directory.systemTemp.createTempSync(
        'dark-trade-candidate-',
      );
      addTearDown(() => parent.deleteSync(recursive: true));
      final output = Directory('${parent.path}/immutable-run');

      await TabTypographyCandidateExport.capture(
        tester: tester,
        selection: 'dark-trade',
        outputDirectory: output,
      );

      final metricLabel = tester.widget<Text>(
        find.byKey(const ValueKey('trade-metric-label-Số dư:')),
      );
      final sectionLabel = tester.widget<Text>(
        find.byKey(const Key('trade-section-label')),
      );
      final secondary = tester.widget<Text>(
        find.byKey(const ValueKey('trade-position-secondary-dark-01')),
      );
      final primary = tester.widget<Text>(
        find.byKey(const ValueKey('trade-position-primary-dark-01')),
      );
      final primarySpans = (primary.textSpan! as TextSpan).children!
          .cast<TextSpan>();

      expect(metricLabel.style?.color, const Color(0xFFEEEEEE));
      expect(sectionLabel.style?.color, const Color(0xFFEEEEEE));
      expect(secondary.style?.color, const Color(0xFF969696));
      expect(primarySpans.first.style?.color, const Color(0xFFEEEEEE));

      final png = image.decodePng(
        File('${output.path}/dark-trade-413x881.png').readAsBytesSync(),
      )!;
      final headerSurface = png.getPixel(100, 80);
      expect(
        (
          headerSurface.r.toInt(),
          headerSurface.g.toInt(),
          headerSurface.b.toInt(),
        ),
        (0, 0, 0),
      );
      final rowSurface = png.getPixel(200, 400);
      expect(
        (rowSurface.r.toInt(), rowSurface.g.toInt(), rowSurface.b.toInt()),
        (0, 0, 0),
      );
    },
  );

  testWidgets(
    'one selected case exports current pixels and a matching manifest',
    (tester) async {
      final parent = Directory.systemTemp.createTempSync('candidate-export-');
      addTearDown(() => parent.deleteSync(recursive: true));
      final output = Directory('${parent.path}/immutable-run');
      output.createSync();

      final manifest = await TabTypographyCandidateExport.capture(
        tester: tester,
        selection: 'prices',
        outputDirectory: output,
        allowExistingEmptyOutput: true,
      );

      expect(manifest.cases, hasLength(1));
      final entry = manifest.cases.single;
      expect(entry.id, 'prices');
      final pngFile = File('${output.path}/prices-590x1280.png');
      expect(pngFile.existsSync(), isTrue);
      final pngBytes = pngFile.readAsBytesSync();
      expect(sha256.convert(pngBytes).toString(), entry.sha256);
      final decoded = image.decodePng(pngBytes)!;
      expect((decoded.width, decoded.height), (590, 1280));
      expect(decoded.numChannels, 4);
      expect(decoded.every((pixel) => pixel.a.toInt() == 255), isTrue);

      final manifestJson =
          jsonDecode(File('${output.path}/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(
        manifestJson['sourceSnapshotSha256'],
        manifest.sourceSnapshotSha256,
      );
      expect(manifest.sourceFiles, isNotEmpty);
      expect(
        manifest.sourceFiles.map((item) => item.path).toList(),
        orderedEquals(
          [...manifest.sourceFiles.map((item) => item.path)]..sort(),
        ),
      );
      expect(
        manifest.sourceFiles.any((item) => item.path.contains('goldens/')),
        isFalse,
      );
      final sourcePaths = manifest.sourceFiles.map((item) => item.path).toSet();
      expect(
        sourcePaths,
        containsAll(const [
          'assets/fonts/mt5-reference/Roboto-Regular.ttf',
          'assets/fonts/mt5-reference/Roboto-Bold.ttf',
          'assets/fonts/mt5-reference/RobotoCondensed-Regular.ttf',
          'assets/fonts/mt5-reference/RobotoCondensed-Bold.ttf',
          'assets/fonts/mt5-reference/font-lock.json',
          'assets/fonts/mt5-reference/LICENSE-Apache-2.0.txt',
        ]),
      );
      expect(
        sourcePaths.any((path) => path.toLowerCase().contains('avenir')),
        isFalse,
      );
    },
  );

  testWidgets('all ten cases replace ProviderScope roots between fixtures', (
    tester,
  ) async {
    final parent = Directory.systemTemp.createTempSync('candidate-export-all-');
    addTearDown(() => parent.deleteSync(recursive: true));
    final output = Directory('${parent.path}/immutable-run');

    final manifest = await TabTypographyCandidateExport.capture(
      tester: tester,
      selection: 'all',
      outputDirectory: output,
    );

    expect(
      manifest.cases.map((item) => item.id),
      referenceTypographyCaptureCases.map((item) => item.id),
    );
    expect(
      manifest.cases.every(
        (item) => File('${output.path}/${item.file}').existsSync(),
      ),
      isTrue,
    );
  });

  testWidgets(
    'scrolled History candidates preserve the complete bottom navigation',
    (tester) async {
      final parent = Directory.systemTemp.createTempSync(
        'candidate-history-navigation-',
      );
      addTearDown(() => parent.deleteSync(recursive: true));
      final output = Directory('${parent.path}/immutable-run');

      await TabTypographyCandidateExport.capture(
        tester: tester,
        selection: 'history',
        outputDirectory: output,
      );

      final navigationHashes = <String, String>{};
      for (final fileName in const [
        'history-positions-590x1280.png',
        'history-orders-590x1280.png',
        'history-orders-summary-590x1280.png',
        'history-deals-590x1280.png',
      ]) {
        final raster = image.decodePng(
          File('${output.path}/$fileName').readAsBytesSync(),
        )!;
        navigationHashes[fileName] = _regionSha256(
          raster,
          const Rect.fromLTWH(60, 1175, 470, 65),
        );
      }
      expect(
        navigationHashes.values.toSet(),
        hasLength(1),
        reason:
            'The opaque center of the shared History navigation capsule '
            'must not be clipped or replaced by a scrolled History body: '
            '$navigationHashes',
      );
    },
  );

  testWidgets('candidate output is immutable', (tester) async {
    final parent = Directory.systemTemp.createTempSync('candidate-no-write-');
    addTearDown(() => parent.deleteSync(recursive: true));
    final output = Directory('${parent.path}/immutable-run');
    await TabTypographyCandidateExport.capture(
      tester: tester,
      selection: 'prices',
      outputDirectory: output,
    );
    await expectLater(
      TabTypographyCandidateExport.capture(
        tester: tester,
        selection: 'prices',
        outputDirectory: output,
      ),
      throwsStateError,
    );
  });

  testWidgets('define-style output rejects a nonempty existing directory', (
    tester,
  ) async {
    final parent = Directory.systemTemp.createTempSync('candidate-nonempty-');
    addTearDown(() => parent.deleteSync(recursive: true));
    final output = Directory('${parent.path}/immutable-run')..createSync();
    final marker = File('${output.path}/owned.txt')..writeAsStringSync('owned');
    await expectLater(
      TabTypographyCandidateExport.capture(
        tester: tester,
        selection: 'prices',
        outputDirectory: output,
        allowExistingEmptyOutput: true,
      ),
      throwsStateError,
    );
    expect(marker.readAsStringSync(), 'owned');
  });
}

String _regionSha256(image.Image raster, Rect bounds) {
  final rgba = <int>[];
  for (var y = bounds.top.toInt(); y < bounds.bottom.toInt(); y++) {
    for (var x = bounds.left.toInt(); x < bounds.right.toInt(); x++) {
      final pixel = raster.getPixel(x, y);
      rgba.addAll([
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        pixel.a.toInt(),
      ]);
    }
  }
  return sha256.convert(rgba).toString();
}
