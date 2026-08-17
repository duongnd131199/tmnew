import 'package:trading_mobile/features/account_login/domain/account_password_login_models.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

class AccountPasswordLoginRepository {
  const AccountPasswordLoginRepository(this._client);

  final ExV2ApiClient _client;

  Future<AccountPasswordLoginResult> login(
    AccountPasswordLoginRequest request, {
    required String installationId,
    required ExV2CommandMetadata metadata,
  }) async => AccountPasswordLoginResult.fromJson(
    await _client.postLoginJson(
      '/mobile/auth/login',
      body: request.toJson(),
      installationId: installationId,
      metadata: metadata,
    ),
  );
}
