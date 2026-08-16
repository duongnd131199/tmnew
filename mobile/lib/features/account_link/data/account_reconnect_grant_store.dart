import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AccountReconnectGrantStore {
  Future<String?> read(String accountId);
  Future<void> write(String accountId, String grant);
  Future<void> delete(String accountId);
}

final class SecureAccountReconnectGrantStore
    implements AccountReconnectGrantStore {
  const SecureAccountReconnectGrantStore(this._storage);

  static const storageKeyPrefix = 'ex_v2_account_reconnect_grant';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String accountId) => _storage.read(key: _key(accountId));

  @override
  Future<void> write(String accountId, String grant) async {
    if (grant.isEmpty) throw const FormatException('Reconnect grant is empty');
    await _storage.write(key: _key(accountId), value: grant);
  }

  @override
  Future<void> delete(String accountId) =>
      _storage.delete(key: _key(accountId));

  String _key(String accountId) {
    final normalized = accountId.trim();
    if (normalized.isEmpty) throw const FormatException('Account id is empty');
    return '${storageKeyPrefix}_$normalized';
  }
}
