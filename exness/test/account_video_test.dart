import 'package:exness/features/account/presentation/account_screen.dart';
import 'package:exness/features/account/presentation/video_account_screen.dart';
import 'package:exness/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('video account preview fits a 360 pixel wide screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AccountScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('account-details')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('video account preview shows recorded account and suggestions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AccountScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0.06 USD và 0.06 EXD'), findsOneWidget);
    expect(find.text('MỖI NGÀY MỘT TỶ 🍀'), findsOneWidget);
    expect(find.text('0,00 USD'), findsOneWidget);
    expect(find.text('4.378,101'), findsOneWidget);
  });

  testWidgets('video account bell opens local notifications', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AccountScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo'), findsOneWidget);
  });

  testWidgets('video account switches to recorded closed history', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AccountScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('9/9/26'), findsOneWidget);
    expect(find.text('-40,75 USD'), findsOneWidget);
    expect(find.text('-17,88 USD'), findsOneWidget);
    expect(
      find.text('Không có lệnh mở. Tìm cơ hội giao dịch tiếp theo:'),
      findsNothing,
    );
  });

  testWidgets('video account detail switches from settings to funds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AccountScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account-details')));
    await tester.pumpAndSettle();
    expect(find.text('Exness-MT5Real6'), findsOneWidget);
    expect(find.text('Chênh lệch tối thiểu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-detail-tab-0')));
    await tester.pumpAndSettle();
    expect(find.text('Tiền Ký Quỹ Khả Dụng'), findsOneWidget);
    expect(find.text('1:2000'), findsOneWidget);
  });

  testWidgets(
    'video account detail sheet matches recorded top and close icon',
    (tester) async {
      tester.view.physicalSize = const Size(384, 848);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: AccountScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-details')));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byType(VideoAccountDetailSheet)).dy,
        closeTo(63, 1),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.close)).color,
        AppColors.textPrimary,
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(VideoAccountDetailSheet), findsNothing);
    },
  );
}
