import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';

enum MtToolbarIconKind {
  menu,
  add,
  edit,
  swap,
  newOrder,
  exchange,
  currencyExchange,
  calendar,
  search,
  more,
}

class MtToolbarIcon extends StatelessWidget {
  const MtToolbarIcon(
    this.kind, {
    this.color = AppColors.navigationUnselected,
    this.size = 24,
    super.key,
  });

  final MtToolbarIconKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MtToolbarIconPainter(kind, color),
  );
}

class MtHistoryClockIcon extends StatelessWidget {
  const MtHistoryClockIcon({
    required this.color,
    this.size = 24,
    this.selected = false,
    super.key,
  });

  final Color color;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: MtHistoryClockIconPainter(color: color, selected: selected),
  );
}

class MtHistoryClockIconPainter extends CustomPainter {
  const MtHistoryClockIconPainter({
    required this.color,
    required this.selected,
  });

  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    void paintLayer(double strokeWidth, Color layerColor) {
      final stroke = Paint()
        ..color = layerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final fill = Paint()
        ..color = layerColor
        ..style = PaintingStyle.fill;
      paintMtHistoryClockLayer(
        canvas,
        stroke: stroke,
        fill: fill,
        selected: selected,
      );
    }

    canvas.save();
    canvas.scale(size.width / 27, size.height / 27);
    paintLayer(2.78, color.withValues(alpha: .565));
    paintLayer(1.15, color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MtHistoryClockIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.selected != selected;
}

void paintMtHistoryClockLayer(
  Canvas canvas, {
  required Paint stroke,
  required Paint fill,
  required bool selected,
}) {
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(13.75, 13.25), radius: 9.75),
    math.pi * .9777777778,
    math.pi * 1.7611111111,
    false,
    stroke,
  );
  final arrow = Path()
    ..moveTo(2.25, 13.3)
    ..lineTo(5, 11.05)
    ..lineTo(selected ? 4 : 4.75, selected ? 14.5 : 15.05)
    ..close();
  canvas.drawPath(arrow, fill);
  canvas.drawLine(
    const Offset(13.85, 14.25),
    const Offset(13.85, 9.55),
    stroke,
  );
  canvas.drawLine(
    const Offset(13.85, 14.25),
    const Offset(17.25, 17.95),
    stroke,
  );
}

class _MtToolbarIconPainter extends CustomPainter {
  const _MtToolbarIconPainter(this.kind, this.color);

  final MtToolbarIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.15
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case MtToolbarIconKind.menu:
        p
          ..color = color
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.square;
        for (final y in const [7.0, 12.0, 17.0]) {
          canvas.drawLine(Offset(4, y), Offset(20, y), p);
        }
      case MtToolbarIconKind.add:
        canvas.drawLine(const Offset(12, 2.5), const Offset(12, 21.5), p);
        canvas.drawLine(const Offset(2.5, 12), const Offset(21.5, 12), p);
      case MtToolbarIconKind.edit:
        // The recorded pencil has a detached eraser, two fine body rails and
        // a hollow graphite tip. Coordinates are aligned to its 1.5x raster.
        final pencil = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawLine(
          const Offset(4.19, 16.04),
          const Offset(13.79, 6.44),
          pencil,
        );
        canvas.drawLine(
          const Offset(8.14, 20.19),
          const Offset(17.89, 10.44),
          pencil,
        );

        final eraser = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        final eraserPath = Path()
          ..moveTo(17.1, 1.33)
          ..quadraticBezierTo(17.8, .58, 18.6, 1.33)
          ..lineTo(22.15, 5.23)
          ..quadraticBezierTo(23.05, 6.13, 22.15, 7.23)
          ..lineTo(20.46, 9.65)
          ..lineTo(15.41, 3.87)
          ..close();
        canvas.drawPath(eraserPath, eraser);

