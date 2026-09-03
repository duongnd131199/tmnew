import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/wallet/presentation/screens/wallet_request_screen.dart';

void main() {
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
