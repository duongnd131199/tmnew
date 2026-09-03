import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/account_link/application/account_activation_coordinator.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sessions/data/removed_account_store.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

enum AccountRemovalResult { switched, signedOut }

abstract interface class AccountRemovalService {
  Future<AccountRemovalResult> removeActiveAccount();
}

final class AccountRemovalInProgress implements Exception {
  const AccountRemovalInProgress();
}

final class AccountRemovalUnavailable implements Exception {
  const AccountRemovalUnavailable();
}

final class AccountReplacementActivationRejected implements Exception {
  const AccountReplacementActivationRejected();
}

typedef ActiveAccountIdReader = String? Function();
typedef LinkedAccountsReader = Future<List<LinkedTradingAccount>> Function();
typedef AccountRemovalActivator = Future<bool> Function(String accountId);
typedef AccountRemovalCallback = void Function();

final class LocalAccountRemovalService implements AccountRemovalService {
  LocalAccountRemovalService({
    required this.activeAccountId,
    required this.accounts,
    required this.activate,
    required this.removedAccountStore,
    required this.tokenStore,
    required this.onCatalogChanged,
    required this.onSignedOut,
  });

  final ActiveAccountIdReader activeAccountId;
  final LinkedAccountsReader accounts;
  final AccountRemovalActivator activate;
  final RemovedAccountStore removedAccountStore;
  final DeviceTokenStore tokenStore;
  final AccountRemovalCallback onCatalogChanged;
  final AccountRemovalCallback onSignedOut;

  bool _operationInFlight = false;

  @override
  Future<AccountRemovalResult> removeActiveAccount() async {
    if (_operationInFlight) throw const AccountRemovalInProgress();

    final targetId = activeAccountId()?.trim();
    if (targetId == null || targetId.isEmpty) {
      throw const AccountRemovalUnavailable();
    }

    _operationInFlight = true;
    try {
      final visibleAccounts = await accounts();
      final replacement = visibleAccounts
          .where((account) => account.id != targetId)
          .firstOrNull;

      await removedAccountStore.add(targetId);
      if (replacement != null) {
        try {
          final accepted = await activate(replacement.id);
          if (!accepted) {
            throw const AccountReplacementActivationRejected();
          }
        } catch (error, stackTrace) {
          await removedAccountStore.remove(targetId);
          Error.throwWithStackTrace(error, stackTrace);
        }
        onCatalogChanged();
        return AccountRemovalResult.switched;
      }

      try {
        await tokenStore.delete();
      } catch (error, stackTrace) {
        await removedAccountStore.remove(targetId);
        Error.throwWithStackTrace(error, stackTrace);
      }
      onCatalogChanged();
      onSignedOut();
      return AccountRemovalResult.signedOut;
    } finally {
      _operationInFlight = false;
    }
  }
}

final deviceSessionRevisionProvider =
    NotifierProvider<DeviceSessionRevisionController, int>(
      DeviceSessionRevisionController.new,
    );

final class DeviceSessionRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void advance() => state += 1;
}

final accountRemovalServiceProvider = Provider<AccountRemovalService>((ref) {
  return LocalAccountRemovalService(
    activeAccountId: () =>
        ref.read(exV2AccountProvider).value?.bootstrap.account.id,
    accounts: () => ref.read(linkedTradingAccountsProvider.future),
    activate: (accountId) async {
      final outcome = await ref
          .read(accountActivationCoordinatorProvider.notifier)
          .activate(accountId, metadata: ExV2CommandMetadata.create());
      return outcome.accepted;
    },
    removedAccountStore: ref.watch(removedAccountStoreProvider),
    tokenStore: ref.watch(deviceTokenStoreProvider),
    onCatalogChanged: () => ref.invalidate(linkedTradingAccountsProvider),
    onSignedOut: () {
      ref.invalidate(exV2AccountProvider);
      ref.read(deviceSessionRevisionProvider.notifier).advance();
    },
  );
});
