import 'package:flutter/material.dart';

enum MtSettingsIconKind {
  newAccount,
  mail,
  news,
  tradays,
  messages,
  community,
  telegram,
  otp,
  interface,
  charts,
  journal,
  about,
}

class MtSettingsIcon extends StatelessWidget {
  const MtSettingsIcon(this.kind, {this.size = 29, super.key});

  final MtSettingsIconKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * .225);
    final icon = DecoratedBox(
      decoration: BoxDecoration(
        color: _backgroundColor(kind),
        borderRadius: radius,
      ),
      child: Center(child: _glyph(kind, size)),
    );

    return SizedBox.square(
      dimension: size,
      child: kind == MtSettingsIconKind.interface
          ? ClipRRect(borderRadius: radius, child: icon)
          : icon,
    );
  }
}

Color _backgroundColor(MtSettingsIconKind kind) => switch (kind) {
  MtSettingsIconKind.newAccount => const Color(0xFF4BCF1C),
  MtSettingsIconKind.mail => const Color(0xFF52C9FA),
  MtSettingsIconKind.news => const Color(0xFFFBA526),
  MtSettingsIconKind.tradays => const Color(0xFFD62F2E),
  MtSettingsIconKind.messages => const Color(0xFF4D7DC4),
  MtSettingsIconKind.community => const Color(0xFF3474DE),
  MtSettingsIconKind.telegram => const Color(0xFF2BA9F8),
  MtSettingsIconKind.otp => const Color(0xFF4CDA64),
  MtSettingsIconKind.interface => const Color(0xFF169FFF),
  MtSettingsIconKind.charts => const Color(0xFF179BFA),
  MtSettingsIconKind.journal => const Color(0xFFBEC4D0),
  MtSettingsIconKind.about => const Color(0xFFB6DDF1),
};

Widget _glyph(MtSettingsIconKind kind, double size) => switch (kind) {
  MtSettingsIconKind.newAccount => CustomPaint(
    size: Size.square(size),
    painter: const _NewAccountPainter(),
  ),
  MtSettingsIconKind.mail => CustomPaint(
    size: Size.square(size),
    painter: const _MailPainter(),
  ),
  MtSettingsIconKind.news => CustomPaint(
    size: Size.square(size),
    painter: const _NewsPainter(),
  ),
  MtSettingsIconKind.tradays => CustomPaint(
    size: Size.square(size),
    painter: const _TradaysPainter(),
  ),
  MtSettingsIconKind.messages => CustomPaint(
    size: Size.square(size),
    painter: const _MessagesPainter(),
  ),
  MtSettingsIconKind.community => CustomPaint(
    size: Size.square(size),
    painter: const _CommunityPainter(),
  ),
  MtSettingsIconKind.telegram => CustomPaint(
    size: Size.square(size),
    painter: const _TelegramPainter(),
  ),
  MtSettingsIconKind.otp => CustomPaint(
    size: Size.square(size),
    painter: const _OtpPainter(),
  ),
  MtSettingsIconKind.interface => _InterfaceGlyph(size: size),
  MtSettingsIconKind.charts => CustomPaint(
    size: Size.square(size),
    painter: const _CandlesPainter(),
  ),
  MtSettingsIconKind.journal => CustomPaint(
    size: Size.square(size),
    painter: const _JournalPainter(),
  ),
  MtSettingsIconKind.about => Image.asset(
    'assets/images/metatrader5_settings_menu.png',
    width: size,
    height: size,
    fit: BoxFit.fill,
    filterQuality: FilterQuality.high,
    isAntiAlias: true,
  ),
};

const _settingsGlyphColor = Color(0xFFF8F8FA);

class _NewAccountPainter extends CustomPainter {
  const _NewAccountPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = _settingsGlyphColor;
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
      ..color = _settingsGlyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(18.2, 13.8), const Offset(24, 13.8), plus);
    canvas.drawLine(const Offset(21.1, 10.9), const Offset(21.1, 16.7), plus);
  }

  @override
  bool shouldRepaint(covariant _NewAccountPainter oldDelegate) => false;
}

