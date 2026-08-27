import 'package:flutter/material.dart';

@immutable
final class ChartReferenceTheme {
  const ChartReferenceTheme({
    required this.background,
    required this.foreground,
    required this.grid,
    required this.bullish,
    required this.bearish,
    required this.tradeBlue,
    required this.plotTitleBlue,
    required this.ticketBlue,
    required this.axisBorder,
    required this.axisText,
    required this.plotSubtitleText,
    required this.priceLine,
  });

  static const light = ChartReferenceTheme(
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF000000),
    grid: Color(0xFFE8E8E8),
    bullish: Color(0xFF26A69A),
    bearish: Color(0xFFEF5350),
    tradeBlue: Color(0xFF3183FF),
    plotTitleBlue: Color(0xFF3985E9),
    ticketBlue: Color(0xFF007AFF),
    axisBorder: Color(0xFFD8D8D8),
    axisText: Color(0xFF404040),
    plotSubtitleText: Color(0xFF404040),
    priceLine: Color(0xFF26A69A),
  );

  static const toolbarAccentRed = Color(0xFFC85C4B);
  static const toolbarAccentBlue = Color(0xFF4D85E6);
  static const toolbarAccentNeutral = Color(0xFFB4BFC0);

  final Color background;
  final Color foreground;
  final Color grid;
  final Color bullish;
  final Color bearish;
  final Color tradeBlue;
  final Color plotTitleBlue;
  final Color ticketBlue;
  final Color axisBorder;
  final Color axisText;
  final Color plotSubtitleText;
  final Color priceLine;

  Color get toolbarInk =>
      Color.alphaBlend(foreground.withValues(alpha: .75), background);
}
