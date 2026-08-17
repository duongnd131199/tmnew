import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/account_login/presentation/account_password_login_screen.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

class DeviceGate extends ConsumerStatefulWidget {
  const DeviceGate({
    required this.child,
    this.onAddAccount,
    this.startupTimeout = const Duration(seconds: 20),
    super.key,
  });

  final Widget child;
  final VoidCallback? onAddAccount;
  final Duration startupTimeout;

  @override
  ConsumerState<DeviceGate> createState() => _DeviceGateState();
}

class _DeviceGateState extends ConsumerState<DeviceGate> {
  bool _loading = true;
  bool _activated = false;
  bool _accountlessUnlocked = false;
  int _tokenReadGeneration = 0;
  Object? _tokenReadError;
  Timer? _bootstrapTimer;
  bool _bootstrapTimedOut = false;

  @override
  void initState() {
    super.initState();
    _readToken();
  }

  Future<void> _readToken({bool retry = false}) async {
    final generation = ++_tokenReadGeneration;
    if (retry && mounted) {
      _bootstrapTimer?.cancel();
      setState(() {
        _loading = true;
        _tokenReadError = null;
        _bootstrapTimedOut = false;
      });
    }
    try {
      final enabled = ref.read(exV2EnabledProvider);
      final token = await ref
          .read(deviceTokenStoreProvider)
          .read()
          .timeout(widget.startupTimeout);
      if (!mounted || generation != _tokenReadGeneration) return;
      final activated = !enabled || (token != null && token.trim().isNotEmpty);
      setState(() {
        _activated = activated;
        _loading = false;
      });
      if (enabled && activated) _armBootstrapTimeout();
    } catch (error) {
      if (!mounted || generation != _tokenReadGeneration) return;
      setState(() {
        _tokenReadError = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tokenReadError != null) {
      return _AccountBootstrapUnavailable(
        key: const Key('device-token-read-error'),
        message: 'Không thể đọc phiên đăng nhập.',
        onRetry: () => _readToken(retry: true),
      );
    }
    if (_loading) {
      return const _AccountBootstrapLoading();
    }
    if (_activated) {
      if (!ref.watch(exV2EnabledProvider)) return widget.child;
      if (_accountlessUnlocked) return widget.child;
      final accountState = ref.watch(exV2AccountProvider);
      if (accountState.isLoading) {
        return _bootstrapTimedOut
            ? _AccountBootstrapUnavailable(
                key: const Key('account-bootstrap-timeout'),
                message: 'Máy chủ phản hồi quá lâu.',
                onRetry: _retryBootstrap,
              )
            : const _AccountBootstrapLoading();
      }
      if (!accountState.isLoading) _bootstrapTimer?.cancel();
      return accountState.when(
        loading: () => const _AccountBootstrapLoading(),
        error: (error, stackTrace) => _isAccountNotConfigured(error)
            ? _AccountBootstrapAccountless(onAddAccount: _openAddAccount)
            : _isDeviceAuthenticationFailure(error)
            ? _AccountBootstrapUnavailable(
                key: const Key('device-authentication-error'),
                message: 'Phiên đăng nhập đã hết hiệu lực.',
                buttonLabel: 'Đăng nhập lại',
                onRetry: () => unawaited(_resetDeviceAuthentication()),
              )
            : _AccountBootstrapUnavailable(
                key: const Key('account-bootstrap-error'),
                message: 'Không thể tải tài khoản.',
                onRetry: _retryBootstrap,
              ),
        data: (account) => account == null
            ? _AccountBootstrapUnavailable(
                key: const Key('account-bootstrap-empty'),
                message: 'Chưa có tài khoản được cấp quyền.',
                onRetry: _retryBootstrap,
              )
            : widget.child,
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AccountPasswordLoginScreen(
        onAuthenticated: () {
          if (!mounted) return;
          setState(() {
            _activated = true;
            _accountlessUnlocked = false;
          });
          if (ref.read(exV2AccountProvider).isLoading) {
            _armBootstrapTimeout();
          }
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

  void _armBootstrapTimeout() {
    _bootstrapTimer?.cancel();
    _bootstrapTimedOut = false;
    _bootstrapTimer = Timer(widget.startupTimeout, () {
      if (!mounted || !ref.read(exV2AccountProvider).isLoading) return;
      setState(() => _bootstrapTimedOut = true);
    });
  }

  void _retryBootstrap() {
    if (!mounted) return;
    _bootstrapTimer?.cancel();
    setState(() => _bootstrapTimedOut = false);
    ref.invalidate(exV2AccountProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _armBootstrapTimeout();
    });
  }

  Future<void> _resetDeviceAuthentication() async {
    final generation = ++_tokenReadGeneration;
    _bootstrapTimer?.cancel();
    setState(() {
      _loading = true;
      _tokenReadError = null;
      _bootstrapTimedOut = false;
    });
    try {
      await ref
          .read(deviceTokenStoreProvider)
          .delete()
          .timeout(widget.startupTimeout);
      if (!mounted || generation != _tokenReadGeneration) return;
      ref.invalidate(exV2AccountProvider);
      setState(() {
        _activated = false;
        _accountlessUnlocked = false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _tokenReadGeneration) return;
      setState(() {
        _tokenReadError = error;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tokenReadGeneration += 1;
    _bootstrapTimer?.cancel();
    super.dispose();
  }
}

bool _isAccountNotConfigured(Object error) =>
    error is ExV2RequestFailure &&
    error.statusCode == 409 &&
    error.code == 'ACTIVE_ACCOUNT_NOT_CONFIGURED';

bool _isDeviceAuthenticationFailure(Object error) =>
    error is ExV2RequestFailure &&
    (error.statusCode == 401 || error.statusCode == 403);

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
    this.buttonLabel = 'Thử lại',
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final String buttonLabel;

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
              OutlinedButton(onPressed: onRetry, child: Text(buttonLabel)),
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
