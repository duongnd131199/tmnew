import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const _base = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: 'sans-serif-condensed',
  );

  static const caption = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: 'sans-serif-condensed',
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
  );
  static const bodySmall = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: 'sans-serif-condensed',
    fontSize: 12.5,
  );
  static const bodyMedium = TextStyle(
    fontFamily: 'sans-serif-condensed',
    fontSize: 14,
  );
  static const bodyLarge = TextStyle(
    fontFamily: 'sans-serif-condensed',
    fontSize: 16,
  );
  static const titleSmall = TextStyle(
    fontFamily: 'sans-serif-condensed',
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );
  static const titleMedium = TextStyle(
    fontFamily: 'sans-serif-condensed',
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const referenceServerName = TextStyle(
    fontFamily: 'sans-serif',
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const titleLarge = TextStyle(
    fontFamily: 'sans-serif-condensed',
    fontSize: 26,
    fontWeight: FontWeight.w600,
  );
  static const numberSmall = TextStyle(
    fontFamily: 'sans-serif-condensed',
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numberMedium = TextStyle(
    fontFamily: 'sans-serif-condensed',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numberLarge = TextStyle(
    fontFamily: 'sans-serif-condensed',
    fontSize: 26,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextTheme get textTheme =>
      const TextTheme(
        bodySmall: bodySmall,
        bodyMedium: bodyMedium,
        bodyLarge: bodyLarge,
        titleSmall: titleSmall,
        titleMedium: titleMedium,
        titleLarge: titleLarge,
        labelSmall: caption,
        headlineSmall: numberLarge,
      ).apply(
        bodyColor: _base.color,
        displayColor: _base.color,
        fontFamily: _base.fontFamily,
      );
}
