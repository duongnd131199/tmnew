import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';

abstract final class AccountLinkReferenceMetrics {
  static const toolbarHeight = 70.0;
  static const toolbarControlTop = 21.0;
  static const toolbarTitleTop = 34.0;
  static const horizontalInset = 18.0;
  static const accountHeaderHeight = 84.0;
  static const accountHeaderControlTop = toolbarControlTop;
  static const accountHeaderBrokerGap = 27.0;
  static const brokerRowHeight = 62.0;
  static const brokerMarkGap = 10.0;
  static const serverHeaderGap = 33.0;
  static const serverRowHeight = 49.0;
  static const sectionHeight = 42.0;
  static const registrationRowHeight = 88.0;
  static const formRowHeight = 49.0;
  static const segmentHeight = 29.0;
  static const searchFieldHeight = 43.0;
  static const loginActionHeight = 76.0;
}

abstract final class AccountLinkReferenceTypography {
  static const _family = AppTypography.plainFamily;

  static const toolbarTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: _family,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  static const brokerName = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: _family,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    height: 1,
  );

  static const brokerCompany = TextStyle(
    color: AppColors.settingsRowSecondary,
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1,
  );

  static const sectionTitle = TextStyle(
    color: AppColors.settingsRowSecondary,
    fontFamily: _family,
    fontSize: 16.5,
    fontWeight: FontWeight.w600,
    height: 1,
  );

  static const registrationTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: _family,
    fontSize: 16.5,
    fontWeight: FontWeight.w400,
    height: 1,
  );

  static const registrationDescription = TextStyle(
    color: AppColors.settingsRowSecondary,
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static const rowLabel = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: _family,
    fontSize: 16.5,
    fontWeight: FontWeight.w400,
    height: 1,
  );

  static const rowValue = TextStyle(
    color: AppColors.settingsRowSecondary,
    fontFamily: _family,
    fontSize: 16.5,
    fontWeight: FontWeight.w400,
    height: 1,
  );

  static const inputValue = TextStyle(
    color: AppColors.primary,
    fontFamily: _family,
    fontSize: 16.5,
    fontWeight: FontWeight.w500,
    height: 1,
  );

  static const rowHint = TextStyle(
    color: AppColors.accountLinkHint,
    fontFamily: _family,
    fontSize: 16.5,
    fontWeight: FontWeight.w400,
    height: 1,
  );

  static const segmentLabel = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: _family,
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    height: 1,
  );

  static const serverName = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: _family,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    height: 1,
  );

  static const searchHint = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: _family,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1,
  );
}
