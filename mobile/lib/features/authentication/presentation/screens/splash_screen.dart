import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(milliseconds: 1190), () {
      if (mounted) context.go('/trade');
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: IgnorePointer(child: _MetaTraderSplashOverlay()));
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
