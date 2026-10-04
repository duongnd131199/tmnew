import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF8F9FB);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF20252E);
  static const textSecondary = Color(0xFF767C85);
  static const accent = Color(0xFFFFDC00);
  static const border = Color(0xFFE8E9EC);
  static const muted = Color(0xFFF0F2F6);
  static const blue = Color(0xFF3483D4);
  static const bitcoin = Color(0xFFF7931A);
  static const ethereum = Color(0xFF69717A);
  static const positive = Color(0xFF259F71);
  static const negative = Color(0xFFCB4650);
  static const chart = Color(0xFFFFF0F0);
  static const iconSurface = Color(0xFFF0F2F6);
  static const infoSurface = Color(0xFFF5F7FA);
  static const bronzeStart = Color(0xFF251512);
  static const bronzeEnd = Color(0xFF694436);
  static const bronzeText = Color(0xFFF4E8E2);
  static const dangerSurface = Color(0xFFFFECEF);
  static const referralSurface = Color(0xFFF5EDFF);
  static const referral = Color(0xFF823EC0);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const section = 36.0;
  static const rowVertical = 12.0;
}

abstract final class AppRadius {
  static const card = 8.0;
  static const button = 4.0;
  static const sheet = 13.0;
}

abstract final class AppSizes {
  static const profileHeaderCollapsed = 44.0;
  static const profileHeaderExpanded = 105.0;
  static const profileBannerHeight = 110.0;
  static const profileIconRadius = 21.0;
  static const profileIconSize = 20.0;
  static const sheetHeaderHeight = 66.0;
  static const sheetHeightFraction = 0.935;
  static const settingsTrailingMax = 120.0;
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 29,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      labelMedium: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      labelSmall: TextStyle(color: AppColors.textSecondary, fontSize: 11),
    ),
  );
}
