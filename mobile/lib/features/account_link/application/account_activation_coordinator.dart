import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/account_link/data/account_link_dependencies.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/realtime_market_service.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

final accountMutationsConnectedProvider = Provider<bool>((ref) {
  if (!ref.watch(exV2EnabledProvider)) return true;
  return ref.watch(marketConnectionStatusProvider).value ==
      MarketConnectionStatus.connected;
});

final class AccountMutationOffline implements Exception {
  const AccountMutationOffline();

  @override
  String toString() => 'Account mutations are unavailable while offline';
}

final class AccountActivationIdentityMismatch implements Exception {
  const AccountActivationIdentityMismatch();

  String get message =>
      'Máy chủ trả về dữ liệu của tài khoản khác. Vui lòng thử lại.';

  @override
  String toString() => message;
}

final accountActivationCoordinatorProvider =
    NotifierProvider<AccountActivationCoordinator, int>(
      AccountActivationCoordinator.new,
    );

final class AccountActivationOutcome {
  const AccountActivationOutcome({
    required this.result,
    required this.authority,
    required this.publication,
  });

  final ActivateLinkedAccountResult result;
  final int authority;
  final ExV2BootstrapPublication publication;

  bool get accepted => publication != ExV2BootstrapPublication.rejectedStale;
}

final class AccountActivationCoordinator extends Notifier<int> {
  int _nextAuthority = 0;

  @override
  int build() => 0;

  Future<AccountActivationOutcome> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) async {
    if (!ref.read(accountMutationsConnectedProvider)) {
      throw const AccountMutationOffline();
    }
    final authority = ++_nextAuthority;
    state = authority;
    final result = await ref
        .read(accountLinkRepositoryProvider)
        .activate(accountId, metadata: metadata);
    final account = result.account;
    if (account.id != accountId ||
        result.bootstrap.account.id != accountId ||
        result.bootstrap.summary.accountId != accountId) {
      throw const AccountActivationIdentityMismatch();
    }
    final publication = ref
        .read(exV2AccountProvider.notifier)
        .publishBootstrap(
          result.bootstrap,
          operationAuthority: authority,
          authoritativeAccountSwitch: true,
          presentation: ExV2AccountPresentation(
            brokerId: account.brokerId,
            companyName: account.brokerName,
            serverId: account.serverId,
            tradingServer: account.serverName,
          ),
        );
    return AccountActivationOutcome(
      result: result,
      authority: authority,
      publication: publication,
    );
  }
}
