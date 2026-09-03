import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
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
          'orderId': 'deal-order-1',
          'positionId': 'position-1',
          'type': 'in',
          'symbol': 'XAUUSD+',
          'side': 'BUY',
          'volume': 0.1,
          'price': 3300.5,
          'profit': 0,
          'createdAtUtc': '2026-08-13T07:00:00Z',
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
      'recentDeposits': [
        {
          'id': '11111111-1111-4111-8111-111111111111',
          'accountId': 'account-1',
          'amount': 5000000,
          'currency': 'USD',
          'method': 'demo',
          'reference': 'five-million',
          'status': 'pending',
          'createdAtUtc': '2026-08-13T08:00:00Z',
          'updatedAtUtc': '2026-08-13T08:00:00Z',
          'approvedAtUtc': null,
          'rejectedAtUtc': null,
          'transactionId': null,
          'snapshotVersion': 12,
        },
      ],
      'historySummary': {
        'deposit': 1200,
        'withdrawal': -300,
        'realizedProfit': 100,
        'swap': -1,
        'commission': -2,
        'netChange': 997,
        'snapshotVersion': 12,
      },
    });
    final viewState = ExV2AccountViewState.fromBootstrap(snapshot);

    expect(snapshot.version, 12);
    expect(snapshot.serverTime.isUtc, isTrue);
    expect(snapshot.account.accountCode, 'TEST-100');
    expect(snapshot.summary.balance, 5000);
    expect(snapshot.summary.equity, 5100);
    expect(snapshot.positions.single.remainingVolume, 0.1);
    expect(snapshot.positions.single.stopLoss, isNull);
    expect(snapshot.pendingOrders.single.rowVersion, 'rv-2');
    expect(snapshot.recentDeals.single.orderId, 'deal-order-1');
    expect(snapshot.recentDeals.single.positionId, 'position-1');
    expect(snapshot.recentDeals.single.type, 'in');
    expect(snapshot.recentDeals.single.profit, 0);
    expect(snapshot.recentDeals.single.createdAt.isUtc, isTrue);
    expect(snapshot.wallet.lockedBalance, 100);
    expect(snapshot.performance.netProfit, 100);
    expect(viewState.deposits.single['status'], 'pending');
    expect(viewState.deposits.single['snapshotVersion'], 12);
    expect(viewState.historySummary.deposit, 1200);
  });

  test(
    'bootstrap rejects a missing active account instead of using mock data',
    () {
      expect(
        () => ExV2Bootstrap.fromJson({
          'serverTime': '2026-08-13T08:00:00Z',
          'version': 1,
        }),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('bootstrap accepts nullable display metadata from production', () {
    final snapshot = ExV2Bootstrap.fromJson({
      'serverTime': '2026-09-02T08:00:00Z',
      'version': 1,
      'device': {'id': 'device-1', 'name': null},
      'activeAccount': {
        'id': 'acct_public_1',
        'accountCode': null,
        'name': null,
        'currency': null,
        'status': null,
      },
      'summary': {
        'accountId': 'acct_public_1',
        'currency': 'USD',
        'balance': 100000,
        'equity': 100000,
        'profit': 0,
        'margin': 0,
        'freeMargin': 100000,
        'marginLevel': 0,
        'updatedAt': '2026-09-02T08:00:00Z',
      },
      'positions': <Object?>[],
      'pendingOrders': <Object?>[],
      'recentDeals': <Object?>[],
      'wallet': {
        'currency': null,
        'availableBalance': 0,
        'lockedBalance': 0,
        'totalBalance': 0,
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
      'connection': {'marketFeedStatus': null, 'lastMarketTickAt': null},
      'integrityWarnings': 0,
    });

    expect(snapshot.account.id, 'acct_public_1');
    expect(snapshot.device.name, 'Thiết bị');
    expect(snapshot.account.accountCode, 'acct_public_1');
    expect(snapshot.account.name, 'acct_public_1');
    expect(snapshot.account.currency, 'USD');
    expect(snapshot.account.status, 'unknown');
    expect(snapshot.wallet.currency, 'USD');
    expect(snapshot.connection.marketFeedStatus, 'unknown');
  });

  test('canonical deal accepts nullable legacy linkage ids', () {
    final deal = ExV2Deal.fromJson({
      'id': 'deal-legacy',
      'orderId': null,
      'positionId': null,
      'type': 'out_by',
      'symbol': 'XAUUSD+',
      'side': 'SELL',
      'volume': 0.25,
      'price': 4589.556,
      'profit': 7.5,
      'createdAtUtc': '2026-08-28T00:44:38Z',
    });

    expect(deal.orderId, isNull);
    expect(deal.positionId, isNull);
    expect(deal.type, 'out_by');
    expect(deal.profit, 7.5);
    expect(deal.createdAt.isUtc, isTrue);
  });

  test('canonical deposit preserves a nullable legacy reference', () {
    final deposit = ExV2Deposit.fromJson({
      'id': '11111111-1111-4111-8111-111111111111',
      'accountId': 'acct_1',
      'amount': 5000000,
      'currency': 'USD',
      'method': 'legacy',
      'reference': null,
      'status': 'approved',
      'createdAtUtc': '2026-09-01T10:00:00Z',
      'updatedAtUtc': '2026-09-01T10:01:00Z',
      'approvedAtUtc': null,
      'rejectedAtUtc': null,
      'transactionId': null,
      'snapshotVersion': 12,
    });

    expect(deposit.reference, isNull);
    expect(deposit.toJson()['reference'], isNull);
  });

  test('close position response parses its canonical sync and mode', () {
    final response = ExV2ClosePositionResponse.fromJson({
      ..._closedPositionJson,
      'sync': _closeSyncJson(mode: 'full'),
    });

    expect(response.position.id, 'position-1');
    expect(response.position.status, 'closed');
    expect(response.sync?.operation.mode, ExV2CloseMode.full);
    expect(response.sync?.operation.mode.wireName, 'full');
    expect(response.sync?.deals.single.type, 'out');
  });

  test('close-by response maps snake case mode without closing remainder', () {
    final response = ExV2CloseByResponse.fromJson({
      'position': {
        ..._closedPositionJson,
        'remainingVolume': 0.01,
        'status': 'open',
        'closedAt': null,
      },
      'oppositePosition': _closedPositionJson,
      'closedVolume': 0.01,
      'version': 13,
      'sync': _closeSyncJson(mode: 'close_by'),
    });

    expect(response.position.status, 'open');
    expect(response.oppositePosition.status, 'closed');
    expect(response.closedVolume, 0.01);
    expect(response.version, 13);
    expect(response.sync?.operation.mode, ExV2CloseMode.closeBy);
    expect(response.sync?.operation.mode.wireName, 'close_by');
  });
}

final _closedPositionJson = <String, Object?>{
  'id': 'position-1',
  'symbol': 'XAUUSD+',
  'side': 'buy',
  'initialVolume': 0.02,
  'remainingVolume': 0,
  'entryPrice': 4397.125,
  'stopLoss': null,
  'takeProfit': null,
  'realizedProfit': -0.26,
  'status': 'closed',
  'createdAt': '2026-09-01T09:59:00Z',
  'closedAt': '2026-09-01T10:00:00Z',
  'rowVersion': 'row-version-1',
};

Map<String, Object?> _closeSyncJson({required String mode}) => {
  'accountId': 'account-1',
  'version': 13,
  'committedAtUtc': '2026-09-01T10:00:00Z',
  'operation': {
    'mode': mode,
    'idempotencyKey': '11111111-1111-4111-8111-111111111111',
    'correlationId': '22222222-2222-4222-8222-222222222222',
  },
  'affectedPositions': [_closedPositionJson],
  'closedPositions': [
    {
      'id': 'position-1',
      'positionId': 'position-1',
      'symbol': 'XAUUSD+',
      'side': 'buy',
      'volume': 0.02,
      'openPrice': 4397.125,
      'closePrice': 4397.385,
      'realizedProfit': -0.26,
      'openedAtUtc': '2026-09-01T09:59:00Z',
      'closedAtUtc': '2026-09-01T10:00:00Z',
      'status': 'closed',
    },
  ],
  'orders': <Object?>[],
  'deals': [
    {
      'id': 'deal-1',
      'orderId': 'order-1',
      'positionId': 'position-1',
      'type': mode == 'close_by' ? 'out_by' : 'out',
      'symbol': 'XAUUSD+',
      'side': 'sell',
      'volume': 0.02,
      'price': 4397.385,
      'profit': -0.26,
      'createdAtUtc': '2026-09-01T10:00:00Z',
    },
  ],
  'accountSummary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 4999.74,
    'equity': 4999.74,
    'profit': 0,
    'margin': 0,
    'freeMargin': 4999.74,
    'marginLevel': 0,
    'updatedAt': '2026-09-01T10:00:00Z',
  },
  'historySummary': {
    'deposit': 0,
    'withdrawal': 0,
    'realizedProfit': -0.26,
    'swap': 0,
    'commission': 0,
    'netChange': -0.26,
  },
};