class _MailPainter extends CustomPainter {
  const _MailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final envelope = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5.3, 7.7, 18.4, 13.6),
      const Radius.circular(.8),
    );
    canvas.drawRRect(envelope, Paint()..color = _settingsGlyphColor);
    final fold = Paint()
      ..color = const Color(0xFF52C9FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    final flap = Path()
      ..moveTo(5.8, 8.4)
      ..lineTo(14.5, 15.1)
      ..lineTo(23.2, 8.4);
    canvas.drawPath(flap, fold);
  }

  @override
  bool shouldRepaint(covariant _MailPainter oldDelegate) => false;
}

class _NewsPainter extends CustomPainter {
  const _NewsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(13.8333333333, 15.2);
    canvas.scale(.82, .9);
    canvas.translate(-14.5, -14.5);
    final page = Paint()..color = _settingsGlyphColor;
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
      ..color = _settingsGlyphColor
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
  bool shouldRepaint(covariant _NewsPainter oldDelegate) => false;
}

class _TradaysPainter extends CustomPainter {
  const _TradaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(.88);
    canvas.rotate(-.34);
    canvas.translate(-size.width / 2, -size.height / 2);
    final outline = Paint()
      ..color = _settingsGlyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // The reference glyph is a folded desk calendar. Its rear stand is drawn
    // first so the narrower front face can overlap it cleanly.
    final stand = Path()
      ..moveTo(9, 10)
      ..lineTo(2.3, 19.8)
      ..lineTo(9, 21.8);
    canvas.drawPath(stand, outline);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 10, 15.4, 14.8),
        const Radius.circular(.55),
      ),
      outline,
    );

    // Keep the calendar rail separate from the top edge and binding loops.
    canvas.drawLine(
      const Offset(9.35, 13.35),
      const Offset(24.05, 13.35),
      outline,
    );

    final binding = Paint()
      ..color = _settingsGlyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    for (final x in const [12.9, 22.4]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 1.35, 6.3, 2.7, 5.5),
          const Radius.circular(1.25),
        ),
        binding,
      );
    }

    final wick = Paint()
      ..color = _settingsGlyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(11.9, 14.5), const Offset(11.9, 22.2), wick);
    canvas.drawLine(const Offset(16.2, 13), const Offset(16.2, 22.7), wick);
    canvas.drawLine(const Offset(20, 12.3), const Offset(20, 22.4), wick);

    final candleOutline = Paint()
      ..color = _settingsGlyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(10.55, 16.1, 13.25, 20.6),
        const Radius.circular(.25),
      ),
      candleOutline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(14.75, 14.7, 17.65, 20.8),
        const Radius.circular(.25),
      ),
      Paint()..color = _settingsGlyphColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(18.65, 14.1, 21.35, 18.5),
        const Radius.circular(.25),
      ),
      candleOutline,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TradaysPainter oldDelegate) => false;
}

class _MessagesPainter extends CustomPainter {
  const _MessagesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(14.5, 11.8);
    canvas.scale(.84);
    canvas.translate(-14.5, -14.5);
    final white = Paint()..color = _settingsGlyphColor;
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
  bool shouldRepaint(covariant _MessagesPainter oldDelegate) => false;
}

class _CommunityPainter extends CustomPainter {
  const _CommunityPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()
      ..color = _settingsGlyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round;

    final m = Path()
      ..moveTo(3.2, 18.5)
      ..lineTo(3.2, 10.7)
      ..lineTo(6.1, 15.2)
      ..lineTo(9, 10.7)
      ..lineTo(9, 18.5);
    canvas.drawPath(m, white);

    canvas.drawOval(const Rect.fromLTWH(10.4, 10.8, 5.7, 7.5), white);
    canvas.drawLine(const Offset(14.2, 16.4), const Offset(16.3, 18.7), white);

