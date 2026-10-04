import 'package:exness/features/insights/presentation/insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recorded insights preview shows cards, signals and events', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: InsightsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thông tin chuyên sâu'), findsOneWidget);
    expect(find.byKey(const Key('insights-symbol-XPD/USD')), findsOneWidget);
    expect(find.byKey(const Key('insights-symbol-XAG/USD')), findsOneWidget);
    expect(find.byKey(const Key('insights-signal-05:08')), findsOneWidget);
    expect(find.text('Bầu cử Quốc hội'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('insights-event-RU')));
    await tester.pumpAndSettle();
    expect(find.textContaining('07:00:00 Ngày mai'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
