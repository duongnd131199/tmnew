import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launcher matches the MetaTrader 5 sample', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:label="@string/app_name"'));
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(strings, contains('<string name="app_name">MetaTrader 5</string>'));

    for (final density in const [
      'mdpi',
      'hdpi',
      'xhdpi',
      'xxhdpi',
      'xxxhdpi',
    ]) {
      final icon = File(
        'android/app/src/main/res/mipmap-$density/ic_launcher.png',
      );
      expect(icon.existsSync(), isTrue, reason: 'missing $density icon');
      expect(
        icon.lengthSync(),
        greaterThan(1000),
        reason: '$density icon is still the Flutter placeholder',
      );
    }
  });

  test('Android app does not request external storage permissions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    for (final permission in const [
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'MANAGE_EXTERNAL_STORAGE',
      'READ_MEDIA_IMAGES',
      'READ_MEDIA_VIDEO',
      'READ_MEDIA_AUDIO',
    ]) {
      expect(manifest, isNot(contains(permission)));
    }
  });

  test('MainActivity does not request runtime storage permissions', () {
    final source = File(
      'android/app/src/main/kotlin/com/tradingdemo/trading_mobile/'
      'MainActivity.kt',
    ).readAsStringSync();

    expect(source, isNot(contains('requestPermissions')));
    expect(source, isNot(contains('READ_EXTERNAL_STORAGE')));
    expect(source, isNot(contains('WRITE_EXTERNAL_STORAGE')));
  });
}
