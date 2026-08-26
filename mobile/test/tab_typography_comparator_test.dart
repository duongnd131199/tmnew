import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../tool/compare_tab_typography.dart' as comparator;
import 'test_support/tab_reference_manifest.dart';

void main() {
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
