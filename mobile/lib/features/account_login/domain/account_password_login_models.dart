import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

typedef AccountLoginJson = Map<String, dynamic>;

final class AccountPasswordLoginRequest {
  const AccountPasswordLoginRequest({
    required this.brokerId,
    required this.serverId,
    required this.login,
    required this.password,
  });

  final String brokerId;
  final String serverId;
  final String login;
  final String password;

  AccountLoginJson toJson() => <String, dynamic>{
    'brokerId': brokerId,
    'serverId': serverId,
    'login': login,
    'password': password,
  };
}

final class AccountPasswordLoginResult {
  const AccountPasswordLoginResult({
    required this.deviceToken,
    required this.account,
    required this.bootstrap,
  });

  factory AccountPasswordLoginResult.fromJson(AccountLoginJson json) {
    final account = LinkedTradingAccount.fromJson(
      _requiredMap(json, 'account'),
    );
    final bootstrap = ExV2Bootstrap.fromJson(_requiredMap(json, 'bootstrap'));
    if (account.id != bootstrap.account.id ||
        account.id != bootstrap.summary.accountId) {
      throw const FormatException(
        'Login account and bootstrap account identities must match',
      );
    }
    return AccountPasswordLoginResult(
      deviceToken: _requiredString(json, 'deviceToken'),
      account: account,
      bootstrap: bootstrap,
    );
  }

  final String deviceToken;
  final LinkedTradingAccount account;
  final ExV2Bootstrap bootstrap;
}

String _requiredString(AccountLoginJson json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key must be a non-empty string');
}

AccountLoginJson _requiredMap(AccountLoginJson json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw FormatException('$key must be a JSON object');
}
