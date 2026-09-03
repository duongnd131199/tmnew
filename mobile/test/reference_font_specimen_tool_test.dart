import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

const _scorerPath = 'tool/compare_reference_font_specimens.dart';
const _rendererPath = 'tool/render_forensic_font_specimens.swift';
const _lockedTradeReferenceSha256 =
    '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc';
const _referenceRoleManifestSha256 =
    '6eafbb63c29a8313df4ec9ffa6f0a2afa455b0e5c7fffd4d2d3ef85183c9f2d0';
const _coverageStrings = <String>[
  'Giá  Biểu đồ  Giao dịch  Lịch sử  Cài đặt',
  'Số dư:  Vốn:  Tiền ký quỹ:  Mức ký quỹ (%):',
  'XAUUSD buy 1',
  '4637.05 → 4640.81',
  '376.00  -341.00  103 310.00  203.24',
  'L:  H:  M1  Orders  Deals',
];

class _TrailingFixtureContract {
  const _TrailingFixtureContract({
    required this.roleId,
    required this.text,
    required this.pointSize,
    required this.sourceNominalWeight,
    required this.width,
    required this.height,
    required this.baseline,
    required this.anchor,
    required this.letterSpacing,
    required this.sourceLeft,
    required this.sourceTop,
    required this.sourceWidth,
    required this.paddingLeft,
    required this.paddingRight,
  });

  final String roleId;
  final String text;
  final double pointSize;
  final int sourceNominalWeight;
  final int width;
  final int height;
  final int baseline;
  final int anchor;
  final double letterSpacing;
  final int sourceLeft;
  final int sourceTop;
  final int sourceWidth;
  final int paddingLeft;
  final int paddingRight;
}

const _trailingFixtureContracts = <String, _TrailingFixtureContract>{
  'trade-profit-positive': _TrailingFixtureContract(
    roleId: 'tradePositionProfit',
    text: '376.00',
    pointSize: 21,
    sourceNominalWeight: 550,
    width: 115,
    height: 46,
    baseline: 34,
    anchor: 107,
    letterSpacing: .17,
    sourceLeft: 475,
    sourceTop: 375,
    sourceWidth: 107,
    paddingLeft: 0,
    paddingRight: 8,
  ),
  'trade-profit-negative': _TrailingFixtureContract(
    roleId: 'tradePositionProfit',
    text: '-341.00',
    pointSize: 21,
    sourceNominalWeight: 550,
    width: 136,
    height: 42,
    baseline: 30,
    anchor: 123,
    letterSpacing: .17,
    sourceLeft: 467,
    sourceTop: 857,
    sourceWidth: 115,
    paddingLeft: 8,
    paddingRight: 13,
  ),
  'trade-balance-value': _TrailingFixtureContract(
    roleId: 'tradeMetricValue',
    text: '103 310.00',
    pointSize: 16,
    sourceNominalWeight: 450,
    width: 140,
    height: 40,
    baseline: 29,
    anchor: 134,
    letterSpacing: .2,
    sourceLeft: 448,
    sourceTop: 156,
    sourceWidth: 134,
    paddingLeft: 0,
    paddingRight: 6,
  ),
  'trade-margin-level-value': _TrailingFixtureContract(
    roleId: 'tradeMetricValue',
    text: '203.24',
    pointSize: 16,
    sourceNominalWeight: 450,
    width: 96,
    height: 37,
    baseline: 23,
    anchor: 90,
    letterSpacing: .2,
    sourceLeft: 492,
    sourceTop: 291,
    sourceWidth: 90,
    paddingLeft: 0,
    paddingRight: 6,
  ),
};

