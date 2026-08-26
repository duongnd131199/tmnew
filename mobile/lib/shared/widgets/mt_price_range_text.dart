import 'dart:math' as math;

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
                child: Center(
                  child: Transform.rotate(
                    angle: math.pi / 2,
                    child: Text(
                      '↑',
                      style: style.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
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
