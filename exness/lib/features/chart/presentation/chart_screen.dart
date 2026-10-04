import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/app_shell.dart';
import '../../../core/config/video_demo_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ex_widgets.dart';
import '../../account/data/account_session.dart';
import '../../trading/data/market_api.dart';
import '../domain/chart_candle_book.dart';
import '../domain/video_chart_fixture.dart';
import 'chart_settings_sheet.dart';

class ChartScreen extends ConsumerStatefulWidget {
  const ChartScreen({required this.symbol, super.key});
  final String symbol;

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> {
  late final WebViewController _webView;
  late String _symbol = marketSymbol(widget.symbol);
  String _timeframe = 'M1';
  String _displayMode = 'candles';
  ChartSettings get _settings => ref.read(chartSettingsProvider);
  late ChartCandleBook _book = ChartCandleBook(_symbol, _timeframe);
  bool _chartReady = false;
  bool _hasSnapshot = false;
  bool _chartFailed = false;
  Future<void> _commands = Future.value();
  Timer? _quoteTimer;
  MarketQuote? _pendingQuote;
  bool _noticeEnabled = false;

  @override
  void initState() {
    super.initState();
    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..addJavaScriptChannel(
        'ChartBridge',
        onMessageReceived: (message) {
          if (!mounted || message.message != 'ready') return;
          setState(() {
            _chartReady = true;
            _chartFailed = false;
          });
          _syncStyle();
          _send({'type': 'setDisplayMode', 'mode': _displayMode});
          final demo = ref.read(videoDemoModeProvider);
          final snapshot = demo
              ? videoChartCandles(_symbol, _timeframe)
              : ref.read(marketCandlesProvider((_symbol, _timeframe))).value;
          if (snapshot != null) _setCandles(snapshot);
          final quote = demo
              ? videoChartQuote(_symbol)
              : ref.read(marketQuotesProvider).value?.quoteFor(_symbol);
          if (quote != null) _queueQuote(quote);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _chartFailed = true);
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/chart/index.html');
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  void _send(Map<String, Object?> message) {
    if (!_chartReady || !mounted) return;
    final command = 'window.exnessChart.receive(${jsonEncode(message)});';
    _commands = _commands
        .then((_) => _webView.runJavaScript(command))
        .catchError((Object _) {});
  }

  Map<String, Object> _bar(MarketCandle item) => {
    'time': item.time.millisecondsSinceEpoch ~/ 1000,
    'open': item.open,
    'high': item.high,
    'low': item.low,
    'close': item.close,
  };

  void _setCandles(List<MarketCandle> candles) {
    _book.replace(candles);
    _hasSnapshot = true;
    _send({'type': 'setData', 'candles': _book.candles.map(_bar).toList()});
    final quote = ref.read(videoDemoModeProvider)
        ? null
        : ref.read(marketQuotesProvider).value?.quoteFor(_symbol);
    if (quote != null) _queueQuote(quote);
  }

  void _queueQuote(MarketQuote quote) {
    if (quote.symbol != _symbol) return;
    _pendingQuote = quote;
    _quoteTimer?.cancel();
    _quoteTimer = Timer(const Duration(milliseconds: 90), () {
      final pending = _pendingQuote;
      if (!mounted || pending == null || pending.symbol != _symbol) return;
      if (_hasSnapshot) {
        final updated = _book.acceptQuote(pending);
        if (updated != null) {
          _send({'type': 'updateCandle', 'candle': _bar(updated)});
        }
      }
      _send({
        'type': 'setQuote',
        'bid': pending.bid,
        'ask': pending.ask,
        'source': _settings.priceSource.name,
        'visible': _settings.showPriceLines,
      });
    });
  }

  void _syncStyle() => _send({
    'type': 'setStyle',
    'provider': _settings.provider == ChartProvider.exness
        ? 'Exness'
        : 'TradingView',
    'grid': _settings.showGrid,
    'timeScale': _settings.showTimeScale,
    'priceScale': _settings.showPriceScale,
    'priceLines': _settings.showPriceLines,
    'videoReferenceAxes':
        ref.read(videoDemoModeProvider) &&
        _symbol == 'XAUUSD+' &&
        _timeframe == 'M1',
  });

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(videoDemoModeProvider);
    final candles = demo
        ? null
        : ref.watch(marketCandlesProvider((_symbol, _timeframe)));
    final feed = demo ? null : ref.watch(marketQuotesProvider);
    final account = demo ? null : ref.watch(accountSessionProvider).value;
    if (!demo) {
      ref.listen(marketCandlesProvider((_symbol, _timeframe)), (_, next) {
        if (next.value case final List<MarketCandle> items) _setCandles(items);
      });
      ref.listen(marketQuotesProvider, (_, next) {
        final quote = next.value?.quoteFor(_symbol);
        if (quote != null) _queueQuote(quote);
      });
    }
    final marketState = feed?.value;
    final subtitle = demo
        ? '21 thg 9 · 05:01'
        : marketState?.status == MarketFeedStatus.disconnected
        ? 'Mất kết nối giá thị trường'
        : marketState?.isStale(_symbol) == true
        ? 'Đang chờ giá mới'
        : 'Chưa có lịch mở cửa';

    return Scaffold(
      key: const Key('chart-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const PhoneStatusBar(),
            const SizedBox(height: 6),
            GestureDetector(
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 250) context.pop();
              },
              child: SizedBox(
                height: 22,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 35,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 38,
              child: Stack(
                children: [
                  const Positioned(
                    left: 15,
                    top: 3,
                    child: Row(
                      children: [
                        Icon(
                          Icons.toggle_off_outlined,
                          size: 29,
                          color: AppColors.border,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'One-click',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 118,
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          demo
                              ? '0,00 USD ⋮'
                              : account == null
                              ? '— USD'
                              : formatMoney(
                                  account.summary.balance,
                                  account.summary.currency,
                                ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 0,
                    child: Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _showNoticeInfo,
                          child: const SizedBox(
                            width: 32,
                            height: 36,
                            child: Icon(Icons.alarm_outlined, size: 21),
                          ),
                        ),
                        GestureDetector(
                          key: const Key('chart-settings-button'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _showSettings,
                          child: const SizedBox(
                            width: 32,
                            height: 36,
                            child: Icon(Icons.settings_outlined, size: 21),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: WebViewWidget(controller: _webView)),
                  Positioned(
                    left: 15,
                    top: 12,
                    child: Material(
                      color: AppColors.background.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(5),
                      child: InkWell(
                        key: const Key('chart-symbol-button'),
                        onTap: _chooseSymbol,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 3,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: AppColors.muted,
                                child: Text(
                                  _symbol == 'XAUUSD+'
                                      ? '🇺🇸'
                                      : _symbol.substring(0, 1),
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                marketLabel(_symbol),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down, size: 15),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!demo)
                    Positioned(
                      right: 56,
                      bottom: 47,
                      child: Material(
                        color: AppColors.background,
                        shape: const CircleBorder(
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _send({'type': 'resetView'}),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(Icons.open_in_full, size: 16),
                          ),
                        ),
                      ),
                    ),
                  if (_chartFailed || candles?.hasError == true)
                    Positioned.fill(
                      child: ColoredBox(
                        color: AppColors.background.withValues(alpha: 0.92),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Không thể tải biểu đồ'),
                              TextButton(
                                onPressed: () {
                                  if (_chartFailed) {
                                    setState(() {
                                      _chartFailed = false;
                                      _chartReady = false;
                                    });
                                    _webView.loadFlutterAsset(
                                      'assets/chart/index.html',
                                    );
                                  }
                                  ref.invalidate(
                                    marketCandlesProvider((
                                      _symbol,
                                      _timeframe,
                                    )),
                                  );
                                },
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (candles?.isLoading == true || !_chartReady)
                    const Positioned(
                      right: 72,
                      top: 54,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  _Tool(
                    key: const Key('chart-timeframe-button'),
                    label: _timeframeLabel(_timeframe),
                    onTap: _chooseTimeframe,
                  ),
                  const SizedBox(width: 8),
                  _Tool(
                    key: const Key('chart-display-button'),
                    icon: _displayMode == 'candles'
                        ? Icons.candlestick_chart
                        : Icons.show_chart,
                    onTap: _chooseDisplayMode,
                  ),
                  const SizedBox(width: 8),
                  _Tool(
                    key: const Key('chart-indicator-button'),
                    label: 'ƒx',
                    onTap: _showIndicators,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 70,
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông báo cho tôi khi thị trường mở cửa',
                          style: TextStyle(fontSize: 13),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _noticeEnabled,
                    onChanged: demo
                        ? (value) => setState(() => _noticeEnabled = value)
                        : null,
                    thumbColor: const WidgetStatePropertyAll(
                      AppColors.background,
                    ),
                    trackColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.positive
                          : AppColors.border,
                    ),
                    trackOutlineColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
              ),
            ),
            const SizedBox(height: 53),
          ],
        ),
      ),
    );
  }

  void _changeChart(String symbol, String timeframe) {
    _quoteTimer?.cancel();
    setState(() {
      _symbol = symbol;
      _timeframe = timeframe;
      _book = ChartCandleBook(symbol, timeframe);
      _hasSnapshot = false;
    });
    _syncStyle();
    _send({'type': 'setData', 'candles': <Object>[]});
    final demo = ref.read(videoDemoModeProvider);
    final snapshot = demo
        ? videoChartCandles(symbol, timeframe)
        : ref.read(marketCandlesProvider((symbol, timeframe))).value;
    if (snapshot != null) _setCandles(snapshot);
    final quote = demo
        ? videoChartQuote(symbol)
        : ref.read(marketQuotesProvider).value?.quoteFor(symbol);
    if (quote != null) _queueQuote(quote);
  }

  void _chooseTimeframe() {
    const choices = ['M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1', 'MN'];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Khung thời gian')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in choices)
                  ChoiceChip(
                    label: Text(_timeframeLabel(value)),
                    selected: value == _timeframe,
                    onSelected: (_) {
                      Navigator.pop(context);
                      _changeChart(_symbol, value);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  void _chooseSymbol() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Công cụ giao dịch')),
            for (final value in const ['XAUUSD+', 'BTCUSD', 'ETHUSD'])
              ListTile(
                title: Text(marketLabel(value)),
                trailing: value == _symbol ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.pop(context);
                  _changeChart(value, _timeframe);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _chooseDisplayMode() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Kiểu biểu đồ')),
            for (final mode in const ['candles', 'line'])
              ListTile(
                title: Text(mode == 'candles' ? 'Nến' : 'Đường'),
                trailing: mode == _displayMode ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _displayMode = mode);
                  _send({'type': 'setDisplayMode', 'mode': mode});
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showIndicators() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('Chỉ báo')),
            ListTile(
              title: Text('Chưa có dữ liệu chỉ báo'),
              subtitle: Text(
                'Biểu đồ đang hiển thị giá và nến từ nguồn thị trường.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: .19),
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: .764,
        child: ChartSettingsSheet(
          settings: _settings,
          onChanged: (value) {
            if (!mounted) return;
            ref.read(chartSettingsProvider.notifier).update(value);
            _syncStyle();
            final quote = ref.read(videoDemoModeProvider)
                ? videoChartQuote(_symbol)
                : ref.read(marketQuotesProvider).value?.quoteFor(_symbol);
            if (quote != null) _queueQuote(quote);
          },
        ),
      ),
    );
  }

  void _showNoticeInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.read(videoDemoModeProvider)
              ? 'Thông báo khi thị trường mở cửa: 21 thg 9 · 05:01'
              : 'Nguồn giá hiện chưa cung cấp lịch mở cửa tiếp theo.',
        ),
      ),
    );
  }
}

String _timeframeLabel(String value) => switch (value) {
  'M1' => '1m',
  'M5' => '5m',
  'M15' => '15m',
  'M30' => '30m',
  'H1' => '1h',
  'H4' => '4h',
  'D1' => '1d',
  'W1' => '1w',
  'MN' => '1M',
  _ => value,
};

class _Tool extends StatelessWidget {
  const _Tool({required this.onTap, this.label, this.icon, super.key});
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      width: 28,
      height: 29,
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: icon == null
            ? Text(
                label!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Icon(icon, size: 16),
      ),
    ),
  );
}
