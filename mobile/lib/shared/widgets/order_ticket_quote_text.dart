import 'package:flutter/material.dart';

class OrderTicketQuoteText extends StatelessWidget {
  const OrderTicketQuoteText({
    required this.formattedPrice,
    required this.color,
    this.usePipette = false,
    super.key,
  });

  final String formattedPrice;
  final Color color;
  final bool usePipette;

  @override
  Widget build(BuildContext context) {
    final decimalAt = formattedPrice.lastIndexOf('.');
    final fractionLength = decimalAt < 0
        ? 0
        : formattedPrice.length - decimalAt - 1;
    final hasPipette = usePipette && fractionLength >= 3;
    final pipetteAt = hasPipette
        ? formattedPrice.length - 1
        : formattedPrice.length;
    final emphasizedStart = pipetteAt > 2 ? pipetteAt - 2 : 0;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formattedPrice.substring(0, emphasizedStart),
            style: TextStyle(
              color: color,
              fontSize: 20.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: formattedPrice.substring(emphasizedStart, pipetteAt),
            style: TextStyle(
              color: color,
              fontSize: 26.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasPipette)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Transform.translate(
                offset: const Offset(0, -8),
                child: Text(
                  formattedPrice.substring(pipetteAt),
                  style: TextStyle(
                    color: color,
                    fontFamily: 'sans-serif',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
      semanticsLabel: formattedPrice,
      maxLines: 1,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontFamily: 'sans-serif',
        height: 1,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
