import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../tool/compare_tab_typography.dart' as comparator;
import 'test_support/tab_reference_manifest.dart';

void main() {
  test('canonical tab renderings match reference optical ink density', () {
    final output = StringBuffer();
    final errors = StringBuffer();

    final result = comparator.runTabTypographyComparison(
      const [],
      standardOutput: output,
      errorOutput: errors,
    );

    expect(result, 0, reason: '$output\n$errors');
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
    'comparator rejects visibly heavier glyphs with unchanged bounds and ink',
    () async {
      final candidateDirectory = await Directory.systemTemp.createTemp(
        'mt5-tab-density-comparator-',
      );
      addTearDown(() => candidateDirectory.delete(recursive: true));

      for (final referenceCase in tabReferenceCases) {
        await File(
          'test/goldens/tab-typography/'
          '${referenceCase.id}-590x1280.png',
        ).copy('${candidateDirectory.path}/${referenceCase.id}-590x1280.png');
      }

      final pricesCase = tabReferenceCases.singleWhere(
        (referenceCase) => referenceCase.id == 'prices',
      );
      final symbolRegion = pricesCase.staticTextRegions.singleWhere(
        (region) => region.name == 'quote-symbol',
      );
      final pricesFile = File('${candidateDirectory.path}/prices-590x1280.png');
      final prices = image.decodePng(await pricesFile.readAsBytes())!;
      const ink = (red: 0, green: 0, blue: 0);

      for (var pass = 0; pass < 2; pass++) {
        final solidInk = <(int, int)>{};
        for (
          var y = symbolRegion.candidateRect.top;
          y < symbolRegion.candidateRect.bottom;
          y++
        ) {
          for (
            var x = symbolRegion.candidateRect.left;
            x < symbolRegion.candidateRect.right;
            x++
          ) {
            final pixel = prices.getPixel(x, y);
            if (pixel.r == ink.red &&
                pixel.g == ink.green &&
                pixel.b == ink.blue) {
              solidInk.add((x, y));
            }
          }
        }
        final left = solidInk
            .map((pixel) => pixel.$1)
            .reduce((a, b) => a < b ? a : b);
        final right = solidInk
            .map((pixel) => pixel.$1)
            .reduce((a, b) => a > b ? a : b);
        final top = solidInk
            .map((pixel) => pixel.$2)
            .reduce((a, b) => a < b ? a : b);
        final bottom = solidInk
            .map((pixel) => pixel.$2)
            .reduce((a, b) => a > b ? a : b);
        final additions = <(int, int)>{};
        for (final pixel in solidInk) {
          for (final offset in const <(int, int)>[
            (-1, 0),
            (1, 0),
            (0, -1),
            (0, 1),
          ]) {
            final x = pixel.$1 + offset.$1;
            final y = pixel.$2 + offset.$2;
            if (x >= left && x <= right && y >= top && y <= bottom) {
              additions.add((x, y));
            }
          }
        }
        for (final pixel in additions) {
          prices.setPixelRgba(
            pixel.$1,
            pixel.$2,
            ink.red,
            ink.green,
            ink.blue,
            255,
          );
        }
      }
      await pricesFile.writeAsBytes(image.encodePng(prices));

      final output = StringBuffer();
      final errors = StringBuffer();
      final result = comparator.runTabTypographyComparison(
        ['--candidate-dir', candidateDirectory.path],
        standardOutput: output,
        errorOutput: errors,
      );

      expect(result, 1, reason: '$output\n$errors');
      expect('$output$errors', contains('ink density'));
    },
  );

  test('comparator rejects semantic ink shifted beyond six channels', () async {
    final candidateDirectory = await Directory.systemTemp.createTemp(
      'mt5-tab-comparator-',
    );
    addTearDown(() => candidateDirectory.delete(recursive: true));

    for (final referenceCase in tabReferenceCases) {
      await File(
        'test/goldens/tab-typography/'
        '${referenceCase.id}-590x1280.png',
      ).copy('${candidateDirectory.path}/${referenceCase.id}-590x1280.png');
    }

    final pricesFile = File('${candidateDirectory.path}/prices-590x1280.png');
    final prices = image.decodePng(await pricesFile.readAsBytes())!;
    for (var y = 0; y < prices.height; y++) {
      for (var x = 0; x < prices.width; x++) {
        final pixel = prices.getPixel(x, y);
        final distance = <int>[
          pixel.r.toInt(),
          (pixel.g.toInt() - 127).abs(),
          (pixel.b.toInt() - 255).abs(),
        ].reduce((left, right) => left > right ? left : right);
        if (distance <= 48) prices.setPixelRgba(x, y, 0, 147, 255, 255);
      }
    }
    await pricesFile.writeAsBytes(image.encodePng(prices));

    final output = StringBuffer();
    final errors = StringBuffer();
    final result = comparator.runTabTypographyComparison(
      ['--candidate-dir', candidateDirectory.path],
      standardOutput: output,
      errorOutput: errors,
    );

    expect(result, 1, reason: '$output\n$errors');
    expect('$output$errors', contains('Static typography exceeds tolerance'));

    final androidOutput = StringBuffer();
    final androidErrors = StringBuffer();
    final androidResult = comparator.runTabTypographyComparison(
      [
        '--candidate-dir',
        candidateDirectory.path,
        '--candidate-renderer',
        'android',
      ],
      standardOutput: androidOutput,
      errorOutput: androidErrors,
    );
    expect(androidResult, 1, reason: '$androidOutput\n$androidErrors');
  });
}
