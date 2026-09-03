import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/test_support/reference_font_loader.dart';
import '../test/test_support/reference_typography_role_manifest.dart';
import '../test/test_support/reference_typography_specimen_widgets.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const rendererId = String.fromEnvironment('REFERENCE_RENDERER');

  setUpAll(() async {
    if (rendererId != ReferenceRendererProfile.ios.id) {
      throw StateError(
        'REFERENCE_RENDERER must be ${ReferenceRendererProfile.ios.id}',
      );
    }
    await loadReferenceFonts();
  });

  testWidgets('captures keyed role runs on the primary renderer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = referenceFontSpecimenDevicePixelRatio;
    await tester.binding.setSurfaceSize(referenceFontSpecimenLogicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await runReferenceFontSpecimenRasterCaptureScope(tester, () async {
      final specimens = <Map<String, Object>>[];
      final coverageSpecimens = <Map<String, Object>>[];
      for (final candidate in referenceFontSpecimenCandidates) {
        final sheetKey = ValueKey('reference-specimen-${candidate.id}');
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('vi', 'VN'),
            home: MediaQuery(
              data: const MediaQueryData(
                size: referenceFontSpecimenLogicalSize,
                devicePixelRatio: referenceFontSpecimenDevicePixelRatio,
                textScaler: TextScaler.noScaling,
              ),
              child: RepaintBoundary(
                key: sheetKey,
                child: SizedBox.fromSize(
                  size: referenceFontSpecimenLogicalSize,
                  child: ReferenceFontSpecimenSheet(candidate: candidate),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final sheetRect = tester.getRect(find.byKey(sheetKey));

        for (final run in referenceFontSpecimenOutputRuns.where(
          (run) => run.supports(candidate),
        )) {
          final runFinder = find.byKey(ValueKey(run.keyFor(candidate)));
          final runRect = tester.getRect(runFinder);
          final actualPhysicalRect = Rect.fromLTWH(
            (runRect.left - sheetRect.left) *
                referenceFontSpecimenDevicePixelRatio,
            (runRect.top - sheetRect.top) *
                referenceFontSpecimenDevicePixelRatio,
            runRect.width * referenceFontSpecimenDevicePixelRatio,
            runRect.height * referenceFontSpecimenDevicePixelRatio,
          );
          _expectRect(actualPhysicalRect, run.physicalRect, run.comparisonId);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            runFinder,
          );
          final baselineWidget = tester.widget<Baseline>(
            find.descendant(of: runFinder, matching: find.byType(Baseline)),
          );
          final physicalBaseline =
              run.physicalRect.top +
              baselineWidget.baseline * referenceFontSpecimenDevicePixelRatio;
          expect(
            physicalBaseline,
            closeTo(run.physicalBaseline, .01),
            reason: run.comparisonId,
          );
          if (!referenceFontScoredRunIds.contains(run.comparisonId)) continue;
          final capture = await captureReferenceFontSpecimenBoundary(
            tester,
            boundary,
          );
          final png = capture.pngBytes;
          final id = '${candidate.id}--${run.comparisonId}';
          specimens.add({
            'id': id,
            'comparisonId': run.comparisonId,
            'roleId': run.roleId,
            'candidateId': candidate.id,
            'text': run.text,
            'sourceClass': 'annotatedReferenceRun',
            'sourceAnnotationId': run.comparisonId,
            'file': '$id.png',
            'sha256': sha256.convert(png).toString(),
            'pngBase64': base64Encode(png),
            'font': _fontJson(candidate, roleId: run.roleId),
            'pointSize': run.pointSize,
            'sourceNominalWeight': run.sourceNominalWeight,
            'candidateWeight': candidate.weight,
            'letterSpacing': run.letterSpacing,
            'tabularFigures': run.tabularFigures,
            'physicalWidth': run.physicalRect.width.toInt(),
            'physicalHeight': run.physicalRect.height.toInt(),
            'candidateBaseline': run.physicalBaseline - run.physicalRect.top,
            'horizontalLayout': run.horizontalLayout.name,
            'candidateAnchorX': run.horizontalAnchor,
            'parameterEvidence': run.parameterEvidence,
            'devicePixelRatio': referenceFontSpecimenDevicePixelRatio,
            'textScale': 1.0,
            'locale': 'vi-VN',
            'rasterEvidence': capture.evidence,
          });
        }

        final coverageKey = ValueKey(
          'reference-coverage-sheet-${candidate.id}',
        );
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('vi', 'VN'),
            home: MediaQuery(
              data: const MediaQueryData(
                size: referenceFontSpecimenLogicalSize,
                devicePixelRatio: referenceFontSpecimenDevicePixelRatio,
                textScaler: TextScaler.noScaling,
              ),
              child: RepaintBoundary(
                key: coverageKey,
                child: SizedBox.fromSize(
                  size: referenceFontSpecimenLogicalSize,
                  child: ReferenceFontCoverageSheet(candidate: candidate),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        for (final coverage in referenceFontCoverageRuns) {
          expect(
            find.byKey(ValueKey(coverage.keyFor(candidate))),
            findsOneWidget,
            reason: coverage.text,
          );
        }
        final coverageBoundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(coverageKey),
        );
        final capture = await captureReferenceFontSpecimenBoundary(
          tester,
          coverageBoundary,
        );
        final png = capture.pngBytes;
        final id = '${candidate.id}--coverage';
        coverageSpecimens.add({
          'id': id,
          'candidateId': candidate.id,
          'text': referenceFontSpecimenStrings.join('\n'),
          'strings': referenceFontSpecimenStrings,
          'file': '$id.png',
          'sha256': sha256.convert(png).toString(),
          'pngBase64': base64Encode(png),
          'physicalWidth': referenceFontSpecimenPhysicalSize.width.toInt(),
          'physicalHeight': referenceFontSpecimenPhysicalSize.height.toInt(),
          'devicePixelRatio': referenceFontSpecimenDevicePixelRatio,
          'textScale': 1.0,
          'locale': 'vi-VN',
          'font': _fontJson(candidate),
          'scored': false,
          'rasterEvidence': capture.evidence,
        });
      }

      binding.reportData = {
        'referenceFontSpecimens': {
          'schemaVersion': 1,
          'rendererId': rendererId,
          'diagnosticOnly': false,
          'appOperatingSystem': Platform.operatingSystem,
          'appOperatingSystemVersion': Platform.operatingSystemVersion,
          'parameterPolicy': referenceRunParameterPolicy,
          'rasterContract': referenceFontSpecimenRasterContract,
          'specimens': specimens,
          'coverageSpecimens': coverageSpecimens,
        },
      };
    });
  });

  testWidgets(
    'capture suppresses baseline debug paint and restores the external flag',
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

        expect(debugPaintBaselinesEnabled, isTrue);
        expect(capture.debugPaintBaselinesEnabledAtCapture, isFalse);
        expect(await _firstRasterContractViolation(capture.pngBytes), isNull);
      } finally {
        debugPaintBaselinesEnabled = previousDebugPaintBaselinesEnabled;
        await tester.pump();
      }
    },
  );
}

Future<String?> _firstRasterContractViolation(List<int> png) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  codec.dispose();
  if (rgba == null) return 'PNG could not be decoded as raw RGBA';
  for (var offset = 0; offset < rgba.lengthInBytes; offset += 4) {
    final red = rgba.getUint8(offset);
    final green = rgba.getUint8(offset + 1);
    final blue = rgba.getUint8(offset + 2);
    final alpha = rgba.getUint8(offset + 3);
    if (alpha != 255 || red != green || green != blue) {
      final pixel = offset ~/ 4;
      return 'pixel $pixel is rgba($red,$green,$blue,$alpha)';
    }
  }
  return null;
}

Map<String, Object> _fontJson(
  ReferenceFontSpecimenCandidate candidate, {
  String? roleId,
}) => {
  'family': candidate.family,
  'faceSha256': candidate.faceSha256,
  'weight': candidate.weight,
  'selectable': roleId == null
      ? candidate.selectable
      : candidate.isSelectableForRole(roleId),
  'selectableRoleIds': candidate.selectableRoleIds.toList()..sort(),
  'assetPath': candidate.assetPath,
  'provenance': candidate.provenance,
};

void _expectRect(Rect actual, ReferenceSpecimenRect expected, String id) {
  expect(actual.left, closeTo(expected.left, .01), reason: '$id left');
  expect(actual.top, closeTo(expected.top, .01), reason: '$id top');
  expect(actual.width, closeTo(expected.width, .01), reason: '$id width');
  expect(actual.height, closeTo(expected.height, .01), reason: '$id height');
}
