import 'package:flutter/material.dart';

class OrderTicketQuoteText extends StatelessWidget {
  const OrderTicketQuoteText({
    required this.formattedPrice,
    required this.color,
    super.key,
  });

  final String formattedPrice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final suffixStart = formattedPrice.length > 2
        ? formattedPrice.length - 2
        : 0;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formattedPrice.substring(0, suffixStart),
            style: TextStyle(
              color: color,
              fontSize: 20.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: formattedPrice.substring(suffixStart),
            style: TextStyle(
              color: color,
              fontSize: 26.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
