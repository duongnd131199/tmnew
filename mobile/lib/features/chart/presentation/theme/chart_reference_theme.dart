import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';

@immutable
final class ChartReferenceTheme {
  const ChartReferenceTheme({
    required this.background,
    required this.foreground,
    required this.grid,
    required this.bullish,
    required this.bearish,
    required this.tradeBlue,
    required this.tradeRed,
    required this.plotTitleBlue,
    required this.ticketBlue,
    required this.axisBorder,
    required this.axisText,
    required this.plotSubtitleText,
    required this.priceLine,
  });

  static const light = ChartReferenceTheme(
    background: Color(0xFFFFFFFF),
    foreground: AppColors.tradingPrimaryText,
    grid: Color(0xFFE8E8E8),
    bullish: Color(0xFF26A69A),
    bearish: Color(0xFFEF5350),
    tradeBlue: AppColors.tradingPositiveText,
    tradeRed: AppColors.tradingNegativeText,
    plotTitleBlue: AppColors.chartCornerSymbolBlue,
    ticketBlue: AppColors.tradingPositiveText,
    axisBorder: Color(0xFFD8D8D8),
    axisText: AppColors.textSecondary,
    plotSubtitleText: AppColors.textSecondary,
    priceLine: Color(0xFF26A69A),
  );

  static const toolbarAccentRed = AppColors.chartToolbarAccentRed;
  static const toolbarAccentBlue = AppColors.chartToolbarAccentBlue;
  static const toolbarAccentNeutral = AppColors.chartToolbarAccentNeutral;

  final Color background;
  final Color foreground;
  final Color grid;
  final Color bullish;
  final Color bearish;
  final Color tradeBlue;
  final Color tradeRed;
  final Color plotTitleBlue;
  final Color ticketBlue;
  final Color axisBorder;
  final Color axisText;
  final Color plotSubtitleText;
  final Color priceLine;

  Color get toolbarInk => axisText;
}
