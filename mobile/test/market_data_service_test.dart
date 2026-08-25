import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/chart/data/market_data_service.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';

void main() {
  MarketCandle candle(int hour, int minute, double price) => MarketCandle(
    time: DateTime(2026, 7, 18, hour, minute),
    open: price,
    high: price + .0002,
    low: price - .0001,
    close: price + .0001,
  );

  test('minute timeframes aggregate on wall-clock boundaries', () {
    final service = MarketDataService(Dio());
    final result = service.aggregateCandles([
      candle(10, 3, 1.10),
      candle(10, 4, 1.11),
      candle(10, 5, 1.12),
      candle(10, 6, 1.13),
      candle(10, 7, 1.14),
      candle(10, 8, 1.15),
    ], 'M4');

    expect(result.map((item) => item.time.minute), [0, 4, 8]);
    expect(result[1].open, 1.11);
    expect(result[1].close, closeTo(1.1401, .000001));
  });

  test('hour timeframes aggregate on wall-clock boundaries', () {
    final service = MarketDataService(Dio());
    final result = service.aggregateCandles([
      candle(3, 0, 1.10),
      candle(4, 0, 1.11),
      candle(5, 0, 1.12),
      candle(7, 0, 1.13),
      candle(8, 0, 1.14),
    ], 'H4');

    expect(result.map((item) => item.time.hour), [0, 4, 8]);
    expect(result[1].open, 1.11);
    expect(result[1].close, closeTo(1.1301, .000001));
  });

  test('XAUUSD+ falls back to the XAUUSD Yahoo feed symbol', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;

    final result = await MarketDataService(dio).fetchCandles('XAUUSD+', 'H4');

    expect(adapter.requestedUri?.pathSegments.last, 'GC=F');
    expect(adapter.requestedUri?.queryParameters['interval'], '1h');
    expect(result, hasLength(1));
    expect(result.single.close, 4104.5);
  });

  test('configured MT5 API supplies exact broker candle history', () async {
    final adapter = _RealtimeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;

    final result = await MarketDataService(
      dio,
      marketApiBaseUrl: 'https://api.example.com',
    ).fetchCandles('XAUUSD+', 'H4');

    expect(adapter.requestedUri?.path, '/api/market/candles');
    expect(adapter.requestedUri?.queryParameters['symbol'], 'XAUUSD+');
    expect(adapter.requestedUri?.queryParameters['timeframe'], 'H4');
    expect(
      adapter.requestedUri?.queryParameters['limit'],
      '${MarketDataService.realtimeHistoryLimit}',
    );
    expect(result, hasLength(2));
    expect(result.last.time.isUtc, isTrue);
    expect(result.last.time.toUtc(), DateTime.utc(2026, 7, 31, 8));
    expect(result.last.open, 4100);
    expect(result.last.high, 4107);
    expect(result.last.low, 4098);
    expect(result.last.close, 4104.12);
    expect(result.last.volume, 120);
  });

  test('aggregated candles sum source volume', () {
    final service = MarketDataService(Dio());
    final source = [
      MarketCandle(
        time: DateTime(2026, 7, 18, 10),
        open: 1,
        high: 2,
        low: .5,
        close: 1.5,
        volume: 120,
      ),
      MarketCandle(
        time: DateTime(2026, 7, 18, 10, 1),
        open: 1.5,
        high: 2.5,
        low: 1,
        close: 2,
        volume: 80,
      ),
    ];

    final result = service.aggregateCandles(source, 'M5');

    expect(result.single.volume, 200);
  });

  test('XAUUSD+ H4 quote ticks mutate active close, high and low', () {
    var result = <MarketCandle>[
      MarketCandle(
        time: DateTime(2026, 7, 27, 8),
        open: 4105,
        high: 4105,
        low: 4105,
        close: 4105,
      ),
    ];

    result = MarketDataService.applyQuoteTick(
      result,
      timeframe: 'H4',
      price: 4106,
      receivedAt: DateTime(2026, 7, 27, 9, 21),
    );
    result = MarketDataService.applyQuoteTick(
      result,
      timeframe: 'H4',
      price: 4104,
      receivedAt: DateTime(2026, 7, 27, 9, 22),
    );

    expect(result, hasLength(1));
    expect(result.single.time, DateTime(2026, 7, 27, 8));
    expect(result.single.open, 4105);
    expect(result.single.high, 4106);
    expect(result.single.low, 4104);
    expect(result.single.close, 4104);
  });

  test('BTCUSD H4 quote ticks mutate active close, high and low', () {
    var result = <MarketCandle>[
      MarketCandle(
        time: DateTime(2026, 7, 27, 8),
        open: 65100,
        high: 65100,
        low: 65100,
        close: 65100,
      ),
    ];

    result = MarketDataService.applyQuoteTick(
      result,
      timeframe: 'H4',
      price: 65200,
      receivedAt: DateTime(2026, 7, 27, 10),
    );
    result = MarketDataService.applyQuoteTick(
      result,
      timeframe: 'H4',
      price: 64900,
      receivedAt: DateTime(2026, 7, 27, 10, 1),
    );

    expect(result, hasLength(1));
    expect(result.single.open, 65100);
    expect(result.single.high, 65200);
    expect(result.single.low, 64900);
    expect(result.single.close, 64900);
  });

  test('H4 boundary appends one flat candle at the first new-bucket tick', () {
    final source = <MarketCandle>[
      MarketCandle(
        time: DateTime(2026, 7, 27, 8),
        open: 4105,
        high: 4106,
        low: 4104,
        close: 4104,
      ),
    ];

    final result = MarketDataService.applyQuoteTick(
      source,
      timeframe: 'H4',
      price: 4107,
      receivedAt: DateTime(2026, 7, 27, 12),
    );

    expect(result, hasLength(2));
    expect(result.last.time, DateTime(2026, 7, 27, 12));
    expect(result.last.open, 4107);
    expect(result.last.high, 4107);
    expect(result.last.low, 4107);
    expect(result.last.close, 4107);
    expect(
      MarketDataService.nextBoundary(result.last.time, 'H4'),
      DateTime(2026, 7, 27, 16),
    );
  });

  test('MetaTrader HC column cache is decoded into exact OHLC bars', () {
    const count = 2;
    const timeOffset = 352;
    const columnBytes = count * 8;
    const openCount = timeOffset + columnBytes;
    const openOffset = openCount + 4;
    const highCount = openOffset + columnBytes;
    const highOffset = highCount + 4;
    const lowCount = highOffset + columnBytes;
    const lowOffset = lowCount + 4;
    const closeCount = lowOffset + columnBytes;
    const closeOffset = closeCount + 4;
    final bytes = Uint8List(closeOffset + columnBytes);
    final data = ByteData.sublistView(bytes);
    data.setInt32(348, count, Endian.little);
    for (final offset in [openCount, highCount, lowCount, closeCount]) {
      data.setInt32(offset, count, Endian.little);
    }
    for (var index = 0; index < count; index++) {
      data.setInt64(
        timeOffset + index * 8,
        1784246400 + index * 60,
        Endian.little,
      );
      data.setFloat64(
        openOffset + index * 8,
        1.1400 + index * .001,
        Endian.little,
      );
      data.setFloat64(
        highOffset + index * 8,
        1.1420 + index * .001,
        Endian.little,
      );
      data.setFloat64(
        lowOffset + index * 8,
        1.1390 + index * .001,
        Endian.little,
      );
      data.setFloat64(
        closeOffset + index * 8,
        1.1410 + index * .001,
        Endian.little,
      );
    }

    final result = MarketDataService(Dio()).parseMt5HistoryCache(bytes);

    expect(result, hasLength(2));
    expect(result.last.time.toUtc(), DateTime.utc(2026, 7, 17, 0, 1));
    expect(result.last.open, closeTo(1.141, .000001));
    expect(result.last.high, closeTo(1.143, .000001));
    expect(result.last.low, closeTo(1.140, .000001));
    expect(result.last.close, closeTo(1.142, .000001));
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  Uri? requestedUri;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUri = options.uri;
    return ResponseBody.fromString(
      jsonEncode({
        'chart': {
          'result': [
            {
              'timestamp': [1785196800],
              'indicators': {
                'quote': [
                  {
                    'open': [4104.0],
                    'high': [4105.0],
                    'low': [4103.0],
                    'close': [4104.5],
                  },
                ],
              },
            },
          ],
          'error': null,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RealtimeAdapter implements HttpClientAdapter {
  Uri? requestedUri;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUri = options.uri;
    return ResponseBody.fromString(
      jsonEncode([
        {
          'symbol': 'XAUUSD+',
          'timeframe': 'H4',
          'time': '2026-07-31T04:00:00Z',
          'open': 4096.0,
          'high': 4102.0,
          'low': 4095.0,
          'close': 4100.0,
          'volume': 100,
        },
        {
          'symbol': 'XAUUSD+',
          'timeframe': 'H4',
          'time': '2026-07-31T08:00:00Z',
          'open': 4100.0,
          'high': 4107.0,
          'low': 4098.0,
          'close': 4104.12,
          'volume': 120,
        },
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
