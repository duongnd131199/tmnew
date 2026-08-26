import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../tool/compare_tab_typography.dart' as comparator;
import 'test_support/tab_reference_manifest.dart';

const _canvas = ReferencePixelRect(0, 0, 64, 64);
const _textSearch = ReferencePixelRect(8, 8, 28, 24);

void main() {
  test('synthetic known-equal reference and candidate succeed', () async {
    final reference = _blankImage();
    _fillRect(reference, 12, 12, 16, 10, 0, 0, 0);

    final result = await _runFixture(
      reference: reference,
      candidate: image.Image.from(reference),
      referenceCase: _fixtureCase(
        staticTextRegions: const [
          StaticTextRegion(
            name: 'label',
            referenceRect: _textSearch,
            candidateRect: _textSearch,
            ink: referencePrimaryInk,
          ),
        ],
      ),
    );

    expect(result.exitCode, 0, reason: result.diagnostics);
  });

  test('rejects an alpha-only candidate mutation before comparison', () async {
    final reference = _blankImage();
    _fillRect(reference, 12, 12, 16, 10, 0, 0, 0);
    final candidate = image.Image.from(reference);
    candidate.setPixelRgba(14, 14, 0, 0, 0, 0);

    final result = await _runFixture(
      reference: reference,
      candidate: candidate,
      referenceCase: _fixtureCase(
        staticTextRegions: const [
          StaticTextRegion(
            name: 'alpha-label',
            referenceRect: _textSearch,
            candidateRect: _textSearch,
            ink: referencePrimaryInk,
          ),
        ],
      ),
    );

    expect(result.exitCode, 2, reason: result.diagnostics);
    expect(result.diagnostics, contains('fixture candidate'));
    expect(result.diagnostics, contains('candidate/fixture-590x1280.png'));
    expect(result.diagnostics, contains('fully opaque'));
    expect(result.diagnostics, contains('(14,14)'));
    expect(result.diagnostics, contains('alpha 0'));
  });

  test(
    'preflight rejects a later alpha error without partial evidence',
    () async {
      final firstReference = _blankImage();
      final secondReference = _blankImage();
      final secondCandidate = image.Image.from(secondReference);
      secondCandidate.setPixelRgba(31, 27, 255, 255, 255, 0);
      final root = await Directory.systemTemp.createTemp(
        'mt5-preflight-output-',
      );
      addTearDown(() => root.delete(recursive: true));
      final outputDirectory = Directory('${root.path}/evidence');

      final result = await _runFixtures(
        fixtures: [
          _FixtureInput(
            reference: firstReference,
            candidate: image.Image.from(firstReference),
            referenceCase: _fixtureCase(id: 'first', fileName: 'first.png'),
          ),
          _FixtureInput(
            reference: secondReference,
            candidate: secondCandidate,
            referenceCase: _fixtureCase(id: 'second', fileName: 'second.png'),
          ),
        ],
        outputDirectory: outputDirectory,
      );

      expect(result.exitCode, 2, reason: result.diagnostics);
      expect(result.diagnostics, contains('second candidate'));
      expect(result.diagnostics, contains('(31,27)'));
      expect(result.diagnostics, contains('alpha 0'));
      expect(
        outputDirectory.existsSync(),
        isFalse,
        reason: 'Preflight failures must not create partial evidence.',
      );
    },
  );

  test(
    'Trade keeps the reference header area left of profit visually blank',
    () {
      final reference = image.decodeJpg(
        File(
          '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
        ).readAsBytesSync(),
      )!;
      final candidate = image.decodePng(
        File(
          'test/goldens/tab-typography/trade-590x1280.png',
        ).readAsBytesSync(),
      )!;

      int nonWhitePixels(image.Image source) {
        var count = 0;
        for (var y = 75; y < 155; y++) {
          for (var x = 15; x < 100; x++) {
            final pixel = source.getPixel(x, y);
            if (pixel.r < 223 || pixel.g < 223 || pixel.b < 223) count++;
          }
        }
        return count;
      }

      final referenceInk = nonWhitePixels(reference);
      final candidateInk = nonWhitePixels(candidate);
      expect(
        candidateInk,
        lessThanOrEqualTo(referenceInk + 25),
        reason: 'reference=$referenceInk candidate=$candidateInk',
      );
    },
  );

  test(
    'rejects candidate ink matching manifest hint but not measured reference',
    () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillRect(reference, 12, 12, 16, 10, 24, 24, 24);
      _fillRect(candidate, 12, 12, 16, 10, 0, 0, 0);

      for (final renderer in <String?>[null, 'android']) {
        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          renderer: renderer,
          referenceCase: _fixtureCase(
            staticTextRegions: const [
              StaticTextRegion(
                name: 'measured-color-label',
                referenceRect: _textSearch,
                candidateRect: _textSearch,
                ink: referencePrimaryInk,
                measureInkDensity: false,
              ),
            ],
          ),
        );

        expect(
          result.exitCode,
          1,
          reason: '${renderer ?? 'deterministic'}\n${result.diagnostics}',
        );
        expect(result.diagnostics, contains('manifestInkHint'));
        expect(result.diagnostics, contains('measuredReferenceInk'));
        expect(result.diagnostics, contains('candidateInk'));
        expect(result.diagnostics, contains('rgb(24,24,24)'));
        expect(result.diagnostics, contains('semantic RGB delta 24 exceeds 4'));
      }
    },
  );

  test('rejects optical density drift above five percent', () async {
    final reference = _densityImage(interiorChannel: 100);
    final candidate = _densityImage(interiorChannel: 80);

    for (final renderer in <String?>[null, 'android']) {
      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        renderer: renderer,
        referenceCase: _fixtureCase(
          staticTextRegions: const [
            StaticTextRegion(
              name: 'density-label',
              referenceRect: _textSearch,
              candidateRect: _textSearch,
              ink: referencePrimaryInk,
            ),
          ],
        ),
      );

      expect(
        result.exitCode,
        1,
        reason: '${renderer ?? 'deterministic'}\n${result.diagnostics}',
      );
      expect(result.diagnostics, contains('inkDensityDeltaPercent'));
      expect(
        result.diagnostics,
        contains('ink density delta 6.7% exceeds 5.0%'),
      );
    }
  });

  test(
    'measureInkDensity false cannot waive density above five percent',
    () async {
      final reference = _largeDensityImage(interiorChannel: 100);
      final candidate = _largeDensityImage(interiorChannel: 88);

      for (final renderer in <String?>[null, 'android']) {
        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          renderer: renderer,
          referenceCase: _fixtureCase(
            staticTextRegions: const [
              StaticTextRegion(
                name: 'formerly-density-exempt-label',
                referenceRect: _textSearch,
                candidateRect: _textSearch,
                ink: referencePrimaryInk,
                measureInkDensity: false,
              ),
            ],
          ),
        );

        expect(
          result.exitCode,
          1,
          reason: '${renderer ?? 'deterministic'}\n${result.diagnostics}',
        );
        expect(result.diagnostics, contains('inkDensityDeltaPercent'));
        expect(
          result.diagnostics,
          contains('ink density delta 5.4% exceeds 5.0%'),
        );
      }
    },
  );

  test('rejects a two-physical-pixel text edge shift', () async {
    final reference = _blankImage();
    final candidate = _blankImage();
    _fillRect(reference, 12, 12, 14, 10, 0, 0, 0);
    _fillRect(candidate, 14, 12, 14, 10, 0, 0, 0);

    for (final renderer in <String?>[null, 'android']) {
      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        renderer: renderer,
        referenceCase: _fixtureCase(
          staticTextRegions: const [
            StaticTextRegion(
              name: 'shifted-label',
              referenceRect: _textSearch,
              candidateRect: _textSearch,
              ink: referencePrimaryInk,
            ),
          ],
        ),
      );

      expect(
        result.exitCode,
        1,
        reason: '${renderer ?? 'deterministic'}\n${result.diagnostics}',
      );
      expect(result.diagnostics, contains('edgeDelta'));
      expect(
        result.diagnostics,
        contains('edge delta 2 exceeds 1 physical px'),
      );
    }
  });

  test('rejects a static control mutation outside text regions', () async {
    final reference = _blankImage();
    final candidate = image.Image.from(reference);
    _fillRect(candidate, 42, 42, 10, 10, 0, 0, 0);

    final result = await _runFixture(
      reference: reference,
      candidate: candidate,
      referenceCase: _fixtureCase(
        staticControlRegions: const [
          ReferenceStaticControlRegion(
            name: 'static-control',
            rect: ReferencePixelRect(40, 40, 16, 16),
          ),
        ],
      ),
    );

    expect(result.exitCode, 1, reason: result.diagnostics);
    expect(result.diagnostics, contains('static-control'));
    expect(result.diagnostics, contains('differingPixelCount'));
    expect(result.diagnostics, contains('100 pixels differ'));
  });

  test('rejects a dynamic mask intersecting required static control', () async {
    final reference = _blankImage();

    final result = await _runFixture(
      reference: reference,
      candidate: image.Image.from(reference),
      referenceCase: _fixtureCase(
        staticControlRegions: const [
          ReferenceStaticControlRegion(
            name: 'required-control',
            rect: ReferencePixelRect(40, 40, 16, 16),
          ),
        ],
        dynamicMaskRegions: const [
          ReferenceDynamicMask(
            kind: ReferenceDynamicMaskKind.livePrices,
            rect: ReferencePixelRect(42, 42, 4, 4),
            reason: 'Synthetic live value.',
          ),
        ],
      ),
    );

    expect(result.exitCode, 2, reason: result.diagnostics);
    expect(result.diagnostics, contains('required-control'));
    expect(result.diagnostics, contains('intersects'));
  });

  test('rejects a dynamic mask with an empty reason', () async {
    final reference = _blankImage();

    final result = await _runFixture(
      reference: reference,
      candidate: image.Image.from(reference),
      referenceCase: _fixtureCase(
        dynamicMaskRegions: const [
          ReferenceDynamicMask(
            kind: ReferenceDynamicMaskKind.livePrices,
            rect: ReferencePixelRect(42, 42, 4, 4),
            reason: '   ',
          ),
        ],
      ),
    );

    expect(result.exitCode, 2, reason: result.diagnostics);
    expect(result.diagnostics, contains('non-empty reason'));
  });

  test('rejects a dynamic mask outside the audit canvas', () async {
    final reference = _blankImage();

    final result = await _runFixture(
      reference: reference,
      candidate: image.Image.from(reference),
      referenceCase: _fixtureCase(
        dynamicMaskRegions: const [
          ReferenceDynamicMask(
            kind: ReferenceDynamicMaskKind.livePrices,
            rect: ReferencePixelRect(62, 62, 4, 4),
            reason: 'Synthetic out-of-bounds value.',
          ),
        ],
      ),
    );

    expect(result.exitCode, 2, reason: result.diagnostics);
    expect(result.diagnostics, contains('outside static audit canvas'));
  });

  test('rejects a dynamic mask inside a static text glyph', () async {
    final reference = _blankImage();
    _fillRect(reference, 12, 12, 16, 10, 0, 0, 0);

    final result = await _runFixture(
      reference: reference,
      candidate: image.Image.from(reference),
      referenceCase: _fixtureCase(
        staticTextRegions: const [
          StaticTextRegion(
            name: 'required-static-label',
            referenceRect: _textSearch,
            candidateRect: _textSearch,
            ink: referencePrimaryInk,
          ),
        ],
        dynamicMaskRegions: const [
          ReferenceDynamicMask(
            kind: ReferenceDynamicMaskKind.livePrices,
            rect: ReferencePixelRect(16, 15, 2, 2),
            reason: 'Synthetic live value inside a static glyph.',
          ),
        ],
      ),
    );

    expect(result.exitCode, 2, reason: result.diagnostics);
    expect(result.diagnostics, contains('required-static-label'));
    expect(result.diagnostics, contains('intersects static text'));
  });

  test(
    'explicit dynamic text opt-in permits its mask and still compares',
    () async {
      final reference = _blankImage();
      _fillRect(reference, 12, 12, 16, 10, 0, 0, 0);

      final result = await _runFixture(
        reference: reference,
        candidate: image.Image.from(reference),
        referenceCase: _fixtureCase(
          staticTextRegions: const [
            StaticTextRegion(
              name: 'live-value-label',
              referenceRect: _textSearch,
              candidateRect: _textSearch,
              ink: referencePrimaryInk,
              allowsDynamicMask: true,
            ),
          ],
          dynamicMaskRegions: const [
            ReferenceDynamicMask(
              kind: ReferenceDynamicMaskKind.livePrices,
              rect: ReferencePixelRect(16, 15, 2, 2),
              reason: 'Synthetic explicitly allowed live text value.',
            ),
          ],
        ),
      );

      expect(result.exitCode, 0, reason: result.diagnostics);
      expect(result.diagnostics, contains('live-value-label'));
      expect(result.diagnostics, contains('PASS'));
    },
  );

  test('rejects unsafe or empty manifest paths before input IO', () async {
    final cases = <(TabReferenceCase, String)>[
      (_fixtureCase(id: ''), 'case id must be non-empty'),
      (_fixtureCase(id: '../escape'), 'unsafe case id'),
      (_fixtureCase(id: r'escape\case'), 'unsafe case id'),
      (_fixtureCase(fileName: ''), 'fileName must be non-empty'),
      (_fixtureCase(fileName: '../escape.png'), 'unsafe fileName'),
      (_fixtureCase(fileName: r'escape\reference.png'), 'unsafe fileName'),
      (_fixtureCase(fileName: 'escape..png'), 'unsafe fileName'),
      (_fixtureCase(fileName: '.'), 'unsafe fileName'),
      (_fixtureCase(fileName: 'C:escape.png'), 'unsafe fileName'),
    ];

    for (final entry in cases) {
      final result = await _runManifestWithoutInputs([entry.$1]);
      expect(result.exitCode, 2, reason: result.diagnostics);
      expect(result.diagnostics, contains(entry.$2));
      expect(result.diagnostics, isNot(contains('Missing comparison input')));
    }
  });

  test('rejects duplicate case ids before input IO', () async {
    final result = await _runManifestWithoutInputs([
      _fixtureCase(id: 'duplicate', fileName: 'first.png'),
      _fixtureCase(id: 'duplicate', fileName: 'second.png'),
    ]);

    expect(result.exitCode, 2, reason: result.diagnostics);
    expect(result.diagnostics, contains('duplicate case id "duplicate"'));
    expect(result.diagnostics, isNot(contains('Missing comparison input')));
  });

  test('unsafe case id cannot escape the artifact output directory', () async {
    final evidenceRoot = await Directory.systemTemp.createTemp(
      'mt5-comparator-path-evidence-',
    );
    addTearDown(() => evidenceRoot.delete(recursive: true));
    final outputDirectory = Directory('${evidenceRoot.path}/output')
      ..createSync();
    final escapedArtifact = File(
      '${evidenceRoot.path}/artifact-escape-overlay-50-50.png',
    );
    final reference = _blankImage();

    final result = await _runFixture(
      reference: reference,
      candidate: image.Image.from(reference),
      outputDirectory: outputDirectory,
      referenceCase: _fixtureCase(id: '../artifact-escape'),
    );

    expect(result.exitCode, 2, reason: result.diagnostics);
    expect(result.diagnostics, contains('unsafe case id'));
    expect(escapedArtifact.existsSync(), isFalse);
  });

  test('output directory contains machine CSV overlay and heatmap', () async {
    final outputDirectory = await Directory.systemTemp.createTemp(
      'mt5-comparator-evidence-',
    );
    addTearDown(() => outputDirectory.delete(recursive: true));
    final reference = _blankImage();
    _fillRect(reference, 12, 12, 16, 10, 0, 0, 0);
    reference.setPixelRgba(1, 1, 10, 20, 30, 255);
    reference.setPixelRgba(50, 50, 10, 30, 50, 255);
    final candidate = image.Image.from(reference);
    candidate.setPixelRgba(1, 1, 30, 40, 50, 255);
    candidate.setPixelRgba(50, 50, 110, 130, 150, 255);

    final result = await _runFixture(
      reference: reference,
      candidate: candidate,
      outputDirectory: outputDirectory,
      referenceCase: _fixtureCase(
        visualRegionName: 'fixture,"quoted"\nregion',
        staticTextRegions: const [
          StaticTextRegion(
            name: 'label',
            referenceRect: _textSearch,
            candidateRect: _textSearch,
            ink: referencePrimaryInk,
          ),
        ],
        dynamicMaskRegions: const [
          ReferenceDynamicMask(
            kind: ReferenceDynamicMaskKind.livePrices,
            rect: ReferencePixelRect(50, 50, 1, 1),
            reason: 'Synthetic masked artifact pixel.',
          ),
        ],
      ),
    );

    expect(result.exitCode, 0, reason: result.diagnostics);
    final csv = File('${outputDirectory.path}/comparison.csv');
    expect(csv.existsSync(), isTrue);
    final csvContents = csv.readAsStringSync();
    expect(csvContents, startsWith('recordType,candidateRenderer'));
    expect(csvContents.split('\n').first.split(',').length, 19);
    expect(csvContents, contains('"fixture,""quoted""\nregion"'));

    final overlayFile = File(
      '${outputDirectory.path}/fixture-overlay-50-50.png',
    );
    final heatmapFile = File('${outputDirectory.path}/fixture-heatmap.png');
    final overlay = image.decodePng(overlayFile.readAsBytesSync())!;
    final heatmap = image.decodePng(heatmapFile.readAsBytesSync())!;
    expect((overlay.width, overlay.height), (64, 64));
    expect((heatmap.width, heatmap.height), (64, 64));
    expect(_rgba(overlay.getPixel(1, 1)), (20, 30, 40, 255));
    expect(_rgba(heatmap.getPixel(1, 1)), (20, 0, 0, 255));
    expect(_rgba(overlay.getPixel(50, 50)), (60, 80, 100, 255));
    expect(_rgba(heatmap.getPixel(50, 50)), (0, 0, 0, 0));
  });

  test('CLI keeps default legacy and order-independent forms', () async {
    final reference = _blankImage();
    final candidate = image.Image.from(reference);
    final forms = <List<String> Function(String)>[
      (directory) => ['--candidate-dir', directory],
      (directory) => [
        '--candidate-dir',
        directory,
        '--candidate-renderer',
        'android',
      ],
      (directory) => [
        '--candidate-renderer',
        'android',
        '--candidate-dir',
        directory,
      ],
      (directory) => [
        '--candidate-renderer',
        'deterministic',
        '--candidate-dir',
        directory,
      ],
    ];

    for (final form in forms) {
      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(),
        arguments: form,
      );
      expect(result.exitCode, 0, reason: result.diagnostics);
    }
  });

  test('CLI returns usage exit 2 for malformed arguments', () async {
    final cases = <(List<String>, String)>[
      (['--unknown'], 'Unknown argument'),
      (['--candidate-dir'], 'Missing value for --candidate-dir'),
      (
        ['--candidate-dir', 'one', '--candidate-dir', 'two'],
        'may only be supplied once',
      ),
      (['--candidate-renderer', 'skia'], 'Unsupported candidate renderer'),
      (['--output-dir', '--candidate-dir', 'value'], 'Missing value'),
    ];

    for (final entry in cases) {
      final result = _runArguments(entry.$1);
      expect(result.exitCode, 2, reason: result.diagnostics);
      expect(result.diagnostics, contains(entry.$2));
      expect(result.diagnostics, contains('Usage:'));
    }
  });

  test('default CLI reports current real candidate mismatches', () {
    final output = StringBuffer();
    final errors = StringBuffer();
    final exitCode = comparator.runTabTypographyComparison(
      const [],
      standardOutput: output,
      errorOutput: errors,
    );

    expect(exitCode, 1, reason: '$output$errors');
    expect('$output$errors', contains('Reference parity failed'));
  });
}

