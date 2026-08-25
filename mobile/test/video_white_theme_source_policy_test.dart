import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production presentation has no unexplained dark neutral literals', () {
    final roots = <Directory>[
      Directory('lib/core/theme'),
      Directory('lib/features'),
      Directory('lib/shared/widgets'),
    ];
    final forbidden = RegExp(
      r'Color\((?:0xFF(?:000000|09090A|101010|111111|111112|121212|151516|171719|19191A|1B1B1B|1C1C1E|272728|2C2C2E|333333|373739|38383A)|0x99000000)\)',
    );
    final allowlisted = <String>{
      // The palette owns the canonical dark foreground role.
      'lib/core/theme/app_colors.dart',
      // The native Chart has a separately verified, injected light theme.
      'lib/features/chart/presentation/theme/chart_reference_theme.dart',
    };
    final hits = <String>[];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (allowlisted.contains(path)) continue;
        for (final match in forbidden.allMatches(entity.readAsStringSync())) {
          hits.add('$path:${match.start}:${match.group(0)}');
        }
      }
    }

    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('shared toolbar painters honor the injected light foreground', () {
    final source = File(
      'lib/shared/widgets/mt5_toolbar_icons.dart',
    ).readAsStringSync();

    expect(source, contains('this.color = AppColors.navigationUnselected'));
    expect(source, isNot(contains('Color(0xFFFFFFFF)')));
  });
}
