import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/uuid_v4.dart';
import 'device_token_store.dart';
import 'ex_v2_api_client.dart';
import 'ex_v2_models.dart';
import 'ex_v2_repository.dart';

const _storage = FlutterSecureStorage();
const _installationKey = 'ex_v2_installation_id';

final deviceTokenStoreProvider = Provider<DeviceTokenStore>(
  (ref) => const SecureDeviceTokenStore(_storage),
);

final accountDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://trochoi.top/ex/v2/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final accountClientProvider = Provider<ExV2ApiClient>((ref) {
  final store = ref.watch(deviceTokenStoreProvider);
  return ExV2ApiClient(
    dio: ref.watch(accountDioProvider),
    tokenReader: store.read,
  );
});

final accountRepositoryProvider = Provider<ExV2Repository>(
  (ref) => ExV2Repository(ref.watch(accountClientProvider)),
);

final accountSessionProvider =
    AsyncNotifierProvider<AccountSessionController, ExV2Bootstrap?>(
      AccountSessionController.new,
      retry: (_, _) => null,
    );

class AccountSessionController extends AsyncNotifier<ExV2Bootstrap?> {
  @override
  Future<ExV2Bootstrap?> build() async {
    final store = ref.watch(deviceTokenStoreProvider);
    final token = await store.read();
    if (token == null || token.trim().isEmpty) return null;
    try {
      return await ref.watch(accountRepositoryProvider).bootstrap();
    } catch (error) {
      if (!_isSessionRejected(error)) rethrow;
      await store.delete();
      return null;
    }
  }

  Future<void> login({
    required String login,
    required String password,
    String brokerId = 'yodo-demo',
    String serverId = 'yodo-demo-01',
  }) async {
    if (login.trim().isEmpty || password.isEmpty) {
      throw const FormatException('Vui lòng nhập tài khoản và mật khẩu');
    }
    state = const AsyncLoading();
    try {
      final installationId = await _installationId();
      final response = await ref
          .read(accountClientProvider)
          .postLoginJson(
            '/mobile/auth/login',
            body: {
              'brokerId': brokerId,
              'serverId': serverId,
              'login': login.trim(),
              'password': password,
            },
            installationId: installationId,
            metadata: ExV2CommandMetadata.create(),
          );
      final token = response['deviceToken'];
      final account = response['account'];
      final rawBootstrap = response['bootstrap'];
      if (token is! String ||
          token.isEmpty ||
          account is! Map ||
          rawBootstrap is! Map) {
        throw const FormatException('Phản hồi đăng nhập không hợp lệ');
      }
      final bootstrap = ExV2Bootstrap.fromJson(
        rawBootstrap.cast<String, dynamic>(),
      );
      if (account['id'] != bootstrap.account.id ||
          bootstrap.summary.accountId != bootstrap.account.id) {
        throw const FormatException('Tài khoản đăng nhập không khớp');
      }
      await ref.read(deviceTokenStoreProvider).write(token);
      state = AsyncData(bootstrap);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> refresh() async {
    try {
      final next = await ref.read(accountRepositoryProvider).bootstrap();
      state = AsyncData(next);
    } catch (error) {
      if (!await clearRejectedSession(error)) rethrow;
    }
  }

  Future<bool> clearRejectedSession(Object error) async {
    if (!_isSessionRejected(error)) return false;
    state = const AsyncData(null);
    await ref.read(deviceTokenStoreProvider).delete();
    return true;
  }

  Future<void> logout() async {
    await ref.read(deviceTokenStoreProvider).delete();
    state = const AsyncData(null);
  }

  Future<String> _installationId() async {
    final existing = await _storage.read(key: _installationKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = uuidV4();
    await _storage.write(key: _installationKey, value: created);
    return created;
  }
}

bool _isSessionRejected(Object error) =>
    error is ExV2RequestFailure &&
    (error.statusCode == 401 || error.statusCode == 403);

final historyPositionsProvider = FutureProvider<List<JsonMap>>((ref) async {
  final session = await ref.watch(accountSessionProvider.future);
  if (session == null) return const [];
  return ref.watch(accountRepositoryProvider).historyPositions(pageSize: 50);
});

final historyDealsProvider = FutureProvider<List<JsonMap>>((ref) async {
  final session = await ref.watch(accountSessionProvider.future);
  if (session == null) return const [];
  return ref.watch(accountRepositoryProvider).historyDeals(pageSize: 50);
});

typedef AccountSettingsSnapshot = ({String? accountId, JsonMap values});

final accountSettingsProvider = FutureProvider<AccountSettingsSnapshot>((
  ref,
) async {
  final session = await ref.watch(accountSessionProvider.future);
  if (session == null) {
    return (accountId: null, values: const <String, dynamic>{});
  }
  return (
    accountId: session.account.id,
    values: await ref.watch(accountRepositoryProvider).settings(),
  );
});

final accountCatalogProvider = FutureProvider<List<JsonMap>>((ref) async {
  final session = await ref.watch(accountSessionProvider.future);
  if (session == null) return const [];
  final items = await ref
      .watch(accountClientProvider)
      .getList('/mobile/accounts');
  return items.map((item) => (item as Map).cast<String, dynamic>()).toList();
});
