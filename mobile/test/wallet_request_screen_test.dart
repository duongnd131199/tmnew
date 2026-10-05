import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/wallet/presentation/screens/wallet_request_screen.dart';

void main() {
  testWidgets('invalid wallet amount stays on the form without feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WalletRequestScreen(isDeposit: true)),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '-1');
    await tester.tap(find.text('Gửi yêu cầu Nạp'));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Số tiền không hợp lệ'), findsNothing);
    expect(find.byType(WalletRequestScreen), findsOneWidget);
  });

  test('canonical deposit context failure routes to account linking', () {
    const error = ExV2RequestFailure(
      statusCode: 409,
      code: 'DEPOSIT_CANONICAL_CONTEXT_REQUIRED',
      message: 'Canonical account context is required.',
    );

    expect(
      walletRequestFailureDestination(isDeposit: true, error: error),
      '/accounts/add',
    );
    expect(
      walletRequestFailureDestination(isDeposit: false, error: error),
      isNull,
    );
  });
}
