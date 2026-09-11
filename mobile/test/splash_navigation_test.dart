import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/features/authentication/presentation/screens/splash_screen.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

void main() {
  testWidgets('startup mounts one Trade screen without an overlapping route', (
    tester,
  ) async {
    addTearDown(() => appRouter.go('/'));
    appRouter.go('/');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chartMarketWarmupProvider.overrideWith((ref) async {})],
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.iOS),
          routerConfig: appRouter,
        ),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(TradeScreen), findsNothing);
    expect(find.byType(MtBottomNavigationBar), findsNothing);

    await tester.pump(const Duration(milliseconds: 1189));

    expect(appRouter.state.uri.path, '/');
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(appRouter.state.uri.path, '/trade');
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(TradeScreen), findsOneWidget);
    expect(find.byType(MtBottomNavigationBar), findsOneWidget);
  });
}
