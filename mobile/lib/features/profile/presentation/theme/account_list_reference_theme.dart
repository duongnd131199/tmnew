import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';

abstract final class AccountListReferenceColors {
  static const activeName = Color(0xFF0098FF);
  static const readOnlySurface = AppColors.surfaceElevated;
  static const readOnlyBorder = AppColors.textTertiary;
  static const readOnlyText = AppColors.textSecondary;
}

abstract final class AccountListReferenceMetrics {
  static const readOnlyGap = 8.0;
  static const readOnlySize = Size(70, 21);
  static const readOnlyRadius = 10.5;
}

abstract final class AccountListReferenceTypography {
  static const toolbarTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: AppTypography.referencePlainFamily,
    fontSize: 18.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
  );

  static const activeName = TextStyle(
    color: AccountListReferenceColors.activeName,
    fontFamily: AppTypography.referencePlainFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    letterSpacing: .95,
    height: 1,
  );

  static const inactiveName = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: AppTypography.referencePlainFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w400,
    letterSpacing: .95,
    height: 1,
  );

  static const trailingEmojiGap = TextStyle(
    fontSize: 13.5,
    letterSpacing: 0,
    height: 1,
  );

  static const trailingEmoji = TextStyle(
    fontSize: 20.5,
    letterSpacing: 0,
    height: 1,
  );

  static const activeMetadata = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: AppTypography.referencePlainFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    letterSpacing: .4,
    height: 1,
  );

  static const inactiveMetadata = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: AppTypography.referencePlainFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    letterSpacing: .4,
    height: 1,
  );

  static const readOnly = TextStyle(
    color: AccountListReferenceColors.readOnlyText,
    fontFamily: AppTypography.referenceCondensedFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
  );
}
