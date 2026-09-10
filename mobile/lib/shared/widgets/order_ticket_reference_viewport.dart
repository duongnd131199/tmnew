import 'package:flutter/widgets.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';

class OrderTicketReferenceViewport extends StatelessWidget {
  const OrderTicketReferenceViewport({required this.child, super.key});

  static const _layoutTolerance = .01;

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final referenceScale =
          constraints.maxWidth / TabReferenceMetrics.viewportWidth;
      final referenceHeight = constraints.maxHeight / referenceScale;
      final hasReferencePhoneAspect =
          referenceHeight >=
          TabReferenceMetrics.viewportHeight - _layoutTolerance;
      if (constraints.maxWidth <=
              TabReferenceMetrics.viewportWidth + _layoutTolerance ||
          !hasReferencePhoneAspect) {
        return child;
      }

      final mediaQuery = MediaQuery.of(context);

      return SizedBox.expand(
        child: FittedBox(
          alignment: Alignment.topLeft,
          fit: BoxFit.fill,
          child: SizedBox(
            width: TabReferenceMetrics.viewportWidth,
            height: referenceHeight,
            child: MediaQuery(
              data: mediaQuery.copyWith(
                size: Size(TabReferenceMetrics.viewportWidth, referenceHeight),
              ),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