void main() {
  group('reference specimen scorer', () {
    test('rejects a host run unless diagnostic-only is explicit', () async {
      final fixture = await _ScorerFixture.create(
        rendererId: 'host-coretext-forensic',
      );
      addTearDown(fixture.dispose);

      final output = Directory('${fixture.root.path}/review');
      final result = await _runScorer(
        renderer: 'host-coretext-forensic',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('--diagnostic-only'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('verifies hashes before creating any review output', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      final manifest = fixture.manifestJson;
      final specimens = manifest['specimens']! as List<dynamic>;
      (specimens.first as Map<String, dynamic>)['sha256'] = _repeat('0', 64);
      fixture.manifest.writeAsStringSync(_prettyJson(manifest));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('SHA-256 mismatch'),
      );
      expect(output.existsSync(), isFalse);
    });

    test(
      'refuses an existing output directory without changing inputs',
      () async {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        final beforeManifest = fixture.manifest.readAsBytesSync();
        final beforeHashes = fixture.inputHashes;
        final output = Directory('${fixture.root.path}/review')..createSync();
        final sentinel = File('${output.path}/keep.txt')
          ..writeAsStringSync('owned');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}\n${result.stderr}',
          contains('already exists'),
        );
        expect(sentinel.readAsStringSync(), 'owned');
        expect(fixture.manifest.readAsBytesSync(), beforeManifest);
        expect(fixture.inputHashes, beforeHashes);
      },
    );

    test(
      'controlled specimens emit topology metrics, overlays, and a proposal',
      () async {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        final output = Directory('${fixture.root.path}/review');
        final beforeHashes = fixture.inputHashes;

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final report = _readJson(File('${output.path}/report.json'));
        expect(report['rendererId'], 'ios');
        expect(report['diagnosticOnly'], isFalse);
        expect(report['hostWinnerClaimsProhibited'], isFalse);
        expect(
          report['referenceRoleManifestSha256'],
          _referenceRoleManifestSha256,
        );
        expect(report['parameterPolicy'], <String, dynamic>{
          'provenance': 'currentAppHypothesis',
          'lockEligible': false,
          'requiresRasterScoreForWinner': true,
        });
        final measurements = report['measurements']! as List<dynamic>;
        expect(measurements, hasLength(2));
        for (final value in measurements.cast<Map<String, dynamic>>()) {
          expect(
            (value['comparisonContract']!
                as Map<String, dynamic>)['referenceRoleManifestSha256'],
            _referenceRoleManifestSha256,
          );
          expect(value['metricPolicy'], 'controlled-lossless');
          final metrics = value['metrics']! as Map<String, dynamic>;
          expect(
            metrics.keys,
            containsAll(<String>[
              'componentTopologyExact',
              'advanceDeltaPx',
              'centroidDeltaPx',
              'coverageMassDeltaRatio',
              'strokeWidthDeltaRatio',
            ]),
          );
          final overlay = File('${output.path}/${value['overlayFile']}');
          expect(overlay.existsSync(), isTrue);
          expect(
            value['overlaySha256'],
            sha256.convert(overlay.readAsBytesSync()).toString(),
          );
          expect(value['parameterEvidence'], <String, dynamic>{
            'provenance': 'currentAppHypothesis',
            'lockEligible': false,
            'scope': 'pointSize-letterSpacing-features-sourceNominalWeight',
          });
          expect(
            value['comparisonContract'],
            containsPair('parameterEvidence', value['parameterEvidence']),
          );
        }
        final coverage = (report['coverageEvidence']! as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(coverage, hasLength(2));
        for (final value in coverage) {
          expect(value['verifiedRaster'], <String, dynamic>{
            'opaque': true,
            'grayscale': true,
          });
          expect(value['strings'], _coverageStrings);
        }
        final winners = report['proposedWinners']! as List<dynamic>;
        expect(winners, hasLength(1));
        expect(
          (winners.single as Map<String, dynamic>)['candidateId'],
          'exact',
        );
        expect(winners.single, containsPair('parameterLockEligible', false));
        expect(winners.single, containsPair('reviewedWinner', false));
        expect(
          winners.single,
          containsPair('requiresPrimaryIosHumanReview', true),
        );
        expect(fixture.inputHashes, beforeHashes);
      },
    );

    test('requires a lowercase role-manifest SHA checkpoint', () async {
      for (final invalid in <Object?>[null, _repeat('A', 64), 'abc']) {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        if (invalid == null) {
          fixture.manifestJson.remove('referenceRoleManifestSha256');
        } else {
          fixture.manifestJson['referenceRoleManifestSha256'] = invalid;
        }
        fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0), reason: '$invalid');
        expect(
          '${result.stdout}\n${result.stderr}',
          contains('referenceRoleManifestSha256'),
          reason: '$invalid',
        );
        expect(output.existsSync(), isFalse, reason: '$invalid');
      }
    });

    test('requires exact primary raster declarations', () async {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (manifest) => manifest.remove('rasterContract'),
        (manifest) {
          final coverage =
              (manifest['coverageSpecimens']! as List<dynamic>).first
                  as Map<String, dynamic>;
          (coverage['rasterEvidence']! as Map<String, dynamic>)['grayscale'] =
              false;
        },
      ]) {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        mutate(fixture.manifestJson);
        fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}\n${result.stderr}',
          anyOf(contains('rasterContract'), contains('rasterEvidence')),
        );
        expect(output.existsSync(), isFalse);
      }
    });

    test('rejects lockable or missing parameter-hypothesis metadata', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      final policy =
          fixture.manifestJson['parameterPolicy']! as Map<String, dynamic>;
      policy['lockEligible'] = true;
      final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
      (specimens.first as Map<String, dynamic>).remove('parameterEvidence');
      fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('parameterPolicy must declare currentAppHypothesis'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('rejects missing per-run parameter evidence', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
      (specimens.first as Map<String, dynamic>).remove('parameterEvidence');
      fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('parameterEvidence must declare currentAppHypothesis'),
      );
      expect(output.existsSync(), isFalse);
    });

    test(
      'rejects a scored controlled specimen without crop annotations',
      () async {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
        (specimens.first as Map<String, dynamic>).remove('annotations');
        fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}\n${result.stderr}',
          contains('requires a verified reference file and SHA'),
        );
        expect(output.existsSync(), isFalse);
      },
    );

    test('rejects candidates with divergent role contracts', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
      (specimens.last as Map<String, dynamic>)['pointSize'] = 21;
      fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('comparison contract mismatch'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('rejects a scored specimen without an exact face SHA', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
      (specimens.first as Map<String, dynamic>).remove('font');
      fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('exact candidate face SHA'),
      );
      expect(output.existsSync(), isFalse);
    });

    test(
      'rejects a candidate face SHA absent from the manifest font set',
      () async {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
        final font =
            (specimens.first as Map<String, dynamic>)['font']!
                as Map<String, dynamic>;
        font['faceSha256'] = _repeat('b', 64);
        fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}\n${result.stderr}',
          contains('not declared by the manifest font set'),
        );
        expect(output.existsSync(), isFalse);
      },
    );

    test(
      'binds scored entries to the authoritative manifest renderer',
      () async {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
        for (final specimen in specimens.cast<Map<String, dynamic>>()) {
          specimen.remove('rendererId');
        }
        fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final report = _readJson(File('${output.path}/report.json'));
        final measurements = (report['measurements']! as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(
          measurements.every((value) => value['rendererId'] == 'ios'),
          isTrue,
        );
      },
    );

    test('rejects candidate ink touching a crop edge', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
      final first = specimens.first as Map<String, dynamic>;
      final candidate = File('${fixture.candidates.path}/${first['file']}');
      final decoded = image.decodePng(candidate.readAsBytesSync())!;
      decoded.setPixelRgba(12, 0, 0, 0, 0, 255);
      candidate.writeAsBytesSync(image.encodePng(decoded));
      first['sha256'] = sha256.convert(candidate.readAsBytesSync()).toString();
      fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('touches a crop edge'),
      );
      expect(output.existsSync(), isFalse);
    });

    test(
      'rejects a yellow debug baseline pixel in any candidate PNG',
      () async {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
        final specimen = specimens.first as Map<String, dynamic>;
        final candidate = File(
          '${fixture.candidates.path}/${specimen['file']}',
        );
        final decoded = image.decodePng(candidate.readAsBytesSync())!;
        decoded.setPixelRgba(10, 30, 255, 255, 64, 255);
        candidate.writeAsBytesSync(image.encodePng(decoded));
        specimen['sha256'] = sha256
            .convert(candidate.readAsBytesSync())
            .toString();
        fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}\n${result.stderr}',
          contains('grayscale-only'),
        );
        expect(output.existsSync(), isFalse);
      },
    );

    test('rejects a nonopaque pixel in any candidate PNG', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
      final specimen = specimens.first as Map<String, dynamic>;
      final candidate = File('${fixture.candidates.path}/${specimen['file']}');
      final decoded = image.decodePng(candidate.readAsBytesSync())!;
      decoded.setPixelRgba(10, 30, 64, 64, 64, 254);
      candidate.writeAsBytesSync(image.encodePng(decoded));
      specimen['sha256'] = sha256
          .convert(candidate.readAsBytesSync())
          .toString();
      fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect('${result.stdout}\n${result.stderr}', contains('fully opaque'));
      expect(output.existsSync(), isFalse);
    });

    test('independently rejects chroma in a coverage PNG', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      final coverage =
          (fixture.manifestJson['coverageSpecimens']! as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final specimen = coverage.first;
      final candidate = File('${fixture.candidates.path}/${specimen['file']}');
      final decoded = image.decodePng(candidate.readAsBytesSync())!;
      decoded.setPixelRgba(10, 30, 255, 255, 64, 255);
      candidate.writeAsBytesSync(image.encodePng(decoded));
      specimen['sha256'] = sha256
          .convert(candidate.readAsBytesSync())
          .toString();
      fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('coverage coverage-exact must be grayscale-only'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('rejects specimen ids that cannot name unique overlays', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      final specimens = (fixture.manifestJson['specimens']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      specimens[0]['id'] = 'quote/large';
      specimens[1]['id'] = 'quote?large';
      fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('safe unique overlay filename'),
      );
      expect(output.existsSync(), isFalse);
    });

    test(
      'rejects output reached through a symlink alias into candidates',
      () async {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        final alias = Link('${fixture.root.path}/candidate-alias')
          ..createSync(fixture.candidates.path);
        final output = Directory('${alias.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}\n${result.stderr}',
          contains('inside the read-only candidate directory'),
        );
        expect(output.existsSync(), isFalse);
      },
    );

    test('JPEG crops use only JPEG-aware whole-run metrics', () async {
      final fixture = await _ScorerFixture.create(
        rendererId: 'ios',
        sourceClass: 'jpegCrop',
      );
      addTearDown(fixture.dispose);
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final report = _readJson(File('${output.path}/report.json'));
      final measurements = (report['measurements']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final value in measurements) {
        expect(value['metricPolicy'], 'jpeg-aware-whole-run');
        expect(value['annotationsUsed'], <String, dynamic>{
          'baselineOrigin': 'top',
          'referenceCrop': <String, dynamic>{
            'left': 10,
            'top': 4,
            'width': 80,
            'height': 32,
          },
          'candidateCrop': <String, dynamic>{
            'left': 5,
            'top': 2,
            'width': 80,
            'height': 32,
          },
          'baseline': <String, dynamic>{'referenceY': 25, 'candidateY': 25},
          'landmarks': <dynamic>[
            <String, dynamic>{
              'id': 'run-left',
              'reference': <String, dynamic>{'x': 8, 'y': 25},
              'candidate': <String, dynamic>{'x': 8, 'y': 25},
            },
            <String, dynamic>{
              'id': 'run-right',
              'reference': <String, dynamic>{'x': 59, 'y': 25},
              'candidate': <String, dynamic>{'x': 59, 'y': 25},
            },
          ],
        });
        final metrics = value['metrics']! as Map<String, dynamic>;
        expect(
          metrics.keys,
          containsAll(<String>[
            'supportIou',
            'symmetricResidualRatio',
            'densityDeltaRatio',
            'extentDeltaPx',
            'baselineProxyDeltaPx',
            'annotatedBaselineDeltaPx',
            'annotatedLandmarkMeanDeltaPx',
            'annotatedLandmarkMaxDeltaPx',
          ]),
        );
        expect(metrics.keys, isNot(contains('componentTopologyExact')));
        expect(metrics.keys, isNot(contains('advanceDeltaPx')));
        expect(metrics.keys, isNot(contains('centroidDeltaPx')));
        expect(metrics.keys, isNot(contains('coverageMassDeltaRatio')));
        expect(metrics.keys, isNot(contains('strokeWidthDeltaRatio')));
      }
    });

    test('recomputes and reports a declared white-padding transform', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      _configureDerivedReference(fixture);
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final report = _readJson(File('${output.path}/report.json'));
      final measurements = (report['measurements']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final measurement in measurements) {
        expect(
          measurement['referenceProvenance'],
          containsPair('transformVerified', true),
        );
        expect(
          measurement['referenceProvenance'],
          containsPair('kind', 'whitePaddingNoResample'),
        );
      }
    });

    test('rejects derived bytes even when their own SHA was updated', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      _configureDerivedReference(fixture, tamperDerived: true);
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('does not match the declared white-padding transform'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('rejects source ink touching a raw-crop padding seam', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      _configureDerivedReference(fixture, seamInk: true);
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('ink touches the raw crop-to-padding seam'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('rejects an arbitrary trailing-before-scrollbar waiver', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      _configureDerivedReference(
        fixture,
        seamInk: true,
        trailingScrollbarBoundary: true,
      );
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('exact reviewed trade contract'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('allows only the four exact reviewed scrollbar contracts', () async {
      for (final comparisonId in _trailingFixtureContracts.keys) {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        _configureTrailingScrollbarReference(fixture, comparisonId);
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(
          result.exitCode,
          0,
          reason: '$comparisonId\n${result.stdout}\n${result.stderr}',
        );
        final report = _readJson(File('${output.path}/report.json'));
        final measurements = (report['measurements']! as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (final measurement in measurements) {
          final provenance =
              measurement['referenceProvenance']! as Map<String, dynamic>;
          expect(provenance['reviewedDiagnosticBoundary'], isTrue);
          expect(provenance['certifying'], isFalse);
          expect(provenance['topologyEligible'], isFalse);
        }
      }
    });

    test('rejects wrong scrollbar source, id, boundary, and anchor', () async {
      for (final mutation in <(String, void Function(Map<String, dynamic>))>[
        (
          'source',
          (specimen) {
            specimen['sourceSha256'] = _repeat('b', 64);
            final transform =
                specimen['referenceTransform']! as Map<String, dynamic>;
            transform['sourceSha256'] = _repeat('b', 64);
          },
        ),
        ('id', (specimen) => specimen['comparisonId'] = 'other-role'),
        (
          'boundary',
          (specimen) =>
              (specimen['referenceTransform']!
                      as Map<
                        String,
                        dynamic
                      >)['sourceRightExclusiveBoundaryX'] =
                  581,
        ),
        (
          'anchor',
          (specimen) {
            specimen['candidateAnchorX'] = 106;
            final annotations =
                specimen['annotations']! as Map<String, dynamic>;
            final landmarks = annotations['landmarks']! as List<dynamic>;
            final landmark = landmarks.single as Map<String, dynamic>;
            (landmark['reference']! as Map<String, dynamic>)['x'] = 106;
            (landmark['candidate']! as Map<String, dynamic>)['x'] = 106;
          },
        ),
      ]) {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        _configureTrailingScrollbarReference(fixture, 'trade-profit-positive');
        final specimens = (fixture.manifestJson['specimens']! as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (final specimen in specimens) {
          mutation.$2(specimen);
        }
        fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0), reason: mutation.$1);
        expect(output.existsSync(), isFalse, reason: mutation.$1);
      }
    });

    test(
      'rejects retained source ink injected at scrollbar guard x581',
      () async {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        _configureTrailingScrollbarReference(
          fixture,
          'trade-profit-positive',
          inkFinalGuardColumn: true,
        );
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}\n${result.stderr}',
          contains('source x581 must be blank'),
        );
        expect(output.existsSync(), isFalse);
      },
    );

    test('allows only the exact trade-symbol adjacent-text boundary', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      _configureTradeSymbolBoundaryReference(fixture);
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final report = _readJson(File('${output.path}/report.json'));
      final measurements = (report['measurements']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final measurement in measurements) {
        final provenance =
            measurement['referenceProvenance']! as Map<String, dynamic>;
        expect(provenance['reviewedDiagnosticBoundary'], isTrue);
        expect(provenance['certifying'], isFalse);
        expect(provenance['topologyEligible'], isFalse);
      }
    });

    test('rejects wrong trade-symbol id, source, crop, and boundary', () async {
      for (final mutation in <(String, void Function(Map<String, dynamic>))>[
        ('id', (specimen) => specimen['comparisonId'] = 'other-symbol'),
        (
          'source',
          (specimen) {
            specimen['sourceSha256'] = _repeat('b', 64);
            (specimen['referenceTransform']!
                as Map<String, dynamic>)['sourceSha256'] = _repeat(
              'b',
              64,
            );
          },
        ),
        (
          'crop',
          (specimen) {
            (specimen['sourceCrop']! as Map<String, dynamic>)['width'] = 78;
            ((specimen['referenceTransform']!
                        as Map<String, dynamic>)['sourceCrop']!
                    as Map<String, dynamic>)['width'] =
                78;
          },
        ),
        (
          'boundary',
          (specimen) =>
              (specimen['referenceTransform']!
                      as Map<
                        String,
                        dynamic
                      >)['sourceRightExclusiveBoundaryX'] =
                  81,
        ),
        (
          'strong-guard-metadata',
          (specimen) =>
              (specimen['referenceTransform']!
                      as Map<String, dynamic>)['lastStrongInkX'] =
                  79,
        ),
      ]) {
        final fixture = await _ScorerFixture.create(rendererId: 'ios');
        addTearDown(fixture.dispose);
        _configureTradeSymbolBoundaryReference(fixture);
        final specimens = (fixture.manifestJson['specimens']! as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (final specimen in specimens) {
          mutation.$2(specimen);
        }
        fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0), reason: mutation.$1);
        expect(output.existsSync(), isFalse, reason: mutation.$1);
      }
    });

    test('rejects strong ink in the trade-symbol x81 JPEG guard', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      _configureTradeSymbolBoundaryReference(fixture, inkGuardColumn: true);
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('source x81 must have no strong ink'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('rejects a missing trade side/volume neighbour at x82', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      _configureTradeSymbolBoundaryReference(fixture, eraseNeighbor: true);
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('excluded tradePositionSideVolume neighbour'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('allows the exact leading-before-arrow JPEG-noise boundary', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      _configureLeadingArrowReference(fixture);
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final report = _readJson(File('${output.path}/report.json'));
      final measurements = (report['measurements']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final measurement in measurements) {
        final provenance =
            measurement['referenceProvenance']! as Map<String, dynamic>;
        expect(provenance['reviewedDiagnosticBoundary'], isTrue);
        expect(provenance['certifying'], isFalse);
        expect(provenance['topologyEligible'], isFalse);
      }
    });

    test('rejects false leading-before-arrow blank-guard provenance', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      _configureLeadingArrowReference(fixture);
      final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
      for (final specimen in specimens.cast<Map<String, dynamic>>()) {
        final transform =
            specimen['referenceTransform']! as Map<String, dynamic>;
        transform['lastStrongInkX'] = 59;
      }
      fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('leading-before-arrow blank-guard provenance'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('rejects an unknown derived-reference boundary exception', () async {
      final fixture = await _ScorerFixture.create(rendererId: 'ios');
      addTearDown(fixture.dispose);
      _configureDerivedReference(
        fixture,
        seamInk: true,
        trailingScrollbarBoundary: true,
      );
      final specimens = fixture.manifestJson['specimens']! as List<dynamic>;
      for (final specimen in specimens.cast<Map<String, dynamic>>()) {
        final transform =
            specimen['referenceTransform']! as Map<String, dynamic>;
        transform['boundaryPolicy'] = 'allowEveryEdge';
      }
      fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('unsupported reference boundary policy'),
      );
      expect(output.existsSync(), isFalse);
    });

    test(
      'JPEG crops reject missing baseline and landmark annotations',
      () async {
        final fixture = await _ScorerFixture.create(
          rendererId: 'ios',
          sourceClass: 'jpegCrop',
          includeJpegAnnotations: false,
        );
        addTearDown(fixture.dispose);
        final output = Directory('${fixture.root.path}/review');

        final result = await _runScorer(
          renderer: 'ios',
          candidateDirectory: fixture.candidates,
          outputDirectory: output,
        );

        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}\n${result.stderr}',
          contains('mandatory top-origin baseline and landmark annotations'),
        );
        expect(output.existsSync(), isFalse);
      },
    );

    test('primary iOS refuses an unscored candidate sheet', () async {
      final fixture = await _ScorerFixture.create(
        rendererId: 'ios',
        includeReference: false,
      );
      addTearDown(fixture.dispose);
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'ios',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
      );

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('requires a source-hashed reference association'),
      );
      expect(output.existsSync(), isFalse);
    });

    test('host diagnostics never emit a winner claim', () async {
      final fixture = await _ScorerFixture.create(
        rendererId: 'host-coretext-forensic',
        includeReference: false,
      );
      addTearDown(fixture.dispose);
      final output = Directory('${fixture.root.path}/review');

      final result = await _runScorer(
        renderer: 'host-coretext-forensic',
        candidateDirectory: fixture.candidates,
        outputDirectory: output,
        diagnosticOnly: true,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final report = _readJson(File('${output.path}/report.json'));
      expect(report['diagnosticOnly'], isTrue);
      expect(report['hostWinnerClaimsProhibited'], isTrue);
      expect(report['proposedWinners'], isEmpty);
      expect(report['diagnosticRankings'], isNotEmpty);
      expect(
        report['claimLimit'],
        contains('cannot select or claim a primary iOS winner'),
      );
    });
  });

  group('CoreText forensic renderer', () {
    test('requires a private temporary font path', () async {
      if (!Platform.isMacOS) return;
      final root = await Directory.systemTemp.createTemp(
        'mt5-forensic-reject-',
      );
      addTearDown(() => root.delete(recursive: true));
      final output = Directory('${root.path}/output')..createSync();
      final repositoryFont = File(
        'assets/fonts/mt5-reference/Roboto-Regular.ttf',
      ).absolute;
      final referenceSource = File(
        '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
      ).absolute;

      final result = await Process.run('xcrun', <String>[
        'swift',
        _rendererPath,
        '--font',
        repositoryFont.path,
        '--reference-source',
        referenceSource.path,
        '--output',
        output.path,
        '--renderer-id',
        'host-coretext-forensic',
      ]);

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('private temporary'),
      );
      expect(output.listSync(), isEmpty);
    });

    test(
      'rejects a source reference whose SHA is not the locked crop source',
      () async {
        if (!Platform.isMacOS) return;
        final root = Directory(
          '/tmp/mt5-forensic-source-$pid-${DateTime.now().microsecondsSinceEpoch}',
        )..createSync();
        addTearDown(() => root.delete(recursive: true));
        final privateFont = File('${root.path}/candidate.ttf')
          ..writeAsBytesSync(
            File(
              'assets/fonts/mt5-reference/Roboto-Regular.ttf',
            ).readAsBytesSync(),
          );
        final wrongReference = File('${root.path}/wrong-reference.jpg')
          ..writeAsBytesSync(<int>[1, 2, 3, 4]);
        final output = Directory('${root.path}/output')..createSync();

        final result = await Process.run('xcrun', <String>[
          'swift',
          _rendererPath,
          '--font',
          privateFont.path,
          '--reference-source',
          wrongReference.path,
          '--output',
          output.path,
          '--renderer-id',
          'host-coretext-forensic',
        ]);

        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}\n${result.stderr}',
          contains('reference source SHA-256'),
        );
        expect(output.listSync(), isEmpty);
      },
    );

    test(
      'renders deterministic opaque exact-string evidence without font bytes',
      () async {
        if (!Platform.isMacOS) return;
        final root = Directory(
          '/tmp/mt5-forensic-render-$pid-${DateTime.now().microsecondsSinceEpoch}',
        )..createSync();
        addTearDown(() => root.delete(recursive: true));
        final input = Directory('${root.path}/private-input')..createSync();
        final sourceFont = File(
          'assets/fonts/mt5-reference/Roboto-Regular.ttf',
        );
        final referenceSource = File(
          '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        ).absolute;
        expect(
          sha256.convert(referenceSource.readAsBytesSync()).toString(),
          '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        );
        final privateFont = File('${input.path}/candidate.ttf')
          ..writeAsBytesSync(sourceFont.readAsBytesSync());
        final first = Directory('${root.path}/first')..createSync();
        final second = Directory('${root.path}/second')..createSync();

        for (final output in <Directory>[first, second]) {
          final result = await Process.run('xcrun', <String>[
            'swift',
            _rendererPath,
            '--font',
            privateFont.path,
            '--reference-source',
            referenceSource.path,
            '--output',
            output.path,
            '--renderer-id',
            'host-coretext-forensic',
          ]);
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}\n${result.stderr}',
          );
        }

        final firstManifestFile = File('${first.path}/manifest.json');
        final secondManifestFile = File('${second.path}/manifest.json');
        expect(
          firstManifestFile.readAsBytesSync(),
          secondManifestFile.readAsBytesSync(),
        );
        final manifest = _readJson(firstManifestFile);
        expect(manifest['rendererId'], 'host-coretext-forensic');
        expect(manifest['diagnosticOnly'], isTrue);
        expect(
          manifest['fontSha256'],
          sha256.convert(privateFont.readAsBytesSync()).toString(),
        );
        expect(manifest['font'], containsPair('os2WeightClass', isA<int>()));
        expect(manifest['font'], containsPair('postScriptName', isNotEmpty));
        final renderedWeight =
            (manifest['font']! as Map<String, dynamic>)['os2WeightClass'];
        final renderedPostScriptName =
            (manifest['font']! as Map<String, dynamic>)['postScriptName'];
        expect(manifest['arrowPolicy'], <String, dynamic>{
          'specimen': '4637.05 → 4640.81',
          'delimiter': '→',
          'owner': 'deterministic-vector-shape',
          'fontFallbackAllowed': false,
        });
        final specimens = (manifest['specimens']! as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final coverageSpecimens = specimens
            .where((value) => value['purpose'] == 'exact-six-coverage')
            .toList();
        expect(
          coverageSpecimens.map((value) => value['text']).toList(),
          <String>[
            'Giá  Biểu đồ  Giao dịch  Lịch sử  Cài đặt',
            'Số dư:  Vốn:  Tiền ký quỹ:  Mức ký quỹ (%):',
            'XAUUSD buy 1',
            '4637.05 → 4640.81',
            '376.00  -341.00  103 310.00  203.24',
            'L:  H:  M1  Orders  Deals',
          ],
        );
        expect(coverageSpecimens, hasLength(6));
        final roleComparisons = <String, Map<String, dynamic>>{
          for (final value in specimens.where(
            (specimen) => specimen['purpose'] == 'role-comparison',
          ))
            value['comparisonId']! as String: value,
        };
        expect(roleComparisons.keys, <String>{
          'numeric-price-open',
          'numeric-price-close',
          'trade-profit-positive',
          'trade-profit-negative',
          'trade-balance-value',
          'trade-margin-level-value',
        });
        for (final expected in <Map<String, Object>>[
          <String, Object>{
            'id': 'numeric-price-open',
            'pointSize': 16,
            'width': 112,
            'height': 35,
            'baseline': 30,
            'text': '4637.05',
            'letterSpacing': .98,
            'sourceWeight': 400,
            'layout': 'leading',
            'anchor': 7,
            'sourceCrop': <String, dynamic>{
              'left': 1,
              'top': 401,
              'width': 99,
              'height': 35,
            },
            'padding': <String, dynamic>{
              'left': 0,
              'top': 0,
              'right': 13,
              'bottom': 0,
            },
            'boundaryPolicy': 'leadingBeforeArrowJpegNoise',
          },
          <String, Object>{
            'id': 'numeric-price-close',
            'pointSize': 16,
            'width': 112,
            'height': 35,
            'baseline': 30,
            'text': '4640.81',
            'letterSpacing': .98,
            'sourceWeight': 400,
            'layout': 'leading',
            'anchor': 5,
            'sourceCrop': <String, dynamic>{
              'left': 123,
              'top': 401,
              'width': 107,
              'height': 35,
            },
            'padding': <String, dynamic>{
              'left': 0,
              'top': 0,
              'right': 5,
              'bottom': 0,
            },
            'boundaryPolicy': 'directGuard',
          },
          <String, Object>{
            'id': 'trade-profit-positive',
            'pointSize': 21,
            'width': 115,
            'height': 46,
            'baseline': 34,
            'text': '376.00',
            'letterSpacing': .17,
            'sourceWeight': 550,
            'layout': 'trailing',
            'anchor': 107,
            'sourceCrop': <String, dynamic>{
              'left': 475,
              'top': 375,
              'width': 107,
              'height': 46,
            },
            'padding': <String, dynamic>{
              'left': 0,
              'top': 0,
              'right': 8,
              'bottom': 0,
            },
            'boundaryPolicy': 'trailingBeforeScrollbar',
          },
          <String, Object>{
            'id': 'trade-profit-negative',
            'pointSize': 21,
            'width': 136,
            'height': 42,
            'baseline': 30,
            'text': '-341.00',
            'letterSpacing': .17,
            'sourceWeight': 550,
            'layout': 'trailing',
            'anchor': 123,
            'sourceCrop': <String, dynamic>{
              'left': 467,
              'top': 857,
              'width': 115,
              'height': 42,
            },
            'padding': <String, dynamic>{
              'left': 8,
              'top': 0,
              'right': 13,
              'bottom': 0,
            },
            'boundaryPolicy': 'trailingBeforeScrollbar',
          },
          <String, Object>{
            'id': 'trade-balance-value',
            'pointSize': 16,
            'width': 140,
            'height': 40,
            'baseline': 29,
            'text': '103 310.00',
            'letterSpacing': .2,
            'sourceWeight': 450,
            'layout': 'trailing',
            'anchor': 134,
            'sourceCrop': <String, dynamic>{
              'left': 448,
              'top': 156,
              'width': 134,
              'height': 40,
            },
            'padding': <String, dynamic>{
              'left': 0,
              'top': 0,
              'right': 6,
              'bottom': 0,
            },
            'boundaryPolicy': 'trailingBeforeScrollbar',
          },
          <String, Object>{
            'id': 'trade-margin-level-value',
            'pointSize': 16,
            'width': 96,
            'height': 37,
            'baseline': 23,
            'text': '203.24',
            'letterSpacing': .2,
            'sourceWeight': 450,
            'layout': 'trailing',
            'anchor': 90,
            'sourceCrop': <String, dynamic>{
              'left': 492,
              'top': 291,
              'width': 90,
              'height': 37,
            },
            'padding': <String, dynamic>{
              'left': 0,
              'top': 0,
              'right': 6,
              'bottom': 0,
            },
            'boundaryPolicy': 'trailingBeforeScrollbar',
          },
        ]) {
          final specimen = roleComparisons[expected['id']]!;
          expect(specimen['pointSize'], expected['pointSize']);
          expect(specimen['physicalWidth'], expected['width']);
          expect(specimen['physicalHeight'], expected['height']);
          expect(specimen['width'], expected['width']);
          expect(specimen['height'], expected['height']);
          expect(specimen['candidateBaseline'], expected['baseline']);
          expect(
            (specimen['metrics']! as Map<String, dynamic>)['baselinePx'],
            expected['baseline'],
          );
          expect(
            (specimen['metrics']! as Map<String, dynamic>)['baselineOrigin'],
            'top',
          );
          expect(specimen['baselineOrigin'], 'top');
          expect(specimen['text'], expected['text']);
          expect(specimen['letterSpacing'], expected['letterSpacing']);
          expect(specimen['sourceNominalWeight'], expected['sourceWeight']);
          expect(specimen['horizontalLayout'], expected['layout']);
          expect(specimen['candidateAnchorX'], expected['anchor']);
          expect(specimen['tabularFigures'], isTrue);
          expect(specimen['fontFeatures'], <dynamic>['tnum']);
          expect(specimen['devicePixelRatio'], 1.5);
          expect(specimen['textScale'], 1.0);
          expect(specimen['locale'], 'vi-VN');
          expect(specimen['vectorPolicy'], 'none');
          expect(specimen['crossRendererComparable'], isTrue);
          expect(specimen['scored'], isTrue);
          expect(specimen['sourceClass'], 'jpegCrop');
          expect(specimen['referenceFile'], 'references/${expected['id']}.png');
          expect(
            specimen['sourceSha256'],
            '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
          );
          expect(specimen['sourceFile'], 'references/trade-light.jpg');
          final referenceFile = File(
            '${first.path}/${specimen['referenceFile']}',
          );
          expect(
            specimen['referenceSha256'],
            sha256.convert(referenceFile.readAsBytesSync()).toString(),
          );
          expect(specimen['sourceCrop'], expected['sourceCrop']);
          final transform =
              specimen['referenceTransform']! as Map<String, dynamic>;
          expect(transform['kind'], 'whitePaddingNoResample');
          expect(transform['boundaryPolicy'], expected['boundaryPolicy']);
          expect(transform['sourceCrop'], expected['sourceCrop']);
          expect(transform['padding'], expected['padding']);
          if (expected['boundaryPolicy'] == 'trailingBeforeScrollbar') {
            expect(transform['sourceRightExclusiveBoundaryX'], 582);
            expect(transform['coordinateSpace'], 'sourceImagePhysicalPixels');
            expect(transform['exclusive'], isTrue);
          } else if (expected['boundaryPolicy'] ==
              'leadingBeforeArrowJpegNoise') {
            expect(transform['sourceRightExclusiveBoundaryX'], 100);
            expect(transform['coordinateSpace'], 'sourceImagePhysicalPixels');
            expect(transform['exclusive'], isTrue);
            expect(transform['lastStrongInkX'], 90);
            expect(transform['blankGuardStartX'], 91);
            expect(transform['blankGuardWidth'], 9);
            expect(transform['excludedNeighborStartX'], 100);
            expect(transform['excludedNeighborKind'], 'vectorArrow');
          } else {
            expect(
              transform.containsKey('sourceRightExclusiveBoundaryX'),
              isFalse,
            );
          }
          final candidateCrop =
              specimen['candidateCrop']! as Map<String, dynamic>;
          expect(candidateCrop, <String, dynamic>{
            'left': 0,
            'top': 0,
            'width': expected['width'],
            'height': expected['height'],
          });
          expect(specimen['referenceCrop'], candidateCrop);
          final annotations = specimen['annotations']! as Map<String, dynamic>;
          expect(annotations['baseline'], <String, dynamic>{
            'referenceY': expected['baseline'],
            'candidateY': expected['baseline'],
          });
          expect(annotations['baselineOrigin'], 'top');
          expect(annotations['landmarks'], <dynamic>[
            <String, dynamic>{
              'id': 'horizontal-anchor',
              'reference': <String, dynamic>{
                'x': expected['anchor'],
                'y': expected['baseline'],
              },
              'candidate': <String, dynamic>{
                'x': expected['anchor'],
                'y': expected['baseline'],
              },
            },
          ]);
          expect(
            (specimen['font']! as Map<String, dynamic>)['weight'],
            renderedWeight,
          );
          expect(specimen['candidateId'], renderedPostScriptName);
        }
        final retainedReference = File(
          '${first.path}/references/trade-light.jpg',
        );
        expect(
          retainedReference.readAsBytesSync(),
          referenceSource.readAsBytesSync(),
        );
        expect(
          sha256.convert(retainedReference.readAsBytesSync()).toString(),
          '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
        );
        expect(specimens, hasLength(12));
        for (final specimen in specimens) {
          final relativePath = specimen['file']! as String;
          final rendered = File('${first.path}/$relativePath');
          final duplicate = File('${second.path}/$relativePath');
          expect(rendered.existsSync(), isTrue);
          expect(rendered.readAsBytesSync(), duplicate.readAsBytesSync());
          expect(
            sha256.convert(rendered.readAsBytesSync()).toString(),
            specimen['sha256'],
          );
          final decoded = image.decodePng(rendered.readAsBytesSync())!;
          expect(decoded.width, specimen['width']);
          expect(decoded.height, specimen['height']);
          for (final pixel in decoded) {
            expect(pixel.a.toInt(), 255, reason: relativePath);
          }
          if (specimen['purpose'] == 'role-comparison') {
            final bounds = _inkBounds(decoded);
            expect(bounds, isNotNull, reason: relativePath);
            expect(bounds!.$1, greaterThan(0), reason: '$relativePath left');
            expect(bounds.$2, greaterThan(0), reason: '$relativePath top');
            expect(
              bounds.$3,
              lessThan(decoded.width - 1),
              reason: '$relativePath right',
            );
            expect(
              bounds.$4,
              lessThan(decoded.height - 1),
              reason: '$relativePath bottom',
            );
          }
          if (specimen['id'] == 'numeric-price-arrow') {
            final center = decoded.width ~/ 2;
            final leftMass = _darknessMass(decoded, 0, center - 24);
            final rightMass = _darknessMass(
              decoded,
              center + 24,
              decoded.width,
            );
            expect(
              rightMass / leftMass,
              inInclusiveRange(0.75, 1.25),
              reason: 'right numeric run must be drawn exactly once',
            );
          }
        }
        expect(
          first
              .listSync(recursive: true)
              .whereType<File>()
              .any((file) => file.path.toLowerCase().endsWith('.ttf')),
          isFalse,
        );
        expect(
          firstManifestFile.readAsStringSync(),
          isNot(contains(privateFont.path)),
        );
        expect(firstManifestFile.readAsStringSync(), isNot(contains('.ttf')));

        final review = Directory('${root.path}/host-review');
        final scoreResult = await _runScorer(
          renderer: 'host-coretext-forensic',
          candidateDirectory: first,
          outputDirectory: review,
          diagnosticOnly: true,
        );
        expect(
          scoreResult.exitCode,
          0,
          reason: '${scoreResult.stdout}\n${scoreResult.stderr}',
        );
        final scoreReport = _readJson(File('${review.path}/report.json'));
        final scored = (scoreReport['measurements']! as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .where((value) => value['score'] != null)
            .toList();
        expect(scored, hasLength(6));
        for (final measurement in scored) {
          expect(
            (measurement['metrics']!
                as Map<String, dynamic>)['comparisonAvailable'],
            isTrue,
          );
          final overlay = File('${review.path}/${measurement['overlayFile']}');
          expect(
            measurement['overlaySha256'],
            sha256.convert(overlay.readAsBytesSync()).toString(),
          );
        }
        expect(scoreReport['proposedWinners'], isEmpty);
      },
    );
  });
}