TabReferenceCase _fixtureCase({
  String id = 'fixture',
  String fileName = 'fixture.png',
  String visualRegionName = 'fixture-canvas',
  List<StaticTextRegion> staticTextRegions = const [],
  List<ReferenceStaticControlRegion> staticControlRegions = const [],
  List<ReferenceDynamicMask> dynamicMaskRegions = const [],
}) => TabReferenceCase(
  id: id,
  fileName: fileName,
  state: TabReferenceState.prices,
  route: '/fixture',
  selectedTab: ReferenceSelectedTab.prices,
  captureState: const ReferenceCaptureState(
    description: 'Synthetic deterministic comparator fixture.',
    scrollState: ReferenceScrollState.atTop,
  ),
  staticAuditRegion: _canvas,
  visualRegions: [
    ReferenceVisualRegion(
      name: visualRegionName,
      type: ReferenceVisualRegionType.body,
      rect: _canvas,
    ),
  ],
  staticControlRegions: staticControlRegions,
  staticTextRegions: staticTextRegions,
  dynamicMaskRegions: dynamicMaskRegions,
);

image.Image _blankImage() {
  final result = image.Image(width: 64, height: 64, numChannels: 4);
  _fillRect(result, 0, 0, 64, 64, 255, 255, 255);
  return result;
}

