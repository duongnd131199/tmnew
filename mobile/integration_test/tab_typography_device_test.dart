import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/tab_typography_golden_test.dart' as parity;
import '../test/test_support/tab_reference_manifest.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const caseFilter = String.fromEnvironment('TAB_REFERENCE_CASE');
  final cases = caseFilter.isEmpty
      ? tabReferenceCases
      : tabReferenceCases
            .where((referenceCase) => referenceCase.id == caseFilter)
            .toList(growable: false);

  for (final referenceCase in cases) {
    testWidgets('renders ${referenceCase.id} on the Android engine', (
      tester,
    ) async {
      await binding.convertFlutterSurfaceToImage();
      await parity.pumpTabReference(tester, referenceCase.state);
      await tester.pump(const Duration(milliseconds: 500));
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final screenshot = await binding.takeScreenshot(
        'android-${referenceCase.id}-590x1280',
      );
      expect(screenshot, isNotEmpty, reason: referenceCase.id);
      expect(tester.takeException(), isNull, reason: referenceCase.id);
    });
  }
}
