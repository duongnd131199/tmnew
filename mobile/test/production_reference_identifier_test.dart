import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production Dart excludes unapproved recorded financial and trade data',
    () {
      const approvedReferenceCatalogPath =
          'lib/features/account_link/presentation/widgets/'
          'reference_server_catalog.dart';
      const approvedReferenceServerNames = <String>{
        'Exness-MT5Real15',
        'Exness-MT5Real20',
      };
      const prohibited = <String>{
        '28210230',
        '463696038',
        '425302695',
        '425297911',
        'Exness-MT5Trial17',
        'Exness-MT5Real15',
        'Exness-MT5Real20',
        '2292.60',
        '318441.72',
        '-325690.38',
        '21081.96',
        '-11531.70',
        '2301.60',
        '27297978.10',
        '12000119',
        '15297859.10',
        '1231.48',
        '1470684.33',
        '179.00',
        '57360797890',
        '57360798130',
        '57016800413',
        '4078.77',
        '4039.03',
        '4104.09',
        '4104.22',
        '4108.117',
        '4102.396',
        '65175.98',
        '65193.10',
        '2026.07.',
        '2026.07.24 18:04:32',
        '2026.07.27 04:00:49',
        'Cash Adjustment-Debt W/O',
        'Transfer In from 32401745',
        '-41.36',
        '24.24',
        '50.00',
        '100.00%',
        '4063.33',
        '4115.79',
        '3959.93',
        '6 336',
        '6336',
      };
      final hits = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        final contents = file.readAsStringSync();
        final normalizedPath = file.path.replaceAll('\\', '/');
        for (final identifier in prohibited) {
          if (contents.contains(identifier)) {
            if (normalizedPath == approvedReferenceCatalogPath &&
                approvedReferenceServerNames.contains(identifier)) {
              continue;
            }
            hits.add('${file.path}: $identifier');
          }
        }
        if (contents.contains("'Vantage'") || contents.contains('"Vantage"')) {
          hits.add('${file.path}: Vantage string literal');
        }
      }

      expect(hits, isEmpty);
    },
  );
}
