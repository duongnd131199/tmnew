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
    expect(state.deals.single.orderId, 'deal-order-1');
    expect(state.deals.single.positionId, 'position-1');
    expect(state.deals.single.entry, 'in');
  });

  test('bootstrap maps authoritative valuation into its matching position', () {
    final state = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(
        _bootstrapFor(
          profit: 35.79,
          positions: [_position(symbol: 'BTCUSD', entryPrice: 79768.46)],
          positionValuations: const [
            <String, Object?>{
              'positionId': 'position-1',
              'symbol': 'BTCUSD',
              'currentPrice': 79911.64,
              'floatingProfit': 35.79,
            },
          ],
        ),
      ),
    );

    expect(state.positions.single.currentPrice, 79911.64);
    expect(state.positions.single.profit, 35.79);
    expect(state.liveValuationPositionIds, {'position-1'});
    expect(state.hasLiveValuation, isTrue);
  });

  test('public quote cannot overwrite an authoritative position valuation', () {
    final state = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(
        _bootstrapFor(
          profit: 35.79,
          positions: [_position(symbol: 'BTCUSD', entryPrice: 79768.46)],
          positionValuations: const [
            <String, Object?>{
              'positionId': 'position-1',
              'symbol': 'BTCUSD',
              'currentPrice': 79911.64,
              'floatingProfit': 35.79,
            },
          ],
        ),
      ),
    );

    final updated = state.withMarketPrice(
      symbol: 'BTCUSD',
      bid: 80000,
      ask: 80001,
    );

    expect(updated.positions.single.currentPrice, 79911.64);
    expect(updated.positions.single.profit, 35.79);
  });

  test('public quote updates price without calculating position profit', () {
    final state = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(_bootstrap),
    );

    final updated = state.withMarketPrice(
      symbol: 'XAUUSD+',
      bid: 3302,
      ask: 3302.2,
    );

    expect(updated.positions.single.currentPrice, 3302);
    expect(updated.positions.single.profit, 0);
    expect(updated.liveValuationPositionIds, isEmpty);
    expect(updated.balance, 5000);
    expect(updated.profit, 0);
    expect(updated.equity, 5000);
    expect(updated.margin, 0);
    expect(updated.freeMargin, 5000);
    expect(updated.marginLevel, 0);
  });

  test('public quotes never become authoritative position valuations', () {
    final state = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(<String, Object?>{
        ..._bootstrap,
        'summary': <String, Object?>{
          ...(_bootstrap['summary']! as Map<String, Object?>),
          'profit': 75,
          'equity': 5075,
          'freeMargin': 5075,
        },
        'positions': <Object?>[
          ...(_bootstrap['positions']! as List<Object?>),
          <String, Object?>{
            'id': 'position-2',
            'symbol': 'BTCUSD',
            'side': 'BUY',
            'initialVolume': 0.01,
            'remainingVolume': 0.01,
            'entryPrice': 60000,
            'stopLoss': null,
            'takeProfit': null,
            'realizedProfit': 0,
            'status': 'open',
            'createdAt': '2026-08-13T07:15:00Z',
            'closedAt': null,
            'rowVersion': 'position-rv-2',
          },
        ],
      }),
    );

    final xauOnly = state.withMarketPrice(
      symbol: 'XAUUSD+',
      bid: 3302,
      ask: 3302.2,
    );

    expect(xauOnly.hasLiveValuation, isFalse);
    expect(xauOnly.profit, 75);
    expect(xauOnly.equity, 5075);

    final allSymbols = xauOnly.withMarketPrice(
      symbol: 'BTCUSD',
      bid: 60010,
      ask: 60011,
    );

    expect(allSymbols.hasLiveValuation, isFalse);
    expect(allSymbols.profit, 75);
    expect(allSymbols.equity, 5075);
    expect(allSymbols.freeMargin, 5075);
  });

  test('refresh preserves prices only for positions with a live valuation', () {
    final initial = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(
        _bootstrapFor(
          profit: 75,
          positions: [
            _position(),
            _position(
              id: 'position-2',
              symbol: 'BTCUSD',
              entryPrice: 60000,
              volume: 0.01,
            ),
          ],
          positionValuations: const [
            <String, Object?>{
              'positionId': 'position-1',
              'symbol': 'XAUUSD+',
              'currentPrice': 3302,
              'floatingProfit': 15,
            },
          ],
        ),
      ),
    );
    final refreshed = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(
        _bootstrapFor(
          profit: 80,
          positions: [
            _position(entryPrice: 3301),
            _position(
              id: 'position-2',
              symbol: 'BTCUSD',
              entryPrice: 60100,
              volume: 0.01,
            ),
          ],
        ),
      ),
    ).preserveLiveValuationFrom(initial);
    final positionsById = {
      for (final position in refreshed.positions) position.id: position,
    };

    expect(positionsById['position-1']!.currentPrice, 3302);
    expect(positionsById['position-2']!.currentPrice, 60100);
    expect(refreshed.liveValuationPositionIds, {'position-1'});
    expect(refreshed.hasLiveValuation, isFalse);
    expect(refreshed.profit, 80);
  });

  test('refresh does not reuse valuation readiness for a changed identity', () {
    final initial = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(
        _bootstrapFor(
          profit: 15,
          positions: [_position()],
          positionValuations: const [
            <String, Object?>{
              'positionId': 'position-1',
              'symbol': 'XAUUSD+',
              'currentPrice': 3302,
              'floatingProfit': 15,
            },
          ],
        ),
      ),
    );
    final refreshed = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(
        _bootstrapFor(
          profit: 40,
          positions: [
            _position(symbol: 'BTCUSD', entryPrice: 60000, volume: 0.01),
          ],
        ),
      ),
    ).preserveLiveValuationFrom(initial);

    expect(refreshed.positions.single.currentPrice, 60000);
    expect(refreshed.liveValuationPositionIds, isEmpty);
    expect(refreshed.hasLiveValuation, isFalse);
    expect(refreshed.profit, 40);
    expect(refreshed.equity, 5040);
  });

  test(
    'refresh never carries valuation across accounts with overlapping ids',
    () {
      final initial = ExV2AccountViewState.fromBootstrap(
        ExV2Bootstrap.fromJson(
          _bootstrapFor(
            profit: 15,
            positions: [_position()],
            positionValuations: const [
              <String, Object?>{
                'positionId': 'position-1',
                'symbol': 'XAUUSD+',
                'currentPrice': 3302,
                'floatingProfit': 15,
              },
            ],
          ),
        ),
      );
      final refreshed = ExV2AccountViewState.fromBootstrap(
        ExV2Bootstrap.fromJson(
          _bootstrapFor(
            accountId: 'account-2',
            profit: 10,
            positions: [_position(entryPrice: 3400)],
          ),
        ),
      ).preserveLiveValuationFrom(initial);

      expect(refreshed.positions.single.currentPrice, 3400);
      expect(refreshed.liveValuationPositionIds, isEmpty);
      expect(refreshed.hasLiveValuation, isFalse);
      expect(refreshed.profit, 10);
    },
  );

  test('a newer authoritative valuation replaces a preserved older one', () {
    final initial = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(
        _bootstrapFor(
          profit: 15,
          positions: [_position()],
          positionValuations: const [
            <String, Object?>{
              'positionId': 'position-1',
              'symbol': 'XAUUSD+',
              'currentPrice': 3302,
              'floatingProfit': 15,
            },
          ],
        ),
      ),
    );
    final refreshed = ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(
        _bootstrapFor(
          profit: 25,
          positions: [_position()],
          positionValuations: const [
            <String, Object?>{
              'positionId': 'position-1',
              'symbol': 'XAUUSD+',
              'currentPrice': 3303,
              'floatingProfit': 25,
            },
          ],
        ),
      ),
    ).preserveLiveValuationFrom(initial);

    expect(refreshed.positions.single.currentPrice, 3303);
    expect(refreshed.positions.single.profit, 25);
    expect(refreshed.liveValuationPositionIds, {'position-1'});
  });
}

