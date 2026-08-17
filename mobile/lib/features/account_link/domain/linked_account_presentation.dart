import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/reference_server_catalog.dart';

final class LinkedAccountPresentation {
  const LinkedAccountPresentation({
    required this.companyName,
    required this.serverName,
  });

  final String companyName;
  final String serverName;

  Map<String, dynamic> toJson() => {
    'companyName': companyName,
    'serverName': serverName,
  };

  factory LinkedAccountPresentation.fromJson(Map<String, dynamic> json) {
    final companyName = json['companyName'];
    final serverName = json['serverName'];
    if (companyName is! String || companyName.trim().isEmpty) {
      throw const FormatException('companyName must be a non-empty string');
    }
    if (serverName is! String || serverName.trim().isEmpty) {
      throw const FormatException('serverName must be a non-empty string');
    }
    return LinkedAccountPresentation(
      companyName: companyName,
      serverName: serverName,
    );
  }
}

LinkedAccountPresentation presentationForSelectedServer(
  MobileBroker broker,
  MobileTradingServer server,
) => LinkedAccountPresentation(
  companyName: usesReferenceServerPresentation(broker.id)
      ? referenceServerBrokerDisplayName
      : broker.companyName ?? broker.name,
  serverName: server.name,
);

LinkedAccountPresentation resolveLinkedAccountPresentation(
  LinkedTradingAccount account,
  LinkedAccountPresentation? selected,
) {
  if (selected != null) return selected;
  if (usesReferenceServerPresentation(account.brokerId)) {
    return const LinkedAccountPresentation(
      companyName: referenceServerBrokerDisplayName,
      serverName: referenceDefaultServerDisplayName,
    );
  }
  return LinkedAccountPresentation(
    companyName: account.brokerName,
    serverName: account.serverName,
  );
}
