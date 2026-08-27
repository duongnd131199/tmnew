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

  test('rejects a partial mask for dynamic-only text', () async {
    final source = _blankImage();
    _fillRect(source, 12, 12, 16, 10, 0, 0, 0);

    final result = await _runFixture(
      reference: source,
      candidate: image.Image.from(source),
      referenceCase: _fixtureCase(
        staticTextRegions: const [
          StaticTextRegion(
            name: 'live-price',
            referenceRect: _textSearch,
            candidateRect: _textSearch,
            ink: referencePrimaryInk,
            auditMode: StaticTextAuditMode.dynamicOnly,
          ),
        ],
        dynamicMaskRegions: const [
          ReferenceDynamicMask(
            kind: ReferenceDynamicMaskKind.livePrices,
            rect: ReferencePixelRect(12, 12, 1, 1),
            reason: 'Synthetic live price.',
          ),
        ],
      ),
    );

    expect(result.exitCode, 2, reason: result.diagnostics);
    expect(result.diagnostics, contains('must be fully covered'));
  });

  test(
    'rejects a mask when only the reference text rectangle is contained',
    () async {
      final source = _blankImage();
      _fillRect(source, 12, 12, 16, 10, 0, 0, 0);
      const candidateRect = ReferencePixelRect(8, 8, 30, 24);

      final result = await _runFixture(
        reference: source,
        candidate: image.Image.from(source),
        referenceCase: _fixtureCase(
          staticTextRegions: const [
            StaticTextRegion(
              name: 'live-price',
              referenceRect: _textSearch,
              candidateRect: candidateRect,
              ink: referencePrimaryInk,
              auditMode: StaticTextAuditMode.dynamicOnly,
            ),
          ],
          dynamicMaskRegions: const [
            ReferenceDynamicMask(
              kind: ReferenceDynamicMaskKind.livePrices,
              rect: _textSearch,
              reason: 'Synthetic live price.',
            ),
          ],
        ),
      );

      expect(result.exitCode, 2, reason: result.diagnostics);
      expect(result.diagnostics, contains('must be fully covered'));
    },
  );

  test(
    'reports SKIP when one mask fully covers both dynamic-only rectangles',
    () async {
      final source = _blankImage();
      _fillRect(source, 12, 12, 16, 10, 0, 0, 0);
      const candidateRect = ReferencePixelRect(10, 10, 24, 22);

      final result = await _runFixture(
        reference: source,
        candidate: image.Image.from(source),
        referenceCase: _fixtureCase(
          staticTextRegions: const [
            StaticTextRegion(
              name: 'live-price',
              referenceRect: _textSearch,
              candidateRect: candidateRect,
              ink: referencePrimaryInk,
              auditMode: StaticTextAuditMode.dynamicOnly,
            ),
          ],
          dynamicMaskRegions: const [
            ReferenceDynamicMask(
              kind: ReferenceDynamicMaskKind.livePrices,
              rect: ReferencePixelRect(8, 8, 28, 24),
              reason: 'Synthetic live price.',
            ),
          ],
        ),
      );

      expect(result.exitCode, 0, reason: result.diagnostics);
      expect(result.diagnostics, contains(',SKIP,'));
      expect(result.diagnostics, contains('Synthetic live price.'));
    },
  );

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

  for (final mutation in <(int, int)>[(4, 0), (5, 1), (12, 1)]) {
    test(
      'static foreground RGB ${mutation.$1} has exit ${mutation.$2}',
      () async {
        final reference = _blankImage();
        _fillRect(reference, 20, 20, 10, 10, 0, 0, 0);
        final candidate = _blankImage();
        _fillRect(
          candidate,
          20,
          20,
          10,
          10,
          mutation.$1,
          mutation.$1,
          mutation.$1,
        );
        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _fixtureCase(
            staticControlRegions: const [
              ReferenceStaticControlRegion(name: 'ink-control', rect: _canvas),
            ],
          ),
        );
        expect(result.exitCode, mutation.$2, reason: result.diagnostics);
      },
    );
  }

  for (final candidateChannel in [105, 110]) {
    test('rejects flat static surface drift to $candidateChannel', () async {
      final reference = _solidImage(100);
      final result = await _runFixture(
        reference: reference,
        candidate: _solidImage(candidateChannel),
        referenceCase: _fixtureCase(),
      );

      final delta = candidateChannel - 100;
      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(result.diagnostics, contains('rgb(100,100,100)'));
      expect(
        result.diagnostics,
        contains('rgb($candidateChannel,$candidateChannel,$candidateChannel)'),
      );
      expect(
        result.diagnostics,
        contains('surface RGB delta $delta exceeds 4/channel'),
      );
      expect(result.diagnostics, contains(',0,4096,0.000000,FAIL,'));
    });
  }

  test('static feature bounds allow one pixel but reject two', () async {
    final reference = _blankImage();
    _fillRect(reference, 20, 20, 3, 3, 0, 0, 0);
    final candidates = <(int, int)>[(0, 0), (1, 0), (2, 1)];

    for (final entry in candidates) {
      final candidate = _blankImage();
      _fillRect(candidate, 20 + entry.$1, 20, 3, 3, 0, 0, 0);
      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(
          staticControlRegions: const [
            ReferenceStaticControlRegion(
              name: 'small-feature-control',
              rect: _canvas,
            ),
          ],
        ),
      );

      expect(result.exitCode, entry.$2, reason: result.diagnostics);
      expect(result.diagnostics, contains('small-feature-control'));
      expect(result.diagnostics, contains('edgeDelta'));
      if (entry.$1 == 2) {
        expect(result.diagnostics, contains('feature edge delta 2 exceeds 1'));
      }
    }
  });

  test('rejects a one-sided static foreground feature', () async {
    final reference = _solidImage(200);
    final candidate = image.Image.from(reference);
    _fillRect(candidate, 20, 20, 2, 2, 0, 0, 0);

    final result = await _runFixture(
      reference: reference,
      candidate: candidate,
      referenceCase: _fixtureCase(
        staticControlRegions: const [
          ReferenceStaticControlRegion(
            name: 'one-sided-feature-control',
            rect: _canvas,
          ),
        ],
      ),
    );

    expect(result.exitCode, 1, reason: result.diagnostics);
    expect(result.diagnostics, contains('one-sided-feature-control'));
    expect(result.diagnostics, contains('foreground exists on only one side'));
  });

  test('known-equal decoded JPEG raster passes static estimators', () async {
    final source = _solidImage(220);
    _fillRect(source, 10, 10, 20, 12, 35, 35, 35);
    _fillRect(source, 40, 30, 8, 18, 120, 120, 120);
    final decodedReference = image.decodeJpg(
      image.encodeJpg(source, quality: 72),
    )!;

    final result = await _runFixture(
      reference: decodedReference,
      candidate: image.Image.from(decodedReference),
      referenceCase: _fixtureCase(),
    );

    expect(result.exitCode, 0, reason: result.diagnostics);
    expect(result.diagnostics, isNot(contains(',FAIL,')));
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

  test('fully masked dynamic-only text is reported as SKIP', () async {
    final reference = _blankImage();
    _fillRect(reference, 12, 12, 16, 10, 0, 0, 0);

    final result = await _runFixture(
      reference: reference,
      candidate: image.Image.from(reference),
      referenceCase: _fixtureCase(
        staticTextRegions: const [
          StaticTextRegion(
            name: 'live-price',
            referenceRect: ReferencePixelRect(12, 12, 16, 10),
            candidateRect: ReferencePixelRect(12, 12, 16, 10),
            ink: referencePrimaryInk,
            auditMode: StaticTextAuditMode.dynamicOnly,
          ),
        ],
        dynamicMaskRegions: const [
          ReferenceDynamicMask(
            kind: ReferenceDynamicMaskKind.livePrices,
            rect: ReferencePixelRect(12, 12, 16, 10),
            reason: 'Synthetic quote is supplied by the live market feed.',
          ),
        ],
      ),
    );

    expect(result.exitCode, 0, reason: result.diagnostics);
    expect(result.diagnostics, contains('live-price'));
    expect(result.diagnostics, contains(',SKIP,'));
    expect(result.diagnostics, contains('supplied by the live market feed'));
    expect(result.diagnostics, isNot(contains('measurement failed')));
    final skipRow = result.diagnostics
        .split('\n')
        .singleWhere(
          (row) => row.startsWith(
            'text,deterministic,fixture,dynamicText,live-price,',
          ),
        );
    expect(_csvColumnCount(skipRow), 22);
  });

  test('mixed live value keeps its static suffix strictly audited', () async {
    final reference = _blankImage();
    _fillRect(reference, 10, 12, 10, 10, 0, 0, 0);
    _fillRect(reference, 30, 12, 10, 10, 0, 0, 0);
    const valueSearch = ReferencePixelRect(10, 12, 10, 10);
    const suffixSearch = ReferencePixelRect(26, 8, 20, 24);
    final referenceCase = _fixtureCase(
      staticTextRegions: const [
        StaticTextRegion(
          name: 'live-number',
          referenceRect: valueSearch,
          candidateRect: valueSearch,
          ink: referencePrimaryInk,
          auditMode: StaticTextAuditMode.dynamicOnly,
        ),
        StaticTextRegion(
          name: 'currency-suffix',
          referenceRect: suffixSearch,
          candidateRect: suffixSearch,
          ink: referencePrimaryInk,
        ),
      ],
      dynamicMaskRegions: const [
        ReferenceDynamicMask(
          kind: ReferenceDynamicMaskKind.liveProfitAndLoss,
          rect: ReferencePixelRect(10, 12, 10, 10),
          reason: 'Synthetic P/L numeric value changes with live quotes.',
        ),
      ],
    );

    final exact = await _runFixture(
      reference: reference,
      candidate: image.Image.from(reference),
      referenceCase: referenceCase,
    );
    expect(exact.exitCode, 0, reason: exact.diagnostics);
    expect(exact.diagnostics, contains('live-number'));
    expect(exact.diagnostics, contains(',SKIP,'));
    expect(exact.diagnostics, contains('currency-suffix'));
    expect(exact.diagnostics, contains(',PASS,'));

    final recoloredSuffix = image.Image.from(reference);
    _fillRect(recoloredSuffix, 30, 12, 10, 10, 8, 8, 8);
    final recolored = await _runFixture(
      reference: reference,
      candidate: recoloredSuffix,
      referenceCase: referenceCase,
    );
    expect(recolored.exitCode, 1, reason: recolored.diagnostics);
    expect(recolored.diagnostics, contains('currency-suffix'));
    expect(recolored.diagnostics, contains('semantic RGB delta 8 exceeds 4'));

    final shiftedSuffix = image.Image.from(reference);
    _fillRect(shiftedSuffix, 30, 12, 10, 10, 255, 255, 255);
    _fillRect(shiftedSuffix, 32, 12, 10, 10, 0, 0, 0);
    final shifted = await _runFixture(
      reference: reference,
      candidate: shiftedSuffix,
      referenceCase: referenceCase,
    );
    expect(shifted.exitCode, 1, reason: shifted.diagnostics);
    expect(shifted.diagnostics, contains('currency-suffix'));
    expect(shifted.diagnostics, contains('edge delta 2 exceeds 1'));
  });

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
    expect(csvContents.split('\n').first.split(',').length, 22);
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

  test('CLI --case emits only the requested case and its artifacts', () async {
    final root = await Directory.systemTemp.createTemp('mt5-case-filter-');
    addTearDown(() => root.delete(recursive: true));
    final outputDirectory = Directory('${root.path}/evidence');
    final source = _blankImage();
    final result = await _runFixtures(
      fixtures: [
        _FixtureInput(
          reference: source,
          candidate: image.Image.from(source),
          referenceCase: _fixtureCase(id: 'selected', fileName: 'selected.png'),
        ),
        _FixtureInput(
          reference: source,
          candidate: image.Image.from(source),
          referenceCase: _fixtureCase(
            id: 'unselected',
            fileName: 'unselected.png',
          ),
        ),
      ],
      arguments: (candidateDirectory) => [
        '--candidate-dir',
        candidateDirectory,
        '--case',
        'selected',
        '--output-dir',
        outputDirectory.path,
      ],
    );

    expect(result.exitCode, 0, reason: result.diagnostics);
    expect(result.diagnostics, contains(',selected,'));
    expect(result.diagnostics, isNot(contains(',unselected,')));
    expect(
      File('${outputDirectory.path}/selected-overlay-50-50.png').existsSync(),
      isTrue,
    );
    expect(
      File('${outputDirectory.path}/selected-heatmap.png').existsSync(),
      isTrue,
    );
    expect(
      File('${outputDirectory.path}/unselected-overlay-50-50.png').existsSync(),
      isFalse,
    );
    expect(
      File('${outputDirectory.path}/unselected-heatmap.png').existsSync(),
      isFalse,
    );
  });

  test('CLI --case rejects an unknown case before input preflight', () {
    final result = _runArguments(const ['--case', 'unknown']);

    expect(result.exitCode, 2, reason: result.diagnostics);
    expect(
      result.diagnostics,
      contains('Unknown reference parity case: unknown'),
    );
    expect(result.diagnostics, isNot(contains('Missing comparison input')));
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

  test('canonical atomic deferral preserves immutable strict evidence', () {
    final root = Directory.systemTemp.createTempSync(
      'mt5-atomic-deferred-evidence-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final output = StringBuffer();
    final errors = StringBuffer();
    final exitCode = comparator.runTabTypographyComparison(
      ['--output-dir', root.path],
      standardOutput: output,
      errorOutput: errors,
    );

    expect(exitCode, 1, reason: '$output$errors');
    final rows = _parseCsv(output.toString());
    final header = rows.first;
    final regionIndex = header.indexOf('region');
    final statusIndex = header.indexOf('status');
    final detailsIndex = header.indexOf('details');
    final atomicRows = rows
        .skip(1)
        .where(
          (row) =>
              row[regionIndex].startsWith('navigation-') &&
              (row[regionIndex].endsWith('-icon') ||
                  row[regionIndex].endsWith('-label')),
        )
        .toList(growable: false);
    expect(atomicRows, hasLength(70));
    expect(
      atomicRows.where((row) => row[statusIndex] == 'PASS'),
      hasLength(10),
    );
    final deferred = atomicRows
        .where((row) => row[statusIndex] == 'FAIL')
        .toList(growable: false);
    expect(deferred, hasLength(60));
    expect(deferred.map((row) => row[detailsIndex]).toSet(), {
      'reference-evidence-deferred: lossless shared navigation source '
          'required; restore in Task 7',
    });
    expect(tabReferenceForegroundConsensusGroups, hasLength(18));
    expect(
      tabReferenceForegroundConsensusGroups.fold<int>(
        0,
        (sum, group) => sum + group.memberCaseIds.length,
      ),
      70,
    );
    expect(
      tabReferenceCases.map((item) => item.referenceSha256).toSet(),
      hasLength(7),
    );

    final evidence = File(
      '${root.path}/atomic-deferred-evidence.csv',
    ).readAsStringSync();
    expect(_fnv1a64(evidence), '-fe9fe9695ab2bc3');
    expect(_fnv1a64(_atomicNumericEvidence(evidence)), '050c4c5ec79384e9');
    final evidenceRows = _parseCsv(evidence);
    expect(evidenceRows, hasLength(71));
    expect(
      evidenceRows.skip(1).where((row) => row[statusIndex] == 'PASS'),
      hasLength(10),
    );
    expect(
      evidenceRows.skip(1).where((row) => row[statusIndex] == 'FAIL'),
      hasLength(60),
    );

    final surfaceEvidence = File(
      '${root.path}/surface-deferred-evidence.csv',
    ).readAsStringSync();
    final surfaceRows = _parseCsv(surfaceEvidence);
    expect(surfaceRows, hasLength(15));
    expect(
      surfaceRows.skip(1).where((row) => row[statusIndex] == 'PASS'),
      hasLength(7),
    );
    final deferredSurfaces = surfaceRows
        .skip(1)
        .where((row) => row[statusIndex] == 'FAIL')
        .toList(growable: false);
    expect(deferredSurfaces, hasLength(7));
    expect(
      deferredSurfaces.every(
        (row) => row[regionIndex] == 'bottom-navigation-selected-pill-surface',
      ),
      isTrue,
    );
    expect(_fnv1a64(surfaceEvidence), '6f3fdb15f2e40d7b');
  });

  test('canonical shared chrome exposes exact deferred evidence', () {
    final output = StringBuffer();
    final errors = StringBuffer();
    comparator.runTabTypographyComparison(
      const [],
      standardOutput: output,
      errorOutput: errors,
    );

    final rows = _parseCsv(output.toString());
    final header = rows.first;
    final caseIndex = header.indexOf('case');
    final regionIndex = header.indexOf('region');
    final regionTypeIndex = header.indexOf('regionType');
    final statusIndex = header.indexOf('status');
    final detailsIndex = header.indexOf('details');
    final navigationRows = rows
        .skip(1)
        .where((row) {
          final region = row[regionIndex];
          return region.startsWith('bottom-navigation') ||
              region.startsWith('navigation-');
        })
        .toList(growable: false);
    final systemRows = rows
        .skip(1)
        .where((row) => row[regionIndex] == 'system')
        .toList(growable: false);
    final platformStatusRows = rows
        .skip(1)
        .where((row) => row[regionIndex].startsWith('system-status-'))
        .toList(growable: false);
    const deferredSystemCases = {'history-orders-summary', 'history-deals'};
    final deferredSystemRows = systemRows
        .where((row) => deferredSystemCases.contains(row[caseIndex]))
        .toList(growable: false);
    final sharedRows = <List<String>>[
      ...navigationRows,
      ...systemRows.where(
        (row) => !deferredSystemCases.contains(row[caseIndex]),
      ),
    ];

    expect(
      navigationRows.map((row) => row[caseIndex]).toSet(),
      tabReferenceCases.map((referenceCase) => referenceCase.id).toSet(),
    );
    expect(
      deferredSystemRows.map((row) => row[caseIndex]).toSet(),
      deferredSystemCases,
    );
    expect(
      deferredSystemRows.every((row) => row[statusIndex] == 'FAIL'),
      isTrue,
      reason: deferredSystemRows.map((row) => row.join(',')).join('\n'),
    );
    expect(platformStatusRows, hasLength(14));
    for (final referenceCase in tabReferenceCases) {
      final caseRows = platformStatusRows.where(
        (row) => row[caseIndex] == referenceCase.id,
      );
      expect(caseRows, hasLength(2), reason: referenceCase.id);
      expect(
        caseRows.every(
          (row) =>
              row[regionTypeIndex] == 'dynamicText' &&
              row[statusIndex] == 'SKIP' &&
              row[detailsIndex].trim().isNotEmpty,
        ),
        isTrue,
        reason: caseRows.map((row) => row.join(',')).join('\n'),
      );
    }
    expect(
      sharedRows.where(
        (row) =>
            row[regionTypeIndex] == 'dynamicText' &&
            (row[statusIndex] != 'SKIP' || row[detailsIndex].trim().isEmpty),
      ),
      isEmpty,
    );
    expect(navigationRows, hasLength(119));
    expect(
      navigationRows.where((row) => row[statusIndex] == 'PASS'),
      hasLength(17),
    );
    expect(
      navigationRows.where((row) => row[statusIndex] == 'FAIL'),
      hasLength(102),
    );
    expect(systemRows.where((row) => row[statusIndex] == 'PASS'), hasLength(5));
  });

  test(
    'actual seven-case reference copies have no mask-caused measurement error',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'mt5-reference-copy-candidates-',
      );
      addTearDown(() => root.delete(recursive: true));
      for (final referenceCase in tabReferenceCases) {
        final decoded = image.decodeImage(
          File(referenceCase.referencePath).readAsBytesSync(),
        )!;
        File(
          '${root.path}/${referenceCase.id}-590x1280.png',
        ).writeAsBytesSync(image.encodePng(decoded));
      }
      final output = StringBuffer();
      final errors = StringBuffer();

      final exitCode = comparator.runTabTypographyComparison(
        ['--candidate-dir', root.path],
        standardOutput: output,
        errorOutput: errors,
      );
      final diagnostics = '$output$errors';

      expect(exitCode, 0, reason: diagnostics);
      expect(
        diagnostics,
        isNot(contains('measurement failed')),
        reason: diagnostics,
      );
      for (final referenceCase in tabReferenceCases) {
        for (final region in referenceCase.staticTextRegions.where(
          (region) => region.auditMode == StaticTextAuditMode.dynamicOnly,
        )) {
          expect(
            diagnostics,
            contains(
              'text,deterministic,${referenceCase.id},dynamicText,'
              '${region.name}',
            ),
          );
        }
      }
    },
  );

  group('decoded-reference foreground role calibration', () {
    test(
      'reference consensus ignores one outlier but changes at strict majority',
      () async {
        final base = _blankImage();
        _fillInkRect(base, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(base, 10, 10, 4, 4, referenceBlackInk);
        final outlier = image.Image.from(base)
          ..setPixelRgba(18, 18, 0, 0, 0, 255);
        final majorityMutation = image.Image.from(base)
          ..setPixelRgba(14, 13, 0, 0, 0, 255);

        List<_FixtureInput> fixtures(bool majority) => [
          for (var index = 0; index < 4; index++)
            _FixtureInput(
              reference: index < (majority ? 3 : 1)
                  ? (majority ? majorityMutation : outlier)
                  : image.Image.from(base),
              candidate: image.Image.from(base),
              referenceCase: _coverageControlCase(
                id: 'consensus-$index',
                fileName: 'consensus-$index.png',
              ),
            ),
        ];
        const key = ReferenceForegroundConsensusKey(
          controlIdentity: 'coverage-control',
          selection: ReferenceForegroundSelectionState.unselected,
          semanticRole: 'black-role',
          surfaceRole: 'fixture-white-surface',
        );
        const group = ReferenceForegroundConsensusGroup(
          key: key,
          memberCaseIds: [
            'consensus-0',
            'consensus-1',
            'consensus-2',
            'consensus-3',
          ],
        );

        final outlierResult = await _runFixtures(
          fixtures: fixtures(false),
          foregroundConsensusGroups: const [group],
        );
        final majorityResult = await _runFixtures(
          fixtures: fixtures(true),
          foregroundConsensusGroups: const [group],
        );

        List<String> atomicStatuses(_RunResult result) {
          final rows = _parseCsv(result.diagnostics);
          final header = rows.first;
          final region = header.indexOf('region');
          final status = header.indexOf('status');
          return rows
              .where(
                (row) =>
                    row.length == header.length &&
                    row[region] == 'coverage-control',
              )
              .map((row) => row[status])
              .toList(growable: false);
        }

        expect(
          atomicStatuses(outlierResult),
          everyElement('PASS'),
          reason: outlierResult.diagnostics,
        );
        expect(
          atomicStatuses(majorityResult).where((status) => status == 'FAIL'),
          hasLength(3),
          reason: majorityResult.diagnostics,
        );
        expect(outlierResult.diagnostics, contains('strict-majority 3/4'));
      },
    );

    test('candidate mutation cannot alter reference consensus', () async {
      final reference = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 10, 10, 4, 4, referenceBlackInk);
      final candidateMutation = image.Image.from(reference)
        ..setPixelRgba(18, 18, 0, 0, 0, 255);
      final passingCandidate = image.Image.from(reference)
        ..setPixelRgba(40, 40, 254, 254, 254, 255);
      final referenceCase = _coverageControlCase();

      final passing = await _runFixture(
        reference: reference,
        candidate: passingCandidate,
        referenceCase: referenceCase,
      );
      final failing = await _runFixture(
        reference: reference,
        candidate: candidateMutation,
        referenceCase: referenceCase,
      );

      String provenance(_RunResult result) {
        final rows = _parseCsv(result.diagnostics);
        final header = rows.first;
        final region = header.indexOf('region');
        final details = header.indexOf('details');
        final value = rows
            .singleWhere(
              (row) =>
                  row.length == header.length &&
                  row[region] == 'coverage-control',
            )[details]
            .split('consensus provenance ')
            .last;
        return value.replaceFirst(
          RegExp(r'members=.*; count='),
          'members=<reference-only>; count=',
        );
      }

      expect(passing.exitCode, 0, reason: passing.diagnostics);
      expect(failing.exitCode, 1, reason: failing.diagnostics);
      expect(provenance(failing), provenance(passing));
    });

    test('reference consensus membership is exact and immutable', () async {
      final source = _blankImage();
      _fillInkRect(source, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(source, 10, 10, 4, 4, referenceBlackInk);
      final fixture = _FixtureInput(
        reference: source,
        candidate: image.Image.from(source),
        referenceCase: _coverageControlCase(),
      );
      const key = ReferenceForegroundConsensusKey(
        controlIdentity: 'coverage-control',
        selection: ReferenceForegroundSelectionState.unselected,
        semanticRole: 'black-role',
        surfaceRole: 'fixture-white-surface',
      );
      for (final scenario
          in <(String, List<ReferenceForegroundConsensusGroup>)>[
            ('missing', const []),
            (
              'duplicate',
              const [
                ReferenceForegroundConsensusGroup(
                  key: key,
                  memberCaseIds: ['fixture'],
                ),
                ReferenceForegroundConsensusGroup(
                  key: key,
                  memberCaseIds: ['fixture'],
                ),
              ],
            ),
            (
              'unexpected',
              const [
                ReferenceForegroundConsensusGroup(
                  key: key,
                  memberCaseIds: ['fixture', 'not-a-case'],
                ),
              ],
            ),
          ]) {
        final result = await _runFixtures(
          fixtures: [fixture],
          foregroundConsensusGroups: scenario.$2,
        );
        expect(
          result.exitCode,
          2,
          reason: '${scenario.$1}\n${result.diagnostics}',
        );
        expect(
          result.diagnostics,
          contains('foreground consensus membership'),
          reason: scenario.$1,
        );
      }
    });

    test(
      'uniform coverage permits unequal supplemental core cardinality',
      () async {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(reference, 2, 4, 2, 1, const ReferenceInk(237, 237, 237));
        _fillInkRect(candidate, 2, 4, 2, 1, const ReferenceInk(237, 237, 237));
        _fillInkRect(reference, 8, 8, 8, 8, const ReferenceInk(237, 237, 237));
        _fillInkRect(candidate, 8, 8, 8, 8, const ReferenceInk(237, 237, 237));
        reference
          ..setPixelRgba(10, 10, 11, 11, 11, 255)
          ..setPixelRgba(11, 10, 13, 13, 13, 255)
          ..setPixelRgba(10, 11, 13, 13, 13, 255)
          ..setPixelRgba(11, 11, 13, 13, 13, 255);
        candidate
          ..setPixelRgba(10, 10, 0, 0, 0, 255)
          ..setPixelRgba(11, 10, 2, 2, 2, 255)
          ..setPixelRgba(10, 11, 2, 2, 2, 255)
          ..setPixelRgba(11, 11, 2, 2, 2, 255);

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _fixtureCase(
            staticControlRegions: const [
              ReferenceStaticControlRegion(
                name: 'sparse-core-control',
                rect: ReferencePixelRect(8, 8, 8, 8),
              ),
            ],
            referenceForegroundInteriors: const [
              ReferenceForegroundInterior(
                role: 'black-role',
                rect: ReferencePixelRect(2, 2, 2, 1),
              ),
            ],
            referenceSurfaceInteriors: const [
              ReferenceSurfaceInterior(
                role: 'gray-surface',
                rect: ReferencePixelRect(2, 4, 2, 1),
              ),
            ],
            foregroundRoleByRegion: const {'sparse-core-control': 'black-role'},
            surfaceRoleByRegion: const {'sparse-core-control': 'gray-surface'},
          ),
        );

        expect(result.exitCode, 0, reason: result.diagnostics);
      },
    );

    test('coverage requires a decoded-reference RGB12 role seed', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 10, 10, 3, 3, const ReferenceInk(20, 20, 20));
      _fillInkRect(candidate, 10, 10, 3, 3, referenceBlackInk);

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _coverageControlCase(),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(
        result.diagnostics,
        contains('no decoded-reference RGB12 seed for role and surface'),
      );
    });

    test('coverage rejects a tiny wrong-direction candidate color', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 10, 10, 3, 3, referenceBlackInk);
      _fillInkRect(candidate, 10, 10, 3, 3, referenceBlackInk);
      _fillInkRect(candidate, 17, 17, 2, 2, const ReferenceInk(0, 0, 9));

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _coverageControlCase(),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(result.diagnostics, contains('off-axis foreground colors'));
    });

    test('coverage rejects disconnected decoded-reference noise', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 10, 10, 3, 3, referenceBlackInk);
      _fillInkRect(candidate, 10, 10, 3, 3, referenceBlackInk);
      _fillInkRect(reference, 17, 17, 2, 2, const ReferenceInk(100, 100, 100));

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _coverageControlCase(),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(
        result.diagnostics,
        contains('foreground component count differs'),
      );
    });

    test(
      'coverage permits an AA-only component with a local control core',
      () async {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        for (final target in <image.Image>[reference, candidate]) {
          _fillInkRect(target, 10, 10, 3, 3, referenceBlackInk);
          _fillInkRect(target, 17, 17, 2, 2, const ReferenceInk(100, 100, 100));
        }
        candidate.setPixelRgba(17, 17, 99, 99, 99, 255);

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _coverageControlCase(),
        );

        expect(result.exitCode, 0, reason: result.diagnostics);
      },
    );

    test('coverage component bijection rejects topology mutations', () async {
      for (final mutation in <String>[
        'extra',
        'omission',
        'merge',
        'split',
        'translation',
      ]) {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        if (mutation == 'merge' || mutation == 'split') {
          for (final target in <image.Image>[reference, candidate]) {
            _fillInkRect(target, 10, 10, 3, 3, referenceBlackInk);
            _fillInkRect(target, 14, 10, 3, 3, referenceBlackInk);
          }
          _fillInkRect(
            mutation == 'merge' ? candidate : reference,
            13,
            10,
            1,
            3,
            referenceBlackInk,
          );
        } else if (mutation == 'translation') {
          _fillInkRect(reference, 10, 10, 3, 3, referenceBlackInk);
          _fillInkRect(candidate, 12, 10, 3, 3, referenceBlackInk);
        } else {
          for (final target in <image.Image>[reference, candidate]) {
            _fillInkRect(target, 10, 10, 3, 3, referenceBlackInk);
          }
          _fillInkRect(
            mutation == 'extra' ? candidate : reference,
            17,
            17,
            2,
            2,
            const ReferenceInk(100, 100, 100),
          );
        }

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _coverageControlCase(),
        );

        expect(result.exitCode, 1, reason: '$mutation\n${result.diagnostics}');
        expect(
          result.diagnostics,
          contains(
            mutation == 'translation'
                ? 'complete one-to-one local bijection'
                : 'foreground component count differs',
          ),
          reason: mutation,
        );
      }
    });

    test('coverage requires a local raw RGB4 candidate core', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 10, 10, 3, 3, referenceBlackInk);
      _fillInkRect(candidate, 10, 10, 3, 3, const ReferenceInk(100, 100, 100));

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _coverageControlCase(),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(result.diagnostics, contains('foreground core is missing'));
    });

    test('coverage grid rejects a localized mass shift', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 10, 10, 9, 9, const ReferenceInk(60, 60, 60));
      _fillInkRect(candidate, 10, 10, 9, 9, const ReferenceInk(60, 60, 60));
      _fillInkRect(candidate, 10, 10, 3, 3, const ReferenceInk(10, 10, 10));
      _fillInkRect(candidate, 16, 10, 3, 3, const ReferenceInk(110, 110, 110));
      _fillInkRect(candidate, 10, 16, 3, 3, const ReferenceInk(10, 10, 10));
      _fillInkRect(candidate, 16, 16, 3, 3, const ReferenceInk(110, 110, 110));
      reference.setPixelRgba(14, 14, 0, 0, 0, 255);
      candidate.setPixelRgba(14, 14, 0, 0, 0, 255);

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _coverageControlCase(),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(result.diagnostics, contains('3x3 coverage grid'));
    });

    test(
      'coverage grid rejects equal mass and centroid redistribution',
      () async {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(reference, 10, 10, 9, 9, const ReferenceInk(60, 60, 60));
        _fillInkRect(candidate, 10, 10, 9, 9, const ReferenceInk(60, 60, 60));
        for (final cell in <(int, int, ReferenceInk)>[
          (10, 10, const ReferenceInk(10, 10, 10)),
          (16, 16, const ReferenceInk(10, 10, 10)),
          (16, 10, const ReferenceInk(110, 110, 110)),
          (10, 16, const ReferenceInk(110, 110, 110)),
        ]) {
          _fillInkRect(candidate, cell.$1, cell.$2, 3, 3, cell.$3);
        }
        reference.setPixelRgba(14, 14, 0, 0, 0, 255);
        candidate.setPixelRgba(14, 14, 0, 0, 0, 255);

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _coverageControlCase(),
        );

        expect(result.exitCode, 1, reason: result.diagnostics);
        expect(result.diagnostics, contains('3x3 coverage grid'));
        expect(result.diagnostics, isNot(contains('coverage mass delta')));
        expect(result.diagnostics, isNot(contains('coverage centroid delta')));
      },
    );

    test('coverage mass rejects a uniform candidate fade', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 10, 10, 9, 9, const ReferenceInk(60, 60, 60));
      _fillInkRect(candidate, 10, 10, 9, 9, const ReferenceInk(80, 80, 80));
      reference.setPixelRgba(14, 14, 0, 0, 0, 255);
      candidate.setPixelRgba(14, 14, 0, 0, 0, 255);

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _coverageControlCase(),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(result.diagnostics, contains('coverage mass delta'));
      expect(result.diagnostics, isNot(contains('3x3 coverage grid')));
    });

    test('coverage grid rejects per-component redistribution', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      for (final left in <int>[10, 20]) {
        _fillInkRect(reference, left, 10, 3, 9, const ReferenceInk(60, 60, 60));
      }
      _fillInkRect(candidate, 10, 10, 3, 9, const ReferenceInk(10, 10, 10));
      _fillInkRect(candidate, 20, 10, 3, 9, const ReferenceInk(110, 110, 110));
      for (final target in <image.Image>[reference, candidate]) {
        target
          ..setPixelRgba(11, 14, 0, 0, 0, 255)
          ..setPixelRgba(21, 14, 0, 0, 0, 255);
      }

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(
          staticControlRegions: const [
            ReferenceStaticControlRegion(
              name: 'component-coverage-control',
              rect: ReferencePixelRect(8, 8, 17, 13),
            ),
          ],
          referenceForegroundInteriors: const [
            ReferenceForegroundInterior(
              role: 'black-role',
              rect: ReferencePixelRect(2, 2, 2, 1),
            ),
          ],
          foregroundRoleByRegion: const {
            'component-coverage-control': 'black-role',
          },
        ),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(result.diagnostics, contains('3x3 coverage grid'));
    });

    test('one-to-one core matching rejects a many-to-one collapse', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 10, 10, 2, 3, referenceBlackInk);
      _fillInkRect(candidate, 10, 11, 2, 2, referenceBlackInk);

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(
          staticControlRegions: const [
            ReferenceStaticControlRegion(
              name: 'collapsed-core',
              rect: ReferencePixelRect(8, 8, 8, 8),
            ),
          ],
          referenceForegroundInteriors: const [
            ReferenceForegroundInterior(
              role: 'black-role',
              rect: ReferencePixelRect(2, 2, 2, 1),
            ),
          ],
          foregroundRoleByRegion: const {'collapsed-core': 'black-role'},
        ),
      );

      final rows = _parseCsv(result.diagnostics);
      final header = rows.first;
      final region = header.indexOf('region');
      final status = header.indexOf('status');
      final details = header.indexOf('details');
      final row = rows.singleWhere(
        (row) => row.length == header.length && row[region] == 'collapsed-core',
      );
      expect(row[status], 'FAIL', reason: row.join(','));
      expect(row[details], contains('foreground core pixels differ'));
    });

    test('one-to-one core matching permits a one-pixel shift', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 10, 10, 2, 3, referenceBlackInk);
      _fillInkRect(candidate, 11, 10, 2, 3, referenceBlackInk);

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(
          staticControlRegions: const [
            ReferenceStaticControlRegion(
              name: 'shifted-core',
              rect: ReferencePixelRect(8, 8, 8, 8),
            ),
          ],
          referenceForegroundInteriors: const [
            ReferenceForegroundInterior(
              role: 'black-role',
              rect: ReferencePixelRect(2, 2, 2, 1),
            ),
          ],
          foregroundRoleByRegion: const {'shifted-core': 'black-role'},
        ),
      );

      expect(result.exitCode, 0, reason: result.diagnostics);
    });

    test(
      'parent surface rejects wrong background outside child transition ownership',
      () async {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(
          reference,
          8,
          8,
          24,
          20,
          const ReferenceInk(237, 237, 237),
        );
        _fillInkRect(
          candidate,
          8,
          8,
          24,
          20,
          const ReferenceInk(237, 237, 237),
        );
        _fillInkRect(reference, 13, 13, 5, 5, referenceBlackInk);
        _fillInkRect(candidate, 13, 13, 5, 5, referenceBlackInk);

        // Two physical pixels beyond the glyph is outside its allowed
        // one-pixel transition ownership and must remain surface-owned.
        for (var y = 14; y <= 16; y++) {
          candidate.setPixelRgba(19, y, 255, 255, 255, 255);
        }

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _fixtureCase(
            visualRegionName: 'selected-pill-parent',
            visualRect: const ReferencePixelRect(8, 8, 24, 20),
            requiredForegroundRoles: const ['black-role'],
            foregroundRegionNames: const ['glyph-child'],
            staticControlRegions: const [
              ReferenceStaticControlRegion(
                name: 'glyph-child',
                rect: ReferencePixelRect(10, 10, 14, 12),
              ),
            ],
            referenceForegroundInteriors: const [
              ReferenceForegroundInterior(
                role: 'black-role',
                rect: ReferencePixelRect(2, 2, 2, 1),
              ),
            ],
            foregroundRoleByRegion: const {'glyph-child': 'black-role'},
          ),
        );

        final rows = _parseCsv(result.diagnostics);
        final header = rows.first;
        final region = header.indexOf('region');
        final status = header.indexOf('status');
        final details = header.indexOf('details');
        final parent = rows.singleWhere(
          (row) =>
              row.length == header.length &&
              row[region] == 'selected-pill-parent',
        );
        expect(parent[status], 'FAIL', reason: parent.join(','));
        expect(parent[details], contains('parent-surface pixels differ'));
      },
    );

    test(
      'surface ownership follows declared candidate text geometry',
      () async {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(reference, 16, 16, 2, 3, referenceBlackInk);
        _fillInkRect(candidate, 17, 16, 2, 3, referenceBlackInk);
        reference.setPixelRgba(15, 17, 128, 128, 128, 255);
        candidate.setPixelRgba(19, 17, 128, 128, 128, 255);

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _fixtureCase(
            staticTextRegions: const [
              StaticTextRegion(
                name: 'shifted-label-child',
                referenceRect: ReferencePixelRect(14, 14, 4, 7),
                candidateRect: ReferencePixelRect(15, 14, 4, 7),
                ink: referenceBlackInk,
              ),
            ],
            surfaceRegions: const [
              ReferenceSurfaceRegion(
                name: 'candidate-geometry-surface',
                rect: ReferencePixelRect(8, 8, 24, 24),
                surfaceRole: 'fixture-white-surface',
                surroundingRole: 'fixture-white-surface',
                foregroundRegionNames: ['shifted-label-child'],
              ),
            ],
            referenceForegroundInteriors: const [
              ReferenceForegroundInterior(
                role: 'black-role',
                rect: ReferencePixelRect(2, 2, 2, 1),
              ),
            ],
            foregroundRoleByRegion: const {'shifted-label-child': 'black-role'},
          ),
        );

        final row = _rowForRegion(
          result.diagnostics,
          'candidate-geometry-surface',
        );
        expect(row, contains(',PASS,'), reason: row);
      },
    );

    test(
      'explicit capsule and pill surface leaves pass exact ownership',
      () async {
        final reference = _surfaceFixtureImage();
        final result = await _runFixture(
          reference: reference,
          candidate: image.Image.from(reference),
          referenceCase: _surfaceFixtureCase(),
        );

        final rows = _parseCsv(result.diagnostics);
        final header = rows.first;
        final recordType = header.indexOf('recordType');
        final status = header.indexOf('status');
        final surfaceRows = rows
            .skip(1)
            .where(
              (row) =>
                  row.length == header.length &&
                  row[recordType] == 'static-surface',
            )
            .toList(growable: false);
        expect(surfaceRows, hasLength(2), reason: result.diagnostics);
        expect(
          surfaceRows.every((row) => row[status] == 'PASS'),
          isTrue,
          reason: surfaceRows.map((row) => row.join(',')).join('\n'),
        );
      },
    );

    test('selected pill surface rejects a wrong calibrated fill', () async {
      final reference = _surfaceFixtureImage();
      final candidate = image.Image.from(reference);
      _fillInkRect(
        candidate,
        12,
        12,
        20,
        20,
        const ReferenceInk(230, 230, 230),
      );

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _surfaceFixtureCase(),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(
        _rowForRegion(result.diagnostics, 'fixture-pill-surface'),
        contains(',FAIL,'),
      );
      expect(result.diagnostics, contains('surface RGB delta 7'));
    });

    test('selected pill surface rejects a changed corner radius', () async {
      final reference = _surfaceFixtureImage();
      final candidate = image.Image.from(reference);
      for (final left in <int>[12, 29]) {
        for (final top in <int>[12, 29]) {
          _fillInkRect(
            candidate,
            left,
            top,
            3,
            3,
            const ReferenceInk(237, 237, 237),
          );
        }
      }

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _surfaceFixtureCase(),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      final row = _rowForRegion(result.diagnostics, 'fixture-pill-surface');
      expect(row, contains(',FAIL,'));
      expect(row, contains('surface pixels differ'));
    });

    test('capsule surface rejects an unexpected background class', () async {
      final reference = _surfaceFixtureImage();
      final candidate = image.Image.from(reference);
      _fillInkRect(candidate, 5, 5, 3, 3, const ReferenceInk(237, 237, 237));

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _surfaceFixtureCase(),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      final row = _rowForRegion(result.diagnostics, 'fixture-capsule-surface');
      expect(row, contains(',FAIL,'));
      expect(row, contains('pixels belong to neither declared surface class'));
    });

    test('surface-relative shadow rejects a two-pixel translation', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 12, 14, 16, 4, const ReferenceInk(242, 242, 242));
      _fillInkRect(candidate, 12, 16, 16, 4, const ReferenceInk(242, 242, 242));

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(
          shadowRegions: const [
            ReferenceShadowRegion(
              name: 'surface-relative-shadow',
              rect: ReferencePixelRect(8, 10, 24, 14),
              surfaceSampleRect: ReferencePixelRect(8, 4, 24, 4),
            ),
          ],
        ),
      );

      final rows = _parseCsv(result.diagnostics);
      final header = rows.first;
      final recordType = header.indexOf('recordType');
      final region = header.indexOf('region');
      final status = header.indexOf('status');
      final details = header.indexOf('details');
      final shadowRows = rows
          .where(
            (row) =>
                row.length == header.length &&
                row[recordType] == 'static-shadow' &&
                row[region] == 'surface-relative-shadow',
          )
          .toList(growable: false);
      expect(shadowRows, hasLength(1), reason: result.diagnostics);
      if (shadowRows.length != 1) return;
      expect(shadowRows.single[status], 'FAIL');
      expect(shadowRows.single[details], contains('surface-relative shadow'));
      expect(shadowRows.single[details], contains('feature edge delta 2'));
    });

    test(
      'role-aware atomic and composite rows enforce raw feature edges',
      () async {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(reference, 10, 10, 3, 3, referenceBlackInk);
        _fillInkRect(candidate, 10, 10, 3, 3, referenceBlackInk);
        _fillInkRect(reference, 28, 10, 2, 2, referenceBlackInk);
        _fillInkRect(candidate, 30, 10, 2, 2, referenceBlackInk);

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _fixtureCase(
            visualRegionName: 'role-composite',
            visualRect: const ReferencePixelRect(8, 8, 28, 16),
            requiredForegroundRoles: const ['black-role'],
            staticControlRegions: const [
              ReferenceStaticControlRegion(
                name: 'black-control',
                rect: ReferencePixelRect(8, 8, 28, 16),
              ),
            ],
            referenceForegroundInteriors: const [
              ReferenceForegroundInterior(
                role: 'black-role',
                rect: ReferencePixelRect(2, 2, 2, 1),
              ),
            ],
            foregroundRoleByRegion: const {'black-control': 'black-role'},
          ),
        );

        final rows = _parseCsv(result.diagnostics);
        final header = rows.first;
        final recordType = header.indexOf('recordType');
        final region = header.indexOf('region');
        final status = header.indexOf('status');
        final details = header.indexOf('details');
        for (final target in <(String, String)>[
          ('static-control', 'black-control'),
          ('static-region', 'role-composite'),
        ]) {
          final row = rows.singleWhere(
            (row) =>
                row.length == header.length &&
                row[recordType] == target.$1 &&
                row[region] == target.$2,
          );
          expect(row[status], 'FAIL', reason: row.join(','));
          expect(row[details], contains('feature edge delta 2'));
        }
      },
    );

    test(
      'role-aware atomic and composite rows enforce raw residuals',
      () async {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(reference, 10, 10, 3, 3, referenceBlackInk);
        _fillInkRect(candidate, 10, 10, 3, 3, referenceBlackInk);
        _fillInkRect(reference, 20, 10, 4, 4, referenceBlackInk);
        _fillInkRect(candidate, 20, 10, 4, 4, const ReferenceInk(20, 20, 20));

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _fixtureCase(
            visualRegionName: 'role-composite',
            visualRect: const ReferencePixelRect(8, 8, 24, 16),
            requiredForegroundRoles: const ['black-role'],
            staticControlRegions: const [
              ReferenceStaticControlRegion(
                name: 'black-control',
                rect: ReferencePixelRect(8, 8, 24, 16),
              ),
            ],
            referenceForegroundInteriors: const [
              ReferenceForegroundInterior(
                role: 'black-role',
                rect: ReferencePixelRect(2, 2, 2, 1),
              ),
            ],
            foregroundRoleByRegion: const {'black-control': 'black-role'},
          ),
        );

        final rows = _parseCsv(result.diagnostics);
        final header = rows.first;
        final recordType = header.indexOf('recordType');
        final region = header.indexOf('region');
        final status = header.indexOf('status');
        final details = header.indexOf('details');
        for (final target in <(String, String)>[
          ('static-control', 'black-control'),
          ('static-region', 'role-composite'),
        ]) {
          final row = rows.singleWhere(
            (row) =>
                row.length == header.length &&
                row[recordType] == target.$1 &&
                row[region] == target.$2,
          );
          expect(row[status], 'FAIL', reason: row.join(','));
          expect(
            row[details],
            contains(
              target.$1 == 'static-control'
                  ? 'coverage mass delta'
                  : 'one or more assigned foreground children failed',
            ),
          );
        }
      },
    );

    test(
      'same-bounds equal-density internal deformation fails role residuals',
      () async {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        for (final target in [reference, candidate]) {
          _fillInkRect(target, 10, 10, 3, 7, referenceBlackInk);
          _fillInkRect(target, 22, 10, 3, 7, referenceBlackInk);
        }
        _fillInkRect(reference, 15, 10, 5, 3, referenceBlackInk);
        _fillInkRect(candidate, 15, 14, 5, 3, referenceBlackInk);

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _fixtureCase(
            visualRegionName: 'role-composite',
            visualRect: const ReferencePixelRect(8, 8, 28, 20),
            requiredForegroundRoles: const ['black-role'],
            staticControlRegions: const [
              ReferenceStaticControlRegion(
                name: 'black-control',
                rect: ReferencePixelRect(8, 8, 28, 20),
              ),
            ],
            referenceForegroundInteriors: const [
              ReferenceForegroundInterior(
                role: 'black-role',
                rect: ReferencePixelRect(2, 2, 2, 1),
              ),
            ],
            foregroundRoleByRegion: const {'black-control': 'black-role'},
          ),
        );

        final rows = _parseCsv(result.diagnostics);
        final header = rows.first;
        final recordType = header.indexOf('recordType');
        final region = header.indexOf('region');
        final edgeDelta = header.indexOf('edgeDelta');
        final density = header.indexOf('candidateInkRatio');
        final status = header.indexOf('status');
        final details = header.indexOf('details');
        for (final target in <(String, String)>[
          ('static-control', 'black-control'),
          ('static-region', 'role-composite'),
        ]) {
          final row = rows.singleWhere(
            (row) =>
                row.length == header.length &&
                row[recordType] == target.$1 &&
                row[region] == target.$2,
          );
          expect(row[edgeDelta], '0', reason: row.join(','));
          if (target.$1 == 'static-control') {
            expect(double.parse(row[density]), closeTo(1, .001));
          }
          expect(row[status], 'FAIL', reason: row.join(','));
          expect(
            row[details],
            contains(
              target.$1 == 'static-control'
                  ? 'foreground shape pixels differ'
                  : 'aggregate owned pixels differ',
            ),
          );
        }
      },
    );

    test(
      'role-aware text independently rejects internal deformation',
      () async {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        for (final target in [reference, candidate]) {
          _fillInkRect(target, 10, 10, 3, 7, referenceBlackInk);
          _fillInkRect(target, 22, 10, 3, 7, referenceBlackInk);
        }
        _fillInkRect(reference, 15, 10, 5, 3, referenceBlackInk);
        _fillInkRect(candidate, 15, 14, 5, 3, referenceBlackInk);

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _fixtureCase(
            visualRegionName: 'role-composite',
            visualRect: const ReferencePixelRect(8, 8, 28, 20),
            requiredForegroundRoles: const ['black-role'],
            foregroundRegionNames: const ['black-label'],
            staticTextRegions: const [
              StaticTextRegion(
                name: 'black-label',
                referenceRect: ReferencePixelRect(8, 8, 28, 20),
                candidateRect: ReferencePixelRect(8, 8, 28, 20),
                ink: referenceBlackInk,
              ),
            ],
            referenceForegroundInteriors: const [
              ReferenceForegroundInterior(
                role: 'black-role',
                rect: ReferencePixelRect(2, 2, 2, 1),
              ),
            ],
            foregroundRoleByRegion: const {'black-label': 'black-role'},
          ),
        );

        final rows = _parseCsv(result.diagnostics);
        final header = rows.first;
        final recordType = header.indexOf('recordType');
        final region = header.indexOf('region');
        final status = header.indexOf('status');
        final details = header.indexOf('details');
        final text = rows.singleWhere(
          (row) =>
              row.length == header.length &&
              row[recordType] == 'text' &&
              row[region] == 'black-label',
        );
        expect(text[status], 'FAIL', reason: text.join(','));
        expect(text[details], contains('foreground shape pixels differ'));
      },
    );

    test('empty role-aware foreground emits controlled FAIL rows', () async {
      final reference = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 8, 8, 2, 2, const ReferenceInk(20, 20, 20));
      final candidate = image.Image.from(reference)
        ..setPixelRgba(50, 50, 254, 254, 254, 255);

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(
          visualRegionName: 'role-composite',
          visualRect: const ReferencePixelRect(8, 8, 2, 2),
          requiredForegroundRoles: const ['black-role'],
          staticControlRegions: const [
            ReferenceStaticControlRegion(
              name: 'black-control',
              rect: ReferencePixelRect(8, 8, 2, 2),
            ),
          ],
          referenceForegroundInteriors: const [
            ReferenceForegroundInterior(
              role: 'black-role',
              rect: ReferencePixelRect(2, 2, 2, 1),
            ),
          ],
          foregroundRoleByRegion: const {'black-control': 'black-role'},
        ),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      final rows = _parseCsv(result.diagnostics);
      final header = rows.first;
      final status = header.indexOf('status');
      expect(
        rows.where(
          (row) => row.length == header.length && row[status] == 'FAIL',
        ),
        hasLength(2),
      );
    });

    test('missing candidate assigned-role ink emits a FAIL row', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 10, 10, 3, 3, referenceBlackInk);

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(
          staticControlRegions: const [
            ReferenceStaticControlRegion(
              name: 'missing-icon',
              rect: ReferencePixelRect(8, 8, 8, 8),
            ),
          ],
          referenceForegroundInteriors: const [
            ReferenceForegroundInterior(
              role: 'black-role',
              rect: ReferencePixelRect(2, 2, 2, 1),
            ),
          ],
          foregroundRoleByRegion: const {'missing-icon': 'black-role'},
        ),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      final rows = _parseCsv(result.diagnostics);
      final header = rows.first;
      final region = header.indexOf('region');
      final status = header.indexOf('status');
      final details = header.indexOf('details');
      final row = rows.singleWhere(
        (row) => row.length == header.length && row[region] == 'missing-icon',
      );
      expect(row[status], 'FAIL', reason: row.join(','));
      expect(row[details], startsWith('measurement failed: No ink'));
    });

    test(
      'one-pixel RGB5 mutation defeats the identical-raster fast path',
      () async {
        final reference = _blankImage();
        _fillInkRect(reference, 10, 10, 3, 1, const ReferenceInk(11, 11, 11));
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        final candidate = image.Image.from(reference)
          ..setPixelRgba(10, 10, 5, 5, 5, 255);

        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _calibratedTextCase('black-role', referenceBlackInk),
        );

        expect(result.exitCode, 1, reason: result.diagnostics);
        expect(result.diagnostics, contains('thin-ink'));
        expect(result.diagnostics, contains('semantic RGB delta 11'));
      },
    );

    test('thin JPEG black and blue pass exact raw PNG candidates', () async {
      for (final fixture in <(String, ReferenceInk, ReferenceInk)>[
        ('black-role', const ReferenceInk(11, 11, 11), referenceBlackInk),
        ('blue-role', const ReferenceInk(12, 134, 246), referenceBlueInk),
      ]) {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 10, 10, 2, 2, fixture.$2);
        _fillInkRect(candidate, 10, 10, 2, 2, fixture.$3);
        _fillInkRect(reference, 2, 2, 2, 1, fixture.$3);
        _fillInkRect(candidate, 2, 2, 2, 1, fixture.$3);
        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _calibratedTextCase(fixture.$1, fixture.$3),
        );
        expect(result.exitCode, 0, reason: result.diagnostics);
      }
    });

    test('black RGB5 and RGB12 candidates fail calibrated semantics', () async {
      for (final channel in <int>[5, 12]) {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 10, 10, 2, 2, const ReferenceInk(11, 11, 11));
        _fillInkRect(
          candidate,
          10,
          10,
          2,
          2,
          ReferenceInk(channel, channel, channel),
        );
        _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
        _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _calibratedTextCase('black-role', referenceBlackInk),
        );
        expect(result.exitCode, 1, reason: result.diagnostics);
        expect(result.diagnostics, contains('semantic RGB delta $channel'));
      }
    });

    test(
      'blue +5 channel and hue-shift candidates fail independently',
      () async {
        for (final candidateInk in <ReferenceInk>[
          const ReferenceInk(5, 122, 255),
          const ReferenceInk(5, 117, 250),
        ]) {
          final reference = _blankImage();
          final candidate = _blankImage();
          _fillInkRect(
            reference,
            10,
            10,
            2,
            2,
            const ReferenceInk(12, 134, 246),
          );
          _fillInkRect(candidate, 10, 10, 2, 2, candidateInk);
          _fillInkRect(reference, 2, 2, 2, 1, referenceBlueInk);
          _fillInkRect(candidate, 2, 2, 2, 1, referenceBlueInk);
          final result = await _runFixture(
            reference: reference,
            candidate: candidate,
            referenceCase: _calibratedTextCase('blue-role', referenceBlueInk),
          );
          expect(result.exitCode, 1, reason: result.diagnostics);
          expect(result.diagnostics, contains('semantic RGB delta 5'));
        }
      },
    );

    test(
      'composite black and blue roles each reject +5 independently',
      () async {
        for (final mutateBlack in <bool>[true, false]) {
          final reference = _blankImage();
          final candidate = _blankImage();
          _fillInkRect(reference, 10, 10, 2, 2, const ReferenceInk(11, 11, 11));
          _fillInkRect(
            reference,
            20,
            10,
            2,
            2,
            const ReferenceInk(12, 134, 246),
          );
          _fillInkRect(
            candidate,
            10,
            10,
            2,
            2,
            mutateBlack ? const ReferenceInk(5, 5, 5) : referenceBlackInk,
          );
          _fillInkRect(
            candidate,
            20,
            10,
            2,
            2,
            mutateBlack ? referenceBlueInk : const ReferenceInk(5, 122, 255),
          );
          _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
          _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
          _fillInkRect(reference, 2, 4, 2, 1, referenceBlueInk);
          _fillInkRect(candidate, 2, 4, 2, 1, referenceBlueInk);
          final result = await _runFixture(
            reference: reference,
            candidate: candidate,
            referenceCase: _fixtureCase(
              visualRegionName: 'role-composite',
              requiredForegroundRoles: const ['black-role', 'blue-role'],
              staticControlRegions: const [
                ReferenceStaticControlRegion(
                  name: 'black-control',
                  rect: ReferencePixelRect(8, 8, 8, 8),
                ),
                ReferenceStaticControlRegion(
                  name: 'blue-control',
                  rect: ReferencePixelRect(18, 8, 8, 8),
                ),
              ],
              referenceForegroundInteriors: const [
                ReferenceForegroundInterior(
                  role: 'black-role',
                  rect: ReferencePixelRect(2, 2, 2, 1),
                ),
                ReferenceForegroundInterior(
                  role: 'blue-role',
                  rect: ReferencePixelRect(2, 4, 2, 1),
                ),
              ],
              foregroundRoleByRegion: const {
                'black-control': 'black-role',
                'blue-control': 'blue-role',
              },
            ),
          );
          expect(result.exitCode, 1, reason: result.diagnostics);
          expect(result.diagnostics, contains('role-composite'));
          expect(result.diagnostics, contains('foreground RGB delta 5'));
        }
      },
    );

    test('unassigned required composite foreground fails input', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(
          requiredForegroundRoles: const ['black-role'],
          referenceForegroundInteriors: const [
            ReferenceForegroundInterior(
              role: 'black-role',
              rect: ReferencePixelRect(2, 2, 2, 1),
            ),
          ],
        ),
      );
      expect(result.exitCode, 2, reason: result.diagnostics);
      expect(result.diagnostics, contains('has no assigned foreground region'));
    });

    test('composite foreground rejects an extra assigned role', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 10, 10, 2, 2, const ReferenceInk(11, 11, 11));
      _fillInkRect(candidate, 10, 10, 2, 2, referenceBlackInk);
      _fillInkRect(reference, 20, 10, 2, 2, const ReferenceInk(12, 134, 246));
      _fillInkRect(candidate, 20, 10, 2, 2, referenceBlueInk);
      _fillInkRect(reference, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(candidate, 2, 2, 2, 1, referenceBlackInk);
      _fillInkRect(reference, 2, 4, 2, 1, referenceBlueInk);
      _fillInkRect(candidate, 2, 4, 2, 1, referenceBlueInk);

      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(
          visualRegionName: 'role-composite',
          requiredForegroundRoles: const ['black-role'],
          staticControlRegions: const [
            ReferenceStaticControlRegion(
              name: 'black-control',
              rect: ReferencePixelRect(8, 8, 8, 8),
            ),
            ReferenceStaticControlRegion(
              name: 'blue-control',
              rect: ReferencePixelRect(18, 8, 8, 8),
            ),
          ],
          referenceForegroundInteriors: const [
            ReferenceForegroundInterior(
              role: 'black-role',
              rect: ReferencePixelRect(2, 2, 2, 1),
            ),
            ReferenceForegroundInterior(
              role: 'blue-role',
              rect: ReferencePixelRect(2, 4, 2, 1),
            ),
          ],
          foregroundRoleByRegion: const {
            'black-control': 'black-role',
            'blue-control': 'blue-role',
          },
        ),
      );

      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(result.diagnostics, contains('extra foreground roles: blue-role'));
    });

    test('misleading hint preserves decoded reference RGB24 failure', () async {
      final reference = _blankImage();
      final candidate = _blankImage();
      _fillInkRect(reference, 10, 10, 2, 2, const ReferenceInk(24, 24, 24));
      _fillInkRect(candidate, 10, 10, 2, 2, referenceBlackInk);
      final result = await _runFixture(
        reference: reference,
        candidate: candidate,
        referenceCase: _fixtureCase(
          staticTextRegions: const [
            StaticTextRegion(
              name: 'misleading-hint',
              referenceRect: ReferencePixelRect(8, 8, 8, 8),
              candidateRect: ReferencePixelRect(8, 8, 8, 8),
              ink: referenceBlackInk,
            ),
          ],
        ),
      );
      expect(result.exitCode, 1, reason: result.diagnostics);
      expect(result.diagnostics, contains('semantic RGB delta 24'));
    });

    test('empty and inconsistent role calibration fail input', () async {
      for (final interiors in <List<ReferenceForegroundInterior>>[
        const [],
        const [
          ReferenceForegroundInterior(
            role: 'black-role',
            rect: ReferencePixelRect(2, 2, 1, 1),
          ),
          ReferenceForegroundInterior(
            role: 'black-role',
            rect: ReferencePixelRect(3, 2, 1, 1),
          ),
        ],
      ]) {
        final reference = _blankImage();
        final candidate = _blankImage();
        _fillInkRect(reference, 10, 10, 2, 2, const ReferenceInk(11, 11, 11));
        _fillInkRect(candidate, 10, 10, 2, 2, referenceBlackInk);
        if (interiors.isNotEmpty) {
          _fillInkRect(reference, 2, 2, 1, 1, referenceBlackInk);
          _fillInkRect(reference, 3, 2, 1, 1, const ReferenceInk(24, 24, 24));
        }
        final result = await _runFixture(
          reference: reference,
          candidate: candidate,
          referenceCase: _calibratedTextCase(
            'black-role',
            referenceBlackInk,
            interiors: interiors,
          ),
        );
        expect(result.exitCode, 2, reason: result.diagnostics);
        expect(
          result.diagnostics,
          anyOf(contains('no decoded-reference'), contains('inconsistent')),
        );
      }
    });
  });
}

