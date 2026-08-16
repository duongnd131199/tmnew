import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/data/account_reconnect_grant_store.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

enum AccountLinkPhase {
  idle,
  loadingCatalog,
  editing,
  submitting,
  activating,
  succeeded,
  failed,
}

final class AccountLinkState {
  const AccountLinkState({
    this.phase = AccountLinkPhase.idle,
    this.brokers = const [],
    this.servers = const [],
    this.accounts = const [],
    this.selectedBroker,
    this.selectedServer,
    this.login = '',
    this.password = '',
    this.savePassword = true,
    this.errorMessage,
    this.linkedAccount,
    this.reconnectGrant,
  });

  final AccountLinkPhase phase;
  final List<MobileBroker> brokers;
  final List<MobileTradingServer> servers;
  final List<LinkedTradingAccount> accounts;
  final MobileBroker? selectedBroker;
  final MobileTradingServer? selectedServer;
  final String login;
  final String password;
  final bool savePassword;
  final String? errorMessage;
  final LinkedTradingAccount? linkedAccount;
  final String? reconnectGrant;

  bool get canSubmit =>
      selectedBroker != null &&
      selectedServer != null &&
      RegExp(r'^\d+$').hasMatch(login.trim()) &&
      password.isNotEmpty &&
      phase != AccountLinkPhase.submitting &&
      phase != AccountLinkPhase.activating;

  AccountLinkState copyWith({
    AccountLinkPhase? phase,
    List<MobileBroker>? brokers,
    List<MobileTradingServer>? servers,
    List<LinkedTradingAccount>? accounts,
    Object? selectedBroker = _absent,
    Object? selectedServer = _absent,
    String? login,
    String? password,
    bool? savePassword,
    Object? errorMessage = _absent,
    Object? linkedAccount = _absent,
    Object? reconnectGrant = _absent,
  }) => AccountLinkState(
    phase: phase ?? this.phase,
    brokers: List.unmodifiable(brokers ?? this.brokers),
    servers: List.unmodifiable(servers ?? this.servers),
    accounts: List.unmodifiable(accounts ?? this.accounts),
    selectedBroker: identical(selectedBroker, _absent)
        ? this.selectedBroker
        : selectedBroker as MobileBroker?,
    selectedServer: identical(selectedServer, _absent)
        ? this.selectedServer
        : selectedServer as MobileTradingServer?,
    login: login ?? this.login,
    password: password ?? this.password,
    savePassword: savePassword ?? this.savePassword,
    errorMessage: identical(errorMessage, _absent)
        ? this.errorMessage
        : errorMessage as String?,
    linkedAccount: identical(linkedAccount, _absent)
        ? this.linkedAccount
        : linkedAccount as LinkedTradingAccount?,
    reconnectGrant: identical(reconnectGrant, _absent)
        ? this.reconnectGrant
        : reconnectGrant as String?,
  );
}

const _absent = Object();

typedef AccountLinkBootstrapPublisher = void Function(ExV2Bootstrap bootstrap);

final accountLinkRepositoryProvider = Provider<AccountLinkRepository>(
  (ref) => AccountLinkRepository(ref.watch(exV2ApiClientProvider)),
);

final accountReconnectGrantStoreProvider = Provider<AccountReconnectGrantStore>(
  (ref) => const SecureAccountReconnectGrantStore(FlutterSecureStorage()),
);

final accountLinkBootstrapPublisherProvider =
    Provider<AccountLinkBootstrapPublisher>(
      (ref) => ref.read(exV2AccountProvider.notifier).publishBootstrap,
    );

final accountLinkControllerProvider =
    AsyncNotifierProvider<AccountLinkController, AccountLinkState>(
      AccountLinkController.new,
    );

final class AccountLinkController extends AsyncNotifier<AccountLinkState> {
  bool _operationInFlight = false;
  int _catalogGeneration = 0;

  @override
  Future<AccountLinkState> build() async => const AccountLinkState();

  AccountLinkState get _current => state.value ?? const AccountLinkState();

  Future<void> loadCatalog({String query = ''}) async {
    final generation = ++_catalogGeneration;
    final before = _current;
    state = AsyncData(
      before.copyWith(
        phase: AccountLinkPhase.loadingCatalog,
        errorMessage: null,
      ),
    );
    try {
      final repository = ref.read(accountLinkRepositoryProvider);
      final results = await Future.wait<Object>([
        repository.brokers(query: query),
        repository.accounts(),
      ]);
      if (!ref.mounted || generation != _catalogGeneration) return;
      state = AsyncData(
        _current.copyWith(
          phase: AccountLinkPhase.editing,
          brokers: results[0] as List<MobileBroker>,
          accounts: results[1] as List<LinkedTradingAccount>,
        ),
      );
    } catch (error) {
      if (generation == _catalogGeneration) _fail(error);
    }
  }

