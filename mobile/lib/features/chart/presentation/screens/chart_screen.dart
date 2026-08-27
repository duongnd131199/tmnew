import 'dart:async';
import 'dart:collection';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/chart/application/chart_timeframe_session.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/data/market_data_service.dart';
import 'package:trading_mobile/features/chart/presentation/navigation/chart_navigation.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_candle_resolver.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_hit_targets.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_render_snapshot.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/theme/chart_reference_theme.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_price_viewport.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';
import 'package:trading_mobile/shared/widgets/trading_drawer.dart';

const _chartToolbarReferenceWidth = 384.0;
const _chartToolbarHeight = 70.6666666667;
const _oneClickPanelHeight = 38.6666666667;
const _chartNavigationOverlap = 10.0;

enum ChartLayoutProfile { standard, tabReferenceCapture }

class ChartScreen extends ConsumerStatefulWidget {
  const ChartScreen({
    this.symbol = 'XAUUSD+',
    this.initialTimeframe = 'H4',
    this.theme = ChartReferenceTheme.light,
    this.layoutProfile = ChartLayoutProfile.standard,
    super.key,
  });

  final String symbol;
  final String initialTimeframe;
  final ChartReferenceTheme theme;
  final ChartLayoutProfile layoutProfile;

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _LastValidChartFrame {
  _LastValidChartFrame({required this.request, required this.candleState});

  final MarketDataRequest request;
  final LiveMarketCandleState candleState;

  List<MarketCandle> get candles => candleState.candles;
}

typedef _PositionRenderValue = ({
  String id,
  String symbol,
  String side,
  double volume,
  double openPrice,
  double currentPrice,
  double profit,
  double? stopLoss,
  double? takeProfit,
  String openedAt,
});

typedef _PendingOrderRenderValue = ({
  String id,
  String symbol,
  String side,
  String type,
  double volume,
  double price,
  double? stopLoss,
  double? takeProfit,
  String createdAt,
  String status,
});

typedef _ChartResolutionCacheKey = ({
  MarketDataRequest request,
  int historyRevision,
  bool useRealtimeCandles,
  String symbol,
  String timeframe,
  double referencePrice,
  bool loadingPlaceholder,
  int sourceLength,
  int settledLiveLength,
  Object settledLiveIdentity,
  bool referencePriceBand,
});

@immutable
final class _RenderProjection<T, V> {
  _RenderProjection(Iterable<T> items, V Function(T) project)
    : items = List<T>.unmodifiable(items),
      values = List<V>.unmodifiable(items.map(project));

  final List<T> items;
  final List<V> values;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RenderProjection<T, V> && listEquals(values, other.values);

