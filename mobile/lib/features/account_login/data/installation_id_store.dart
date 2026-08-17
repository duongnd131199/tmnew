import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trading_mobile/core/utils/uuid_v4.dart';

abstract interface class InstallationIdStore {
  Future<String> readOrCreate();
}

final class SecureInstallationIdStore implements InstallationIdStore {
  const SecureInstallationIdStore(this._storage, {this.uuidFactory = uuidV4});

  static const storageKey = 'ex_v2_installation_id';

  final FlutterSecureStorage _storage;
  final UuidV4Factory uuidFactory;

  @override
  Future<String> readOrCreate() async {
    final existing = await _storage.read(key: storageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final created = uuidFactory();
    await _storage.write(key: storageKey, value: created);
    return created;
  }
}
