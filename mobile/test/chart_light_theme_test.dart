import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_hit_targets.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_render_snapshot.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/chart/presentation/theme/chart_reference_theme.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

import 'test_support/video_reference_fixtures.dart';

const _background = 0xFFFFFFFF;
const _foreground = 0xFF000000;
const _grid = 0xFFE8E8E8;
const _bullish = 0xFF26A69A;
const _bearish = 0xFFEF5350;
const _tradeBlue = 0xFF3183FF;
const _axisBorder = 0xFFD8D8D8;
const _priceLine = 0xFF26A69A;
const _renderSize = Size(384, 600);
const _hostilePrimary = Color(0xFFFF00E5);
const _hostileSecondary = Color(0xFF00FF2A);
const _hostileSurface = Color(0xFF120018);
const _hostileForeground = Color(0xFFFFF500);
const _hostileState = Color(0xFFFF6A00);

const _alternateTheme = ChartReferenceTheme(
  background: Color(0xFFFFF4D6),
  foreground: Color(0xFF5B217A),
  grid: Color(0xFFC8A96A),
  bullish: Color(0xFF147D64),
  bearish: Color(0xFFB61F48),
  tradeBlue: Color(0xFF7257D7),
  axisBorder: Color(0xFF8E6F9E),
  priceLine: Color(0xFF0F6D99),
);

ChartReferenceTheme _replaceTheme(
  ChartReferenceTheme source, {
  Color? bullish,
  Color? bearish,
  Color? tradeBlue,
  Color? priceLine,
}) => ChartReferenceTheme(
  background: source.background,
  foreground: source.foreground,
  grid: source.grid,
  bullish: bullish ?? source.bullish,
  bearish: bearish ?? source.bearish,
  tradeBlue: tradeBlue ?? source.tradeBlue,
  axisBorder: source.axisBorder,
  priceLine: priceLine ?? source.priceLine,
);

List<MarketCandle> _candles({bool allBearish = false}) {
  return List<MarketCandle>.generate(40, (index) {
    final open = 100 + index * .1;
    final rising = !allBearish && index.isEven;
    final close = open + (rising ? .16 : -.16);
    return MarketCandle(
      time: DateTime.utc(2026, 8, 23, 10).add(Duration(minutes: index * 5)),
      open: open,
      high: math.max(open, close) + .28,
      low: math.min(open, close) - .25,
      close: close,
      volume: 1000 + index.toDouble(),
    );
  });
}

Mt5CandlePainter _painter({
  ChartReferenceTheme theme = ChartReferenceTheme.light,
  List<MarketCandle>? candles,
  double? currentPrice,
  bool crosshairEnabled = false,
  List<DemoPosition> positions = const <DemoPosition>[],
  List<DemoPendingOrder> pendingOrders = const <DemoPendingOrder>[],
  String? pendingOrderType,
  double? pendingOrderPrice,
  double barSpacing = ChartViewport.defaultBarSpacing,
  DateTime? tickTime,
}) {
  final resolvedCandles = candles ?? _candles();
  final resolvedPrice = currentPrice ?? resolvedCandles.last.close;
  final viewport = ChartViewport(barSpacing: barSpacing);
  final snapshot = ChartRenderSnapshot.evolve(
    history: resolvedCandles,
    liveTail: const <MarketCandle>[],
    resolvedCandles: resolvedCandles,
    historyRevision: 0,
    liveCandleRevision: 0,
    viewport: viewport,
    overlayValues: <Object?>[
      crosshairEnabled,
      for (final position in positions) ...<Object?>[
        position.id,
        position.currentPrice,
        position.profit,
      ],
      for (final order in pendingOrders) ...<Object?>[order.id, order.price],
      pendingOrderType,
      pendingOrderPrice,
    ],
    theme: theme,
  );
  return Mt5CandlePainter(
    snapshot: snapshot,
    symbol: 'TEST',
    referencePrice: resolvedPrice,
    currentPrice: resolvedPrice,
    tickTime: tickTime ?? DateTime.utc(2026, 8, 23, 13, 19, 30),
    crosshairEnabled: crosshairEnabled,
    crosshairPosition: crosshairEnabled ? const Offset(120, 180) : null,
    measurementStart: null,
    measurementEnd: null,
    timeframe: 'M5',
    positions: positions,
    pendingOrders: pendingOrders,
    indicators: const <String>{},
    chartObjects: const [],
    pendingOrderType: pendingOrderType,
    pendingOrderPrice: pendingOrderPrice,
    pendingOrderVolume: .2,
    pendingStopLoss: null,
    pendingTakeProfit: null,
    focusedChartPrice: null,
    loadingPlaceholder: false,
    oneClickTrading: false,
    h4ExpandedScaleSeen: false,
    showHistoryBadge: false,
    useRealtimeCandles: true,
    hitTargets: ChartHitTargets(),
  );
}

