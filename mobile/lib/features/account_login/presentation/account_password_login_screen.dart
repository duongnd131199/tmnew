import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_radius.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_login/application/account_password_login_controller.dart';

class AccountPasswordLoginScreen extends ConsumerStatefulWidget {
  const AccountPasswordLoginScreen({required this.onAuthenticated, super.key});

  final VoidCallback onAuthenticated;

  @override
  ConsumerState<AccountPasswordLoginScreen> createState() =>
      _AccountPasswordLoginScreenState();
}

class _AccountPasswordLoginScreenState
    extends ConsumerState<AccountPasswordLoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      widget.onAuthenticated();
    } else if (current.errorCode == 'invalid_credentials') {
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountPasswordLoginControllerProvider);
    final submitting = state.phase == AccountPasswordLoginPhase.submitting;
    return Scaffold(
      key: const Key('account-password-login-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.candlestick_chart_rounded,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Đăng nhập EX2',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Nhập tài khoản và mật khẩu giao dịch của bạn.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextField(
                      key: const Key('account-login-field'),
                      controller: _loginController,
                      enabled: !submitting,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.username],
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: _decoration('Tài khoản'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const Key('account-password-field'),
                      controller: _passwordController,
                      enabled: !submitting,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.password],
                      onSubmitted: submitting ? null : (_) => _submit(),
                      decoration: _decoration('Mật khẩu'),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      key: const Key('account-login-submit'),
                      onPressed: submitting ? null : _submit,
                      child: submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Đăng nhập'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _decoration(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: AppColors.surface,
  border: const OutlineInputBorder(borderRadius: AppRadius.input),
  enabledBorder: const OutlineInputBorder(
    borderRadius: AppRadius.input,
    borderSide: BorderSide(color: AppColors.divider),
  ),
);
