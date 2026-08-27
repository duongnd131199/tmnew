import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/profile/presentation/screens/settings_screen.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/video_reference_fixtures.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';
import 'package:trading_mobile/shared/widgets/mt5_settings_icons.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';

void main() {
  testWidgets('settings icons render the complete vector set without images', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final kind in MtSettingsIconKind.values)
              MtSettingsIcon(key: ValueKey(kind), kind),
          ],
        ),
      ),
    );

    expect(MtSettingsIconKind.values, hasLength(12));
    expect(find.byType(Image), findsNothing);
    for (final kind in MtSettingsIconKind.values) {
      expect(tester.getSize(find.byKey(ValueKey(kind))), const Size(29, 29));
    }
  });

  testWidgets('settings account header renders canonical broker metadata', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(288, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDemoAccountProvider.overrideWithValue(_exnessAccount),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text(_exnessAccount.name), findsOneWidget);
    expect(find.text('Exness Technologies Ltd'), findsOneWidget);
    expect(
      find.text('109740422 - Exness-MT5Real20\nAccess Point #9'),
      findsOneWidget,
    );
    expect(find.text('active'), findsNothing);
    expect(find.textContaining('trochoi.top'), findsNothing);
    expect(find.text('EX V2'), findsNothing);

    final name = find.byKey(const Key('settings-account-name'));
    final company = find.byKey(const Key('settings-account-company'));
    final server = find.byKey(const Key('settings-account-server-access'));
    expect(name, findsOneWidget);
    expect(company, findsOneWidget);
    expect(server, findsOneWidget);
    expect(tester.getCenter(name).dx, inInclusiveRange(144, 146));
    expect(tester.getCenter(company).dx, inInclusiveRange(144, 146));
    expect(tester.getCenter(server).dx, inInclusiveRange(144, 146));
    expect(tester.getTopLeft(name).dy, lessThan(tester.getTopLeft(company).dy));
    expect(
      tester.getTopLeft(company).dy,
      lessThan(tester.getTopLeft(server).dy),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('settings-account')),
        matching: find.byKey(const Key('account-chevron-glyph')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings renders every static label exactly as recorded', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();

    for (final text in const [
      'Cai dat',
      'Tai khoan moi',
      'Hop thu',
      'You have registered a new acco...',
      'Tin tuc',
      'Australian Dollar: RBA keeps hik...',
      'Tradays',
      'Lich Kinh Te',
      'Trao doi va tin nhan',
      'Dang nhap vao cong dong MQ...',
      'Cong dong trader',
      'MQL5 Algo Trading',
    ]) {
      expect(find.text(text), findsWidgets, reason: 'Missing "$text"');
    }

    for (final oldText in const [
      'Cài đặt',
      'Tài khoản mới',
      'Hộp thư',
      'Tin tức',
      'Lịch Kinh Tế',
      'Trao đổi và tin nhắn',
      'Đăng nhập vào cộng đồng MQ...',
      'Cộng đồng trader',
    ]) {
      expect(find.text(oldText), findsNothing, reason: 'Unexpected "$oldText"');
    }

    await tester.scrollUntilVisible(
      find.text('Nhung bieu do'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    for (final text in const [
      'OTP',
      'Khoi tao mat khau mot lan',
      'Giao dien',
      'Tieng Viet',
      'Nhung bieu do',
      'Nhat ky',
      'Cai dat',
    ]) {
      expect(find.text(text), findsWidgets, reason: 'Missing "$text"');
    }

    for (final oldText in const [
      'Khởi tạo mật khẩu một lần',
      'Giao diện',
      'Tiếng Việt',
      'Nhúng biểu đồ',
      'Nhật ký',
    ]) {
      expect(find.text(oldText), findsNothing, reason: 'Unexpected "$oldText"');
    }
  });

  testWidgets('settings matches the video 2 account card and divider', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );

    expect(find.text('Demo Account One'), findsOneWidget);
    expect(find.text('Demo Markets Ltd'), findsOneWidget);

    final accountIcon = find.byKey(const Key('settings-icon-Tai khoan moi'));
    final notificationBadge = find.byKey(
      const Key('settings-notification-Trao doi va tin nhan'),
    );
    final communityIcon = find.byKey(
      const Key('settings-icon-Trao doi va tin nhan'),
    );
    final connectedIndicator = find.byKey(
      const Key('settings-connected-indicator'),
    );
    expect(tester.getSize(accountIcon), const Size(29, 29));
    expect(tester.getSize(notificationBadge), const Size(21, 21));
    expect(tester.getSize(connectedIndicator), const Size(29, 29));
    expect(
      find.descendant(
        of: connectedIndicator,
        matching: find.byKey(const Key('settings-connected-glyph')),
      ),
      findsOneWidget,
    );

    final iconOrigin = tester.getTopLeft(accountIcon);
    final communityIconOrigin = tester.getTopLeft(communityIcon);
    final titleOrigin = tester.getTopLeft(find.text('Tai khoan moi'));
    final badgeOrigin = tester.getTopLeft(notificationBadge);
    expect(titleOrigin.dx - iconOrigin.dx, closeTo(42.3333333333, .01));
    expect(badgeOrigin.dx - communityIconOrigin.dx, closeTo(13, .01));
    expect(badgeOrigin.dy - communityIconOrigin.dy, closeTo(-7.3, .01));

    final accountRow = find.byKey(const Key('settings-Tai khoan moi'));
    final accountChevron = find.descendant(
      of: accountRow,
      matching: find.byKey(const Key('settings-row-chevron')),
    );
    expect(tester.getSize(accountChevron), const Size(18, 18));

    expect(find.byKey(const Key('settings-account-accent')), findsNothing);
    final divider = find.byKey(const Key('settings-account-divider'));
    expect(divider, findsOneWidget);
    expect(tester.getSize(divider).height, .5);
    expect(tester.widget<Divider>(divider).color, AppColors.divider);

    final scrollView = tester.widget<ListView>(
      find.byKey(const Key('settings-scroll-view')),
    );
    expect(scrollView.physics, isA<BouncingScrollPhysics>());
    expect(
      (scrollView.physics! as BouncingScrollPhysics).parent,
      isA<AlwaysScrollableScrollPhysics>(),
    );

    expect(find.bySemanticsLabel('Tai khoan moi'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(r'Trao doi va tin nhan.*2 thông báo.*Đã kết nối'),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Nhung bieu do'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhung bieu do'), findsOneWidget);
    expect(find.text('Nhat ky'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('trade navigation follows loss, flat and profit colors', (
    tester,
  ) async {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MtBottomNavigationBar(
              selectedIndex: 2,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );

    Text selectedLabel() => tester.widget<Text>(find.text('Giao dich'));

    expect(
      find.byKey(const ValueKey('bottom-nav-icon-quotes')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bottom-nav-icon-chart')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bottom-nav-icon-history')),
      findsOneWidget,
    );
    final settingsIcon = find.byKey(
      const ValueKey('bottom-nav-icon-settings'),
    );
    expect(settingsIcon, findsOneWidget);
    expect(tester.widget(settingsIcon), isA<CustomPaint>());
    expect(selectedLabel().style?.color, AppColors.negative);

    container.read(activeDemoAccountIdProvider.notifier).select('10001003');
    await tester.pump();
    expect(selectedLabel().style?.color, AppColors.primary);

    container.read(activeDemoAccountIdProvider.notifier).select('10001001');
    container
        .read(demoTradingProvider.notifier)
        .updateMarketPrice(symbol: 'XAUUSD+', bid: 4105.51, ask: 4105.64);
    await tester.pump();
    expect(selectedLabel().style?.color, AppColors.primary);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MtBottomNavigationBar(
              selectedIndex: 4,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Cai dat')).style?.color,
      AppColors.primary,
    );
  });
}

const _exnessAccount = DemoAccountProfile(
  id: '109740422',
  name: 'Mỗi Ngày Một Tỷ 🍀',
  company: 'Exness Technologies Ltd',
  server: 'Exness-MT5Real20',
  accessPoint: 'Access Point #9',
  balance: 154763.90,
  brand: DemoBrokerBrand.exness,
  historyDeposit: 0,
  historyWithdrawal: 0,
  historyProfit: 0,
  historySwap: 0,
  historyCommission: 0,
  historyBalance: 154763.90,
);
