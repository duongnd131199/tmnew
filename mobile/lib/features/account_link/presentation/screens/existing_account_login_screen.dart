import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_radius.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/presentation/theme/account_link_reference_theme.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/account_link_visuals.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/reference_server_catalog.dart';
import 'package:trading_mobile/features/account_login/application/account_password_login_controller.dart';
import 'package:trading_mobile/features/profile/presentation/widgets/account_visuals.dart';

class ExistingAccountLoginScreen extends ConsumerStatefulWidget {
  const ExistingAccountLoginScreen({
    required this.brokerId,
    this.initialLogin,
    this.initialServerId,
    this.initialAuthentication = false,
    this.onAuthenticated,
    super.key,
  }) : assert(!initialAuthentication || onAuthenticated != null);

  final String brokerId;
  final String? initialLogin;
  final String? initialServerId;
  final bool initialAuthentication;
  final VoidCallback? onAuthenticated;

  @override
  ConsumerState<ExistingAccountLoginScreen> createState() =>
      _ExistingAccountLoginScreenState();
}

class _ExistingAccountLoginScreenState
    extends ConsumerState<ExistingAccountLoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  _AccountLoginMode _loginMode = _AccountLoginMode.tradingAccount;
  bool _savePassword = true;
  bool _serverLoadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepare());
    });
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(accountLinkControllerProvider);
    final state = asyncState.value ?? const AccountLinkState();
    final authenticationState = widget.initialAuthentication
        ? ref.watch(accountPasswordLoginControllerProvider)
        : const AccountPasswordLoginState();
    final routeAuthorized =
        widget.initialAuthentication ||
        state.selectedBroker?.id == widget.brokerId;
    final formState = routeAuthorized ? state : const AccountLinkState();
    final referencePresentation = usesReferenceServerPresentation(
      widget.brokerId,
    );
    final visibleBroker =
        (widget.initialAuthentication ? null : formState.selectedBroker) ??
        referenceBrokerFallback(widget.brokerId);
    final visibleServerName =
        (widget.initialAuthentication
            ? null
            : formState.selectedServer?.name) ??
        (referencePresentation
            ? referenceDefaultServerDisplayName
            : 'Chọn máy chủ');
    if (!widget.initialAuthentication) {
      _synchronize(_loginController, formState.login);
      _synchronize(_passwordController, formState.password);
    }
    final canSubmit = widget.initialAuthentication
        ? _AccountLoginMode.tradingAccount == _loginMode &&
              RegExp(r'^\d+$').hasMatch(_loginController.text.trim()) &&
              _passwordController.text.isNotEmpty
        : formState.canSubmit;
    final busy = widget.initialAuthentication
        ? authenticationState.phase == AccountPasswordLoginPhase.submitting
        : state.phase == AccountLinkPhase.submitting ||
              state.phase == AccountLinkPhase.activating;

    return Scaffold(
      key: const Key('existing-account-login-screen'),
      backgroundColor: AppColors.accountLinkBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _BrokerHeader(
              broker: visibleBroker,
              referencePresentation: referencePresentation,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionLabel(
                      text: 'Đăng ký tài khoản mới',
                      sectionKey: Key('new-account-section-title'),
                    ),
                    _RegistrationRow(
                      key: const Key('real-account-row'),
                      title: 'Tài khoản thật',
                      description:
                          'Tạo tài khoản thật bằng cách điền vào mẫu đơn sau và gửi các giấy tờ yêu cầu',
                      onTap: () {},
                    ),
                    _RegistrationRow(
                      key: const Key('demo-account-row'),
                      title: 'Tài khoản dùng thử',
                      description:
                          'Đăng ký tài khoản để học giao dịch và kiểm tra chiến lược',
                      onTap: () {},
                    ),
                    const _SectionLabel(
                      text: 'Sử dụng tài khoản hiện có',
                      sectionKey: Key('existing-account-section-title'),
                    ),
                    _AccountTypeRow(
                      mode: _loginMode,
                      onChanged: (mode) => setState(() => _loginMode = mode),
                    ),
                    _ValueRow(
                      key: const Key('existing-account-server-row'),
                      label: 'Máy chủ',
                      value: visibleServerName,
                      referencePresentation: referencePresentation,
                      onTap: !routeAuthorized || widget.initialAuthentication
                          ? null
                          : () => context.push(
                              '/accounts/add/${Uri.encodeComponent(widget.brokerId)}/servers',
                            ),
                    ),
                    if (_serverLoadFailed)
                      _ServerFailureRow(
                        onRetry: () => unawaited(_loadServers()),
                      ),
                    _InputRow(
                      key: const Key('existing-account-login-row'),
                      label: _loginMode == _AccountLoginMode.tradingAccount
                          ? 'Đăng nhập'
                          : 'Mã máy khách',
                      field: TextField(
                        key: const Key('existing-account-login-field'),
                        controller: _loginController,
                        keyboardType:
                            _loginMode == _AccountLoginMode.tradingAccount
                            ? TextInputType.number
                            : TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        textAlign: TextAlign.end,
                        style: AccountLinkReferenceTypography.inputValue,
                        decoration: InputDecoration(
                          hintText:
                              _loginMode == _AccountLoginMode.tradingAccount
                              ? 'Nhập login'
                              : 'cl1234',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: AccountLinkReferenceTypography.rowHint,
                        ),
                        onChanged: widget.initialAuthentication
                            ? (_) => setState(() {})
                            : ref
                                  .read(accountLinkControllerProvider.notifier)
                                  .updateLogin,
                      ),
                    ),
                    _InputRow(
                      key: const Key('existing-account-password-row'),
                      label: 'Mật khẩu',
                      field: TextField(
                        key: const Key('existing-account-password-field'),
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        textAlign: TextAlign.end,
                        style: AccountLinkReferenceTypography.inputValue,
                        decoration: const InputDecoration(
                          hintText: 'Nhập mật khẩu',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: AccountLinkReferenceTypography.rowHint,
                        ),
                        onChanged: widget.initialAuthentication
                            ? (_) => setState(() {})
                            : ref
                                  .read(accountLinkControllerProvider.notifier)
                                  .updatePassword,
                        onSubmitted: (_) {
                          if (routeAuthorized && canSubmit) {
                            unawaited(_submit());
                          }
                        },
                      ),
                    ),
                    _SavePasswordRow(
                      value: _savePassword,
                      onChanged: (value) =>
                          setState(() => _savePassword = value),
                    ),
                    SizedBox(
                      height: 60,
                      child: Center(
                        child: TextButton(
                          key: const Key('existing-account-forgot-password'),
                          onPressed: () {},
                          child: Text(
                            'Quên mật khẩu',
                            style: AccountLinkReferenceTypography.rowValue
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _LoginAction(
              enabled: routeAuthorized && canSubmit,
              busy: busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prepare() async {
    if (widget.initialAuthentication) {
      final initialLogin = widget.initialLogin?.trim();
      if (initialLogin != null && initialLogin.isNotEmpty) {
        _loginController.text = initialLogin;
        if (mounted) setState(() {});
      }
      return;
    }
    final controller = ref.read(accountLinkControllerProvider.notifier);
    var state = await ref.read(accountLinkControllerProvider.future);
    if (!mounted) return;

    if (state.selectedBroker?.id != widget.brokerId) {
      if (state.brokers.every((broker) => broker.id != widget.brokerId)) {
        await controller.loadCatalog();
        if (!mounted) return;
        state = ref.read(accountLinkControllerProvider).value ?? state;
      }
      MobileBroker? selectedBroker;
      for (final broker in state.brokers) {
        if (broker.id == widget.brokerId) {
          selectedBroker = broker;
          break;
        }
      }
      if (selectedBroker == null) {
        context.go('/accounts/add');
        return;
      }
      controller.selectBroker(selectedBroker);
    }

    state = ref.read(accountLinkControllerProvider).value ?? state;
    if (state.selectedServer == null) {
      await _loadServers();
    }
    if (!mounted) return;
    state = ref.read(accountLinkControllerProvider).value ?? state;
    final initialServerId = widget.initialServerId?.trim();
    if (initialServerId != null && initialServerId.isNotEmpty) {
      final options = referenceServerOptions(
        brokerId: widget.brokerId,
        servers: state.servers,
      );
      for (final option in options) {
        if (option.server.id == initialServerId) {
          controller.selectServer(option.server);
          break;
        }
      }
    }
    final initialLogin = widget.initialLogin?.trim();
    if (initialLogin != null && initialLogin.isNotEmpty) {
      controller.updateLogin(initialLogin);
    }
  }

  Future<void> _loadServers() async {
    if (_serverLoadFailed) setState(() => _serverLoadFailed = false);
    final controller = ref.read(accountLinkControllerProvider.notifier);
    await controller.loadServers(widget.brokerId);
    if (!mounted) return;
    final state = ref.read(accountLinkControllerProvider).value;
    if (state == null || state.phase == AccountLinkPhase.failed) {
      setState(() => _serverLoadFailed = true);
      return;
    }
    if (state.selectedServer == null && state.servers.isNotEmpty) {
      final options = referenceServerOptions(
        brokerId: widget.brokerId,
        servers: state.servers,
      );
      controller.selectServer(options.first.server);
    }
  }

  Future<void> _submit() async {
    if (widget.initialAuthentication) {
      FocusScope.of(context).unfocus();
      final accepted = await ref
          .read(accountPasswordLoginControllerProvider.notifier)
          .submit(
            login: _loginController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      final current = ref.read(accountPasswordLoginControllerProvider);
      if (accepted) {
        _passwordController.clear();
        widget.onAuthenticated?.call();
        return;
      }
      if (current.errorCode == 'invalid_credentials') {
        _passwordController.clear();
      }
      setState(() {});
      return;
    }
    final state = ref.read(accountLinkControllerProvider).value;
    if (state?.selectedBroker?.id != widget.brokerId) return;
    FocusScope.of(context).unfocus();
    final result = await ref
        .read(accountLinkControllerProvider.notifier)
        .submit();
    if (!mounted) return;
    if (result != null) {
      context.go('/trade');
      return;
    }
  }

  static void _synchronize(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

enum _AccountLoginMode { tradingAccount, clientId }

class _BrokerHeader extends StatelessWidget {
  const _BrokerHeader({
    required this.broker,
    required this.referencePresentation,
  });

  final MobileBroker? broker;
  final bool referencePresentation;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('existing-account-header'),
    width: double.infinity,
    height: AccountLinkReferenceMetrics.accountHeaderHeight,
    child: Stack(
      children: [
        Positioned(
          left: AccountLinkReferenceMetrics.horizontalInset,
          right: AccountLinkReferenceMetrics.horizontalInset,
          top: AccountLinkReferenceMetrics.accountHeaderControlTop,
          height: 43,
          child: Row(
            children: [
              AccountLinkToolbarButton(
                action: AccountLinkToolbarAction.back,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(
                width: AccountLinkReferenceMetrics.accountHeaderBrokerGap,
              ),
              if (broker case final value?)
                AccountLinkBrokerMark(
                  broker: value,
                  displayAsExness: referencePresentation,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  referencePresentation
                      ? referenceServerBrokerDisplayName
                      : broker?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: referencePresentation
                      ? AccountLinkReferenceTypography.toolbarTitle
                      : AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.sectionKey});

  final String text;
  final Key sectionKey;

  @override
  Widget build(BuildContext context) => Container(
    key: sectionKey,
    height: AccountLinkReferenceMetrics.sectionHeight,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    color: AppColors.accountLinkBackground,
    child: Text(text, style: AccountLinkReferenceTypography.sectionTitle),
  );
}

class _RegistrationRow extends StatelessWidget {
  const _RegistrationRow({
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: AccountLinkReferenceMetrics.registrationRowHeight,
        margin: const EdgeInsets.only(left: AppSpacing.md),
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          right: AppSpacing.md,
          bottom: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: .6),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AccountLinkReferenceTypography.registrationTitle,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AccountLinkReferenceTypography.registrationDescription,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const AccountChevronRight(),
          ],
        ),
      ),
    ),
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.referencePresentation,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool referencePresentation;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: InkWell(
      onTap: onTap,
      child: _RowFrame(
        child: Row(
          children: [
            Text(label, style: _rowLabelStyle),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: referencePresentation
                    ? AccountLinkReferenceTypography.rowValue
                    : AppTypography.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            const AccountChevronRight(),
          ],
        ),
      ),
    ),
  );
}

class _AccountTypeRow extends StatelessWidget {
  const _AccountTypeRow({required this.mode, required this.onChanged});

  final _AccountLoginMode mode;
  final ValueChanged<_AccountLoginMode> onChanged;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surface,
    child: _RowFrame(
      key: const Key('existing-account-type-row'),
      child: Row(
        children: [
          const SizedBox(width: 90, child: Text('Loại', style: _rowLabelStyle)),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: AccountLinkReferenceMetrics.segmentHeight,
              decoration: const BoxDecoration(
                color: AppColors.accountLinkSegment,
                borderRadius: AppRadius.pill,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 58,
                    child: _AccountTypeSegment(
                      segmentKey: const Key(
                        'existing-account-trading-account-segment',
                      ),
                      label: 'Tài khoản giao dịch',
                      selected: mode == _AccountLoginMode.tradingAccount,
                      onTap: () => onChanged(_AccountLoginMode.tradingAccount),
                    ),
                  ),
                  Expanded(
                    flex: 42,
                    child: _AccountTypeSegment(
                      segmentKey: const Key(
                        'existing-account-client-id-segment',
                      ),
                      label: 'Mã máy khách',
                      selected: mode == _AccountLoginMode.clientId,
                      onTap: () => onChanged(_AccountLoginMode.clientId),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AccountTypeSegment extends StatelessWidget {
  const _AccountTypeSegment({
    required this.segmentKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key segmentKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: segmentKey,
    color: selected ? AppColors.surface : AppColors.transparent,
    shape: StadiumBorder(
      side: selected
          ? const BorderSide(color: AppColors.divider, width: .6)
          : BorderSide.none,
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AccountLinkReferenceTypography.segmentLabel.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _InputRow extends StatelessWidget {
  const _InputRow({required this.label, required this.field, super.key});

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surface,
    child: _RowFrame(
      child: Row(
        children: [
          Text(label, style: _rowLabelStyle),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: field),
        ],
      ),
    ),
  );
}

class _SavePasswordRow extends StatelessWidget {
  const _SavePasswordRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surface,
    child: _RowFrame(
      key: const Key('existing-account-save-password-row'),
      child: Row(
        children: [
          Text('Lưu mật khẩu', style: _rowLabelStyle),
          const Spacer(),
          Transform.scale(
            scaleX: 1.1,
            scaleY: 1.03,
            child: CupertinoSwitch(
              key: const Key('existing-account-save-password-switch'),
              value: value,
              activeTrackColor: AppColors.savePasswordEnabled,
              inactiveTrackColor: AppColors.disabledSurface,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ServerFailureRow extends StatelessWidget {
  const _ServerFailureRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('existing-account-server-error'),
    color: AppColors.surface,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        key: const Key('existing-account-server-retry'),
        onPressed: onRetry,
        child: const Text('Thử lại'),
      ),
    ),
  );
}

class _RowFrame extends StatelessWidget {
  const _RowFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: AccountLinkReferenceMetrics.formRowHeight,
    margin: const EdgeInsets.only(
      left: AccountLinkReferenceMetrics.horizontalInset,
    ),
    padding: const EdgeInsets.only(
      right: AccountLinkReferenceMetrics.horizontalInset,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.divider, width: .6)),
    ),
    child: child,
  );
}

class _LoginAction extends StatelessWidget {
  const _LoginAction({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AccountLinkReferenceMetrics.loginActionHeight,
    child: Center(
      child: OutlinedButton(
        key: const Key('existing-account-login-button'),
        onPressed: enabled && !busy ? () => unawaited(onPressed()) : null,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(106, 46)),
          maximumSize: const WidgetStatePropertyAll(Size(106, 46)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: const WidgetStatePropertyAll(BorderSide.none),
          elevation: const WidgetStatePropertyAll(4),
          shadowColor: const WidgetStatePropertyAll(Color(0x18000000)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.surface.withValues(alpha: .55)
                : AppColors.surface,
          ),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                'Đăng nhập',
                style: AccountLinkReferenceTypography.rowLabel.copyWith(
                  color: enabled
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    ),
  );
}

const _rowLabelStyle = AccountLinkReferenceTypography.rowLabel;
