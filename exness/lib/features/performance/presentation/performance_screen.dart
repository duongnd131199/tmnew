import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/config/video_demo_mode.dart';
import '../../../core/widgets/ex_widgets.dart';
import 'video_performance_screen.dart';
import '../../account/data/account_session.dart';
import '../../account/data/ex_v2_api_client.dart';
import '../../account/data/ex_v2_models.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  int days = 7;
  bool switchingAccount = false;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(videoDemoModeProvider)) {
      return const VideoPerformanceScreen();
    }
    final sessionState = ref.watch(accountSessionProvider);
    final session = sessionState.value;
    final history = ref.watch(historyDealsProvider);
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: days));
    final rows =
        history.value?.where((row) {
          final type = row['dealType'] ?? row['type'];
          if (type is! String || !_isExitDealType(type)) return false;
          final raw = row['createdAtUtc'] ?? row['createdAt'];
          final date = raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
          return date != null && (days == 0 || !date.isBefore(cutoff));
        }).toList() ??
        const <JsonMap>[];
    final netProfit = days == 0
        ? session?.performance.netProfit ?? 0.0
        : rows.fold<double>(0, (sum, row) {
            final value = row['profit'];
            return sum + (value is num ? value.toDouble() : 0);
          });
    final hasAggregateActivity =
        session != null &&
        (session.performance.netProfit != 0 ||
            session.performance.grossProfit != 0 ||
            session.performance.grossLoss != 0 ||
            session.performance.tradingVolume != 0);
    return Column(
      key: const Key('performance-screen'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 46),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Hiệu suất',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 15),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Tất cả thời gian trên trang này đều theo múi giờ UTC (GMT+0) và có thể khác so với giờ địa phương của bạn',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              _FilterChip(
                label: session?.account.accountCode ?? 'Tài khoản',
                onTap: () => _selectAccount(context, session),
              ),
              const SizedBox(width: 5),
              _FilterChip(
                label: days == 0 ? 'Toàn bộ thời gian' : '$days ngày gần nhất',
                onTap: () => _selectDays(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 50),
        if (sessionState.isLoading || (days != 0 && history.isLoading))
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else if (sessionState.hasError || (days != 0 && history.hasError))
          Center(
            child: ExEmptyState(
              title: 'Không tải được dữ liệu hiệu suất',
              subtitle: 'Kiểm tra kết nối và thử lại.',
              action: TextButton(
                onPressed: () {
                  ref.invalidate(accountSessionProvider);
                  ref.invalidate(historyDealsProvider);
                },
                child: const Text('Thử lại'),
              ),
            ),
          )
        else if (rows.isEmpty && (days != 0 || !hasAggregateActivity))
          Center(
            child: ExEmptyState(
              title: 'Không tìm thấy hoạt động giao dịch nào',
              subtitle: 'Chọn tài khoản hoặc khoảng thời gian khác nhau.',
              action: FilledButton(
                onPressed: () => context.go('/trading'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                  minimumSize: const Size(130, 36),
                ),
                child: const Text('Bắt đầu giao dịch'),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  days == 0 ? 'Lãi/Lỗ ròng' : 'Lãi/Lỗ ròng trong $days ngày',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  formatMoney(netProfit, session?.account.currency ?? 'USD'),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: netProfit < 0
                        ? AppColors.negative
                        : AppColors.positive,
                  ),
                ),
                const SizedBox(height: 16),
                if (days == 0)
                  const Text('Dữ liệu tổng hợp từ máy chủ')
                else
                  Text('${rows.length} giao dịch đã đóng'),
              ],
            ),
          ),
      ],
    );
  }

  void _selectDays(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Khoảng thời gian')),
            for (final option in const [7, 30, 90, 0])
              ListTile(
                title: Text(
                  option == 0 ? 'Toàn bộ thời gian' : '$option ngày gần nhất',
                ),
                trailing: days == option ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() => days = option);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _selectAccount(BuildContext context, ExV2Bootstrap? session) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => Consumer(
          builder: (sheetContext, sheetRef, _) {
            final catalog = sheetRef.watch(accountCatalogProvider);
            final items = catalog.value ?? const <JsonMap>[];
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(title: Text('Tài khoản')),
                  if (catalog.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (catalog.hasError)
                    ListTile(
                      title: const Text('Không tải được danh sách tài khoản'),
                      trailing: const Icon(Icons.refresh),
                      onTap: () => sheetRef.invalidate(accountCatalogProvider),
                    )
                  else if (items.isEmpty && session == null)
                    const ListTile(
                      title: Text('Chưa có tài khoản đang sử dụng'),
                    )
                  else ...[
                    for (final account in items)
                      if (account['id'] is String)
                        ListTile(
                          title: Text(
                            (account['displayName'] as String?) ??
                                (account['login'] as String?) ??
                                (account['id'] as String),
                          ),
                          subtitle: Text(
                            (account['login'] as String?) ??
                                (account['id'] as String),
                          ),
                          trailing:
                              (account['id'] == session?.account.id ||
                                  account['isActive'] == true)
                              ? const Icon(Icons.check)
                              : null,
                          onTap:
                              switchingAccount ||
                                  account['id'] == session?.account.id
                              ? null
                              : () => _activateAccount(
                                  sheetContext,
                                  account['id'] as String,
                                  updateSheet,
                                ),
                        ),
                    if (session != null &&
                        !items.any((row) => row['id'] == session.account.id))
                      ListTile(
                        title: Text(session.account.name),
                        subtitle: Text(session.account.accountCode),
                        trailing: const Icon(Icons.check),
                      ),
                  ],
                  if (switchingAccount)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Text('Hiệu suất được tính cho tài khoản đang chọn.'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _activateAccount(
    BuildContext sheetContext,
    String accountId,
    StateSetter updateSheet,
  ) async {
    if (switchingAccount) return;
    switchingAccount = true;
    updateSheet(() {});
    try {
      await ref
          .read(accountClientProvider)
          .putJson(
            '/mobile/accounts/${Uri.encodeComponent(accountId)}/activate',
            body: const {},
            metadata: ExV2CommandMetadata.create(),
          );
      ref.invalidate(accountSessionProvider);
      ref.invalidate(historyDealsProvider);
      ref.invalidate(historyPositionsProvider);
      ref.invalidate(accountCatalogProvider);
      await ref.read(accountSessionProvider.future);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
    } catch (error) {
      final sessionRejected = await ref
          .read(accountSessionProvider.notifier)
          .clearRejectedSession(error);
      if (sessionRejected && sheetContext.mounted) Navigator.pop(sheetContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sessionRejected
                  ? 'Phiên đã hết hạn. Đăng nhập lại ở Hồ sơ.'
                  : 'Không thể chuyển tài khoản. Thử lại.',
            ),
          ),
        );
      }
    } finally {
      switchingAccount = false;
      if (sheetContext.mounted) updateSheet(() {});
    }
  }
}

bool _isExitDealType(String type) {
  final normalized = type.trim().toLowerCase().replaceAll(
    RegExp(r'[_-]+'),
    ' ',
  );
  return normalized.contains('close') || normalized.contains('out');
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}
