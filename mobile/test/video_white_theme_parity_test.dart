import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/settings_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  testWidgets('bottom navigation uses video white roles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: MtBottomNavigationBar(
              selectedIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final decorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .toList(growable: false);
    expect(
      decorations.any(
        (decoration) => decoration.color == AppColors.navigationSurface,
      ),
      isTrue,
    );
    expect(
      decorations.any(
        (decoration) => decoration.color == AppColors.navigationSelectedSurface,
      ),
      isTrue,
    );

    expect(find.text('Gia'), findsOneWidget);
    expect(find.text('Bieu do'), findsOneWidget);
    expect(find.text('Giao dich'), findsOneWidget);
    expect(find.text('Lich su'), findsOneWidget);
    expect(find.text('Cai dat'), findsOneWidget);

    Color iconColor(String key) {
      final paint = tester.widget<CustomPaint>(find.byKey(ValueKey(key)));
      return (paint.painter! as dynamic).color as Color;
    }

    expect(iconColor('bottom-nav-icon-quotes'), AppColors.primary);
    expect(iconColor('bottom-nav-icon-chart'), AppColors.navigationUnselected);
  });

  testWidgets('Prices uses video white surfaces and symbol sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(384, 848),
              padding: EdgeInsets.only(top: 24),
            ),
            child: MarketWatchScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, anyOf(isNull, AppColors.background));

    await tester.tap(find.text('XAUUSD'));
    await tester.pumpAndSettle();

    final menu = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('market-symbol-menu-XAUUSD+')),
    );
    expect((menu.decoration as BoxDecoration).color, AppColors.sheetSurface);
    final barriers = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .where((barrier) => barrier.color != null)
        .toList(growable: false);
    expect(barriers.last.color, AppColors.dimBarrier);
    expect(find.text('Giao dich'), findsOneWidget);
    expect(find.text('Bieu do'), findsOneWidget);
    expect(find.text('Chi tiet'), findsOneWidget);
    expect(find.text('Depth of Market'), findsOneWidget);
    expect(find.text('Huy'), findsOneWidget);
  });

  testWidgets('Trade position sheet uses video white roles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    final position = container.read(demoPositionsProvider).first;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(384, 848),
              padding: EdgeInsets.only(top: 24),
            ),
            child: TradeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(ValueKey('trade-position-${position.id}')));
    await tester.pumpAndSettle();

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, AppColors.sheetSurface);
    expect(find.text('Đóng trạng thái'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Đóng trạng thái')).style?.color,
      AppColors.negative,
    );
  });

  testWidgets('Trade bulk dialog uses video white roles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(384, 848),
              padding: EdgeInsets.only(top: 24),
            ),
            child: TradeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('trade-bulk-menu')));
    await tester.pumpAndSettle();

    final dialogSurface = tester.widget<DecoratedBox>(
      find.byKey(const Key('trade-bulk-actions-dialog')),
    );
    expect(
      (dialogSurface.decoration as BoxDecoration).color,
      AppColors.sheetSurface,
    );
    final actionDecorations = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byKey(const Key('trade-bulk-actions-dialog')),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      actionDecorations.any(
        (decoration) => decoration.color == AppColors.sheetActionSurface,
      ),
      isTrue,
    );
    expect(find.textContaining('Hoạt động hàng loạt'), findsOneWidget);
  });

  testWidgets('Settings and accounts use video grouped white roles', (
    tester,
  ) async {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);

    Future<void> pumpScreen(Widget screen) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light, home: screen),
        ),
      );
      await tester.pump();
    }

    await pumpScreen(const SettingsScreen());
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.groupedBackground,
    );
    final settingsDecorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>();
    expect(
      settingsDecorations.any(
        (decoration) => decoration.color == AppColors.surface,
      ),
      isTrue,
    );

    await pumpScreen(const ProfileScreen());
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.groupedBackground,
    );
    expect(find.byKey(const Key('accounts-add')), findsOneWidget);
    final accounts = container.read(demoAccountsProvider);
    final nonActiveAccount = accounts.length > 1 ? accounts.last : null;
    if (nonActiveAccount != null) {
      final rowMaterial = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(ValueKey('account-${nonActiveAccount.id}')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(rowMaterial.color, AppColors.surface);
    }
  });
}
