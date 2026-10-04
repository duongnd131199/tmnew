import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/video_demo_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ex_widgets.dart';
import '../../account/data/account_session.dart';
import '../../account/data/ex_v2_api_client.dart';
import '../../account/data/ex_v2_models.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(videoDemoModeProvider)) {
      return const _VideoSettingsSheet();
    }
    final session = ref.watch(accountSessionProvider);
    final state = ref.watch(accountSettingsProvider);
    return ExSheet(
      title: 'Thiết lập',
      child: session.isLoading
          ? const Center(child: CircularProgressIndicator())
          : session.hasError
          ? const Center(child: ExEmptyState(title: 'Không thể tải hồ sơ'))
          : state.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: ExEmptyState(
                  title: 'Không thể tải cài đặt',
                  action: TextButton(
                    onPressed: () => ref.invalidate(accountSettingsProvider),
                    child: const Text('Thử lại'),
                  ),
                ),
              ),
              data: (snapshot) =>
                  snapshot.accountId == session.value?.account.id
                  ? _SettingsContent(settings: snapshot.values)
                  : const Center(child: CircularProgressIndicator()),
            ),
    );
  }
}

class _VideoSettingsSheet extends StatefulWidget {
  const _VideoSettingsSheet();

  @override
  State<_VideoSettingsSheet> createState() => _VideoSettingsSheetState();
}

class _VideoSettingsSheetState extends State<_VideoSettingsSheet> {
  bool _faceId = true;
  bool _hideBalance = false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'Thiết lập',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Positioned(
                  left: AppSpacing.sm,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const Key('settings-list'),
              padding: EdgeInsets.zero,
              children: [
                const _VideoSettingsHeading('Tùy chọn', top: 4),
                _VideoSettingsRow(
                  icon: Icons.notifications_none,
                  title: 'Thông báo',
                  height: 66,
                  onTap: () => _showVideoSettingsInfo(context, 'Thông báo'),
                ),
                _VideoSettingsRow(
                  icon: Icons.translate,
                  title: 'Ngôn ngữ',
                  height: 66,
                  onTap: () => _showVideoSettingsInfo(context, 'Ngôn ngữ'),
                ),
                _VideoSettingsRow(
                  icon: Icons.palette_outlined,
                  title: 'Giao diện',
                  trailingText: 'Cài đặt thiết bị',
                  height: 66,
                  onTap: () => _showVideoSettingsInfo(context, 'Giao diện'),
                ),
                const _VideoSettingsHeading('Bảo mật', top: 16, bottom: 5),
                _VideoSettingsRow(
                  icon: Icons.shield_outlined,
                  title: 'Loại bảo mật',
                  trailingText: 'Điện thoại',
                  height: 74,
                  onTap: () => _showVideoSettingsInfo(context, 'Loại bảo mật'),
                ),
                _VideoSettingsRow(
                  icon: Icons.pin_outlined,
                  title: 'Đổi mật mã',
                  height: 74,
                  onTap: () => _showVideoSettingsInfo(context, 'Đổi mật mã'),
                ),
                _VideoSettingsRow(
                  icon: Icons.timer_outlined,
                  title: 'Khoảng thời gian bỏ qua mã PIN',
                  subtitle: 'Chọn thời điểm cần nhập mã PIN',
                  trailingText: '10 phút',
                  height: 74,
                  onTap: () => _showVideoSettingsInfo(
                    context,
                    'Khoảng thời gian bỏ qua mã PIN',
                  ),
                ),
                _VideoSettingsRow(
                  icon: Icons.face_unlock_outlined,
                  title: 'Đăng nhập bằng\nFace ID',
                  height: 74,
                  trailing: Transform.scale(
                    scale: .86,
                    child: CupertinoSwitch(
                      key: const Key('face-id-switch'),
                      value: _faceId,
                      activeTrackColor: const Color(0xFF596E7C),
                      inactiveTrackColor: const Color(0xFFE4E5E8),
                      trackOutlineColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      onChanged: (value) => setState(() => _faceId = value),
                    ),
                  ),
                  onTap: () => setState(() => _faceId = !_faceId),
                ),
                _VideoSettingsRow(
                  icon: Icons.visibility_off_outlined,
                  title: 'Nghiêng màn hình để ẩn số dư',
                  subtitle: 'Nghiêng màn hình thiết bị của bạn xuống để ẩn\nvà hiển thị nhanh số dư của bạn',
                  height: 74,
                  trailing: Transform.scale(
                    scale: .86,
                    child: CupertinoSwitch(
                      key: const Key('hide-balance-switch'),
                      value: _hideBalance,
                      activeTrackColor: const Color(0xFF596E7C),
                      inactiveTrackColor: const Color(0xFFE4E5E8),
                      trackOutlineColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      onChanged: (value) =>
                          setState(() => _hideBalance = value),
                    ),
                  ),
                  onTap: () => setState(() => _hideBalance = !_hideBalance),
                ),
                const _VideoSettingsHeading('Các hành động bảo mật', top: 10),
                _VideoSettingsRow(
                  icon: Icons.logout,
                  title: 'Bảo mật tài khoản của tôi',
                  subtitle:
                      'Đăng xuất khỏi tất cả thiết bị khác trừ thiết bị này',
                  iconColor: AppColors.dangerSurface,
                  iconForeground: AppColors.negative,
                  onTap: () => _showVideoSettingsInfo(
                    context,
                    'Bảo mật tài khoản của tôi',
                  ),
                ),
                _VideoSettingsRow(
                  icon: Icons.delete_outline,
                  title: 'Đóng Khu vực Cá nhân Exness',
                  subtitle: 'Đây là hành động không thể hoàn tác',
                  iconColor: AppColors.dangerSurface,
                  iconForeground: AppColors.negative,
                  onTap: () => _showVideoSettingsInfo(
                    context,
                    'Đóng Khu vực Cá nhân Exness',
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _VideoSettingsHeading extends StatelessWidget {
  const _VideoSettingsHeading(this.title, {this.top = 20, this.bottom = 10});

  final String title;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(AppSpacing.md, top, AppSpacing.md, bottom),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _VideoSettingsRow extends StatelessWidget {
  const _VideoSettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.height = 72,
    this.iconColor = AppColors.iconSurface,
    this.iconForeground = AppColors.textPrimary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;
  final Color iconColor;
  final Color iconForeground;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 15, right: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: AppSizes.profileIconRadius,
              backgroundColor: iconColor,
              child: Icon(
                icon,
                color: iconForeground,
                size: AppSizes.profileIconSize,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(height: 1.2),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(height: 1.15),
                    ),
                ],
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (trailing case final Widget trailingWidget) trailingWidget,
            if (trailing == null && onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(Icons.chevron_right, size: 21),
              ),
          ],
        ),
      ),
    ),
  );
}

