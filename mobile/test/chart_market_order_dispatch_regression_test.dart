import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chart market orders are not protected by the pending-order lock', () {
    final source = File(
      'lib/features/chart/presentation/screens/chart_screen.dart',
    ).readAsStringSync();
    final marketStart = source.indexOf('Future<bool> _placeChartOrder(');
    final pendingStart = source.indexOf(
      'Future<bool> _placeChartPendingOrder(',
      marketStart,
    );
    final marketMethod = source.substring(marketStart, pendingStart);

    expect(marketMethod, isNot(contains('_tradingCommandPending')));
    expect(
      source.substring(pendingStart),
      contains('if (_tradingCommandPending) return false;'),
    );
  });
}
