import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_icons.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/account_link_visuals.dart';

class TradingServerScreen extends ConsumerStatefulWidget {
  const TradingServerScreen({
    required this.brokerId,
    this.onSelected,
    super.key,
  });

  final String brokerId;
  final ValueChanged<MobileTradingServer>? onSelected;

  @override
  ConsumerState<TradingServerScreen> createState() =>
      _TradingServerScreenState();
}

class _TradingServerScreenState extends ConsumerState<TradingServerScreen> {
  String? _routeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(accountLinkControllerProvider);
    final state = asyncState.value;
    final loading =
        asyncState.isLoading || state?.phase == AccountLinkPhase.loadingCatalog;
    final failed = state?.phase == AccountLinkPhase.failed;
    final servers = state?.servers ?? const <MobileTradingServer>[];
    final message = _routeError ?? state?.errorMessage;

    return Scaffold(
      key: const Key('trading-server-screen'),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 66,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'Máy chủ',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    child: AccountLinkToolbarButton(
                      action: AccountLinkToolbarAction.back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch ((
                failed || message != null,
                loading,
                servers.isEmpty,
              )) {
                (true, _, _) => _ServerFailure(
                  message: message ?? 'Unable to link this account',
                  onRetry: () => unawaited(_load()),
                ),
                (false, true, true) => const Center(
                  child: CircularProgressIndicator(
                    key: Key('server-catalog-loading'),
                  ),
                ),
                (_, _, true) => Center(
                  child: Text(
                    'Không có máy chủ',
                    key: const Key('server-catalog-empty'),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                _ => DecoratedBox(
                  decoration: const BoxDecoration(color: AppColors.surface),
                  child: Scrollbar(
                    radius: const Radius.circular(2),
                    thickness: 2,
                    child: ListView.builder(
                      key: const Key('server-list'),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemExtent: 56,
                      itemCount: servers.length,
                      itemBuilder: (context, index) {
                        final server = servers[index];
                        return _ServerRow(
                          server: server,
                          selected: state?.selectedServer?.id == server.id,
                          onTap: () => _select(server),
                        );
                      },
                    ),
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final controller = ref.read(accountLinkControllerProvider.notifier);
    var state = await ref.read(accountLinkControllerProvider.future);
    if (!mounted) return;
    if (state.selectedBroker?.id != widget.brokerId) {
      var broker = _brokerFor(state.brokers);
      if (broker == null) {
        await controller.loadCatalog();
        if (!mounted) return;
        state = ref.read(accountLinkControllerProvider).value ?? state;
        broker = _brokerFor(state.brokers);
      }
      if (broker == null) {
        setState(
          () => _routeError =
              state.errorMessage ?? 'Không tìm thấy công ty đã chọn',
        );
        return;
      }
      controller.selectBroker(broker);
    }
    await _loadServers();
  }

  MobileBroker? _brokerFor(List<MobileBroker> brokers) {
    for (final broker in brokers) {
      if (broker.id == widget.brokerId) return broker;
    }
    return null;
  }

  Future<void> _loadServers() async {
    if (mounted && _routeError != null) setState(() => _routeError = null);
    await ref
        .read(accountLinkControllerProvider.notifier)
        .loadServers(widget.brokerId);
  }

  void _select(MobileTradingServer server) {
    ref.read(accountLinkControllerProvider.notifier).selectServer(server);
    widget.onSelected?.call(server);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(server);
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.server,
    required this.selected,
    required this.onTap,
  });

  final MobileTradingServer server;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('server-row-${server.id}'),
    color: AppColors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    server.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    color: AppColors.primary,
                    size: AppIconSizes.medium,
                  ),
              ],
            ),
          ),
          Positioned(
            key: ValueKey('server-divider-${server.id}'),
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: 0,
            child: const Divider(height: 1, thickness: .6),
          ),
        ],
      ),
    ),
  );
}

class _ServerFailure extends StatelessWidget {
  const _ServerFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('server-catalog-error'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const Key('server-catalog-retry'),
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}