  @override
  int get hashCode => Object.hashAll(values);
}

mixin _ImmutableCandleListMixin on ListBase<MarketCandle> {
  Never _rejectMutation() => throw UnsupportedError('Immutable candle list');

  @override
  set length(int value) => _rejectMutation();

  @override
  void operator []=(int index, MarketCandle value) => _rejectMutation();

  @override
  void add(MarketCandle value) => _rejectMutation();

  @override
  void addAll(Iterable<MarketCandle> iterable) => _rejectMutation();

  @override
  void insert(int index, MarketCandle element) => _rejectMutation();

  @override
  void insertAll(int index, Iterable<MarketCandle> iterable) =>
      _rejectMutation();

  @override
  void setAll(int index, Iterable<MarketCandle> iterable) => _rejectMutation();

  @override
  void setRange(
    int start,
    int end,
    Iterable<MarketCandle> iterable, [
    int skipCount = 0,
  ]) => _rejectMutation();

  @override
  void fillRange(int start, int end, [MarketCandle? fillValue]) =>
      _rejectMutation();

  @override
  void replaceRange(int start, int end, Iterable<MarketCandle> replacements) =>
      _rejectMutation();

  @override
  bool remove(Object? value) => _rejectMutation();

  @override
  MarketCandle removeAt(int index) => _rejectMutation();

  @override
  MarketCandle removeLast() => _rejectMutation();

  @override
  void removeRange(int start, int end) => _rejectMutation();

  @override
  void removeWhere(bool Function(MarketCandle element) test) =>
      _rejectMutation();

  @override
  void retainWhere(bool Function(MarketCandle element) test) =>
      _rejectMutation();

  @override
  void clear() => _rejectMutation();

  @override
  void sort([int Function(MarketCandle a, MarketCandle b)? compare]) =>
      _rejectMutation();

  @override
  void shuffle([math.Random? random]) => _rejectMutation();
}

final class _ImmutableRenderCandleSeries extends ListBase<MarketCandle>
    with _ImmutableCandleListMixin {
  _ImmutableRenderCandleSeries(this._history, this._active);

  final List<MarketCandle> _history;
  final MarketCandle? _active;

  @override
  int get length => _history.length + (_active == null ? 0 : 1);

  @override
  MarketCandle operator [](int index) {
    RangeError.checkValidIndex(index, this);
    if (index < _history.length) return _history[index];
    return _active!;
  }
}

final class _ImmutableCandleRange extends ListBase<MarketCandle>
    with _ImmutableCandleListMixin {
  _ImmutableCandleRange(this._source, this._start, this._end)
    : assert(_start >= 0),
      assert(_start <= _end),
      assert(_end <= _source.length);

  final List<MarketCandle> _source;
  final int _start;
  final int _end;

  @override
  int get length => _end - _start;

  @override
  MarketCandle operator [](int index) {
    RangeError.checkValidIndex(index, this);
    return _source[_start + index];
  }
}

class _ChartScreenState extends ConsumerState<ChartScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String timeframe;
  bool crosshairEnabled = false;
  bool showTimeframes = false;
  bool showOneClickTrading = false;
  double volume = 0.25;
  double? pendingStopLoss;
  double? pendingTakeProfit;
  Offset? crosshairPosition;
  Offset? measurementStart;
  Offset? measurementEnd;
  final Map<int, Offset> _chartPointers = <int, Offset>{};
  final Map<int, Offset> _viewportPointers = <int, Offset>{};
  final ChartHitTargets _chartHitTargets = ChartHitTargets();
  final ChartViewportController _viewportController = ChartViewportController();
  ChartViewport _viewport = const ChartViewport();
  late final ChartTimeframeSessionController _chartViewSessionController;
  ProviderSubscription<AsyncValue<List<MarketCandle>>>? _historySubscription;
  final ChartPriceViewportController _priceViewportController =
      ChartPriceViewportController();
  ChartPriceViewport _priceViewport = const ChartPriceViewport.auto();
  late MarketDataRequest _selectedRequest;
  int _requestGeneration = 0;
  _LastValidChartFrame? _lastValidFrame;
  ChartRenderSnapshot? _renderSnapshot;
  _ChartResolutionCacheKey? _resolutionCacheKey;
  List<MarketCandle> _resolvedHistoryPrefix = const <MarketCandle>[];
  List<MarketCandle> _resolvedAppendedActivePrefix = const <MarketCandle>[];
  List<MarketCandle> _selectedResolvedHistoryPrefix = const <MarketCandle>[];
  MarketCandle? _resolvedActiveTemplate;
  bool _scaleGestureWasPinch = false;
  bool _h4ExpandedScaleSeen = false;
  late bool _showXauH1HistoryBadge;
  late final AnimationController _panInertiaController;
  double _panAnimationPlotWidth = 0;
  int _panAnimationCandleCount = 0;
  int _viewportCandleCount = 1;
  double _latestMarketPrice = 0;
  double? _previousBid;
  double? _previousAsk;
  late Color _sellQuoteColor;
  late Color _buyQuoteColor;
  late final TextEditingController _volumeController;
  bool _volumeKeypadOpen = false;
  DemoPendingOrder? _pendingOrderForTap;
  int? _pendingTapPointer;
  int? _pendingScalePointer;
  int? _priceAxisPointer;
  final Set<int> _priceAxisSequencePointers = <int>{};
  bool _priceAxisScaleSuppressed = false;
  Offset? _priceAxisDragOrigin;
  Offset? _doubleTapPosition;
  Offset? _pendingTapOrigin;
  bool _pendingTapMoved = false;
  Timer? _chartLongPressTimer;
  Timer? _pendingSubtitleTimer;
  int? _chartLongPressPointer;
  Offset? _chartLongPressOrigin;
  final OverlayPortalController _transientPendingPortalController =
      OverlayPortalController(debugLabel: 'chart-pending-editor');
  Completer<void>? _transientPendingClosed;
  LocalHistoryEntry? _transientPendingHistoryEntry;
  DemoPendingOrder? _transientPendingOrder;
  bool _pendingOverlayClosing = false;
  bool _tradingCommandPending = false;
  bool _removeHistoryOnPendingClose = true;
  String? pendingOrderType;
  double? pendingOrderPrice;
  double? _focusedChartPrice;
  bool _showPendingLevelSubtitle = false;
  final Set<String> favoriteTimeframes = {
    'M1',
    'M5',
    'M15',
    'M30',
    'H1',
    'H4',
    'D1',
    'W1',
    'MN',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sellQuoteColor = widget.theme.ticketBlue;
    _buyQuoteColor = widget.theme.ticketBlue;
    timeframe = widget.initialTimeframe;
    _chartViewSessionController = ref.read(
      chartTimeframeSessionProvider.notifier,
    );
    final rememberedView = _chartViewSessionController.viewFor(widget.symbol);
    if (rememberedView?.timeframe == timeframe) {
      _viewport = rememberedView!.viewport;
      _priceViewport = rememberedView.priceViewport;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rememberChartView();
    });
    _selectedRequest = MarketDataRequest(widget.symbol, timeframe);
    final normalisedSymbol = _normaliseSymbol(widget.symbol);
    _showXauH1HistoryBadge =
        normalisedSymbol == 'XAUUSD' && widget.initialTimeframe == 'H1';
    _panInertiaController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        final next = _viewport
            .copyWith(scrollOffset: _panInertiaController.value)
            .bounded(
              plotWidth: _panAnimationPlotWidth,
              candleCount: _panAnimationCandleCount,
            );
        if (next == _viewport || !mounted) return;
        setState(() => _viewport = next);
      });
    _volumeController = TextEditingController(text: volume.toStringAsFixed(2));
    _listenToHistory(_selectedRequest, _requestGeneration);
  }

  @override
  void dispose() {
    _rememberChartView();
    WidgetsBinding.instance.removeObserver(this);
    _historySubscription?.close();
    _chartLongPressTimer?.cancel();
    _pendingSubtitleTimer?.cancel();
    _panInertiaController.dispose();
    _dismissTransientPendingOverlay();
    _volumeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _rememberChartView();
    }
  }

  String _normaliseSymbol(String symbol) =>
      symbol.endsWith('+') ? symbol.substring(0, symbol.length - 1) : symbol;

  bool _sameSymbol(String left, String right) =>
      _normaliseSymbol(left) == _normaliseSymbol(right);

  void _rememberChartView({ChartViewport? viewport}) {
    _chartViewSessionController.remember(
      widget.symbol,
      timeframe,
      viewport: viewport ?? _viewport,
      priceViewport: _priceViewport,
    );
  }

  // Video 2 is the canonical chart shell. Every symbol and timeframe keeps
  // the same toolbar/header/axis geometry; only the candle data changes.
  bool get _usesVideo2ChartLayout => true;

  ChartReferenceTheme get _theme => widget.theme;

  ThemeData _chartOverlayTheme() {
    final brightness = _theme.background.computeLuminance() > .5
        ? Brightness.light
        : Brightness.dark;
    final mutedForeground = _theme.foreground.withValues(alpha: .55);
    final disabledForeground = _theme.foreground.withValues(alpha: .38);
    final transparent = _theme.background.withValues(alpha: 0);
    Color overBackground(Color color, double alpha) =>
        Color.alphaBlend(color.withValues(alpha: alpha), _theme.background);
    final controlFill = Color.alphaBlend(
      _theme.foreground.withValues(alpha: .06),
      _theme.background,
    );
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: _theme.tradeBlue,
      onPrimary: _theme.background,
      primaryContainer: overBackground(_theme.tradeBlue, .16),
      onPrimaryContainer: _theme.foreground,
      primaryFixed: _theme.tradeBlue,
      primaryFixedDim: overBackground(_theme.tradeBlue, .72),
      onPrimaryFixed: _theme.background,
      onPrimaryFixedVariant: _theme.foreground,
      secondary: _theme.bullish,
      onSecondary: _theme.background,
      secondaryContainer: overBackground(_theme.bullish, .16),
      onSecondaryContainer: _theme.foreground,
      secondaryFixed: _theme.bullish,
      secondaryFixedDim: overBackground(_theme.bullish, .72),
      onSecondaryFixed: _theme.background,
      onSecondaryFixedVariant: _theme.foreground,
      tertiary: _theme.priceLine,
      onTertiary: _theme.background,
      tertiaryContainer: overBackground(_theme.priceLine, .16),
      onTertiaryContainer: _theme.foreground,
      tertiaryFixed: _theme.priceLine,
      tertiaryFixedDim: overBackground(_theme.priceLine, .72),
      onTertiaryFixed: _theme.background,
      onTertiaryFixedVariant: _theme.foreground,
      error: _theme.bearish,
      onError: _theme.background,
      errorContainer: overBackground(_theme.bearish, .16),
      onErrorContainer: _theme.foreground,
      surface: _theme.background,
      onSurface: _theme.foreground,
      surfaceDim: overBackground(_theme.foreground, .12),
      surfaceBright: _theme.background,
      surfaceContainerLowest: _theme.background,
      surfaceContainerLow: overBackground(_theme.foreground, .02),
      surfaceContainer: overBackground(_theme.foreground, .04),
      surfaceContainerHigh: overBackground(_theme.foreground, .06),
      surfaceContainerHighest: overBackground(_theme.foreground, .10),
      onSurfaceVariant: _theme.foreground.withValues(alpha: .72),
      outline: _theme.axisBorder,
      outlineVariant: _theme.axisBorder.withValues(alpha: .65),
      shadow: _theme.foreground.withValues(alpha: .24),
      scrim: _theme.foreground.withValues(alpha: .32),
      inverseSurface: _theme.foreground,
      onInverseSurface: _theme.background,
      inversePrimary: _theme.tradeBlue,
      surfaceTint: transparent,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: AppTypography.condensedFamily,
      splashColor: _theme.tradeBlue.withValues(alpha: .12),
      highlightColor: _theme.tradeBlue.withValues(alpha: .08),
      hoverColor: _theme.tradeBlue.withValues(alpha: .08),
      focusColor: _theme.tradeBlue.withValues(alpha: .12),
      disabledColor: disabledForeground,
    );
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: _theme.axisBorder),
    );
    final textButtonStyle = ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) return disabledForeground;
        return _theme.tradeBlue;
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused)) {
          return _theme.tradeBlue.withValues(alpha: .12);
        }
        if (states.contains(WidgetState.hovered)) {
          return _theme.tradeBlue.withValues(alpha: .08);
        }
        return transparent;
      }),
    );
    return base.copyWith(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _theme.background,
      canvasColor: _theme.background,
      cardColor: _theme.background,
      dividerColor: _theme.axisBorder,
      textTheme: base.textTheme.apply(
        bodyColor: _theme.foreground,
        displayColor: _theme.foreground,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        bodyColor: _theme.foreground,
        displayColor: _theme.foreground,
      ),
      iconTheme: IconThemeData(color: _theme.foreground),
      primaryIconTheme: IconThemeData(color: _theme.foreground),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _theme.background,
        modalBackgroundColor: _theme.background,
        surfaceTintColor: transparent,
        modalBarrierColor: _theme.foreground.withValues(alpha: .32),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _theme.background,
        surfaceTintColor: transparent,
        barrierColor: _theme.foreground.withValues(alpha: .32),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: _theme.foreground,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: _theme.foreground,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: _theme.foreground,
        textColor: _theme.foreground,
        tileColor: _theme.background,
        selectedColor: _theme.tradeBlue,
        selectedTileColor: overBackground(_theme.tradeBlue, .08),
        titleTextStyle: base.textTheme.bodyLarge?.copyWith(
          color: _theme.foreground,
        ),
        subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: mutedForeground,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: controlFill,
        labelStyle: TextStyle(color: mutedForeground),
        hintStyle: TextStyle(color: mutedForeground),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: _theme.axisBorder.withValues(alpha: .45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _theme.tradeBlue, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _theme.bearish),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _theme.bearish, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: textButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: textButtonStyle.copyWith(
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            final color = states.contains(WidgetState.disabled)
                ? _theme.axisBorder.withValues(alpha: .45)
                : _theme.axisBorder;
            return BorderSide(color: color);
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: textButtonStyle.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return disabledForeground;
            }
            return _theme.foreground;
          }),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: _theme.tradeBlue,
        selectionColor: _theme.tradeBlue.withValues(alpha: .24),
        selectionHandleColor: _theme.tradeBlue,
      ),
    );
  }

  void _selectTimeframe(String period, {bool closeFavorites = true}) {
    final requestChanged = period != timeframe;
    final nextRequest = requestChanged
        ? MarketDataRequest(widget.symbol, period)
        : _selectedRequest;
    final cachedFrame = requestChanged ? _readCachedFrame(nextRequest) : null;
    if (requestChanged) {
      _panInertiaController.stop();
    }
    setState(() {
      if (requestChanged) {
        timeframe = period;
        _selectedRequest = nextRequest;
        _requestGeneration++;
        if (cachedFrame != null) _lastValidFrame = cachedFrame;
        _viewport = ChartViewport(barSpacing: _viewport.barSpacing);
        _priceViewport = const ChartPriceViewport.auto();
        _h4ExpandedScaleSeen = false;
        _showXauH1HistoryBadge =
            _normaliseSymbol(widget.symbol) == 'XAUUSD' && period == 'H1';
        _focusedChartPrice = null;
        crosshairPosition = null;
        measurementStart = null;
        measurementEnd = null;
        _chartPointers.clear();
        _viewportPointers.clear();
        _priceAxisPointer = null;
        _priceAxisDragOrigin = null;
      }
      if (closeFavorites) showTimeframes = false;
    });
    if (requestChanged) {
      _rememberChartView();
      _listenToHistory(_selectedRequest, _requestGeneration);
    }
  }

  _LastValidChartFrame? _readCachedFrame(MarketDataRequest request) {
    final cached = ref.read(marketCandleHistoryCacheProvider)[request];
    if (cached == null || cached.isEmpty) return null;
    final liveProvider = liveMarketCandlesProvider(request);
    final notifier = ref.read(liveProvider.notifier);
    notifier.seedHistory(cached);
    final latestQuote = ref.read(demoQuoteProvider(widget.symbol)).value;
    if (latestQuote != null) {
      notifier.applyTick(
        price: latestQuote.bid,
        receivedAt: ref.read(marketClockProvider)(),
      );
    }
    final candleState = ref.read(liveProvider);
    if (!candleState.hasHistorySnapshot || candleState.candles.isEmpty) {
      return null;
    }
    return _LastValidChartFrame(request: request, candleState: candleState);
  }

  void _listenToHistory(MarketDataRequest request, int generation) {
    final retiringSubscription = _historySubscription;
    _historySubscription = ref.listenManual<AsyncValue<List<MarketCandle>>>(
      marketCandlesProvider(request),
      (previous, next) {
        next.whenData(
          (history) => scheduleMicrotask(
            () => _acceptHistoryFrame(
              request: request,
              generation: generation,
              history: history,
            ),
          ),
        );
      },
      fireImmediately: true,
    );
    if (retiringSubscription != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => retiringSubscription.close(),
      );
    }
  }

  void _acceptHistoryFrame({
    required MarketDataRequest request,
    required int generation,
    required List<MarketCandle> history,
  }) {
    if (!mounted ||
        history.isEmpty ||
        generation != _requestGeneration ||
        request != _selectedRequest) {
      return;
    }
    final liveProvider = liveMarketCandlesProvider(request);
    final beforeSeed = ref.read(liveProvider);
    final notifier = ref.read(liveProvider.notifier);
    notifier.seedHistory(history);
    final reconciled = ref.read(liveProvider);
    if (identical(beforeSeed, reconciled) || reconciled.candles.isEmpty) return;
    setState(() {
      if (generation == _requestGeneration && request == _selectedRequest) {
        _lastValidFrame = _LastValidChartFrame(
          request: request,
          candleState: reconciled,
        );
      }
    });
  }

  void _setVolume(double value) {
    final next = value.clamp(.01, 100000.0);
    setState(() {
      volume = next;
      _volumeController.text = next.toStringAsFixed(2);
    });
  }

  void _updateVolumeFromText(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    volume = parsed.clamp(.01, 100000.0);
  }

  void _appendVolumeKey(String key) {
    if (key == ',') {
      if (_volumeController.text.contains('.') ||
          _volumeController.text.contains(',')) {
        return;
      }
    }
    final next = key == ','
        ? '${_volumeController.text.isEmpty ? '0' : _volumeController.text}.'
        : _volumeController.text == '0'
        ? key
        : '${_volumeController.text}$key';
    if (next.length > 9) return;
    setState(() {
      _volumeController.text = next;
      _updateVolumeFromText(next);
    });
  }

  void _removeVolumeKey() {
    if (_volumeController.text.isEmpty) return;
    final next = _volumeController.text.substring(
      0,
      _volumeController.text.length - 1,
    );
    setState(() {
      _volumeController.text = next;
      _updateVolumeFromText(next);
    });
  }

  void _commitVolumeInput() {
    final parsed = double.tryParse(_volumeController.text.replaceAll(',', '.'));
    final next = parsed == null || parsed <= 0
        ? volume
        : parsed.clamp(.01, 100000.0);
    volume = next;
    _volumeController.text = next.toStringAsFixed(2);
  }

  Future<void> _openVolumeKeypad() async {
    if (_volumeKeypadOpen) return;
    setState(() => _volumeKeypadOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: false,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ChartNumericKeypad(
        theme: _theme,
        onKey: _appendVolumeKey,
        onBackspace: _removeVolumeKey,
      ),
    );
    if (!mounted) return;
    setState(() {
      _commitVolumeInput();
      _volumeKeypadOpen = false;
      showOneClickTrading = false;
    });
  }

  void _updateCrosshairPointers() {
    if (!crosshairEnabled || _chartPointers.isEmpty) return;
    final points = _chartPointers.values.toList(growable: false);
    setState(() {
      crosshairPosition = points.last;
      if (points.length >= 2) {
        measurementStart = points.first;
        measurementEnd = points[1];
      } else {
        measurementStart = null;
        measurementEnd = null;
      }
    });
  }

  void _handleChartPointerDown(PointerDownEvent event) {
    if (_priceAxisSequencePointers.isNotEmpty) {
      _priceAxisSequencePointers.add(event.pointer);
      return;
    }
    if (_showXauH1HistoryBadge && !crosshairEnabled) {
      setState(() => _showXauH1HistoryBadge = false);
    }
    if (!crosshairEnabled) {
      if (_priceAxisPointer == null &&
          _viewportPointers.isEmpty &&
          _pendingTapPointer == null &&
          _chartHitTargets.priceAxisRect.contains(event.localPosition)) {
        _panInertiaController.stop();
        _priceAxisPointer = event.pointer;
        _priceAxisSequencePointers.add(event.pointer);
        _priceAxisScaleSuppressed = true;
        _priceAxisDragOrigin = event.localPosition;
        _priceViewportController.beginDrag(
          viewport: _priceViewport,
          focalY: event.localPosition.dy,
          priceTop: _chartHitTargets.priceTop,
          priceHeight: _chartHitTargets.priceHeight,
          displayedRange: ChartPriceRange(
            minPrice: _chartHitTargets.minPrice,
            maxPrice: _chartHitTargets.maxPrice,
          ),
        );
        return;
      }
      final pendingLineY = _chartHitTargets.pendingOrderY;
      final hitPendingLine =
          pendingLineY != null &&
          event.localPosition.dx <= _chartHitTargets.chartWidth &&
          (event.localPosition.dy - pendingLineY).abs() <= 18;
      if ((_pendingOrderForTap != null || pendingOrderPrice != null) &&
          _pendingTapPointer == null &&
          hitPendingLine) {
        _pendingTapPointer = event.pointer;
        _pendingScalePointer = event.pointer;
        _pendingTapOrigin = event.localPosition;
        _pendingTapMoved = false;
        return;
      }
      _viewportPointers[event.pointer] = event.localPosition;
      if (_viewportPointers.length >= 2) {
        _cancelChartLongPress();
        final points = _viewportPointers.values.take(2).toList(growable: false);
        final focalPoint = (points[0].dx + points[1].dx) / 2;
        _viewportController.beginScale(
          viewport: _viewport,
          focalPoint: focalPoint,
          plotWidth: math.max(0.0, _chartHitTargets.chartWidth),
          candleCount: _viewportCandleCount,
        );
        _scaleGestureWasPinch = true;
        return;
      }
      if (_chartLongPressPointer != null) {
        _cancelChartLongPress();
        return;
      }
      _chartLongPressPointer = event.pointer;
      _chartLongPressOrigin = event.localPosition;
      _chartLongPressTimer = Timer(const Duration(milliseconds: 520), () {
        if (!mounted || _chartLongPressPointer != event.pointer) return;
        final touchPosition = _chartLongPressOrigin;
        _cancelChartLongPress();
        if (touchPosition != null) {
          _beginPendingOrderFromChart(touchPosition);
        }
      });
      return;
    }
    _chartPointers[event.pointer] = event.localPosition;
    _updateCrosshairPointers();
  }

  void _handleChartPointerMove(PointerMoveEvent event) {
    if (_priceAxisSequencePointers.contains(event.pointer)) {
      if (_priceAxisPointer != event.pointer || crosshairEnabled) return;
      final origin = _priceAxisDragOrigin;
      if (origin == null) return;
      final next = _priceViewportController.updateDrag(
        deltaY: event.localPosition.dy - origin.dy,
      );
      if (next != _priceViewport) {
        setState(() => _priceViewport = next);
      }
      return;
    }
    if (!crosshairEnabled) {
      if (_viewportPointers.containsKey(event.pointer)) {
        _viewportPointers[event.pointer] = event.localPosition;
      }
      if (_chartLongPressPointer == event.pointer &&
          _chartLongPressOrigin != null &&
          (event.localPosition - _chartLongPressOrigin!).distance > 8) {
        _cancelChartLongPress();
      }
      if (_pendingTapPointer == event.pointer &&
          _pendingTapOrigin != null &&
          (event.localPosition - _pendingTapOrigin!).distance > 8) {
        _pendingTapMoved = true;
        if (pendingOrderPrice != null) {
          final price = _pendingPriceAt(event.localPosition.dy);
          if (price != pendingOrderPrice) {
            setState(() {
              pendingOrderPrice = price;
              _focusedChartPrice = null;
            });
          }
        }
      }
      return;
    }
    if (!_chartPointers.containsKey(event.pointer)) return;
    _chartPointers[event.pointer] = event.localPosition;
    _updateCrosshairPointers();
  }

  void _handleChartPointerEnd(PointerEvent event) {
    if (_priceAxisSequencePointers.remove(event.pointer)) {
      if (_priceAxisPointer == event.pointer) {
        _priceAxisPointer = null;
        _priceAxisDragOrigin = null;
      }
      if (_priceAxisSequencePointers.isEmpty) {
        _rememberChartView();
        Future<void>.microtask(() {
          if (_priceAxisSequencePointers.isEmpty) {
            _priceAxisScaleSuppressed = false;
          }
        });
      }
      return;
    }
    if (!crosshairEnabled) {
      _viewportPointers.remove(event.pointer);
      if (_chartLongPressPointer == event.pointer) {
        _cancelChartLongPress();
      }
      if (_pendingTapPointer != event.pointer) return;
      final order = _pendingOrderForTap;
      final shouldOpen = !_pendingTapMoved && order != null;
      _pendingTapPointer = null;
      _pendingTapOrigin = null;
      _pendingTapMoved = false;
      final pendingScalePointer = event.pointer;
      Future<void>.microtask(() {
        if (_pendingScalePointer == pendingScalePointer) {
          _pendingScalePointer = null;
        }
      });
      if (shouldOpen) {
        Future<void>.microtask(() {
          if (mounted) _showPendingOrderPanel(order);
        });
      }
      return;
    }
    _chartPointers.remove(event.pointer);
    if (_chartPointers.isEmpty) {
      setState(() {
        measurementStart = null;
        measurementEnd = null;
      });
      return;
    }
    _updateCrosshairPointers();
  }

  void _cancelChartLongPress() {
    _chartLongPressTimer?.cancel();
    _chartLongPressTimer = null;
    _chartLongPressPointer = null;
    _chartLongPressOrigin = null;
  }

  double _pendingPriceAt(double localY) {
    final chartHeight = math.max(1.0, _chartHitTargets.chartHeight);
    final priceTop = _chartHitTargets.priceTop;
    final priceHeight = math.max(1.0, _chartHitTargets.priceHeight);
    final range = _chartHitTargets.maxPrice - _chartHitTargets.minPrice;
    final mappedPrice = range > 0
        ? _chartHitTargets.maxPrice -
              ((localY.clamp(priceTop, chartHeight) - priceTop) / priceHeight) *
                  range
        : _latestMarketPrice * .9988;
    return double.parse(mappedPrice.toStringAsFixed(2));
  }

  void _showPendingSubtitleTemporarily() {
    _pendingSubtitleTimer?.cancel();
    if (!mounted) return;
    setState(() => _showPendingLevelSubtitle = true);
    _pendingSubtitleTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _showPendingLevelSubtitle = false);
    });
  }

  String _format(double value) {
    if (value >= 1000) return value.toStringAsFixed(2);
    if (value >= 100) return value.toStringAsFixed(3);
    return value.toStringAsFixed(5);
  }

  List<MarketCandle> _alignCandlesToQuote(
    List<MarketCandle> source,
    double price,
  ) {
    if (source.isEmpty) return source;
    final anchor = source.last.close;
    if (!widget.symbol.startsWith('XAU')) {
      final comparisonScale = math.max(
        1.0,
        math.max(anchor.abs(), price.abs()),
      );
      final domainMismatch =
          !anchor.isFinite ||
          anchor == 0 ||
          (anchor - price).abs() / comparisonScale > .25;
      if (!domainMismatch) return source;

      // Demo quotes and downloaded history can come from different providers.
      // Keep the provider's candle contour intact and move the entire series
      // into the quote's price domain instead of stretching one huge bar.
      final offset = price - anchor;
      return [
        for (final candle in source)
          MarketCandle(
            time: candle.time,
            open: candle.open + offset,
            high: candle.high + offset,
            low: candle.low + offset,
            close: candle.close + offset,
          ),
      ];
    }
    final referenceWindow = source.sublist(math.max(0, source.length - 41));
    final upperRange = math.max(
      .01,
      referenceWindow.map((candle) => candle.high - anchor).reduce(math.max),
    );
    final lowerRange = math.max(
      .01,
      referenceWindow.map((candle) => anchor - candle.low).reduce(math.max),
    );
    double aligned(double value) {
      final difference = value - anchor;
      return difference >= 0
          ? price + difference / upperRange * 33
          : price + difference / lowerRange * 29;
    }

    return [
      for (final candle in source)
        MarketCandle(
          time: candle.time,
          open: aligned(candle.open),
          high: aligned(candle.high),
          low: aligned(candle.low),
          close: aligned(candle.close),
        ),
    ];
  }

  List<MarketCandle> _resolveRenderCandles({
    required MarketDataRequest frameRequest,
    required LiveMarketCandleState candleState,
    required List<MarketCandle> sourceCandles,
    required List<MarketCandle> settledLiveTail,
    required bool useRealtimeCandles,
    required double referencePrice,
    required double currentPrice,
    required bool loadingPlaceholder,
  }) {
    final key = (
      request: frameRequest,
      historyRevision: candleState.historyRevision,
      useRealtimeCandles: useRealtimeCandles,
      symbol: widget.symbol,
      timeframe: frameRequest.timeframe,
      referencePrice: referencePrice,
      loadingPlaceholder: loadingPlaceholder,
      sourceLength: sourceCandles.length,
      settledLiveLength: settledLiveTail.length,
      settledLiveIdentity: settledLiveTail,
      referencePriceBand: currentPrice >= 1000 && currentPrice < 10000,
    );
    if (_resolutionCacheKey != key) {
      ChartRenderSnapshot.recordFullHistoryResolution();
      final alignedSource = useRealtimeCandles
          ? sourceCandles
          : _alignCandlesToQuote(sourceCandles, currentPrice);
      final resolved = ChartCandleResolver(
        symbol: widget.symbol,
        referencePrice: referencePrice,
        currentPrice: currentPrice,
        timeframe: frameRequest.timeframe,
        loadingPlaceholder: loadingPlaceholder,
        useRealtimeCandles: useRealtimeCandles,
      ).resolve(alignedSource, settledLiveTail);
      final frozenResolved = List<MarketCandle>.unmodifiable(resolved);
      _resolvedHistoryPrefix = _ImmutableCandleRange(
        frozenResolved,
        0,
        frozenResolved.isEmpty ? 0 : frozenResolved.length - 1,
      );
      _resolvedAppendedActivePrefix = _ImmutableCandleRange(
        frozenResolved,
        frozenResolved.length >= 360 ? 1 : 0,
        frozenResolved.length,
      );
      _resolvedActiveTemplate = frozenResolved.isEmpty
          ? null
          : frozenResolved.last;
      _resolutionCacheKey = key;
    }
    final liveActive = candleState.activeCandleIsLive
        ? candleState.activeCandle
        : null;
    var prefix = _resolvedHistoryPrefix;
    MarketCandle? active;
    if (liveActive == null || _resolvedActiveTemplate == null) {
      active = useRealtimeCandles
          ? _liveCandleAtPrice(
              candleState.activeCandle ?? _resolvedActiveTemplate,
              currentPrice,
            )
          : _activeCandleAtPrice(_resolvedActiveTemplate, currentPrice);
    } else {
      final template = _resolvedActiveTemplate!;
      final liveTime = template.time.isUtc
          ? liveActive.time.toUtc()
          : liveActive.time.toLocal();
      final templateBucket = MarketDataService.bucketStart(
        template.time,
        frameRequest.timeframe,
      );
      final liveBucket = MarketDataService.bucketStart(
        liveTime,
        frameRequest.timeframe,
      );
      if (liveBucket.isAfter(templateBucket)) {
        prefix = _resolvedAppendedActivePrefix;
        active = _liveCandleAtPrice(liveActive, currentPrice);
      } else if (liveBucket == templateBucket) {
        active = _liveCandleAtPrice(
          MarketCandle(
            time: templateBucket,
            open: template.open,
            high: math.max(template.high, liveActive.high),
            low: math.min(template.low, liveActive.low),
            close: liveActive.close,
            volume: liveActive.volume,
          ),
          currentPrice,
        );
      } else {
        active = _liveCandleAtPrice(template, currentPrice);
      }
    }
    _selectedResolvedHistoryPrefix = prefix;
    return _ImmutableRenderCandleSeries(prefix, active);
  }

  MarketCandle? _liveCandleAtPrice(MarketCandle? candle, double currentPrice) {
    if (candle == null) return null;
    return MarketCandle(
      time: candle.time,
      open: candle.open,
      high: math.max(candle.high, currentPrice),
      low: math.min(candle.low, currentPrice),
      close: currentPrice,
      volume: candle.volume,
    );
  }

  MarketCandle? _activeCandleAtPrice(
    MarketCandle? template,
    double currentPrice,
  ) {
    if (template == null) return null;
    final upperWick = math.max(
      0.0,
      template.high - math.max(template.open, template.close),
    );
    final lowerWick = math.max(
      0.0,
      math.min(template.open, template.close) - template.low,
    );
    return MarketCandle(
      time: template.time,
      open: template.open,
      high: math.max(template.open, currentPrice) + upperWick,
      low: math.min(template.open, currentPrice) - lowerWick,
      close: currentPrice,
      volume: template.volume,
    );
  }

  List<Object?> _renderOverlayValues({
    required List<DemoPosition> positions,
    required List<DemoPendingOrder> pendingOrders,
    required Set<String> indicators,
    required List<DemoChartObject> chartObjects,
    required DemoPendingOrder? activePendingOrder,
  }) => <Object?>[
    crosshairEnabled,
    crosshairPosition,
    measurementStart,
    measurementEnd,
    for (final position in positions) ...<Object?>[
      position.id,
      position.symbol,
      position.side,
      position.volume,
      position.openPrice,
      position.currentPrice,
      position.profit,
      position.stopLoss,
      position.takeProfit,
    ],
    null,
    for (final order in pendingOrders) ...<Object?>[
      order.id,
      order.symbol,
      order.side,
      order.type,
      order.volume,
      order.price,
      order.stopLoss,
      order.takeProfit,
      order.createdAt,
      order.status,
    ],
    null,
    ...indicators.toList(growable: false)..sort(),
    null,
    for (final object in chartObjects) ...<Object?>[
      object.id,
      object.type,
      object.visible,
      object.locked,
    ],
    activePendingOrder?.type ?? pendingOrderType,
    activePendingOrder?.price ?? pendingOrderPrice,
    activePendingOrder?.volume ?? volume,
    activePendingOrder == null ? pendingStopLoss : activePendingOrder.stopLoss,
    activePendingOrder == null
        ? pendingTakeProfit
        : activePendingOrder.takeProfit,
    _focusedChartPrice,
    showOneClickTrading && !showTimeframes,
    _h4ExpandedScaleSeen,
    _showXauH1HistoryBadge,
  ];

  @override
  Widget build(BuildContext context) {
    // Warm every canonical timeframe for the active symbol. This is
    // fire-and-forget from the UI perspective and shares provider instances
    // with the selected timeframe, so it neither blocks paint nor duplicates
    // an in-flight history request.
    ref.listen<AsyncValue<void>>(
      chartSymbolMarketWarmupProvider(widget.symbol),
      (previous, next) {},
    );
    final availableQuotes = ref.watch(demoQuotesProvider);
    final initial = availableQuotes.firstWhere(
      (quote) => _sameSymbol(quote.symbol, widget.symbol),
      orElse: () => availableQuotes.first,
    );
    final usesRealtimeMarket = ref.watch(marketApiConfigProvider).enabled;
    return OverlayPortal(
      controller: _transientPendingPortalController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (overlayContext) {
        final order = _transientPendingOrder;
        if (order == null) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: _pendingOverlayClosing ? 0 : 1,
              end: _pendingOverlayClosing ? 1 : 0,
            ),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            onEnd: () {
              if (_pendingOverlayClosing) {
                _dismissTransientPendingOverlay(
                  removeHistoryEntry: _removeHistoryOnPendingClose,
                );
              }
            },
            builder: (context, progress, child) => Transform.translate(
              offset: Offset(0, 81 * progress),
              child: child,
            ),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                key: const Key('chart-transient-pending-sheet'),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: ColoredBox(
                    color: Color.alphaBlend(
                      _theme.foreground.withValues(alpha: .1),
                      _theme.background,
                    ),
                    child: _buildPendingOrderPanel(
                      overlayContext,
                      order,
                      transient: true,
                      onCollapse: _beginDismissTransientPendingOverlay,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _theme.background,
        drawer: const TradingDrawer(),
        appBar: _buildAppBar(),
        body: Consumer(
          child: ColoredBox(
            key: const Key('chart-light-surface'),
            color: _theme.background,
          ),
          builder: (context, bodyRef, staticBackdrop) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              staticBackdrop!,
              _buildReactiveBody(
                context,
                bodyRef,
                initial: initial,
                usesRealtimeMarket: usesRealtimeMarket,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactiveBody(
    BuildContext context,
    WidgetRef ref, {
    required DemoQuote initial,
    required bool usesRealtimeMarket,
  }) {
    final request = _selectedRequest;
    final requestGeneration = _requestGeneration;
    final quoteProvider = demoQuoteProvider(widget.symbol);
    final selectedQuote = ref.watch(
      quoteProvider.select((state) {
        final value = state.value;
        return value == null
            ? null
            : (
                bid: value.bid,
                ask: value.ask,
                changePercent: value.changePercent,
              );
      }),
    );
    final latestQuote = ref.read(quoteProvider).value;
    final quote = selectedQuote == null
        ? initial
        : DemoQuote(
            symbol: widget.symbol,
            name: latestQuote?.name ?? initial.name,
            bid: selectedQuote.bid,
            ask: selectedQuote.ask,
            changePercent: selectedQuote.changePercent,
            sourceTimestamp: latestQuote?.sourceTimestamp,
          );
    ref.listen<AsyncValue<DemoQuote>>(quoteProvider, (previous, next) {
      next.whenData((liveQuote) {
        if (requestGeneration != _requestGeneration ||
            request != _selectedRequest) {
          return;
        }
        final receivedAt =
            liveQuote.sourceTimestamp ?? ref.read(marketClockProvider)();
        ref
            .read(liveMarketCandlesProvider(request).notifier)
            .applyTick(price: liveQuote.bid, receivedAt: receivedAt);
        ref
            .read(demoTradingProvider.notifier)
            .updateMarketPrice(
              symbol: widget.symbol,
              bid: liveQuote.bid,
              ask: liveQuote.ask,
            );
      });
    });
    ref.listen<AsyncValue<MarketCandle>>(realtimeCandleProvider(request), (
      previous,
      next,
    ) {
      next.whenData((candle) {
        if (requestGeneration != _requestGeneration ||
            request != _selectedRequest) {
          return;
        }
        ref
            .read(liveMarketCandlesProvider(request).notifier)
            .applyRemoteCandle(
              candle,
              receivedAt: ref.read(marketClockProvider)(),
            );
      });
    });
    final liveProvider = liveMarketCandlesProvider(request);
    ref.watch(
      liveProvider.select(
        (state) => (state.historyRevision, state.liveCandleRevision),
      ),
    );
    final liveCandleState = ref.read(liveProvider);
    const loadingPlaceholder = false;
    final marketPrice = quote.bid;
    // Resolution is cached by history/request semantics so quote ticks only
    // replace the active candle instead of reprocessing the settled series.
    var visibleFrame = _lastValidFrame;
    if (visibleFrame?.request == request &&
        liveCandleState.hasHistorySnapshot &&
        liveCandleState.candles.isNotEmpty) {
      visibleFrame = _LastValidChartFrame(
        request: request,
        candleState: liveCandleState,
      );
      _lastValidFrame = visibleFrame;
    }
    final frameCandles = visibleFrame?.candles ?? const <MarketCandle>[];
    final settledLiveTail = visibleFrame == null
        ? liveCandleState.settledLiveTail
        : const <MarketCandle>[];
    final renderCandleState = visibleFrame?.candleState ?? liveCandleState;
    final frameRequest = visibleFrame?.request ?? request;
    final frameTimeframe = frameRequest.timeframe;
    final useRealtimeCandles = usesRealtimeMarket && visibleFrame != null;
    final candles = _resolveRenderCandles(
      frameRequest: frameRequest,
      candleState: renderCandleState,
      sourceCandles: frameCandles,
      settledLiveTail: settledLiveTail,
      useRealtimeCandles: useRealtimeCandles,
      referencePrice: initial.bid,
      currentPrice: marketPrice,
      loadingPlaceholder: loadingPlaceholder,
    );
    // Quote ticks are the single live source for the trading panel, active
    // candle and current-price line. Historical candles provide context.
    final tickTime =
        liveCandleState.lastTickAt ?? ref.read(marketClockProvider)();
    _latestMarketPrice = marketPrice;
    if (_previousBid != null && quote.bid != _previousBid) {
      _sellQuoteColor = quote.bid > _previousBid!
          ? _theme.ticketBlue
          : _theme.bearish;
    }
    if (_previousAsk == null) {
      _buyQuoteColor = _sellQuoteColor;
    } else if (quote.ask != _previousAsk) {
      _buyQuoteColor = quote.ask > _previousAsk!
          ? _theme.ticketBlue
          : _theme.bearish;
    }
    _previousBid = quote.bid;
    _previousAsk = quote.ask;
    final quotedSpread = quote.ask - quote.bid;
    final spread = quotedSpread > 0
        ? quotedSpread
        : _minimumSpread(marketPrice);
    final positionsProjection = ref.watch(
      demoPositionsProvider.select(
        (items) => _RenderProjection<DemoPosition, _PositionRenderValue>(
          items.where(
            (position) => _sameSymbol(position.symbol, widget.symbol),
          ),
          (position) => (
            id: position.id,
            symbol: position.symbol,
            side: position.side,
            volume: position.volume,
            openPrice: position.openPrice,
            currentPrice: position.currentPrice,
            profit: position.profit,
            stopLoss: position.stopLoss,
            takeProfit: position.takeProfit,
            openedAt: position.openedAt,
          ),
        ),
      ),
    );
    final positions = positionsProjection.items;
    final pendingOrdersProjection = ref.watch(
      demoPendingOrdersProvider.select(
        (items) =>
            _RenderProjection<DemoPendingOrder, _PendingOrderRenderValue>(
              items.where((order) => _sameSymbol(order.symbol, widget.symbol)),
              (order) => (
                id: order.id,
                symbol: order.symbol,
                side: order.side,
                type: order.type,
                volume: order.volume,
                price: order.price,
                stopLoss: order.stopLoss,
                takeProfit: order.takeProfit,
                createdAt: order.createdAt,
                status: order.status,
              ),
            ),
      ),
    );
    final pendingOrders = pendingOrdersProjection.items;
    final activePendingOrder = pendingOrders.firstOrNull;
    _pendingOrderForTap = activePendingOrder;
    final hasPendingLevel =
        pendingOrderPrice != null || activePendingOrder != null;
    final chartSubtitle = _showPendingLevelSubtitle
        ? 'Hien thi muc do giao dich'
        : initial.name;
    final chartTimeframeLabel = timeframe;
    final indicators = ref.watch(chartIndicatorsVisibilityProvider)
        ? ref.watch(chartIndicatorsProvider)
        : const <String>{};
    final chartObjects = ref
        .watch(chartObjectsProvider)
        .where((object) => object.visible)
        .toList(growable: false);
    final renderSnapshot = ChartRenderSnapshot.evolve(
      previous: _renderSnapshot,
      history: renderCandleState.history,
      liveTail: renderCandleState.liveTail,
      resolvedCandles: candles,
      historyRevision: renderCandleState.historyRevision,
      liveCandleRevision: renderCandleState.liveCandleRevision,
      historyIdentity: (
        visibleFrame?.request ?? request,
        renderCandleState.historyRevision,
        _selectedResolvedHistoryPrefix,
      ),
      viewport: _viewport,
      priceViewport: _priceViewport,
      overlayValues: _renderOverlayValues(
        positions: positions,
        pendingOrders: pendingOrders,
        indicators: indicators,
        chartObjects: chartObjects,
        activePendingOrder: activePendingOrder,
      ),
      theme: _theme,
    );
    _renderSnapshot = renderSnapshot;
    final chartPainter = Mt5CandlePainter(
      snapshot: renderSnapshot,
      symbol: widget.symbol,
      referencePrice: initial.bid,
      currentPrice: marketPrice,
      tickTime: tickTime,
      crosshairEnabled: crosshairEnabled,
      crosshairPosition: crosshairPosition,
      measurementStart: measurementStart,
      measurementEnd: measurementEnd,
      timeframe: frameTimeframe,
      positions: positions,
      pendingOrders: pendingOrders,
      indicators: indicators,
      chartObjects: chartObjects,
      pendingOrderType: activePendingOrder?.type ?? pendingOrderType,
      pendingOrderPrice: activePendingOrder?.price ?? pendingOrderPrice,
      pendingOrderVolume: activePendingOrder?.volume ?? volume,
      pendingStopLoss: activePendingOrder == null
          ? pendingStopLoss
          : activePendingOrder.stopLoss,
      pendingTakeProfit: activePendingOrder == null
          ? pendingTakeProfit
          : activePendingOrder.takeProfit,
      focusedChartPrice: _focusedChartPrice,
      loadingPlaceholder: loadingPlaceholder,
      oneClickTrading: showOneClickTrading && !showTimeframes,
      h4ExpandedScaleSeen: _h4ExpandedScaleSeen,
      showHistoryBadge: _showXauH1HistoryBadge && frameTimeframe == 'H1',
      useRealtimeCandles: useRealtimeCandles,
      hitTargets: _chartHitTargets,
    );
    final viewportCandleCount = math.max(
      1,
      chartPainter.debugResolvedCandles.length,
    );
    _viewportCandleCount = viewportCandleCount;
    final usesM1ReferenceTypography =
        _normaliseSymbol(widget.symbol) == 'XAUUSD' && frameTimeframe == 'M1';
    final navigationOverlap =
        usesM1ReferenceTypography ||
            widget.layoutProfile == ChartLayoutProfile.tabReferenceCapture
        ? _chartNavigationOverlap
        : 0.0;
    return Padding(
      padding: EdgeInsets.only(
        bottom: math.max(
          0,
          MediaQuery.paddingOf(context).bottom - navigationOverlap,
        ),
      ),
      child: Stack(
        children: [
          if (showOneClickTrading && !showTimeframes)
            Positioned(
              key: const Key('chart-one-click-panel'),
              left: 0,
              right: 0,
              top: 0,
              height: _oneClickPanelHeight,
              child: ColoredBox(
                color: _theme.background,
                child: Row(
                  children: [
                    SizedBox(
                      width: 118,
                      child: _TradeQuote(
                        theme: _theme,
                        label: 'SELL',
                        price: _format(marketPrice),
                        color: _sellQuoteColor,
                        onTap: () => _placeChartOrder('SELL', marketPrice),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: _oneClickPanelHeight,
                        child: ColoredBox(
                          color: _theme.background,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 40,
                                    height: _oneClickPanelHeight,
                                  ),
                                  onPressed: volume <= .01
                                      ? null
                                      : () => _setVolume(volume - .01),
                                  icon: Transform.translate(
                                    offset: const Offset(0, -.6666666667),
                                    child: Icon(
                                      CupertinoIcons.chevron_down,
                                      color: _theme.foreground,
                                      size: 12,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 48,
                                  child: _OneClickVolumeField(
                                    theme: _theme,
                                    key: const Key(
                                      'chart-one-click-volume-field',
                                    ),
                                    value: _volumeController.text,
                                    active: _volumeKeypadOpen,
                                    onTap: _openVolumeKeypad,
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 40,
                                    height: _oneClickPanelHeight,
                                  ),
                                  onPressed: () => _setVolume(volume + .01),
                                  icon: Transform.translate(
                                    offset: const Offset(0, -.6666666667),
                                    child: Icon(
                                      CupertinoIcons.chevron_up,
                                      color: _theme.foreground,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 118,
                      child: _TradeQuote(
                        theme: _theme,
                        label: 'Buy',
                        price: _format(marketPrice + spread),
                        color: _buyQuoteColor,
                        onTap: () =>
                            _placeChartOrder('BUY', marketPrice + spread),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned.fill(
            child: ClipRect(
              clipper: showOneClickTrading && !showTimeframes
                  ? const _TopInsetRectClipper(_oneClickPanelHeight)
                  : null,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: Listener(
                        key: const Key('chart-gesture-area'),
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _handleChartPointerDown,
                        onPointerMove: _handleChartPointerMove,
                        onPointerUp: _handleChartPointerEnd,
                        onPointerCancel: _handleChartPointerEnd,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: crosshairEnabled
                              ? (details) => setState(
                                  () =>
                                      crosshairPosition = details.localPosition,
                                )
                              : null,
                          onScaleStart: (details) {
                            if (crosshairEnabled ||
                                _priceAxisScaleSuppressed ||
                                _pendingScalePointer != null) {
                              return;
                            }
                            _panInertiaController.stop();
                            final plotWidth = math.max(
                              0.0,
                              _chartHitTargets.chartWidth,
                            );
                            if (_viewportPointers.length < 2) {
                              _viewportController.beginScale(
                                viewport: _viewport,
                                focalPoint: details.localFocalPoint.dx,
                                plotWidth: plotWidth,
                                candleCount: viewportCandleCount,
                              );
                              _scaleGestureWasPinch = false;
                            }
                            if (_showXauH1HistoryBadge) {
                              setState(() => _showXauH1HistoryBadge = false);
                            }
                          },
                          onScaleUpdate: (details) {
                            if (crosshairEnabled ||
                                _priceAxisScaleSuppressed ||
                                _pendingScalePointer != null) {
                              return;
                            }
                            final plotWidth = math.max(
                              0.0,
                              _chartHitTargets.chartWidth,
                            );
                            if (details.pointerCount > 1 &&
                                !_scaleGestureWasPinch) {
                              _viewportController.beginScale(
                                viewport: _viewport,
                                focalPoint: details.localFocalPoint.dx,
                                plotWidth: plotWidth,
                                candleCount: viewportCandleCount,
                                gestureScale: details.scale,
                              );
                              _scaleGestureWasPinch = true;
                            }
                            final next = details.pointerCount > 1
                                ? _viewportController.updateScale(
                                    scale: details.scale,
                                    focalPoint: details.localFocalPoint.dx,
                                    plotWidth: plotWidth,
                                    candleCount: viewportCandleCount,
                                  )
                                : _viewportController.panBy(
                                    viewport: _viewport,
                                    delta: details.focalPointDelta.dx,
                                    plotWidth: plotWidth,
                                    candleCount: viewportCandleCount,
                                  );
                            if (next != _viewport) {
                              setState(() => _viewport = next);
                            }
                          },
                          onScaleEnd: (details) {
                            if (crosshairEnabled ||
                                _priceAxisScaleSuppressed ||
                                _pendingScalePointer != null) {
                              return;
                            }
                            if (_scaleGestureWasPinch ||
                                details.velocity.pixelsPerSecond.dx.abs() <
                                    10) {
                              _rememberChartView();
                              return;
                            }
                            final plotWidth = math.max(
                              0.0,
                              _chartHitTargets.chartWidth,
                            );
                            final target = _viewportController.endPan(
                              viewport: _viewport,
                              velocity: details.velocity.pixelsPerSecond.dx,
                              plotWidth: plotWidth,
                              candleCount: viewportCandleCount,
                            );
                            if (target == _viewport) {
                              _rememberChartView();
                              return;
                            }
                            _rememberChartView(viewport: target);
                            _panAnimationPlotWidth = plotWidth;
                            _panAnimationCandleCount = viewportCandleCount;
                            _panInertiaController.value =
                                _viewport.scrollOffset;
                            _panInertiaController.animateTo(
                              target.scrollOffset,
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          onDoubleTapDown: crosshairEnabled
                              ? null
                              : (details) =>
                                    _doubleTapPosition = details.localPosition,
                          onDoubleTap: crosshairEnabled
                              ? null
                              : () {
                                  if (_pendingScalePointer != null) {
                                    return;
                                  }
                                  _panInertiaController.stop();
                                  final position = _doubleTapPosition;
                                  _doubleTapPosition = null;
                                  if (position != null &&
                                      _chartHitTargets.priceAxisRect.contains(
                                        position,
                                      )) {
                                    setState(
                                      () => _priceViewport =
                                          _priceViewportController.reset(),
                                    );
                                  } else {
                                    setState(
                                      () => _viewport = _viewportController
                                          .reset(),
                                    );
                                  }
                                  _rememberChartView();
                                },
                          child: RepaintBoundary(
                            key: const Key('chart-plot-repaint-boundary'),
                            child: CustomPaint(
                              key: const Key('chart-canvas'),
                              painter: chartPainter,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (crosshairEnabled)
                    Positioned(
                      left: 4,
                      top:
                          1 +
                          (showOneClickTrading && !showTimeframes
                              ? _oneClickPanelHeight
                              : 0),
                      child: Text.rich(
                        key: const Key('chart-plot-title'),
                        TextSpan(
                          children: [
                            TextSpan(
                              text: displayTradingSymbol(widget.symbol),
                              style: TextStyle(
                                color: _theme.tradeBlue,
                                fontWeight: FontWeight.w500,
                                fontVariations: const [
                                  FontVariation('wght', 500),
                                ],
                              ),
                            ),
                            TextSpan(text: ' '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: _ChartSymbolChevron(
                                key: const Key('chart-symbol-chevron'),
                                theme: _theme,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' $chartTimeframeLabel, '
                                  '${_crosshairOhlc(candles)}\n'
                                  'Di chuyển con trỏ hoặc nhấn vào biểu đồ '
                                  'để chuyển sang một\nloại thước',
                              style: TextStyle(color: _theme.foreground),
                            ),
                          ],
                        ),
                        style: AppTypography.chartAnnotation.copyWith(
                          color: _theme.foreground,
                          fontSize: _usesVideo2ChartLayout ? 12.3 : 10.5,
                          fontWeight: FontWeight.w400,
                          height: _usesVideo2ChartLayout ? 1.35 : 1.1,
                        ),
                      ),
                    )
                  else ...[
                    Positioned(
                      left: usesM1ReferenceTypography ? 2 : 4,
                      top:
                          (usesM1ReferenceTypography
                              ? 1.6666666667
                              : 2.3333333333) +
                          (showOneClickTrading && !showTimeframes
                              ? _oneClickPanelHeight
                              : 0),
                      child: Text.rich(
                        key: const Key('chart-plot-title'),
                        TextSpan(
                          children: [
                            TextSpan(
                              text: displayTradingSymbol(widget.symbol),
                              style: TextStyle(
                                color: usesM1ReferenceTypography
                                    ? _theme.plotTitleBlue
                                    : _theme.tradeBlue,
                                fontFamily: usesM1ReferenceTypography
                                    ? AppTypography.tabPlainFamily
                                    : null,
                                fontWeight: usesM1ReferenceTypography
                                    ? FontWeight.w300
                                    : FontWeight.w500,
                                fontVariations: usesM1ReferenceTypography
                                    ? const [FontVariation('wght', 250)]
                                    : const [FontVariation('wght', 500)],
                                fontSize: _usesVideo2ChartLayout ? 13 : null,
                                letterSpacing: _usesVideo2ChartLayout
                                    ? usesM1ReferenceTypography
                                          ? 1.2
                                          : .5
                                    : null,
                              ),
                            ),
                            const TextSpan(text: ' '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: _ChartSymbolChevron(
                                key: const Key('chart-symbol-chevron'),
                                theme: _theme,
                              ),
                            ),
                            TextSpan(
                              text: ' $chartTimeframeLabel',
                              style: TextStyle(
                                color: _theme.foreground,
                                fontSize: _usesVideo2ChartLayout ? 13 : null,
                                letterSpacing: _usesVideo2ChartLayout
                                    ? .1
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        style: AppTypography.chartAnnotation.copyWith(
                          color: _theme.foreground,
                          fontSize: _usesVideo2ChartLayout ? 12.8 : 10.5,
                          fontWeight: FontWeight.w400,
                          height: _usesVideo2ChartLayout ? 1.35 : 1.1,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 3.3333333333,
                      top:
                          (usesM1ReferenceTypography ? 17.3333333333 : 16) +
                          (showOneClickTrading && !showTimeframes
                              ? _oneClickPanelHeight
                              : 0),
                      child: Transform.scale(
                        alignment: Alignment.topLeft,
                        scaleX: usesM1ReferenceTypography ? 1.035 : 1,
                        scaleY: usesM1ReferenceTypography ? .85 : 1,
                        transformHitTests: false,
                        child: Text(
                          chartSubtitle,
                          key: const Key('chart-plot-subtitle'),
                          style: AppTypography.chartAnnotation.copyWith(
                            color: usesM1ReferenceTypography
                                ? _theme.plotSubtitleText
                                : _theme.foreground,
                            fontFamily: usesM1ReferenceTypography
                                ? AppTypography.tabPlainFamily
                                : null,
                            fontSize: _usesVideo2ChartLayout ? 12.5 : 10.5,
                            fontWeight: usesM1ReferenceTypography
                                ? FontWeight.w200
                                : FontWeight.w400,
                            fontVariations: usesM1ReferenceTypography
                                ? const [FontVariation('wght', 225)]
                                : null,
                            letterSpacing: _usesVideo2ChartLayout ? .4 : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (hasPendingLevel)
                    Positioned(
                      right: 76,
                      top: 7,
                      child: Semantics(
                        button: true,
                        label: 'Focus pending order',
                        child: GestureDetector(
                          key: const Key('chart-pending-jump'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            final level =
                                activePendingOrder?.price ?? pendingOrderPrice;
                            if (level == null) return;
                            setState(() {
                              _focusedChartPrice = _focusedChartPrice == level
                                  ? null
                                  : level;
                            });
                          },
                          child: Container(
                            width: 39,
                            height: 39,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _theme.foreground.withValues(alpha: .1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _theme.axisBorder,
                                width: .7,
                              ),
                            ),
                            child: Transform.translate(
                              offset: const Offset(0, .6666666667),
                              child: Transform.scale(
                                scaleX: 1.11,
                                scaleY: 1.29,
                                child: Icon(
                                  CupertinoIcons.arrow_up_to_line,
                                  color: _theme.foreground,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 22.6666666667,
                    bottom: 21.3333333333,
                    child: Text(
                      '•••',
                      style: AppTypography.chartToolbar.copyWith(
                        color: _theme.foreground,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w400,
                        letterSpacing: .6666666667,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (showTimeframes) {
      const order = [
        'M1',
        'M2',
        'M3',
        'M4',
        'M5',
        'M6',
        'M10',
        'M12',
        'M15',
        'M20',
        'M30',
        'H1',
        'H2',
        'H3',
        'H4',
        'H6',
        'H8',
        'H12',
        'D1',
        'W1',
        'MN',
      ];
      final periods = order.where(favoriteTimeframes.contains).take(9).toList();
      return AppBar(
        backgroundColor: _theme.background,
        foregroundColor: _theme.foreground,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: _chartToolbarHeight,
        automaticallyImplyLeading: false,
        titleSpacing: 8.1,
        title: Padding(
          padding: const EdgeInsets.only(top: 27),
          child: Row(
            children: [
              for (final period in periods)
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTimeframe(period),
                    child: Center(
                      child: Text(
                        period,
                        style: AppTypography.chartToolbar.copyWith(
                          color: period == timeframe
                              ? _theme.tradeBlue
                              : _theme.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: 32.5,
                child: InkWell(
                  key: const Key('chart-timeframe-more'),
                  onTap: () {
                    setState(() => showTimeframes = false);
                    _showTimeframeSettings();
                  },
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, 1),
                      child: Text(
                        '•••',
                        style: TextStyle(
                          color: _theme.foreground,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return AppBar(
      backgroundColor: _theme.background,
      foregroundColor: _theme.foreground,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: _chartToolbarHeight,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: SizedBox(
        height: _chartToolbarHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            double referenceLeft(double value) =>
                constraints.maxWidth * value / _chartToolbarReferenceWidth;
            return Stack(
              children: [
                Positioned(
                  left: referenceLeft(12.6666666667),
                  top: 30,
                  width: 35,
                  height: 40,
                  child: InkWell(
                    onTap: () => setState(() {
                      if (_normaliseSymbol(widget.symbol) == 'XAUUSD' &&
                          timeframe == 'H4') {
                        _h4ExpandedScaleSeen = true;
                      }
                      showTimeframes = true;
                    }),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        timeframe,
                        key: const Key('chart-toolbar-timeframe'),
                        maxLines: 1,
                        style: AppTypography.chartToolbar.copyWith(
                          color: _theme.toolbarInk,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: referenceLeft(134.6666666667),
                  top: 29.6666666667,
                  width: 38,
                  height: 40,
                  child: InkWell(
                    key: const Key('chart-crosshair-button'),
                    onTap: () => setState(() {
                      crosshairEnabled = !crosshairEnabled;
                      crosshairPosition ??= Offset(
                        _chartHitTargets.chartWidth * .58,
                        _chartHitTargets.priceTop +
                            _chartHitTargets.priceHeight * .515,
                      );
                      measurementStart = null;
                      measurementEnd = null;
                      _chartPointers.clear();
                    }),
                    child: Center(
                      child: _CrosshairIcon(
                        theme: _theme,
                        active: crosshairEnabled,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: referenceLeft(172),
                  top: 29.6666666667,
                  width: 38,
                  height: 40,
                  child: InkWell(
                    key: const Key('chart-indicators-button'),
                    onTap: () => context.push(
                      '/chart-indicators?symbol='
                      '${Uri.encodeQueryComponent(widget.symbol)}'
                      '&timeframe=$timeframe',
                    ),
                    child: Center(child: _MtIndicatorIcon(theme: _theme)),
                  ),
                ),
                Positioned(
                  left: referenceLeft(213),
                  top: 29,
                  width: 38,
                  height: 40,
                  child: InkWell(
                    key: const Key('chart-objects-button'),
                    onTap: () => context.push(
                      '/chart-objects?symbol='
                      '${Uri.encodeQueryComponent(widget.symbol)}'
                      '&timeframe=$timeframe',
                    ),
                    child: Center(child: _ObjectsIcon(theme: _theme)),
                  ),
                ),
                Positioned(
                  left: referenceLeft(305),
                  top: 31,
                  width: 38,
                  height: 40,
                  child: InkWell(
                    key: const Key('chart-windows-button'),
                    onTap: _showMtChartWindows,
                    child: Center(child: _ChartModeIcon(theme: _theme)),
                  ),
                ),
                Positioned(
                  left: referenceLeft(343),
                  top: 31,
                  width: 38,
                  height: 40,
                  child: InkWell(
                    key: const Key('chart-one-click-toggle'),
                    onTap: () => setState(
                      () => showOneClickTrading = !showOneClickTrading,
                    ),
                    onLongPress: () => _showMtAdvancedTrade(),
                    child: Center(child: _ToolbarWindowsIcon(theme: _theme)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _minimumSpread(double price) {
    if (price >= 10000) return price * .00008;
    if (price >= 1000) return .3;
    if (price >= 100) return .001;
    return .00001;
  }

  String _crosshairOhlc(List<MarketCandle> candles) {
    final visible = _chartHitTargets.visibleCandles.isNotEmpty
        ? _chartHitTargets.visibleCandles
        : candles;
    if (visible.isEmpty) {
      final value = _format(_latestMarketPrice);
      return '$value $value $value $value';
    }
    final chartWidth = math.max(1.0, _chartHitTargets.chartWidth);
    final localX = (crosshairPosition?.dx ?? chartWidth * .5).clamp(
      0.0,
      chartWidth,
    );
    final index = _chartHitTargets.visibleCandles.isNotEmpty
        ? _chartHitTargets.visibleCandleIndex(localX)
        : ((localX / chartWidth) * (visible.length - 1)).round();
    final candle = visible[index];
    return '${_format(candle.open)} ${_format(candle.high)} '
        '${_format(candle.low)} ${_format(candle.close)}';
  }

  Future<void> _beginPendingOrderFromChart(Offset touchPosition) async {
    if (_transientPendingClosed != null) return;
    if (_pendingOrderForTap != null) {
      await _showPendingOrderPanel(_pendingOrderForTap!);
      return;
    }
    final price = _pendingPriceAt(touchPosition.dy);
    final draft = DemoPendingOrder(
      id: 'chart-draft',
      symbol: widget.symbol,
      side: 'BUY',
      type: 'Buy Limit',
      volume: volume,
      price: price,
      createdAt: '',
    );
    setState(() {
      pendingOrderType = draft.type;
      pendingOrderPrice = draft.price;
      _focusedChartPrice = null;
    });
    _showPendingSubtitleTemporarily();
    await _showPendingOrderPanel(draft, transient: true);
    if (!mounted) return;
    _pendingSubtitleTimer?.cancel();
    setState(() {
      pendingOrderType = null;
      pendingOrderPrice = null;
      pendingStopLoss = null;
      pendingTakeProfit = null;
      _showPendingLevelSubtitle = false;
      _focusedChartPrice = null;
    });
  }

  Future<void> _showTimeframeSettings() async {
    const minutes = [
      'M1',
      'M2',
      'M3',
      'M4',
      'M5',
      'M6',
      'M10',
      'M12',
      'M15',
      'M20',
      'M30',
    ];
    const hours = ['H1', 'H2', 'H3', 'H4', 'H6', 'H8', 'H12'];
    const days = ['D1', 'W1', 'MN'];
    var showHint = true;
    await showDialog<void>(
      context: context,
      barrierColor: _theme.foreground.withValues(alpha: .65),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget periodButton(String period) {
            final selected = period == timeframe;
            final favorite = favoriteTimeframes.contains(period);
            return SizedBox(
              width: 58,
              height: 32,
              child: Material(
                color: selected
                    ? _theme.tradeBlue
                    : Color.alphaBlend(
                        _theme.foreground.withValues(alpha: .08),
                        _theme.background,
                      ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: favorite
                      ? BorderSide(color: _theme.tradeBlue, width: 1)
                      : BorderSide.none,
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('chart-timeframe-$period'),
                  onTap: () {
                    _selectTimeframe(period, closeFavorites: false);
                    Navigator.of(dialogContext).pop();
                  },
                  onLongPress: () {
                    setState(() {
                      favorite
                          ? favoriteTimeframes.remove(period)
                          : favoriteTimeframes.add(period);
                    });
                    setDialogState(() {});
                  },
                  child: Center(
                    child: Text(
                      period,
                      style: AppTypography.chartToolbar.copyWith(
                        color: selected ? _theme.background : _theme.foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          Widget section(String title, List<String> periods) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.chartToolbar.copyWith(
                  color: _theme.foreground,
                  fontWeight: FontWeight.w700,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 15,
                runSpacing: 7,
                children: [for (final period in periods) periodButton(period)],
              ),
            ],
          );

          return Dialog(
            alignment: Alignment.topRight,
            insetPadding: const EdgeInsets.fromLTRB(8, 81, 8, 0),
            backgroundColor: _theme.background,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(27),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              key: const Key('chart-timeframe-dialog'),
              width: 306.6666666667,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  15.3333333333,
                  16.6666666667,
                  14,
                  15.6666666667,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    section('Phút', minutes),
                    const SizedBox(height: 10.6666666667),
                    section('Giờ', hours),
                    const SizedBox(height: 10.6666666667),
                    section('Ngày', days),
                    if (showHint) ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 79,
                        padding: const EdgeInsets.fromLTRB(8, 5.75, 0, 5.75),
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            _theme.foreground.withValues(alpha: .06),
                            _theme.background,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Transform.translate(
                              offset: const Offset(-.6666666667, -.3333333333),
                              child: Transform.scale(
                                scaleX: .93,
                                scaleY: 1.38,
                                alignment: Alignment.center,
                                child: Icon(
                                  CupertinoIcons.hand_draw,
                                  color: _theme.tradeBlue,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Transform.translate(
                                offset: const Offset(0, -.6666666667),
                                child: Text(
                                  'Nhấn và giữ một khung thời\n'
                                  'gian để thêm hoặc xóa nó\n'
                                  'khỏi menu biểu đồ',
                                  style: AppTypography.chartToolbar.copyWith(
                                    color: _theme.foreground,
                                    fontWeight: FontWeight.w600,
                                    height: 1.49,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              key: const Key('chart-timeframe-hint-close'),
                              onTap: () => Navigator.of(dialogContext).pop(),
                              child: Transform.translate(
                                offset: const Offset(
                                  -2.6666666667,
                                  1.3333333333,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(5),
                                  child: Icon(
                                    CupertinoIcons.xmark,
                                    color: _theme.tradeBlue,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showMtAdvancedTrade([DemoPendingOrder? existingOrder]) async {
    if (existingOrder != null) {
      await _showPendingOrderPanel(existingOrder);
      return;
    }
    var selected = existingOrder?.type ?? pendingOrderType ?? 'Buy Limit';
    var committed = false;
    double draftPrice(String type) {
      final isAbove = type == 'Sell Limit' || type == 'Buy Stop';
      return _latestMarketPrice * (isAbove ? 1.0012 : .9988);
    }

    if (existingOrder == null && selected != 'Bởi thị trường') {
      setState(() {
        pendingOrderType = selected;
        pendingOrderPrice = draftPrice(selected);
      });
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      barrierColor: _theme.foreground.withValues(alpha: .32),
      backgroundColor: _theme.background,
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) => Theme(
        data: _chartOverlayTheme(),
        child: StatefulBuilder(
          builder: (context, setSheetState) => SizedBox(
            height: 88,
            child: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Text(
                        displayTradingSymbol(widget.symbol),
                        style: TextStyle(
                          color: _theme.tradeBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        CupertinoIcons.arrow_up_arrow_down,
                        color: _theme.tradeBlue,
                      ),
                      const Spacer(),
                      _ProtectionButton(
                        label: 'SL',
                        color: _theme.bearish,
                        onTap: () => _showPriceDialog('Stop Loss'),
                      ),
                      const SizedBox(width: 8),
                      _ProtectionButton(
                        label: 'TP',
                        color: _theme.bullish,
                        onTap: () => _showPriceDialog('Take Profit'),
                      ),
                      IconButton(
                        onPressed: () async {
                          try {
                            if (existingOrder != null) {
                              if (ref.read(exV2EnabledProvider)) {
                                await ref
                                    .read(exV2AccountProvider.notifier)
                                    .cancelOrder(existingOrder.id);
                              } else {
                                ref
                                    .read(demoTradingProvider.notifier)
                                    .cancelPendingOrder(existingOrder.id);
                              }
                            }
                            final placed = selected == 'Bởi thị trường'
                                ? await _placeChartOrder(
                                    'BUY',
                                    _latestMarketPrice,
                                  )
                                : await _placeChartPendingOrder(
                                    type: selected,
                                    orderVolume: volume,
                                    price: draftPrice(selected),
                                  );
                            if (!placed || !mounted) return;
                            committed = true;
                            if (selected != 'Bởi thị trường') {
                              final price = draftPrice(selected);
                              setState(() {
                                pendingOrderType = selected;
                                pendingOrderPrice = price;
                              });
                            }
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          } catch (_) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Không thể sửa lệnh'),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          CupertinoIcons.arrow_right,
                          color: _theme.tradeBlue,
                          size: 31,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final type in const [
                        'Bởi thị trường',
                        'Buy Limit',
                        'Sell Limit',
                        'Buy Stop',
                        'Sell Stop',
                      ])
                        SizedBox(
                          width: 100,
                          child: InkWell(
                            onTap: () {
                              setSheetState(() => selected = type);
                              if (existingOrder == null) {
                                setState(() {
                                  pendingOrderType = type == 'Bởi thị trường'
                                      ? null
                                      : type;
                                  pendingOrderPrice = type == 'Bởi thị trường'
                                      ? null
                                      : draftPrice(type);
                                });
                              }
                            },
                            child: Center(
                              child: Text(
                                type,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: type == selected
                                      ? _theme.bearish
                                      : _theme.foreground.withValues(
                                          alpha: .55,
                                        ),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || existingOrder != null) return;
    setState(() {
      pendingOrderType = null;
      pendingOrderPrice = null;
      pendingStopLoss = null;
      pendingTakeProfit = null;
    });
    if (!committed) return;
  }

  Widget _buildPendingOrderPanel(
    BuildContext sheetContext,
    DemoPendingOrder order, {
    required bool transient,
    VoidCallback? onCollapse,
  }) {
    var noConnection = false;
    var confirmed = false;
    return StatefulBuilder(
      builder: (context, setSheetState) => Consumer(
        builder: (context, sheetRef, child) {
          final quoteState = sheetRef.watch(demoQuoteProvider(widget.symbol));
          final feedConnected = quoteState.hasValue && !quoteState.hasError;
          final currentOrder = transient
              ? order
              : sheetRef
                    .watch(demoPendingOrdersProvider)
                    .where((item) => item.id == order.id)
                    .firstOrNull;
          if (currentOrder == null) return const SizedBox.shrink();
          Future<void> confirmPendingOrder() async {
            if (!feedConnected) {
              setSheetState(() => noConnection = true);
              return;
            }
            if (confirmed) return;
            confirmed = true;
            if (transient) {
              final placed = await _placeChartPendingOrder(
                type: currentOrder.type,
                orderVolume: currentOrder.volume,
                price: pendingOrderPrice ?? currentOrder.price,
              );
              if (placed) {
                _beginDismissTransientPendingOverlay();
              } else {
                confirmed = false;
              }
              return;
            }
            Navigator.pop(sheetContext);
          }

          return SafeArea(
            top: false,
            child: SizedBox(
              height: noConnection ? 94 : 81,
              child: Column(
                children: [
                  if (noConnection)
                    Container(
                      key: const Key('chart-pending-no-connection'),
                      width: double.infinity,
                      height: 29,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _theme.bearish.withValues(alpha: .14),
                        border: Border(
                          top: BorderSide(color: _theme.bearish, width: .8),
                        ),
                      ),
                      child: Text(
                        'Không có kết nối',
                        style: TextStyle(
                          color: _theme.bearish,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    )
                  else
                    Container(
                      key: const Key('chart-pending-grabber'),
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(
                        top: 1.6666666667,
                        bottom: 13,
                      ),
                      decoration: BoxDecoration(
                        color: _theme.foreground.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      noConnection ? 0 : 0,
                      19,
                      0,
                    ),
                    child: Row(
                      children: [
                        _PendingOrderPill(
                          theme: _theme,
                          type: currentOrder.type,
                          volume: currentOrder.volume,
                          onTap: confirmPendingOrder,
                          onConfirm: confirmPendingOrder,
                        ),
                        const Spacer(),
                        _PendingProtectionButton(
                          label: 'SL',
                          color: _theme.bearish,
                          onTap: () => _showPendingProtectionDialog(
                            currentOrder,
                            stopLoss: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PendingProtectionButton(
                          label: 'TP',
                          color: _theme.bullish,
                          onTap: () => _showPendingProtectionDialog(
                            currentOrder,
                            stopLoss: false,
                          ),
                        ),
                        const SizedBox(width: 13),
                        _PendingCollapseButton(
                          theme: _theme,
                          onTap:
                              onCollapse ?? () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPendingOrderPanel(
    DemoPendingOrder order, {
    bool transient = false,
  }) async {
    final backgroundColor = _theme.background;
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
    );
    if (transient) {
      final activePanel = _transientPendingClosed;
      if (activePanel != null) {
        await activePanel.future;
        return;
      }

      final closed = Completer<void>();
      _transientPendingOrder = order;
      _transientPendingClosed = closed;
      _pendingOverlayClosing = false;
      final route = ModalRoute.of(context);
      if (route != null) {
        final historyEntry = LocalHistoryEntry(
          onRemove: () =>
              _beginDismissTransientPendingOverlay(removeHistoryEntry: false),
        );
        _transientPendingHistoryEntry = historyEntry;
        route.addLocalHistoryEntry(historyEntry);
      }
      _transientPendingPortalController.show();
      await closed.future;
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      backgroundColor: backgroundColor,
      shape: shape,
      builder: (sheetContext) =>
          _buildPendingOrderPanel(sheetContext, order, transient: false),
    );
  }

  void _dismissTransientPendingOverlay({bool removeHistoryEntry = true}) {
    final historyEntry = _transientPendingHistoryEntry;
    final closed = _transientPendingClosed;
    if (historyEntry == null &&
        closed == null &&
        _transientPendingOrder == null) {
      return;
    }

    _transientPendingHistoryEntry = null;
    _transientPendingClosed = null;
    _transientPendingOrder = null;
    _pendingOverlayClosing = false;
    if (removeHistoryEntry) historyEntry?.remove();
    if (_transientPendingPortalController.isShowing) {
      _transientPendingPortalController.hide();
    }
    if (closed != null && !closed.isCompleted) closed.complete();
  }

  void _beginDismissTransientPendingOverlay({bool removeHistoryEntry = true}) {
    if ((_transientPendingOrder == null && _transientPendingClosed == null) ||
        _pendingOverlayClosing ||
        (!_transientPendingPortalController.isShowing &&
            _transientPendingOrder == null)) {
      return;
    }
    _removeHistoryOnPendingClose = removeHistoryEntry;
    if (!mounted) {
      _dismissTransientPendingOverlay(removeHistoryEntry: removeHistoryEntry);
      return;
    }
    setState(() => _pendingOverlayClosing = true);
  }

  Future<void> _showPendingProtectionDialog(
    DemoPendingOrder order, {
    required bool stopLoss,
  }) async {
    final isTransientDraft = order.id == 'chart-draft';
    final current = isTransientDraft
        ? stopLoss
              ? pendingStopLoss
              : pendingTakeProfit
        : stopLoss
        ? order.stopLoss
        : order.takeProfit;
    var draft = current?.toStringAsFixed(2) ?? '';
    final result = await showDialog<double?>(
      context: context,
      barrierColor: _theme.foreground.withValues(alpha: .32),
      builder: (dialogContext) => Theme(
        data: _chartOverlayTheme(),
        child: AlertDialog(
          backgroundColor: _theme.background,
          surfaceTintColor: Colors.transparent,
          title: Text(stopLoss ? 'Stop Loss' : 'Take Profit'),
          content: TextFormField(
            initialValue: draft,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: _theme.foreground),
            cursorColor: _theme.tradeBlue,
            decoration: InputDecoration(
              labelText: stopLoss ? 'Stop Loss' : 'Take Profit',
              hintText: 'Để trống để xóa',
            ),
            onChanged: (value) => draft = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('HỦY'),
            ),
            TextButton(
              onPressed: () {
                final value = draft.trim().isEmpty
                    ? 0.0
                    : double.tryParse(draft);
                Navigator.pop(dialogContext, value);
              },
              child: const Text('XONG'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (isTransientDraft) {
      setState(() {
        if (stopLoss) {
          pendingStopLoss = result > 0 ? result : null;
        } else {
          pendingTakeProfit = result > 0 ? result : null;
        }
      });
      return;
    }
    if (stopLoss) {
      ref
          .read(demoTradingProvider.notifier)
          .modifyPendingOrder(
            order.id,
            stopLoss: result > 0 ? result : null,
            clearStopLoss: result <= 0,
          );
    } else {
      ref
          .read(demoTradingProvider.notifier)
          .modifyPendingOrder(
            order.id,
            takeProfit: result > 0 ? result : null,
            clearTakeProfit: result <= 0,
          );
    }
  }

  // ignore: unused_element
  void _showAdvancedTrade() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SizedBox(
        height: 84,
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Text(
                    displayTradingSymbol(widget.symbol),
                    style: TextStyle(
                      color: _theme.tradeBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    CupertinoIcons.arrow_up_arrow_down,
                    color: _theme.tradeBlue,
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => _showPriceDialog('Stop Loss'),
                    style: OutlinedButton.styleFrom(
                      shape: const CircleBorder(),
                      foregroundColor: _theme.bearish,
                    ),
                    child: const Text('SL'),
                  ),
                  OutlinedButton(
                    onPressed: () => _showPriceDialog('Take Profit'),
                    style: OutlinedButton.styleFrom(
                      shape: const CircleBorder(),
                      foregroundColor: _theme.bullish,
                    ),
                    child: const Text('TP'),
                  ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      CupertinoIcons.arrow_right,
                      color: _theme.tradeBlue,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _OrderTypeLabel(_theme, 'Bởi thị trường'),
                  _OrderTypeLabel(_theme, 'Buy Limit'),
                  _OrderTypeLabel(_theme, 'Sell Limit', selected: true),
                  _OrderTypeLabel(_theme, 'Buy Stop'),
                  _OrderTypeLabel(_theme, 'Sell Stop'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _placeChartOrder(String side, double price) async {
    try {
      if (ref.read(exV2EnabledProvider)) {
        await ref
            .read(exV2AccountProvider.notifier)
            .createOrder(
              symbol: widget.symbol,
              side: side,
              volume: volume,
              stopLoss: pendingStopLoss,
              takeProfit: pendingTakeProfit,
            );
        if (!mounted) return false;
        return true;
      }
      ref
          .read(demoTradingProvider.notifier)
          .placeOrder(
            symbol: widget.symbol,
            side: side,
            volume: volume,
            executedPrice: price,
          );
      if (!mounted) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _placeChartPendingOrder({
    required String type,
    required double orderVolume,
    required double price,
  }) async {
    if (_tradingCommandPending) return false;
    _tradingCommandPending = true;
    try {
      if (ref.read(exV2EnabledProvider)) {
        final normalized = type.toLowerCase();
        final side = normalized.startsWith('buy') ? 'buy' : 'sell';
        await ref
            .read(exV2AccountProvider.notifier)
            .createOrder(
              symbol: widget.symbol,
              side: side,
              volume: orderVolume,
              type: normalized.contains('stop') ? 'stop' : 'limit',
              requestedPrice: price,
              stopLoss: pendingStopLoss,
              takeProfit: pendingTakeProfit,
            );
        if (!mounted) return false;
        return true;
      }
      ref
          .read(demoTradingProvider.notifier)
          .placePendingOrder(
            symbol: widget.symbol,
            type: type,
            volume: orderVolume,
            price: price,
            stopLoss: pendingStopLoss,
            takeProfit: pendingTakeProfit,
          );
      return true;
    } catch (_) {
      return false;
    } finally {
      _tradingCommandPending = false;
    }
  }

  Future<void> _showPriceDialog(String label) async {
    final isStopLoss = label == 'Stop Loss';
    final current = isStopLoss ? pendingStopLoss : pendingTakeProfit;
    var draft = current?.toStringAsFixed(2) ?? '';
    final result = await showDialog<double?>(
      context: context,
      barrierColor: _theme.foreground.withValues(alpha: .32),
      builder: (dialogContext) => Theme(
        data: _chartOverlayTheme(),
        child: AlertDialog(
          backgroundColor: _theme.background,
          surfaceTintColor: Colors.transparent,
          title: Text(label),
          content: TextFormField(
            initialValue: draft,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: _theme.foreground),
            cursorColor: _theme.tradeBlue,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Để trống để xóa',
            ),
            onChanged: (value) => draft = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('HỦY'),
            ),
            TextButton(
              onPressed: () {
                final value = draft.trim().isEmpty
                    ? 0.0
                    : double.tryParse(draft);
                Navigator.pop(dialogContext, value);
              },
              child: const Text('XONG'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isStopLoss) {
        pendingStopLoss = result > 0 ? result : null;
      } else {
        pendingTakeProfit = result > 0 ? result : null;
      }
    });
  }

  // ignore: unused_element
  void _showChartWindows() {
    final symbols = ref
        .read(demoQuotesProvider)
        .take(6)
        .map((quote) => quote.symbol);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 360,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Biểu đồ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                trailing: Icon(CupertinoIcons.add, size: 28),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    for (final symbol in symbols)
                      ListTile(
                        leading: _WindowsIcon(theme: _theme),
                        title: Text(
                          '${displayTradingSymbol(symbol)}, $timeframe',
                        ),
                        subtitle: Text(
                          symbol == widget.symbol
                              ? 'Cửa sổ đang hoạt động'
                              : 'Chạm để mở biểu đồ',
                        ),
                        trailing: symbol == widget.symbol
                            ? Icon(
                                CupertinoIcons.check_mark,
                                color: _theme.tradeBlue,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          context.go(
                            chartLocationForSymbol(
                              symbol,
                              timeframe: timeframe,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMtChartWindows() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: _theme.foreground.withValues(alpha: .32),
      backgroundColor: _theme.background,
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) => Theme(
        data: _chartOverlayTheme(),
        child: SafeArea(
          child: SizedBox(
            height: 190,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'Biểu đồ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(CupertinoIcons.add, size: 28),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(
                      '/symbols?mode=chart&timeframe='
                      '${Uri.encodeQueryComponent(timeframe)}',
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: _WindowsIcon(theme: _theme),
                  title: Text(
                    '${displayTradingSymbol(widget.symbol)}, $timeframe',
                  ),
                  subtitle: const Text('Cửa sổ đang hoạt động'),
                  trailing: Icon(
                    CupertinoIcons.check_mark,
                    color: _theme.tradeBlue,
                  ),
                  onTap: () => Navigator.pop(sheetContext),
                ),
                ListTile(
                  leading: const Icon(Icons.add_chart_outlined, size: 27),
                  title: const Text('Mở biểu đồ mới'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(
                      '/symbols?mode=chart&timeframe='
                      '${Uri.encodeQueryComponent(timeframe)}',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderTypeLabel extends StatefulWidget {
  const _OrderTypeLabel(this.theme, this.label, {this.selected = false});
  final ChartReferenceTheme theme;
  final String label;
  final bool selected;

  @override
  State<_OrderTypeLabel> createState() => _OrderTypeLabelState();
}

class _ProtectionButton extends StatelessWidget {
  const _ProtectionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 42,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.2),
        shape: const CircleBorder(),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    ),
  );
}

class _PendingOrderPill extends StatefulWidget {
  const _PendingOrderPill({
    required this.theme,
    required this.type,
    required this.volume,
    required this.onTap,
    required this.onConfirm,
  });

  final ChartReferenceTheme theme;
  final String type;
  final double volume;
  final VoidCallback onTap;
  final VoidCallback onConfirm;

  @override
  State<_PendingOrderPill> createState() => _PendingOrderPillState();
}

class _PendingOrderPillState extends State<_PendingOrderPill> {
  static const double _width = 179;
  static const double _handleSize = 32;
  static const double _confirmThreshold = 92;

  double dragOffset = 0;

  void _updateDrag(DragUpdateDetails details) {
    setState(() {
      dragOffset = (dragOffset + details.delta.dx).clamp(
        0,
        _width - _handleSize,
      );
    });
  }

  void _endDrag(DragEndDetails details) {
    if (dragOffset >= _confirmThreshold) {
      widget.onConfirm();
      return;
    }
    setState(() => dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: widget.theme.tradeBlue,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: GestureDetector(
      key: const Key('chart-pending-order-pill'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onHorizontalDragUpdate: _updateDrag,
      onHorizontalDragEnd: _endDrag,
      child: SizedBox(
        width: _width,
        height: 34,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Opacity(
              opacity: (1 - dragOffset / _confirmThreshold).clamp(0.18, 1),
              child: Row(
                children: [
                  const SizedBox(width: _handleSize),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.chartToolbar.copyWith(
                          color: widget.theme.background,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 9),
                    child: Text(
                      widget.volume.toStringAsFixed(2),
                      style: AppTypography.chartToolbar.copyWith(
                        color: widget.theme.background,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(dragOffset, 0),
              child: Container(
                width: _handleSize,
                height: _handleSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.theme.tradeBlue.withValues(alpha: .84),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.arrow_right,
                  color: widget.theme.background,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PendingProtectionButton extends StatelessWidget {
  const _PendingProtectionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 33,
    child: OutlinedButton(
      key: Key('chart-pending-${label.toLowerCase()}'),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: color,
        side: BorderSide(color: color, width: 1),
        shape: const CircleBorder(),
      ),
      child: Text(
        label,
        style: AppTypography.chartToolbar.copyWith(fontSize: 16),
      ),
    ),
  );
}

class _PendingCollapseButton extends StatelessWidget {
  const _PendingCollapseButton({required this.theme, required this.onTap});

  final ChartReferenceTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 20,
    child: OutlinedButton(
      key: const Key('chart-pending-collapse'),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: theme.tradeBlue,
        side: BorderSide(color: theme.tradeBlue, width: 2),
        shape: const CircleBorder(),
      ),
      child: Transform.translate(
        offset: const Offset(0, -.6666666667),
        child: const Icon(CupertinoIcons.chevron_up, size: 13),
      ),
    ),
  );
}

class _OrderTypeLabelState extends State<_OrderTypeLabel> {
  late bool selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: InkWell(
        onTap: () => setState(() => selected = !selected),
        child: Center(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? widget.theme.bearish
                  : widget.theme.foreground.withValues(alpha: .55),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CrosshairIcon extends StatelessWidget {
  const _CrosshairIcon({required this.theme, required this.active});
  final ChartReferenceTheme theme;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (active) {
      return Transform.translate(
        offset: const Offset(1.2, 2.1666666667),
        child: Transform.scale(
          scaleX: 1,
          scaleY: .96,
          child: CustomPaint(
            size: const Size.square(16.67),
            painter: _CrosshairIconPainter(theme: theme, active: true),
          ),
        ),
      );
    }
    return Transform.translate(
      offset: const Offset(1.2, 2.1666666667),
      child: Transform.scale(
        scaleX: 1,
        scaleY: .96,
        child: CustomPaint(
          size: const Size.square(16.67),
          painter: _CrosshairIconPainter(theme: theme),
        ),
      ),
    );
  }
}

class _CrosshairIconPainter extends CustomPainter {
  const _CrosshairIconPainter({required this.theme, this.active = false});

  final ChartReferenceTheme theme;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = active ? theme.tradeBlue : theme.toolbarInk
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.square;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, center.dy - 3.32),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + 3.32),
      Offset(center.dx, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(center.dx - 3.32, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 3.32, center.dy),
      Offset(size.width, center.dy),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 1.25, height: 1.25),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrosshairIconPainter oldDelegate) =>
      oldDelegate.active != active || oldDelegate.theme != theme;
}

class _MtIndicatorIcon extends StatelessWidget {
  const _MtIndicatorIcon({required this.theme});

  final ChartReferenceTheme theme;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(1.4, 3.5),
    child: Transform.scale(
      scaleX: .88,
      scaleY: .88,
      alignment: Alignment.topCenter,
      child: CustomPaint(
        size: const Size(12, 17),
        painter: _MtIndicatorIconPainter(theme),
      ),
    ),
  );
}

class _MtIndicatorIconPainter extends CustomPainter {
  const _MtIndicatorIconPainter(this.theme);

  final ChartReferenceTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.toolbarInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final function = Path()
      ..moveTo(11.2, 1.5)
      ..cubicTo(8.2, .25, 6.75, 1.65, 6.15, 4.25)
      ..lineTo(3.8, 13.2)
      ..cubicTo(3.2, 15.55, 1.8, 16.55, .45, 16)
      ..moveTo(3.7, 7)
      ..lineTo(9.7, 7);
    canvas.drawPath(function, paint);
  }

  @override
  bool shouldRepaint(covariant _MtIndicatorIconPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class _ObjectsIcon extends StatelessWidget {
  const _ObjectsIcon({required this.theme});

  final ChartReferenceTheme theme;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(-3.5, 3.3333333333),
    child: Transform.scale(
      scaleX: .98,
      scaleY: .92,
      alignment: Alignment.centerLeft,
      child: CustomPaint(
        size: const Size.square(18),
        painter: _ObjectsIconPainter(theme),
      ),
    ),
  );
}

class _ObjectsIconPainter extends CustomPainter {
  const _ObjectsIconPainter(this.theme);

  final ChartReferenceTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.toolbarInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(6.5, 6.7)
        ..lineTo(2.2, 6.7)
        ..lineTo(2.2, 15.3)
        ..lineTo(6.5, 15.3),
      paint,
    );
    canvas.drawCircle(const Offset(12.5, 4.85), 4.97, paint);
    final triangle = Path()
      ..moveTo(7.6, 16.67)
      ..lineTo(12.5, 8.5)
      ..lineTo(16.8, 16.67)
      ..close();
    canvas.drawPath(triangle, paint);
  }

  @override
  bool shouldRepaint(covariant _ObjectsIconPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

// ignore: unused_element
class _IndicatorIcon extends StatelessWidget {
  const _IndicatorIcon({required this.theme});

  final ChartReferenceTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 29,
      height: 28,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: -4,
            child: Text(
              'ƒ',
              style: TextStyle(
                color: theme.foreground,
                fontSize: 30,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 12,
            child: CustomPaint(
              size: const Size(29, 10),
              painter: _WavePainter(theme),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter(this.theme);

  final ChartReferenceTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 6)
      ..cubicTo(5, 0, 9, 10, 14, 5)
      ..cubicTo(19, 0, 23, 9, 29, 3);
    canvas.drawPath(
      path,
      Paint()
        ..color = theme.foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class _OneClickVolumeField extends StatelessWidget {
  const _OneClickVolumeField({
    required this.theme,
    required this.value,
    required this.active,
    required this.onTap,
    super.key,
  });

  final ChartReferenceTheme theme;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      value: value,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    key: const Key('chart-one-click-volume-text'),
                    style: AppTypography.chartToolbar.copyWith(
                      color: theme.foreground,
                      fontFamily: AppTypography.condensedFamily,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w400,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (active)
                    SizedBox(
                      key: Key('chart-one-click-volume-caret'),
                      width: 1,
                      height: 20,
                      child: ColoredBox(color: theme.tradeBlue),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartNumericKeypad extends StatelessWidget {
  const _ChartNumericKeypad({
    required this.theme,
    required this.onKey,
    required this.onBackspace,
  });

  static const double height = 297.3333333333;
  static const double _horizontalInset = 4.6666666667;
  static const double _topInset = 23.3333333333;
  static const double _keyHeight = 46.6666666667;
  static const double _columnGap = 6;
  static const double _rowGap = 6.6666666667;

  final ChartReferenceTheme theme;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('chart-numeric-keypad-sheet'),
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(37),
          bottomRight: Radius.circular(37),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                theme.foreground.withValues(alpha: .08),
                theme.background,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(37),
                bottomRight: Radius.circular(37),
              ),
              border: Border.all(color: theme.axisBorder, width: .7),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: _horizontalInset,
                top: _topInset,
                right: _horizontalInset,
              ),
              child: Column(
                children: [
                  _numberRow(const [
                    ('1', null),
                    ('2', 'A B C'),
                    ('3', 'D E F'),
                  ]),
                  const SizedBox(height: _rowGap),
                  _numberRow(const [
                    ('4', 'G H I'),
                    ('5', 'J K L'),
                    ('6', 'M N O'),
                  ]),
                  const SizedBox(height: _rowGap),
                  _numberRow(const [
                    ('7', 'P Q R S'),
                    ('8', 'T U V'),
                    ('9', 'W X Y Z'),
                  ]),
                  const SizedBox(height: _rowGap),
                  SizedBox(
                    height: _keyHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: _KeypadButton(
                            theme: theme,
                            buttonKey: const Key('chart-keypad-decimal'),
                            filled: false,
                            onTap: () => onKey(','),
                            child: Text(',', style: _auxiliaryStyle),
                          ),
                        ),
                        const SizedBox(width: _columnGap),
                        Expanded(
                          child: _KeypadButton(
                            theme: theme,
                            buttonKey: const Key('chart-keypad-0'),
                            onTap: () => onKey('0'),
                            child: Text('0', style: _digitStyle),
                          ),
                        ),
                        const SizedBox(width: _columnGap),
                        Expanded(
                          child: _KeypadButton(
                            theme: theme,
                            buttonKey: const Key('chart-keypad-backspace'),
                            filled: false,
                            onTap: onBackspace,
                            child: Transform.translate(
                              offset: const Offset(0, -1),
                              child: Transform.scale(
                                scaleX: 1.10,
                                scaleY: 1.03,
                                child: Icon(
                                  CupertinoIcons.delete_left,
                                  color: theme.foreground,
                                  size: 25,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberRow(List<(String, String?)> values) {
    return SizedBox(
      height: _keyHeight,
      child: Row(
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const SizedBox(width: _columnGap),
            Expanded(
              child: _KeypadButton(
                theme: theme,
                buttonKey: ValueKey('chart-keypad-${values[index].$1}'),
                onTap: () => onKey(values[index].$1),
                child: values[index].$2 == null
                    ? Text(values[index].$1, style: _digitStyle)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(values[index].$1, style: _digitStyle),
                          const SizedBox(height: 2.5),
                          Text(values[index].$2!, style: _lettersStyle),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle get _digitStyle => AppTypography.chartToolbar.copyWith(
    color: theme.foreground,
    fontSize: 21.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  TextStyle get _lettersStyle => AppTypography.chartToolbar.copyWith(
    color: theme.foreground,
    fontSize: 7.7,
    fontWeight: FontWeight.w700,
  );

  TextStyle get _auxiliaryStyle => AppTypography.chartToolbar.copyWith(
    color: theme.foreground,
    fontSize: 22,
  );
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.theme,
    required this.buttonKey,
    required this.onTap,
    required this.child,
    this.filled = true,
  });

  final ChartReferenceTheme theme;
  final Key buttonKey;
  final VoidCallback onTap;
  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: buttonKey,
      color: filled
          ? Color.alphaBlend(
              theme.foreground.withValues(alpha: .12),
              theme.background,
            )
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(child: child),
      ),
    );
  }
}

class _TradeQuote extends StatelessWidget {
  const _TradeQuote({
    required this.theme,
    required this.label,
    required this.price,
    required this.color,
    required this.onTap,
  });
  final ChartReferenceTheme theme;
  final String label;
  final String price;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final leading = price.substring(0, price.length - 2);
    final trailing = price.substring(price.length - 2);
    return Material(
      key: ValueKey('chart-ticket-${label.toLowerCase()}'),
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: label == 'Buy' ? 5.3333333333 : 6.6666666667,
              top: label == 'Buy' ? 4.3333333333 : 5,
              child: Text(
                label,
                style:
                    (label == 'Buy'
                            ? AppTypography.chartTicketLabel.copyWith(
                                fontFamily: AppTypography.tabPlainFamily,
                                fontSize: 7,
                                fontVariations: const [
                                  FontVariation('wght', 250),
                                ],
                                letterSpacing: 1.75,
                              )
                            : AppTypography.chartTicketLabel.copyWith(
                                fontWeight: FontWeight.w200,
                                fontVariations: const [
                                  FontVariation('wght', 200),
                                ],
                                letterSpacing: .42,
                              ))
                        .copyWith(
                          color: theme.background,
                          fontWeight: io.Platform.isAndroid
                              ? label == 'Buy'
                                    ? FontWeight.w500
                                    : FontWeight.w200
                              : null,
                          fontVariations: io.Platform.isAndroid
                              ? label == 'Buy'
                                    ? const [FontVariation('wght', 500)]
                                    : const [FontVariation('wght', 200)]
                              : null,
                        ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 10.7,
              height: 27,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      leading,
                      style: AppTypography.chartTicketPriceMajor.copyWith(
                        color: theme.background,
                      ),
                    ),
                    Text(
                      trailing,
                      style: AppTypography.chartTicketPriceMinor.copyWith(
                        color: theme.background,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartSymbolChevron extends StatelessWidget {
  const _ChartSymbolChevron({required this.theme, super.key});

  final ChartReferenceTheme theme;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 8,
    height: 12,
    child: Center(
      child: Icon(
        CupertinoIcons.chevron_down,
        color: theme.foreground,
        size: 6.5,
      ),
    ),
  );
}

class _ChartModeIcon extends StatelessWidget {
  const _ChartModeIcon({required this.theme});

  final ChartReferenceTheme theme;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(2, 1.3333333333),
    child: CustomPaint(
      size: const Size(18, 14),
      painter: _ChartModePainter(theme),
    ),
  );
}

class _ChartModePainter extends CustomPainter {
  const _ChartModePainter(this.theme);

  final ChartReferenceTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Path.combine(
      PathOperation.difference,
      Path()..addOval(const Rect.fromLTWH(-0.6666666667, 0, 18.6666666667, 14)),
      Path()..addOval(const Rect.fromLTWH(3.1666666667, 1.99, 11, 10.02)),
    );
    canvas
      ..save()
      ..clipRect(const Rect.fromLTWH(0, 0, 8.3666666667, 14))
      ..drawPath(
        ring,
        Paint()
          ..color = ChartReferenceTheme.toolbarAccentRed
          ..style = PaintingStyle.fill,
      )
      ..restore()
      ..save()
      ..clipRect(const Rect.fromLTWH(9.3, 0, 8.3666666667, 14))
      ..drawPath(
        ring,
        Paint()
          ..color = ChartReferenceTheme.toolbarAccentBlue
          ..style = PaintingStyle.fill,
      )
      ..restore();
    final hand = Path()
      ..moveTo(8.3333333333, 4.4333333334)
      ..lineTo(8.3333333333, 8.3333333334)
      ..lineTo(10.4333333333, 9.7666666667);
    canvas.drawPath(
      hand,
      Paint()
        ..color = ChartReferenceTheme.toolbarAccentNeutral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartModePainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class _ToolbarWindowsIcon extends StatelessWidget {
  const _ToolbarWindowsIcon({required this.theme});

  final ChartReferenceTheme theme;

  @override
  Widget build(BuildContext context) => Transform.translate(
    key: const Key('chart-windows-icon-scale'),
    offset: const Offset(0, 1.3333333333),
    child: CustomPaint(
      size: const Size(18.3333333333, 12.6666666667),
      painter: _ToolbarWindowsIconPainter(theme),
    ),
  );
}

class _ToolbarWindowsIconPainter extends CustomPainter {
  const _ToolbarWindowsIconPainter(this.theme);

  final ChartReferenceTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final redRect = RRect.fromRectAndCorners(
      const Rect.fromLTWH(0, 0, 9, 12.6666666667),
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(2),
      bottomLeft: const Radius.circular(3),
      bottomRight: const Radius.circular(3),
    );
    final blueRect = RRect.fromRectAndCorners(
      const Rect.fromLTWH(10.0833333333, 0.3, 8.4166666667, 12.3666666667),
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(2),
      bottomLeft: const Radius.circular(3),
      bottomRight: const Radius.circular(3),
    );
    canvas.drawRRect(
      redRect,
      Paint()..color = ChartReferenceTheme.toolbarAccentRed,
    );
    canvas.drawRRect(
      blueRect,
      Paint()..color = ChartReferenceTheme.toolbarAccentBlue,
    );

    final outerLink = RRect.fromRectXY(
      const Rect.fromLTWH(
        4.3611111111,
        3.3333333333,
        9.7777777778,
        5.3333333333,
      ),
      1.5,
      2.6666666667,
    );
    final innerLink = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5.75, 4.5, 7, 4),
      const Radius.circular(2),
    );
    canvas.drawRRect(outerLink, Paint()..color = theme.background);
    canvas.drawRRect(
      innerLink,
      Paint()
        ..color = ChartReferenceTheme.toolbarAccentNeutral
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ToolbarWindowsIconPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class _WindowsIcon extends StatelessWidget {
  const _WindowsIcon({required this.theme});

  final ChartReferenceTheme theme;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(0, 1.3333333333),
    child: CustomPaint(
      size: const Size(20.6666666667, 14.6666666667),
      painter: _WindowsIconPainter(theme),
    ),
  );
}

class _WindowsIconPainter extends CustomPainter {
  const _WindowsIconPainter(this.theme);

  final ChartReferenceTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final redRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 11.3333333333, 14),
      const Radius.circular(1.3333333333),
    );
    final blueRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(9.3333333333, .6666666667, 11.3333333333, 14),
      const Radius.circular(1.3333333333),
    );
    canvas.drawRRect(
      redRect,
      Paint()..color = ChartReferenceTheme.toolbarAccentRed,
    );
    canvas.drawRRect(
      blueRect,
      Paint()..color = ChartReferenceTheme.toolbarAccentBlue,
    );

    final outerLink = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5.3333333333, 4, 10, 6.6666666667),
      const Radius.circular(3.3333333333),
    );
    final innerLink = RRect.fromRectAndRadius(
      const Rect.fromLTWH(6.6666666667, 5.3333333333, 7.3333333333, 4),
      const Radius.circular(2),
    );
    canvas.drawRRect(outerLink, Paint()..color = theme.background);
    canvas.drawRRect(
      innerLink,
      Paint()
        ..color = theme.axisBorder
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _WindowsIconPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class _TopInsetRectClipper extends CustomClipper<Rect> {
  const _TopInsetRectClipper(this.inset);

  final double inset;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, inset, size.width, math.max(0, size.height - inset));

  @override
  bool shouldReclip(covariant _TopInsetRectClipper oldClipper) =>
      oldClipper.inset != inset;
}
