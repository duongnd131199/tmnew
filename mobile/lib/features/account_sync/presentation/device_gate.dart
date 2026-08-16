import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

class DeviceGate extends ConsumerStatefulWidget {
  const DeviceGate({required this.child, this.onAddAccount, super.key});

  final Widget child;
  final VoidCallback? onAddAccount;

  @override
  ConsumerState<DeviceGate> createState() => _DeviceGateState();
}

class _DeviceGateState extends ConsumerState<DeviceGate> {
  bool _loading = true;
  bool _activated = false;
  bool _accountlessUnlocked = false;

  @override
  void initState() {
    super.initState();
    _readToken();
  }

  Future<void> _readToken() async {
    final enabled = ref.read(exV2EnabledProvider);
    final token = await ref.read(deviceTokenStoreProvider).read();
    if (!mounted) return;
    setState(() {
      _activated = !enabled || (token != null && token.trim().isNotEmpty);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _AccountBootstrapLoading();
    }
    if (_activated) {
      if (!ref.watch(exV2EnabledProvider)) return widget.child;
      if (_accountlessUnlocked) return widget.child;
      return ref
          .watch(exV2AccountProvider)
          .when(
            loading: () => const _AccountBootstrapLoading(),
            error: (error, stackTrace) => _isAccountNotConfigured(error)
                ? _AccountBootstrapAccountless(onAddAccount: _openAddAccount)
                : _AccountBootstrapUnavailable(
                    key: const Key('account-bootstrap-error'),
                    message: 'Không thể tải tài khoản.',
                    onRetry: () => ref.invalidate(exV2AccountProvider),
                  ),
            data: (account) => account == null
                ? _AccountBootstrapUnavailable(
                    key: const Key('account-bootstrap-empty'),
                    message: 'Chưa có tài khoản được cấp quyền.',
                    onRetry: () => ref.invalidate(exV2AccountProvider),
                  )
                : widget.child,
          );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _DeviceActivationScreen(
        onActivated: () {
          if (!mounted) return;
          ref.invalidate(exV2AccountProvider);
          setState(() => _activated = true);
        },
      ),
    );
  }

  void _openAddAccount() {
    if (!mounted) return;
    setState(() => _accountlessUnlocked = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final callback = widget.onAddAccount;
      if (callback != null) {
        callback();
      } else {
        appRouter.go('/accounts/add');
      }
    });
  }
}

bool _isAccountNotConfigured(Object error) =>
    error is ExV2RequestFailure &&
    error.statusCode == 409 &&
    error.code == 'ACTIVE_ACCOUNT_NOT_CONFIGURED';

class _AccountBootstrapLoading extends StatelessWidget {
  const _AccountBootstrapLoading();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    key: Key('account-bootstrap-loading'),
    color: Colors.black,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _AccountBootstrapUnavailable extends StatelessWidget {
  const _AccountBootstrapUnavailable({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AccountBootstrapAccountless extends StatelessWidget {
  const _AccountBootstrapAccountless({required this.onAddAccount});

  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) => MaterialApp(
    key: const Key('account-bootstrap-accountless'),
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thiết bị đã được kích hoạt. Hãy thêm tài khoản giao dịch đầu tiên.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onAddAccount,
                child: const Text('Thêm tài khoản'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DeviceActivationScreen extends ConsumerStatefulWidget {
  const _DeviceActivationScreen({required this.onActivated});

  final VoidCallback onActivated;

  @override
  ConsumerState<_DeviceActivationScreen> createState() =>
      _DeviceActivationScreenState();
}

class _DeviceActivationScreenState
    extends ConsumerState<_DeviceActivationScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final service = DeviceActivationService(
        ref.read(deviceTokenStoreProvider),
      );
      await service.activate(
        _controller.text,
        validate: (_) async {
          await ref.read(exV2RepositoryProvider).status();
        },
      );
      widget.onActivated();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể xác thực thiết bị.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kích hoạt thiết bị')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const Text(
          'Nhập token một lần. Tài khoản sử dụng trên app sẽ được chọn từ trang quản trị web.',
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _controller,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Device token',
            errorText: _error,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _submitting ? null : _activate,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kích hoạt'),
        ),
      ],
    ),
  );
}