Future<ProcessResult> _runScorer({
  required String renderer,
  required Directory candidateDirectory,
  required Directory outputDirectory,
  bool diagnosticOnly = false,
}) {
  return Process.run('dart', <String>[
    'run',
    _scorerPath,
    '--renderer',
    renderer,
    if (diagnosticOnly) '--diagnostic-only',
    '--candidate-dir',
    candidateDirectory.path,
    '--output-dir',
    outputDirectory.path,
  ]);
}

class _ScorerFixture {
  _ScorerFixture({
    required this.root,
    required this.candidates,
    required this.manifest,
    required this.manifestJson,
    required this.files,
  });

  final Directory root;
  final Directory candidates;
  final File manifest;
  final Map<String, dynamic> manifestJson;
  final List<File> files;

  static Future<_ScorerFixture> create({
    required String rendererId,
    String sourceClass = 'controlledSpecimen',
    bool includeReference = true,
    bool includeJpegAnnotations = true,
  }) async {
    final root = await Directory.systemTemp.createTemp('mt5-font-score-');
    final candidates = Directory('${root.path}/candidates')..createSync();
    final baseReference = _fixtureImage();
    final baseExact = _fixtureImage();
    final baseShifted = _fixtureImage(offset: 3, gray: 40);
    final reference = sourceClass == 'jpegCrop'
        ? _placeOnCanvas(baseReference, width: 100, height: 40, x: 10, y: 4)
        : baseReference;
    final exact = sourceClass == 'jpegCrop'
        ? _placeOnCanvas(baseExact, width: 90, height: 36, x: 5, y: 2)
        : baseExact;
    final shifted = sourceClass == 'jpegCrop'
        ? _placeOnCanvas(baseShifted, width: 90, height: 36, x: 5, y: 2)
        : baseShifted;
    final referenceFile =
        File(
          '${candidates.path}/${sourceClass == 'jpegCrop' ? 'reference.jpg' : 'reference.png'}',
        )..writeAsBytesSync(
          sourceClass == 'jpegCrop'
              ? image.encodeJpg(reference, quality: 82)
              : image.encodePng(reference),
        );
    final exactFile = File('${candidates.path}/exact.png')
      ..writeAsBytesSync(image.encodePng(exact));
    final shiftedFile = File('${candidates.path}/shifted.png')
      ..writeAsBytesSync(image.encodePng(shifted));
    final coverageFiles = <File>[
      if (rendererId == 'ios')
        File('${candidates.path}/coverage-exact.png')
          ..writeAsBytesSync(image.encodePng(_fixtureImage())),
      if (rendererId == 'ios')
        File('${candidates.path}/coverage-shifted.png')
          ..writeAsBytesSync(image.encodePng(_fixtureImage(offset: 2))),
    ];
    final entries = <Map<String, dynamic>>[
      for (final pair in <(String, File)>[
        ('exact', exactFile),
        ('shifted', shiftedFile),
      ])
        <String, dynamic>{
          'id': 'quote-large-${pair.$1}',
          'comparisonId': 'quote-large',
          'roleId': 'priceLarge',
          'candidateId': pair.$1,
          'text': '4637.05 → 4640.81',
          'file': pair.$2.uri.pathSegments.last,
          'sha256': sha256.convert(pair.$2.readAsBytesSync()).toString(),
          'sourceClass': sourceClass,
          'rendererId': rendererId,
          'scored': includeReference,
          'font': <String, dynamic>{
            'family': 'Fixture',
            'faceSha256': _repeat('a', 64),
            'weight': 400,
            'selectable': true,
          },
          'pointSize': 16,
          'sourceNominalWeight': 400,
          'physicalWidth': sourceClass == 'jpegCrop' ? 90 : 80,
          'physicalHeight': sourceClass == 'jpegCrop' ? 36 : 32,
          'candidateBaseline': 25,
          'baselineOrigin': 'top',
          'horizontalLayout': 'leading',
          'candidateAnchorX': 8,
          'letterSpacing': .98,
          'tabularFigures': true,
          'fontFeatures': <String>['tnum'],
          'devicePixelRatio': 1.5,
          'textScale': 1.0,
          'locale': 'vi-VN',
          'vectorPolicy': 'none',
          'crossRendererComparable': true,
          'parameterEvidence': <String, dynamic>{
            'provenance': 'currentAppHypothesis',
            'lockEligible': false,
            'scope': 'pointSize-letterSpacing-features-sourceNominalWeight',
          },
          if (rendererId == 'ios')
            'rasterEvidence': <String, dynamic>{
              'opaque': true,
              'grayscale': true,
              'debugPaintBaselinesEnabledAtCapture': false,
            },
          if (includeReference) ...<String, dynamic>{
            'referenceFile': referenceFile.uri.pathSegments.last,
            'referenceSha256': sha256
                .convert(referenceFile.readAsBytesSync())
                .toString(),
            'sourceFile': referenceFile.uri.pathSegments.last,
            'sourceSha256': sha256
                .convert(referenceFile.readAsBytesSync())
                .toString(),
            'referenceCrop': sourceClass == 'jpegCrop'
                ? <String, dynamic>{
                    'left': 10,
                    'top': 4,
                    'width': 80,
                    'height': 32,
                  }
                : <String, dynamic>{
                    'left': 0,
                    'top': 0,
                    'width': 80,
                    'height': 32,
                  },
            'sourceCrop': sourceClass == 'jpegCrop'
                ? <String, dynamic>{
                    'left': 10,
                    'top': 4,
                    'width': 80,
                    'height': 32,
                  }
                : <String, dynamic>{
                    'left': 0,
                    'top': 0,
                    'width': 80,
                    'height': 32,
                  },
            'candidateCrop': sourceClass == 'jpegCrop'
                ? <String, dynamic>{
                    'left': 5,
                    'top': 2,
                    'width': 80,
                    'height': 32,
                  }
                : <String, dynamic>{
                    'left': 0,
                    'top': 0,
                    'width': 80,
                    'height': 32,
                  },
            if (sourceClass != 'jpegCrop' || includeJpegAnnotations)
              'annotations': <String, dynamic>{
                'baselineOrigin': 'top',
                'baseline': <String, dynamic>{
                  'referenceY': 25,
                  'candidateY': 25,
                },
                'landmarks': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'run-left',
                    'reference': <String, dynamic>{'x': 8, 'y': 25},
                    'candidate': <String, dynamic>{'x': 8, 'y': 25},
                  },
                  <String, dynamic>{
                    'id': 'run-right',
                    'reference': <String, dynamic>{'x': 59, 'y': 25},
                    'candidate': <String, dynamic>{'x': 59, 'y': 25},
                  },
                ],
              },
          },
        },
    ];
    final manifestJson = <String, dynamic>{
      'schemaVersion': 1,
      'rendererId': rendererId,
      'diagnosticOnly': rendererId == 'host-coretext-forensic',
      'referenceRoleManifestSha256': _referenceRoleManifestSha256,
      'parameterPolicy': <String, dynamic>{
        'provenance': 'currentAppHypothesis',
        'lockEligible': false,
        'requiresRasterScoreForWinner': true,
      },
      if (rendererId == 'ios')
        'rasterContract': <String, dynamic>{
          'colorModel': 'opaqueGrayscale',
          'alpha': 255,
          'redEqualsGreenEqualsBlue': true,
          'debugPaintBaselinesEnabledAtCapture': false,
        },
      'fontSha256': _repeat('a', 64),
      'font': <String, dynamic>{
        'postScriptName': 'Fixture-Regular',
        'os2WeightClass': 400,
        'faceSha256': _repeat('a', 64),
      },
      'specimens': entries,
      if (rendererId == 'ios')
        'coverageSpecimens': <Map<String, dynamic>>[
          for (var index = 0; index < coverageFiles.length; index++)
            <String, dynamic>{
              'id': 'coverage-${index == 0 ? 'exact' : 'shifted'}',
              'candidateId': index == 0 ? 'exact' : 'shifted',
              'text': _coverageStrings.join('\n'),
              'strings': _coverageStrings,
              'file': coverageFiles[index].uri.pathSegments.last,
              'sha256': sha256
                  .convert(coverageFiles[index].readAsBytesSync())
                  .toString(),
              'physicalWidth': 80,
              'physicalHeight': 32,
              'devicePixelRatio': 1.5,
              'textScale': 1.0,
              'locale': 'vi-VN',
              'font': <String, dynamic>{
                'family': 'Fixture',
                'faceSha256': _repeat('a', 64),
                'weight': 400,
                'selectable': true,
              },
              'scored': false,
              'rasterEvidence': <String, dynamic>{
                'opaque': true,
                'grayscale': true,
                'debugPaintBaselinesEnabledAtCapture': false,
              },
            },
        ],
    };
    final manifest = File('${candidates.path}/manifest.json')
      ..writeAsStringSync(_prettyJson(manifestJson));
    return _ScorerFixture(
      root: root,
      candidates: candidates,
      manifest: manifest,
      manifestJson: manifestJson,
      files: <File>[
        referenceFile,
        exactFile,
        shiftedFile,
        ...coverageFiles,
        manifest,
      ],
    );
  }

  Map<String, String> get inputHashes => <String, String>{
    for (final file in files)
      file.uri.pathSegments.last: sha256
          .convert(file.readAsBytesSync())
          .toString(),
  };

  Future<void> dispose() => root.delete(recursive: true);
}