Mt5CandlePainter _withTheme(
  Mt5CandlePainter source,
  ChartReferenceTheme theme,
) {
  final snapshot = ChartRenderSnapshot.evolve(
    previous: source.snapshot,
    history: source.snapshot.history,
    liveTail: source.liveTail,
    resolvedCandles: source.candles,
    historyRevision: source.snapshot.historyRevision,
    liveCandleRevision: source.snapshot.liveCandleRevision,
    viewport: source.viewport,
    overlayValues: <Object?>[
      source.crosshairEnabled,
      for (final position in source.positions) ...<Object?>[
        position.id,
        position.currentPrice,
        position.profit,
      ],
      for (final order in source.pendingOrders) ...<Object?>[
        order.id,
        order.price,
      ],
      source.pendingOrderType,
      source.pendingOrderPrice,
    ],
    theme: theme,
  );
  return Mt5CandlePainter(
    snapshot: snapshot,
    symbol: source.symbol,
    referencePrice: source.referencePrice,
    currentPrice: source.currentPrice,
    tickTime: source.tickTime,
    crosshairEnabled: source.crosshairEnabled,
    crosshairPosition: source.crosshairPosition,
    measurementStart: source.measurementStart,
    measurementEnd: source.measurementEnd,
    timeframe: source.timeframe,
    positions: source.positions,
    pendingOrders: source.pendingOrders,
    indicators: source.indicators,
    chartObjects: source.chartObjects,
    pendingOrderType: source.pendingOrderType,
    pendingOrderPrice: source.pendingOrderPrice,
    pendingOrderVolume: source.pendingOrderVolume,
    pendingStopLoss: source.pendingStopLoss,
    pendingTakeProfit: source.pendingTakeProfit,
    focusedChartPrice: source.focusedChartPrice,
    loadingPlaceholder: source.loadingPlaceholder,
    oneClickTrading: source.oneClickTrading,
    h4ExpandedScaleSeen: source.h4ExpandedScaleSeen,
    showHistoryBadge: source.showHistoryBadge,
    useRealtimeCandles: source.useRealtimeCandles,
    hitTargets: ChartHitTargets(),
  );
}

final class _RenderedPixels {
  const _RenderedPixels(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;

  int countArgb(int target, Rect region, {int tolerance = 0}) {
    final left = region.left.floor().clamp(0, width - 1);
    final top = region.top.floor().clamp(0, height - 1);
    final right = region.right.ceil().clamp(left + 1, width);
    final bottom = region.bottom.ceil().clamp(top + 1, height);
    final targetA = (target >> 24) & 0xFF;
    final targetR = (target >> 16) & 0xFF;
    final targetG = (target >> 8) & 0xFF;
    final targetB = target & 0xFF;
    var count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final offset = (y * width + x) * 4;
        if ((rgba[offset + 3] - targetA).abs() <= tolerance &&
            (rgba[offset] - targetR).abs() <= tolerance &&
            (rgba[offset + 1] - targetG).abs() <= tolerance &&
            (rgba[offset + 2] - targetB).abs() <= tolerance) {
          count++;
        }
      }
    }
    return count;
  }

  int countUnambiguousRole(
    Color role,
    ChartReferenceTheme palette,
    Rect region, {
    double minimumCoverage = .18,
    double residualTolerance = 3,
  }) {
    final competingRoles = <Color>[
      palette.foreground,
      palette.grid,
      palette.bullish,
      palette.bearish,
      palette.tradeBlue,
      palette.axisBorder,
      palette.priceLine,
    ].where((candidate) => candidate != role).toList(growable: false);
    final left = region.left.floor().clamp(0, width - 1);
    final top = region.top.floor().clamp(0, height - 1);
    final right = region.right.ceil().clamp(left + 1, width);
    final bottom = region.bottom.ceil().clamp(top + 1, height);
    var count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final offset = (y * width + x) * 4;
        if (rgba[offset + 3] != 0xFF) continue;
        final pixel = (rgba[offset], rgba[offset + 1], rgba[offset + 2]);
        if (!_matchesRoleBlend(
          pixel,
          role,
          palette.background,
          minimumCoverage,
          residualTolerance,
        )) {
          continue;
        }
        final alsoMatchesCompetitor = competingRoles.any(
          (competitor) => _matchesRoleBlend(
            pixel,
            competitor,
            palette.background,
            minimumCoverage,
            residualTolerance,
          ),
        );
        if (!alsoMatchesCompetitor) count++;
      }
    }
    return count;
  }

  int countRoleBlend(Color role, Color underlay, Rect region) {
    final left = region.left.floor().clamp(0, width - 1);
    final top = region.top.floor().clamp(0, height - 1);
    final right = region.right.ceil().clamp(left + 1, width);
    final bottom = region.bottom.ceil().clamp(top + 1, height);
    var count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final offset = (y * width + x) * 4;
        if (rgba[offset + 3] != 0xFF) continue;
        if (_matchesRoleBlend(
          (rgba[offset], rgba[offset + 1], rgba[offset + 2]),
          role,
          underlay,
          .18,
          3,
        )) {
          count++;
        }
      }
    }
    return count;
  }

  int countDifferences(_RenderedPixels other, Rect region) {
    if (width != other.width || height != other.height) {
      throw ArgumentError('Rendered pixel dimensions must match.');
    }
    final left = region.left.floor().clamp(0, width - 1);
    final top = region.top.floor().clamp(0, height - 1);
    final right = region.right.ceil().clamp(left + 1, width);
    final bottom = region.bottom.ceil().clamp(top + 1, height);
    var count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final offset = (y * width + x) * 4;
        if (rgba[offset] != other.rgba[offset] ||
            rgba[offset + 1] != other.rgba[offset + 1] ||
            rgba[offset + 2] != other.rgba[offset + 2] ||
            rgba[offset + 3] != other.rgba[offset + 3]) {
          count++;
        }
      }
    }
    return count;
  }
}

