import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _navigationTimer = Timer(const Duration(milliseconds: 90), () {
      if (mounted) _fadeController.forward();
    });
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go('/trade');
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOutCubic),
    );
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: TradeScreen()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: MtBottomNavigationBar(selectedIndex: 2, onTap: (_) {}),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: opacity,
                child: const _MetaTraderSplashOverlay(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTraderSplashOverlay extends StatelessWidget {
  const _MetaTraderSplashOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.1),
          radius: 1.08,
          colors: [
            Color(0xFFF0F4ED),
            Color(0xFFD7EFEC),
            Color(0xFF88D7E5),
            Color(0xFF229FD0),
            Color(0xFF087DB8),
          ],
          stops: [0, .24, .52, .79, 1],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -.08),
        child: Transform.translate(
          offset: const Offset(0, -5),
          child: const Image(
            image: AssetImage('assets/images/metatrader5_splash.png'),
            width: 275.3333333333,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
