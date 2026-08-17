import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';

const referenceServerBrokerDisplayName = 'Exness Technologies Ltd';
const referenceServerBrokerCompanyName = 'Exness';

bool usesReferenceServerPresentation(String brokerId) =>
    brokerId == 'yodo-demo';

final class ReferenceBrokerPresentation {
  const ReferenceBrokerPresentation({
    required this.name,
    required this.companyName,
    required this.displayAsExness,
  });

  final String name;
  final String? companyName;
  final bool displayAsExness;
}

ReferenceBrokerPresentation referenceBrokerPresentation(MobileBroker broker) {
  if (usesReferenceServerPresentation(broker.id)) {
    return const ReferenceBrokerPresentation(
      name: referenceServerBrokerDisplayName,
      companyName: referenceServerBrokerCompanyName,
      displayAsExness: true,
    );
  }
  return ReferenceBrokerPresentation(
    name: broker.name,
    companyName: broker.companyName,
    displayAsExness: false,
  );
}

const referenceServerDisplayNames = <String>[
  'Exness-MT5Real20',
  'Exness-MT5Real17',
  'Exness-MT5Real32',
  'Exness-MT5Trial5',
  'Exness-MT5Real2',
  'Exness-MT5Real11',
  'Exness-MT5Real38',
  'Exness-MT5Trial',
  'Exness-MT5Real27',
  'Exness-MT5Real4',
  'Exness-MT5Trial2',
  'Exness-MT5Real18',
  'Exness-MT5Real25',
  'Exness-MT5Real43',
  'Exness-MT5Real35',
  'Exness-MT5Real28',
  'Exness-MT5Trial14',
  'Exness-MT5Real21',
  'Exness-MT5Real15',
  'Exness-MT5Real19',
  'Exness-MT5Trial15',
  'Exness-MT5Real31',
  'Exness-MT5Real39',
  'Exness-MT5Real24',
];

final class ReferenceServerOption {
  const ReferenceServerOption({
    required this.server,
    required this.rowKey,
    required this.defaultOption,
  });

  final MobileTradingServer server;
  final String rowKey;
  final bool defaultOption;

  bool isSelected(MobileTradingServer? selected) {
    if (selected == null) return defaultOption;
    if (selected.id != server.id) return false;
    if (selected.name == server.name) return true;
    return defaultOption &&
        !referenceServerDisplayNames.contains(selected.name);
  }
}

List<ReferenceServerOption> referenceServerOptions({
  required String brokerId,
  required List<MobileTradingServer> servers,
}) {
  if (!usesReferenceServerPresentation(brokerId)) {
    return [
      for (final server in servers)
        ReferenceServerOption(
          server: server,
          rowKey: server.id,
          defaultOption: false,
        ),
    ];
  }
  if (servers.isEmpty) return const [];

  final source = servers.first;
  return [
    for (var index = 0; index < referenceServerDisplayNames.length; index++)
      ReferenceServerOption(
        server: MobileTradingServer(
          id: source.id,
          name: referenceServerDisplayNames[index],
          brokerId: source.brokerId,
          accountType: source.accountType,
          description: source.description,
        ),
        rowKey: '${source.id}-reference-$index',
        defaultOption: index == 0,
      ),
  ];
}
