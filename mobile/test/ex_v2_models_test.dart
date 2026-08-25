import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

void main() {
  test('bootstrap maps the server account snapshot without client totals', () {
    final snapshot = ExV2Bootstrap.fromJson({
      'serverTime': '2026-08-13T08:00:00Z',
      'version': 12,
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
        'equity': 5100,
        'profit': 100,
        'margin': 0,
        'freeMargin': 5100,
        'marginLevel': 0,
        'updatedAt': '2026-08-13T08:00:00Z',
      },
      'positions': [
        {
          'id': 'position-1',
          'symbol': 'XAUUSD+',
          'side': 'BUY',
          'initialVolume': 0.2,
          'remainingVolume': 0.1,
          'entryPrice': 3300.5,
          'stopLoss': null,
          'takeProfit': 3400,
          'realizedProfit': 10,
          'status': 'open',
          'createdAt': '2026-08-13T07:00:00Z',
          'closedAt': null,
          'rowVersion': 'rv-1',
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
          'version': 12,
          'rowVersion': 'rv-2',
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
          'profit': 10,
          'createdAt': '2026-08-13T07:00:00Z',
        },
      ],
      'wallet': {
        'currency': 'USD',
        'availableBalance': 900,
        'lockedBalance': 100,
        'totalBalance': 1000,
      },
      'performance': {
        'netProfit': 100,
        'grossProfit': 120,
        'grossLoss': -20,
        'floatingProfit': 5,
        'tradingVolume': 1.5,
        'updatedAt': '2026-08-13T08:00:00Z',
        'integrityWarnings': 0,
      },
      'connection': {
        'marketFeedStatus': 'connected',
        'lastMarketTickAt': '2026-08-13T07:59:59Z',
      },
      'integrityWarnings': 0,
    });

    expect(snapshot.version, 12);
    expect(snapshot.serverTime.isUtc, isTrue);
    expect(snapshot.account.accountCode, 'TEST-100');
    expect(snapshot.summary.balance, 5000);
    expect(snapshot.summary.equity, 5100);
    expect(snapshot.positions.single.remainingVolume, 0.1);
    expect(snapshot.positions.single.stopLoss, isNull);
    expect(snapshot.pendingOrders.single.rowVersion, 'rv-2');
    expect(snapshot.wallet.lockedBalance, 100);
    expect(snapshot.performance.netProfit, 100);
  });

  test('bootstrap rejects a missing active account instead of using mock data', () {
    expect(
      () => ExV2Bootstrap.fromJson({
        'serverTime': '2026-08-13T08:00:00Z',
        'version': 1,
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
