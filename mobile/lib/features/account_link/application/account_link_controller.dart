import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/account_link/data/account_link_dependencies.dart';
import 'package:trading_mobile/features/account_link/data/linked_account_presentation_store.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/domain/linked_account_presentation.dart';
import 'package:trading_mobile/features/account_sessions/data/removed_account_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_link/application/account_activation_coordinator.dart';

export 'package:trading_mobile/features/account_link/data/account_link_dependencies.dart'
    show accountLinkRepositoryProvider;

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
    this.errorMessage,
    this.linkedAccount,
  });

  final AccountLinkPhase phase;
  final List<MobileBroker> brokers;
  final List<MobileTradingServer> servers;
  final List<LinkedTradingAccount> accounts;
  final MobileBroker? selectedBroker;
  final MobileTradingServer? selectedServer;
  final String login;
  final String password;
  final String? errorMessage;
  final LinkedTradingAccount? linkedAccount;

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
    Object? errorMessage = _absent,
    Object? linkedAccount = _absent,
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
    errorMessage: identical(errorMessage, _absent)
        ? this.errorMessage
        : errorMessage as String?,
    linkedAccount: identical(linkedAccount, _absent)
        ? this.linkedAccount
        : linkedAccount as LinkedTradingAccount?,
  );
}

const _absent = Object();

final accountLinkControllerProvider =
    AsyncNotifierProvider<AccountLinkController, AccountLinkState>(
      AccountLinkController.new,
    );

final class AccountLinkIdentityMismatch implements Exception {
  const AccountLinkIdentityMismatch();

  @override
  String toString() => 'Linked account identity does not match the request';
}

final class AccountLinkController extends AsyncNotifier<AccountLinkState> {
  bool _operationInFlight = false;
  int _catalogGeneration = 0;
  int _formGeneration = 0;

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
    _formGeneration += 1;
    state = AsyncData(
      _current.copyWith(
        phase: AccountLinkPhase.editing,
        selectedBroker: broker,
        selectedServer: null,
        servers: const [],
        errorMessage: null,
        linkedAccount: null,
      ),
    );
  }

  void selectServer(MobileTradingServer server) {
    final selectedBrokerId = _current.selectedBroker?.id;
    if (server.brokerId != selectedBrokerId) {
      throw ArgumentError.value(
        server.brokerId,
        'server.brokerId',
        'Server does not belong to the selected broker',
      );
    }
    _formGeneration += 1;
    state = AsyncData(
      _current.copyWith(
        phase: AccountLinkPhase.editing,
        selectedServer: server,
        errorMessage: null,
        linkedAccount: null,
      ),
    );
  }

  void updateLogin(String value) {
    _formGeneration += 1;
    _edit(_current.copyWith(login: value, linkedAccount: null));
  }

  void updatePassword(String value) =>
      _edit(_current.copyWith(password: value));

  void _edit(AccountLinkState next) {
    state = AsyncData(
      next.copyWith(phase: AccountLinkPhase.editing, errorMessage: null),
    );
  }

  Future<ActivateLinkedAccountResult?> submit({
    ExV2CommandMetadata? loginMetadata,
  }) async {
    final before = _current;
    final formGeneration = _formGeneration;
    if (_operationInFlight) return null;
    final activationRetry = _activationRetryCandidate(before);
    if (activationRetry == null && !before.canSubmit) {
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
        phase: activationRetry == null
            ? AccountLinkPhase.submitting
            : AccountLinkPhase.activating,
        errorMessage: null,
        linkedAccount: activationRetry,
      ),
    );
    try {
      late final LinkedTradingAccount linkedAccount;
      if (activationRetry != null) {
        linkedAccount = activationRetry;
      } else {
        final linked = await _requestLink(before, loginMetadata);
        if (!ref.mounted) return null;
        if (formGeneration != _formGeneration) {
          _clearSubmittedPassword(before.password);
          return null;
        }
        _verifyLinkedIdentity(linked.account, before);
        await _persistLinkedAccount(linked, before);
        if (!ref.mounted) return null;
        if (formGeneration != _formGeneration) {
          _clearSubmittedPassword(before.password);
          return null;
        }
        linkedAccount = linked.account;
      }
      if (!ref.mounted) return null;
      state = AsyncData(
        _current.copyWith(
          phase: AccountLinkPhase.activating,
          linkedAccount: linkedAccount,
        ),
      );
      final activation = await ref
          .read(accountActivationCoordinatorProvider.notifier)
          .activate(linkedAccount.id, metadata: ExV2CommandMetadata.create());
      if (!ref.mounted) return null;
      if (formGeneration != _formGeneration) {
        _clearSubmittedPassword(before.password);
        return null;
      }
      if (!activation.accepted) {
        state = AsyncData(
          _current.copyWith(
            phase: AccountLinkPhase.failed,
            password: '',
            linkedAccount: linkedAccount,
            errorMessage: 'A newer account session is already active',
          ),
        );
        return null;
      }

      state = AsyncData(
        _current.copyWith(
          phase: AccountLinkPhase.succeeded,
          linkedAccount: activation.result.account,
          password: '',
          errorMessage: null,
        ),
      );
      return activation.result;
    } catch (error) {
      if (!ref.mounted) return null;
      _clearSubmittedPassword(before.password);
      if (formGeneration != _formGeneration) return null;
      state = AsyncData(
        _current.copyWith(
          phase: AccountLinkPhase.failed,
          errorMessage: _message(error),
        ),
      );
      return null;
    } finally {
      _operationInFlight = false;
    }
  }

  LinkedTradingAccount? _activationRetryCandidate(AccountLinkState current) {
    final account = current.linkedAccount;
    if (current.phase != AccountLinkPhase.failed || account == null) {
      return null;
    }
    if (account.brokerId != current.selectedBroker?.id ||
        account.serverId != current.selectedServer?.id ||
        account.login != current.login.trim()) {
      return null;
    }
    return account;
  }

  Future<LinkAccountResult> _requestLink(
    AccountLinkState before,
    ExV2CommandMetadata? metadata,
  ) => ref
      .read(accountLinkRepositoryProvider)
      .link(
        LinkAccountRequest(
          brokerId: before.selectedBroker!.id,
          serverId: before.selectedServer!.id,
          login: before.login.trim(),
          password: before.password,
          savePassword: false,
        ),
        metadata: metadata ?? ExV2CommandMetadata.create(),
      );

  Future<void> _persistLinkedAccount(
    LinkAccountResult linked,
    AccountLinkState before,
  ) async {
    final selectedPresentation = presentationForSelectedServer(
      before.selectedBroker!,
      before.selectedServer!,
    );
    await ref
        .read(linkedAccountPresentationStoreProvider)
        .write(linked.account.id, selectedPresentation);
    await ref.read(removedAccountStoreProvider).remove(linked.account.id);
    ref.invalidate(linkedAccountPresentationProvider(linked.account.id));
  }

  void _clearSubmittedPassword(String submittedPassword) {
    final current = _current;
    if (current.password != submittedPassword) return;
    state = AsyncData(current.copyWith(password: ''));
  }

  void _verifyLinkedIdentity(
    LinkedTradingAccount account,
    AccountLinkState request,
  ) {
    if (account.brokerId != request.selectedBroker!.id ||
        account.serverId != request.selectedServer!.id ||
        account.login != request.login.trim()) {
      throw const AccountLinkIdentityMismatch();
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

String _message(Object error) => switch (error) {
  ExV2RequestFailure failure => failure.safeDisplayMessage,
  ExV2ClientFailure failure => failure.message,
  FormatException exception => exception.message,
  _ => 'Unable to link this account',
};
