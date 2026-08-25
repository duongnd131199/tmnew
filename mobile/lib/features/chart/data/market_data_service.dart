import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

class MarketDataService {
  MarketDataService(this._dio, {this.marketApiBaseUrl = ''});

  static const realtimeHistoryLimit = 1000;

  final Dio _dio;
  final String marketApiBaseUrl;

  final Map<String, _Mt5FileSnapshot> _mt5FileCache = {};
  final Map<String, _Mt5ResultSnapshot> _mt5ResultCache = {};
  String? _lastM1Signature;
  double? _lastM1Close;

  static const _mt5HistoryRoot =
      '/sdcard/Android/data/net.metaquotes.metatrader5/files/bases/'
      'MetaQuotes-Demo/history';

  static const _symbols = <String, String>{
    'EURUSD': 'EURUSD=X',
    'GBPUSD': 'GBPUSD=X',
    'USDCHF': 'USDCHF=X',
    'USDJPY': 'USDJPY=X',
    'USDCNH': 'USDCNH=X',
    'USDRUB': 'USDRUB=X',
    'AUDUSD': 'AUDUSD=X',
    'NZDUSD': 'NZDUSD=X',
    'USDCAD': 'USDCAD=X',
    'USDSEK': 'USDSEK=X',
    'XAUUSD': 'GC=F',
    'BTCUSD': 'BTC-USD',
    'US30': '^DJI',
  };

  bool get usesRealtimeApi => marketApiBaseUrl.isNotEmpty;

  Future<bool> hasLocalMt5History(String symbol) async {
    if (usesRealtimeApi) return false;
    try {
      final stat = await File('$_mt5HistoryRoot/$symbol/cache/M1.hc').stat();
      return stat.type == FileSystemEntityType.file && stat.size >= 512;
    } on FileSystemException {
      return false;
    }
  }

  Future<List<MarketCandle>> fetchCandles(
    String symbol,
    String timeframe, {
    CancelToken? cancelToken,
  }) async {
    final initialCancellation = cancelToken?.cancelError;
    if (initialCancellation != null) throw initialCancellation;
    if (usesRealtimeApi) {
      return _fetchRealtimeApiCandles(
        symbol,
        timeframe,
        cancelToken: cancelToken,
      );
    }
    final mt5Candles = await _fetchMt5Candles(symbol, timeframe);
    final localCancellation = cancelToken?.cancelError;
    if (localCancellation != null) throw localCancellation;
    if (mt5Candles != null && mt5Candles.isNotEmpty) return mt5Candles;

    final feedSymbol = switch (symbol) {
      'XAUUSD+' => 'XAUUSD',
      _ => symbol,
    };
    final yahooSymbol = _symbols[feedSymbol] ?? '$feedSymbol=X';
    final rawInterval = _rawInterval(timeframe);
    final response = await _dio.get<Map<String, dynamic>>(
      'https://query1.finance.yahoo.com/v8/finance/chart/'
      '${Uri.encodeComponent(yahooSymbol)}',
      queryParameters: {
        'interval': rawInterval,
        'range': _range(timeframe),
        'includePrePost': 'false',
        'events': 'div,splits',
      },
      options: Options(headers: const {'User-Agent': 'Mozilla/5.0'}),
      cancelToken: cancelToken,
    );
    final chart = response.data?['chart'] as Map<String, dynamic>?;
    final results = chart?['result'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw StateError('Nguồn thị trường không trả về dữ liệu');
    }
    final result = results.first as Map<String, dynamic>;
    final timestamps = (result['timestamp'] as List<dynamic>?) ?? const [];
    final indicators = result['indicators'] as Map<String, dynamic>?;
    final quotes = indicators?['quote'] as List<dynamic>?;
    if (quotes == null || quotes.isEmpty) {
      throw StateError('Nguồn thị trường không trả về OHLC');
    }
    final quote = quotes.first as Map<String, dynamic>;
    final opens = quote['open'] as List<dynamic>? ?? const [];
    final highs = quote['high'] as List<dynamic>? ?? const [];
    final lows = quote['low'] as List<dynamic>? ?? const [];
    final closes = quote['close'] as List<dynamic>? ?? const [];
    final candles = <MarketCandle>[];
    for (var index = 0; index < timestamps.length; index++) {
      if (index >= opens.length ||
          index >= highs.length ||
          index >= lows.length ||
          index >= closes.length) {
        break;
      }
      final open = (opens[index] as num?)?.toDouble();
      final high = (highs[index] as num?)?.toDouble();
      final low = (lows[index] as num?)?.toDouble();
      final close = (closes[index] as num?)?.toDouble();
      if (open == null || high == null || low == null || close == null) {
        continue;
      }
      candles.add(
        MarketCandle(
          time: DateTime.fromMillisecondsSinceEpoch(
            (timestamps[index] as num).toInt() * 1000,
            isUtc: true,
          ).toLocal(),
          open: open,
          high: high,
          low: low,
          close: close,
        ),
      );
    }
    if (candles.isEmpty) throw StateError('Không có nến hợp lệ');
    final factor = _aggregateFactor(timeframe);
    final normalized = factor > 1
        ? aggregateCandles(candles, timeframe)
        : candles;
    return normalized.length > 360
        ? normalized.sublist(normalized.length - 360)
        : normalized;
  }

