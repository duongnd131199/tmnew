import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_shell.dart';
import '../../../core/config/video_demo_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ex_widgets.dart';
import '../../account/data/account_session.dart';
import '../../account/data/ex_v2_models.dart';
import '../../account/presentation/account_screen.dart';
import '../../wallet/presentation/wallet_sheet.dart';
import 'settings_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showAllBenefits = false;
  bool _showEmail = false;
  bool _loggingOut = false;
  bool _demoSignedIn = true;
  String? _visibleAccountId;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(videoDemoModeProvider)) {
      return _demoProfile(context);
    }
    final sessionState = ref.watch(accountSessionProvider);
    final accountId = sessionState.value?.account.id;
    if (_visibleAccountId != accountId) {
      _visibleAccountId = accountId;
      _showEmail = false;
    }
    final settingsState = ref.watch(accountSettingsProvider);
    final settingsSnapshot = settingsState.value;
    final settings =
        settingsState.isLoading ||
            settingsState.hasError ||
            settingsSnapshot?.accountId != accountId
        ? null
        : settingsSnapshot?.values;
    return CustomScrollView(
      key: const Key('profile-screen'),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _ProfileHeader(
            onSettings: () => showExSheet(context, const SettingsSheet()),
          ),
        ),
        SliverToBoxAdapter(
          child: sessionState.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ExEmptyState(
                title: 'Không thể tải hồ sơ',
                action: FilledButton(
                  onPressed: () => ref.invalidate(accountSessionProvider),
                  child: const Text('Thử lại'),
                ),
              ),
            ),
            data: (session) => _content(context, session, settings),
          ),
        ),
      ],
    );
  }

  Widget _demoProfile(BuildContext context) => CustomScrollView(
    key: const Key('profile-screen'),
    slivers: [
      SliverPersistentHeader(
        pinned: true,
        delegate: _ProfileHeader(
          onSettings: () => showVideoExSheet(
            context,
            const SettingsSheet(),
            heightFactor: .933,
          ),
        ),
      ),
      SliverToBoxAdapter(child: _demoContent(context)),
    ],
  );

  Widget _demoContent(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _VideoBenefitsBanner(),
      const SizedBox(height: AppSpacing.xs),
      const _SectionTitle('Tài khoản'),
      const SizedBox(height: 13),
      _VideoProfileRow(
        icon: Icons.alternate_email,
        title: 'Đăng nhập',
        subtitle: _demoSignedIn
            ? _showEmail
                  ? 'demo@example.com'
                  : '******@*******'
            : 'Đăng nhập tài khoản demo',
        height: 60,
        trailing: _showEmail
            ? const Icon(
                Icons.visibility_outlined,
                size: 20,
                color: AppColors.textSecondary,
              )
            : const CustomPaint(
                size: Size(20, 20),
                painter: _VideoClosedEyePainter(),
              ),
        showChevron: false,
        onTap: () => setState(() => _showEmail = !_showEmail),
      ),
      _VideoProfileRow(
        icon: Icons.person_outline,
        title: 'Tiến độ xác minh',
        height: 60,
        trailing: const _VideoStatusBadge(
          label: 'Đã xác minh (Cơ bản)',
          foreground: Color(0xFF9D813C),
          background: Color(0xFFFFFBF0),
        ),
        onTap: () => _showDemoProfileInfo(context, 'Tiến độ xác minh'),
      ),
      const SizedBox(height: 3),
      const _SectionTitle('Quyền lợi'),
      const SizedBox(height: 13),
      _VideoProfileRow(
        icon: Icons.brightness_2_outlined,
        iconWidget: const CustomPaint(
          size: Size(23, 23),
          painter: _OvernightBenefitPainter(),
        ),
        title: 'Miễn phí phí qua đêm',
        trailing: const _VideoStatusBadge(
          label: 'Đủ điều kiện',
          foreground: Color(0xFF289463),
          background: Color(0xFFF0FBF5),
        ),
        onTap: () => _showDemoProfileInfo(context, 'Miễn phí phí qua đêm'),
      ),
      _VideoProfileRow(
        icon: Icons.shield_outlined,
        iconWidget: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 21, color: AppColors.textPrimary),
            Icon(Icons.remove, size: 12, color: AppColors.textPrimary),
          ],
        ),
        title: 'Bảo vệ khỏi số dư âm',
        onTap: () => _showDemoProfileInfo(context, 'Bảo vệ khỏi số dư âm'),
      ),
      const SizedBox(height: 7),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SizedBox(
          height: 36,
          child: TextButton(
            key: const Key('profile-show-more'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: AppColors.infoSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            onPressed: () =>
                setState(() => _showAllBenefits = !_showAllBenefits),
            child: Text(_showAllBenefits ? 'Hiển thị ít hơn' : 'Hiển thị thêm'),
          ),
        ),
      ),
      if (_showAllBenefits)
        _VideoProfileRow(
          icon: Icons.stars_outlined,
          title: 'Quyền lợi Bronze',
          onTap: () => _showDemoProfileInfo(context, 'Quyền lợi Bronze'),
        ),
      const SizedBox(height: AppSpacing.sm),
      const _SectionTitle('Ví nạp tiền'),
      _VideoProfileRow(
        icon: Icons.attach_money,
        title: 'Số dư',
        trailing: const Text(
          '2,00 USD',
          key: Key('profile-wallet-balance'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        onTap: () => _showDemoProfileInfo(context, 'Ví nạp tiền'),
        notificationDot: true,
      ),
      const _SectionTitle('Ví tiền điện tử'),
      _VideoProfileRow(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Số dư',
        trailing: const Text(
          '0,00 USD',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        onTap: () => _showDemoProfileInfo(context, 'Ví tiền điện tử'),
      ),
      const _SectionTitle('Chương trình giới thiệu'),
      _VideoProfileRow(
        icon: Icons.work_outline,
        title: 'Số dư\nTổng lợi nhuận\nGiới thiệu',
        height: 76,
        trailing: const Text(
          '90.21 USD\n7633.50 USD\n5',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        iconColor: AppColors.referralSurface,
        iconForeground: AppColors.referral,
        onTap: () => _showDemoProfileInfo(context, 'Chương trình giới thiệu'),
      ),
      const _SectionTitle('Hỗ trợ'),
      _demoSupportRow(
        context,
        Icons.favorite_border,
        'Trung tâm Hỗ trợ Khách hàng',
        'Giải đáp các thắc mắc của bạn',
      ),
      _demoSupportRow(
        context,
        Icons.sms_outlined,
        'Mở yêu cầu',
        'Điền vào mẫu yêu cầu và chúng tôi sẽ liên hệ lại với bạn',
        height: 74,
      ),
      _demoSupportRow(
        context,
        Icons.chat_bubble_outline,
        'Chat trực tuyến',
        'Đừng ngần ngại liên hệ với bộ phận hỗ trợ khách hàng của chúng tôi',
        height: 74,
      ),
      _demoSupportRow(
        context,
        Icons.lightbulb_outline,
        'Đề xuất một tính năng',
        'Giúp chúng tôi trở nên tốt hơn',
      ),
      _demoSupportRow(
        context,
        Icons.assignment_outlined,
        'Giấy tờ Pháp lý',
        'Exness (SC) Ltd',
      ),
      _demoSupportRow(
        context,
        Icons.thumb_up_alt_outlined,
        'Đánh giá ứng dụng',
        'Vui lòng để lại đánh giá cho chúng tôi trên App Store',
        height: 74,
      ),
      _demoSupportRow(
        context,
        Icons.info_outline,
        'Giới thiệu về ứng dụng',
        null,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.section,
          AppSpacing.md,
          AppSpacing.section,
        ),
        child: SizedBox(
          height: 37,
          child: TextButton.icon(
            key: const Key('profile-session-action'),
            onPressed: () => setState(() => _demoSignedIn = !_demoSignedIn),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.negative,
              backgroundColor: AppColors.dangerSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            icon: Icon(_demoSignedIn ? Icons.logout : Icons.login, size: 16),
            label: Text(_demoSignedIn ? 'Đăng xuất' : 'Đăng nhập'),
          ),
        ),
      ),
    ],
  );

  Widget _demoSupportRow(
    BuildContext context,
    IconData icon,
    String title,
    String? subtitle, {
    double height = 66,
  }) => _VideoProfileRow(
    icon: icon,
    title: title,
    subtitle: subtitle,
    height: height,
    onTap: () => _showDemoProfileInfo(context, title),
  );

  Widget _content(
    BuildContext context,
    ExV2Bootstrap? session,
    JsonMap? settings,
  ) {
    final wallet = session?.wallet;
    final email = _maskedEmail(settings?['email']);
    final fullEmail = settings?['email'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BenefitsBanner(),
        const _SectionTitle('Tài khoản'),
        _ProfileRow(
          icon: Icons.alternate_email,
          title: 'Đăng nhập',
          subtitle: session == null
              ? 'Đăng nhập tài khoản demo'
              : _showEmail && email != null && fullEmail is String
              ? fullEmail.trim()
              : email ?? session.account.accountCode,
          trailing: email == null
              ? null
              : Icon(
                  _showEmail
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
          onTap: session == null
              ? () => showAccountLoginSheet(context)
              : email == null
              ? null
              : () => setState(() => _showEmail = !_showEmail),
        ),
        const _ProfileRow(
          icon: Icons.person_outline,
          title: 'Tiến độ xác minh',
          subtitle: 'Chưa có dữ liệu xác minh',
        ),
        const _SectionTitle('Quyền lợi'),
        const _ProfileRow(
          icon: Icons.nights_stay_outlined,
          title: 'Miễn phí phí qua đêm',
          subtitle: 'Chưa có dữ liệu điều kiện',
        ),
        const _ProfileRow(
          icon: Icons.shield_outlined,
          title: 'Bảo vệ khỏi số dư âm',
          subtitle: 'Chưa có dữ liệu điều kiện',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextButton(
            key: const Key('profile-show-more'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: AppColors.infoSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            onPressed: () =>
                setState(() => _showAllBenefits = !_showAllBenefits),
            child: Text(_showAllBenefits ? 'Hiển thị ít hơn' : 'Hiển thị thêm'),
          ),
        ),
        if (_showAllBenefits)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: ExEmptyState(
              title: 'Chưa có dữ liệu quyền lợi',
              subtitle: 'Quyền lợi sẽ hiển thị khi có nguồn dữ liệu hợp lệ.',
            ),
          ),
        const _SectionTitle('Ví nạp tiền'),
        _ProfileRow(
          icon: Icons.attach_money,
          title: 'Số dư',
          subtitle: 'Ví demo',
          trailing: Text(
            wallet == null
                ? 'Chưa có dữ liệu'
                : formatMoney(wallet.totalBalance, wallet.currency),
            key: const Key('profile-wallet-balance'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          onTap: wallet == null
              ? null
              : () => showExSheet(context, WalletSheet(wallet: wallet)),
        ),
        const _SectionTitle('Ví tiền điện tử'),
        const _ProfileRow(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Số dư',
          subtitle: 'Chưa có dữ liệu ví tiền điện tử',
        ),
        const _SectionTitle('Chương trình giới thiệu'),
        const _ProfileRow(
          icon: Icons.card_giftcard_outlined,
          title: 'Chưa có dữ liệu giới thiệu',
          iconColor: AppColors.referralSurface,
          iconForeground: AppColors.referral,
        ),
        const _SectionTitle('Hỗ trợ'),
        _supportRow(
          context,
          Icons.favorite_border,
          'Trung tâm Hỗ trợ Khách hàng',
        ),
        _supportRow(context, Icons.message_outlined, 'Mở yêu cầu'),
        _supportRow(context, Icons.chat_bubble_outline, 'Chat trực tuyến'),
        _supportRow(context, Icons.lightbulb_outline, 'Đề xuất một tính năng'),
        _supportRow(context, Icons.assignment_outlined, 'Giấy tờ Pháp lý'),
        _supportRow(context, Icons.thumb_up_alt_outlined, 'Đánh giá ứng dụng'),
        _supportRow(context, Icons.info_outline, 'Giới thiệu về ứng dụng'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.section,
            AppSpacing.md,
            AppSpacing.section,
          ),
          child: TextButton.icon(
            key: const Key('profile-session-action'),
            onPressed: _loggingOut
                ? null
                : session == null
                ? () => showAccountLoginSheet(context)
                : _logout,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.negative,
              backgroundColor: AppColors.dangerSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            icon: Icon(session == null ? Icons.login : Icons.logout),
            label: Text(session == null ? 'Đăng nhập' : 'Đăng xuất'),
          ),
        ),
      ],
    );
  }

  Widget _supportRow(BuildContext context, IconData icon, String title) =>
      _ProfileRow(
        icon: icon,
        title: title,
        onTap: () => _showUnavailable(
          context,
          title,
          'Chức năng này chưa có nguồn dữ liệu hoặc dịch vụ hỗ trợ.',
        ),
      );

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await ref.read(accountSessionProvider.notifier).logout();
      ref.invalidate(accountSettingsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể đăng xuất. Thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }
}

class _ProfileHeader extends SliverPersistentHeaderDelegate {
  _ProfileHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  double get minExtent => AppSizes.profileHeaderCollapsed;

  @override
  double get maxExtent => AppSizes.profileHeaderExpanded;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final compact = shrinkOffset >= maxExtent - minExtent;
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          if (compact)
            Center(
              child: Text(
                'Hồ sơ',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else
            Positioned(
              left: AppSpacing.md,
              bottom: AppSpacing.lg,
              child: Text(
                'Hồ sơ',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          Positioned(
            right: 0,
            top: -4,
            child: IconButton(
              key: const Key('profile-settings'),
              icon: const Icon(Icons.settings_outlined),
              onPressed: onSettings,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileHeader oldDelegate) => true;
}

class _BenefitsBanner extends StatelessWidget {
  const _BenefitsBanner();

  @override
  Widget build(BuildContext context) => Container(
    height: AppSizes.profileBannerHeight,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.card),
      gradient: const LinearGradient(
        colors: [AppColors.bronzeStart, AppColors.bronzeEnd],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Quyền lợi',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.bronzeText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Chưa có dữ liệu hạng',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.bronzeText),
        ),
      ],
    ),
  );
}

class _VideoBenefitsBanner extends StatelessWidget {
  const _VideoBenefitsBanner();

  @override
  Widget build(BuildContext context) => Container(
    height: AppSizes.profileBannerHeight,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        const Positioned.fill(
          child: CustomPaint(painter: _BronzeBannerPainter()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bronze',
                      style: TextStyle(
                        color: AppColors.bronzeText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '0,15 EXD',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.bronzeText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Text(
                'Còn 4 ngày nữa để nâng cấp',
                style: TextStyle(color: Color(0xFFADAAA9), fontSize: 12),
              ),
              const Spacer(),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kiếm 9,85 EXD',
                      style: TextStyle(
                        color: AppColors.bronzeText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '0,15/10',
                    style: TextStyle(color: Color(0xFFADAAA9), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Stack(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.bronzeText.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    height: 4,
                    width: 7,
                    decoration: BoxDecoration(
                      color: AppColors.bronzeText,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BronzeBannerPainter extends CustomPainter {
  const _BronzeBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.lerp(AppColors.bronzeStart, Colors.black, .18)!,
            Color.lerp(AppColors.bronzeEnd, AppColors.bronzeStart, .28)!,
          ],
        ).createShader(rect),
    );
    final sheen = Path()
      ..moveTo(0, size.height * .7)
      ..lineTo(size.width * .52, 0)
      ..lineTo(size.width * .9, 0)
      ..lineTo(size.width * .68, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      sheen,
      Paint()..color = AppColors.bronzeText.withValues(alpha: .075),
    );
    final darkEdge = Path()
      ..moveTo(size.width * .91, 0)
      ..lineTo(size.width * .97, 0)
      ..lineTo(size.width * .73, size.height)
      ..lineTo(size.width * .69, size.height)
      ..close();
    canvas.drawPath(
      darkEdge,
      Paint()..color = AppColors.bronzeStart.withValues(alpha: .76),
    );
    canvas.drawLine(
      Offset(0, size.height * .72),
      Offset(size.width * .52, 0),
      Paint()
        ..color = AppColors.bronzeText.withValues(alpha: .18)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _BronzeBannerPainter oldDelegate) => false;
}

class _VideoClosedEyePainter extends CustomPainter {
  const _VideoClosedEyePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.textSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final lid = Path()
      ..moveTo(size.width * .08, size.height * .38)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .9,
        size.width * .92,
        size.height * .38,
      );
    canvas.drawPath(lid, stroke);
    for (final lash in <(double, double, double, double)>[
      (.22, .58, .11, .76),
      (.4, .7, .36, .9),
      (.6, .7, .64, .9),
      (.78, .58, .89, .76),
    ]) {
      canvas.drawLine(
        Offset(size.width * lash.$1, size.height * lash.$2),
        Offset(size.width * lash.$3, size.height * lash.$4),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VideoClosedEyePainter oldDelegate) => false;
}

class _OvernightBenefitPainter extends CustomPainter {
  const _OvernightBenefitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      Offset(size.width * .43, size.height * .5),
      size.width * .36,
      stroke,
    );
    canvas.drawCircle(
      Offset(size.width * .61, size.height * .5),
      size.width * .36,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _OvernightBenefitPainter oldDelegate) => false;
}

class _VideoStatusBadge extends StatelessWidget {
  const _VideoStatusBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: foreground, height: 1),
    ),
  );
}

class _VideoProfileRow extends StatelessWidget {
  const _VideoProfileRow({
    required this.icon,
    required this.title,
    this.iconWidget,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.height = 66,
    this.iconColor = AppColors.iconSurface,
    this.iconForeground = AppColors.textPrimary,
    this.showChevron = true,
    this.notificationDot = false,
  });

  final IconData icon;
  final String title;
  final Widget? iconWidget;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;
  final Color iconColor;
  final Color iconForeground;
  final bool showChevron;
  final bool notificationDot;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 15, right: 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: AppSizes.profileIconRadius,
                  backgroundColor: iconColor,
                  child:
                      iconWidget ??
                      Icon(
                        icon,
                        size: AppSizes.profileIconSize,
                        color: iconForeground,
                      ),
                ),
                if (notificationDot)
                  const Positioned(
                    right: 1,
                    top: -1,
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: AppColors.negative,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: title.contains('\n') ? 3 : 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(height: title.contains('\n') ? 1.35 : null),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(height: 1.25),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
            if (showChevron && onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  Icons.chevron_right,
                  size: 21,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void _showDemoProfileInfo(BuildContext context, String title) {
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.section,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = AppColors.iconSurface,
    this.iconForeground = AppColors.textPrimary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color iconForeground;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.rowVertical,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: AppSizes.profileIconRadius,
            backgroundColor: iconColor,
            child: Icon(
              icon,
              size: AppSizes.profileIconSize,
              color: iconForeground,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          ?trailing,
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm),
              child: Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ),
        ],
      ),
    ),
  );
}

String? _maskedEmail(Object? value) {
  if (value is! String) return null;
  final parts = value.trim().split('@');
  if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
    return null;
  }
  return '${parts.first.substring(0, 1)}••••@${parts.last}';
}

void _showUnavailable(BuildContext context, String title, String description) {
  showExSheet(
    context,
    ExSheet(
      title: title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ExEmptyState(title: 'Chưa hỗ trợ', subtitle: description),
        ),
      ),
    ),
  );
}