  Future<void> loadServers(String brokerId, {String query = ''}) async {
    final generation = ++_catalogGeneration;
    state = AsyncData(
      _current.copyWith(
        phase: AccountLinkPhase.loadingCatalog,
        errorMessage: null,
      ),
    );
    try {
      final servers = await ref
          .read(accountLinkRepositoryProvider)
          .servers(brokerId, query: query);
      if (!ref.mounted ||
          generation != _catalogGeneration ||
          _current.selectedBroker?.id != brokerId) {
        return;
      }
      state = AsyncData(
        _current.copyWith(phase: AccountLinkPhase.editing, servers: servers),
      );
    } catch (error) {
      if (generation == _catalogGeneration &&
          _current.selectedBroker?.id == brokerId) {
        _fail(error);
      }
    }
  }

  void selectBroker(MobileBroker broker) {
    _catalogGeneration += 1;
    state = AsyncData(
      _current.copyWith(
        phase: AccountLinkPhase.editing,
        selectedBroker: broker,
        selectedServer: null,
        servers: const [],
        errorMessage: null,
      ),
    );
  }

  void selectServer(MobileTradingServer server) {
    final selectedBrokerId = _current.selectedBroker?.id;
    if (server.brokerId != null && server.brokerId != selectedBrokerId) {
      throw ArgumentError.value(
        server.brokerId,
        'server.brokerId',
        'Server does not belong to the selected broker',
      );
    }
    state = AsyncData(
      _current.copyWith(
        phase: AccountLinkPhase.editing,
        selectedServer: server,
        errorMessage: null,
      ),
    );
  }

  void updateLogin(String value) => _edit(_current.copyWith(login: value));

  void updatePassword(String value) =>
      _edit(_current.copyWith(password: value));

  void updateSavePassword(bool value) =>
      _edit(_current.copyWith(savePassword: value));

  void _edit(AccountLinkState next) {
    state = AsyncData(
      next.copyWith(phase: AccountLinkPhase.editing, errorMessage: null),
    );
  }

  Future<ActivateLinkedAccountResult?> submit({
    ExV2CommandMetadata? linkMetadata,
    ExV2CommandMetadata? activateMetadata,
  }) async {
    final before = _current;
    if (_operationInFlight) return null;
    if (!before.canSubmit) {
      state = AsyncData(
        before.copyWith(
          phase: AccountLinkPhase.failed,
          errorMessage: 'Server, numeric login, and password are required',
        ),
      );
      return null;
    }

    _operationInFlight = true;
    state = AsyncData(
      before.copyWith(
        phase: AccountLinkPhase.submitting,
        errorMessage: null,
        linkedAccount: null,
      ),
    );
    try {
      final repository = ref.read(accountLinkRepositoryProvider);
      final request = LinkAccountRequest(
        brokerId: before.selectedBroker!.id,
        serverId: before.selectedServer!.id,
        login: before.login.trim(),
        password: before.password,
        savePassword: before.savePassword,
      );
      final linked = await repository.link(
        request,
        metadata: linkMetadata ?? ExV2CommandMetadata.create(),
      );
      if (!ref.mounted) return null;

      final grantStore = ref.read(accountReconnectGrantStoreProvider);
      final grant = linked.reconnectGrant;
      if (before.savePassword && grant != null) {
        await grantStore.write(linked.account.id, grant);
      } else if (!before.savePassword) {
        await grantStore.delete(linked.account.id);
      }
      if (!ref.mounted) return null;

      state = AsyncData(
        _current.copyWith(
          phase: AccountLinkPhase.activating,
          password: '',
          linkedAccount: linked.account,
          reconnectGrant: grant,
        ),
      );
      final activated = await repository.activate(
        linked.account.id,
        metadata: activateMetadata ?? ExV2CommandMetadata.create(),
      );
      if (!ref.mounted) return null;

      ref.read(accountLinkBootstrapPublisherProvider)(activated.bootstrap);
      state = AsyncData(
        _current.copyWith(
          phase: AccountLinkPhase.succeeded,
          linkedAccount: activated.account,
          password: '',
          errorMessage: null,
        ),
      );
      return activated;
    } catch (error) {
      if (!ref.mounted) return null;
      final clearPassword = _isInvalidCredentials(error);
      state = AsyncData(
        _current.copyWith(
          phase: AccountLinkPhase.failed,
          password: clearPassword ? '' : _current.password,
          errorMessage: _message(error),
        ),
      );
      return null;
    } finally {
      _operationInFlight = false;
    }
  }

  void _fail(Object error) {
    if (!ref.mounted) return;
    state = AsyncData(
      _current.copyWith(
        phase: AccountLinkPhase.failed,
        errorMessage: _message(error),
      ),
    );
  }
}

bool _isInvalidCredentials(Object error) {
  if (error is! ExV2RequestFailure) return false;
  final code = error.code?.toLowerCase().replaceAll('-', '_');
  return error.statusCode == 401 ||
      code == 'invalid_credentials' ||
      code == 'invalid_credential';
}

String _message(Object error) => switch (error) {
  ExV2ClientFailure failure => failure.message,
  FormatException exception => exception.message,
  _ => 'Unable to link this account',
};
