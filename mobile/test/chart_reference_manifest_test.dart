import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _timeframes = <String>[
  'M1',
  'M5',
  'M15',
  'M30',
  'H1',
  'H4',
  'D1',
  'W1',
  'MN',
];
const _zooms = <String>['min', 'default', 'max'];
const _sources = <String>['ref', 'dev-before'];
const _referencePalette = <String, String>{
  'canvas': '#FFFFFF',
  'grid': '#E8E8E8',
  'bullishCandle': '#26A69A',
  'bearishCandle': '#EF5350',
  'tradingBlue': '#3183FF',
  'primaryTextAndAxes': '#000000',
};
const _maskExclusions = <String>[
  'changing prices',
  'timestamps',
  'candle data contour',
  'Android status/navigation chrome',
  'shared bottom navigation',
];

void main() {
  test('chart light manifest preserves the two-emulator reference matrix', () {
    final manifestFile = File('../reference/screens/chart/light/manifest.json');
    expect(manifestFile.existsSync(), isTrue);

    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['canonicalDevice'], {
      'width': 590,
      'height': 1280,
      'densityDpi': 240,
    });
    expect(manifest['referenceTargetPalette'], _referencePalette);
    expect(manifest['comparisonMaskExclusions'], _maskExclusions);
    final goldenMatrix = manifest['goldenMatrix'] as Map<String, dynamic>;
    expect(goldenMatrix['logicalSurface'], {'width': 394, 'height': 854});
    expect(goldenMatrix['derivedFromDevice'], manifest['canonicalDevice']);
    expect(
      goldenMatrix['pathPattern'],
      'mobile/test/goldens/chart/light/<timeframe>-<zoom>.png',
    );
    expect(goldenMatrix['generatedCount'], 27);
    for (final timeframe in _timeframes) {
      for (final zoom in _zooms) {
        final image = File('test/goldens/chart/light/$timeframe-$zoom.png');
        expect(image.existsSync(), isTrue, reason: '$timeframe/$zoom');
        expect(
          _pngSize(image.readAsBytesSync()),
          const _PngSize(394, 854),
          reason: '$timeframe/$zoom',
        );
      }
    }

    final entries = (manifest['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      entries,
      hasLength(_sources.length * _timeframes.length * _zooms.length),
    );
    expect(
      entries
          .map(
            (entry) =>
                '${entry['source']}/${entry['timeframe']}/${entry['zoom']}',
          )
          .toSet(),
      {
        for (final source in _sources)
          for (final timeframe in _timeframes)
            for (final zoom in _zooms) '$source/$timeframe/$zoom',
      },
    );

    final capturedKeys = <String>{};
    for (final entry in entries) {
      final key = '${entry['source']}/${entry['timeframe']}/${entry['zoom']}';
      expect(entry['device'], manifest['canonicalDevice'], reason: key);
      expect(entry['comparisonMaskExclusions'], _maskExclusions, reason: key);
      expect(entry['targetPalette'], 'referenceTargetPalette', reason: key);
      expect(
        DateTime.tryParse(entry['capturedAt'] as String),
        isNotNull,
        reason: key,
      );
      expect(
        entry['visibleCandleCount'],
        isA<int>().having((value) => value, 'positive', greaterThan(0)),
        reason: key,
      );
      expect(
        entry['rightAxisWidth'],
        isA<num>().having((value) => value, 'positive', greaterThan(0)),
        reason: key,
      );
      expect(
        entry['bottomAxisHeight'],
        isA<num>().having((value) => value, 'positive', greaterThan(0)),
        reason: key,
      );

      final crop = entry['chartRegion'] as Map<String, dynamic>;
      for (final field in ['x', 'y', 'width', 'height']) {
        expect(crop[field], isA<num>(), reason: '$key crop $field');
      }
      expect(crop['x'], greaterThanOrEqualTo(0), reason: key);
      expect(crop['y'], greaterThanOrEqualTo(0), reason: key);
      expect(crop['width'], greaterThan(0), reason: key);
      expect(crop['height'], greaterThan(0), reason: key);
      expect(
        (crop['x'] as num) + (crop['width'] as num),
        lessThanOrEqualTo(590),
        reason: key,
      );
      expect(
        (crop['y'] as num) + (crop['height'] as num),
        lessThanOrEqualTo(1280),
        reason: key,
      );

      switch (entry['captureState']) {
        case 'captured':
          capturedKeys.add(key);
          final screenshotPath = entry['screenshotPath'];
          expect(
            screenshotPath,
            isA<String>().having((value) => value, 'non-empty', isNotEmpty),
            reason: key,
          );
          expect(entry.containsKey('fixtureNote'), isFalse, reason: key);
          final confirmation =
              entry['operatorStateConfirmation'] as Map<String, dynamic>;
          expect(confirmation['timeframe'], entry['timeframe'], reason: key);
          expect(confirmation['zoom'], entry['zoom'], reason: key);
          expect(
            confirmation['zoomVerification'],
            'operator-confirmed; native automation unavailable',
            reason: key,
          );
          final image = File('../$screenshotPath');
          expect(image.existsSync(), isTrue, reason: key);
          expect(
            _pngSize(image.readAsBytesSync()),
            const _PngSize(590, 1280),
            reason: key,
          );
          if (entry['source'] == 'ref') {
            expect(
              entry['observedColorStatus'],
              'reference-sampled',
              reason: key,
            );
            expect(entry['observedColors'], _referencePalette, reason: key);
          } else {
            expect(entry['observedColorStatus'], 'not-sampled', reason: key);
            expect(entry['observedColors'], isNull, reason: key);
          }
        case 'fixture-pending-native-pinch':
          expect(entry['screenshotPath'], isNull, reason: key);
          expect(
            entry['fixtureNote'],
            isA<String>().having((value) => value, 'non-empty', isNotEmpty),
            reason: key,
          );
          expect(entry['operatorStateConfirmation'], isNull, reason: key);
          expect(entry['observedColorStatus'], 'not-sampled', reason: key);
          expect(entry['observedColors'], isNull, reason: key);
        default:
          fail('Unexpected capture state for $key: ${entry['captureState']}');
      }
    }

    expect(capturedKeys, {'ref/M5/default', 'dev-before/M5/default'});
  });

  test(
    'capture script preflight uses fallback ADB and requires operator confirmation',
    () async {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          '../scripts/capture-chart-parity.ps1',
          '-ReferenceSerial',
          '127.0.0.1:5561',
          '-DevelopmentSerial',
          '127.0.0.1:5555',
          '-Timeframe',
          'M5',
          '-Zoom',
          'default',
          '-OperatorStateConfirmation',
          'timeframe=M5;zoom=default;symbol=BTCUSD;oneClickPanel=visible',
          '-OutputRoot',
          '..',
          '-PreflightOnly',
        ],
        workingDirectory: Directory.current.path,
        environment: {...Platform.environment, 'ANDROID_HOME': ''},
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('Capture preflight passed'));
    },
    skip: Platform.isWindows
        ? false
        : 'capture-chart-parity.ps1 requires Windows PowerShell',
  );
}

_PngSize _pngSize(List<int> bytes) {
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  expect(bytes.length, greaterThanOrEqualTo(24));
  expect(bytes.take(8), orderedEquals(signature));
  return _PngSize(data.getUint32(16), data.getUint32(20));
}

class _PngSize {
  const _PngSize(this.width, this.height);

  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is _PngSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '${width}x$height';
}
