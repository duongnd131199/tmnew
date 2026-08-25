import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/app/app.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  testWidgets('application starts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: videoReferenceOverrides,
        child: const TradingApp(),
      ),
    );

    expect(find.text('Số dư:'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pumpAndSettle();

    expect(find.text('Số dư:'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('XAUUSD', findRichText: true), findsWidgets);
    expect(find.textContaining('XAUUSD+', findRichText: true), findsNothing);
  });
}