        final graphite = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.miter;
        final tip = Path()
          ..moveTo(4.19, 16.04)
          ..lineTo(8.14, 20.19)
          ..lineTo(3.73, 21.16)
          ..close();
        canvas.drawPath(tip, graphite);
      case MtToolbarIconKind.swap:
        canvas.drawLine(const Offset(8, 21.5), const Offset(8, 3), p);
        canvas.drawLine(const Offset(8, 3), const Offset(3.5, 7.5), p);
        canvas.drawLine(const Offset(8, 3), const Offset(12.5, 7.5), p);
        canvas.drawLine(const Offset(16, 2.5), const Offset(16, 21), p);
        canvas.drawLine(const Offset(16, 21), const Offset(11.5, 16.5), p);
        canvas.drawLine(const Offset(16, 21), const Offset(20.5, 16.5), p);
      case MtToolbarIconKind.newOrder:
        final doc = Path()
          ..moveTo(4, 1.5)
          ..lineTo(15.5, 1.5)
          ..lineTo(21, 7)
          ..lineTo(21, 22.5)
          ..lineTo(4, 22.5)
          ..close()
          ..moveTo(15.5, 1.5)
          ..lineTo(15.5, 7)
          ..lineTo(21, 7);
        canvas.drawPath(doc, p);
        canvas.drawLine(const Offset(8, 14), const Offset(17, 14), p);
        canvas.drawLine(const Offset(12.5, 9.5), const Offset(12.5, 18.5), p);
      case MtToolbarIconKind.exchange:
        p.strokeCap = StrokeCap.round;
        canvas.drawArc(
          const Rect.fromLTWH(2, 2, 20, 20),
          -.2,
          math.pi * .92,
          false,
          p,
        );
        canvas.drawArc(
          const Rect.fromLTWH(2, 2, 20, 20),
          math.pi * .8,
          math.pi * .92,
          false,
          p,
        );
        canvas.drawLine(const Offset(21.2, 5.2), const Offset(21.2, 10), p);
        canvas.drawLine(const Offset(21.2, 5.2), const Offset(16.4, 5.2), p);
        canvas.drawLine(const Offset(2.8, 18.8), const Offset(2.8, 14), p);
        canvas.drawLine(const Offset(2.8, 18.8), const Offset(7.6, 18.8), p);
        final tp = TextPainter(
          text: TextSpan(
            text: r'$',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(12 - tp.width / 2, 12 - tp.height / 2));
      case MtToolbarIconKind.currencyExchange:
        p
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.05;
        canvas.drawArc(
          const Rect.fromLTWH(2.5, 2.5, 19, 19),
          -math.pi * .13,
          math.pi * 1.03,
          false,
          p,
        );
        canvas.drawArc(
          const Rect.fromLTWH(2.5, 2.5, 19, 19),
          math.pi * .87,
          math.pi * 1.03,
          false,
          p,
        );
        canvas.drawLine(const Offset(21.2, 5.0), const Offset(21.2, 9.2), p);
        canvas.drawLine(const Offset(21.2, 5.0), const Offset(17.0, 5.0), p);
        canvas.drawLine(const Offset(2.8, 19.0), const Offset(2.8, 14.8), p);
        canvas.drawLine(const Offset(2.8, 19.0), const Offset(7.0, 19.0), p);
        final money = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final dollar = Path()
          ..moveTo(15.5, 8.2)
          ..cubicTo(14.7, 7.1, 9.3, 6.8, 9.0, 9.6)
          ..cubicTo(8.8, 11.8, 15.3, 11.0, 15.1, 14.2)
          ..cubicTo(14.9, 17.0, 9.3, 16.6, 8.4, 15.2);
        canvas.drawPath(dollar, money);
        canvas.drawLine(const Offset(12, 5.5), const Offset(12, 18.1), money);
      case MtToolbarIconKind.calendar:
        p.strokeCap = StrokeCap.round;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 4, 20, 18),
            const Radius.circular(1.5),
          ),
          p,
        );
        canvas.drawLine(const Offset(2, 9), const Offset(22, 9), p);
        canvas.drawLine(const Offset(7, 1.5), const Offset(7, 6.5), p);
        canvas.drawLine(const Offset(17, 1.5), const Offset(17, 6.5), p);
        p.style = PaintingStyle.fill;
        for (final y in const [12.0, 15.7, 19.4]) {
          for (final x in const [5.6, 10.0, 14.4, 18.8]) {
            canvas.drawRect(
              Rect.fromCenter(center: Offset(x, y), width: 1.9, height: 1.9),
              p,
            );
          }
        }
      case MtToolbarIconKind.search:
        p.strokeCap = StrokeCap.round;
        canvas.drawCircle(const Offset(10, 10), 7.2, p);
        canvas.drawLine(const Offset(15.4, 15.4), const Offset(22, 22), p);
      case MtToolbarIconKind.more:
        p.style = PaintingStyle.fill;
        for (final x in const [5.0, 12.0, 19.0]) {
          canvas.drawCircle(Offset(x, 12), 1.75, p);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MtToolbarIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