bool _matchesRoleBlend(
  (int, int, int) pixel,
  Color role,
  Color background,
  double minimumCoverage,
  double residualTolerance,
) {
  final roleArgb = role.toARGB32();
  final backgroundArgb = background.toARGB32();
  final roleChannels = <double>[
    ((roleArgb >> 16) & 0xFF).toDouble(),
    ((roleArgb >> 8) & 0xFF).toDouble(),
    (roleArgb & 0xFF).toDouble(),
  ];
  final backgroundChannels = <double>[
    ((backgroundArgb >> 16) & 0xFF).toDouble(),
    ((backgroundArgb >> 8) & 0xFF).toDouble(),
    (backgroundArgb & 0xFF).toDouble(),
  ];
  final pixelChannels = <double>[
    pixel.$1.toDouble(),
    pixel.$2.toDouble(),
    pixel.$3.toDouble(),
  ];
  var dot = 0.0;
  var squaredLength = 0.0;
  for (var channel = 0; channel < 3; channel++) {
    final direction = roleChannels[channel] - backgroundChannels[channel];
    dot += (pixelChannels[channel] - backgroundChannels[channel]) * direction;
    squaredLength += direction * direction;
  }
  if (squaredLength == 0) return false;
  final coverage = dot / squaredLength;
  if (coverage < minimumCoverage || coverage > 1.01) return false;
  for (var channel = 0; channel < 3; channel++) {
    final expected =
        backgroundChannels[channel] +
        (roleChannels[channel] - backgroundChannels[channel]) * coverage;
    if ((pixelChannels[channel] - expected).abs() > residualTolerance) {
      return false;
    }
  }
  return true;
}

Future<_RenderedPixels> _pixelsFromImage(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _RenderedPixels(image.width, image.height, data!.buffer.asUint8List());
}

Future<void> _loadBadgeTypographyFont() async {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final font = File(
      '${directory.path}/artifacts/material_fonts/roboto-regular.ttf',
    );
    if (font.existsSync()) {
      final bytes = await font.readAsBytes();
      final loader = FontLoader('sans-serif')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      return;
    }
    directory = directory.parent;
  }
  throw StateError('Flutter Roboto test font was not found.');
}

Future<_RenderedPixels> _renderPainter(
  CustomPainter painter, {
  Size size = _renderSize,
}) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.ceil(), size.height.ceil());
  final pixels = await _pixelsFromImage(image);
  image.dispose();
  picture.dispose();
  return pixels;
}

double _priceY(Mt5CandlePainter painter, double price) {
  final targets = painter.hitTargets;
  return targets.priceTop +
      (targets.maxPrice - price) /
          (targets.maxPrice - targets.minPrice) *
          targets.priceHeight;
}

double _candleX(Mt5CandlePainter painter, int visibleIndex) {
  final targets = painter.hitTargets;
  return targets.firstCandleCenterX + targets.candleWidth * visibleIndex;
}

({int leftBody, int rightBody, int wick}) _candleBodyAndWickRoleCounts(
  _RenderedPixels pixels,
  Mt5CandlePainter painter,
  int visibleIndex,
  Color role,
  ChartReferenceTheme palette,
) {
  final candle = painter.hitTargets.visibleCandles[visibleIndex];
  final x = _candleX(painter, visibleIndex);
  final openY = _priceY(painter, candle.open);
  final closeY = _priceY(painter, candle.close);
  final highY = _priceY(painter, candle.high);
  final bodyTop = math.min(openY, closeY);
  final bodyBottom = math.max(openY, closeY) + 1.2;
  final bodyHalfWidth = painter.hitTargets.candleWidth * .18;
  // The wick is a .7 px center stroke. A 1.5 px minimum gap keeps both
  // sampled strips beyond the stroke plus a full anti-aliasing pixel.
  final centerGap = math.max(1.5, bodyHalfWidth * .45);
  const edgeInset = .2;

  return (
    leftBody: pixels.countUnambiguousRole(
      role,
      palette,
      Rect.fromLTRB(
        x - bodyHalfWidth + edgeInset,
        bodyTop,
        x - centerGap,
        bodyBottom,
      ),
    ),
    rightBody: pixels.countUnambiguousRole(
      role,
      palette,
      Rect.fromLTRB(
        x + centerGap,
        bodyTop,
        x + bodyHalfWidth - edgeInset,
        bodyBottom,
      ),
    ),
    wick: pixels.countUnambiguousRole(
      role,
      palette,
      Rect.fromLTRB(x - 2, highY, x + 2, bodyTop - .5),
    ),
  );
}

Future<void> _pumpAlternateChartOnDark(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(384, 848));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = createVideoReferenceContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _hostilePrimary,
            brightness: Brightness.dark,
            primary: _hostilePrimary,
            onPrimary: _hostileSurface,
            secondary: _hostileSecondary,
            onSecondary: _hostileSurface,
            surface: _hostileSurface,
            onSurface: _hostileForeground,
            error: _hostileState,
            onError: _hostileSurface,
          ),
          splashColor: _hostileState,
          highlightColor: _hostileState,
          hoverColor: _hostileState,
          focusColor: _hostileState,
          disabledColor: _hostileState,
          visualDensity: const VisualDensity(vertical: -1),
        ),
        home: const ChartScreen(theme: _alternateTheme),
      ),
    ),
  );
  await tester.pump();
}

Color _over(Color color, double alpha) => Color.alphaBlend(
  color.withValues(alpha: alpha),
  _alternateTheme.background,
);