image.Image _densityImage({required int interiorChannel}) {
  final result = _blankImage();
  _fillRect(result, 12, 12, 10, 10, 0, 0, 0);
  _fillRect(
    result,
    13,
    13,
    8,
    8,
    interiorChannel,
    interiorChannel,
    interiorChannel,
  );
  return result;
}

image.Image _largeDensityImage({required int interiorChannel}) {
  final result = _blankImage();
  _fillRect(result, 10, 10, 18, 18, 0, 0, 0);
  _fillRect(
    result,
    11,
    11,
    16,
    16,
    interiorChannel,
    interiorChannel,
    interiorChannel,
  );
  return result;
}

void _fillRect(
  image.Image target,
  int left,
  int top,
  int width,
  int height,
  int red,
  int green,
  int blue,
) {
  for (var y = top; y < top + height; y++) {
    for (var x = left; x < left + width; x++) {
      target.setPixelRgba(x, y, red, green, blue, 255);
    }
  }
}

Future<_RunResult> _runFixture({
  required image.Image reference,
  required image.Image candidate,
  required TabReferenceCase referenceCase,
  String? renderer,
  Directory? outputDirectory,
  List<String> Function(String candidateDirectory)? arguments,
}) => _runFixtures(
  fixtures: [
    _FixtureInput(
      reference: reference,
      candidate: candidate,
      referenceCase: referenceCase,
    ),
  ],
  renderer: renderer,
  outputDirectory: outputDirectory,
  arguments: arguments,
);