void _configureDerivedReference(
  _ScorerFixture fixture, {
  bool tamperDerived = false,
  bool seamInk = false,
  bool trailingScrollbarBoundary = false,
}) {
  final source = image.Image(width: 100, height: 50, numChannels: 4);
  image.fill(source, color: image.ColorRgba8(255, 255, 255, 255));
  final ink = image.ColorRgba8(0, 0, 0, 255);
  image.fillRect(source, x1: 18, y1: 13, x2: 27, y2: 26, color: ink);
  image.fillRect(source, x1: 35, y1: 13, x2: 44, y2: 26, color: ink);
  image.fillRect(source, x1: 52, y1: 13, x2: 60, y2: 18, color: ink);
  if (seamInk) source.setPixel(69, 20, ink);
  final jpegSource = trailingScrollbarBoundary;
  final sourceFile =
      File(
        '${fixture.candidates.path}/raw-source.${jpegSource ? 'jpg' : 'png'}',
      )..writeAsBytesSync(
        jpegSource
            ? image.encodeJpg(source, quality: 100)
            : image.encodePng(source),
      );
  final retainedSource = image.decodeImage(sourceFile.readAsBytesSync())!;
  final cropped = image.copyCrop(
    retainedSource,
    x: 10,
    y: 8,
    width: 60,
    height: 24,
  );
  final correctDerived = image.Image(width: 80, height: 32, numChannels: 4);
  image.fill(correctDerived, color: image.ColorRgba8(255, 255, 255, 255));
  image.compositeImage(
    correctDerived,
    cropped,
    dstX: 8,
    dstY: 4,
    blend: image.BlendMode.direct,
  );
  final reference = image.Image.from(correctDerived);
  if (tamperDerived) {
    reference.setPixelRgba(75, 16, 0, 0, 0, 255);
  }
  final referenceFile = File('${fixture.candidates.path}/derived-reference.png')
    ..writeAsBytesSync(image.encodePng(reference));
  final specimens = (fixture.manifestJson['specimens']! as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (var index = 0; index < specimens.length; index++) {
    final specimen = specimens[index];
    final candidate = File('${fixture.candidates.path}/${specimen['file']}');
    final candidateImage = index == 0
        ? correctDerived
        : _shiftImage(correctDerived, 2);
    candidate.writeAsBytesSync(image.encodePng(candidateImage));
    specimen['sha256'] = sha256.convert(candidate.readAsBytesSync()).toString();
    specimen['sourceClass'] = jpegSource ? 'jpegCrop' : 'lossless';
    specimen['horizontalLayout'] = trailingScrollbarBoundary
        ? 'trailing'
        : 'leading';
    specimen['candidateAnchorX'] = trailingScrollbarBoundary ? 68 : 8;
    specimen['annotations'] = <String, dynamic>{
      'baselineOrigin': 'top',
      'baseline': <String, dynamic>{'referenceY': 25, 'candidateY': 25},
      'landmarks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': trailingScrollbarBoundary ? 'trailing-anchor' : 'run-left',
          'reference': <String, dynamic>{
            'x': trailingScrollbarBoundary ? 68 : 8,
            'y': 25,
          },
          'candidate': <String, dynamic>{
            'x': trailingScrollbarBoundary ? 68 : 8,
            'y': 25,
          },
        },
      ],
    };
    specimen['referenceFile'] = referenceFile.uri.pathSegments.last;
    specimen['referenceSha256'] = sha256
        .convert(referenceFile.readAsBytesSync())
        .toString();
    specimen['referenceCrop'] = <String, dynamic>{
      'left': 0,
      'top': 0,
      'width': 80,
      'height': 32,
    };
    specimen['candidateCrop'] = <String, dynamic>{
      'left': 0,
      'top': 0,
      'width': 80,
      'height': 32,
    };
    specimen['sourceFile'] = sourceFile.uri.pathSegments.last;
    specimen['sourceSha256'] = sha256
        .convert(sourceFile.readAsBytesSync())
        .toString();
    specimen['sourceCrop'] = <String, dynamic>{
      'left': 10,
      'top': 8,
      'width': 60,
      'height': 24,
    };
    specimen['referenceTransform'] = <String, dynamic>{
      'kind': 'whitePaddingNoResample',
      'boundaryPolicy': trailingScrollbarBoundary
          ? 'trailingBeforeScrollbar'
          : 'directGuard',
      if (trailingScrollbarBoundary) ...<String, dynamic>{
        'sourceRightExclusiveBoundaryX': 70,
        'coordinateSpace': 'sourceImagePhysicalPixels',
        'exclusive': true,
      },
      'sourceFile': sourceFile.uri.pathSegments.last,
      'sourceSha256': specimen['sourceSha256'],
      'sourceCrop': specimen['sourceCrop'],
      'padding': <String, dynamic>{
        'left': 8,
        'top': 4,
        'right': 12,
        'bottom': 4,
      },
    };
  }
  fixture.files.addAll(<File>[sourceFile, referenceFile]);
  fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
}

