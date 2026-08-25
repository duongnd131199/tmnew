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
        child: const MetaquotesBrokerMark(),
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
