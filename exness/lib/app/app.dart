import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class ExnessApp extends StatelessWidget {
  const ExnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Exness',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
