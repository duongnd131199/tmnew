import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(WidgetRef ref) async {
    await ref.read(exV2AccountProvider.notifier).markAllNotificationsRead();
  }

  Future<void> _markRead(WidgetRef ref, String id) async {
    await ref.read(exV2AccountProvider.notifier).markNotificationRead(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(exV2NotificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: notifications.value?.isNotEmpty == true
                ? () => _markAllRead(ref)
                : null,
            child: const Text('Đã đọc'),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(exV2AccountProvider),
            child: const Text('Thử lại'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Bạn đã xem tất cả thông báo'))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final id = (item['id'] ?? '').toString();
                  final title = (item['title'] ?? item['type'] ?? 'Thông báo')
                      .toString();
                  final message =
                      (item['message'] ??
                              item['body'] ??
                              item['description'] ??
                              '')
                          .toString();
                  final createdAt =
                      (item['createdAt'] ?? item['updatedAt'] ?? '').toString();
                  final isRead = item['isRead'] == true || item['read'] == true;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: isRead || id.isEmpty
                        ? null
                        : () => _markRead(ref, id),
                    leading: CircleAvatar(
                      backgroundColor: isRead
                          ? AppColors.surface
                          : AppColors.primaryMuted,
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                    title: Text(displayTradingSymbolText(title)),
                    subtitle: Text(
                      displayTradingSymbolText(
                        message.isEmpty ? createdAt : message,
                      ),
                    ),
                    trailing: createdAt.isEmpty
                        ? null
                        : Text(
                            createdAt,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                  );
                },
              ),
      ),
    );
  }
}
