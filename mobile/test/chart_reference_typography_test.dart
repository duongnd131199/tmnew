import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/chart/presentation/theme/chart_reference_theme.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

void main() {
  test('chart corner symbol uses the Prices positive #007AFF ink', () {
    expect(ChartReferenceTheme.light.plotTitleBlue, const Color(0xFF007AFF));
  });

  test('chart toolbar and axis use the source-locked #3C3C43 ink', () {
    expect(ChartReferenceTheme.light.toolbarInk, const Color(0xFF3C3C43));
    expect(ChartReferenceTheme.light.axisText, const Color(0xFF3C3C43));
  });

  testWidgets('canonical chart text uses static semantic reference faces', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M1'),
        ),
      ),
    );
    await tester.pump();

    final toolbarTimeframe = tester.widget<Text>(
      find.byKey(const Key('chart-toolbar-timeframe')),
    );
    expect(
      toolbarTimeframe.style?.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(toolbarTimeframe.style?.fontWeight, FontWeight.w700);
    expect(toolbarTimeframe.style?.fontVariations, isNull);
    expect(
      toolbarTimeframe.style?.color,
      const Color(0xFF3C3C43),
      reason: 'The secondary chart toolbar ink is locked to the reference.',
    );

    final title = tester.widget<Text>(
      find.byKey(const Key('chart-plot-title')),
    );
    final titleSpan = title.textSpan! as TextSpan;
    final symbolSpan = titleSpan.children!.first as TextSpan;
    expect(symbolSpan.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(
      symbolSpan.style?.fontWeight,
      FontWeight.w700,
      reason: 'The chart symbol matches the bold XAUUSD label in Prices.',
    );
    expect(symbolSpan.style?.fontVariations, isNull);
    expect(
      symbolSpan.style?.color,
      const Color(0xFF007AFF),
      reason: 'The XAUUSD chart corner matches the positive Prices blue.',
    );

    final subtitle = find.byKey(const Key('chart-plot-subtitle'));
    expect(
      find.ancestor(
        of: subtitle,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Transform &&
              !widget.transform.storage.every(
                (value) => value == 0 || value == 1,
              ),
        ),
      ),
      findsNothing,
      reason:
          'M1 subtitle must not compensate typography with a scale transform.',
    );

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.referenceTextFamily, AppTypography.referencePlainFamily);
    expect(
      painter.debugTimeAxisTextStyle.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(painter.debugTimeAxisTextStyle.fontWeight, FontWeight.w400);
    expect(painter.debugTimeAxisTextStyle.fontVariations, isNull);
    expect(
      painter.debugTimeAxisTextStyle.color,
      const Color(0xFF3C3C43),
      reason: 'The chart axis uses the locked secondary reference ink.',
    );

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();

    final volume = tester.widget<Text>(
      find.byKey(const Key('chart-one-click-volume-text')),
    );
    expect(volume.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(volume.style?.fontWeight, FontWeight.w400);
    expect(volume.style?.fontVariations, isNull);
    expect(
      find.ancestor(
        of: find.byKey(const Key('chart-one-click-volume-text')),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
      reason: 'The volume run must keep its locked font metrics.',
    );

    for (final label in const <String>['SELL', 'Buy']) {
      final ticketLabel = tester.widget<Text>(find.text(label));
      expect(
        ticketLabel.style?.fontFamily,
        AppTypography.referenceCondensedFamily,
        reason: label,
      );
      expect(ticketLabel.style?.fontSize, 10, reason: label);
      expect(ticketLabel.style?.fontWeight, FontWeight.w700, reason: label);
      expect(ticketLabel.style?.fontVariations, isNull, reason: label);
    }

    final ticketPrices = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('chart-one-click-panel')),
            matching: find.byType(Text),
          ),
        )
        .where(
          (text) =>
              text.style?.fontSize ==
                  AppTypography.chartTicketPriceMajor.fontSize ||
              text.style?.fontSize ==
                  AppTypography.chartTicketPriceMinor.fontSize,
        )
        .toList(growable: false);
    expect(ticketPrices, hasLength(4));
    for (final ticketPrice in ticketPrices) {
      expect(
        ticketPrice.style?.fontFamily,
        AppTypography.referenceCondensedFamily,
      );
      expect(ticketPrice.style?.fontWeight, FontWeight.w700);
      expect(ticketPrice.style?.fontVariations, isNull);
      expect(
        find.ancestor(
          of: find.byWidget(ticketPrice),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
        reason: 'Ticket prices must not be scaled after style resolution.',
      );
    }

    await tester.tap(find.byKey(const Key('chart-toolbar-timeframe')));
    await tester.pump();

    final expandedPeriod = tester.widget<Text>(find.text('M5'));
    expect(expandedPeriod.style?.color, const Color(0xFF3C3C43));
    final expandedMore = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('chart-timeframe-more')),
        matching: find.text('•••'),
      ),
    );
    expect(expandedMore.style?.color, const Color(0xFF3C3C43));

    await tester.tap(find.byKey(const Key('chart-timeframe-more')));
    await tester.pumpAndSettle();

    final dialogPeriod = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('chart-timeframe-M1')),
        matching: find.text('M1'),
      ),
    );
    expect(dialogPeriod.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(dialogPeriod.style?.fontWeight, FontWeight.w700);
    expect(dialogPeriod.style?.fontVariations, isNull);

    final hint = tester.widget<Text>(
      find.byKey(const Key('chart-timeframe-hint-text')),
    );
    expect(hint.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(hint.style?.fontWeight, FontWeight.w400);
    expect(hint.style?.fontVariations, isNull);
  });
}