Map<String, Object?> _bootstrapFor({
  String accountId = 'account-1',
  required double profit,
  required List<Map<String, Object?>> positions,
  List<Map<String, Object?>>? positionValuations,
}) => <String, Object?>{
  ..._bootstrap,
  'activeAccount': <String, Object?>{
    ...(_bootstrap['activeAccount']! as Map<String, Object?>),
    'id': accountId,
  },
  'summary': <String, Object?>{
    ...(_bootstrap['summary']! as Map<String, Object?>),
    'accountId': accountId,
    'profit': profit,
    'equity': 5000 + profit,
    'freeMargin': 5000 + profit,
    'positionValuations': ?positionValuations,
  },
  'positions': positions,
};

Map<String, Object?> _position({
  String id = 'position-1',
  String symbol = 'XAUUSD+',
  String side = 'BUY',
  double entryPrice = 3300.5,
  double volume = 0.1,
}) => <String, Object?>{
  'id': id,
  'symbol': symbol,
  'side': side,
  'initialVolume': volume,
  'remainingVolume': volume,
  'entryPrice': entryPrice,
  'stopLoss': null,
  'takeProfit': null,
  'realizedProfit': 0,
  'status': 'open',
  'createdAt': '2026-08-13T07:00:00Z',
  'closedAt': null,
  'rowVersion': '$id-rv',
};

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
