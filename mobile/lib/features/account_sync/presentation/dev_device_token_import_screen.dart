import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_radius.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_sync/application/dev_device_token_import.dart';

class DevDeviceTokenImportScreen extends ConsumerStatefulWidget {
  const DevDeviceTokenImportScreen({required this.onActivated, super.key});

  final VoidCallback onActivated;

  @override
  ConsumerState<DevDeviceTokenImportScreen> createState() =>
      _DevDeviceTokenImportScreenState();
}

class _DevDeviceTokenImportScreenState
    extends ConsumerState<DevDeviceTokenImportScreen> {
  final _tokenController = TextEditingController();
  bool _obscureToken = true;
  bool _submitting = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      await ref
          .read(deviceActivationServiceProvider)
          .activate(
            _tokenController.text,
            validate: ref.read(deviceTokenBootstrapValidatorProvider),
          );
      if (!mounted) return;
      _tokenController.clear();
      widget.onActivated();
    } catch (_) {
      if (!mounted) return;
      _tokenController.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('dev-device-token-import-screen'),
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Image(
                    key: Key('dev-device-token-branding'),
                    image: AssetImage('assets/images/metatrader5_splash.png'),
                    width: 150,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Kích hoạt thiết bị',
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Nhập device token để tải tài khoản trên thiết bị này.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xxl),
                TextField(
                  key: const Key('dev-device-token-field'),
                  controller: _tokenController,
                  enabled: !_submitting,
                  obscureText: _obscureToken,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submitting ? null : (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Device token',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: const OutlineInputBorder(
                      borderRadius: AppRadius.input,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.input,
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    suffixIcon: IconButton(
                      key: const Key('dev-device-token-visibility'),
                      tooltip: _obscureToken ? 'Hiện token' : 'Ẩn token',
                      onPressed: _submitting
                          ? null
                          : () =>
                                setState(() => _obscureToken = !_obscureToken),
                      icon: Icon(
                        _obscureToken
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  key: const Key('dev-device-token-submit'),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          key: Key('dev-device-token-loading'),
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kích hoạt'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
