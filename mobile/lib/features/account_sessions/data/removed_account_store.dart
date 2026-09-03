import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class RemovedAccountStore {
  Future<Set<String>> read();

  Future<void> add(String accountId);

  Future<void> remove(String accountId);
}

final class SecureRemovedAccountStore implements RemovedAccountStore {
  const SecureRemovedAccountStore(this._storage);

  static const storageKey = 'ex_v2_removed_account_ids_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<Set<String>> read() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.isEmpty) return <String>{};

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Removed account IDs must be a JSON list');
    }

    return decoded.map((value) {
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException(
          'Removed account ID must be a non-empty string',
        );
      }
      return value.trim();
    }).toSet();
  }

  @override
  Future<void> add(String accountId) => _update(accountId, add: true);

  @override
  Future<void> remove(String accountId) => _update(accountId, add: false);

  Future<void> _update(String accountId, {required bool add}) async {
    final normalized = accountId.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Removed account ID must not be empty');
    }

    final values = await read();
    if (add) {
      values.add(normalized);
    } else {
      values.remove(normalized);
    }

    if (values.isEmpty) {
      await _storage.delete(key: storageKey);
      return;
    }

    final sorted = values.toList()..sort();
    await _storage.write(key: storageKey, value: jsonEncode(sorted));
  }
}

final removedAccountStoreProvider = Provider<RemovedAccountStore>(
  (ref) => const SecureRemovedAccountStore(FlutterSecureStorage()),
);
