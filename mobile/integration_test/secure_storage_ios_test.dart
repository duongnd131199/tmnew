import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS Keychain persists and removes an opaque sentinel', (
    tester,
  ) async {
    const storage = FlutterSecureStorage();
    const key = 'secure_storage_integration_sentinel';
    const value = 'non-sensitive-test-value';
    addTearDown(() => storage.delete(key: key));

    await storage.delete(key: key);
    await storage.write(key: key, value: value);

    expect(await storage.read(key: key), value);

    await storage.delete(key: key);
    expect(await storage.read(key: key), isNull);
  });

  testWidgets('iOS app reaches the production bootstrap endpoint', (
    tester,
  ) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://trochoi.top/ex/v2/api',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final client = ExV2ApiClient(
      dio: dio,
      tokenReader: () async => 'non-credential-connectivity-probe',
    );

    try {
      await ExV2Repository(client).bootstrap();
      fail('A non-credential probe must not authenticate');
    } on ExV2RequestFailure catch (error) {
      expect(error.statusCode, 401);
      expect(error.code, 'DEVICE_TOKEN_INVALID');
    } finally {
      dio.close(force: true);
    }
  });

}
