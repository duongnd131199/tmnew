import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/data/linked_account_presentation_store.dart';
import 'package:trading_mobile/features/account_link/domain/linked_account_presentation.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('persists the selected display server by linked account ID', () async {
    const storage = FlutterSecureStorage();
    const store = SecureLinkedAccountPresentationStore(storage);
    const selected = LinkedAccountPresentation(
      companyName: 'Exness Technologies Ltd',
      serverName: 'Exness-MT5Real15',
    );

    await store.write('account-1', selected);
    final restored = await store.read('account-1');

    expect(restored?.companyName, selected.companyName);
    expect(restored?.serverName, selected.serverName);
    expect(await store.read('account-2'), isNull);
  });
}
