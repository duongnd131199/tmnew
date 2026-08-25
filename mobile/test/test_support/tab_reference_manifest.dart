import 'dart:ui';

enum TabReferenceState {
  prices,
  chart,
  trade,
  historyPositions,
  historyOrders,
  historyOrdersSummary,
  historyDeals,
}

class TabReferenceCase {
  const TabReferenceCase({
    required this.id,
    required this.fileName,
    required this.state,
    this.dynamicMasks = const <Rect>[],
  });

  final String id;
  final String fileName;
  final TabReferenceState state;
  final List<Rect> dynamicMasks;

  String get referencePath => '../iconMau/anhmau/$fileName';
}

const tabReferenceLogicalSize = Size(393.3333333333, 853.3333333333);
const tabReferenceDevicePixelRatio = 1.5;

const tabReferenceCases = <TabReferenceCase>[
  TabReferenceCase(
    id: 'prices',
    fileName: 'photo_2026-08-25_22-30-10.jpg',
    state: TabReferenceState.prices,
  ),
  TabReferenceCase(
    id: 'chart',
    fileName: 'photo_2026-08-25_22-30-17.jpg',
    state: TabReferenceState.chart,
  ),
  TabReferenceCase(
    id: 'trade',
    fileName: 'photo_2026-08-25_22-30-20.jpg',
    state: TabReferenceState.trade,
  ),
  TabReferenceCase(
    id: 'history-positions',
    fileName: 'photo_2026-08-25_22-30-23.jpg',
    state: TabReferenceState.historyPositions,
  ),
  TabReferenceCase(
    id: 'history-orders',
    fileName: 'photo_2026-08-25_22-30-26.jpg',
    state: TabReferenceState.historyOrders,
  ),
  TabReferenceCase(
    id: 'history-orders-summary',
    fileName: 'photo_2026-08-25_22-30-29.jpg',
    state: TabReferenceState.historyOrdersSummary,
  ),
  TabReferenceCase(
    id: 'history-deals',
    fileName: 'photo_2026-08-25_22-30-34.jpg',
    state: TabReferenceState.historyDeals,
  ),
];
