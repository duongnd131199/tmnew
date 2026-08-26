import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';

void main() {
  test('video light palette locks semantic neutral and financial roles', () {
    expect(AppColors.background, const Color(0xFFFFFFFF));
    expect(AppColors.groupedBackground, const Color(0xFFEEEDF5));
    expect(AppColors.surface, const Color(0xFFFFFFFF));
    expect(AppColors.surfaceElevated, const Color(0xFFF5F5F5));
    expect(AppColors.surfaceSelected, const Color(0xFFE4E4E4));
    expect(AppColors.sheetSurface, const Color(0xFFF1F1F1));
    expect(AppColors.sheetActionSurface, const Color(0xFFEAEAEA));
    expect(AppColors.disabledSurface, const Color(0xFFF1F1F1));
    expect(AppColors.primary, const Color(0xFF007AFF));
    expect(AppColors.negative, const Color(0xFFE42D30));
    expect(AppColors.textPrimary, const Color(0xFF000000));
    expect(AppColors.textSecondary, const Color(0xFF3C3C43));
    expect(AppColors.textTertiary, const Color(0xFF9A9A9F));
    expect(AppColors.divider, const Color(0xFFD9D9DE));
  });

  test('production Material theme and Android chrome are light', () {
    final theme = AppTheme.light;
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.colorScheme.onSurface, AppColors.textPrimary);
    expect(theme.bottomSheetTheme.backgroundColor, AppColors.sheetSurface);
    expect(theme.bottomSheetTheme.modalBarrierColor, AppColors.dimBarrier);
    expect(theme.dialogTheme.backgroundColor, AppColors.surface);
    expect(theme.dialogTheme.barrierColor, AppColors.dimBarrier);
    expect(
      AppTheme.systemUiOverlayStyle.statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      AppTheme.systemUiOverlayStyle.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
    expect(
      AppTheme.systemUiOverlayStyle.statusBarColor,
      AppColors.background,
    );
  });
}