Future<_RunResult> _runFixtures({
  required List<_FixtureInput> fixtures,
  String? renderer,
  Directory? outputDirectory,
  List<String> Function(String candidateDirectory)? arguments,
}) async {
  final root = await Directory.systemTemp.createTemp('mt5-comparator-');
  addTearDown(() => root.delete(recursive: true));
  final referenceDirectory = Directory('${root.path}/reference')..createSync();
  final candidateDirectory = Directory('${root.path}/candidate')..createSync();
  for (final fixture in fixtures) {
    File(
      '${referenceDirectory.path}/${fixture.referenceCase.fileName}',
    ).writeAsBytesSync(image.encodePng(fixture.reference));
    File(
      '${candidateDirectory.path}/'
      '${fixture.referenceCase.id}-590x1280.png',
    ).writeAsBytesSync(image.encodePng(fixture.candidate));
  }

  final output = StringBuffer();
  final errors = StringBuffer();
  final args =
      arguments?.call(candidateDirectory.path) ??
      <String>[
        if (outputDirectory != null) ...['--output-dir', outputDirectory.path],
        '--candidate-dir',
        candidateDirectory.path,
      ];
  if (renderer != null) {
    args.addAll(['--candidate-renderer', renderer]);
  }
  final exitCode = comparator.runTabTypographyComparison(
    args,
    standardOutput: output,
    errorOutput: errors,
    referenceCases: fixtures.map((fixture) => fixture.referenceCase).toList(),
    referenceDirectory: referenceDirectory.path,
  );
  return _RunResult(exitCode, '$output$errors');
}