String _fnv1a64(String value) {
  var hash = 0xcbf29ce484222325;
  for (final byte in value.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

String _atomicNumericEvidence(String evidence) => evidence.replaceAll(
  RegExp(r'unmatched support reference [^;]*; candidate [^;]*; support counts'),
  'unmatched support <pairing-omitted>; support counts',
);

String _rowForRegion(String diagnostics, String regionName) {
  final rows = _parseCsv(diagnostics);
  final header = rows.first;
  final region = header.indexOf('region');
  return rows
      .singleWhere(
        (row) => row.length == header.length && row[region] == regionName,
      )
      .join(',');
}

image.Image _surfaceFixtureImage() {
  final result = _blankImage();
  _fillInkRect(result, 12, 12, 20, 20, const ReferenceInk(237, 237, 237));
  for (final left in <int>[12, 29]) {
    for (final top in <int>[12, 29]) {
      _fillInkRect(result, left, top, 3, 3, referenceWhiteInk);
    }
  }
  return result;
}

TabReferenceCase _surfaceFixtureCase() => _fixtureCase(
  surfaceRegions: const [
    ReferenceSurfaceRegion(
      name: 'fixture-capsule-surface',
      rect: ReferencePixelRect(4, 4, 36, 36),
      surfaceRole: 'fixture-white-surface',
      surroundingRole: 'fixture-white-surface',
      excludedRects: [ReferencePixelRect(8, 8, 28, 28)],
    ),
    ReferenceSurfaceRegion(
      name: 'fixture-pill-surface',
      rect: ReferencePixelRect(8, 8, 28, 28),
      surfaceRole: 'fixture-gray-surface',
      surroundingRole: 'fixture-white-surface',
    ),
  ],
  referenceSurfaceInteriors: const [
    ReferenceSurfaceInterior(
      role: 'fixture-white-surface',
      rect: ReferencePixelRect(2, 2, 2, 1),
    ),
    ReferenceSurfaceInterior(
      role: 'fixture-gray-surface',
      rect: ReferencePixelRect(16, 16, 2, 1),
    ),
  ],
);

TabReferenceCase _calibratedTextCase(
  String role,
  ReferenceInk hint, {
  List<ReferenceForegroundInterior>? interiors,
}) => _fixtureCase(
  staticTextRegions: [
    StaticTextRegion(
      name: 'thin-ink',
      referenceRect: const ReferencePixelRect(8, 8, 8, 8),
      candidateRect: const ReferencePixelRect(8, 8, 8, 8),
      ink: hint,
    ),
  ],
  referenceForegroundInteriors:
      interiors ??
      [
        ReferenceForegroundInterior(
          role: role,
          rect: const ReferencePixelRect(2, 2, 2, 1),
        ),
      ],
  foregroundRoleByRegion: {'thin-ink': role},
);

TabReferenceCase _coverageControlCase({
  String id = 'fixture',
  String fileName = 'fixture.png',
}) => _fixtureCase(
  id: id,
  fileName: fileName,
  staticControlRegions: const [
    ReferenceStaticControlRegion(
      name: 'coverage-control',
      rect: ReferencePixelRect(8, 8, 13, 13),
    ),
  ],
  referenceForegroundInteriors: const [
    ReferenceForegroundInterior(
      role: 'black-role',
      rect: ReferencePixelRect(2, 2, 2, 1),
    ),
  ],
  foregroundRoleByRegion: const {'coverage-control': 'black-role'},
);

void _fillInkRect(
  image.Image target,
  int left,
  int top,
  int width,
  int height,
  ReferenceInk ink,
) => _fillRect(target, left, top, width, height, ink.red, ink.green, ink.blue);

TabReferenceCase _fixtureCase({
  String id = 'fixture',
  String fileName = 'fixture.png',
  String visualRegionName = 'fixture-canvas',
  ReferencePixelRect visualRect = _canvas,
  List<StaticTextRegion> staticTextRegions = const [],
  List<ReferenceStaticControlRegion> staticControlRegions = const [],
  List<ReferenceSurfaceRegion> surfaceRegions = const [],
  List<ReferenceShadowRegion> shadowRegions = const [],
  List<ReferenceDynamicMask> dynamicMaskRegions = const [],
  List<ReferenceForegroundInterior> referenceForegroundInteriors = const [],
  List<ReferenceSurfaceInterior> referenceSurfaceInteriors = const [],
  Map<String, String> foregroundRoleByRegion = const {},
  Map<String, String> surfaceRoleByRegion = const {},
  Map<String, ReferenceForegroundSelectionState> foregroundSelectionByRegion =
      const {},
  List<String> requiredForegroundRoles = const [],
  List<String> foregroundRegionNames = const [],
  List<String> shadowRegionNames = const [],
}) {
  final resolvedSurfaceInteriors =
      referenceSurfaceInteriors.isNotEmpty || foregroundRoleByRegion.isEmpty
      ? referenceSurfaceInteriors
      : const [
          ReferenceSurfaceInterior(
            role: 'fixture-white-surface',
            rect: ReferencePixelRect(0, 0, 2, 1),
          ),
        ];
  final resolvedSurfaceRoles =
      surfaceRoleByRegion.isNotEmpty || foregroundRoleByRegion.isEmpty
      ? surfaceRoleByRegion
      : {
          for (final name in foregroundRoleByRegion.keys)
            name: 'fixture-white-surface',
        };
  final resolvedForegroundSelections =
      foregroundSelectionByRegion.isNotEmpty || foregroundRoleByRegion.isEmpty
      ? foregroundSelectionByRegion
      : {
          for (final name in foregroundRoleByRegion.keys)
            name: ReferenceForegroundSelectionState.unselected,
        };
  return TabReferenceCase(
    id: id,
    fileName: fileName,
    referenceSha256:
        '0000000000000000000000000000000000000000000000000000000000000000',
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
        rect: visualRect,
        requiredForegroundRoles: requiredForegroundRoles,
        foregroundRegionNames: foregroundRegionNames,
        shadowRegionNames: shadowRegionNames,
      ),
    ],
    staticControlRegions: staticControlRegions,
    surfaceRegions: surfaceRegions,
    shadowRegions: shadowRegions,
    staticTextRegions: staticTextRegions,
    dynamicMaskRegions: dynamicMaskRegions,
    referenceForegroundInteriors: referenceForegroundInteriors,
    referenceSurfaceInteriors: resolvedSurfaceInteriors,
    foregroundRoleByRegion: foregroundRoleByRegion,
    surfaceRoleByRegion: resolvedSurfaceRoles,
    foregroundSelectionByRegion: resolvedForegroundSelections,
  );
}

