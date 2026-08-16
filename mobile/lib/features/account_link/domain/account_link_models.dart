import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

typedef AccountLinkJson = Map<String, dynamic>;

final class MobileBroker {
  const MobileBroker({
    required this.id,
    required this.name,
    this.companyName,
    this.description,
    this.logoUrl,
  });

  factory MobileBroker.fromJson(AccountLinkJson json) => MobileBroker(
    id: _requiredString(json, 'id'),
    name: _requiredString(json, 'name'),
    companyName: _optionalString(json, 'companyName'),
    description: _optionalString(json, 'description'),
    logoUrl: _optionalString(json, 'logoUrl'),
  );

  final String id;
  final String name;
  final String? companyName;
  final String? description;
  final String? logoUrl;

  AccountLinkJson toJson() => {
    'id': id,
    'name': name,
    'companyName': ?companyName,
    'description': ?description,
    'logoUrl': ?logoUrl,
  };
}

final class MobileTradingServer {
  const MobileTradingServer({
    required this.id,
    required this.name,
    required this.brokerId,
    this.accountType,
    this.description,
  });

  factory MobileTradingServer.fromJson(AccountLinkJson json) =>
      MobileTradingServer(
        id: _requiredString(json, 'id'),
        name: _requiredString(json, 'name'),
        brokerId: _requiredString(json, 'brokerId'),
        accountType: _optionalString(json, 'accountType'),
        description: _optionalString(json, 'description'),
      );

  final String id;
  final String name;
  final String brokerId;
  final String? accountType;
  final String? description;

  AccountLinkJson toJson() => {
    'id': id,
    'name': name,
    'brokerId': brokerId,
    'accountType': ?accountType,
    'description': ?description,
  };
}

final class LinkedTradingAccount {
  const LinkedTradingAccount({
    required this.id,
    required this.brokerId,
    required this.brokerName,
    required this.serverId,
    required this.serverName,
    required this.login,
    required this.isActive,
    this.displayName,
    this.currency,
    this.status,
  });

  factory LinkedTradingAccount.fromJson(AccountLinkJson json) =>
      LinkedTradingAccount(
        id: _requiredString(json, 'id'),
        brokerId: _requiredString(json, 'brokerId'),
        brokerName: _requiredString(json, 'brokerName'),
        serverId: _requiredString(json, 'serverId'),
        serverName: _requiredString(json, 'serverName'),
        login: _requiredString(json, 'login'),
        isActive: _requiredBool(json, 'isActive'),
        displayName: _optionalString(json, 'displayName'),
        currency: _optionalString(json, 'currency'),
        status: _optionalString(json, 'status'),
      );

  final String id;
  final String brokerId;
  final String brokerName;
  final String serverId;
  final String serverName;
  final String login;
  final bool isActive;
  final String? displayName;
  final String? currency;
  final String? status;

  AccountLinkJson toJson() => {
    'id': id,
    'brokerId': brokerId,
    'brokerName': brokerName,
    'serverId': serverId,
    'serverName': serverName,
    'login': login,
    'isActive': isActive,
    'displayName': ?displayName,
    'currency': ?currency,
    'status': ?status,
  };
}

final class LinkAccountRequest {
  const LinkAccountRequest({
    required this.brokerId,
    required this.serverId,
    required this.login,
    required this.password,
    required this.savePassword,
  });

  final String brokerId;
  final String serverId;
  final String login;
  final String password;
  final bool savePassword;

  AccountLinkJson toJson() => {
    'brokerId': brokerId,
    'serverId': serverId,
    'login': login,
    'password': password,
    'savePassword': savePassword,
  };
}

final class LinkAccountResult {
  const LinkAccountResult({
    required this.account,
    required this.reconnectGrant,
    required this.alreadyLinked,
  });

  factory LinkAccountResult.fromJson(AccountLinkJson json) => LinkAccountResult(
    account: LinkedTradingAccount.fromJson(_requiredMap(json, 'account')),
    reconnectGrant: _requiredString(json, 'reconnectGrant'),
    alreadyLinked: _requiredBool(json, 'alreadyLinked'),
  );

  final LinkedTradingAccount account;
  final String reconnectGrant;
  final bool alreadyLinked;
}

final class ActivateLinkedAccountResult {
  const ActivateLinkedAccountResult({
    required this.account,
    required this.bootstrap,
  });

  factory ActivateLinkedAccountResult.fromJson(AccountLinkJson json) {
    final account = LinkedTradingAccount.fromJson(
      _requiredMap(json, 'account'),
    );
    final bootstrap = ExV2Bootstrap.fromJson(_requiredMap(json, 'bootstrap'));
    final accountId = account.id;
    if (bootstrap.account.id != accountId ||
        bootstrap.summary.accountId != accountId) {
      throw const FormatException(
        'Activated account and bootstrap account identities must match',
      );
    }
    return ActivateLinkedAccountResult(account: account, bootstrap: bootstrap);
  }

  final LinkedTradingAccount account;
  final ExV2Bootstrap bootstrap;
}

String _requiredString(AccountLinkJson json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key must be a non-empty string');
}

String? _optionalString(AccountLinkJson json, String key) {
  final value = json[key];
  return value is String && value.trim().isNotEmpty ? value : null;
}

bool _requiredBool(AccountLinkJson json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a boolean');
}

AccountLinkJson _requiredMap(AccountLinkJson json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw FormatException('$key must be a JSON object');
}
