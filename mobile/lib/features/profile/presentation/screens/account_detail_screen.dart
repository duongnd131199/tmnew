import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/profile/presentation/widgets/account_visuals.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

abstract final class _AccountDetailMetrics {
  static const toolbarHeight = 66.0;
  static const heroHeight = 168.0;
  static const rowHeight = 43.0;
}

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({super.key});

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool? _tradeNotificationsOverride;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(activeDemoAccountProvider);
    final serverState = ref.watch(exV2AccountProvider).value;
    final settings = serverState?.settings ?? const <String, dynamic>{};
    final tradeNotifications =
        _tradeNotificationsOverride ??
        _boolSetting(settings, 'tradeNotificationsEnabled');
    final ownerName = _textSetting(settings, const [
      'ownerName',
      'fullName',
    ], fallback: account.name);
    final email = _textSetting(settings, const ['email']);
    final phone = _textSetting(settings, const ['phone', 'phoneNumber']);

    return Scaffold(
      key: const Key('account-detail-screen'),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: _AccountDetailMetrics.toolbarHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.md),
                  child: KeyedSubtree(
                    key: const Key('account-detail-back'),
                    child: AccountRoundBackButton(
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Scrollbar(
                radius: const Radius.circular(2),
                thickness: 2,
                child: ListView(
                  key: const Key('account-detail-scroll'),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _AccountHero(account: account),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailGroup(
                      key: const Key('account-detail-company-group'),
                      children: [
                        _DetailRow(
                          title: 'Công ty',
                          value: _unavailable(account.company),
                          showChevron: true,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailGroup(
                      key: const Key('account-detail-money-group'),
                      children: [
                        _DetailRow(
                          key: const Key('account-deposit-row'),
                          title: 'Tiền nạp',
                          titleColor: AppColors.primary,
                          showChevron: true,
                          onTap: () => context.push('/deposit'),
                        ),
                        _DetailRow(
                          key: const Key('account-withdraw-row'),
                          title: 'Tiền rút',
                          titleColor: AppColors.primary,
                          showChevron: true,
                          onTap: () => context.push('/withdraw'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailGroup(
                      key: const Key('account-detail-profile-group'),
                      children: [
                        _DetailRow(title: 'Tên', value: ownerName),
                        _DetailRow(title: 'Email', value: email),
                        _DetailRow(title: 'Điện thoại', value: phone),
                        _DetailRow(title: 'Đăng nhập', value: account.id),
                        _DetailRow(
                          title: 'Máy chủ',
                          value: _unavailable(account.server),
                        ),
                        _DetailRow(
                          title: 'Đã kết nối',
                          value: _unavailable(account.accessPoint),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailGroup(
                      key: const Key('account-detail-security-group'),
                      children: [
                        _DetailRow(
                          title: 'Thông báo giao dịch',
                          info: true,
                          trailing: Switch.adaptive(
                            key: const Key('trade-notifications-switch'),
                            value: tradeNotifications,
                            onChanged: (value) => _setTradeNotifications(
                              value,
                              serverState != null,
                            ),
                            activeTrackColor: AppColors.primary,
                          ),
                        ),
                        _DetailRow(
                          key: const Key('account-connect-device-row'),
                          title: 'Kết nối từ thiết bị khác',
                          showChevron: true,
                          onTap: () {},
                        ),
                        _DetailRow(
                          key: const Key('account-change-password-row'),
                          title: 'Thay đổi mật khẩu',
                          showChevron: true,
                          onTap: () {},
                        ),
                        _DetailRow(
                          key: const Key('account-delete-row'),
                          title: 'Xóa tài khoản',
                          titleColor: AppColors.negative,
                          showChevron: true,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setTradeNotifications(bool value, bool hasServerState) async {
    setState(() => _tradeNotificationsOverride = value);
    if (!hasServerState) return;
    try {
      await ref.read(exV2AccountProvider.notifier).updateSettings({
        'tradeNotificationsEnabled': value,
      });
      if (mounted) setState(() => _tradeNotificationsOverride = null);
    } catch (_) {
      if (mounted) setState(() => _tradeNotificationsOverride = null);
    }
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.account});

  final DemoAccountProfile account;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('account-detail-hero'),
    height: _AccountDetailMetrics.heroHeight,
    color: AppColors.surface,
    alignment: Alignment.center,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AccountBrokerMark(
          brand: account.brand,
          size: AccountVisualMetrics.heroBrokerMark,
        ),
        const SizedBox(height: 7),
        Text(
          account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'sans-serif',
            fontSize: 17,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${account.id} - ${_unavailable(account.server)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'sans-serif',
            fontSize: 13,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${_formatAccountBalance(account.balance)} ${account.currency}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'sans-serif',
            fontSize: 13,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (account.isMaster) ...[
              const _AccountBadge(label: 'Master', color: AppColors.negative),
              const SizedBox(width: 5),
            ],
            _AccountBadge(label: account.mode, color: AppColors.primary),
          ],
        ),
      ],
    ),
  );
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      border: Border.all(color: color, width: 1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontFamily: 'sans-serif',
        fontSize: 12,
        height: 1,
      ),
    ),
  );
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surface,
    child: Column(children: children),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.title,
    super.key,
    this.value,
    this.titleColor = AppColors.textPrimary,
    this.showChevron = false,
    this.info = false,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? value;
  final Color titleColor;
  final bool showChevron;
  final bool info;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: _AccountDetailMetrics.rowHeight,
        margin: const EdgeInsets.only(left: AppSpacing.sm),
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: .5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontFamily: 'sans-serif',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                  if (info) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      key: Key('account-detail-info-glyph'),
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
            if (value != null)
              Flexible(
                flex: 2,
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontFamily: 'sans-serif',
                    fontSize: 15.5,
                    height: 1,
                  ),
                ),
              ),
            ?trailing,
            if (showChevron)
              const SizedBox(
                width: 24,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AccountChevronRight(),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

String _textSetting(
  Map<String, dynamic> settings,
  List<String> keys, {
  String fallback = '—',
}) {
  for (final key in keys) {
    final value = settings[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return fallback;
}

bool _boolSetting(Map<String, dynamic> settings, String key) {
  final value = settings[key];
  if (value is bool) return value;
  return value?.toString().toLowerCase() == 'true';
}

String _unavailable(String value) => value.trim().isEmpty ? '—' : value;

String _formatAccountBalance(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final digits = parts.first;
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(' ');
    grouped.write(digits[index]);
  }
  return '$grouped.${parts.last}';
}
