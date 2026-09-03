import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../test_driver/reference_font_specimen_device_test.dart'
    as reference_device_driver;
import 'test_support/reference_font_loader.dart';
import 'test_support/reference_typography_role_manifest.dart';
import 'test_support/reference_typography_specimen_widgets.dart';
import 'test_support/reference_typography_sources.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReferenceFonts);

  test('the primary renderer is frozen to Flutter iOS', () {
    expect(ReferenceRendererProfile.primary, ReferenceRendererProfile.ios);
    expect(ReferenceRendererProfile.primary.isPrimary, isTrue);
    expect(ReferenceRendererProfile.android.isPrimary, isFalse);
    expect(ReferenceRendererProfile.deterministicHost.isPrimary, isFalse);
  });

  test('the host driver compiles as a pure Dart kernel', () {
    final temporary = Directory.systemTemp.createTempSync(
      'reference-driver-kernel-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final result = Process.runSync('dart', [
      'compile',
      'kernel',
      'test_driver/reference_font_specimen_device_test.dart',
      '-o',
      '${temporary.path}/reference_font_specimen_device_test.dill',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('the host manifest pins and validates the pure role manifest bytes', () {
    const expectedSha =
        '6eafbb63c29a8313df4ec9ffa6f0a2afa455b0e5c7fffd4d2d3ef85183c9f2d0';
    final provenance = reference_device_driver
        .referenceRoleManifestProvenance();

    expect(provenance, const <String, Object>{
      'referenceRoleManifestSha256': expectedSha,
    });
    expect(
      () => reference_device_driver.validateReferenceRoleManifestProvenance(
        provenance,
      ),
      returnsNormally,
    );
    expect(
      () => reference_device_driver.validateReferenceRoleManifestProvenance(
        const <String, Object>{
          'referenceRoleManifestSha256':
              '0000000000000000000000000000000000000000000000000000000000000000',
        },
      ),
      throwsStateError,
    );
  });

  test('the controlled specimen matrix uses all locked lawful faces', () {
    expect(referenceFontSpecimenStrings, const <String>[
      'Giá  Biểu đồ  Giao dịch  Lịch sử  Cài đặt',
      'Số dư:  Vốn:  Tiền ký quỹ:  Mức ký quỹ (%):',
      'XAUUSD buy 1',
      '4637.05 → 4640.81',
      '376.00  -341.00  103 310.00  203.24',
      'L:  H:  M1  Orders  Deals',
    ]);
    expect(referenceFontSpecimenCandidates, hasLength(8));
    expect(
      referenceFontSpecimenCandidates
          .where((candidate) => candidate.selectable)
          .map((candidate) => (candidate.faceSha256, candidate.weight))
          .toSet(),
      const <(String, int)>{
        (
          'f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27',
          400,
        ),
        (
          '9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70',
          700,
        ),
        (
          'f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8',
          400,
        ),
        (
          'ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a',
          700,
        ),
        (
          'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0',
          400,
        ),
        (
          'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0',
          700,
        ),
      },
    );
    expect(
      referenceFontSpecimenCandidates.where(
        (candidate) => !candidate.selectable,
      ),
      hasLength(2),
    );
    for (final candidate in referenceFontSpecimenCandidates) {
      expect(candidate.faceSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(File(candidate.assetPath).existsSync(), isTrue);
      expect(
        sha256.convert(File(candidate.assetPath).readAsBytesSync()).toString(),
        candidate.faceSha256,
        reason: candidate.id,
      );
      if (candidate.selectable) {
        expect(
          candidate.provenance,
          anyOf(
            'task1-locked-redistributable',
            'task2-locked-redistributable-variable',
          ),
        );
        expect(candidate.family, isNot(contains('Mt5RobotoVariable')));
        expect(candidate.family, isNot(contains('Mt5RobotoCondensedVariable')));
      } else {
        expect(
          candidate.faceSha256,
          const <String>{
            'd7598e12c5dbef095ff8272cfc55da0250bd07fbdecbac8a530b9b277872a134',
          }.single,
        );
        expect(
          candidate.provenance,
          'current-repository-control-not-selectable',
        );
      }
    }
  });

  test('the reviewed variable face is selectable only for winning roles', () {
    final regular = referenceFontSpecimenCandidates.singleWhere(
      (candidate) =>
          candidate.id == 'reference-roboto-condensed-variable-regular',
    );
    final bold = referenceFontSpecimenCandidates.singleWhere(
      (candidate) => candidate.id == 'reference-roboto-condensed-variable-bold',
    );

    expect(regular.selectableRoleIds, const <String>{
      'tradeMetricLabel',
      'historySummary',
      'historyOrderSummaryTotal',
    });
    expect(bold.selectableRoleIds, const <String>{
      'tradeMetricValue',
      'tradeSection',
      'historySummaryValue',
    });
    const regularWinners = <String>{
      'tradeMetricLabel',
      'historySummary',
      'historyOrderSummaryTotal',
    };
    const boldWinners = <String>{
      'tradeMetricValue',
      'tradeSection',
      'historySummaryValue',
    };
    for (final run in referenceFontSpecimenOutputRuns) {
      if (run.supports(regular)) {
        expect(
          regular.isSelectableForRole(run.roleId),
          regularWinners.contains(run.roleId),
          reason: '${regular.id}:${run.comparisonId}',
        );
      }
      if (run.supports(bold)) {
        expect(
          bold.isSelectableForRole(run.roleId),
          boldWinners.contains(run.roleId),
          reason: '${bold.id}:${run.comparisonId}',
        );
      }
    }
  });

  test('U+2192 is a keyed vector run with no font fallback', () {
    final arrow = referenceFontSpecimenRuns.singleWhere(
      (run) => run.key == 'numeric-price-arrow',
    );
    final taskOnePolicy = referenceTypographyStructuralDelimiterPolicies.single;
    expect(arrow.text, '→');
    expect(arrow.codePoints, const <int>{0x2192});
    expect(arrow.usesCandidateFont, isFalse);
    expect(arrow.renderingContract, taskOnePolicy.renderingContract);
    expect(arrow.renderingContract, contains('no-font-fallback'));
  });

  test('scored runs have joinable exact source annotations', () {
    final runs = {
      for (final run in referenceFontSpecimenOutputRuns) run.comparisonId: run,
    };
    expect(runs, hasLength(referenceFontSpecimenOutputRuns.length));
    final edgeFailures = <String>[];
    for (final annotation in referenceFontSpecimenSourceAnnotations) {
      final run = runs[annotation.candidateRunId];
      expect(run, isNotNull, reason: annotation.candidateRunId);
      expect(annotation.comparisonId, annotation.candidateRunId);
      expect(annotation.roleId, run!.roleId);
      expect(
        run.text.substring(
          annotation.candidateTextStart,
          annotation.candidateTextEnd,
        ),
        annotation.text,
      );
      expect(annotation.outputWidth, run.physicalRect.width);
      expect(annotation.outputHeight, run.physicalRect.height);
      expect(
        annotation.outputBaseline,
        run.physicalBaseline - run.physicalRect.top,
      );
      expect(annotation.outputHorizontalAnchor, run.horizontalAnchor);
      final source = File(annotation.sourcePath);
      expect(source.existsSync(), isTrue, reason: annotation.sourceId);
      expect(
        sha256.convert(source.readAsBytesSync()).toString(),
        annotation.sourceSha256,
      );
      final decoded = image.decodeImage(source.readAsBytesSync())!;
      expect(annotation.physicalRect.left, greaterThanOrEqualTo(0));
      expect(annotation.physicalRect.top, greaterThanOrEqualTo(0));
      expect(
        annotation.physicalRect.left + annotation.physicalRect.width,
        lessThanOrEqualTo(decoded.width),
      );
      expect(
        annotation.physicalRect.top + annotation.physicalRect.height,
        lessThanOrEqualTo(decoded.height),
      );
      final rawCrop = image.copyCrop(
        decoded,
        x: annotation.physicalRect.left.toInt(),
        y: annotation.physicalRect.top.toInt(),
        width: annotation.physicalRect.width.toInt(),
        height: annotation.physicalRect.height.toInt(),
      );
      final rawEdges = _inkOnEdge(rawCrop);
      if (annotation.boundaryPolicy ==
          ReferenceSourceBoundaryPolicy.trailingBeforeScrollbar) {
        expect(run.horizontalLayout, ReferenceRunHorizontalLayout.trailing);
        expect(
          annotation.physicalRect.left + annotation.physicalRect.width,
          582,
        );
        expect(annotation.physicalRect.left + annotation.horizontalAnchor, 582);
        rawEdges.removeWhere((edge) => edge == 'right');
        final lastSourceX =
            annotation.physicalRect.left.toInt() +
            annotation.physicalRect.width.toInt() -
            1;
        final top = annotation.physicalRect.top.toInt();
        final bottom = top + annotation.physicalRect.height.toInt();
        expect(
          [
            for (var y = top; y < bottom; y += 1)
              _isStrongReferenceInk(decoded.getPixel(lastSourceX, y)),
          ],
          everyElement(isFalse),
          reason: '${annotation.candidateRunId} requires blank source x=581',
        );
        expect(
          [
            for (var y = top; y < bottom; y += 1)
              _isReferenceInk(decoded.getPixel(582, y)),
          ],
          contains(isTrue),
          reason: '${annotation.candidateRunId} must exclude scrollbar x=582',
        );
      } else if (annotation.boundaryPolicy ==
          ReferenceSourceBoundaryPolicy
              .trailingBeforeAdjacentColoredTextJpegNoise) {
        expect(annotation.candidateRunId, 'trade-position-symbol');
        expect(run.horizontalLayout, ReferenceRunHorizontalLayout.leading);
        expect(
          annotation.physicalRect.left + annotation.physicalRect.width,
          annotation.sourceRightExclusiveBoundaryX,
        );
        expect(
          annotation.sourceRightExclusiveBoundaryX,
          annotation.excludedNeighborStartX,
        );
        rawEdges.removeWhere((edge) => edge == 'right');
      }
      final touching = <String>{
        ...rawEdges,
        ..._inkOnEdge(_paddedReferenceCrop(decoded, annotation)),
      }.toList();
      if (touching.isNotEmpty) {
        edgeFailures.add('${annotation.candidateRunId}:$touching');
      }
    }
    expect(edgeFailures, isEmpty);
  });

  test('numeric open isolates JPEG noise before the vector arrow', () {
    final annotation = referenceFontSpecimenSourceAnnotations.singleWhere(
      (value) => value.candidateRunId == 'numeric-price-open',
    );
    final source = image.decodeImage(
      File(annotation.sourcePath).readAsBytesSync(),
    )!;
    final rect = annotation.physicalRect;
    final crop = image.copyCrop(
      source,
      x: rect.left.toInt(),
      y: rect.top.toInt(),
      width: rect.width.toInt(),
      height: rect.height.toInt(),
    );
    expect(_jpegScorerSupportOnEdge(crop, 'right'), isTrue);
    expect(
      annotation.boundaryPolicy,
      ReferenceSourceBoundaryPolicy.leadingBeforeArrowJpegNoise,
    );
    expect(rect.left + rect.width, 100);
    expect(annotation.sourceRightExclusiveBoundaryX, 100);
    expect(annotation.lastStrongInkX, 90);
    expect(annotation.blankGuardStartX, 91);
    expect(annotation.blankGuardWidth, 9);
    expect(annotation.excludedNeighborStartX, 100);
    expect(annotation.excludedNeighborKind, 'vectorArrow');
    final top = rect.top.toInt();
    final bottom = top + rect.height.toInt();
    bool columnHasStrongInk(int x) => [
      for (var y = top; y < bottom; y += 1)
        _isReferenceInk(source.getPixel(x, y)),
    ].contains(true);
    expect(columnHasStrongInk(90), isTrue);
    for (var x = 91; x <= 99; x += 1) {
      expect(columnHasStrongInk(x), isFalse, reason: 'blank source x=$x');
    }
    expect(columnHasStrongInk(100), isTrue, reason: 'vector arrow boundary');
  });

  test('reviewed row and position crops preserve exact output geometry', () {
    ReferenceFontSpecimenSourceAnnotation annotation(String id) =>
        referenceFontSpecimenSourceAnnotations.singleWhere(
          (value) => value.candidateRunId == id,
        );
    ReferenceFontSpecimenOutputRun run(String id) =>
        referenceFontSpecimenOutputRuns.singleWhere(
          (value) => value.comparisonId == id,
        );

    final settings = annotation('settings-row-title');
    expect(
      (
        settings.physicalRect.left,
        settings.physicalRect.top,
        settings.physicalRect.width,
        settings.physicalRect.height,
      ),
      (112, 232, 160, 35),
    );
    expect((settings.paddingRight, settings.paddingBottom), (0, 0));
    expect((settings.baseline, settings.outputBaseline), (256, 24));
    expect(
      (
        settings.outputWidth,
        settings.outputHeight,
        settings.outputHorizontalAnchor,
      ),
      (160, 35, 3),
    );

    final side = annotation('trade-position-side-volume');
    expect(
      (
        side.physicalRect.left,
        side.physicalRect.top,
        side.physicalRect.width,
        side.physicalRect.height,
      ),
      (82, 369, 75, 35),
    );
    expect((side.paddingRight, side.paddingBottom), (0, 4));
    expect((side.baseline, side.outputBaseline), (398, 29));
    expect(
      (side.outputWidth, side.outputHeight, side.outputHorizontalAnchor),
      (75, 39, 4),
    );

    final symbol = annotation('trade-position-symbol');
    expect(
      (
        symbol.physicalRect.left,
        symbol.physicalRect.top,
        symbol.physicalRect.width,
        symbol.physicalRect.height,
      ),
      (3, 369, 79, 35),
    );
    expect((symbol.paddingRight, symbol.paddingBottom), (14, 4));
    expect((symbol.baseline, symbol.outputBaseline), (398, 29));
    expect(
      (symbol.outputWidth, symbol.outputHeight, symbol.outputHorizontalAnchor),
      (93, 39, 4),
    );

    expect(
      (
        run('settings-row-title').physicalRect.width,
        run('settings-row-title').physicalRect.height,
        run('settings-row-title').physicalBaseline -
            run('settings-row-title').physicalRect.top,
        run('settings-row-title').horizontalAnchor,
      ),
      (160, 35, 24, 3),
    );
    expect(
      (
        run('trade-position-symbol').physicalRect.width,
        run('trade-position-symbol').physicalRect.height,
        run('trade-position-symbol').physicalBaseline -
            run('trade-position-symbol').physicalRect.top,
        run('trade-position-symbol').horizontalAnchor,
      ),
      (93, 39, 29, 4),
    );
    expect(
      (
        run('trade-position-side-volume').physicalRect.width,
        run('trade-position-side-volume').physicalRect.height,
        run('trade-position-side-volume').physicalBaseline -
            run('trade-position-side-volume').physicalRect.top,
        run('trade-position-side-volume').horizontalAnchor,
      ),
      (75, 39, 29, 4),
    );

    final settingsSource = image.decodePng(
      File(settings.sourcePath).readAsBytesSync(),
    )!;
    for (var y = 264; y <= 266; y += 1) {
      expect(
        [
          for (var x = 112; x < 272; x += 1)
            _isExactWhite(settingsSource.getPixel(x, y)),
        ],
        everyElement(isTrue),
        reason: 'settings real blank row y=$y',
      );
    }
    final tradeSource = image.decodeImage(
      File(side.sourcePath).readAsBytesSync(),
    )!;
    for (var x = 144; x <= 156; x += 1) {
      expect(
        [
          for (var y = 369; y < 404; y += 1)
            _isExactWhite(tradeSource.getPixel(x, y)),
        ],
        everyElement(isTrue),
        reason: 'side/volume retained source whitespace x=$x',
      );
    }
  });

  test('symbol isolates JPEG halo before adjacent colored side text', () {
    final annotation = referenceFontSpecimenSourceAnnotations.singleWhere(
      (value) => value.candidateRunId == 'trade-position-symbol',
    );
    expect(
      annotation.boundaryPolicy.name,
      'trailingBeforeAdjacentColoredTextJpegNoise',
    );
    expect(annotation.sourceRightExclusiveBoundaryX, 82);
    expect(annotation.lastStrongInkX, 80);
    expect(annotation.blankGuardStartX, 81);
    expect(annotation.blankGuardWidth, 1);
    expect(annotation.excludedNeighborStartX, 82);
    expect(annotation.excludedNeighborKind, 'tradePositionSideVolume');

    final source = image.decodeImage(
      File(annotation.sourcePath).readAsBytesSync(),
    )!;
    expect(_columnHasStrongInk(source, 80, 369, 35), isTrue);
    expect(_columnHasStrongInk(source, 81, 369, 35), isFalse);
    expect(_columnHasNonWhiteSupport(source, 81, 369, 35), isTrue);
    expect(_columnHasNonWhiteSupport(source, 82, 369, 35), isTrue);
    expect(_columnHasBlueInk(source, 87, 369, 35), isTrue);
  });

  test('host rejects mutations of the reviewed symbol boundary evidence', () {
    final source = image.decodeImage(
      File('../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg').readAsBytesSync(),
    )!;
    const crop = <String, Object>{
      'left': 3,
      'top': 369,
      'width': 79,
      'height': 35,
    };
    const padding = <String, Object>{
      'left': 0,
      'top': 0,
      'right': 14,
      'bottom': 4,
    };
    const valid = <String, Object>{
      'boundaryPolicy': 'trailingBeforeAdjacentColoredTextJpegNoise',
      'sourceRightExclusiveBoundaryX': 82,
      'lastStrongInkX': 80,
      'blankGuardStartX': 81,
      'blankGuardWidth': 1,
      'excludedNeighborStartX': 82,
      'excludedNeighborKind': 'tradePositionSideVolume',
    };

    void validate(Map<String, Object> evidence, {Object? cropValue = crop}) {
      reference_device_driver.validateTradePositionSymbolBoundaryEvidence(
        annotationValue: evidence,
        referenceCropValue: cropValue,
        paddingValue: padding,
        comparisonId: 'trade-position-symbol',
        horizontalLayout: 'leading',
        sourceImage: source,
      );
    }

    expect(() => validate(valid), returnsNormally);
    for (final mutation in const <(String, Object)>[
      ('boundaryPolicy', 'directGuard'),
      ('sourceRightExclusiveBoundaryX', 81),
      ('lastStrongInkX', 79),
      ('blankGuardStartX', 80),
      ('blankGuardWidth', 2),
      ('excludedNeighborStartX', 83),
      ('excludedNeighborKind', 'adjacentBlueSideText'),
    ]) {
      expect(
        () => validate({...valid, mutation.$1: mutation.$2}),
        throwsStateError,
        reason: mutation.$1,
      );
    }
    expect(
      () => validate(
        valid,
        cropValue: const <String, Object>{
          'left': 3,
          'top': 369,
          'width': 80,
          'height': 35,
        },
      ),
      throwsStateError,
      reason: 'source crop width',
    );
  });

  test('every non-reviewed synthetic padding seam is free of strong ink', () {
    final failures = <String>[];
    for (final annotation in referenceFontSpecimenSourceAnnotations) {
      final decoded = image.decodeImage(
        File(annotation.sourcePath).readAsBytesSync(),
      )!;
      final rect = annotation.physicalRect;
      final reviewedRight = annotation.boundaryPolicy.name != 'directGuard';
      void check(String edge, bool padded, Iterable<image.Pixel> pixels) {
        if (!padded || (edge == 'right' && reviewedRight)) return;
        if (pixels.any(_isReferenceInk)) {
          failures.add('${annotation.candidateRunId}:$edge');
        }
      }

      check(
        'left',
        annotation.paddingLeft > 0,
        _sourceEdgePixels(decoded, rect, 'left'),
      );
      check(
        'right',
        annotation.paddingRight > 0,
        _sourceEdgePixels(decoded, rect, 'right'),
      );
      check(
        'top',
        annotation.paddingTop > 0,
        _sourceEdgePixels(decoded, rect, 'top'),
      );
      check(
        'bottom',
        annotation.paddingBottom > 0,
        _sourceEdgePixels(decoded, rect, 'bottom'),
      );
    }
    expect(failures, isEmpty);
  });

  test('synthetic-weight roles retain both real weight alternatives', () {
    for (final id in const [
      'settings-title',
      'trade-section-label',
      'trade-position-side-volume',
      'trade-profit-positive',
      'trade-profit-negative',
      'trade-balance-value',
      'trade-margin-level-value',
      'prices-low-label',
      'prices-high-label',
      'chart-timeframe',
    ]) {
      final run = referenceFontSpecimenOutputRuns.singleWhere(
        (candidate) => candidate.comparisonId == id,
      );
      expect(run.candidateWeights, const <int>{400, 700}, reason: id);
      expect(run.sourceNominalWeight, isNot(anyOf(400, 700)), reason: id);
    }
  });

  test('run parameters are current-app hypotheses, never winner evidence', () {
    expect(referenceRunParameterPolicy, const <String, Object>{
      'provenance': 'currentAppHypothesis',
      'lockEligible': false,
      'requiresRasterScoreForWinner': true,
    });
    for (final run in referenceFontSpecimenOutputRuns) {
      expect(
        run.parameterProvenance,
        ReferenceRunParameterProvenance.currentAppHypothesis,
        reason: run.comparisonId,
      );
      expect(run.parameterLockEligible, isFalse, reason: run.comparisonId);
      expect(run.parameterEvidence, containsPair('lockEligible', false));
    }
  });

  test('source runs preserve horizontal layout semantics and anchors', () {
    ReferenceFontSpecimenOutputRun run(String id) =>
        referenceFontSpecimenOutputRuns.singleWhere(
          (candidate) => candidate.comparisonId == id,
        );
    expect(
      run('navigation-price-label').horizontalLayout,
      ReferenceRunHorizontalLayout.center,
    );
    expect(
      run('settings-title').horizontalLayout,
      ReferenceRunHorizontalLayout.center,
    );
    for (final id in const [
      'settings-row-title',
      'trade-metric-balance-label',
      'trade-section-label',
      'trade-position-symbol',
      'trade-position-side-volume',
      'numeric-price-open',
      'numeric-price-close',
      'chart-timeframe',
    ]) {
      expect(
        run(id).horizontalLayout,
        ReferenceRunHorizontalLayout.leading,
        reason: id,
      );
    }
    for (final id in const [
      'trade-profit-positive',
      'trade-profit-negative',
      'trade-balance-value',
      'trade-margin-level-value',
    ]) {
      expect(
        run(id).horizontalLayout,
        ReferenceRunHorizontalLayout.trailing,
        reason: id,
      );
    }
  });

  test('the actual iOS simulator runtime identifier is normalized exactly', () {
    const sdk = 'com.apple.CoreSimulator.SimRuntime.iOS-26-5';
    expect(normalizeIosSimulatorRuntimeVersion(sdk), '26.5');
    expect(
      iosSimulatorRuntimeMatchesAppVersion(sdk, 'Version 26.5 (Build 23F76)'),
      isTrue,
    );
    expect(
      iosSimulatorRuntimeMatchesAppVersion(sdk, 'Version 26.4 (Build 23E1)'),
      isFalse,
    );
    expect(
      iosSimulatorRuntimeMatchesAppVersion(
        'com.apple.CoreSimulator.SimRuntime.iOS-26-5-1',
        'Version 26.5',
      ),
      isFalse,
    );
  });

  testWidgets('keyed run geometry and exact-six coverage are rendered', (
    tester,
  ) async {
    const candidate = ReferenceFontSpecimenCandidate(
      id: 'geometry-control',
      family: 'Mt5ReferenceRoboto',
      weight: 400,
      faceSha256:
          'f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27',
      selectable: false,
      assetPath: 'assets/fonts/mt5-reference/Roboto-Regular.ttf',
      provenance: 'test-only-geometry-control',
    );
    tester.view.devicePixelRatio = referenceFontSpecimenDevicePixelRatio;
    await tester.binding.setSurfaceSize(referenceFontSpecimenLogicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const sheetKey = Key('geometry-sheet');
    await tester.pumpWidget(
      const MaterialApp(
        home: RepaintBoundary(
          key: sheetKey,
          child: SizedBox(
            width: 393.3333333333,
            height: 620,
            child: ReferenceFontSpecimenSheet(candidate: candidate),
          ),
        ),
      ),
    );
    await tester.pump();
    final sheetRect = tester.getRect(find.byKey(sheetKey));
    for (final run in referenceFontSpecimenOutputRuns.where(
      (run) => run.supports(candidate),
    )) {
      final finder = find.byKey(ValueKey(run.keyFor(candidate)));
      expect(finder, findsOneWidget, reason: run.comparisonId);
      final rect = tester.getRect(finder);
      expect(
        (rect.left - sheetRect.left) * referenceFontSpecimenDevicePixelRatio,
        closeTo(run.physicalRect.left, .01),
      );
      expect(
        (rect.top - sheetRect.top) * referenceFontSpecimenDevicePixelRatio,
        closeTo(run.physicalRect.top, .01),
      );
      expect(
        rect.width * referenceFontSpecimenDevicePixelRatio,
        closeTo(run.physicalRect.width, .01),
      );
      expect(
        rect.height * referenceFontSpecimenDevicePixelRatio,
        closeTo(run.physicalRect.height, .01),
      );
      final baseline = tester.widget<Baseline>(
        find.descendant(of: finder, matching: find.byType(Baseline)),
      );
      expect(
        run.physicalRect.top +
            baseline.baseline * referenceFontSpecimenDevicePixelRatio,
        closeTo(run.physicalBaseline, .01),
        reason: run.comparisonId,
      );
    }
    const coverageSheetKey = Key('coverage-sheet');
    await tester.pumpWidget(
      const MaterialApp(
        home: RepaintBoundary(
          key: coverageSheetKey,
          child: SizedBox(
            width: 393.3333333333,
            height: 620,
            child: ReferenceFontCoverageSheet(candidate: candidate),
          ),
        ),
      ),
    );
    await tester.pump();
    for (final coverage in referenceFontCoverageRuns) {
      final finder = find.byKey(ValueKey(coverage.keyFor(candidate)));
      expect(finder, findsOneWidget, reason: coverage.text);
    }
    expect(find.byKey(const Key('numeric-price-arrow')), findsOneWidget);
    final coverageBoundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(coverageSheetKey),
    );
    final coverageImage = await coverageBoundary.toImage(
      pixelRatio: referenceFontSpecimenDevicePixelRatio,
    );
    expect(
      (coverageImage.width, coverageImage.height),
      (
        referenceFontSpecimenPhysicalSize.width,
        referenceFontSpecimenPhysicalSize.height,
      ),
    );
    coverageImage.dispose();
  });

  testWidgets('every emitted raster is opaque grayscale', (tester) async {
    tester.view.devicePixelRatio = referenceFontSpecimenDevicePixelRatio;
    await tester.binding.setSurfaceSize(referenceFontSpecimenLogicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final failures = <String>[];
    var scoredRasterCount = 0;
    var coverageRasterCount = 0;
    await runReferenceFontSpecimenRasterCaptureScope(tester, () async {
      for (final candidate in referenceFontSpecimenCandidates) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: referenceFontSpecimenLogicalSize.width,
              height: referenceFontSpecimenLogicalSize.height,
              child: ReferenceFontSpecimenSheet(candidate: candidate),
            ),
          ),
        );
        await tester.pump();
        for (final run in referenceFontSpecimenOutputRuns.where(
          (run) =>
              run.supports(candidate) &&
              referenceFontScoredRunIds.contains(run.comparisonId),
        )) {
          scoredRasterCount += 1;
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(ValueKey(run.keyFor(candidate))),
          );
          final capture = await captureReferenceFontSpecimenBoundary(
            tester,
            boundary,
          );
          final decoded = image.decodePng(capture.pngBytes);
          final id = '${candidate.id}--${run.comparisonId}';
          if (decoded == null) {
            failures.add('$id:decode');
            continue;
          }
          final violation = _firstNonOpaqueGrayscalePixel(decoded);
          if (violation != null) failures.add('$id:$violation');
          final edges = _imageNonWhiteEdges(decoded, inset: 2);
          if (edges.isNotEmpty) failures.add('$id:$edges');
        }

        final coverageKey = ValueKey('coverage-raster-${candidate.id}');
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: coverageKey,
              child: SizedBox(
                width: referenceFontSpecimenLogicalSize.width,
                height: referenceFontSpecimenLogicalSize.height,
                child: ReferenceFontCoverageSheet(candidate: candidate),
              ),
            ),
          ),
        );
        await tester.pump();
        final coverageBoundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(coverageKey),
        );
        final coverage = await captureReferenceFontSpecimenBoundary(
          tester,
          coverageBoundary,
        );
        coverageRasterCount += 1;
        final decodedCoverage = image.decodePng(coverage.pngBytes);
        final coverageId = '${candidate.id}--coverage';
        if (decodedCoverage == null) {
          failures.add('$coverageId:decode');
        } else {
          final violation = _firstNonOpaqueGrayscalePixel(decodedCoverage);
          if (violation != null) failures.add('$coverageId:$violation');
        }
      }
    });
    expect(scoredRasterCount, 88);
    expect(coverageRasterCount, 8);
    expect(failures, isEmpty);
  });

  testWidgets(
    'capture suppresses debug baseline chroma and restores caller state',
    (tester) async {
      final previousDebugPaintBaselinesEnabled = debugPaintBaselinesEnabled;
      try {
        debugPaintBaselinesEnabled = true;
        final candidate = referenceFontSpecimenCandidates.singleWhere(
          (value) => value.id == 'reference-roboto-condensed-regular',
        );
        final run = referenceFontSpecimenOutputRuns.singleWhere(
          (value) => value.comparisonId == 'numeric-price-open',
        );
        final capture = await runReferenceFontSpecimenRasterCaptureScope(
          tester,
          () async {
            await tester.pumpWidget(
              MaterialApp(
                home: ReferenceFontSpecimenSheet(candidate: candidate),
              ),
            );
            await tester.pump();
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(ValueKey(run.keyFor(candidate))),
            );
            return captureReferenceFontSpecimenBoundary(tester, boundary);
          },
        );
        final decoded = image.decodePng(capture.pngBytes);

        expect(debugPaintBaselinesEnabled, isTrue);
        expect(capture.debugPaintBaselinesEnabledAtCapture, isFalse);
        expect(referenceFontSpecimenRasterContract, const <String, Object>{
          'colorModel': 'opaqueGrayscale',
          'alpha': 255,
          'redEqualsGreenEqualsBlue': true,
          'debugPaintBaselinesEnabledAtCapture': false,
        });
        expect(capture.evidence, const <String, Object>{
          'opaque': true,
          'grayscale': true,
          'debugPaintBaselinesEnabledAtCapture': false,
        });
        expect(decoded, isNotNull);
        expect(_firstNonOpaqueGrayscalePixel(decoded!), isNull);
      } finally {
        debugPaintBaselinesEnabled = previousDebugPaintBaselinesEnabled;
        await tester.pump();
      }
    },
  );
}

