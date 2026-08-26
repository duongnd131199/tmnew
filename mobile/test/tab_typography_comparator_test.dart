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

  test('output directory contains machine CSV overlay and heatmap', () async {
    final outputDirectory = await Directory.systemTemp.createTemp(
      'mt5-comparator-evidence-',
    );
    addTearDown(() => outputDirectory.delete(recursive: true));
    final reference = _blankImage();
    _fillRect(reference, 12, 12, 16, 10, 0, 0, 0);

    final result = await _runFixture(
      reference: reference,
      candidate: image.Image.from(reference),
      outputDirectory: outputDirectory,
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
    final csv = File('${outputDirectory.path}/comparison.csv');
    expect(csv.existsSync(), isTrue);
    expect(csv.readAsStringSync(), startsWith('recordType,candidateRenderer'));
    expect(csv.readAsStringSync(), contains('static-region'));
    for (final name in const [
      'fixture-overlay-50-50.png',
      'fixture-heatmap.png',
    ]) {
      final artifact = File('${outputDirectory.path}/$name');
      expect(artifact.existsSync(), isTrue, reason: artifact.path);
      final decoded = image.decodePng(artifact.readAsBytesSync());
      expect(decoded, isNotNull, reason: artifact.path);
      expect((decoded!.width, decoded.height), (64, 64));
    }
  });
}

TabReferenceCase _fixtureCase({
  List<StaticTextRegion> staticTextRegions = const [],
  List<ReferenceStaticControlRegion> staticControlRegions = const [],
  List<ReferenceDynamicMask> dynamicMaskRegions = const [],
}) => TabReferenceCase(
  id: 'fixture',
  fileName: 'fixture.png',
  state: TabReferenceState.prices,
  route: '/fixture',
  selectedTab: ReferenceSelectedTab.prices,
  captureState: const ReferenceCaptureState(
    description: 'Synthetic deterministic comparator fixture.',
    scrollState: ReferenceScrollState.atTop,
  ),
  staticAuditRegion: _canvas,
  visualRegions: const [
    ReferenceVisualRegion(
      name: 'fixture-canvas',
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
}) async {
  final root = await Directory.systemTemp.createTemp('mt5-comparator-');
  addTearDown(() => root.delete(recursive: true));
  final referenceDirectory = Directory('${root.path}/reference')..createSync();
  final candidateDirectory = Directory('${root.path}/candidate')..createSync();
  File(
    '${referenceDirectory.path}/${referenceCase.fileName}',
  ).writeAsBytesSync(image.encodePng(reference));
  File(
    '${candidateDirectory.path}/${referenceCase.id}-590x1280.png',
  ).writeAsBytesSync(image.encodePng(candidate));

  final output = StringBuffer();
  final errors = StringBuffer();
  final args = <String>[
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
    referenceCases: [referenceCase],
    referenceDirectory: referenceDirectory.path,
  );
  return _RunResult(exitCode, '$output$errors');
}

class _RunResult {
  const _RunResult(this.exitCode, this.diagnostics);

  final int exitCode;
  final String diagnostics;
}
