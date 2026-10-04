import 'package:exness/features/account/data/ex_v2_models.dart';
import 'package:exness/features/wallet/data/wallet_transaction.dart';
import 'package:exness/features/wallet/presentation/wallet_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('withdrawal keeps the server amount and displays its outflow sign', () {
    final transaction = WalletTransaction.fromJson({
      'id': 'withdrawal-1',
      'type': 'withdrawal',
      'amount': 3.5,
      'currency': 'USD',
      'status': 'completed',
      'createdAt': '2026-09-19T02:00:00Z',
    });

    expect(transaction.signedAmount, -3.5);
    expect(transaction.title, 'Rút tiền');
    expect(transaction.createdAt, DateTime.utc(2026, 9, 19, 2));
  });

  test('missing amount stays unknown instead of becoming zero', () {
    final transaction = WalletTransaction.fromJson({
      'id': 'unknown-1',
      'type': 'deposit',
      'currency': 'USD',
    });

    expect(transaction.signedAmount, isNull);
  });

  testWidgets('wallet sheet shows server balance and transaction history', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletTransactionsProvider.overrideWith(
            (ref) async => [
              WalletTransaction.fromJson({
                'id': 'deposit-1',
                'type': 'deposit',
                'amount': 2,
                'currency': 'USD',
                'status': 'completed',
                'createdAt': '2026-09-19T02:00:00Z',
              }),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WalletSheet(
              wallet: ExV2Wallet(
                currency: 'USD',
                availableBalance: 2,
                lockedBalance: 0,
                totalBalance: 2,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Số dư ví demo'), findsOneWidget);
    expect(find.text('2,00 USD'), findsWidgets);
    expect(find.text('Nạp tiền'), findsOneWidget);
    expect(find.text('+2,00 USD'), findsOneWidget);
  });

  testWidgets('wallet sheet exposes an empty transaction state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletTransactionsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WalletSheet(
              wallet: ExV2Wallet(
                currency: 'USD',
                availableBalance: 0,
                lockedBalance: 0,
                totalBalance: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có giao dịch ví'), findsOneWidget);
  });

  testWidgets('wallet history failure gives a retry action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletTransactionsProvider.overrideWith(
            (ref) async => throw StateError('offline'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WalletSheet(
              wallet: ExV2Wallet(
                currency: 'USD',
                availableBalance: 2,
                lockedBalance: 0,
                totalBalance: 2,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không thể tải giao dịch ví'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('unknown wallet transaction type does not imply an inflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletTransactionsProvider.overrideWith(
            (ref) async => [
              WalletTransaction.fromJson({
                'id': 'adjustment-1',
                'type': 'adjustment',
                'amount': 5,
                'currency': 'USD',
              }),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WalletSheet(
              wallet: ExV2Wallet(
                currency: 'USD',
                availableBalance: 0,
                lockedBalance: 0,
                totalBalance: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5,00 USD'), findsOneWidget);
    expect(find.text('+5,00 USD'), findsNothing);
  });
}
