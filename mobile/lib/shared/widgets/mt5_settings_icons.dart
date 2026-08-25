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
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _backgroundColor(kind),
        borderRadius: BorderRadius.circular(size * .225),
      ),
      child: Center(child: _glyph(kind, size)),
    ),
  );
}

Color _backgroundColor(MtSettingsIconKind kind) => switch (kind) {
  MtSettingsIconKind.newAccount => const Color(0xFF35D04F),
  MtSettingsIconKind.mail => const Color(0xFF43BBDD),
  MtSettingsIconKind.news => const Color(0xFFFF951D),
  MtSettingsIconKind.tradays => const Color(0xFFE72E55),
  MtSettingsIconKind.messages => const Color(0xFF4A73CC),
  MtSettingsIconKind.community => const Color(0xFF466DD0),
  MtSettingsIconKind.telegram => const Color(0xFF2AA9D6),
  MtSettingsIconKind.otp => const Color(0xFF35D75A),
  MtSettingsIconKind.interface => const Color(0xFF389FE1),
  MtSettingsIconKind.charts => const Color(0xFF2E9EE3),
  MtSettingsIconKind.journal => const Color(0xFF9095A5),
  MtSettingsIconKind.about => const Color(0xFF55A56C),
};

Widget _glyph(MtSettingsIconKind kind, double size) => switch (kind) {
  MtSettingsIconKind.newAccount => CustomPaint(
    size: Size.square(size),
    painter: const _NewAccountPainter(),
  ),
  MtSettingsIconKind.mail => Icon(
    Icons.mail_outline_rounded,
    size: size * .7,
    color: Colors.white,
  ),
  MtSettingsIconKind.news => Icon(
    Icons.menu_book_rounded,
    size: size * .68,
    color: Colors.white,
  ),
  MtSettingsIconKind.tradays => Transform.rotate(
    angle: -.13,
    child: Icon(
      Icons.confirmation_number_rounded,
      size: size * .67,
      color: Colors.white,
    ),
  ),
  MtSettingsIconKind.messages => Icon(
    Icons.thumb_up_alt_rounded,
    size: size * .64,
    color: Colors.white,
  ),
  MtSettingsIconKind.community => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      'MQL5',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * .31,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: -.65,
      ),
    ),
  ),
  MtSettingsIconKind.telegram => Transform.rotate(
    angle: -.12,
    child: Icon(Icons.send_rounded, size: size * .65, color: Colors.white),
  ),
  MtSettingsIconKind.otp => Icon(
    Icons.key_rounded,
    size: size * .68,
    color: Colors.white,
  ),
  MtSettingsIconKind.interface => Icon(
    Icons.translate_rounded,
    size: size * .7,
    color: Colors.white,
  ),
  MtSettingsIconKind.charts => CustomPaint(
    size: Size.square(size),
    painter: const _CandlesPainter(),
  ),
  MtSettingsIconKind.journal => Icon(
    Icons.notes_rounded,
    size: size * .7,
    color: Colors.white,
  ),
  MtSettingsIconKind.about => Icon(
    Icons.info_outline_rounded,
    size: size * .69,
    color: Colors.white,
  ),
};

class _NewAccountPainter extends CustomPainter {
  const _NewAccountPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(size.width * .42, size.height * .35),
      size.width * .13,
      white,
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .2,
        size.height * .5,
        size.width * .44,
        size.height * .27,
      ),
      Radius.circular(size.width * .11),
    );
    canvas.drawRRect(body, white);
    final stroke = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * .075
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .72, size.height * .42),
      Offset(size.width * .72, size.height * .66),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .6, size.height * .54),
      Offset(size.width * .84, size.height * .54),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _NewAccountPainter oldDelegate) => false;
}

class _CandlesPainter extends CustomPainter {
  const _CandlesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * .055
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = Colors.white;
    final centers = [size.width * .29, size.width * .5, size.width * .71];
    final tops = [size.height * .24, size.height * .16, size.height * .33];
    final bottoms = [size.height * .76, size.height * .69, size.height * .82];
    final bodies = [
      Rect.fromCenter(
        center: Offset(centers[0], size.height * .48),
        width: size.width * .13,
        height: size.height * .2,
      ),
      Rect.fromCenter(
        center: Offset(centers[1], size.height * .42),
        width: size.width * .13,
        height: size.height * .25,
      ),
      Rect.fromCenter(
        center: Offset(centers[2], size.height * .58),
        width: size.width * .13,
        height: size.height * .22,
      ),
    ];
    for (var index = 0; index < centers.length; index++) {
      canvas.drawLine(
        Offset(centers[index], tops[index]),
        Offset(centers[index], bottoms[index]),
        stroke,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bodies[index],
          Radius.circular(size.width * .025),
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CandlesPainter oldDelegate) => false;
}
