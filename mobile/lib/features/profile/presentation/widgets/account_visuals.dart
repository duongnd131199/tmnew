import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/features/profile/domain/account_presentation_profile.dart';

abstract final class AccountVisualMetrics {
  static const brokerMark = 31.0;
  static const heroBrokerMark = 60.0;
  static const toolbarHitTarget = 43.0;
  static const chevron = Size(10, 14);
}

class AccountBrokerMark extends StatelessWidget {
  const AccountBrokerMark({
    required this.brand,
    this.size = AccountVisualMetrics.brokerMark,
    super.key = const Key('account-broker-mark'),
  });

  final DemoBrokerBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ExcludeSemantics(
        child: switch (brand) {
          DemoBrokerBrand.exness => ColoredBox(
            color: AppColors.brokerExness,
            child: Center(
              child: Text(
                'exness',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: AppColors.brokerMarkInk,
                  fontFamily: 'sans-serif',
                  fontSize: size * .226,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
          DemoBrokerBrand.yodo => const ColoredBox(color: AppColors.brokerYodo),
          DemoBrokerBrand.vantage => CustomPaint(
            painter: const _VantageLogoPainter(),
          ),
          DemoBrokerBrand.metaquotes => MetaquotesBrokerMark(size: size),
          DemoBrokerBrand.unknown => ColoredBox(
            color: AppColors.surfaceElevated,
            child: Center(
              child: Icon(
                Icons.account_balance_outlined,
                color: AppColors.textSecondary,
                size: size * .58,
              ),
            ),
          ),
        },
      ),
    );
  }
}

class MetaquotesBrokerMark extends StatelessWidget {
  const MetaquotesBrokerMark({
    this.size = AccountVisualMetrics.brokerMark,
    super.key = const Key('metaquotes-broker-mark-raster'),
  });

  static const _assetPath = 'assets/images/metatrader5_splash.png';
  static const _sourceSize = Size(720, 520);
  static const _sourceCrop = Rect.fromLTWH(170, 0, 380, 370);
  final double size;

  @override
  Widget build(BuildContext context) {
    final unitScale = size / AccountVisualMetrics.brokerMark;
    final renderedSize = (82 / 3) * unitScale;
    final imageScale = renderedSize / _sourceCrop.width;
    final scaledSourceSize = Size(
      _sourceSize.width * imageScale,
      _sourceSize.height * imageScale,
    );
    final verticalOffset = (renderedSize - _sourceCrop.height * imageScale) / 2;

    return Transform.translate(
      offset: Offset((-2 / 3) * unitScale, (2 / 3) * unitScale),
      child: Center(
        child: SizedBox.square(
          dimension: renderedSize,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: scaledSourceSize.width,
              maxWidth: scaledSourceSize.width,
              minHeight: scaledSourceSize.height,
              maxHeight: scaledSourceSize.height,
              child: Transform.translate(
                offset: Offset(-_sourceCrop.left * imageScale, verticalOffset),
                child: Image.asset(
                  _assetPath,
                  width: scaledSourceSize.width,
                  height: scaledSourceSize.height,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountRoundBackButton extends StatelessWidget {
  const AccountRoundBackButton({
    required this.onTap,
    super.key = const Key('account-round-back-button'),
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const CircleBorder(
      side: BorderSide(color: AppColors.divider, width: .6),
    ),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: const SizedBox.square(
        dimension: AccountVisualMetrics.toolbarHitTarget,
        child: Center(
          child: CustomPaint(
            key: Key('account-back-glyph'),
            size: Size.square(24),
            painter: _BackIconPainter(),
          ),
        ),
      ),
    ),
  );
}

class AccountRoundAddButton extends StatelessWidget {
  const AccountRoundAddButton({
    required this.onTap,
    super.key = const Key('account-round-add-button'),
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const CircleBorder(
      side: BorderSide(color: AppColors.divider, width: .6),
    ),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: const SizedBox.square(
        dimension: AccountVisualMetrics.toolbarHitTarget,
        child: Center(
          child: CustomPaint(
            key: Key('account-add-glyph'),
            size: Size.square(24),
            painter: _AddIconPainter(),
          ),
        ),
      ),
    ),
  );
}

class AccountChevronRight extends StatelessWidget {
  const AccountChevronRight({super.key = const Key('account-chevron-glyph')});

  @override
  Widget build(BuildContext context) => const CustomPaint(
    size: AccountVisualMetrics.chevron,
    painter: _ChevronRightPainter(),
  );
}

class _BackIconPainter extends CustomPainter {
  const _BackIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(14.7, 4.5)
      ..lineTo(6.3, 12)
      ..lineTo(14.7, 20.3);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AddIconPainter extends CustomPainter {
  const _AddIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.28
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4.4, 12), const Offset(19.6, 12), paint);
    canvas.drawLine(const Offset(12, 4.4), const Offset(12, 19.6), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChevronRightPainter extends CustomPainter {
  const _ChevronRightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(1.8, 2)
      ..lineTo(6.8, 7)
      ..lineTo(1.8, 12);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.textTertiary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VantageLogoPainter extends CustomPainter {
  const _VantageLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.brokerVantage,
    );
    canvas.save();
    canvas.scale(size.width / 31, size.height / 31);
    canvas.translate(15.5, 15.5);
    canvas.scale(.75);
    canvas.translate(-15.5, -15.5);
    final white = Paint()..color = AppColors.textPrimary;
    final red = Paint()..color = AppColors.negative;
    canvas.drawPath(
      Path()
        ..moveTo(7, 7)
        ..lineTo(13.7, 7)
        ..lineTo(20.3, 24)
        ..lineTo(16.2, 24)
        ..close(),
      white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(14.7, 7)
        ..lineTo(24, 7)
        ..lineTo(20.3, 17.5)
        ..close(),
      red,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
