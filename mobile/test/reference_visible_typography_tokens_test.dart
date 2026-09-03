import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

void main() {
  const referencePlain = 'Mt5ReferenceRoboto';
  const referenceCondensed = 'Mt5ReferenceRobotoCondensed';
  const referenceCondensedVariable = 'Mt5ReferenceRobotoCondensedVariable';

  test('reference-visible static roles use the reviewed real faces', () {
    final roles =
        <String, ({TextStyle style, String family, FontWeight weight})>{
          'navigationLabel': (
            style: AppTypography.navigationLabel,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'navigationLabelSelected': (
            style: AppTypography.navigationLabelSelected,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'settingsToolbarTitle': (
            style: AppTypography.settingsToolbarTitle,
            family: referencePlain,
            weight: FontWeight.w700,
          ),
          'settingsAccountName': (
            style: AppTypography.settingsAccountName,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'settingsAccountCompany': (
            style: AppTypography.settingsAccountCompany,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'settingsAccountMeta': (
            style: AppTypography.settingsAccountMeta,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'settingsRowTitle': (
            style: AppTypography.settingsRowTitle,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'settingsRowSubtitle': (
            style: AppTypography.settingsRowSubtitle,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'chartTimeframe': (
            style: AppTypography.chartTimeframe,
            family: referencePlain,
            weight: FontWeight.w700,
          ),
          'chartToolbar': (
            style: AppTypography.chartToolbar,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'chartTicketLabel': (
            style: AppTypography.chartTicketLabel,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'chartTicketPriceMajor': (
            style: AppTypography.chartTicketPriceMajor,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'chartTicketPriceMinor': (
            style: AppTypography.chartTicketPriceMinor,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'chartAnnotation': (
            style: AppTypography.chartAnnotation,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'chartAxis': (
            style: AppTypography.chartAxis,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'chartTimeAxis': (
            style: AppTypography.chartTimeAxis,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'tradeHeaderProfit': (
            style: AppTypography.tradeHeaderProfit,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'tradeMetric': (
            style: AppTypography.tradeMetric,
            family: referenceCondensed,
            weight: FontWeight.w400,
          ),
          'tradeMetricValue': (
            style: AppTypography.tradeMetricValue,
            family: referenceCondensed,
            weight: FontWeight.w400,
          ),
          'tradePositionPrimary': (
            style: AppTypography.tradePositionPrimary,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'tradePositionSide': (
            style: AppTypography.tradePositionSide,
            family: referencePlain,
            weight: FontWeight.w700,
          ),
          'tradePositionSecondary': (
            style: AppTypography.tradePositionSecondary,
            family: referenceCondensed,
            weight: FontWeight.w400,
          ),
          'tradePositionProfit': (
            style: AppTypography.tradePositionProfit,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'historySegment': (
            style: AppTypography.historySegment,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'historyDealsSegment': (
            style: AppTypography.historyDealsSegment,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'historyPrimary': (
            style: AppTypography.historyPrimary,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'historyAction': (
            style: AppTypography.historyAction,
            family: referencePlain,
            weight: FontWeight.w700,
          ),
          'historyTrailingPrimary': (
            style: AppTypography.historyTrailingPrimary,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'historySecondary': (
            style: AppTypography.historySecondary,
            family: referenceCondensed,
            weight: FontWeight.w400,
          ),
          'historyPriceRange': (
            style: AppTypography.historyPriceRange,
            family: referenceCondensed,
            weight: FontWeight.w400,
          ),
          'historyBalancePrimary': (
            style: AppTypography.historyBalancePrimary,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'historyBalanceTrailingPrimary': (
            style: AppTypography.historyBalanceTrailingPrimary,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'historyBalanceSecondary': (
            style: AppTypography.historyBalanceSecondary,
            family: referenceCondensed,
            weight: FontWeight.w400,
          ),
          'historyTrailingSecondary': (
            style: AppTypography.historyTrailingSecondary,
            family: referenceCondensed,
            weight: FontWeight.w400,
          ),
          'historySummary': (
            style: AppTypography.historySummary,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'historyOrderSummaryTotal': (
            style: AppTypography.historyOrderSummaryTotal,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'historySummaryValue': (
            style: AppTypography.historySummaryValue,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
        };

    for (final MapEntry(key: role, value: expectation) in roles.entries) {
      expect(expectation.style.fontFamily, expectation.family, reason: role);
      expect(expectation.style.fontWeight, expectation.weight, reason: role);
      expect(expectation.style.fontVariations, isNull, reason: role);
    }
  });

  test('reviewed Prices roles stay on static reference faces', () {
    final roles =
        <String, ({TextStyle style, String family, FontWeight weight})>{
          'pricesToolbarTitle': (
            style: AppTypography.pricesToolbarTitle,
            family: referencePlain,
            weight: FontWeight.w700,
          ),
          'quoteChange': (
            style: AppTypography.quoteChange,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'quoteSymbol': (
            style: AppTypography.quoteSymbol,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'quoteMeta': (
            style: AppTypography.quoteMeta,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'quoteTimeMeta': (
            style: AppTypography.quoteTimeMeta,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'quoteSpreadMeta': (
            style: AppTypography.quoteSpreadMeta,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'quoteRangeMeta': (
            style: AppTypography.quoteRangeMeta,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'quoteRangeLabel': (
            style: AppTypography.quoteRangeLabel,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'quoteRangeValue': (
            style: AppTypography.quoteRangeValue,
            family: referencePlain,
            weight: FontWeight.w400,
          ),
          'quoteBtcHighMeta': (
            style: AppTypography.quoteBtcHighMeta,
            family: referenceCondensed,
            weight: FontWeight.w400,
          ),
          'quotePriceMajor': (
            style: AppTypography.quotePriceMajor,
            family: referenceCondensed,
            weight: FontWeight.w400,
          ),
          'quotePriceMinor': (
            style: AppTypography.quotePriceMinor,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'quotePriceBtcMajor': (
            style: AppTypography.quotePriceBtcMajor,
            family: referenceCondensed,
            weight: FontWeight.w400,
          ),
          'quotePriceBtcMinor': (
            style: AppTypography.quotePriceBtcMinor,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
          'quotePricePipette': (
            style: AppTypography.quotePricePipette,
            family: referenceCondensed,
            weight: FontWeight.w700,
          ),
        };

    for (final MapEntry(key: role, value: expectation) in roles.entries) {
      expect(expectation.style.fontFamily, expectation.family, reason: role);
      expect(expectation.style.fontWeight, expectation.weight, reason: role);
      expect(expectation.style.fontVariations, isNull, reason: role);
    }
  });

  test(
    'reference condensed variable roles use only real 400 and 700 weights',
    () {
      final roles = <String, ({TextStyle style, double weight})>{
        'tradeSection': (style: AppTypography.tradeSection, weight: 700),
      };

      for (final MapEntry(key: role, value: expectation) in roles.entries) {
        expect(
          expectation.style.fontFamily,
          referenceCondensedVariable,
          reason: role,
        );
        expect(
          expectation.style.fontWeight,
          expectation.weight == 400 ? FontWeight.w400 : FontWeight.w700,
          reason: role,
        );
        expect(expectation.style.fontVariations, <FontVariation>[
          FontVariation('wght', expectation.weight),
        ], reason: role);
        expect(_fontAxis(expectation.style, 'wdth'), isNull, reason: role);
      }
    },
  );

  testWidgets('locked reference faces ignore synthetic iOS ink', (
    tester,
  ) async {
    const lockedStaticStyle = TextStyle(
      fontFamily: referenceCondensed,
      fontWeight: FontWeight.w700,
    );
    const lockedVariableStyle = TextStyle(
      fontFamily: referenceCondensedVariable,
      fontWeight: FontWeight.w700,
      fontVariations: <FontVariation>[FontVariation('wght', 700)],
    );
    late TextStyle staticResult;
    late TextStyle variableResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) {
            staticResult = AppTypography.platformInk(
              context,
              lockedStaticStyle,
              iosWeight: 550,
            );
            variableResult = AppTypography.platformInk(
              context,
              lockedVariableStyle,
              iosWeight: 450,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(staticResult, lockedStaticStyle);
    expect(variableResult, lockedVariableStyle);
  });

  testWidgets('MtTabTextScope does not override inherited text metrics', (
    tester,
  ) async {
    const inheritedStyle = TextStyle(
      fontFamily: 'ParentSentinel',
      fontWeight: FontWeight.w300,
      letterSpacing: 1.25,
      fontVariations: <FontVariation>[FontVariation('slnt', -10)],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTextStyle(
          style: inheritedStyle,
          child: MtTabTextScope(child: Text('probe', key: Key('scope-probe'))),
        ),
      ),
    );

    final effectiveStyle = DefaultTextStyle.of(
      tester.element(find.byKey(const Key('scope-probe'))),
    ).style;
    expect(effectiveStyle, inheritedStyle);
  });
}

double? _fontAxis(TextStyle style, String axis) {
  for (final variation in style.fontVariations ?? const <FontVariation>[]) {
    if (variation.axis == axis) return variation.value;
  }
  return null;
}