    final l = Path()
      ..moveTo(17.6, 10.7)
      ..lineTo(17.6, 18.5)
      ..lineTo(20.7, 18.5);
    canvas.drawPath(l, white);

    final fiveTop = Paint()
      ..color = const Color(0xFFF6D52F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fiveBottom = Paint()
      ..color = const Color(0xFFF0A733)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final five = Path()
      ..moveTo(25.4, 10.9)
      ..lineTo(21.8, 10.9)
      ..lineTo(21.5, 14.4)
      ..quadraticBezierTo(23.3, 13.7, 24.5, 14.7);
    canvas.drawPath(five, fiveTop);
    final fiveCurve = Path()
      ..moveTo(24.5, 14.7)
      ..quadraticBezierTo(26.1, 16.7, 24.4, 18.3)
      ..quadraticBezierTo(22.7, 19.5, 21.2, 18.2);
    canvas.drawPath(fiveCurve, fiveBottom);
  }

  @override
  bool shouldRepaint(covariant _CommunityPainter oldDelegate) => false;
}

class _TelegramPainter extends CustomPainter {
  const _TelegramPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final plane = Path()
      ..moveTo(5.1, 13)
      ..lineTo(23.1, 5.6)
      ..lineTo(18.8, 22.4)
      ..lineTo(12.9, 16.5)
      ..lineTo(9.4, 19)
      ..lineTo(10.1, 15.1)
      ..close();
    canvas.drawPath(plane, Paint()..color = _settingsGlyphColor);
    final fold = Path()
      ..moveTo(10.1, 15.1)
      ..lineTo(21.4, 7.7)
      ..lineTo(12.9, 16.5)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0xFF2BA9F8));
  }

  @override
  bool shouldRepaint(covariant _TelegramPainter oldDelegate) => false;
}

class _OtpPainter extends CustomPainter {
  const _OtpPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = _settingsGlyphColor;
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
  bool shouldRepaint(covariant _OtpPainter oldDelegate) => false;
}

class _InterfaceGlyph extends StatelessWidget {
  const _InterfaceGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _InterfacePanelPainter()),
          ),
          const Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'A',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: _settingsGlyphColor,
                        fontFamily: 'Mt5Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '文',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: Color(0xFF34434A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InterfacePanelPainter extends CustomPainter {
  const _InterfacePanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grayPanel = Path()
      ..moveTo(11.5, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(17, size.height)
      ..close();
    canvas.drawPath(grayPanel, Paint()..color = const Color(0xFFD2DBE2));
  }

  @override
  bool shouldRepaint(covariant _InterfacePanelPainter oldDelegate) => false;
}

class _CandlesPainter extends CustomPainter {
  const _CandlesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 29, size.height / 29);
    final line = Paint()
      ..color = _settingsGlyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(10.7, 8), const Offset(10.7, 11), line);
    canvas.drawLine(const Offset(10.7, 19.75), const Offset(10.7, 23), line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 11, 5.25, 8.75),
        const Radius.circular(.6),
      ),
      line,
    );
    canvas.drawLine(const Offset(20.2, 5.4), const Offset(20.2, 18.7), line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16.7, 7.8, 6.8, 9.8),
        const Radius.circular(.6),
      ),
      Paint()..color = _settingsGlyphColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CandlesPainter oldDelegate) => false;
}

class _JournalPainter extends CustomPainter {
  const _JournalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _settingsGlyphColor
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(6.7, 7.3), const Offset(22.3, 7.3), line);
    canvas.drawLine(const Offset(6.7, 11.9), const Offset(22.3, 11.9), line);
    canvas.drawLine(const Offset(6.7, 16.5), const Offset(20.3, 16.5), line);
    canvas.drawLine(const Offset(6.7, 21.1), const Offset(17.7, 21.1), line);
  }

  @override
  bool shouldRepaint(covariant _JournalPainter oldDelegate) => false;
}