void _showVideoSettingsInfo(BuildContext context, String title) {
  showExSheet(
    context,
    ExSheet(
      title: title,
      child: Center(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    ),
  );
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.settings});

  final JsonMap settings;

  @override
  Widget build(BuildContext context) {
    final language = settings['language'] ?? settings['locale'];
    return ListView(
      key: const Key('settings-list'),
      padding: EdgeInsets.zero,
      children: [
        const _SettingsHeading('Tùy chọn'),
        _SettingsRow(
          icon: Icons.notifications_none,
          title: 'Thông báo',
          onTap: () =>
              showExSheet(context, const NotificationPreferencesSheet()),
        ),
        _SettingsRow(
          icon: Icons.translate,
          title: 'Ngôn ngữ',
          trailing: language is String && language.trim().isNotEmpty
              ? language.trim()
              : 'Chưa có dữ liệu',
          onTap: () => _showInformation(
            context,
            'Ngôn ngữ',
            'Nguồn API hiện tại chưa xác nhận thao tác đổi ngôn ngữ.',
          ),
        ),
        _SettingsRow(
          icon: Icons.palette_outlined,
          title: 'Giao diện',
          trailing: 'Cài đặt thiết bị',
          onTap: () => _showInformation(
            context,
            'Giao diện',
            'Ứng dụng đang sử dụng giao diện theo thiết bị.',
          ),
        ),
        const _SettingsHeading('Bảo mật'),
        const _SettingsRow(
          icon: Icons.shield_outlined,
          title: 'Loại bảo mật',
          trailing: 'Chưa hỗ trợ',
        ),
        const _SettingsRow(icon: Icons.pin_outlined, title: 'Đổi mật mã'),
        const _SettingsRow(
          icon: Icons.timer_outlined,
          title: 'Khoảng thời gian bỏ qua mã PIN',
          subtitle: 'Cần xác thực thiết bị để thiết lập',
        ),
        const _SettingsSwitchRow(
          icon: Icons.face_outlined,
          title: 'Đăng nhập bằng Face ID',
          subtitle: 'Chưa có xác thực sinh trắc học',
          switchKey: Key('face-id-switch'),
        ),
        const _SettingsSwitchRow(
          icon: Icons.visibility_off_outlined,
          title: 'Nghiêng màn hình để ẩn số dư',
          subtitle: 'Chưa có tính năng ẩn số dư',
          switchKey: Key('hide-balance-switch'),
        ),
        const _SettingsHeading('Các hành động bảo mật'),
        const _SettingsRow(
          icon: Icons.logout,
          title: 'Bảo mật tài khoản của tôi',
          subtitle: 'Chưa có luồng quản lý thiết bị khác',
        ),
        const _SettingsRow(
          icon: Icons.delete_outline,
          title: 'Đóng Khu vực Cá nhân',
          subtitle: 'Chưa có thao tác đóng tài khoản',
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class NotificationPreferencesSheet extends ConsumerStatefulWidget {
  const NotificationPreferencesSheet({super.key});

  @override
  ConsumerState<NotificationPreferencesSheet> createState() =>
      _NotificationPreferencesSheetState();
}

class _NotificationPreferencesSheetState
    extends ConsumerState<NotificationPreferencesSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(accountSessionProvider);
    final state = ref.watch(accountSettingsProvider);
    return ExSheet(
      title: 'Thông báo',
      child: session.isLoading
          ? const Center(child: CircularProgressIndicator())
          : session.hasError
          ? const Center(child: ExEmptyState(title: 'Không thể tải hồ sơ'))
          : state.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: ExEmptyState(
                  title: 'Không thể tải cài đặt thông báo',
                  action: TextButton(
                    onPressed: () => ref.invalidate(accountSettingsProvider),
                    child: const Text('Thử lại'),
                  ),
                ),
              ),
              data: (snapshot) {
                if (snapshot.accountId != session.value?.account.id) {
                  return const Center(child: CircularProgressIndicator());
                }
                final settings = snapshot.values;
                final enabled = settings['tradeNotificationsEnabled'];
                if (enabled is! bool) {
                  return const Center(
                    child: ExEmptyState(
                      title: 'Chưa có cài đặt thông báo',
                      subtitle:
                          'Đăng nhập tài khoản hỗ trợ để thay đổi tùy chọn.',
                    ),
                  );
                }
                return ListView(
                  children: [
                    const _SettingsHeading('Giao dịch'),
                    Material(
                      color: AppColors.background,
                      child: ListTile(
                        key: const Key('trade-notifications-tile'),
                        title: const Text('Thông báo giao dịch'),
                        subtitle: const Text(
                          'Nhận thông báo về tài khoản demo',
                        ),
                        onTap: _busy ? null : () => _save(!enabled),
                        leading: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        trailing: Switch(
                          key: const Key('trade-notifications-switch'),
                          value: enabled,
                          onChanged: _busy ? null : _save,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _save(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider).updateSettings({
        'tradeNotificationsEnabled': enabled,
      }, metadata: ExV2CommandMetadata.create());
      ref.invalidate(accountSettingsProvider);
      await ref.read(accountSettingsProvider.future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu cài đặt thông báo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xl,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.iconSurface,
        child: Icon(icon, color: AppColors.textPrimary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null
          ? trailing == null
                ? null
                : ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.settingsTrailingMax,
                    ),
                    child: Text(
                      trailing!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  )
          : trailing == null
          ? const Icon(Icons.chevron_right)
          : SizedBox(
              width: AppSizes.settingsTrailingMax,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      trailing!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
    ),
  );
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.switchKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Key switchKey;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: CircleAvatar(
        backgroundColor: AppColors.iconSurface,
        child: Icon(icon, color: AppColors.textPrimary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(subtitle),
      trailing: Switch(key: switchKey, value: false, onChanged: null),
    ),
  );
}

void _showInformation(BuildContext context, String title, String message) {
  showExSheet(
    context,
    ExSheet(
      title: title,
      child: Center(
        child: ExEmptyState(title: 'Chưa hỗ trợ', subtitle: message),
      ),
    ),
  );
}
