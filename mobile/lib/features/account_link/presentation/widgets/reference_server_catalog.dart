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

const referenceMetaquotesBroker = MobileBroker(
  id: 'metaquotes',
  name: 'MetaQuotes Ltd.',
  companyName: 'MetaQuotes',
);

/// Removes duplicate broker records while preserving the first API record.
///
/// The mobile catalog may receive the same broker under different IDs, so both
/// the ID and the display name are treated as case-insensitive identities.
List<MobileBroker> deduplicateBrokerCatalog(Iterable<MobileBroker> brokers) {
  final seenIds = <String>{};
  final seenNames = <String>{};
  final unique = <MobileBroker>[];
  for (final broker in brokers) {
    final id = _normalizedBrokerValue(broker.id);
    final name = _normalizedBrokerValue(broker.name);
    if (seenIds.contains(id) || seenNames.contains(name)) continue;
    seenIds.add(id);
    seenNames.add(name);
    unique.add(broker);
  }
  return unique;
}

/// Adds the video-reference MetaQuotes row at presentation time when the API
/// only exposes the Exness broker. This does not change repository responses or
/// create a selectable server/login flow for MetaQuotes.
List<MobileBroker> referenceBrokerCatalog(Iterable<MobileBroker> brokers) {
  final unique = deduplicateBrokerCatalog(brokers);
  MobileBroker? exness;
  MobileBroker? metaquotes;
  for (final broker in unique) {
    if (exness == null && _isReferenceExness(broker)) {
      exness = broker;
    }
    if (metaquotes == null && _isMetaquotes(broker)) {
      metaquotes = broker;
    }
  }

  if (exness == null) return unique;

  final ordered = <MobileBroker>[exness];
  ordered.add(metaquotes ?? referenceMetaquotesBroker);
  for (final broker in unique) {
    if (identical(broker, exness) || identical(broker, metaquotes)) continue;
    if (ordered.any((item) => identical(item, broker))) continue;
    ordered.add(broker);
  }
  return ordered;
}

String referenceBrokerSemanticId(MobileBroker broker) {
  if (_isReferenceExness(broker)) return 'exness';
  if (_isMetaquotes(broker)) return 'metaquotes';
  return broker.id;
}

bool _isReferenceExness(MobileBroker broker) {
  final presentation = referenceBrokerPresentation(broker);
  final identity = _normalizedBrokerValue(
    '${broker.id} ${broker.name} ${broker.companyName ?? ''} '
    '${presentation.name} ${presentation.companyName ?? ''}',
  );
  return presentation.displayAsExness || identity.contains('exness');
}

bool _isMetaquotes(MobileBroker broker) {
  final identity = _normalizedBrokerValue(
    '${broker.id} ${broker.name} ${broker.companyName ?? ''}',
  );
  return identity.contains('metaquotes');
}

String _normalizedBrokerValue(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

const referenceDefaultServerDisplayName = 'Exness-MT5Real20';
const referenceDefaultAccessPoint = 'Access Point #9';

const referenceServerDisplayNames = <String>[
  referenceDefaultServerDisplayName,
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