image.Image _paddedReferenceCrop(
  image.Image source,
  ReferenceFontSpecimenSourceAnnotation annotation,
) {
  final rect = annotation.physicalRect;
  final cropped = image.copyCrop(
    source,
    x: rect.left.toInt(),
    y: rect.top.toInt(),
    width: rect.width.toInt(),
    height: rect.height.toInt(),
  );
  final output = image.Image(
    width: annotation.outputWidth.toInt(),
    height: annotation.outputHeight.toInt(),
    numChannels: 4,
  );
  image.fill(output, color: image.ColorRgba8(255, 255, 255, 255));
  image.compositeImage(
    output,
    cropped,
    dstX: annotation.paddingLeft,
    dstY: annotation.paddingTop,
    blend: image.BlendMode.direct,
  );
  return output;
}

List<String> _inkOnEdge(image.Image decoded) {
  final touching = <String>[];
  for (var inset = 0; inset < 2; inset += 1) {
    for (var x = 0; x < decoded.width; x += 1) {
      if (_isReferenceInk(decoded.getPixel(x, inset))) {
        touching.add('top');
        break;
      }
      if (_isReferenceInk(decoded.getPixel(x, decoded.height - 1 - inset))) {
        touching.add('bottom');
        break;
      }
    }
    for (var y = 0; y < decoded.height; y += 1) {
      if (_isReferenceInk(decoded.getPixel(inset, y))) {
        touching.add('left');
        break;
      }
      if (_isReferenceInk(decoded.getPixel(decoded.width - 1 - inset, y))) {
        touching.add('right');
        break;
      }
    }
  }
  return touching;
}

