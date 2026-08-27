import 'package:flutter/material.dart';

/// Renders the price-transition arrow without relying on a platform fallback
/// font. The bundled Roboto families contain the upward arrow but not U+2192,
/// so rotating the matching glyph keeps screenshots and devices deterministic.
class MtPriceRangeText extends StatelessWidget {
  const MtPriceRangeText({
    required this.openPrice,
    required this.closePrice,
    required this.style,
    this.textKey,
    super.key,
  });

  final String openPrice;
  final String closePrice;
  final TextStyle style;
  final Key? textKey;

  String get semanticLabel => '$openPrice → $closePrice';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Text.rich(
        key: textKey,
        TextSpan(
          children: [
            TextSpan(text: openPrice),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                width: 21,
                height: 14,
                child: CustomPaint(
                  key: const Key('mt-price-range-arrow'),
                  painter: _PriceRangeArrowPainter(
                    color:
                        style.color ??
                        DefaultTextStyle.of(context).style.color!,
                  ),
                ),
              ),
            ),
            TextSpan(text: closePrice),
          ],
        ),
        style: style,
      ),
    );
  }
}

class _PriceRangeArrowPainter extends CustomPainter {
  const _PriceRangeArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final centerY = size.height / 2;
    canvas.drawLine(Offset(3.5, centerY), Offset(17.5, centerY), paint);
    canvas.drawLine(Offset(13.5, centerY - 3.5), Offset(17.5, centerY), paint);
    canvas.drawLine(Offset(13.5, centerY + 3.5), Offset(17.5, centerY), paint);
  }

  @override
  bool shouldRepaint(covariant _PriceRangeArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
