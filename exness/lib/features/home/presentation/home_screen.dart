import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Text('Exness', style: textTheme.displaySmall),
              const SizedBox(height: AppSpacing.md),
              Text('Chào mừng bạn', style: textTheme.bodyLarge),
              const Spacer(),
              Text('Ứng dụng giao dịch demo', style: textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
