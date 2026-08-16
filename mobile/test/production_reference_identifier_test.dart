import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Dart excludes recorded account and server identifiers', () {
    const prohibited = <String>{
      '28210230',
      '463696038',
      '425302695',
      '425297911',
      'Exness-MT5Trial17',
      'Exness-MT5Real15',
      'Exness-MT5Real20',
    };
    final hits = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final contents = file.readAsStringSync();
      for (final identifier in prohibited) {
        if (contents.contains(identifier)) {
          hits.add('${file.path}: $identifier');
        }
      }
    }

    expect(hits, isEmpty);
  });
}