List<String> _imageNonWhiteEdges(image.Image decoded, {required int inset}) {
  bool white(int x, int y) {
    final pixel = decoded.getPixel(x, y);
    return pixel.r.toInt() == 255 &&
        pixel.g.toInt() == 255 &&
        pixel.b.toInt() == 255 &&
        pixel.a.toInt() == 255;
  }

  final edges = <String>{};
  for (var edge = 0; edge < inset; edge += 1) {
    for (var x = 0; x < decoded.width; x += 1) {
      if (!white(x, edge)) edges.add('top');
      if (!white(x, decoded.height - 1 - edge)) edges.add('bottom');
    }
    for (var y = 0; y < decoded.height; y += 1) {
      if (!white(edge, y)) edges.add('left');
      if (!white(decoded.width - 1 - edge, y)) edges.add('right');
    }
  }
  return edges.toList();
}

bool _isReferenceInk(image.Pixel pixel) =>
    [
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
    ].reduce((minimum, channel) => channel < minimum ? channel : minimum) <
    190;

bool _isStrongReferenceInk(image.Pixel pixel) =>
    [
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
    ].reduce((minimum, channel) => channel < minimum ? channel : minimum) <
    160;

bool _isExactWhite(image.Pixel pixel) =>
    pixel.r.toInt() == 255 &&
    pixel.g.toInt() == 255 &&
    pixel.b.toInt() == 255 &&
    pixel.a.toInt() == 255;

