import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec build metadata is a legal Android version code', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*[^+\s]+\+(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec version needs build metadata');
    final versionCode = int.tryParse(match!.group(1)!);
    expect(versionCode, isNotNull, reason: 'build metadata must be an integer');
    expect(versionCode, inInclusiveRange(1, 2100000000));
  });
}
