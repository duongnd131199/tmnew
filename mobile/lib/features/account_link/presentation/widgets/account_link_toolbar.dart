import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/account_link_visuals.dart';

class AccountLinkToolbar extends StatelessWidget {
  const AccountLinkToolbar({
    required this.title,
    required this.onBack,
    this.trailing,
    super.key = const Key('account-link-toolbar'),
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 81,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 49,
          child: IgnorePointer(
            child: Center(
              child: Text(
                title,
                key: const Key('account-link-toolbar-title'),
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.md,
          top: 37,
          child: AccountLinkToolbarButton(
            action: AccountLinkToolbarAction.back,
            onTap: onBack,
          ),
        ),
        if (trailing case final action?)
          Positioned(right: AppSpacing.md, top: 37, child: action),
      ],
    ),
  );
}
