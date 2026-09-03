import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sessions/data/removed_account_store.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'add normalizes and deduplicates account IDs across instances',
    () async {
      const store = SecureRemovedAccountStore(FlutterSecureStorage());

      await store.add(' account-a ');
      await store.add('account-a');
      await store.add('account-b');

      const restored = SecureRemovedAccountStore(FlutterSecureStorage());
      expect(await restored.read(), {'account-a', 'account-b'});
      expect(
        jsonDecode(
          (await const FlutterSecureStorage().read(
            key: SecureRemovedAccountStore.storageKey,
          ))!,
        ),
        ['account-a', 'account-b'],
      );
    },
  );

  test('remove deletes only the selected account ID', () async {
    const store = SecureRemovedAccountStore(FlutterSecureStorage());
    await store.add('account-a');
    await store.add('account-b');

    await store.remove('account-a');

    expect(await store.read(), {'account-b'});
  });

  test('remove deletes its key after the final account ID', () async {
    const storage = FlutterSecureStorage();
    const store = SecureRemovedAccountStore(storage);
    await store.add('account-a');

    await store.remove('account-a');

    expect(await store.read(), isEmpty);
    expect(
      await storage.read(key: SecureRemovedAccountStore.storageKey),
      isNull,
    );
  });

  test('empty account ID is rejected without changing stored IDs', () async {
    const store = SecureRemovedAccountStore(FlutterSecureStorage());
    await store.add('account-a');

    await expectLater(store.add('  '), throwsA(isA<FormatException>()));

    expect(await store.read(), {'account-a'});
  });

  test('malformed secure payload fails without deleting it', () async {
    FlutterSecureStorage.setMockInitialValues({
      SecureRemovedAccountStore.storageKey: '{bad-json',
    });
    const storage = FlutterSecureStorage();
    const store = SecureRemovedAccountStore(storage);

    await expectLater(store.read(), throwsA(isA<FormatException>()));

    expect(
      await storage.read(key: SecureRemovedAccountStore.storageKey),
      '{bad-json',
    );
  });
}
