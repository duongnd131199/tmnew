import 'package:flutter/material.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';

class TradingApp extends StatelessWidget {
  const TradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Trading Demo',
      theme: AppTheme.light,
      scrollBehavior: const _TradingScrollBehavior(),
      routerConfig: appRouter,
    );
  }
}

class _TradingScrollBehavior extends MaterialScrollBehavior {
  const _TradingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
