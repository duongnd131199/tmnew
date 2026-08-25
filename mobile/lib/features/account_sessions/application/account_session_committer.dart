import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/account_login/domain/account_password_login_models.dart';
import 'package:trading_mobile/features/account_sessions/application/account_switch_guard.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';

abstract interface class AccountSessionCommitter {
  Future<ExV2BootstrapPublication> commit(AccountPasswordLoginResult result);
}

final class SecureAccountSessionCommitter implements AccountSessionCommitter {
  const SecureAccountSessionCommitter({
    required this.guard,
    required this.tokenStore,
    required this.publisher,
  });

  final AccountSwitchGuard guard;
  final DeviceTokenStore tokenStore;
  final ExV2AccountController publisher;

  @override
  Future<ExV2BootstrapPublication> commit(
    AccountPasswordLoginResult result,
  ) async {
    final lease = guard.tryAcquire();
    if (lease == null) throw const AccountSwitchInProgress();
    String? previousToken;
    var tokenWriteAttempted = false;
    try {
      previousToken = await tokenStore.read();
      tokenWriteAttempted = true;
      await tokenStore.write(result.deviceToken);
      final publication = publisher.publishBootstrap(
        result.bootstrap,
        operationAuthority: lease.authority,
        authoritativeAccountSwitch: true,
        presentation: ExV2AccountPresentation(
          brokerId: result.account.brokerId,
          companyName: result.account.brokerName,
          serverId: result.account.serverId,
          tradingServer: result.account.serverName,
        ),
      );
      if (publication == ExV2BootstrapPublication.rejectedStale) {
        await _restoreToken(previousToken);
        tokenWriteAttempted = false;
      }
      return publication;
    } catch (_) {
      if (tokenWriteAttempted) await _restoreToken(previousToken);
      rethrow;
    } finally {
      guard.release(lease);
    }
  }

  Future<void> _restoreToken(String? previousToken) => previousToken == null
      ? tokenStore.delete()
      : tokenStore.write(previousToken);
}

final accountSessionCommitterProvider = Provider<AccountSessionCommitter>((
  ref,
) {
  return SecureAccountSessionCommitter(
    guard: ref.watch(accountSwitchGuardProvider),
    tokenStore: ref.watch(deviceTokenStoreProvider),
    publisher: ref.read(exV2AccountProvider.notifier),
  );
});
