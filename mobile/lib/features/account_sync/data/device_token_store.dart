import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class DeviceTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

final class SecureDeviceTokenStore implements DeviceTokenStore {
  const SecureDeviceTokenStore(this._storage);

  static const storageKey = 'ex_v2_device_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: storageKey, value: token.trim());

  @override
  Future<void> delete() => _storage.delete(key: storageKey);
}

final class DeviceActivationService {
  const DeviceActivationService(this._store);

  final DeviceTokenStore _store;

  Future<void> activate(
    String token, {
    required Future<void> Function(String token) validate,
  }) async {
    final normalized = token.trim();
    try {
      if (normalized.isEmpty) {
        throw const FormatException('Device token cannot be empty');
      }
      await validate(normalized);
      await _store.write(normalized);
    } catch (_) {
      await _store.delete();
      rethrow;
    }
  }
}
