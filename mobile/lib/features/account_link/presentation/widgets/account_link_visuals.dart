import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_icons.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/profile/presentation/widgets/account_visuals.dart';

enum AccountLinkToolbarAction { back, qr }

class AccountLinkToolbarButton extends StatelessWidget {
  const AccountLinkToolbarButton({
    required this.action,
    required this.onTap,
    super.key,
  });

  final AccountLinkToolbarAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => switch (action) {
    AccountLinkToolbarAction.back => KeyedSubtree(
      key: const Key('account-link-back-button'),
      child: AccountRoundBackButton(onTap: onTap),
    ),
    AccountLinkToolbarAction.qr => Material(
      key: const Key('account-link-qr-button'),
      color: AppColors.surface,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.divider, width: .6),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox.square(
          dimension: AccountVisualMetrics.toolbarHitTarget,
          child: Icon(
            Icons.qr_code_2_rounded,
            color: AppColors.textPrimary,
            size: AppIconSizes.medium,
          ),
        ),
      ),
    ),
  };
}

class AccountLinkBrokerMark extends StatelessWidget {
  const AccountLinkBrokerMark({
    required this.broker,
    this.displayAsExness = false,
    super.key,
  });

  final MobileBroker broker;
  final bool displayAsExness;

  @override
  Widget build(BuildContext context) {
    final identity = '${broker.name} ${broker.companyName ?? ''}'.toLowerCase();
    if (displayAsExness || identity.contains('exness')) {
      return SizedBox.square(
        key: ValueKey('broker-mark-${broker.id}'),
        dimension: AccountVisualMetrics.brokerMark,
        child: ColoredBox(
          color: AppColors.brokerExness,
          child: Center(
            child: Text(
              displayAsExness ? 'exness' : 'EX',
              textScaler: TextScaler.noScaling,
              style: AppTypography.caption.copyWith(
                color: AppColors.brokerMarkInk,
                fontFamily: displayAsExness ? 'sans-serif' : null,
                fontSize: displayAsExness ? 7 : null,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      );
    }
    if (identity.contains('metaquotes')) {
      return SizedBox.square(
        key: ValueKey('broker-mark-${broker.id}'),
        dimension: AccountVisualMetrics.brokerMark,
        child: const CustomPaint(painter: _ConnectedMarketMarkPainter()),
      );
    }
    return SizedBox.square(
      key: ValueKey('broker-mark-${broker.id}'),
      dimension: AccountVisualMetrics.brokerMark,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            broker.name.characters.first.toUpperCase(),
            textScaler: TextScaler.noScaling,
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class AccountLinkInfoButton extends StatelessWidget {
  const AccountLinkInfoButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    iconSize: AppIconSizes.medium,
    splashRadius: AccountVisualMetrics.brokerMark,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(
      width: AccountVisualMetrics.toolbarHitTarget,
      height: AccountVisualMetrics.toolbarHitTarget,
    ),
    icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
  );
}

class _ConnectedMarketMarkPainter extends CustomPainter {
  const _ConnectedMarketMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final nodes = <Offset>[
      Offset(size.width * .25, size.height * .68),
      Offset(size.width * .42, size.height * .24),
      Offset(size.width * .76, size.height * .38),
      Offset(size.width * .72, size.height * .76),
    ];
    final line = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final node in nodes) {
      canvas.drawLine(center, node, line);
    }
    canvas.drawCircle(
      center,
      size.width * .17,
      Paint()..color = AppColors.primary,
    );
    for (final node in nodes) {
      canvas.drawCircle(
        node,
        size.width * .11,
        Paint()..color = AppColors.positive,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
