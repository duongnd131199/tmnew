import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ex_widgets.dart';
import '../../account/data/account_session.dart';
import '../../account/data/ex_v2_api_client.dart';
import '../data/account_notification.dart';
import '../data/notification_provider.dart';

class NotificationsSheet extends ConsumerStatefulWidget {
  const NotificationsSheet({super.key});

  @override
  ConsumerState<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<NotificationsSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final items = state.value;
    return ExSheet(
      title: 'Thông báo',
      child: Column(
        key: const Key('notifications-sheet'),
        children: [
          if (items?.any((item) => !item.isRead) == true)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('notifications-read-all'),
                onPressed: _busy ? null : _markAllRead,
                child: const Text('Đánh dấu tất cả'),
              ),
            ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: ExEmptyState(
                  title: 'Không thể tải thông báo',
                  action: TextButton(
                    onPressed: () => ref.invalidate(notificationsProvider),
                    child: const Text('Thử lại'),
                  ),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: ExEmptyState(title: 'Chưa có thông báo'),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: AppColors.border, height: 1),
                      itemBuilder: (context, index) =>
                          _NotificationRow(items[index], _busy, _markRead),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markRead(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .markNotificationRead(id, metadata: ExV2CommandMetadata.create());
      ref.invalidate(notificationsProvider);
      await ref.read(notificationsProvider.future);
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .markAllNotificationsRead(metadata: ExV2CommandMetadata.create());
      ref.invalidate(notificationsProvider);
      await ref.read(notificationsProvider.future);
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không thể đánh dấu đã đọc. Thử lại.')),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow(this.notification, this.busy, this.onRead);

  final AccountNotification notification;
  final bool busy;
  final Future<void> Function(String id) onRead;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    child: ListTile(
      key: notification.id.isEmpty
          ? null
          : Key('notification-${notification.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      onTap: busy || notification.isRead || notification.id.isEmpty
          ? null
          : () => onRead(notification.id),
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? AppColors.iconSurface
            : AppColors.infoSurface,
        child: const Icon(
          Icons.notifications_none,
          color: AppColors.textPrimary,
        ),
      ),
      title: Text(notification.title),
      subtitle: notification.message.isEmpty
          ? null
          : Text(notification.message),
      trailing: Text(
        notification.isRead ? 'Đã đọc' : 'Mới',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    ),
  );
}