void _expectFullyDerivedOverlayTheme(WidgetTester tester, Finder finder) {
  final theme = Theme.of(tester.element(finder));
  final scheme = theme.colorScheme;
  expect(scheme.surface, _alternateTheme.background);
  expect(scheme.onSurface, _alternateTheme.foreground);
  expect(scheme.primary, _alternateTheme.tradeBlue);
  expect(scheme.onPrimary, _alternateTheme.background);
  expect(scheme.primaryContainer, _over(_alternateTheme.tradeBlue, .16));
  expect(scheme.onPrimaryContainer, _alternateTheme.foreground);
  expect(scheme.primaryFixed, _alternateTheme.tradeBlue);
  expect(scheme.primaryFixedDim, _over(_alternateTheme.tradeBlue, .72));
  expect(scheme.onPrimaryFixed, _alternateTheme.background);
  expect(scheme.onPrimaryFixedVariant, _alternateTheme.foreground);
  expect(scheme.secondary, _alternateTheme.bullish);
  expect(scheme.onSecondary, _alternateTheme.background);
  expect(scheme.secondaryContainer, _over(_alternateTheme.bullish, .16));
  expect(scheme.onSecondaryContainer, _alternateTheme.foreground);
  expect(scheme.secondaryFixed, _alternateTheme.bullish);
  expect(scheme.secondaryFixedDim, _over(_alternateTheme.bullish, .72));
  expect(scheme.onSecondaryFixed, _alternateTheme.background);
  expect(scheme.onSecondaryFixedVariant, _alternateTheme.foreground);
  expect(scheme.tertiary, _alternateTheme.priceLine);
  expect(scheme.onTertiary, _alternateTheme.background);
  expect(scheme.tertiaryContainer, _over(_alternateTheme.priceLine, .16));
  expect(scheme.onTertiaryContainer, _alternateTheme.foreground);
  expect(scheme.tertiaryFixed, _alternateTheme.priceLine);
  expect(scheme.tertiaryFixedDim, _over(_alternateTheme.priceLine, .72));
  expect(scheme.onTertiaryFixed, _alternateTheme.background);
  expect(scheme.onTertiaryFixedVariant, _alternateTheme.foreground);
  expect(scheme.outline, _alternateTheme.axisBorder);
  expect(
    scheme.outlineVariant,
    _alternateTheme.axisBorder.withValues(alpha: .65),
  );
  expect(scheme.error, _alternateTheme.bearish);
  expect(scheme.onError, _alternateTheme.background);
  expect(scheme.errorContainer, _over(_alternateTheme.bearish, .16));
  expect(scheme.onErrorContainer, _alternateTheme.foreground);
  expect(scheme.surfaceDim, _over(_alternateTheme.foreground, .12));
  expect(scheme.surfaceBright, _alternateTheme.background);
  expect(scheme.surfaceContainerLowest, _alternateTheme.background);
  expect(scheme.surfaceContainerLow, _over(_alternateTheme.foreground, .02));
  expect(scheme.surfaceContainer, _over(_alternateTheme.foreground, .04));
  expect(scheme.surfaceContainerHigh, _over(_alternateTheme.foreground, .06));
  expect(
    scheme.surfaceContainerHighest,
    _over(_alternateTheme.foreground, .10),
  );
  expect(
    scheme.onSurfaceVariant,
    _alternateTheme.foreground.withValues(alpha: .72),
  );
  expect(scheme.shadow, _alternateTheme.foreground.withValues(alpha: .24));
  expect(scheme.scrim, _alternateTheme.foreground.withValues(alpha: .32));
  expect(scheme.inverseSurface, _alternateTheme.foreground);
  expect(scheme.onInverseSurface, _alternateTheme.background);
  expect(scheme.inversePrimary, _alternateTheme.tradeBlue);
  expect(scheme.surfaceTint, _alternateTheme.background.withValues(alpha: 0));
  expect(theme.splashColor, _alternateTheme.tradeBlue.withValues(alpha: .12));
  expect(
    theme.highlightColor,
    _alternateTheme.tradeBlue.withValues(alpha: .08),
  );
  expect(theme.hoverColor, _alternateTheme.tradeBlue.withValues(alpha: .08));
  expect(theme.focusColor, _alternateTheme.tradeBlue.withValues(alpha: .12));
  expect(
    theme.disabledColor,
    _alternateTheme.foreground.withValues(alpha: .38),
  );
}

Color? _dismissibleRouteBarrierColor(WidgetTester tester) {
  return tester
      .widgetList<ModalBarrier>(find.byType(ModalBarrier))
      .lastWhere((barrier) => barrier.dismissible)
      .color;
}

void _expectTextButtonStates(WidgetTester tester, Finder buttonFinder) {
  final style = TextButtonTheme.of(tester.element(buttonFinder)).style!;
  expect(style.foregroundColor!.resolve({}), _alternateTheme.tradeBlue);
  expect(
    style.foregroundColor!.resolve({WidgetState.disabled}),
    _alternateTheme.foreground.withValues(alpha: .38),
  );
  expect(
    style.overlayColor!.resolve({WidgetState.pressed}),
    _alternateTheme.tradeBlue.withValues(alpha: .12),
  );
  expect(
    style.overlayColor!.resolve({WidgetState.hovered}),
    _alternateTheme.tradeBlue.withValues(alpha: .08),
  );
  expect(
    style.overlayColor!.resolve({WidgetState.focused}),
    _alternateTheme.tradeBlue.withValues(alpha: .12),
  );
}

