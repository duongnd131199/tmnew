import 'dart:async';

import 'package:exness/core/config/video_demo_mode.dart';

import 'package:exness/features/account/data/account_session.dart';
import 'package:exness/features/account/data/ex_v2_models.dart';
import 'package:exness/features/trading/data/market_api.dart';
import 'package:exness/features/trading/presentation/trading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trading shows loading before the first quote snapshot', (
    tester,
  ) async {
    final updates = StreamController<MarketFeedState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(_LoggedOutSession.new),
          marketQuotesProvider.overrideWith((ref) => updates.stream),
          marketCandlesProvider.overrideWith((ref, request) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: TradingScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('Đang tải giá thị trường…'), findsOneWidget);
    await updates.close();
  });

  testWidgets('live quote updates its row while the search stays active', (
    tester,
  ) async {
    final updates = StreamController<MarketFeedState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(_LoggedOutSession.new),
          marketQuotesProvider.overrideWith((ref) => updates.stream),
          marketCandlesProvider.overrideWith((ref, request) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: TradingScreen())),
      ),
    );
    updates.add(_state(4300));
    await tester.pumpAndSettle();
    expect(find.text('4.300,000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trading-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'XAU');
    await tester.pump();
    updates.add(_state(4301));
    await tester.pump();

    expect(find.text('4.301,000'), findsOneWidget);
    expect(find.text('BTC'), findsNothing);
    expect(find.text('XAU/USD'), findsOneWidget);
    await updates.close();
  });

  testWidgets('a stale quote is not displayed as a live price', (tester) async {
    final updates = StreamController<MarketFeedState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(_LoggedOutSession.new),
          marketQuotesProvider.overrideWith((ref) => updates.stream),
          marketCandlesProvider.overrideWith((ref, request) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: TradingScreen())),
      ),
    );
    updates.add(_state(4300));
    await tester.pumpAndSettle();
    expect(find.text('4.300,000'), findsOneWidget);

    updates.add(
      MarketFeedState(
        quotes: _state(4300).quotes,
        status: MarketFeedStatus.connected,
        staleSymbols: const {'XAUUSD+'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4.300,000'), findsNothing);
    expect(find.text('Giá cũ'), findsOneWidget);
    await updates.close();
  });
}

MarketFeedState _state(double bid) => MarketFeedState(
  quotes: [
    MarketQuote(
      symbol: 'XAUUSD+',
      bid: bid,
      ask: bid + 0.2,
      timestamp: DateTime.utc(2026, 9, 19, 10),
      source: 'test',
    ),
  ],
  status: MarketFeedStatus.connected,
);

final class _LoggedOutSession extends AccountSessionController {
  @override
  Future<ExV2Bootstrap?> build() async => null;
}
