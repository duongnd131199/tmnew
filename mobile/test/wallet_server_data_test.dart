import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/wallet/presentation/screens/wallet_screen.dart';

void main() {
  testWidgets('wallet renders server balances instead of fixed demo values', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exV2WalletViewProvider.overrideWithValue(
            const AsyncData(
              ExV2WalletView(
                wallet: ExV2Wallet(
                  currency: 'USD',
                  availableBalance: 1234.5,
                  lockedBalance: 25,
                  totalBalance: 1259.5,
                ),
                transactions: [
                  {
                    'id': 'tx-1',
                    'type': 'deposit',
                    'amount': 250,
                    'status': 'pending',
                    'createdAt': '2026-08-13T08:00:00Z',
                  },
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: WalletScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1,234.50'), findsOneWidget);
    expect(find.textContaining('250.00'), findsOneWidget);
    expect(find.textContaining('pending'), findsOneWidget);
    expect(find.text('2,000.00'), findsNothing);
  });
}
