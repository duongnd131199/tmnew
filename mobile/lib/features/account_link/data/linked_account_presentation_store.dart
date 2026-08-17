import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trading_mobile/features/account_link/domain/linked_account_presentation.dart';

abstract interface class LinkedAccountPresentationStore {
  Future<LinkedAccountPresentation?> read(String accountId);
  Future<void> write(String accountId, LinkedAccountPresentation value);
}

final class SecureLinkedAccountPresentationStore
    implements LinkedAccountPresentationStore {
  const SecureLinkedAccountPresentationStore(this._storage);

  static const storageKeyPrefix = 'ex_v2_linked_account_presentation';
  final FlutterSecureStorage _storage;

  @override
  Future<LinkedAccountPresentation?> read(String accountId) async {
    final value = await _storage.read(key: _key(accountId));
    if (value == null) return null;
    final json = jsonDecode(value);
    if (json is! Map) throw const FormatException('Invalid presentation');
    return LinkedAccountPresentation.fromJson(json.cast<String, dynamic>());
  }

  @override
  Future<void> write(String accountId, LinkedAccountPresentation value) =>
      _storage.write(key: _key(accountId), value: jsonEncode(value.toJson()));

  String _key(String accountId) {
    final normalized = accountId.trim();
    if (normalized.isEmpty) throw const FormatException('Account id is empty');
    return '${storageKeyPrefix}_$normalized';
  }
}

final linkedAccountPresentationStoreProvider =
    Provider<LinkedAccountPresentationStore>(
      (ref) =>
          const SecureLinkedAccountPresentationStore(FlutterSecureStorage()),
    );

final linkedAccountPresentationProvider =
    FutureProvider.family<LinkedAccountPresentation?, String>(
      (ref, accountId) =>
          ref.watch(linkedAccountPresentationStoreProvider).read(accountId),
    );
