import 'package:flutter/services.dart';

Future<void> loadMt5TestFonts() async {
  await _loadFamily('MaterialIcons', const ['fonts/MaterialIcons-Regular.otf']);
  await _loadFamily('packages/cupertino_icons/CupertinoIcons', const [
    'packages/cupertino_icons/assets/CupertinoIcons.ttf',
  ]);
  await _loadFamily('Mt5Roboto', const [
    'assets/fonts/Roboto-Regular.ttf',
    'assets/fonts/Roboto-Medium.ttf',
    'assets/fonts/Roboto-Bold.ttf',
  ]);
  await _loadFamily('Mt5RobotoCondensed', const [
    'assets/fonts/RobotoCondensed-Regular.ttf',
    'assets/fonts/RobotoCondensed-Medium.ttf',
    'assets/fonts/RobotoCondensed-Bold.ttf',
  ]);
}

Future<void> _loadFamily(String family, List<String> assetPaths) async {
  final loader = FontLoader(family);
  for (final path in assetPaths) {
    loader.addFont(rootBundle.load(path));
  }
  await loader.load();
}
