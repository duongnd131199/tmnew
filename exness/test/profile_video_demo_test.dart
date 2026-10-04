import 'package:exness/features/profile/presentation/profile_screen.dart';
import 'package:exness/features/profile/presentation/settings_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile preview shows recorded loyalty and verification state', (
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
        child: MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Bronze'), findsOneWidget);
    expect(find.text('0,15 EXD'), findsOneWidget);
    expect(find.text('Đã xác minh (Cơ bản)'), findsOneWidget);
    expect(find.text('Đủ điều kiện'), findsOneWidget);

    await tester.scrollUntilVisible(find.textContaining('90.21 USD'), 240);
    expect(find.text('2,00 USD'), findsOneWidget);
    expect(find.text('Trung tâm Hỗ trợ Khách hàng'), findsOneWidget);
  });

  testWidgets('settings preview uses the recorded security choices locally', (
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
        child: MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Điện thoại'), findsOneWidget);
    expect(find.text('10 phút'), findsOneWidget);
    final face = find.byKey(const Key('face-id-switch'));
    final balance = find.byKey(const Key('hide-balance-switch'));
    expect(tester.widget<CupertinoSwitch>(face).value, isTrue);
    expect(tester.widget<CupertinoSwitch>(balance).value, isFalse);

    await tester.tap(face);
    await tester.pumpAndSettle();
    expect(tester.widget<CupertinoSwitch>(face).value, isFalse);
    expect(tester.widget<CupertinoSwitch>(balance).value, isFalse);
  });
}
