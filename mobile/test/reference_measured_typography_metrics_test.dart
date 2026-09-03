import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';

void main() {
  test('Prices roles retain the measured reference extents', () {
    // Fresh 590x1280 comparison against photo_2026-08-25_22-30-10.jpg:
    // title 41x22 -> 32x18, symbol width ratio 1.143, first-price major
    // 61x20 -> 54x18, and first-price minor 35x33 -> 34x30.
    expect(AppTypography.pricesToolbarTitle.fontSize, 16);
    expect(AppTypography.pricesToolbarTitle.fontWeight, FontWeight.w700);
    expect(
      AppTypography.pricesToolbarTitle.fontFamily,
      AppTypography.referencePlainFamily,
    );

    expect(AppTypography.quoteSymbol.fontSize, 16);
    expect(AppTypography.quoteSymbol.fontWeight, FontWeight.w700);
    expect(
      AppTypography.quoteSymbol.fontFamily,
      AppTypography.referenceCondensedFamily,
    );

    for (final style in <TextStyle>[
      AppTypography.quotePriceMajor,
      AppTypography.quotePriceBtcMajor,
    ]) {
      expect(style.fontSize, 16);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontFamily, AppTypography.referenceCondensedFamily);
    }
    for (final style in <TextStyle>[
      AppTypography.quotePriceMinor,
      AppTypography.quotePriceBtcMinor,
    ]) {
      expect(style.fontSize, 27);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, .85);
      expect(style.fontFamily, AppTypography.referenceCondensedFamily);
    }
  });

  test('Chart ticket labels use the requested stronger 10px role', () {
    expect(AppTypography.chartTicketLabel.fontSize, 10);
    expect(AppTypography.chartTicketLabel.fontWeight, FontWeight.w700);
    expect(
      AppTypography.chartTicketLabel.fontFamily,
      AppTypography.referenceCondensedFamily,
    );
    expect(AppTypography.chartTicketLabel.fontVariations, isNull);
  });
}
