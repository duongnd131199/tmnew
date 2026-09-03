import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/reference_server_catalog.dart';

void main() {
  test('requested Exness servers preserve the live server identity', () {
    const liveServer = MobileTradingServer(
      id: 'yodo-demo-01',
      name: 'YODO-Demo-01',
      brokerId: 'yodo-demo',
    );

    final options = referenceServerOptions(
      brokerId: 'yodo-demo',
      servers: const [liveServer],
    );

    for (final name in const ['Exness-MT5Real15', 'Exness-MT5Real26']) {
      final matches = options.where((option) => option.server.name == name);

      expect(matches, hasLength(1), reason: '$name must be selectable');
      expect(matches.single.server.id, liveServer.id);
      expect(matches.single.server.brokerId, liveServer.brokerId);
    }
  });
}
