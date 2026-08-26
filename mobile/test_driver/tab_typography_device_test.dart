import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputDirectory = Directory(
    '../docs/screenshots/tab-typography-parity',
  );
  await outputDirectory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [arguments]) async {
      await File('${outputDirectory.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
    writeResponseOnFailure: true,
  );
}
