import 'package:exness/features/chart/presentation/chart_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chart preferences survive closing and reopening a chart route', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(chartSettingsProvider.notifier)
        .update(const ChartSettings(provider: ChartProvider.tradingView));

    expect(
      container.read(chartSettingsProvider).provider,
      ChartProvider.tradingView,
    );
  });

  testWidgets(
    'price source and chart provider remain selected after changing',
    (tester) async {
      ChartSettings? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartSettingsSheet(
              settings: const ChartSettings(),
              onChanged: (value) => latest = value,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Nguồn giá'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giá bán').last);
      await tester.pumpAndSettle();
      expect(latest?.priceSource, ChartPriceSource.ask);

      await tester.tap(find.text('TradingView'));
      await tester.pumpAndSettle();
      expect(latest?.provider, ChartProvider.tradingView);
    },
  );
}