void _configureTrailingScrollbarReference(
  _ScorerFixture fixture,
  String comparisonId, {
  bool inkFinalGuardColumn = false,
}) {
  final contract = _trailingFixtureContracts[comparisonId];
  if (contract == null) {
    throw ArgumentError.value(comparisonId, 'comparisonId');
  }
  final lockedSource = File('../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg');
  final sourceImage = image.decodeImage(lockedSource.readAsBytesSync())!;
  if (inkFinalGuardColumn) {
    sourceImage.setPixelRgba(
      581,
      contract.sourceTop + contract.height ~/ 2,
      0,
      0,
      0,
      255,
    );
  }
  final sourceFile = File('${fixture.candidates.path}/raw-source.jpg')
    ..writeAsBytesSync(
      inkFinalGuardColumn
          ? image.encodeJpg(sourceImage, quality: 100)
          : lockedSource.readAsBytesSync(),
    );
  final sourceSha = sha256.convert(sourceFile.readAsBytesSync()).toString();
  if (!inkFinalGuardColumn && sourceSha != _lockedTradeReferenceSha256) {
    throw StateError('locked trade fixture source SHA changed');
  }
  final retainedSource = image.decodeImage(sourceFile.readAsBytesSync())!;
  final cropped = image.copyCrop(
    retainedSource,
    x: contract.sourceLeft,
    y: contract.sourceTop,
    width: contract.sourceWidth,
    height: contract.height,
  );
  final reference = image.Image(
    width: contract.width,
    height: contract.height,
    numChannels: 4,
  );
  image.fill(reference, color: image.ColorRgba8(255, 255, 255, 255));
  image.compositeImage(
    reference,
    cropped,
    dstX: contract.paddingLeft,
    blend: image.BlendMode.direct,
  );
  final referenceFile = File('${fixture.candidates.path}/derived-reference.png')
    ..writeAsBytesSync(image.encodePng(reference));
  final referenceSha = sha256
      .convert(referenceFile.readAsBytesSync())
      .toString();

  image.Image candidateImage(int offset) {
    final value = image.Image(
      width: contract.width,
      height: contract.height,
      numChannels: 4,
    );
    image.fill(value, color: image.ColorRgba8(255, 255, 255, 255));
    final ink = image.ColorRgba8(0, 0, 0, 255);
    final top = 7;
    final bottom = contract.height - 8;
    final start = 14 + offset;
    image.fillRect(
      value,
      x1: start,
      y1: top,
      x2: start + 9,
      y2: bottom,
      color: ink,
    );
    image.fillRect(
      value,
      x1: start + 18,
      y1: top,
      x2: start + 27,
      y2: bottom,
      color: ink,
    );
    image.fillRect(
      value,
      x1: start + 36,
      y1: top,
      x2: start + 49,
      y2: top + 5,
      color: ink,
    );
    image.fillRect(
      value,
      x1: start + 42,
      y1: top + 5,
      x2: start + 45,
      y2: bottom,
      color: ink,
    );
    return value;
  }

  final specimens = (fixture.manifestJson['specimens']! as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (var index = 0; index < specimens.length; index++) {
    final specimen = specimens[index];
    final candidate = File('${fixture.candidates.path}/${specimen['file']}')
      ..writeAsBytesSync(image.encodePng(candidateImage(index * 2)));
    specimen
      ..['id'] = '$comparisonId-${index == 0 ? 'exact' : 'shifted'}'
      ..['comparisonId'] = comparisonId
      ..['roleId'] = contract.roleId
      ..['text'] = contract.text
      ..['sha256'] = sha256.convert(candidate.readAsBytesSync()).toString()
      ..['sourceClass'] = 'jpegCrop'
      ..['pointSize'] = contract.pointSize
      ..['sourceNominalWeight'] = contract.sourceNominalWeight
      ..['physicalWidth'] = contract.width
      ..['physicalHeight'] = contract.height
      ..['candidateBaseline'] = contract.baseline
      ..['baselineOrigin'] = 'top'
      ..['horizontalLayout'] = 'trailing'
      ..['candidateAnchorX'] = contract.anchor
      ..['letterSpacing'] = contract.letterSpacing
      ..['tabularFigures'] = true
      ..['fontFeatures'] = <String>['tnum']
      ..['devicePixelRatio'] = 1.5
      ..['textScale'] = 1.0
      ..['locale'] = 'vi-VN'
      ..['vectorPolicy'] = 'none'
      ..['referenceFile'] = referenceFile.uri.pathSegments.last
      ..['referenceSha256'] = referenceSha
      ..['referenceCrop'] = <String, dynamic>{
        'left': 0,
        'top': 0,
        'width': contract.width,
        'height': contract.height,
      }
      ..['candidateCrop'] = <String, dynamic>{
        'left': 0,
        'top': 0,
        'width': contract.width,
        'height': contract.height,
      }
      ..['sourceFile'] = sourceFile.uri.pathSegments.last
      ..['sourceSha256'] = sourceSha
      ..['sourceCrop'] = <String, dynamic>{
        'left': contract.sourceLeft,
        'top': contract.sourceTop,
        'width': contract.sourceWidth,
        'height': contract.height,
      }
      ..['referenceTransform'] = <String, dynamic>{
        'kind': 'whitePaddingNoResample',
        'boundaryPolicy': 'trailingBeforeScrollbar',
        'sourceRightExclusiveBoundaryX': 582,
        'coordinateSpace': 'sourceImagePhysicalPixels',
        'exclusive': true,
        'sourceFile': sourceFile.uri.pathSegments.last,
        'sourceSha256': sourceSha,
        'sourceCrop': <String, dynamic>{
          'left': contract.sourceLeft,
          'top': contract.sourceTop,
          'width': contract.sourceWidth,
          'height': contract.height,
        },
        'padding': <String, dynamic>{
          'left': contract.paddingLeft,
          'top': 0,
          'right': contract.paddingRight,
          'bottom': 0,
        },
      }
      ..['annotations'] = <String, dynamic>{
        'baselineOrigin': 'top',
        'baseline': <String, dynamic>{
          'referenceY': contract.baseline,
          'candidateY': contract.baseline,
        },
        'landmarks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'horizontal-anchor',
            'reference': <String, dynamic>{
              'x': contract.anchor,
              'y': contract.baseline,
            },
            'candidate': <String, dynamic>{
              'x': contract.anchor,
              'y': contract.baseline,
            },
          },
        ],
      };
  }
  fixture.files.addAll(<File>[sourceFile, referenceFile]);
  fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
}