void main() {
  test('painter exposes the exact immutable MT5 light palette', () {
    const light = ChartReferenceTheme.light;
    expect(light.background.toARGB32(), _background);
    expect(light.foreground.toARGB32(), _foreground);
    expect(light.grid.toARGB32(), _grid);
    expect(light.bullish.toARGB32(), _bullish);
    expect(light.bearish.toARGB32(), _bearish);
    expect(light.tradeBlue.toARGB32(), _tradeBlue);
    expect(light.axisBorder.toARGB32(), _axisBorder);
    expect(light.priceLine.toARGB32(), _priceLine);
  });

  test('bullish and bearish body and wick paths use their own roles', () async {
    final painter = _painter(theme: _alternateTheme, barSpacing: 48);
    final pixels = await _renderPainter(painter);
    final visible = painter.hitTargets.visibleCandles;
    final bullishIndex = visible.indexWhere(
      (candle) => candle.close > candle.open,
    );
    final bearishIndex = visible.indexWhere(
      (candle) => candle.close < candle.open,
    );

    final bullish = _candleBodyAndWickRoleCounts(
      pixels,
      painter,
      bullishIndex,
      _alternateTheme.bullish,
      _alternateTheme,
    );
    final bearish = _candleBodyAndWickRoleCounts(
      pixels,
      painter,
      bearishIndex,
      _alternateTheme.bearish,
      _alternateTheme,
    );
    expect(
      bullish.leftBody,
      greaterThanOrEqualTo(2),
      reason: 'The bullish left body interior excludes the center wick.',
    );
    expect(
      bullish.rightBody,
      greaterThanOrEqualTo(2),
      reason: 'The bullish right body interior excludes the center wick.',
    );
    expect(bullish.wick, greaterThan(0));
    expect(
      bearish.leftBody,
      greaterThanOrEqualTo(2),
      reason: 'The bearish left body interior excludes the center wick.',
    );
    expect(
      bearish.rightBody,
      greaterThanOrEqualTo(2),
      reason: 'The bearish right body interior excludes the center wick.',
    );
    expect(bearish.wick, greaterThan(0));

    final wrongBullishPainter = _painter(
      theme: _replaceTheme(_alternateTheme, bullish: _alternateTheme.grid),
      barSpacing: 48,
    );
    final wrongBullishPixels = await _renderPainter(wrongBullishPainter);
    final wrongBullish = _candleBodyAndWickRoleCounts(
      wrongBullishPixels,
      wrongBullishPainter,
      bullishIndex,
      _alternateTheme.bullish,
      _alternateTheme,
    );
    expect(wrongBullish.leftBody, 0);
    expect(wrongBullish.rightBody, 0);
    expect(wrongBullish.wick, 0);
    final wrongBullishAsGrid = _candleBodyAndWickRoleCounts(
      wrongBullishPixels,
      wrongBullishPainter,
      bullishIndex,
      _alternateTheme.grid,
      _alternateTheme,
    );
    expect(wrongBullishAsGrid.leftBody, greaterThanOrEqualTo(2));
    expect(wrongBullishAsGrid.rightBody, greaterThanOrEqualTo(2));
    expect(wrongBullishAsGrid.wick, greaterThan(0));

    final wrongBearishPainter = _painter(
      theme: _replaceTheme(_alternateTheme, bearish: _alternateTheme.grid),
      barSpacing: 48,
    );
    final wrongBearishPixels = await _renderPainter(wrongBearishPainter);
    final wrongBearish = _candleBodyAndWickRoleCounts(
      wrongBearishPixels,
      wrongBearishPainter,
      bearishIndex,
      _alternateTheme.bearish,
      _alternateTheme,
    );
    expect(wrongBearish.leftBody, 0);
    expect(wrongBearish.rightBody, 0);
    expect(wrongBearish.wick, 0);
    final wrongBearishAsGrid = _candleBodyAndWickRoleCounts(
      wrongBearishPixels,
      wrongBearishPainter,
      bearishIndex,
      _alternateTheme.grid,
      _alternateTheme,
    );
    expect(wrongBearishAsGrid.leftBody, greaterThanOrEqualTo(2));
    expect(wrongBearishAsGrid.rightBody, greaterThanOrEqualTo(2));
    expect(wrongBearishAsGrid.wick, greaterThan(0));
  });

  test('price line and badge use priceLine outside candle regions', () async {
    final painter = _painter(
      theme: _alternateTheme,
      candles: _candles(allBearish: true),
    );
    final pixels = await _renderPainter(painter);
    final currentY = _priceY(painter, painter.currentPrice);
    final chartWidth = painter.hitTargets.chartWidth;
    final badge = painter.debugCurrentPriceBadgeRect!;

    expect(
      pixels.countUnambiguousRole(
        _alternateTheme.priceLine,
        _alternateTheme,
        Rect.fromLTRB(8, currentY - 2, chartWidth - 8, currentY + 2),
      ),
      greaterThan(0),
      reason: 'The plot price-line path must paint priceLine.',
    );
    expect(
      pixels.countUnambiguousRole(
        _alternateTheme.priceLine,
        _alternateTheme,
        badge,
      ),
      greaterThan(100),
      reason: 'The axis badge fill must paint priceLine.',
    );

    final wrongPainter = _painter(
      theme: _replaceTheme(
        _alternateTheme,
        priceLine: _alternateTheme.axisBorder,
      ),
      candles: _candles(allBearish: true),
    );
    final wrongPixels = await _renderPainter(wrongPainter);
    final wrongCurrentY = _priceY(wrongPainter, wrongPainter.currentPrice);
    expect(
      wrongPixels.countUnambiguousRole(
        _alternateTheme.priceLine,
        _alternateTheme,
        Rect.fromLTRB(
          8,
          wrongCurrentY - 2,
          wrongPainter.hitTargets.chartWidth - 8,
          wrongCurrentY + 2,
        ),
      ),
      0,
    );
    expect(
      wrongPixels.countUnambiguousRole(
        _alternateTheme.axisBorder,
        _alternateTheme,
        Rect.fromLTRB(
          8,
          wrongCurrentY - 2,
          wrongPainter.hitTargets.chartWidth - 8,
          wrongCurrentY + 2,
        ),
      ),
      greaterThan(0),
    );
    expect(
      wrongPixels.countUnambiguousRole(
        _alternateTheme.priceLine,
        _alternateTheme,
        wrongPainter.debugCurrentPriceBadgeRect!,
      ),
      0,
    );
    expect(
      wrongPixels.countUnambiguousRole(
        _alternateTheme.axisBorder,
        _alternateTheme,
        wrongPainter.debugCurrentPriceBadgeRect!,
      ),
      greaterThan(100),
    );
  });

  test('current-price badge is one price row with no countdown ink', () async {
    final painter = _painter(
      theme: _alternateTheme,
      tickTime: DateTime.utc(2026, 8, 23, 13, 19, 30),
    );
    final laterPainter = _painter(
      theme: _alternateTheme,
      tickTime: DateTime.utc(2026, 8, 23, 13, 19, 45),
    );
    final pixels = await _renderPainter(painter);
    final laterPixels = await _renderPainter(laterPainter);
    final badge = painter.debugCurrentPriceBadgeRect!;
    final contrastingTextArgb = _alternateTheme.background.toARGB32();

    expect(badge.height, 20);
    expect(
      badge.center.dy,
      closeTo(_priceY(painter, painter.currentPrice), .01),
    );
    expect(
      pixels.countArgb(contrastingTextArgb, badge.deflate(2)),
      greaterThan(5),
      reason: 'The realtime price must use the chart-background contrast.',
    );
    expect(
      pixels.countDifferences(
        laterPixels,
        Rect.fromLTRB(badge.left, badge.top, badge.right, badge.bottom + 14),
      ),
      0,
      reason: 'Changing only tick time must not paint countdown digits.',
    );
  });

  test(
    'position and pending lines paint tradeBlue with crosshair excluded',
    () async {
      const positionPrice = 103.0;
      const pendingPrice = 103.35;
      final positionPainter = _painter(
        theme: _alternateTheme,
        candles: _candles(allBearish: true),
        crosshairEnabled: false,
        positions: const [
          DemoPosition(
            id: 'position',
            symbol: 'TEST',
            side: 'BUY',
            volume: .1,
            openPrice: positionPrice,
            currentPrice: 102,
            profit: 4.5,
          ),
        ],
      );
      final positionPixels = await _renderPainter(positionPainter);
      final positionChartWidth = positionPainter.hitTargets.chartWidth;
      final positionLineRegionLeft = positionChartWidth * .65;

      expect(positionPainter.crosshairEnabled, isFalse);
      expect(
        positionPixels.countUnambiguousRole(
          _alternateTheme.tradeBlue,
          _alternateTheme,
          Rect.fromLTRB(
            positionLineRegionLeft,
            _priceY(positionPainter, positionPrice) - 2,
            positionChartWidth - 4,
            _priceY(positionPainter, positionPrice) + 2,
          ),
        ),
        greaterThan(0),
        reason: 'The position-line path must paint tradeBlue.',
      );

      final pendingPainter = _painter(
        theme: _alternateTheme,
        candles: _candles(allBearish: true),
        crosshairEnabled: false,
        pendingOrders: const [
          DemoPendingOrder(
            id: 'pending',
            symbol: 'TEST',
            side: 'BUY',
            type: 'Buy Limit',
            volume: .2,
            price: pendingPrice,
            createdAt: '',
          ),
        ],
        pendingOrderType: 'Buy Limit',
        pendingOrderPrice: pendingPrice,
      );
      final pendingPixels = await _renderPainter(pendingPainter);
      final chartWidth = pendingPainter.hitTargets.chartWidth;
      final lineRegionLeft = chartWidth * .65;

      expect(pendingPainter.crosshairEnabled, isFalse);
      expect(
        pendingPixels.countUnambiguousRole(
          _alternateTheme.tradeBlue,
          _alternateTheme,
          Rect.fromLTRB(
            lineRegionLeft,
            _priceY(pendingPainter, pendingPrice) - 2,
            chartWidth - 4,
            _priceY(pendingPainter, pendingPrice) + 2,
          ),
        ),
        greaterThan(0),
        reason: 'The pending-order-line path must paint tradeBlue.',
      );

      final wrongPositionPainter = _painter(
        theme: _replaceTheme(
          _alternateTheme,
          tradeBlue: _alternateTheme.axisBorder,
        ),
        candles: _candles(allBearish: true),
        crosshairEnabled: false,
        positions: positionPainter.positions,
      );
      final wrongPositionPixels = await _renderPainter(wrongPositionPainter);
      expect(
        wrongPositionPixels.countUnambiguousRole(
          _alternateTheme.tradeBlue,
          _alternateTheme,
          Rect.fromLTRB(
            wrongPositionPainter.hitTargets.chartWidth * .65,
            _priceY(wrongPositionPainter, positionPrice) - 2,
            wrongPositionPainter.hitTargets.chartWidth - 4,
            _priceY(wrongPositionPainter, positionPrice) + 2,
          ),
        ),
        0,
      );
      expect(
        wrongPositionPixels.countUnambiguousRole(
          _alternateTheme.axisBorder,
          _alternateTheme,
          Rect.fromLTRB(
            wrongPositionPainter.hitTargets.chartWidth * .65,
            _priceY(wrongPositionPainter, positionPrice) - 2,
            wrongPositionPainter.hitTargets.chartWidth - 4,
            _priceY(wrongPositionPainter, positionPrice) + 2,
          ),
        ),
        greaterThan(0),
      );

      final wrongPendingPainter = _painter(
        theme: _replaceTheme(
          _alternateTheme,
          tradeBlue: _alternateTheme.axisBorder,
        ),
        candles: _candles(allBearish: true),
        crosshairEnabled: false,
        pendingOrders: pendingPainter.pendingOrders,
        pendingOrderType: pendingPainter.pendingOrderType,
        pendingOrderPrice: pendingPainter.pendingOrderPrice,
      );
      final wrongPendingPixels = await _renderPainter(wrongPendingPainter);
      expect(
        wrongPendingPixels.countUnambiguousRole(
          _alternateTheme.tradeBlue,
          _alternateTheme,
          Rect.fromLTRB(
            wrongPendingPainter.hitTargets.chartWidth * .65,
            _priceY(wrongPendingPainter, pendingPrice) - 2,
            wrongPendingPainter.hitTargets.chartWidth - 4,
            _priceY(wrongPendingPainter, pendingPrice) + 2,
          ),
        ),
        0,
      );
      expect(
        wrongPendingPixels.countUnambiguousRole(
          _alternateTheme.axisBorder,
          _alternateTheme,
          Rect.fromLTRB(
            wrongPendingPainter.hitTargets.chartWidth * .65,
            _priceY(wrongPendingPainter, pendingPrice) - 2,
            wrongPendingPainter.hitTargets.chartWidth - 4,
            _priceY(wrongPendingPainter, pendingPrice) + 2,
          ),
        ),
        greaterThan(0),
      );
    },
  );

  test('canvas background, grid, axes and frame use light roles', () async {
    final painter = _painter(candles: _candles(allBearish: true));
    final pixels = await _renderPainter(painter);
    final chartWidth = painter.hitTargets.chartWidth;
    final chartHeight = painter.hitTargets.chartHeight;

    expect(
      pixels.countArgb(_background, Offset.zero & _renderSize),
      greaterThan(1000),
    );
    expect(
      pixels.countArgb(
        _grid,
        Rect.fromLTRB(
          0,
          painter.hitTargets.priceTop - 1,
          chartWidth,
          chartHeight,
        ),
        tolerance: 20,
      ),
      greaterThan(0),
    );
    expect(
      pixels.countArgb(
        _foreground,
        Rect.fromLTRB(chartWidth, 0, _renderSize.width, _renderSize.height),
      ),
      greaterThan(0),
    );
    expect(
      pixels.countArgb(
        _axisBorder,
        Rect.fromLTRB(chartWidth - 2, 0, chartWidth + 2, chartHeight),
        tolerance: 20,
      ),
      greaterThan(0),
    );
  });

  testWidgets('an actual outside-Chart screen renders the app light theme', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RepaintBoundary(
            key: Key('outside-chart-boundary'),
            child: MarketWatchScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final scaffoldMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(Scaffold),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(scaffoldMaterial.color, AppColors.background);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      isNull,
    );
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.background);
  });

  testWidgets('injected theme reaches toolbar icon painter', (tester) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ChartScreen(theme: _alternateTheme)),
      ),
    );
    await tester.pump();

    final chartSurface = tester.widget<ColoredBox>(
      find.byKey(const Key('chart-light-surface')),
    );
    expect(chartSurface.color, _alternateTheme.background);

    final painterThemes = <Object?>[];
    for (final key in const <Key>[
      Key('chart-crosshair-button'),
      Key('chart-indicators-button'),
      Key('chart-objects-button'),
      Key('chart-windows-button'),
      Key('chart-one-click-toggle'),
    ]) {
      final paintFinder = find
          .descendant(of: find.byKey(key), matching: find.byType(CustomPaint))
          .first;
      final customPaint = tester.widget<CustomPaint>(paintFinder);
      try {
        painterThemes.add((customPaint.painter! as dynamic).theme as Object?);
      } on NoSuchMethodError {
        painterThemes.add(null);
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
      painterThemes,
      everyElement(same(_alternateTheme)),
      reason: 'Every toolbar painter must consume ChartScreen.theme.',
    );
  });

  testWidgets('injected theme reaches one-click field and keypad', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ChartScreen(theme: _alternateTheme)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    final volumeText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('chart-one-click-volume-field')),
        matching: find.text('0.25'),
      ),
    );
    final volumeColor = volumeText.style?.color;

    await tester.tap(find.byKey(const Key('chart-one-click-volume-field')));
    await tester.pump(const Duration(milliseconds: 400));
    final keypadOne = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('chart-numeric-keypad-sheet')),
        matching: find.text('1'),
      ),
    );
    final keypadColor = keypadOne.style?.color;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(volumeColor, _alternateTheme.foreground);
    expect(keypadColor, _alternateTheme.foreground);
  });

  testWidgets('injected theme reaches pending-order controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ChartScreen(theme: _alternateTheme)),
      ),
    );
    await tester.pump();

    final chart = find.byKey(const Key('chart-gesture-area'));
    final gesture = await tester.startGesture(tester.getCenter(chart));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();

    final pill = find.byKey(const Key('chart-pending-order-pill'));
    expect(pill, findsOneWidget);
    final material = tester.widget<Material>(
      find.ancestor(of: pill, matching: find.byType(Material)).first,
    );
    final pillColor = material.color;
    final collapse = tester.widget<OutlinedButton>(
      find.byKey(const Key('chart-pending-collapse')),
    );
    final collapseColor = collapse.style?.foregroundColor?.resolve({});
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(pillColor, _alternateTheme.tradeBlue);
    expect(collapseColor, _alternateTheme.tradeBlue);
  });

  testWidgets('advanced-trade sheet has no dark Material leakage', (
    tester,
  ) async {
    await _pumpAlternateChartOnDark(tester);

    await tester.longPress(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump(const Duration(milliseconds: 400));

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet).last);
    final selectedFinder = find.text('Buy Limit').last;
    final unselectedFinder = find.text('Bởi thị trường').last;
    final selected = tester.widget<Text>(find.text('Buy Limit').last);
    final unselected = tester.widget<Text>(unselectedFinder);
    final inkWellFinder = find.ancestor(
      of: unselectedFinder,
      matching: find.byType(InkWell),
    );
    final inkWell = tester.widget<InkWell>(inkWellFinder);
    final inkTheme = Theme.of(tester.element(inkWellFinder));
    final surface = sheet.backgroundColor;
    final selectedColor = selected.style?.color;
    final unselectedColor = unselected.style?.color;
    final barrierColor = _dismissibleRouteBarrierColor(tester);

    expect(surface, _alternateTheme.background);
    _expectFullyDerivedOverlayTheme(tester, selectedFinder);
    expect(selectedColor, _alternateTheme.bearish);
    expect(unselectedColor, _alternateTheme.foreground.withValues(alpha: .55));
    expect(barrierColor, _alternateTheme.foreground.withValues(alpha: .32));
    expect(
      inkWell.splashColor ?? inkTheme.splashColor,
      _alternateTheme.tradeBlue.withValues(alpha: .12),
    );
    expect(
      inkWell.highlightColor ?? inkTheme.highlightColor,
      _alternateTheme.tradeBlue.withValues(alpha: .08),
    );
    expect(
      inkWell.hoverColor ?? inkTheme.hoverColor,
      _alternateTheme.tradeBlue.withValues(alpha: .08),
    );
    expect(
      inkWell.focusColor ?? inkTheme.focusColor,
      _alternateTheme.tradeBlue.withValues(alpha: .12),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('advanced-trade price dialog uses only the injected theme', (
    tester,
  ) async {
    await _pumpAlternateChartOnDark(tester);

    await tester.longPress(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('SL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final inputTheme = Theme.of(
      tester.element(find.byType(TextFormField)),
    ).inputDecorationTheme;
    final cancelFinder = find.text('HỦY');
    final surface = dialog.backgroundColor;
    final inputFill = inputTheme.fillColor;
    final barrierColor = _dismissibleRouteBarrierColor(tester);

    expect(surface, _alternateTheme.background);
    _expectFullyDerivedOverlayTheme(tester, find.byType(AlertDialog));
    expect(
      inputFill,
      Color.alphaBlend(
        _alternateTheme.foreground.withValues(alpha: .06),
        _alternateTheme.background,
      ),
    );
    expect(barrierColor, _alternateTheme.foreground.withValues(alpha: .32));
    _expectTextButtonStates(tester, cancelFinder);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('pending-protection dialog uses only the injected theme', (
    tester,
  ) async {
    await _pumpAlternateChartOnDark(tester);

    final chart = find.byKey(const Key('chart-gesture-area'));
    final gesture = await tester.startGesture(tester.getCenter(chart));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    tester
        .widget<OutlinedButton>(find.byKey(const Key('chart-pending-sl')))
        .onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final inputTheme = Theme.of(
      tester.element(find.byType(TextFormField)),
    ).inputDecorationTheme;
    final doneFinder = find.text('XONG');
    final surface = dialog.backgroundColor;
    final inputBorder = inputTheme.enabledBorder?.borderSide.color;
    final barrierColor = _dismissibleRouteBarrierColor(tester);

    expect(surface, _alternateTheme.background);
    _expectFullyDerivedOverlayTheme(tester, find.byType(AlertDialog));
    expect(inputBorder, _alternateTheme.axisBorder);
    expect(barrierColor, _alternateTheme.foreground.withValues(alpha: .32));
    _expectTextButtonStates(tester, doneFinder);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('active chart-windows sheet uses only the injected theme', (
    tester,
  ) async {
    await _pumpAlternateChartOnDark(tester);

    await tester.tap(find.byKey(const Key('chart-windows-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet).last);
    final titleFinder = find.text('Biểu đồ');
    final activeTileFinder = find.byType(ListTile).at(1);
    final activeTile = tester.widget<ListTile>(activeTileFinder);
    final activeTileTheme = Theme.of(tester.element(activeTileFinder));
    final titleColor = DefaultTextStyle.of(
      tester.element(titleFinder),
    ).style.color;
    final addIconFinder = find.byIcon(CupertinoIcons.add);
    final addIconColor = IconTheme.of(tester.element(addIconFinder)).color;
    final surface = sheet.backgroundColor;
    final barrierColor = _dismissibleRouteBarrierColor(tester);

    expect(surface, _alternateTheme.background);
    _expectFullyDerivedOverlayTheme(tester, titleFinder);
    expect(titleColor, _alternateTheme.foreground);
    expect(addIconColor, _alternateTheme.foreground);
    expect(barrierColor, _alternateTheme.foreground.withValues(alpha: .32));
    expect(
      activeTile.hoverColor ?? activeTileTheme.hoverColor,
      _alternateTheme.tradeBlue.withValues(alpha: .08),
    );
    expect(
      activeTile.focusColor ?? activeTileTheme.focusColor,
      _alternateTheme.tradeBlue.withValues(alpha: .12),
    );
    expect(
      activeTileTheme.splashColor,
      _alternateTheme.tradeBlue.withValues(alpha: .12),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('changing only painter theme requires repaint', () {
    final original = _painter();
    final sameTheme = _withTheme(original, original.theme);
    final changedTheme = _withTheme(original, _alternateTheme);

    expect(sameTheme.shouldRepaint(original), isFalse);
    expect(changedTheme.shouldRepaint(original), isTrue);
  });

  test('realtime price uses the thin price-axis stroke density', () async {
    await _loadBadgeTypographyFont();
    final painter = _painter(theme: _alternateTheme);
    final pixels = await _renderPainter(painter);
    final targets = painter.hitTargets;
    final badge = painter.debugCurrentPriceBadgeRect!;
    final priceLabel = targets.priceAxisLabels.first;
    final priceTextPixels = pixels.countRoleBlend(
      _alternateTheme.background,
      _alternateTheme.priceLine,
      badge.deflate(2),
    );
    final priceAxisPixels = pixels.countRoleBlend(
      _alternateTheme.foreground,
      _alternateTheme.background,
      Rect.fromLTWH(targets.chartWidth + 4, priceLabel.y - 8, badge.width, 16),
    );

    expect(priceAxisPixels, greaterThan(0));
    expect(
      priceTextPixels / priceAxisPixels,
      lessThan(1.7),
      reason: 'The realtime price stroke is heavier than the price axis.',
    );
  });
}
