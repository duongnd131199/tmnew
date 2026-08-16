import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/profile/presentation/widgets/account_visuals.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/mt5_settings_icon_assets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeDemoAccountProvider);
    final serverState = ref.watch(exV2AccountProvider).value;
    final serverSettings = serverState?.settings ?? const <String, dynamic>{};
    final unreadValue =
        serverSettings['unreadNotifications'] ?? serverSettings['unreadCount'];
    final unreadCount = unreadValue is num ? unreadValue.toInt() : null;
    final language = (serverSettings['language'] ?? serverSettings['locale'])
        ?.toString();
    String sectionRoute(String title) =>
        '/section?title=${Uri.encodeComponent(title)}';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 76,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 48.3333333333,
                    child: Transform.translate(
                      offset: const Offset(.6666666667, .6666666667),
                      child: Transform.scale(
                        scaleY: 1,
                        alignment: Alignment.topCenter,
                        child: Text(
                          'Cai dat',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'sans-serif',
                            fontSize: 19.5,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                key: const Key('settings-scrollbar'),
                radius: const Radius.circular(2),
                thickness: 2,
                child: ListView(
                  key: const Key('settings-scroll-view'),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 118),
                  children: [
                    _SettingsCard(
                      children: [
                        _AccountCardHeader(
                          account: account,
                          onTap: () => context.push('/profile'),
                        ),
                        _SettingsRow(
                          iconKind: _SettingsIconKind.newAccount,
                          title: 'Tai khoan moi',
                          height: 50.6666666667,
                          contentOffsetY: 1.3,
                          iconOffsetY: .6666666667,
                          titleOffsetY: -1,
                          titleScaleX: .97,
                          onTap: serverState == null
                              ? () => context.push('/register')
                              : () => context.push('/accounts/add'),
                        ),
                        _SettingsRow(
                          iconKind: _SettingsIconKind.mail,
                          title: 'Hop thu',
                          subtitle: 'You have registered a new acco...',
                          height: 62,
                          contentOffsetY: -1.3,
                          iconOffsetY: .6666666667,
                          titleOffsetY: .3333333333,
                          titleScaleX: 1.01,
                          titleScaleY: .963,
                          subtitleOffsetY: -.3333333333,
                          subtitleScaleX: 1.033,
                          subtitleScaleY: 1.045,
                          onTap: () => context.push('/messages'),
                        ),
                        _SettingsRow(
                          iconKind: _SettingsIconKind.news,
                          title: 'Tin tuc',
                          subtitle: 'Australian Dollar: RBA keeps hik...',
                          height: 62,
                          contentOffsetY: -1.3,
                          iconOffsetY: .6666666667,
                          titleScaleX: .977,
                          titleScaleY: 1.1,
                          subtitleOffsetY: -.3333333333,
                          subtitleScaleX: 1.035,
                          subtitleScaleY: 1.045,
                          onTap: () => context.push(sectionRoute('Tin tuc')),
                        ),
                        _SettingsRow(
                          iconKind: _SettingsIconKind.tradays,
                          title: 'Tradays',
                          subtitle: 'Lich Kinh Te',
                          height: 62,
                          contentOffsetY: -1.3,
                          subtitleOffsetY: -.3333333333,
                          subtitleScaleX: 1.023,
                          subtitleScaleY: 1.055,
                          onTap: () => context.push(sectionRoute('Tradays')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 19),
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          iconKind: _SettingsIconKind.community,
                          title: 'Trao doi va tin nhan',
                          subtitle: 'Dang nhap vao cong dong MQ...',
                          notificationCount: serverState == null
                              ? 2
                              : unreadCount,
                          showConnectedIndicator: true,
                          height: 62,
                          subtitleGap: 8.7,
                          contentOffsetY: -2.33,
                          iconOffsetY: 1,
                          titleOffsetY: .6666666667,
                          titleScaleX: .98,
                          titleScaleY: 1.048,
                          subtitleOffsetY: 1.6666666667,
                          subtitleScaleX: 1.037,
                          onTap: () => context.push('/messages'),
                        ),
                        _SettingsRow(
                          iconKind: _SettingsIconKind.mql5,
                          title: 'Cong dong trader',
                          height: 50,
                          contentOffsetY: -.1,
                          titleScaleX: 1.01,
                          onTap: () =>
                              context.push(sectionRoute('Cong dong trader')),
                        ),
                        _SettingsRow(
                          iconKind: _SettingsIconKind.telegram,
                          title: 'MQL5 Algo Trading',
                          height: 50.6666666667,
                          contentOffsetY: -1.3,
                          titleOffsetY: .6666666667,
                          titleScaleX: .996,
                          onTap: () =>
                              context.push(sectionRoute('MQL5 Algo Trading')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 19.3333333333),
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          iconKind: _SettingsIconKind.otp,
                          title: 'OTP',
                          subtitle: 'Khoi tao mat khau mot lan',
                          height: 61.6666666667,
                          contentOffsetY: -1.3,
                          iconOffsetY: .3333333333,
                          titleOffsetY: .6666666667,
                          titleScaleY: 1.05,
                          subtitleOffsetY: -.3333333333,
                          subtitleScaleX: 1.024,
                          subtitleScaleY: 1.11,
                          onTap: () => context.push(sectionRoute('OTP')),
                        ),
                        _SettingsRow(
                          iconKind: _SettingsIconKind.language,
                          title: 'Giao dien',
                          subtitle: language?.trim().isNotEmpty == true
                              ? language
                              : 'Tieng Viet',
                          height: 61,
                          contentOffsetY: -1.3,
                          iconOffsetY: 1.3333333333,
                          titleOffsetY: 1,
                          titleScaleX: .99,
                          titleScaleY: 1.05,
                          subtitleOffsetY: -1,
                          subtitleScaleX: 1.037,
                          subtitleScaleY: 1.12,
                          onTap: () => context.push(sectionRoute('Giao dien')),
                        ),
                        _SettingsRow(
                          iconKind: _SettingsIconKind.candles,
                          title: 'Nhung bieu do',
                          height: 61,
                          onTap: () => context.go('/chart'),
                        ),
                        _SettingsRow(
                          iconKind: _SettingsIconKind.journal,
                          title: 'Nhat ky',
                          height: 61,
                          onTap: () => context.push(sectionRoute('Nhat ky')),
                        ),
                        _SettingsRow(
                          iconKind: _SettingsIconKind.settings,
                          title: 'Cai dat',
                          height: 61,
                          onTap: () => context.push(sectionRoute('Cai dat')),
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
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: children),
      ),
    );
  }
}

class _AccountCardHeader extends StatelessWidget {
  const _AccountCardHeader({required this.account, required this.onTap});

  final DemoAccountProfile account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('settings-account'),
      button: true,
      label:
          '${account.name}, ${account.company}, ${account.id}, '
          '${account.server}, ${account.accessPoint}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 110.6666666667,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 9.3,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: const Offset(0, 1.6666666667),
                    child: Transform.scale(
                      scaleX: 1.025,
                      scaleY: 1.05,
                      alignment: Alignment.center,
                      child: Text(
                        account.name,
                        key: const Key('settings-account-name'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'sans-serif',
                          fontSize: 18.5,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 35.7,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: const Offset(.6666666667, 1.3333333333),
                    child: Transform.scale(
                      scaleX: .993,
                      scaleY: .92,
                      alignment: Alignment.center,
                      child: Text(
                        account.company,
                        key: const Key('settings-account-company'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'sans-serif',
                          fontSize: 15,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 60.6333333333,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: const Offset(.6666666667, 0),
                    child: Transform.scale(
                      scaleX: 1.011,
                      alignment: Alignment.topCenter,
                      child: Text(
                        '${account.id} - ${account.server}\n'
                        '${account.accessPoint}',
                        key: const Key('settings-account-server-access'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'sans-serif',
                          fontSize: 15,
                          height: 1.4833333333,
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: 10.7,
                  top: 45.5,
                  child: SizedBox.square(
                    dimension: 18,
                    key: Key('settings-account-chevron'),
                    child: Center(child: AccountChevronRight()),
                  ),
                ),
                const Positioned(
                  left: 15,
                  right: 15,
                  bottom: 0,
                  child: Divider(
                    key: Key('settings-account-divider'),
                    color: AppColors.divider,
                    height: .5,
                    thickness: .5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.iconKind,
    required this.title,
    this.subtitle,
    this.notificationCount,
    this.showConnectedIndicator = false,
    this.height = 52,
    this.subtitleGap = 10.3,
    this.contentOffsetY = 0,
    this.iconOffsetY = 0,
    this.titleOffsetY = 0,
    this.titleScaleX = 1,
    this.titleScaleY = 1,
    this.subtitleOffsetY = 0,
    this.subtitleScaleX = 1,
    this.subtitleScaleY = 1,
    required this.onTap,
  });

  final _SettingsIconKind iconKind;
  final String title;
  final String? subtitle;
  final int? notificationCount;
  final bool showConnectedIndicator;
  final double height;
  final double subtitleGap;
  final double contentOffsetY;
  final double iconOffsetY;
  final double titleOffsetY;
  final double titleScaleX;
  final double titleScaleY;
  final double subtitleOffsetY;
  final double subtitleScaleX;
  final double subtitleScaleY;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = [
      title,
      ?subtitle,
      if (notificationCount case final count?) '$count thông báo',
      if (showConnectedIndicator) 'Đã kết nối',
    ].join(', ');

    return Semantics(
      key: ValueKey('settings-$title'),
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                const SizedBox(width: 15),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Transform.translate(
                      offset: Offset(0, iconOffsetY),
                      child: _SettingsIcon(
                        key: ValueKey('settings-icon-$title'),
                        kind: iconKind,
                      ),
                    ),
                    if (notificationCount != null)
                      Positioned(
                        right: -5,
                        top: -7.3 + iconOffsetY,
                        child: Container(
                          key: ValueKey('settings-notification-$title'),
                          width: 21,
                          height: 21,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE42D30),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$notificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'sans-serif',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.divider, width: .5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Transform.translate(
                            offset: Offset(-.6666666667, contentOffsetY),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Transform.translate(
                                  offset: Offset(0, titleOffsetY),
                                  child: Transform.scale(
                                    scaleX: titleScaleX,
                                    scaleY: titleScaleY,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontFamily: 'sans-serif',
                                        fontSize: 18.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  SizedBox(height: subtitleGap),
                                  Transform.translate(
                                    offset: Offset(0, subtitleOffsetY),
                                    child: Transform.scale(
                                      scaleX: subtitleScaleX,
                                      scaleY: subtitleScaleY,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        subtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontFamily: 'sans-serif',
                                          fontSize: 16,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (showConnectedIndicator)
                          const SizedBox(
                            key: Key('settings-connected-indicator'),
                            width: 29,
                            height: 29,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: SizedBox.square(
                                dimension: 28,
                                child: CustomPaint(
                                  key: Key('settings-connected-glyph'),
                                  painter: _ConnectedIndicatorPainter(),
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox.square(
                            dimension: 18,
                            key: Key('settings-row-chevron'),
                            child: Center(child: AccountChevronRight()),
                          ),
                        SizedBox(width: showConnectedIndicator ? 12.7 : 10.7),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SettingsIconKind {
  newAccount,
  mail,
  news,
  tradays,
  community,
  mql5,
  telegram,
  otp,
  language,
  candles,
  journal,
  settings,
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({super.key, required this.kind});

  final _SettingsIconKind kind;

  @override
  Widget build(BuildContext context) {
    final rasterKind = switch (kind) {
      _SettingsIconKind.newAccount => MtSettingsRasterIconKind.newAccount,
      _SettingsIconKind.mail => MtSettingsRasterIconKind.mail,
      _SettingsIconKind.news => MtSettingsRasterIconKind.news,
      _SettingsIconKind.tradays => MtSettingsRasterIconKind.tradays,
      _SettingsIconKind.community => MtSettingsRasterIconKind.messages,
      _SettingsIconKind.mql5 => MtSettingsRasterIconKind.community,
      _SettingsIconKind.telegram => MtSettingsRasterIconKind.telegram,
      _SettingsIconKind.otp => MtSettingsRasterIconKind.otp,
      _SettingsIconKind.language => MtSettingsRasterIconKind.interface,
      _SettingsIconKind.candles => MtSettingsRasterIconKind.charts,
      _SettingsIconKind.journal => MtSettingsRasterIconKind.journal,
      _SettingsIconKind.settings => MtSettingsRasterIconKind.about,
    };
    return SizedBox(
      width: 29,
      height: 29,
      child: Align(
        alignment: Alignment.topLeft,
        child: MtSettingsRasterIcon(rasterKind),
      ),
    );
  }
}

class _TelegramIconPainter extends CustomPainter {
  const _TelegramIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final plane = Path()
      ..moveTo(5.1, 13)
      ..lineTo(21, 5.8)
      ..lineTo(17.8, 21.4)
      ..lineTo(12.9, 16.5)
      ..lineTo(9.4, 19)
      ..lineTo(10.1, 15.1)
      ..close();
    canvas.drawPath(plane, Paint()..color = const Color(0xFFF8F8FA));

    final fold = Path()
      ..moveTo(10.1, 15.1)
      ..lineTo(19.5, 8)
      ..lineTo(12.9, 16.5)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0xFF2FA5E5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Kept as vector fallbacks for environments that disable raster decoding.
// ignore: unused_element
final List<CustomPainter> _settingsVectorFallbackPainters = [
  const _TelegramIconPainter(),
  const _NewAccountIconPainter(),
  const _MailIconPainter(),
  const _NewsIconPainter(),
  const _TradaysIconPainter(),
  const _CommunityIconPainter(),
  const _Mql5IconPainter(),
  const _OtpIconPainter(),
  const _LanguageIconPainter(),
  const _MetaTraderSettingsIconPainter(),
];

class _NewAccountIconPainter extends CustomPainter {
  const _NewAccountIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = const Color(0xFFF8F8FA);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(9.2, 12.7),
        width: 10.8,
        height: 13.2,
      ),
      white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7.1, 17.2, 4.2, 4.4),
        const Radius.circular(1),
      ),
      white,
    );

    final shoulders = Path()
      ..moveTo(1.4, 25.3)
      ..cubicTo(2.1, 21.8, 4.5, 19.6, 9.2, 19.6)
      ..cubicTo(13.8, 19.6, 16.5, 21.8, 17.1, 25.3)
      ..close();
    canvas.drawPath(shoulders, white);

    final plus = Paint()
      ..color = const Color(0xFFF8F8FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(18.2, 13.8), const Offset(24, 13.8), plus);
    canvas.drawLine(const Offset(21.1, 10.9), const Offset(21.1, 16.7), plus);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MailIconPainter extends CustomPainter {
  const _MailIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final envelope = RRect.fromRectAndRadius(
      const Rect.fromLTWH(6.5, 8.2, 16.2, 12),
      const Radius.circular(.7),
    );
    canvas.drawRRect(envelope, Paint()..color = const Color(0xFFF7F8F8));
    final fold = Paint()
      ..color = const Color(0xFF65BDD9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    final flap = Path()
      ..moveTo(6.8, 8.8)
      ..lineTo(14.5, 15)
      ..lineTo(22.3, 8.8);
    canvas.drawPath(flap, fold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NewsIconPainter extends CustomPainter {
  const _NewsIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(13.8333333333, 15.2);
    canvas.scale(.82, .9);
    canvas.translate(-14.5, -14.5);
    final page = Paint()
      ..color = const Color(0xFFF8F8F7)
      ..style = PaintingStyle.fill;
    final leftPage = Path()
      ..moveTo(4.8, 7)
      ..quadraticBezierTo(9.5, 6.6, 13.3, 9)
      ..lineTo(13.3, 22.1)
      ..quadraticBezierTo(9.4, 19.8, 4.8, 20.5)
      ..close();
    final rightPage = Path()
      ..moveTo(15.7, 9)
      ..quadraticBezierTo(19.6, 6.6, 24.2, 7)
      ..lineTo(24.2, 20.5)
      ..quadraticBezierTo(19.7, 19.8, 15.7, 22.1)
      ..close();
    canvas.drawPath(leftPage, page);
    canvas.drawPath(rightPage, page);

    final binding = Paint()
      ..color = const Color(0xFFF8F8F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bottom = Path()
      ..moveTo(4.1, 8.3)
      ..lineTo(4.1, 22)
      ..quadraticBezierTo(9.4, 21.4, 14.5, 24)
      ..quadraticBezierTo(19.6, 21.4, 24.9, 22)
      ..lineTo(24.9, 8.3);
    canvas.drawPath(bottom, binding);
    canvas.drawLine(const Offset(14.5, 8.9), const Offset(14.5, 22.9), binding);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TradaysIconPainter extends CustomPainter {
  const _TradaysIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(.88);
    canvas.rotate(-.34);
    canvas.translate(-size.width / 2, -size.height / 2);

    final outline = Paint()
      ..color = const Color(0xFFF8F8FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final back = Path()
      ..moveTo(7.2, 5.2)
      ..lineTo(22.4, 4.3)
      ..lineTo(24.4, 18.7)
      ..lineTo(20.3, 19.1);
    canvas.drawPath(back, outline);

    final front = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4.6, 8.2, 17.8, 15.8),
      const Radius.circular(.8),
    );
    canvas.drawRRect(front, outline);
    canvas.drawLine(const Offset(7.2, 12), const Offset(12.2, 12), outline);
    canvas.drawLine(const Offset(7.2, 14.8), const Offset(11.1, 14.8), outline);
    final chart = Path()
      ..moveTo(7.1, 21)
      ..lineTo(10.2, 17.4)
      ..lineTo(13.1, 19.1)
      ..lineTo(18.9, 12.9);
    canvas.drawPath(chart, outline);
    canvas.drawLine(const Offset(16.1, 13), const Offset(18.9, 12.9), outline);
    canvas.drawLine(
      const Offset(18.9, 12.9),
      const Offset(18.8, 15.7),
      outline,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CommunityIconPainter extends CustomPainter {
  const _CommunityIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(14.5, 11.8);
    canvas.scale(.84);
    canvas.translate(-14.5, -14.5);
    final white = Paint()..color = const Color(0xFFF8F8FA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4.6, 14.1, 4.5, 9.7),
        const Radius.circular(.7),
      ),
      white,
    );
    final hand = Path()
      ..moveTo(10.2, 23.8)
      ..lineTo(10.2, 13.5)
      ..cubicTo(12.3, 12.4, 14.1, 10.3, 14.9, 7.7)
      ..cubicTo(15.4, 6, 16.2, 4.5, 17.4, 4.5)
      ..cubicTo(19.2, 4.5, 20, 6.2, 19.4, 8.5)
      ..lineTo(18.8, 10.6)
      ..lineTo(23.2, 10.6)
      ..cubicTo(25.4, 10.6, 26, 12.2, 25.2, 14.2)
      ..lineTo(22.7, 21)
      ..cubicTo(22.1, 22.8, 20.8, 23.8, 18.7, 23.8)
      ..close();
    canvas.drawPath(hand, white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Mql5IconPainter extends CustomPainter {
  const _Mql5IconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: const TextSpan(
        style: TextStyle(
          fontFamily: 'sans-serif-condensed',
          fontSize: 10.2,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: -.45,
        ),
        children: [
          TextSpan(
            text: 'MQL',
            style: TextStyle(color: Color(0xFFF8F8FA)),
          ),
          TextSpan(
            text: '5',
            style: TextStyle(color: Color(0xFFF4D237)),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2 + .3,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OtpIconPainter extends CustomPainter {
  const _OtpIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = const Color(0xFFF8F8FA);
    canvas.drawCircle(const Offset(14.5, 9.8), 3.8, white);
    final stem = Path()
      ..moveTo(12.4, 12.2)
      ..lineTo(16.6, 12.2)
      ..lineTo(16.4, 21.3)
      ..lineTo(12.6, 21.3)
      ..close();
    canvas.drawPath(stem, white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LanguageIconPainter extends CustomPainter {
  const _LanguageIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grayPanel = Path()
      ..moveTo(11.5, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(17, size.height)
      ..close();
    canvas.drawPath(grayPanel, Paint()..color = const Color(0xFFC6C9CF));

    _paintGlyph(
      canvas,
      const TextSpan(
        text: 'A',
        style: TextStyle(
          color: Color(0xFFEAF4FB),
          fontFamily: 'sans-serif',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
      const Offset(4.2, 7.7),
    );

    final glyph = Paint()
      ..color = const Color(0xFF34434A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(21.1, 7.8), const Offset(21.1, 9.4), glyph);
    canvas.drawLine(const Offset(16.5, 11), const Offset(25.6, 11), glyph);
    final leftSweep = Path()
      ..moveTo(18, 13.4)
      ..quadraticBezierTo(19.5, 18.1, 25.1, 22.9);
    final rightSweep = Path()
      ..moveTo(24.4, 13.4)
      ..quadraticBezierTo(22.8, 18.7, 17, 23.3);
    canvas.drawPath(leftSweep, glyph);
    canvas.drawPath(rightSweep, glyph);
  }

  void _paintGlyph(Canvas canvas, TextSpan span, Offset offset) {
    final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConnectedIndicatorPainter extends CustomPainter {
  const _ConnectedIndicatorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 - .6666666667, size.height / 2);
    final bounds = Rect.fromCircle(center: center, radius: 13.3333333333);
    canvas.drawCircle(
      center,
      13.3333333333,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.connectedIndicatorTop,
            AppColors.connectedIndicatorBottom,
          ],
        ).createShader(bounds),
    );

    final line = Paint()
      ..color = AppColors.connectedIndicatorGlyph
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-7.2, -4.1),
      center.translate(6.9, -2.5),
      line,
    );
    canvas.drawLine(
      center.translate(-6.1, -.2),
      center.translate(5.4, .8),
      line,
    );
    canvas.drawLine(
      center.translate(-4.8, 3.6),
      center.translate(3.7, 4.2),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetaTraderSettingsIconPainter extends CustomPainter {
  const _MetaTraderSettingsIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - .5);
    final globe = Paint()
      ..color = const Color(0xFFEAF7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, 8.3, globe);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 7, height: 16.2),
      globe..strokeWidth = .75,
    );
    canvas.drawLine(
      Offset(center.dx - 7.8, center.dy),
      Offset(center.dx + 7.8, center.dy),
      globe,
    );
    canvas.drawCircle(
      center.translate(-3.2, -2.3),
      2.4,
      Paint()..color = const Color(0xFF49B96E),
    );
    canvas.drawCircle(
      center.translate(3.8, 2.2),
      2.7,
      Paint()..color = const Color(0xFF49B96E),
    );
    final tower = Path()
      ..moveTo(center.dx - 4, center.dy + 8)
      ..lineTo(center.dx, center.dy + 2)
      ..lineTo(center.dx + 4, center.dy + 8)
      ..close();
    canvas.drawPath(tower, Paint()..color = const Color(0xFFF0C84B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
