import 'dart:async';
import 'dart:math';

import 'package:trading_mobile/shared/models/demo_models.dart';

class MockQuoteService {
  const MockQuoteService({
    this.tickInterval = const Duration(milliseconds: 350),
    this.freezeWhenMarketClosed = false,
  });

  final Duration tickInterval;
  final bool freezeWhenMarketClosed;

  Stream<DemoQuote> watchQuote(DemoQuote initialQuote) async* {
    var current = initialQuote;
    final random = Random(initialQuote.symbol.hashCode);
    yield current;

    final weekday = DateTime.now().weekday;
    if (freezeWhenMarketClosed &&
        (weekday == DateTime.saturday || weekday == DateTime.sunday)) {
      return;
    }

    yield* Stream<DemoQuote>.periodic(tickInterval, (_) {
      final candidate = nextQuote(current, random.nextDouble());
      final anchor = initialQuote.bid;
      final maxDeviation = switch (initialQuote.symbol) {
        'BTCUSD' => 180.0,
        'XAUUSD' || 'XAUUSD+' => 2.80,
        _ => anchor >= 1000 ? anchor * .00035 : anchor * .00008,
      };
      final correctedBid = (candidate.bid + (anchor - candidate.bid) * .018)
          .clamp(anchor - maxDeviation, anchor + maxDeviation)
          .toDouble();
      current = DemoQuote(
        symbol: candidate.symbol,
        name: candidate.name,
        bid: correctedBid,
        ask: correctedBid + (initialQuote.ask - initialQuote.bid),
        changePercent: candidate.changePercent,
        sourceTimestamp: DateTime.now().toUtc(),
      );
      return current;
    });
  }

  DemoQuote nextQuote(DemoQuote current, double randomValue) {
    final direction = randomValue >= 0.5 ? 1.0 : -1.0;
    final intensity = 0.35 + (randomValue - 0.5).abs();
    final movement = current.bid * 0.000035 * intensity * direction;
    final spread = current.ask - current.bid;
    final nextBid = current.bid + movement;

    return DemoQuote(
      symbol: current.symbol,
      name: current.name,
      bid: nextBid,
      ask: nextBid + spread,
      // The magnitude is the recorded daily change. Its sign doubles as the
      // latest-tick direction so quote digits can flash blue/red like MT5.
      changePercent: current.changePercent.abs() * direction,
      sourceTimestamp: DateTime.now().toUtc(),
    );
  }
}
