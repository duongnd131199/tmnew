import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';

void main() {
  test(
    'activation stores the token only when server validation succeeds',
    () async {
      final store = _MemoryTokenStore();
      final service = DeviceActivationService(store);
      String? storedDuringValidation;

      await service.activate(
        '  test-token  ',
        validate: (_) async {
          storedDuringValidation = await store.read();
        },
      );

      expect(storedDuringValidation, isNull);
      expect(await store.read(), 'test-token');
    },
  );

  test('failed validation removes the rejected token', () async {
    final store = _MemoryTokenStore();
    final service = DeviceActivationService(store);

    await expectLater(
      service.activate(
        'bad-token',
        validate: (_) async => throw StateError('rejected'),
      ),
      throwsStateError,
    );

    expect(await store.read(), isNull);
  });
}

final class _MemoryTokenStore implements DeviceTokenStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}
