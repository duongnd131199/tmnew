import 'dart:async';

import 'package:exness/app/app.dart';
import 'package:exness/app/router.dart';
import 'package:exness/core/widgets/ex_widgets.dart';
import 'package:exness/core/config/video_demo_mode.dart';
import 'package:exness/features/account/data/account_session.dart';
import 'package:exness/features/account/data/ex_v2_models.dart';
import 'package:exness/features/account/data/device_token_store.dart';
import 'package:exness/features/profile/presentation/profile_screen.dart';
import 'package:exness/features/wallet/presentation/wallet_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'profile shows the server wallet without inventing loyalty data',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoDemoModeProvider.overrideWith((ref) => false),
            accountSessionProvider.overrideWith(() => _Session(_bootstrap())),
            accountSettingsProvider.overrideWith(
              (ref) async => (
                accountId: 'account-1',
                values: {
                  'email': 'person@example.com',
                  'tradeNotificationsEnabled': false,
                },
              ),
            ),
            walletTransactionsProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-screen')), findsOneWidget);
      expect(find.text('Chưa có dữ liệu hạng'), findsOneWidget);
      expect(find.text('Bronze'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('profile-wallet-balance')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2,00 USD'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-wallet-balance')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wallet-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile settings button opens the configured settings sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWith((ref) => false),
          accountSessionProvider.overrideWith(_LoggedOutSession.new),
          accountSettingsProvider.overrideWith(
            (ref) async => (
              accountId: null,
              values: {
                'language': 'Tiếng Việt',
                'tradeNotificationsEnabled': false,
              },
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-list')), findsOneWidget);
    expect(find.text('Tùy chọn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account email is revealed only after tapping its eye control', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWith((ref) => false),
          accountSessionProvider.overrideWith(() => _Session(_bootstrap())),
          accountSettingsProvider.overrideWith(
            (ref) async => (
              accountId: 'account-1',
              values: {'email': 'person@example.com'},
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('p••••@example.com'), findsOneWidget);
    expect(find.text('person@example.com'), findsNothing);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    expect(find.text('person@example.com'), findsOneWidget);
  });

  testWidgets('new account never shows email from previous account', (
    tester,
  ) async {
    final controller = _Session(_bootstrap());
    final nextSettings = Completer<AccountSettingsSnapshot>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWith((ref) => false),
          accountSessionProvider.overrideWith(() => controller),
          accountSettingsProvider.overrideWith((ref) async {
            final session = await ref.watch(accountSessionProvider.future);
            if (session?.account.id == 'account-2') {
              return nextSettings.future;
            }
            return (
              accountId: 'account-1',
              values: {'email': 'old@example.com'},
            );
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('o••••@example.com'), findsOneWidget);

    controller.switchTo(_bootstrap(accountId: 'account-2', walletTotal: 7));
    await tester.pump();
    await tester.pump();

    expect(find.text('7,00 USD'), findsOneWidget);
    expect(find.text('o••••@example.com'), findsNothing);
    nextSettings.complete((
      accountId: 'account-2',
      values: {'email': 'new@example.com'},
    ));
    await tester.pumpAndSettle();
    expect(find.text('n••••@example.com'), findsOneWidget);
  });

  testWidgets('profile logout clears the secure session and signed-in wallet', (
    tester,
  ) async {
    final store = _MemoryTokenStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWith((ref) => false),
          deviceTokenStoreProvider.overrideWithValue(store),
          accountSessionProvider.overrideWith(() => _Session(_bootstrap())),
          accountSettingsProvider.overrideWith(
            (ref) async =>
                (accountId: 'account-1', values: const <String, dynamic>{}),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile-session-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-session-action')));
    await tester.pumpAndSettle();

    expect(store.deleteCalls, 1);
    expect(find.text('Đăng xuất'), findsNothing);
    expect(find.text('2,00 USD'), findsNothing);
  });

  testWidgets('profile settings sheet reaches the video top edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWith((ref) => false),
          accountSessionProvider.overrideWith(_LoggedOutSession.new),
          accountSettingsProvider.overrideWith(
            (ref) async => (accountId: null, values: const <String, dynamic>{}),
          ),
        ],
        child: const ExnessApp(),
      ),
    );
    appRouter.go('/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-settings')));
    await tester.pumpAndSettle();

    final sheetTop = tester.getTopLeft(find.byType(ExSheet).last).dy;
    expect(sheetTop, inInclusiveRange(45, 75));
    final closeLeft = tester.getTopLeft(find.byIcon(Icons.close).last).dx;
    expect(closeLeft, lessThan(50));
  });
}

final class _LoggedOutSession extends AccountSessionController {
  @override
  Future<ExV2Bootstrap?> build() async => null;
}

final class _MemoryTokenStore implements DeviceTokenStore {
  int deleteCalls = 0;

  @override
  Future<void> delete() async => deleteCalls++;

  @override
  Future<String?> read() async => 'device-token';

  @override
  Future<void> write(String token) async {}
}

final class _Session extends AccountSessionController {
  _Session(this._bootstrap);

  final ExV2Bootstrap _bootstrap;

  @override
  Future<ExV2Bootstrap?> build() async => _bootstrap;

  void switchTo(ExV2Bootstrap next) => state = AsyncData(next);
}

ExV2Bootstrap _bootstrap({
  String accountId = 'account-1',
  double walletTotal = 2,
}) => ExV2Bootstrap.fromJson({
  'serverTime': '2026-09-19T00:00:00Z',
  'version': 2,
  'device': {'id': 'device-1', 'name': 'Demo'},
  'activeAccount': {
    'id': accountId,
    'accountCode': '100000001',
    'name': 'Virtual account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': accountId,
    'currency': 'USD',
    'balance': 12.5,
    'equity': 12.5,
    'profit': 0,
    'margin': 0,
    'freeMargin': 12.5,
    'marginLevel': 0,
    'updatedAt': '2026-09-19T00:00:00Z',
  },
  'positions': [],
  'pendingOrders': [],
  'recentDeals': [],
  'wallet': {
    'currency': 'USD',
    'availableBalance': walletTotal,
    'lockedBalance': 0,
    'totalBalance': walletTotal,
  },
  'performance': {
    'netProfit': 0,
    'grossProfit': 0,
    'grossLoss': 0,
    'floatingProfit': 0,
    'tradingVolume': 0,
    'updatedAt': null,
    'integrityWarnings': 0,
  },
  'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
  'integrityWarnings': 0,
});
