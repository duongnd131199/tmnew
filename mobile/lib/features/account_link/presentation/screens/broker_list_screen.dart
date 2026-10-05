import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_radius.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/account_link_toolbar.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/account_link_visuals.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/reference_server_catalog.dart';
import 'package:trading_mobile/features/account_link/presentation/theme/account_link_reference_theme.dart';

class BrokerListScreen extends ConsumerStatefulWidget {
  const BrokerListScreen({
    this.onBrokerSelected,
    this.onBrokerInfo,
    this.onQrPressed,
    super.key,
  });

  final ValueChanged<MobileBroker>? onBrokerSelected;
  final ValueChanged<MobileBroker>? onBrokerInfo;
  final VoidCallback? onQrPressed;

  @override
  ConsumerState<BrokerListScreen> createState() => _BrokerListScreenState();
}

class _BrokerListScreenState extends ConsumerState<BrokerListScreen> {
  static const _searchDebounce = Duration(milliseconds: 280);

  Timer? _debounce;
  String _query = '';
  String? _authoritativeQuery;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final generation = ++_requestGeneration;
        unawaited(_loadCatalog('', generation: generation));
      }
    });
  }

  @override
  void dispose() {
    _requestGeneration += 1;
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(accountLinkControllerProvider);
    final state = asyncState.value;
    final catalogBrokers = state?.brokers ?? const <MobileBroker>[];
    final showsOptimisticBroker =
        catalogBrokers.isEmpty &&
        _authoritativeQuery == null &&
        _query.trim().isEmpty;
    final initialBrokers = showsOptimisticBroker
        ? const <MobileBroker>[referenceServerBrokerFallback]
        : catalogBrokers;
    final brokers = _locallyFiltered(initialBrokers);
    final loading =
        asyncState.isLoading || state?.phase == AccountLinkPhase.loadingCatalog;
    final failed = state?.phase == AccountLinkPhase.failed;

    return Scaffold(
      key: const Key('broker-list-screen'),
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AccountLinkToolbar(
              title: 'Brokers',
              onBack: () => Navigator.of(context).maybePop(),
              trailing: AccountLinkToolbarButton(
                action: AccountLinkToolbarAction.qr,
                onTap: _handleQr,
              ),
            ),
            Expanded(
              child: switch ((failed, loading, brokers.isEmpty)) {
                (true, _, _) => _CatalogFailure(
                  key: const Key('broker-catalog-error'),
                  retryKey: const Key('broker-catalog-retry'),
                  onRetry: _retry,
                ),
                (false, true, true) => const Center(
                  child: CircularProgressIndicator(
                    key: Key('broker-catalog-loading'),
                  ),
                ),
                (_, _, true) => Center(
                  child: Text(
                    'Không tìm thấy công ty',
                    key: const Key('broker-catalog-empty'),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                _ => ListView.builder(
                  key: const Key('broker-list'),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.zero,
                  itemCount: brokers.length,
                  itemBuilder: (context, index) {
                    final broker = brokers[index];
                    return _BrokerRow(
                      broker: broker,
                      onTap: () => _handleBrokerTap(
                        broker,
                        optimistic:
                            showsOptimisticBroker &&
                            identical(broker, referenceServerBrokerFallback),
                      ),
                      onInfo: () => _showBrokerInfo(broker),
                    );
                  },
                ),
              },
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xs,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: SizedBox(
                height: AccountLinkReferenceMetrics.searchFieldHeight,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.pill,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: TextField(
                    key: const Key('broker-search-field'),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    onChanged: _search,
                    style: AccountLinkReferenceTypography.searchHint.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Vui lòng nhập tên công ty hoặc máy chủ',
                      hintMaxLines: 1,
                      hintStyle: AccountLinkReferenceTypography.searchHint,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      prefixIconConstraints: BoxConstraints.tightFor(
                        width: 40,
                        height: AccountLinkReferenceMetrics.searchFieldHeight,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: EdgeInsets.only(right: AppSpacing.md),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.pill,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.pill,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.pill,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MobileBroker> _locallyFiltered(List<MobileBroker> brokers) {
    final normalized = _query.trim().toLowerCase();
    final unique = deduplicateBrokerCatalog(brokers);
    final presented = referenceBrokerCatalog(unique);
    if (normalized.isEmpty) return presented;
    final localMatches = presented
        .where((broker) {
          final presentation = referenceBrokerPresentation(broker);
          final searchable = [
            broker.name,
            broker.companyName,
            broker.description,
            presentation.name,
            presentation.companyName,
          ].whereType<String>().join(' ').toLowerCase();
          return searchable.contains(normalized);
        })
        .toList(growable: false);
    if (localMatches.isNotEmpty || _authoritativeQuery != normalized) {
      return localMatches;
    }

    // Keep authoritative server-side matches such as MT5Real20 even when the
    // broker's display fields do not contain the searched server name. Do not
    // append the presentation-only fallback to that server-owned result.
    return unique;
  }

  void _search(String value) {
    final generation = ++_requestGeneration;
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      unawaited(_loadCatalog(value.trim(), generation: generation));
    });
  }

  void _retry() {
    final generation = ++_requestGeneration;
    unawaited(_loadCatalog(_query.trim(), generation: generation));
  }

  Future<void> _loadCatalog(String query, {required int generation}) async {
    await ref
        .read(accountLinkControllerProvider.notifier)
        .loadCatalog(query: query);
    if (!mounted ||
        generation != _requestGeneration ||
        _query.trim().toLowerCase() != query.toLowerCase()) {
      return;
    }
    setState(() => _authoritativeQuery = query.toLowerCase());
  }

  void _selectBroker(MobileBroker broker) {
    _requestGeneration += 1;
    _debounce?.cancel();
    _debounce = null;
    ref.read(accountLinkControllerProvider.notifier).selectBroker(broker);
    final callback = widget.onBrokerSelected;
    if (callback != null) {
      callback(broker);
      return;
    }
    context.push('/accounts/add/${Uri.encodeComponent(broker.id)}');
  }

  void _handleBrokerTap(MobileBroker broker, {required bool optimistic}) {
    if (referenceBrokerSemanticId(broker) == 'metaquotes') return;
    if (optimistic) {
      if (widget.onBrokerSelected != null) return;
      context.push('/accounts/add/${Uri.encodeComponent(broker.id)}');
      return;
    }
    _selectBroker(broker);
  }

  void _showBrokerInfo(MobileBroker broker) {
    final callback = widget.onBrokerInfo;
    if (callback != null) {
      callback(broker);
      return;
    }
  }

  void _handleQr() {
    final callback = widget.onQrPressed;
    if (callback != null) {
      callback();
      return;
    }
  }
}

class _BrokerRow extends StatelessWidget {
  const _BrokerRow({
    required this.broker,
    required this.onTap,
    required this.onInfo,
  });

  final MobileBroker broker;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final presentation = referenceBrokerPresentation(broker);
    final referencePresentation = presentation.displayAsExness;
    final semanticId = referenceBrokerSemanticId(broker);
    return SizedBox(
      height: AccountLinkReferenceMetrics.brokerRowHeight,
      child: Row(
        children: [
          const SizedBox(width: AccountLinkReferenceMetrics.horizontalInset),
          _semanticKeyed(
            prefix: 'broker-mark',
            semanticId: semanticId,
            actualId: broker.id,
            child: AccountLinkBrokerMark(
              broker: broker,
              displayAsExness: referencePresentation,
            ),
          ),
          const SizedBox(width: AccountLinkReferenceMetrics.brokerMarkGap),
          Expanded(
            child: _semanticKeyed(
              prefix: 'broker-row',
              semanticId: semanticId,
              actualId: broker.id,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  key: ValueKey('broker-row-${broker.id}'),
                  onTap: onTap,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          presentation.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AccountLinkReferenceTypography.brokerName,
                        ),
                        if (presentation.companyName case final company?) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            company,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AccountLinkReferenceTypography.brokerCompany,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _semanticKeyed(
            prefix: 'broker-info',
            semanticId: semanticId,
            actualId: broker.id,
            child: AccountLinkInfoButton(
              key: ValueKey('broker-info-${broker.id}'),
              onTap: onInfo,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

Widget _semanticKeyed({
  required String prefix,
  required String semanticId,
  required String actualId,
  required Widget child,
}) {
  if (semanticId == actualId) return child;
  return KeyedSubtree(key: ValueKey('$prefix-$semanticId'), child: child);
}

class _CatalogFailure extends StatelessWidget {
  const _CatalogFailure({
    required this.retryKey,
    required this.onRetry,
    super.key,
  });

  final Key retryKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            key: retryKey,
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}
