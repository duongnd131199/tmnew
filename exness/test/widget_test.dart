import 'dart:async';

import 'package:exness/core/config/video_demo_mode.dart';

import 'package:exness/app/app.dart';
import 'package:exness/app/router.dart';
import 'package:exness/features/trading/data/market_api.dart';
import 'package:exness/features/trading/presentation/trading_screen.dart';
import 'package:exness/features/insights/presentation/insights_screen.dart';
import 'package:exness/features/performance/presentation/performance_screen.dart';
import 'package:exness/features/account/data/account_session.dart';
import 'package:exness/features/account/data/ex_v2_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phase 3 tabs fit a 360 logical pixel screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(_LoggedOutSession.new),
          marketQuotesProvider.overrideWith(
            (ref) => Stream.value(
              MarketFeedState(
                quotes: [
                  MarketQuote(
                    symbol: 'XAUUSD+',
                    bid: 4300,
                    ask: 4300.2,
                    timestamp: DateTime.utc(2026, 9, 19),
                    source: 'test',
                  ),
                ],
                status: MarketFeedStatus.connected,
              ),
            ),
          ),
          marketCandlesProvider.overrideWith((ref, request) async => const []),
        ],
        child: const ExnessApp(),
      ),
    );
    await tester.pumpAndSettle();
    for (final name in const ['trading', 'insights', 'performance']) {
      await tester.tap(find.byKey(Key('nav-$name')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('bottom tabs switch screens and keep the app shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(_LoggedOutSession.new),
          marketQuotesProvider.overrideWith(
            (ref) => Stream.value(
              const MarketFeedState(
                quotes: [],
                status: MarketFeedStatus.connected,
              ),
            ),
          ),
          marketCandlesProvider.overrideWith((ref, request) async => const []),
        ],
        child: const ExnessApp(),
      ),
    );
    appRouter.go('/account');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-screen')), findsOneWidget);
    expect(find.byKey(const Key('bottom-navigation')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-trading')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trading-screen')), findsOneWidget);
    expect(find.byKey(const Key('bottom-navigation')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-screen')), findsOneWidget);
  });

  testWidgets('trading search filters live symbols', (tester) async {
    final timestamp = DateTime.utc(2026, 9, 19);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          marketQuotesProvider.overrideWith(
            (ref) => Stream.value(
              MarketFeedState(
                status: MarketFeedStatus.connected,
                quotes: [
                  MarketQuote(
                    symbol: 'BTCUSD',
                    bid: 80000,
                    ask: 80001,
                    timestamp: timestamp,
                    source: 'test',
                  ),
                  MarketQuote(
                    symbol: 'XAUUSD+',
                    bid: 4300,
                    ask: 4300.1,
                    timestamp: timestamp,
                    source: 'test',
                  ),
                  MarketQuote(
                    symbol: 'ETHUSD',
                    bid: 2600,
                    ask: 2601,
                    timestamp: timestamp,
                    source: 'test',
                  ),
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TradingScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BTC'), findsOneWidget);
    await tester.tap(find.byKey(const Key('trading-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'XAU');
    await tester.pump();
    expect(find.text('XAU/USD'), findsOneWidget);
    expect(find.text('BTC'), findsNothing);
  });

  testWidgets('insights uses market data and labels unavailable feeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          marketQuotesProvider.overrideWith(
            (ref) => Stream.value(
              MarketFeedState(
                status: MarketFeedStatus.connected,
                quotes: [
                  MarketQuote(
                    symbol: 'BTCUSD',
                    bid: 80000,
                    ask: 80001,
                    timestamp: DateTime.utc(2026, 9, 19),
                    source: 'test',
                  ),
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: InsightsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ĐỀ XUẤT HÀNG ĐẦU'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    expect(find.textContaining('Chưa có dữ liệu tín hiệu'), findsOneWidget);
  });

  testWidgets('insights shows market feed failure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          marketQuotesProvider.overrideWith(
            (ref) => Stream.value(
              const MarketFeedState(
                quotes: [],
                status: MarketFeedStatus.disconnected,
                loadError: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: InsightsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không thể tải giá thị trường'), findsOneWidget);
  });

  testWidgets('performance shows the empty state and date filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(_LoggedOutSession.new),
        ],
        child: const MaterialApp(home: Scaffold(body: PerformanceScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Không tìm thấy hoạt động giao dịch nào'),
      findsOneWidget,
    );
    expect(find.text('7 ngày gần nhất'), findsOneWidget);
    expect(find.text('Bắt đầu giao dịch'), findsOneWidget);
  });
}

final class _LoggedOutSession extends AccountSessionController {
  @override
  Future<ExV2Bootstrap?> build() async => null;
}