void _configureTradeSymbolBoundaryReference(
  _ScorerFixture fixture, {
  bool inkGuardColumn = false,
  bool eraseNeighbor = false,
}) {
  final lockedSource = File('../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg');
  final sourceImage = image.decodeImage(lockedSource.readAsBytesSync())!;
  if (inkGuardColumn) {
    image.fillRect(
      sourceImage,
      x1: 81,
      y1: 369,
      x2: 81,
      y2: 403,
      color: image.ColorRgba8(0, 0, 0, 255),
    );
  }
  if (eraseNeighbor) {
    image.fillRect(
      sourceImage,
      x1: 82,
      y1: 360,
      x2: 115,
      y2: 415,
      color: image.ColorRgba8(255, 255, 255, 255),
    );
  }
  final sourceFile = File('${fixture.candidates.path}/raw-source.jpg')
    ..writeAsBytesSync(
      inkGuardColumn || eraseNeighbor
          ? image.encodeJpg(sourceImage, quality: 100)
          : lockedSource.readAsBytesSync(),
    );
  final sourceSha = sha256.convert(sourceFile.readAsBytesSync()).toString();
  if (!inkGuardColumn &&
      !eraseNeighbor &&
      sourceSha != _lockedTradeReferenceSha256) {
    throw StateError('locked trade fixture source SHA changed');
  }
  final retainedSource = image.decodeImage(sourceFile.readAsBytesSync())!;
  final cropped = image.copyCrop(
    retainedSource,
    x: 3,
    y: 369,
    width: 79,
    height: 35,
  );
  final reference = image.Image(width: 93, height: 39, numChannels: 4);
  image.fill(reference, color: image.ColorRgba8(255, 255, 255, 255));
  image.compositeImage(reference, cropped, blend: image.BlendMode.direct);
  final referenceFile = File('${fixture.candidates.path}/derived-reference.png')
    ..writeAsBytesSync(image.encodePng(reference));
  final referenceSha = sha256
      .convert(referenceFile.readAsBytesSync())
      .toString();

  image.Image candidateImage(int offset) {
    final value = image.Image(width: 93, height: 39, numChannels: 4);
    image.fill(value, color: image.ColorRgba8(255, 255, 255, 255));
    final ink = image.ColorRgba8(0, 0, 0, 255);
    image.fillRect(
      value,
      x1: 10 + offset,
      y1: 7,
      x2: 20 + offset,
      y2: 29,
      color: ink,
    );
    image.fillRect(
      value,
      x1: 29 + offset,
      y1: 7,
      x2: 39 + offset,
      y2: 29,
      color: ink,
    );
    image.fillRect(
      value,
      x1: 48 + offset,
      y1: 7,
      x2: 63 + offset,
      y2: 13,
      color: ink,
    );
    return value;
  }

  final specimens = (fixture.manifestJson['specimens']! as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (var index = 0; index < specimens.length; index++) {
    final specimen = specimens[index];
    final candidate = File('${fixture.candidates.path}/${specimen['file']}')
      ..writeAsBytesSync(image.encodePng(candidateImage(index * 2)));
    specimen
      ..['id'] = 'trade-position-symbol-${index == 0 ? 'exact' : 'shifted'}'
      ..['comparisonId'] = 'trade-position-symbol'
      ..['roleId'] = 'tradePositionSymbol'
      ..['text'] = 'XAUUSD'
      ..['sha256'] = sha256.convert(candidate.readAsBytesSync()).toString()
      ..['sourceClass'] = 'jpegCrop'
      ..['pointSize'] = 15.3
      ..['sourceNominalWeight'] = 300
      ..['physicalWidth'] = 93
      ..['physicalHeight'] = 39
      ..['candidateBaseline'] = 29
      ..['baselineOrigin'] = 'top'
      ..['horizontalLayout'] = 'leading'
      ..['candidateAnchorX'] = 4
      ..['letterSpacing'] = -.6
      ..['tabularFigures'] = false
      ..['fontFeatures'] = <String>[]
      ..['devicePixelRatio'] = 1.5
      ..['textScale'] = 1.0
      ..['locale'] = 'vi-VN'
      ..['vectorPolicy'] = 'none'
      ..['referenceFile'] = referenceFile.uri.pathSegments.last
      ..['referenceSha256'] = referenceSha
      ..['referenceCrop'] = <String, dynamic>{
        'left': 0,
        'top': 0,
        'width': 93,
        'height': 39,
      }
      ..['candidateCrop'] = <String, dynamic>{
        'left': 0,
        'top': 0,
        'width': 93,
        'height': 39,
      }
      ..['sourceFile'] = sourceFile.uri.pathSegments.last
      ..['sourceSha256'] = sourceSha
      ..['sourceCrop'] = <String, dynamic>{
        'left': 3,
        'top': 369,
        'width': 79,
        'height': 35,
      }
      ..['referenceTransform'] = <String, dynamic>{
        'kind': 'whitePaddingNoResample',
        'boundaryPolicy': 'trailingBeforeAdjacentColoredTextJpegNoise',
        'sourceRightExclusiveBoundaryX': 82,
        'coordinateSpace': 'sourceImagePhysicalPixels',
        'exclusive': true,
        'lastStrongInkX': 80,
        'blankGuardStartX': 81,
        'blankGuardWidth': 1,
        'excludedNeighborStartX': 82,
        'excludedNeighborKind': 'tradePositionSideVolume',
        'sourceFile': sourceFile.uri.pathSegments.last,
        'sourceSha256': sourceSha,
        'sourceCrop': <String, dynamic>{
          'left': 3,
          'top': 369,
          'width': 79,
          'height': 35,
        },
        'padding': <String, dynamic>{
          'left': 0,
          'top': 0,
          'right': 14,
          'bottom': 4,
        },
      }
      ..['annotations'] = <String, dynamic>{
        'baselineOrigin': 'top',
        'baseline': <String, dynamic>{'referenceY': 29, 'candidateY': 29},
        'landmarks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'horizontal-anchor',
            'reference': <String, dynamic>{'x': 4, 'y': 29},
            'candidate': <String, dynamic>{'x': 4, 'y': 29},
          },
        ],
      };
  }
  fixture.files.addAll(<File>[sourceFile, referenceFile]);
  fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
}

