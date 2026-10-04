import 'package:exness/features/trading/presentation/trading_screen.dart';
import 'package:exness/features/performance/presentation/performance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trading opens with the recorded balance and three favorites', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: TradingScreen())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('0,00 USD'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    expect(find.text('XAU/USD'), findsOneWidget);
    expect(find.text('ETH'), findsOneWidget);
    expect(find.text('81.424,77'), findsOneWidget);
    expect(find.text('4.378,101'), findsOneWidget);
    expect(find.text('2.649,81'), findsOneWidget);
  });

  testWidgets('performance opens in the video empty state without API data', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: PerformanceScreen())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Tất cả tài khoản thực'), findsOneWidget);
    expect(find.text('Không tìm thấy hoạt động giao dịch nào'), findsOneWidget);
    expect(find.text('Bắt đầu giao dịch'), findsOneWidget);
  });
}
