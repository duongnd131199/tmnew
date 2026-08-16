import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/account_link_visuals.dart';

class ExistingAccountLoginScreen extends ConsumerStatefulWidget {
  const ExistingAccountLoginScreen({required this.brokerId, super.key});

  final String brokerId;

  @override
  ConsumerState<ExistingAccountLoginScreen> createState() =>
      _ExistingAccountLoginScreenState();
}

class _ExistingAccountLoginScreenState
    extends ConsumerState<ExistingAccountLoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _serverError;

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
    final routeAuthorized = state.selectedBroker?.id == widget.brokerId;
    final formState = routeAuthorized ? state : const AccountLinkState();
    _synchronize(_loginController, formState.login);
    _synchronize(_passwordController, formState.password);

    return Scaffold(
      key: const Key('existing-account-login-screen'),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _BrokerHeader(broker: formState.selectedBroker),
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
                      onTap: () => _showFeedback(
                        'Đăng ký tài khoản thật chưa được hỗ trợ',
                      ),
                    ),
                    _RegistrationRow(
                      key: const Key('demo-account-row'),
                      title: 'Tài khoản dùng thử',
                      description:
                          'Đăng ký tài khoản để học giao dịch và kiểm tra chiến lược',
                      onTap: () => _showFeedback(
                        'Đăng ký tài khoản dùng thử chưa được hỗ trợ',
                      ),
                    ),
                    const _SectionLabel(
                      text: 'Sử dụng tài khoản hiện có',
                      sectionKey: Key('existing-account-section-title'),
                    ),
                    _ValueRow(
                      key: const Key('existing-account-server-row'),
                      label: 'Máy chủ',
                      value: formState.selectedServer?.name ?? 'Chọn máy chủ',
                      onTap: !routeAuthorized
                          ? null
                          : () => context.push(
                              '/accounts/add/${Uri.encodeComponent(widget.brokerId)}/servers',
                            ),
                    ),
                    if (_serverError case final message?)
                      _ServerFailureRow(
                        message: message,
                        onRetry: () => unawaited(_loadServers()),
                      ),
                    _InputRow(
                      label: 'Đăng nhập',
                      field: TextField(
                        key: const Key('existing-account-login-field'),
                        controller: _loginController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        textAlign: TextAlign.end,
                        style: AppTypography.numberMedium.copyWith(
                          color: AppColors.primary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Nhập login',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: ref
                            .read(accountLinkControllerProvider.notifier)
                            .updateLogin,
                      ),
                    ),
                    _InputRow(
                      label: 'Mật khẩu',
                      field: TextField(
                        key: const Key('existing-account-password-field'),
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        textAlign: TextAlign.end,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.primary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Nhập mật khẩu',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: ref
                            .read(accountLinkControllerProvider.notifier)
                            .updatePassword,
                        onSubmitted: (_) {
                          if (state.canSubmit) unawaited(_submit());
                        },
                      ),
                    ),
                    _SavePasswordRow(
                      value: formState.savePassword,
                      onChanged: ref
                          .read(accountLinkControllerProvider.notifier)
                          .updateSavePassword,
                    ),
                    SizedBox(
                      height: 60,
                      child: Center(
                        child: TextButton(
                          key: const Key('existing-account-forgot-password'),
                          onPressed: () => _showFeedback(
                            'Khôi phục mật khẩu chưa được hỗ trợ',
                          ),
                          child: Text(
                            'Quên mật khẩu',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _LoginAction(
              enabled: routeAuthorized && formState.canSubmit,
              busy:
                  state.phase == AccountLinkPhase.submitting ||
                  state.phase == AccountLinkPhase.activating,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prepare() async {
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
  }

  Future<void> _loadServers() async {
    if (_serverError != null) setState(() => _serverError = null);
    final controller = ref.read(accountLinkControllerProvider.notifier);
    await controller.loadServers(widget.brokerId);
    if (!mounted) return;
    final state = ref.read(accountLinkControllerProvider).value;
    if (state == null || state.phase == AccountLinkPhase.failed) {
      setState(() {
        _serverError = state?.errorMessage ?? 'Unable to link this account';
      });
      return;
    }
    if (state.selectedServer == null && state.servers.isNotEmpty) {
      controller.selectServer(state.servers.first);
    }
  }

  Future<void> _submit() async {
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
    final message = ref.read(accountLinkControllerProvider).value?.errorMessage;
    if (message != null) _showFeedback(message);
  }

  void _showFeedback(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  static void _synchronize(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _BrokerHeader extends StatelessWidget {
  const _BrokerHeader({required this.broker});

  final MobileBroker? broker;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('existing-account-header'),
    height: 72,
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: AccountLinkToolbarButton(
            action: AccountLinkToolbarAction.back,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (broker case final value?) AccountLinkBrokerMark(broker: value),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            broker?.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
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
    height: 42,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    color: AppColors.background,
    child: Text(
      text,
      style: AppTypography.titleMedium.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    ),
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
        constraints: const BoxConstraints(minHeight: 92),
        margin: const EdgeInsets.only(left: AppSpacing.md),
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
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
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
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
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

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
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _InputRow extends StatelessWidget {
  const _InputRow({required this.label, required this.field});

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

class _ServerFailureRow extends StatelessWidget {
  const _ServerFailureRow({required this.message, required this.onRetry});

  final String message;
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
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodySmall.copyWith(color: AppColors.negative),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          key: const Key('existing-account-server-retry'),
          onPressed: onRetry,
          child: const Text('Thử lại'),
        ),
      ],
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
    child: SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text('Lưu mật khẩu', style: _rowLabelStyle)),
            Switch.adaptive(
              key: const Key('existing-account-save-switch'),
              value: value,
              activeTrackColor: AppColors.savePasswordEnabled,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    ),
  );
}

class _RowFrame extends StatelessWidget {
  const _RowFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    margin: const EdgeInsets.only(left: AppSpacing.md),
    padding: const EdgeInsets.only(right: AppSpacing.md),
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
    height: 76,
    child: Center(
      child: OutlinedButton(
        key: const Key('existing-account-login-button'),
        onPressed: enabled && !busy ? () => unawaited(onPressed()) : null,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(122, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.divider, width: .8),
          ),
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
                style: AppTypography.titleMedium.copyWith(
                  color: enabled
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    ),
  );
}

final _rowLabelStyle = AppTypography.titleMedium.copyWith(
  fontWeight: FontWeight.w600,
);
