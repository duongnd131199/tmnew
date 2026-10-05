import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_icons.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/presentation/theme/account_link_reference_theme.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/account_link_toolbar.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/reference_server_catalog.dart';

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
  final _scrollController = ScrollController();
  bool _routeFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(accountLinkControllerProvider);
    final state = asyncState.value;
    final loading =
        asyncState.isLoading || state?.phase == AccountLinkPhase.loadingCatalog;
    final failed = state?.phase == AccountLinkPhase.failed;
    final servers = state?.servers ?? const <MobileTradingServer>[];
    final options = referenceServerOptions(
      brokerId: widget.brokerId,
      servers: servers,
    );
    return Scaffold(
      key: const Key('trading-server-screen'),
      backgroundColor: AppColors.accountLinkServerHeader,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top:
                  AccountLinkReferenceMetrics.toolbarHeight +
                  AccountLinkReferenceMetrics.serverHeaderGap,
              left: 0,
              right: 0,
              bottom: 0,
              child: const ColoredBox(color: AppColors.surface),
            ),
            Positioned.fill(
              child: switch ((
                failed || _routeFailed,
                loading,
                servers.isEmpty,
              )) {
                (true, _, _) => Padding(
                  padding: const EdgeInsets.only(
                    top:
                        AccountLinkReferenceMetrics.toolbarHeight +
                        AccountLinkReferenceMetrics.serverHeaderGap,
                  ),
                  child: _ServerFailure(onRetry: () => unawaited(_load())),
                ),
                (false, true, true) => const Padding(
                  padding: EdgeInsets.only(
                    top:
                        AccountLinkReferenceMetrics.toolbarHeight +
                        AccountLinkReferenceMetrics.serverHeaderGap,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      key: Key('server-catalog-loading'),
                    ),
                  ),
                ),
                (_, _, true) => Padding(
                  padding: const EdgeInsets.only(
                    top:
                        AccountLinkReferenceMetrics.toolbarHeight +
                        AccountLinkReferenceMetrics.serverHeaderGap,
                  ),
                  child: Center(
                    child: Text(
                      'Không có máy chủ',
                      key: const Key('server-catalog-empty'),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                _ => Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  radius: const Radius.circular(2),
                  thickness: 2,
                  child: ListView.builder(
                    key: const Key('server-list'),
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.only(
                      top:
                          AccountLinkReferenceMetrics.toolbarHeight +
                          AccountLinkReferenceMetrics.serverHeaderGap,
                    ),
                    itemExtent: AccountLinkReferenceMetrics.serverRowHeight,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      return _ServerRow(
                        rowKey: option.rowKey,
                        server: option.server,
                        selected: option.isSelected(state?.selectedServer),
                        referencePresentation: usesReferenceServerPresentation(
                          widget.brokerId,
                        ),
                        onTap: () => _select(option.server),
                      );
                    },
                  ),
                ),
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: ColoredBox(
                color: AppColors.accountLinkServerHeader.withValues(alpha: .94),
                child: AccountLinkToolbar(
                  title: 'Máy chủ',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
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
        setState(() => _routeFailed = true);
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
    if (mounted && _routeFailed) setState(() => _routeFailed = false);
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
    required this.rowKey,
    required this.server,
    required this.selected,
    required this.referencePresentation,
    required this.onTap,
  });

  final String rowKey;
  final MobileTradingServer server;
  final bool selected;
  final bool referencePresentation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('server-row-$rowKey'),
    color: AppColors.surface,
    child: InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AccountLinkReferenceMetrics.horizontalInset,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      server.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: referencePresentation
                          ? AccountLinkReferenceTypography.serverName
                          : AppTypography.titleMedium.copyWith(
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
          ),
          Positioned(
            key: ValueKey('server-divider-$rowKey'),
            left: AccountLinkReferenceMetrics.horizontalInset,
            right: AccountLinkReferenceMetrics.horizontalInset,
            bottom: 0,
            child: const Divider(
              height: 1,
              thickness: .6,
              color: AppColors.divider,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ServerFailure extends StatelessWidget {
  const _ServerFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('server-catalog-error'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
