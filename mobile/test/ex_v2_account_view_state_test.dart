import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

void main() {
  test('view state uses bootstrap lists and server account totals', () {
    final state = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(_bootstrap),
    );

    expect(state.accountCode, 'TEST-100');
    expect(state.balance, 5000);
    expect(state.equity, 5000);
    expect(state.positions.single.id, 'position-1');
    expect(state.pendingOrders.single.id, 'order-1');
    expect(state.deals.single.id, 'deal-1');
  });

  test('live quote updates display profit equity and free margin', () {
    final state = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(_bootstrap),
    );

    final updated = state.withMarketPrice(
      symbol: 'XAUUSD+',
      bid: 3302,
      ask: 3302.2,
    );

    expect(updated.positions.single.currentPrice, 3302);
    expect(updated.positions.single.profit, closeTo(15, 0.0001));
    expect(updated.balance, 5000);
    expect(updated.profit, closeTo(15, 0.0001));
    expect(updated.equity, closeTo(5015, 0.0001));
    expect(updated.freeMargin, closeTo(5015, 0.0001));
  });
}

final _bootstrap = <String, Object?>{
  'serverTime': '2026-08-13T08:00:00Z',
  'version': 3,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-1',
    'accountCode': 'TEST-100',
    'name': 'Demo account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 5000,
    'equity': 5000,
    'profit': 0,
    'margin': 0,
    'freeMargin': 5000,
    'marginLevel': 0,
    'updatedAt': '2026-08-13T08:00:00Z',
  },
  'positions': [
    {
      'id': 'position-1',
      'symbol': 'XAUUSD+',
      'side': 'BUY',
      'initialVolume': 0.1,
      'remainingVolume': 0.1,
      'entryPrice': 3300.5,
      'stopLoss': null,
      'takeProfit': null,
      'realizedProfit': 0,
      'status': 'open',
      'createdAt': '2026-08-13T07:00:00Z',
      'closedAt': null,
      'rowVersion': 'position-rv',
    },
  ],
  'pendingOrders': [
    {
      'id': 'order-1',
      'clientOrderId': 'client-1',
      'symbol': 'XAUUSD+',
      'type': 'limit',
      'side': 'SELL',
      'volume': 0.1,
      'requestedPrice': 3400,
      'executedPrice': null,
      'stopLoss': null,
      'takeProfit': null,
      'status': 'pending',
      'createdAt': '2026-08-13T07:30:00Z',
      'version': 3,
      'rowVersion': 'order-rv',
    },
  ],
  'recentDeals': [
    {
      'id': 'deal-1',
      'type': 'trade',
      'symbol': 'XAUUSD+',
      'side': 'BUY',
      'volume': 0.1,
      'price': 3300.5,
      'profit': 0,
      'createdAt': '2026-08-13T07:00:00Z',
    },
  ],
  'wallet': {
    'currency': 'USD',
    'availableBalance': 1000,
    'lockedBalance': 0,
    'totalBalance': 1000,
  },
  'performance': {
    'netProfit': 0,
    'grossProfit': 0,
    'grossLoss': 0,
    'floatingProfit': 0,
    'tradingVolume': 0.1,
    'updatedAt': null,
    'integrityWarnings': 0,
  },
  'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
  'integrityWarnings': 0,
};