image.Image _blankImage() {
  final result = image.Image(width: 64, height: 64, numChannels: 4);
  _fillRect(result, 0, 0, 64, 64, 255, 255, 255);
  return result;
}

image.Image _solidImage(int channel) {
  final result = image.Image(width: 64, height: 64, numChannels: 4);
  _fillRect(result, 0, 0, 64, 64, channel, channel, channel);
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
  List<ReferenceForegroundConsensusGroup>? foregroundConsensusGroups,
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
    foregroundConsensusGroups:
        foregroundConsensusGroups ?? _fixtureConsensusGroups(fixtures),
  );
  return _RunResult(exitCode, '$output$errors');
}

List<ReferenceForegroundConsensusGroup> _fixtureConsensusGroups(
  List<_FixtureInput> fixtures,
) {
  final members = <ReferenceForegroundConsensusKey, List<String>>{};
  for (final fixture in fixtures) {
    final referenceCase = fixture.referenceCase;
    for (final assignment in referenceCase.foregroundRoleByRegion.entries) {
      final key = ReferenceForegroundConsensusKey(
        controlIdentity: assignment.key,
        selection: referenceCase.foregroundSelectionByRegion[assignment.key]!,
        semanticRole: assignment.value,
        surfaceRole: referenceCase.surfaceRoleByRegion[assignment.key]!,
      );
      members.putIfAbsent(key, () => <String>[]).add(referenceCase.id);
    }
  }
  return [
    for (final entry in members.entries)
      ReferenceForegroundConsensusGroup(
        key: entry.key,
        memberCaseIds: entry.value,
      ),
  ];
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

int _csvColumnCount(String row) {
  var columns = 1;
  var inQuotes = false;
  for (var index = 0; index < row.length; index++) {
    final character = row[index];
    if (character == '"') {
      if (inQuotes && index + 1 < row.length && row[index + 1] == '"') {
        index++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (character == ',' && !inQuotes) {
      columns++;
    }
  }
  return columns;
}

List<List<String>> _parseCsv(String contents) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var index = 0; index < contents.length; index++) {
    final character = contents[index];
    if (character == '"') {
      if (inQuotes &&
          index + 1 < contents.length &&
          contents[index + 1] == '"') {
        field.write('"');
        index++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (character == ',' && !inQuotes) {
      row.add(field.toString());
      field.clear();
    } else if (character == '\n' && !inQuotes) {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else if (character != '\r' || inQuotes) {
      field.write(character);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

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