bool _columnHasStrongInk(image.Image source, int x, int top, int height) {
  for (var y = top; y < top + height; y += 1) {
    if (_isReferenceInk(source.getPixel(x, y))) return true;
  }
  return false;
}

bool _columnHasNonWhiteSupport(image.Image source, int x, int top, int height) {
  for (var y = top; y < top + height; y += 1) {
    if (!_isExactWhite(source.getPixel(x, y))) return true;
  }
  return false;
}

bool _columnHasBlueInk(image.Image source, int x, int top, int height) {
  for (var y = top; y < top + height; y += 1) {
    final pixel = source.getPixel(x, y);
    final red = pixel.r.toInt();
    final green = pixel.g.toInt();
    final blue = pixel.b.toInt();
    if (blue - math.max(red, green) > 15 && red < 190) return true;
  }
  return false;
}

Iterable<image.Pixel> _sourceEdgePixels(
  image.Image source,
  ReferenceSpecimenRect rect,
  String edge,
) sync* {
  final left = rect.left.toInt();
  final top = rect.top.toInt();
  final width = rect.width.toInt();
  final height = rect.height.toInt();
  for (var inset = 0; inset < 2; inset += 1) {
    if (edge == 'left' || edge == 'right') {
      final x = edge == 'left' ? left + inset : left + width - 1 - inset;
      for (var y = top; y < top + height; y += 1) {
        yield source.getPixel(x, y);
      }
    } else {
      final y = edge == 'top' ? top + inset : top + height - 1 - inset;
      for (var x = left; x < left + width; x += 1) {
        yield source.getPixel(x, y);
      }
    }
  }
}