void _configureLeadingArrowReference(_ScorerFixture fixture) {
  final lockedSource = File('../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg');
  final sourceFile = File('${fixture.candidates.path}/raw-source.jpg')
    ..writeAsBytesSync(lockedSource.readAsBytesSync());
  final source = image.decodeImage(sourceFile.readAsBytesSync())!;
  final cropped = image.copyCrop(source, x: 1, y: 401, width: 99, height: 35);
  final reference = image.Image(width: 112, height: 35, numChannels: 4);
  image.fill(reference, color: image.ColorRgba8(255, 255, 255, 255));
  image.compositeImage(reference, cropped, blend: image.BlendMode.direct);
  final referenceFile = File('${fixture.candidates.path}/derived-reference.png')
    ..writeAsBytesSync(image.encodePng(reference));
  final baseCandidate = image.Image(width: 112, height: 35, numChannels: 4);
  image.fill(baseCandidate, color: image.ColorRgba8(255, 255, 255, 255));
  final ink = image.ColorRgba8(0, 0, 0, 255);
  image.fillRect(baseCandidate, x1: 10, y1: 8, x2: 21, y2: 24, color: ink);
  image.fillRect(baseCandidate, x1: 30, y1: 8, x2: 41, y2: 24, color: ink);
  image.fillRect(baseCandidate, x1: 50, y1: 8, x2: 61, y2: 24, color: ink);

  final specimens = (fixture.manifestJson['specimens']! as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (var index = 0; index < specimens.length; index++) {
    final specimen = specimens[index];
    final candidate = File('${fixture.candidates.path}/${specimen['file']}');
    candidate.writeAsBytesSync(
      image.encodePng(
        index == 0 ? baseCandidate : _shiftImage(baseCandidate, 2),
      ),
    );
    specimen
      ..['id'] = 'numeric-price-open-${index == 0 ? 'exact' : 'shifted'}'
      ..['comparisonId'] = 'numeric-price-open'
      ..['roleId'] = 'tradePositionSecondary'
      ..['text'] = '4637.05'
      ..['sha256'] = sha256.convert(candidate.readAsBytesSync()).toString()
      ..['sourceClass'] = 'jpegCrop'
      ..['pointSize'] = 16
      ..['sourceNominalWeight'] = 400
      ..['physicalWidth'] = 112
      ..['physicalHeight'] = 35
      ..['candidateBaseline'] = 30
      ..['baselineOrigin'] = 'top'
      ..['horizontalLayout'] = 'leading'
      ..['candidateAnchorX'] = 7
      ..['letterSpacing'] = .98
      ..['tabularFigures'] = true
      ..['fontFeatures'] = <String>['tnum']
      ..['devicePixelRatio'] = 1.5
      ..['textScale'] = 1.0
      ..['locale'] = 'vi-VN'
      ..['vectorPolicy'] = 'none'
      ..['referenceFile'] = referenceFile.uri.pathSegments.last
      ..['referenceSha256'] = sha256
          .convert(referenceFile.readAsBytesSync())
          .toString()
      ..['referenceCrop'] = <String, dynamic>{
        'left': 0,
        'top': 0,
        'width': 112,
        'height': 35,
      }
      ..['candidateCrop'] = <String, dynamic>{
        'left': 0,
        'top': 0,
        'width': 112,
        'height': 35,
      }
      ..['sourceFile'] = sourceFile.uri.pathSegments.last
      ..['sourceSha256'] = sha256
          .convert(sourceFile.readAsBytesSync())
          .toString()
      ..['sourceCrop'] = <String, dynamic>{
        'left': 1,
        'top': 401,
        'width': 99,
        'height': 35,
      }
      ..['referenceTransform'] = <String, dynamic>{
        'kind': 'whitePaddingNoResample',
        'boundaryPolicy': 'leadingBeforeArrowJpegNoise',
        'sourceRightExclusiveBoundaryX': 100,
        'coordinateSpace': 'sourceImagePhysicalPixels',
        'exclusive': true,
        'lastStrongInkX': 90,
        'blankGuardStartX': 91,
        'blankGuardWidth': 9,
        'excludedNeighborStartX': 100,
        'excludedNeighborKind': 'vectorArrow',
        'sourceFile': sourceFile.uri.pathSegments.last,
        'sourceSha256': sha256.convert(sourceFile.readAsBytesSync()).toString(),
        'sourceCrop': <String, dynamic>{
          'left': 1,
          'top': 401,
          'width': 99,
          'height': 35,
        },
        'padding': <String, dynamic>{
          'left': 0,
          'top': 0,
          'right': 13,
          'bottom': 0,
        },
      }
      ..['annotations'] = <String, dynamic>{
        'baselineOrigin': 'top',
        'baseline': <String, dynamic>{'referenceY': 30, 'candidateY': 30},
        'landmarks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'horizontal-anchor',
            'reference': <String, dynamic>{'x': 7, 'y': 30},
            'candidate': <String, dynamic>{'x': 7, 'y': 30},
          },
        ],
      };
  }
  fixture.files.addAll(<File>[sourceFile, referenceFile]);
  fixture.manifest.writeAsStringSync(_prettyJson(fixture.manifestJson));
}

