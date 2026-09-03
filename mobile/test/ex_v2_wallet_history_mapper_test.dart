import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_wallet_history_mapper.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';

void main() {
  test('maps every deposit and withdrawal status into Balance rows', () {
    final entries = ExV2WalletHistoryMapper.entries(
      historyTransactions: const [],
      deposits: const [
        {
          'id': 'deposit-pending',
          'amount': 518.54,
          'status': 'pending',
          'reference': 'D-ALLINT-USD-INT-924750483461',
          'createdAt': '2026-07-21T02:28:53',
        },
        {
          'id': 'deposit-rejected',
          'amount': 20,
          'status': 'rejected',
          'reference': 'D-REJECTED-20',
          'createdAt': '2026-07-21T03:00:00',
        },
      ],
      withdrawals: const [
        {
          'id': 'withdraw-approved',
          'amount': 2000,
          'status': 'approved',
          'reference': 'W-BANKVNGT-USD-1475391737862',
          'processedAt': '2026-07-21T06:49:19',
        },
      ],
    );

    expect(entries, hasLength(3));
    expect(entries.map((entry) => entry.title), everyElement('Balance'));
    expect(entries.map((entry) => entry.side), everyElement(isNull));
    expect(entries.map((entry) => entry.profit), [518.54, 20, -2000]);
    expect(entries.first.subtitle, 'D-ALLINT-USD-INT-924750483461');
    expect(entries[1].subtitle, matches(RegExp(r'^D-ALLINT-USD-INT-\d{12}$')));
    expect(
      _numericSuffix(entries[1].subtitle!),
      greaterThan(_numericSuffix(entries.first.subtitle!)),
    );
    expect(entries.last.subtitle, 'W-BANKVNGT-USD-1475391737862');
    expect(entries.map((entry) => entry.time), [
      '2026.07.21 02:28:53',
      '2026.07.21 03:00:00',
      '2026.07.21 06:49:19',
    ]);
  });

  test('prefers canonical transactions and removes duplicate requests', () {
    final entries = ExV2WalletHistoryMapper.entries(
      historyTransactions: const [
        {
          'id': 'transaction-1',
          'transactionType': 'deposit',
          'amount': 518.54,
          'reference': 'D-ALLINT-USD-INT-924750483461',
          'completedAtUtc': '2026-07-21T02:28:53',
        },
      ],
      deposits: const [
        {
          'id': 'deposit-request-1',
          'amount': 518.54,
          'status': 'completed',
          'reference': 'D-ALLINT-USD-INT-924750483461',
          'createdAtUtc': '2026-07-21T02:20:00',
        },
      ],
      withdrawals: const [
        {
          'id': 'withdrawal-1',
          'amount': 2000,
          'status': 'completed',
          'reference': 'W-BANKVNGT-USD-1475391737862',
          'createdAtUtc': '2026-07-21T06:49:19',
        },
      ],
    );

    expect(entries, hasLength(2));
    expect(entries.first.id, 'wallet-transaction-1');
    expect(entries.first.subtitle, 'D-ALLINT-USD-INT-924750483461');
    expect(entries.last.profit, -2000);
  });

  test('uses the history invoice as the deposit transaction code', () {
    const transactionId = '32b9c810-91f0-4d4c-b976-3dd8f0f726ee';
    const transactionCode = '681540511910';
    final entries = ExV2WalletHistoryMapper.entries(
      historyTransactions: const [
        {
          'id': '2fd15448-34fd-4414-bf56-37061053c498',
          'accountId': 'account-1',
          'invoice': '924750483461',
          'from': 'wallet',
          'to': 'trading-account',
          'type': 'deposit',
          'amount': 50.0,
          'currency': 'USD',
          'status': 'completed',
          'createdAtUtc': '2026-09-03T02:31:36Z',
        },
        {
          'id': transactionId,
          'accountId': 'account-1',
          'invoice': transactionCode,
          'from': 'wallet',
          'to': 'trading-account',
          'type': 'deposit',
          'amount': 100.0,
          'amountValue': 100.0,
          'currency': 'USD',
          'status': 'completed',
          'createdAtUtc': '2026-09-04T02:31:36Z',
          'timestamp': '2026-09-04T02:31:36Z',
          'depositRequestId': '557ab614-b0ec-4132-885f-e642ace92820',
        },
      ],
      deposits: const [],
      withdrawals: const [],
    );

    expect(entries, hasLength(2));
    final target = entries.singleWhere(
      (entry) => entry.id == 'wallet-$transactionId',
    );
    expect(target.subtitle, 'D-ALLINT-USD-INT-$transactionCode');
    final normalizedTarget = ExV2WalletHistoryMapper.normalizeReferences(
      entries,
    ).singleWhere((entry) => entry.id == 'wallet-$transactionId');
    expect(normalizedTarget.subtitle, 'D-ALLINT-USD-INT-$transactionCode');
  });

  test('maps and merges the production legacy payment contract', () {
    final entries = ExV2WalletHistoryMapper.entries(
      historyTransactions: const [
        {
          'id': 'transaction:1919',
          'type': 'Rút tiền',
          'timestamp': '2026-08-07T15:14:25.3111534+00:00',
          'amountValue': 11000.0,
          'currency': 'USD',
          'status': 'hoàn tất',
        },
        {
          'id': 'transaction:1917',
          'type': 'Nạp tiền',
          'timestamp': '2026-08-04T10:00:00.1200000+00:00',
          'amountValue': 50.78,
          'currency': 'USD',
          'status': 'hoàn tất',
        },
      ],
      deposits: const [
        {
          'id': 'deposit:49',
          'amount': 50.78,
          'currency': 'USD',
          'method': 'VNVIETQR-1',
          'reference': '998519055159',
          'status': 'hoàn tất',
          'createdAt': '2026-08-04T10:00:00.0900000+00:00',
          'updatedAt': '2026-08-04T10:03:00+00:00',
        },
      ],
      withdrawals: const [
        {
          'id': 'withdrawal:1064',
          'amount': 11000.0,
          'currency': 'USD',
          'bankName': 'MB Bank',
          'maskedBankAccount': '***3007',
          'status': 'hoàn tất',
          'createdAt': '2026-08-07T15:14:25.2778746+00:00',
          'updatedAt': '2026-08-07T15:17:37.7907667+00:00',
        },
      ],
    );

    expect(entries, hasLength(2));
    expect(entries.map((entry) => entry.id), [
      'wallet-transaction:1917',
      'wallet-transaction:1919',
    ]);
    expect(entries.map((entry) => entry.profit), [50.78, -11000]);
    expect(
      entries.first.subtitle,
      matches(RegExp(r'^D-ALLINT-USD-INT-\d{12}$')),
    );
    expect(entries.last.subtitle, matches(RegExp(r'^W-BANKVNGT-USD-\d{13}$')));
    expect(entries.map((entry) => entry.time), [
      '2026.08.04 17:00:00',
      '2026.08.07 22:14:25',
    ]);
  });

  test(
    'normalizes wallet references to stable MT5 prefixes and increasing digits',
    () {
      const deposits = <Map<String, Object?>>[
        {
          'id': 'deposit-reference',
          'amount': 518.54,
          'reference': '924750483461',
          'createdAt': '2026-07-21T02:28:53',
        },
        {
          'id': 'deposit-legacy',
          'amount': 20,
          'method': 'VNVIETQR-1',
          'reference': 'D-REJECTED-20',
          'createdAt': '2026-07-21T02:29:53',
        },
      ];
      const withdrawals = <Map<String, Object?>>[
        {
          'id': 'withdrawal-reference',
          'amount': 2000,
          'reference': 'W-BANKVNGT-USD-1475391737862',
          'createdAt': '2026-07-21T06:49:19',
        },
        {
          'id': 'withdrawal-legacy',
          'amount': 300,
          'bankName': 'MB Bank',
          'createdAt': '2026-07-21T06:50:19',
        },
      ];

      List<String> mapReferences() => ExV2WalletHistoryMapper.entries(
        historyTransactions: const [],
        deposits: deposits,
        withdrawals: withdrawals,
      ).map((entry) => entry.subtitle!).toList(growable: false);

      final firstLoad = mapReferences();
      final secondLoad = mapReferences();
      final depositReferences = firstLoad
          .where((reference) => reference.startsWith('D-'))
          .toList(growable: false);
      final withdrawalReferences = firstLoad
          .where((reference) => reference.startsWith('W-'))
          .toList(growable: false);

      expect(secondLoad, firstLoad);
      expect(depositReferences.first, 'D-ALLINT-USD-INT-924750483461');
      expect(
        depositReferences,
        everyElement(matches(RegExp(r'^D-ALLINT-USD-INT-\d{12}$'))),
      );
      expect(withdrawalReferences.first, 'W-BANKVNGT-USD-1475391737862');
      expect(
        withdrawalReferences,
        everyElement(matches(RegExp(r'^W-BANKVNGT-USD-\d{13}$'))),
      );
      expect(
        _numericSuffix(depositReferences[1]),
        greaterThan(_numericSuffix(depositReferences[0])),
      );
      expect(
        _numericSuffix(withdrawalReferences[1]),
        greaterThan(_numericSuffix(withdrawalReferences[0])),
      );
    },
  );

  test('normalizes Balance rows already returned by history positions', () {
    const rows = <DemoHistoryPosition>[
      DemoHistoryPosition(
        id: 'balance-626',
        title: 'Balance',
        profit: 50.40,
        time: '2026.06.23 22:17:08',
        subtitle: 'D-ALLINT-USD-INT-928059393626',
      ),
      DemoHistoryPosition(
        id: 'balance-624',
        title: 'Balance',
        profit: 537.15,
        time: '2026.06.23 22:17:08',
        subtitle: 'D-ALLINT-USD-INT-928059393624',
      ),
      DemoHistoryPosition(
        id: 'withdrawal-legacy',
        title: 'Balance',
        profit: -15,
        time: '2026.06.23 22:26:25',
        subtitle: 'MB Bank transfer 19',
      ),
    ];

    final normalized = ExV2WalletHistoryMapper.normalizeReferences(rows);

    expect(normalized.map((entry) => entry.subtitle), [
      'D-ALLINT-USD-INT-928059393626',
      'D-ALLINT-USD-INT-928059393627',
      matches(RegExp(r'^W-BANKVNGT-USD-\d{13}$')),
    ]);
  });
}

int _numericSuffix(String reference) =>
    int.parse(reference.substring(reference.lastIndexOf('-') + 1));
