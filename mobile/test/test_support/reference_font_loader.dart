import 'package:flutter/services.dart';

import 'load_test_fonts.dart';

Future<void> loadReferenceFonts() async {
  await loadMt5TestFonts();
  await _loadReferenceFamily('Mt5ReferenceRoboto', const [
    'assets/fonts/mt5-reference/Roboto-Regular.ttf',
    'assets/fonts/mt5-reference/Roboto-Bold.ttf',
  ]);
  await _loadReferenceFamily('Mt5ReferenceRobotoCondensed', const [
    'assets/fonts/mt5-reference/RobotoCondensed-Regular.ttf',
    'assets/fonts/mt5-reference/RobotoCondensed-Bold.ttf',
  ]);
  await _loadReferenceFamily('Mt5ReferenceRobotoCondensedVariable', const [
    'assets/fonts/RobotoCondensed-Variable.ttf',
  ]);
}

Future<void> _loadReferenceFamily(
  String family,
  List<String> assetPaths,
) async {
  final loader = FontLoader(family);
  for (final path in assetPaths) {
    loader.addFont(rootBundle.load(path));
  }
  await loader.load();
}
