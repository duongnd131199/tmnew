import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/account_login/data/account_password_login_dependencies.dart';
import 'package:trading_mobile/features/account_login/domain/account_password_login_models.dart';
import 'package:trading_mobile/features/account_sessions/application/account_session_committer.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

enum AccountPasswordLoginPhase { editing, submitting, succeeded, failed }

final class AccountPasswordLoginState {
  const AccountPasswordLoginState({
    this.phase = AccountPasswordLoginPhase.editing,
    this.errorMessage,
    this.errorCode,
  });

  final AccountPasswordLoginPhase phase;
  final String? errorMessage;
  final String? errorCode;
}

final accountPasswordLoginControllerProvider =
    NotifierProvider<AccountPasswordLoginController, AccountPasswordLoginState>(
      AccountPasswordLoginController.new,
    );

final class AccountPasswordLoginController
    extends Notifier<AccountPasswordLoginState> {
  bool _operationInFlight = false;

  @override
  AccountPasswordLoginState build() => const AccountPasswordLoginState();

  Future<bool> submit({
    required String login,
    required String password,
    ExV2CommandMetadata? metadata,
  }) async {
    if (_operationInFlight) return false;

    final normalizedLogin = login.trim();
    if (!RegExp(r'^\d+$').hasMatch(normalizedLogin) || password.isEmpty) {
      state = const AccountPasswordLoginState(
        phase: AccountPasswordLoginPhase.failed,
        errorMessage: 'Login dạng số và mật khẩu là bắt buộc',
        errorCode: 'invalid_request',
      );
      return false;
    }

    _operationInFlight = true;
    state = const AccountPasswordLoginState(
      phase: AccountPasswordLoginPhase.submitting,
    );
    try {
      final config = ref.read(exV2LoginConfigProvider);
      final installationId = await ref
          .read(installationIdStoreProvider)
          .readOrCreate();
      final result = await ref
          .read(accountPasswordLoginRepositoryProvider)
          .login(
            AccountPasswordLoginRequest(
              brokerId: config.brokerId,
              serverId: config.serverId,
              login: normalizedLogin,
              password: password,
            ),
            installationId: installationId,
            metadata: metadata ?? ExV2CommandMetadata.create(),
          );
      if (!ref.mounted) return false;

      final publication = await ref
          .read(accountSessionCommitterProvider)
          .commit(result);
      if (!ref.mounted) return false;
      if (publication == ExV2BootstrapPublication.rejectedStale) {
        state = const AccountPasswordLoginState(
          phase: AccountPasswordLoginPhase.failed,
          errorMessage: 'Một phiên tài khoản mới hơn đang hoạt động',
          errorCode: 'stale_bootstrap',
        );
        return false;
      }

      state = const AccountPasswordLoginState(
        phase: AccountPasswordLoginPhase.succeeded,
      );
      return true;
    } catch (error) {
      if (ref.mounted) {
        state = AccountPasswordLoginState(
          phase: AccountPasswordLoginPhase.failed,
          errorMessage: _safeMessage(error),
          errorCode: error is ExV2RequestFailure ? error.code : null,
        );
      }
      return false;
    } finally {
      _operationInFlight = false;
    }
  }
}

String _safeMessage(Object error) => switch (error) {
  ExV2RequestFailure failure => failure.safeDisplayMessage,
  ExV2ClientFailure failure => failure.message,
  FormatException exception => exception.message,
  _ => 'Không thể đăng nhập lúc này',
};
