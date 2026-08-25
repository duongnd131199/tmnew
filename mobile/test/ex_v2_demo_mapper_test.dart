import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_demo_mapper.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

void main() {
  test('maps server trading entities into existing UI models', () {
    final position = ExV2Position.fromJson({
      'id': 'position-1',
      'symbol': 'XAUUSD+',
      'side': 'buy',
      'initialVolume': 0.2,
      'remainingVolume': 0.1,
      'entryPrice': 3300.5,
      'stopLoss': 3200,
      'takeProfit': 3400,
      'realizedProfit': 3,
      'status': 'open',
      'createdAt': '2026-08-13T07:00:00Z',
      'closedAt': null,
      'rowVersion': 'rv-1',
    });
    final order = ExV2Order.fromJson({
      'id': 'order-1',
      'clientOrderId': 'client-1',
      'symbol': 'XAUUSD+',
      'type': 'limit',
      'side': 'sell',
      'volume': 0.1,
      'requestedPrice': 3400,
      'executedPrice': null,
      'stopLoss': null,
      'takeProfit': null,
      'status': 'pending',
      'createdAt': '2026-08-13T07:30:00Z',
      'version': 2,
      'rowVersion': 'rv-2',
    });

    final uiPosition = ExV2DemoMapper.position(position);
    final uiPending = ExV2DemoMapper.pendingOrder(order);

    expect(uiPosition.id, 'position-1');
    expect(uiPosition.side, 'BUY');
    expect(uiPosition.volume, 0.1);
    expect(uiPosition.openPrice, 3300.5);
    expect(uiPosition.stopLoss, 3200);
    expect(uiPending.id, 'order-1');
    expect(uiPending.type, 'Sell Limit');
    expect(uiPending.price, 3400);
  });

  test('maps history position aliases without inventing finance values', () {
    final value = ExV2DemoMapper.historyPosition({
      'id': 'history-1',
      'symbol': 'XAUUSD+',
      'side': 'SELL',
      'volume': 0.2,
      'openPrice': 3400,
      'closePrice': 3390,
      'profit': 200,
      'closedAt': '2026-08-13T08:00:00Z',
    });

    expect(value.id, 'history-1');
    expect(value.title, 'XAUUSD+');
    expect(value.closePrice, 3390);
    expect(value.profit, 200);
  });

  test('legacy open and closed projections are filled execution orders', () {
    final open = ExV2DemoMapper.historyOrder({
      'id': 'legacy-order:1',
      'symbol': 'XAUUSD+',
      'side': 'buy',
      'volume': 0.25,
      'openPrice': 4353.019,
      'status': 'open',
      'openedAt': '2026-08-13T16:19:31Z',
    });
    final closed = ExV2DemoMapper.historyOrder({
      'id': 'legacy-order:2',
      'symbol': 'XAUUSD+',
      'side': 'sell',
      'volume': 0.25,
      'openPrice': 4365.280,
      'status': 'closed',
      'openedAt': '2026-08-13T16:31:10Z',
    });

    expect(open.status, 'filled');
    expect(closed.status, 'filled');
  });

  test('maps close-by deal types as history exits', () {
    final deal = ExV2DemoMapper.historyDeal({
      'id': 'deal-out-by-1',
      'orderId': 'order-1',
      'positionId': 'position-1',
      'symbol': 'XAUUSD+',
      'side': 'sell',
      'volume': 0.1,
      'price': 4383.5,
      'profit': 1.25,
      'dealType': 'out_by',
      'createdAt': '2026-08-13T08:00:00Z',
    });

    expect(deal.entry, 'out');
  });
}