Future<_RunResult> _runManifestWithoutInputs(
  List<TabReferenceCase> referenceCases,
) async {
  final root = await Directory.systemTemp.createTemp('mt5-manifest-only-');
  addTearDown(() => root.delete(recursive: true));
  final output = StringBuffer();
  final errors = StringBuffer();
  final exitCode = comparator.runTabTypographyComparison(
    ['--candidate-dir', '${root.path}/candidate'],
    standardOutput: output,
    errorOutput: errors,
    referenceCases: referenceCases,
    referenceDirectory: '${root.path}/reference',
  );
  return _RunResult(exitCode, '$output$errors');
}

_RunResult _runArguments(List<String> arguments) {
  final output = StringBuffer();
  final errors = StringBuffer();
  final exitCode = comparator.runTabTypographyComparison(
    arguments,
    standardOutput: output,
    errorOutput: errors,
    referenceCases: const [],
  );
  return _RunResult(exitCode, '$output$errors');
}

(int, int, int, int) _rgba(image.Pixel pixel) =>
    (pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), pixel.a.toInt());

class _RunResult {
  const _RunResult(this.exitCode, this.diagnostics);

  final int exitCode;
  final String diagnostics;
}

class _FixtureInput {
  const _FixtureInput({
    required this.reference,
    required this.candidate,
    required this.referenceCase,
  });

  final image.Image reference;
  final image.Image candidate;
  final TabReferenceCase referenceCase;
}
