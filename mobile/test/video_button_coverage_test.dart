import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/settings_screen.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  testWidgets('history starts on positions and applies the symbol filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: videoReferenceOverrides,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();

    final positionsList = tester.widget<ListView>(
      find.byKey(const PageStorageKey('history-positions-list')),
    );
    positionsList.controller!.jumpTo(0);
    await tester.pump();

    expect(
      find.byKey(const Key('history-position-small-history-0')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('history-period-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history-symbol-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('XAUUSD').last);
    await tester.pumpAndSettle();
    expect(find.text('XAUUSD'), findsWidgets);

    await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-period-button')));
    await tester.pumpAndSettle();
    expect(find.text('XAUUSD'), findsWidgets);
  });

  testWidgets('settings chevron rows navigate instead of remaining inert', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/section',
          builder: (context, state) => Scaffold(
            body: Text('Trang ${state.uri.queryParameters['title'] ?? ''}'),
          ),
        ),
        for (final path in const [
          '/profile',
          '/register',
          '/messages',
          '/chart',
        ])
          GoRoute(
            path: path,
            builder: (context, state) => Scaffold(body: Text(path)),
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-Tin tuc')));
    await tester.pumpAndSettle();

    expect(find.text('Trang Tin tuc'), findsOneWidget);
  });
}
