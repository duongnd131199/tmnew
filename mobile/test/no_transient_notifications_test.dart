import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production screens never display transient notifications', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (RegExp(r'\b(?:showSnackBar|SnackBar)\s*\(').hasMatch(source)) {
        violations.add(entity.path);
      }
    }

    expect(violations, isEmpty);
  });
}