bool _jpegScorerSupportOnEdge(image.Image value, String edge) {
  final corners = <image.Pixel>[
    value.getPixel(0, 0),
    value.getPixel(value.width - 1, 0),
    value.getPixel(0, value.height - 1),
    value.getPixel(value.width - 1, value.height - 1),
  ];
  int average(int Function(image.Pixel) channel) =>
      corners.map(channel).reduce((left, right) => left + right) ~/
      corners.length;
  final background = (
    red: average((pixel) => pixel.r.toInt()),
    green: average((pixel) => pixel.g.toInt()),
    blue: average((pixel) => pixel.b.toInt()),
  );
  bool support(int x, int y) {
    final pixel = value.getPixel(x, y);
    final red = pixel.r.toInt() - background.red;
    final green = pixel.g.toInt() - background.green;
    final blue = pixel.b.toInt() - background.blue;
    return math.sqrt(red * red + green * green + blue * blue) > 24;
  }

  return switch (edge) {
    'right' => [
      for (var y = 0; y < value.height; y += 1) support(value.width - 1, y),
    ].contains(true),
    _ => throw ArgumentError.value(edge, 'edge'),
  };
}

String? _firstNonOpaqueGrayscalePixel(image.Image decoded) {
  for (final pixel in decoded) {
    final red = pixel.r.toInt();
    final green = pixel.g.toInt();
    final blue = pixel.b.toInt();
    final alpha = pixel.a.toInt();
    if (alpha != 255 || red != green || green != blue) {
      return 'rgba($red,$green,$blue,$alpha)';
    }
  }
  return null;
}