  Future<List<MarketCandle>> _fetchRealtimeApiCandles(
    String symbol,
    String timeframe, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '$marketApiBaseUrl/api/market/candles',
      queryParameters: {
        'symbol': symbol,
        'timeframe': timeframe,
        'limit': realtimeHistoryLimit,
      },
      cancelToken: cancelToken,
    );
    final payload = response.data ?? const <dynamic>[];
    final candles =
        payload
            .whereType<Map<String, dynamic>>()
            .map((item) {
              final time = DateTime.tryParse(item['time']?.toString() ?? '');
              if (time == null) {
                throw const FormatException(
                  'Invalid realtime candle timestamp',
                );
              }
              return MarketCandle(
                time: time.toUtc(),
                open: _jsonDouble(item['open']),
                high: _jsonDouble(item['high']),
                low: _jsonDouble(item['low']),
                close: _jsonDouble(item['close']),
                volume: _jsonDoubleOrZero(item['volume']),
              );
            })
            .toList(growable: false)
          ..sort((left, right) => left.time.compareTo(right.time));
    if (candles.isEmpty) {
      throw StateError(
        'MT5 feed has no $symbol $timeframe candle history yet.',
      );
    }
    return candles;
  }

  Future<List<MarketCandle>?> _fetchMt5Candles(
    String symbol,
    String timeframe,
  ) async {
    final fileName = switch (timeframe) {
      'D1' => 'Daily.hc',
      'W1' => 'Weekly.hc',
      'MN' => 'Monthly.hc',
      _ => 'M1.hc',
    };
    final path = '$_mt5HistoryRoot/$symbol/cache/$fileName';
    try {
      final file = File(path);
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size < 512) {
        return null;
      }
      var signature = '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
      if (fileName != 'M1.hc') {
        final m1Stat = await File(
          '$_mt5HistoryRoot/$symbol/cache/M1.hc',
        ).stat();
        signature =
            '$signature:${m1Stat.modified.microsecondsSinceEpoch}:${m1Stat.size}';
      }
      final resultKey = '$path:$timeframe';
      final cachedResult = _mt5ResultCache[resultKey];
      if (cachedResult?.signature == signature) return cachedResult!.candles;

      var sourceSnapshot = _mt5FileCache[path];
      if (sourceSnapshot?.signature != signature) {
        final bytes = await file.readAsBytes();
        final parsed = parseMt5HistoryCache(bytes);
        if (parsed.isEmpty) return null;
        sourceSnapshot = _Mt5FileSnapshot(signature, parsed);
        _mt5FileCache[path] = sourceSnapshot;
      }

      final source = sourceSnapshot;
      if (source == null) return null;
      final shouldAggregate = fileName == 'M1.hc' && timeframe != 'M1';
      final normalized = shouldAggregate
          ? aggregateCandles(source.candles, timeframe)
          : source.candles;
      var visible = normalized.length > 360
          ? normalized.sublist(normalized.length - 360)
          : List<MarketCandle>.of(normalized);
      if (fileName != 'M1.hc' && visible.isNotEmpty) {
        final liveClose = await _readLastMt5M1Close(symbol);
        if (liveClose != null) {
          visible = List<MarketCandle>.of(visible);
          final last = visible.last;
          visible[visible.length - 1] = MarketCandle(
            time: last.time,
            open: last.open,
            high: liveClose > last.high ? liveClose : last.high,
            low: liveClose < last.low ? liveClose : last.low,
            close: liveClose,
            volume: last.volume,
          );
        }
      }
      _mt5ResultCache[resultKey] = _Mt5ResultSnapshot(signature, visible);
      return visible;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  Future<double?> _readLastMt5M1Close(String symbol) async {
    final file = File('$_mt5HistoryRoot/$symbol/cache/M1.hc');
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return null;
    final signature = '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
    if (_lastM1Signature == signature) return _lastM1Close;
    final reader = await file.open();
    try {
      await reader.setPosition(348);
      final countBytes = await reader.read(4);
      if (countBytes.length != 4) return null;
      final count = ByteData.sublistView(countBytes).getInt32(0, Endian.little);
      if (count <= 0 || count > 500000) return null;
      final closeOffset = 368 + count * 8 * 4 + (count - 1) * 8;
      await reader.setPosition(closeOffset);
      final closeBytes = await reader.read(8);
      if (closeBytes.length != 8) return null;
      final close = ByteData.sublistView(
        closeBytes,
      ).getFloat64(0, Endian.little);
      _lastM1Signature = signature;
      _lastM1Close = close;
      return close;
    } finally {
      await reader.close();
    }
  }

  List<MarketCandle> parseMt5HistoryCache(Uint8List bytes) {
    const countOffset = 348;
    const timeOffset = 352;
    if (bytes.length < timeOffset) return const [];
    final data = ByteData.sublistView(bytes);
    final count = data.getInt32(countOffset, Endian.little);
    if (count <= 0 || count > 500000) throw const FormatException();
    final columnBytes = count * 8;
    final openCountOffset = timeOffset + columnBytes;
    final openOffset = openCountOffset + 4;
    final highCountOffset = openOffset + columnBytes;
    final highOffset = highCountOffset + 4;
    final lowCountOffset = highOffset + columnBytes;
    final lowOffset = lowCountOffset + 4;
    final closeCountOffset = lowOffset + columnBytes;
    final closeOffset = closeCountOffset + 4;
    if (closeOffset + columnBytes > bytes.length) throw const FormatException();
    for (final offset in [
      openCountOffset,
      highCountOffset,
      lowCountOffset,
      closeCountOffset,
    ]) {
      if (data.getInt32(offset, Endian.little) != count) {
        throw const FormatException();
      }
    }

    return List<MarketCandle>.generate(count, (index) {
      final time = data.getInt64(timeOffset + index * 8, Endian.little);
      return MarketCandle(
        time: DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true),
        open: data.getFloat64(openOffset + index * 8, Endian.little),
        high: data.getFloat64(highOffset + index * 8, Endian.little),
        low: data.getFloat64(lowOffset + index * 8, Endian.little),
        close: data.getFloat64(closeOffset + index * 8, Endian.little),
      );
    }, growable: false);
  }

  String _interval(String timeframe) => switch (timeframe) {
    'M1' => '1m',
    'M5' => '5m',
    'M15' => '15m',
    'M30' => '30m',
    'H1' => '1h',
    'D1' => '1d',
    'W1' => '1wk',
    'MN' => '1mo',
    _ => '15m',
  };

  String _rawInterval(String timeframe) {
    if (const {
      'M2',
      'M3',
      'M4',
      'M6',
      'M10',
      'M12',
      'M20',
    }.contains(timeframe)) {
      return '1m';
    }
    if (const {'H2', 'H3', 'H4', 'H6', 'H8', 'H12'}.contains(timeframe)) {
      return '1h';
    }
    return _interval(timeframe);
  }

  int _aggregateFactor(String timeframe) => switch (timeframe) {
    'M2' => 2,
    'M3' => 3,
    'M4' => 4,
    'M6' => 6,
    'M10' => 10,
    'M12' => 12,
    'M20' => 20,
    'H2' => 2,
    'H3' => 3,
    'H4' => 4,
    'H6' => 6,
    'H8' => 8,
    'H12' => 12,
    _ => 1,
  };

  String _range(String timeframe) => switch (timeframe) {
    'M1' => '1d',
    'M2' ||
    'M3' ||
    'M4' ||
    'M5' ||
    'M6' ||
    'M10' ||
    'M12' ||
    'M15' ||
    'M20' ||
    'M30' => '5d',
    'H1' || 'H2' || 'H3' || 'H4' || 'H6' || 'H8' || 'H12' => '1mo',
    'D1' => '1y',
    'W1' => '5y',
    'MN' => '10y',
    _ => '5d',
  };

  List<MarketCandle> aggregateCandles(
    List<MarketCandle> source,
    String timeframe,
  ) {
    final result = <MarketCandle>[];
    var group = <MarketCandle>[];
    DateTime? activeBucket;

    void flush() {
      if (group.isEmpty || activeBucket == null) return;
      result.add(
        MarketCandle(
          time: activeBucket,
          open: group.first.open,
          high: group.map((item) => item.high).reduce((a, b) => a > b ? a : b),
          low: group.map((item) => item.low).reduce((a, b) => a < b ? a : b),
          close: group.last.close,
          volume: group.fold<double>(
            0,
            (total, candle) => total + candle.volume,
          ),
        ),
      );
      group = <MarketCandle>[];
    }

    for (final candle in source) {
      final bucket = bucketStart(candle.time, timeframe);
      if (activeBucket != null && bucket != activeBucket) flush();
      activeBucket = bucket;
      group.add(candle);
    }
    flush();
    return result;
  }

  /// Applies one quote to the active timeframe candle.
  ///
  /// A quote inside the active bucket mutates only high/low/close. A quote on
  /// a later boundary starts one new flat candle. Missing buckets are not
  /// synthesized because MT5 also waits for the first tick before opening a
  /// bar.
  static List<MarketCandle> applyQuoteTick(
    List<MarketCandle> source, {
    required String timeframe,
    required double price,
    required DateTime receivedAt,
    int maxCandles = 360,
  }) {
    if (!price.isFinite || price <= 0 || maxCandles <= 0) {
      return List<MarketCandle>.unmodifiable(source);
    }

    final result = List<MarketCandle>.of(source);
    final tickTime = result.isEmpty
        ? receivedAt
        : _inSameZone(receivedAt, result.last.time);
    final tickBucket = bucketStart(tickTime, timeframe);
    if (result.isEmpty) {
      return List<MarketCandle>.unmodifiable([
        MarketCandle(
          time: tickBucket,
          open: price,
          high: price,
          low: price,
          close: price,
        ),
      ]);
    }

    final last = result.last;
    final lastBucket = bucketStart(last.time, timeframe);
    if (tickBucket.isBefore(lastBucket)) {
      return List<MarketCandle>.unmodifiable(result);
    }
    if (tickBucket == lastBucket) {
      result[result.length - 1] = MarketCandle(
        time: lastBucket,
        open: last.open,
        high: price > last.high ? price : last.high,
        low: price < last.low ? price : last.low,
        close: price,
        volume: last.volume,
      );
    } else {
      result.add(
        MarketCandle(
          time: tickBucket,
          open: price,
          high: price,
          low: price,
          close: price,
        ),
      );
    }
    if (result.length > maxCandles) {
      result.removeRange(0, result.length - maxCandles);
    }
    return List<MarketCandle>.unmodifiable(result);
  }

  /// Overlays the quote-built tail on top of a historical or reference seed.
  ///
  /// This lets the supplied MT5 contour remain visually stable while the
  /// right-most bar still follows live OHLC values and timeframe rollovers.
  static List<MarketCandle> mergeLiveTail(
    List<MarketCandle> base,
    List<MarketCandle> liveTail, {
    required String timeframe,
    int maxCandles = 360,
  }) {
    if (maxCandles <= 0) return const [];
    final result = List<MarketCandle>.of(base);
    for (final sourceLive in liveTail) {
      final liveTime = result.isEmpty
          ? sourceLive.time
          : _inSameZone(sourceLive.time, result.last.time);
      final liveBucket = bucketStart(liveTime, timeframe);
      final live = MarketCandle(
        time: liveBucket,
        open: sourceLive.open,
        high: sourceLive.high,
        low: sourceLive.low,
        close: sourceLive.close,
        volume: sourceLive.volume,
      );
      if (result.isEmpty) {
        result.add(live);
        continue;
      }

      final last = result.last;
      final lastBucket = bucketStart(last.time, timeframe);
      if (liveBucket.isBefore(lastBucket)) continue;
      if (liveBucket == lastBucket) {
        result[result.length - 1] = MarketCandle(
          time: lastBucket,
          open: last.open,
          high: live.high > last.high ? live.high : last.high,
          low: live.low < last.low ? live.low : last.low,
          close: live.close,
          volume: live.volume,
        );
      } else {
        result.add(live);
      }
    }
    if (result.length > maxCandles) {
      result.removeRange(0, result.length - maxCandles);
    }
    return List<MarketCandle>.unmodifiable(result);
  }

  static Duration timeframeDuration(String timeframe) => switch (timeframe) {
    'MN' => const Duration(days: 31),
    'W1' => const Duration(days: 7),
    'D1' => const Duration(days: 1),
    _ when timeframe.startsWith('H') => Duration(
      hours: int.tryParse(timeframe.substring(1)) ?? 1,
    ),
    _ when timeframe.startsWith('M') => Duration(
      minutes: int.tryParse(timeframe.substring(1)) ?? 1,
    ),
    _ => const Duration(minutes: 15),
  };

  static DateTime bucketStart(DateTime time, String timeframe) {
    if (timeframe == 'MN') {
      return _dateLike(time, time.year, time.month);
    }
    if (timeframe == 'W1') {
      final day = _dateLike(time, time.year, time.month, time.day);
      return day.subtract(Duration(days: time.weekday - DateTime.monday));
    }
    if (timeframe == 'D1') {
      return _dateLike(time, time.year, time.month, time.day);
    }
    if (timeframe.startsWith('H')) {
      final hours = int.tryParse(timeframe.substring(1)) ?? 1;
      return _dateLike(
        time,
        time.year,
        time.month,
        time.day,
        time.hour ~/ hours * hours,
      );
    }
    if (timeframe.startsWith('M')) {
      final minutes = int.tryParse(timeframe.substring(1)) ?? 1;
      return _dateLike(
        time,
        time.year,
        time.month,
        time.day,
        time.hour,
        time.minute ~/ minutes * minutes,
      );
    }
    return _dateLike(
      time,
      time.year,
      time.month,
      time.day,
      time.hour,
      time.minute ~/ 15 * 15,
    );
  }

  static DateTime nextBoundary(DateTime time, String timeframe) {
    final start = bucketStart(time, timeframe);
    if (timeframe == 'MN') {
      return _dateLike(start, start.year, start.month + 1);
    }
    if (timeframe == 'W1') {
      return _dateLike(start, start.year, start.month, start.day + 7);
    }
    if (timeframe == 'D1') {
      return _dateLike(start, start.year, start.month, start.day + 1);
    }
    return start.add(timeframeDuration(timeframe));
  }

  static DateTime _inSameZone(DateTime time, DateTime reference) =>
      reference.isUtc ? time.toUtc() : time.toLocal();

  static DateTime _dateLike(
    DateTime reference,
    int year,
    int month, [
    int day = 1,
    int hour = 0,
    int minute = 0,
  ]) => reference.isUtc
      ? DateTime.utc(year, month, day, hour, minute)
      : DateTime(year, month, day, hour, minute);

  static double _jsonDouble(Object? value) =>
      value is num ? value.toDouble() : double.parse(value.toString());

  static double _jsonDoubleOrZero(Object? value) {
    if (value == null) return 0;
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }
}

class _Mt5FileSnapshot {
  const _Mt5FileSnapshot(this.signature, this.candles);

  final String signature;
  final List<MarketCandle> candles;
}

class _Mt5ResultSnapshot {
  const _Mt5ResultSnapshot(this.signature, this.candles);

  final String signature;
  final List<MarketCandle> candles;
}
