import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_history_reconciler.dart';

void main() {
  test('multiple exit deals produce a volume-weighted close price', () {
    final price = ExV2HistoryReconciler.closePrice(
      const {
        'id': 'position-1',
        'symbol': 'XAUUSD+',
        'status': 'closed',
        'closedAtUtc': '2026-08-17T08:00:00Z',
      },
      const [
        {
          'id': 'deal-1',
          'positionId': 'position-1',
          'dealType': 'out',
          'symbol': 'XAUUSD+',
          'volume': 0.4,
          'price': 100,
          'createdAtUtc': '2026-08-17T07:59:59Z',
        },
        {
          'id': 'deal-2',
          'positionId': 'position-1',
          'dealType': 'close',
          'symbol': 'XAUUSD+',
          'volume': 0.6,
          'price': 110,
          'createdAtUtc': '2026-08-17T08:00:00Z',
        },
      ],
    );

    expect(price, closeTo(106, 0.000001));
  });

  test('positionId aliases link UUIDs case-insensitively', () {
    final enriched = ExV2HistoryReconciler.enrichClosedPositions(
      const [
        {
          'positionId': 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE',
          'symbol': 'EURUSD',
          'status': 'CLOSED',
          'closedAt': '2026-08-17T08:00:00Z',
        },
      ],
      const [
        {
          'id': 'deal-1',
          'positionId': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
          'type': 'out',
          'symbol': 'EURUSD',
          'volume': 1,
          'price': 1.23456,
          'createdAt': '2026-08-17T08:00:00Z',
        },
      ],
    );

    expect(enriched, hasLength(1));
    expect(enriched.single['closePrice'], 1.23456);
  });

  test('close-by exits contribute while unrelated deals are excluded', () {
    final price = ExV2HistoryReconciler.closePrice(
      const {
        'id': 'position-1',
        'symbol': 'XAUUSD+',
        'status': 'closed',
      },
      const [
        {
          'positionId': 'position-1',
          'dealType': 'out_by',
          'symbol': 'XAUUSD+',
          'volume': 0.25,
          'price': 200,
        },
        {
          'positionId': 'position-1',
          'entry': 'OUT',
          'symbol': 'XAUUSD+',
          'volume': 0.75,
          'price': 204,
        },
        {
          'positionId': 'position-2',
          'dealType': 'out',
          'symbol': 'XAUUSD+',
          'volume': 100,
          'price': 999,
        },
      ],
    );

    expect(price, closeTo(203, 0.000001));
  });

  test('open positions are excluded from closed history', () {
    final enriched = ExV2HistoryReconciler.enrichClosedPositions(
      const [
        {'id': 'open-1', 'status': 'open'},
        {
          'id': 'closed-1',
          'status': 'closed',
          'closePrice': 10,
        },
      ],
      const [],
    );

    expect(enriched, hasLength(1));
    expect(enriched.single['id'], 'closed-1');
  });

  test('missing deal volume returns null instead of inventing a price', () {
    final price = ExV2HistoryReconciler.closePrice(
      const {'id': 'position-1', 'status': 'closed'},
      const [
        {
          'positionId': 'position-1',
          'dealType': 'out',
          'price': 123,
        },
      ],
    );

    expect(price, isNull);
  });

  test('legacy row without an id uses one unambiguous symbol-time exit', () {
    final price = ExV2HistoryReconciler.closePrice(
      const {
        'symbol': 'EURUSD',
        'status': 'closed',
        'closedAtUtc': '2026-08-17T08:00:00Z',
      },
      const [
        {
          'positionId': 'position-1',
          'dealType': 'out',
          'symbol': 'EURUSD',
          'volume': 1,
          'price': 1.2,
          'createdAtUtc': '2026-08-17T08:00:00Z',
        },
        {
          'positionId': 'position-2',
          'dealType': 'out',
          'symbol': 'GBPUSD',
          'volume': 1,
          'price': 1.3,
          'createdAtUtc': '2026-08-17T08:00:00Z',
        },
      ],
    );

    expect(price, 1.2);
  });

  test('one legacy exit without positionId remains unambiguous', () {
    final price = ExV2HistoryReconciler.closePrice(
      const {
        'symbol': 'XAUUSD+',
        'status': 'closed',
        'closedAtUtc': '2026-08-17T08:00:00Z',
      },
      const [
        {
          'dealType': 'close',
          'symbol': 'XAUUSD+',
          'volume': 0.01,
          'price': 4321.25,
          'createdAtUtc': '2026-08-17T08:00:00Z',
        },
      ],
    );

    expect(price, 4321.25);
  });

  test('legacy symbol-time fallback refuses ambiguous exit groups', () {
    final price = ExV2HistoryReconciler.closePrice(
      const {
        'symbol': 'EURUSD',
        'status': 'closed',
        'closedAt': '2026-08-17T08:00:00Z',
      },
      const [
        {
          'positionId': 'position-1',
          'type': 'out',
          'symbol': 'EURUSD',
          'volume': 1,
          'price': 1.2,
          'createdAt': '2026-08-17T08:00:00Z',
        },
        {
          'positionId': 'position-2',
          'type': 'out',
          'symbol': 'EURUSD',
          'volume': 1,
          'price': 1.3,
          'createdAt': '2026-08-17T08:00:00Z',
        },
      ],
    );

    expect(price, isNull);
  });
}
