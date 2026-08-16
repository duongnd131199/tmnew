import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

class AccountLinkRepository {
  const AccountLinkRepository(this._client);

  final ExV2ApiClient _client;

  Future<List<MobileBroker>> brokers({String query = ''}) async => _maps(
    await _client.getList('/mobile/brokers', queryParameters: {'query': query}),
  ).map(MobileBroker.fromJson).toList(growable: false);

  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) async => _maps(
    await _client.getList(
      '/mobile/brokers/${Uri.encodeComponent(brokerId)}/servers',
      queryParameters: {'query': query},
    ),
  ).map(MobileTradingServer.fromJson).toList(growable: false);

  Future<List<LinkedTradingAccount>> accounts() async => _maps(
    await _client.getList('/mobile/accounts'),
  ).map(LinkedTradingAccount.fromJson).toList(growable: false);

  Future<LinkAccountResult> link(
    LinkAccountRequest request, {
    required ExV2CommandMetadata metadata,
  }) async => LinkAccountResult.fromJson(
    await _client.postJson(
      '/mobile/accounts/link',
      body: request.toJson(),
      metadata: metadata,
    ),
  );

  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) async => ActivateLinkedAccountResult.fromJson(
    await _client.putJson(
      '/mobile/accounts/${Uri.encodeComponent(accountId)}/activate',
      body: const {},
      metadata: metadata,
    ),
  );
}

List<AccountLinkJson> _maps(List<dynamic> values) => values
    .map((value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.cast<String, dynamic>();
      throw const FormatException('Account-link list contains a non-object');
    })
    .toList(growable: false);
