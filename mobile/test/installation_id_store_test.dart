import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/utils/uuid_v4.dart';
import 'package:trading_mobile/features/account_login/data/installation_id_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('uuidV4 returns RFC 4122 version 4 values', () {
    expect(
      uuidV4(),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('readOrCreate persists and reuses one installation id', () async {
    const expected = '11111111-1111-4111-8111-111111111111';
    final store = SecureInstallationIdStore(
      const FlutterSecureStorage(),
      uuidFactory: () => expected,
    );

    expect(await store.readOrCreate(), expected);
    expect(await store.readOrCreate(), expected);
    expect(
      await const FlutterSecureStorage().read(
        key: SecureInstallationIdStore.storageKey,
      ),
      expected,
    );
  });
}
