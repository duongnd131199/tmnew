import 'package:flutter/material.dart';
import 'package:trading_mobile/features/account_link/presentation/theme/account_link_reference_theme.dart';
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
    height: AccountLinkReferenceMetrics.toolbarHeight,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: AccountLinkReferenceMetrics.toolbarTitleTop,
          child: IgnorePointer(
            child: Center(
              child: Text(
                title,
                key: const Key('account-link-toolbar-title'),
                textAlign: TextAlign.center,
                style: AccountLinkReferenceTypography.toolbarTitle,
              ),
            ),
          ),
        ),
        Positioned(
          left: AccountLinkReferenceMetrics.horizontalInset,
          top: AccountLinkReferenceMetrics.toolbarControlTop,
          child: AccountLinkToolbarButton(
            action: AccountLinkToolbarAction.back,
            onTap: onBack,
          ),
        ),
        if (trailing case final action?)
          Positioned(
            right: AccountLinkReferenceMetrics.horizontalInset,
            top: AccountLinkReferenceMetrics.toolbarControlTop,
            child: action,
          ),
      ],
    ),
  );
}