image.Image _shiftImage(image.Image source, int offsetX) {
  final result = image.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  image.fill(result, color: image.ColorRgba8(255, 255, 255, 255));
  image.compositeImage(result, source, dstX: offsetX);
  return result;
}

image.Image _fixtureImage({int offset = 0, int gray = 0}) {
  final result = image.Image(width: 80, height: 32, numChannels: 4);
  image.fill(result, color: image.ColorRgba8(255, 255, 255, 255));
  final ink = image.ColorRgba8(gray, gray, gray, 255);
  image.fillRect(
    result,
    x1: 8 + offset,
    y1: 7,
    x2: 17 + offset,
    y2: 25,
    color: ink,
  );
  image.fillRect(
    result,
    x1: 25 + offset,
    y1: 7,
    x2: 34 + offset,
    y2: 25,
    color: ink,
  );
  image.fillRect(
    result,
    x1: 42 + offset,
    y1: 7,
    x2: 59 + offset,
    y2: 11,
    color: ink,
  );
  image.fillRect(
    result,
    x1: 50 + offset,
    y1: 11,
    x2: 53 + offset,
    y2: 25,
    color: ink,
  );
  return result;
}

image.Image _placeOnCanvas(
  image.Image source, {
  required int width,
  required int height,
  required int x,
  required int y,
}) {
  final result = image.Image(width: width, height: height, numChannels: 4);
  image.fill(result, color: image.ColorRgba8(255, 255, 255, 255));
  image.compositeImage(result, source, dstX: x, dstY: y);
  return result;
}

double _darknessMass(image.Image value, int startX, int endX) {
  var result = 0.0;
  for (var y = 0; y < value.height; y++) {
    for (var x = startX; x < endX; x++) {
      final pixel = value.getPixel(x, y);
      result += 255 - (pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3;
    }
  }
  return result;
}

(int, int, int, int)? _inkBounds(image.Image value) {
  var minX = value.width;
  var minY = value.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < value.height; y++) {
    for (var x = 0; x < value.width; x++) {
      final pixel = value.getPixel(x, y);
      final darkness =
          255 - (pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3;
      if (darkness <= 12) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  return maxX < 0 ? null : (minX, minY, maxX, maxY);
}

Map<String, dynamic> _readJson(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

String _prettyJson(Object value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

String _repeat(String value, int count) =>
    List<String>.filled(count, value).join();
