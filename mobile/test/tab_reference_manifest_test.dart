import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'test_support/tab_reference_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seven canonical references are 590x1280 and map to unique states', () async {
    expect(tabReferenceCases, hasLength(7));
    expect(tabReferenceCases.map((item) => item.id).toSet(), hasLength(7));
    expect(tabReferenceLogicalSize.width, closeTo(393.3333333333, .0001));
    expect(tabReferenceLogicalSize.height, closeTo(853.3333333333, .0001));
    expect(tabReferenceDevicePixelRatio, 1.5);
    for (final item in tabReferenceCases) {
      final codec = await ui.instantiateImageCodec(
        await File(item.referencePath).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 590, reason: item.id);
      expect(frame.image.height, 1280, reason: item.id);
    }
  });

  test('production declares deterministic reference font assets', () {
    final yaml = File('pubspec.yaml').readAsStringSync();
    for (final token in <String>[
      'family: Mt5Roboto',
      'family: Mt5RobotoCondensed',
      'assets/fonts/Roboto-Regular.ttf',
      'assets/fonts/Roboto-Medium.ttf',
      'assets/fonts/Roboto-Bold.ttf',
      'assets/fonts/RobotoCondensed-Regular.ttf',
      'assets/fonts/RobotoCondensed-Medium.ttf',
      'assets/fonts/RobotoCondensed-Bold.ttf',
    ]) {
      expect(yaml, contains(token), reason: token);
    }
  });
}
