import 'package:exness/features/account/data/ex_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap keeps account, balance, positions and performance typed', () {
    final bootstrap = ExV2Bootstrap.fromJson({
      'serverTime': '2026-09-19T00:00:00Z',
      'version': 2,
      'device': {'id': 'device-1', 'name': 'Demo'},
      'activeAccount': {
        'id': 'account-1',
        'accountCode': '100000001',
        'name': 'Virtual account',
        'currency': 'USD',
        'status': 'active',
      },
      'summary': {
        'accountId': 'account-1',
        'currency': 'USD',
        'balance': 12.5,
        'equity': 12.5,
        'profit': 0,
        'margin': 0,
        'freeMargin': 12.5,
        'marginLevel': 0,
        'updatedAt': '2026-09-19T00:00:00Z',
      },
      'positions': [],
      'pendingOrders': [],
      'recentDeals': [],
      'wallet': {
        'currency': 'USD',
        'availableBalance': 5,
        'lockedBalance': 0,
        'totalBalance': 5,
      },
      'performance': {
        'netProfit': 0,
        'grossProfit': 0,
        'grossLoss': 0,
        'floatingProfit': 0,
        'tradingVolume': 0,
        'updatedAt': null,
        'integrityWarnings': 0,
      },
      'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
      'integrityWarnings': 0,
    });

    expect(bootstrap.account.accountCode, '100000001');
    expect(bootstrap.summary.balance, 12.5);
    expect(bootstrap.wallet.totalBalance, 5);
    expect(bootstrap.positions, isEmpty);
  });
}
