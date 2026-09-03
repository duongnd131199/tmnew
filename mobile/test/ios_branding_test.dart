import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectRoot = Directory.current;
  final infoPlist = File('${projectRoot.path}/ios/Runner/Info.plist');
  final launcher = File(
    '${projectRoot.path}/assets/images/metatrader5_launcher.png',
  );
  final splash = File(
    '${projectRoot.path}/assets/images/metatrader5_splash.png',
  );

  test(
    'installed iOS app is displayed as MetaTrader 5',
    () async {
      final result = await Process.run('plutil', [
        '-extract',
        'CFBundleDisplayName',
        'raw',
        infoPlist.path,
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout.toString().trim(), 'MetaTrader 5');
    },
    skip: Platform.isMacOS ? false : 'iOS configuration requires macOS',
  );

  test(
    'iOS home-screen icons are generated from the repository launcher',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'ios-branding-test-',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));

      await _expectOpaqueResize(
        source: launcher,
        actual: File(
          '${projectRoot.path}/ios/Runner/Assets.xcassets/'
          'AppIcon.appiconset/Icon-App-1024x1024@1x.png',
        ),
        width: 1024,
        height: 1024,
        temporaryDirectory: temporaryDirectory,
      );
      await _expectOpaqueResize(
        source: launcher,
        actual: File(
          '${projectRoot.path}/ios/Runner/Assets.xcassets/'
          'AppIcon.appiconset/Icon-App-60x60@3x.png',
        ),
        width: 180,
        height: 180,
        temporaryDirectory: temporaryDirectory,
      );
    },
    skip: Platform.isMacOS ? false : 'iOS assets require macOS sips',
  );

  test(
    'iOS native launch image is generated from the repository splash',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'ios-splash-test-',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final expected = File('${temporaryDirectory.path}/expected.png');

      await _runSips(['-z', '597', '825', splash.path, '--out', expected.path]);

      final actual = File(
        '${projectRoot.path}/ios/Runner/Assets.xcassets/'
        'LaunchImage.imageset/LaunchImage@3x.png',
      );
      expect(await actual.readAsBytes(), await expected.readAsBytes());
    },
    skip: Platform.isMacOS ? false : 'iOS assets require macOS sips',
  );
}

Future<void> _expectOpaqueResize({
  required File source,
  required File actual,
  required int width,
  required int height,
  required Directory temporaryDirectory,
}) async {
  final suffix = '${width}x$height';
  final jpeg = File('${temporaryDirectory.path}/$suffix.jpg');
  final expected = File('${temporaryDirectory.path}/$suffix.png');

  await _runSips([
    '-z',
    '$height',
    '$width',
    '-s',
    'format',
    'jpeg',
    '-s',
    'formatOptions',
    '100',
    source.path,
    '--out',
    jpeg.path,
  ]);
  await _runSips(['-s', 'format', 'png', jpeg.path, '--out', expected.path]);

  expect(await actual.readAsBytes(), await expected.readAsBytes());
}

Future<void> _runSips(List<String> arguments) async {
  final result = await Process.run('sips', arguments);
  expect(result.exitCode, 0, reason: result.stderr.toString());
}
