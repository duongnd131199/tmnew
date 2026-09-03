import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';

class MtTabHeaderFade extends StatelessWidget {
  const MtTabHeaderFade({required this.decorationKey, super.key});

  final Key decorationKey;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).brightness == Brightness.dark
        ? AppColors.tradeDarkBackground
        : AppColors.background;
    return DecoratedBox(
      key: decorationKey,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            background.withValues(alpha: .88),
            background.withValues(alpha: .80),
            background.withValues(alpha: 0),
          ],
          stops: const [0, .72, 1],
        ),
      ),
    );
  }
}

class MtTabNavigationFade extends StatelessWidget {
  const MtTabNavigationFade({required this.decorationKey, super.key});

  final Key decorationKey;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).brightness == Brightness.dark
        ? AppColors.tradeDarkBackground
        : AppColors.background;
    return DecoratedBox(
      key: decorationKey,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            background.withValues(alpha: 0),
            background.withValues(alpha: .80),
            background.withValues(alpha: .88),
          ],
          stops: const [0, .28, 1],
        ),
      ),
    );
  }
}
