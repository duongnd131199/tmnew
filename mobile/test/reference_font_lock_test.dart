import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'test_support/reference_font_lock.dart';
import 'test_support/reference_typography_sources.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all eleven reference files retain exact identity and authority', () async {
    const expectedSources =
        <
          String,
          ({
            String path,
            String sha256,
            int width,
            int height,
            String encoding,
            String authority,
            String theme,
          })
        >{
          'prices': (
            path: '../iconMau/anhmau/photo_2026-08-25_22-30-10.jpg',
            sha256:
                '6739a1668fa87ca745f5e43ea472c2413ef0434fa1074c3b180c7278ea658db5',
            width: 590,
            height: 1280,
            encoding: 'jpeg',
            authority: 'canonical-prices',
            theme: 'light',
          ),
          'chart': (
            path: '../iconMau/anhmau/photo_2026-08-25_22-30-17.jpg',
            sha256:
                'e5d878286e76f843fec97ac2fc14de68d219fd20475a381a2bda941226854e31',
            width: 590,
            height: 1280,
            encoding: 'jpeg',
            authority: 'canonical-chart',
            theme: 'light',
          ),
          'trade-light': (
            path: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
            sha256:
                '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
            width: 590,
            height: 1280,
            encoding: 'jpeg',
            authority: 'canonical-trade',
            theme: 'light',
          ),
          'history-positions': (
            path: '../iconMau/anhmau/photo_2026-08-25_22-30-23.jpg',
            sha256:
                '40bfd8ddf3e24158453da32e4318e9219d02a201b09bb2fb53d6ee95a98a5924',
            width: 590,
            height: 1280,
            encoding: 'jpeg',
            authority: 'canonical-history-positions',
            theme: 'light',
          ),
          'history-orders-offset': (
            path: '../iconMau/anhmau/photo_2026-08-25_22-30-26.jpg',
            sha256:
                '48dbab6778e247325222bf0e10e991f0ef4d160ecf4cb4127be1e6d1b6eb83c1',
            width: 590,
            height: 1280,
            encoding: 'jpeg',
            authority: 'canonical-history-orders-offset',
            theme: 'light',
          ),
          'history-orders-summary': (
            path: '../iconMau/anhmau/photo_2026-08-25_22-30-29.jpg',
            sha256:
                '7f8d2fe5c086eacb5a8364435373645a4ba3e2ba3df7b852467b5a51d0ee45ee',
            width: 590,
            height: 1280,
            encoding: 'jpeg',
            authority: 'canonical-history-orders-summary',
            theme: 'light',
          ),
          'history-deals-summary': (
            path: '../iconMau/anhmau/photo_2026-08-25_22-30-34.jpg',
            sha256:
                '6fbbf3ccfc834b94052df32713a153c10518298b644844fb9482fa51a70e3bb9',
            width: 590,
            height: 1280,
            encoding: 'jpeg',
            authority: 'canonical-history-deals-summary',
            theme: 'light',
          ),
          'settings-primary': (
            path: '../iconMau/anhmau/image.png',
            sha256:
                '4c4f508369707ef576521c220e918bc0db5c9f3bdb900334ff5a5a859fcfcf9c',
            width: 590,
            height: 1280,
            encoding: 'png',
            authority: 'primary-settings',
            theme: 'light',
          ),
          'settings-secondary': (
            path: '../iconMau/anhmau/photo_2026-08-27_21-13-34.jpg',
            sha256:
                'bf67307f7e12f378ac2bf6abbbdf3b351d1e5492d59a50f0a0233b9a8955d092',
            width: 590,
            height: 1280,
            encoding: 'jpeg',
            authority: 'secondary-settings-shared-roles',
            theme: 'light',
          ),
          'trade-dark': (
            path: '../iconMau/anhmau/photo_2026-08-21_16-51-41.jpg',
            sha256:
                '349b41ed7ab4e974966b7bf1394e65f39cd43f07667613c5f92f0e2e8b2cefe9',
            width: 413,
            height: 881,
            encoding: 'jpeg',
            authority: 'separate-dark-trade',
            theme: 'dark',
          ),
          'partial-system-ui-crop': (
            path: '../iconMau/anhmau/photo_2026-08-31_10-47-10.jpg',
            sha256:
                '3e6d3c3693119c96f78c56e07638f54a16e8238911ec55b7cc94bddfb65ced57',
            width: 336,
            height: 331,
            encoding: 'jpeg',
            authority: 'partial-system-ui-crop',
            theme: 'light',
          ),
        };
    expect(referenceTypographySources, hasLength(11));
    expect(
      referenceTypographySources.map((item) => item.id).toSet(),
      expectedSources.keys.toSet(),
    );
    expect(referenceTypographySpecimenStrings, hasLength(11));
    for (final source in referenceTypographySources) {
      final expected = expectedSources[source.id]!;
      expect(source.path, expected.path, reason: source.id);
      expect(source.sha256, expected.sha256, reason: source.id);
      expect(
        (source.width, source.height),
        (expected.width, expected.height),
        reason: source.id,
      );
      expect(source.encoding, expected.encoding, reason: source.id);
      expect(source.authority, expected.authority, reason: source.id);
      expect(source.theme, expected.theme, reason: source.id);
      expect(source.hasCaptureProvenance, isFalse, reason: source.id);
      expect(source.certificationEligible, isFalse, reason: source.id);
      final bytes = await File(source.path).readAsBytes();
      expect(
        sha256.convert(bytes).toString(),
        source.sha256,
        reason: source.id,
      );
      final decoded = image.decodeImage(bytes)!;
      expect((decoded.width, decoded.height), (source.width, source.height));
      final decoder = image.findDecoderForData(bytes);
      if (source.encoding == 'png') {
        expect(bytes.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
        expect(decoder, isA<image.PngDecoder>(), reason: source.id);
      } else {
        expect(bytes.take(3), <int>[255, 216, 255]);
        expect(decoder, isA<image.JpegDecoder>(), reason: source.id);
      }
      expect(source.losslessSource, source.encoding == 'png');
      expect(
        source.certificationEligible,
        source.losslessSource && source.hasCaptureProvenance,
      );
    }
  });

  test('the immutable specimen preserves one typed structural delimiter', () {
    const exactRun = '4637.05 → 4640.81';
    expect(referenceTypographySpecimenStrings, contains(exactRun));
    expect(referenceTypographyNumericSpecimenStrings, contains(exactRun));
    expect(referenceTypographyStructuralDelimiterPolicies, hasLength(1));
    final policy = referenceTypographyStructuralDelimiterPolicies.single;
    expect(policy.key, 'numeric-price-arrow');
    expect(policy.specimen, exactRun);
    expect(policy.delimiterText, '→');
    expect(policy.codePoints, {0x2192});
    expect(policy.candidateRunKey, 'numeric-price-values');
    expect(
      policy.owner,
      ReferenceStructuralDelimiterOwner.deterministicVectorShape,
    );
    expect(
      policy.renderingContract,
      'keyed-deterministic-vector-shape-no-font-fallback',
    );
    expect(referenceTypographyExcludedStructuralCodePoints, {0x2192});
    expect(
      referenceTypographyAllCodePoints.difference(
        referenceTypographyCodePoints,
      ),
      {0x2192},
    );
  });

  test(
    'font-lock schema requires five lawful baselines and one numeric append slot',
    () {
      final original =
          jsonDecode(
                File(
                  'assets/fonts/mt5-reference/font-lock.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(original['schemaVersion'], 3);
      final fonts = original['fonts'] as List<dynamic>;
      expect(fonts, hasLength(5));
      expect(
        fonts
            .cast<Map<String, dynamic>>()
            .map((font) => font['sha256'])
            .toSet(),
        containsAll(const <String>{
          'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0',
        }),
      );
      for (final font in fonts.cast<Map<String, dynamic>>()) {
        expect(font, containsPair('assetPath', isNotEmpty));
        expect(font, containsPair('licenseEvidenceSha256', isNotEmpty));
        expect(font, containsPair('sourceArtifact', isA<Map>()));
      }

      final invalid = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      final invalidFonts = invalid['fonts'] as List<dynamic>;
      for (var index = 0; index < 2; index++) {
        final extra = Map<String, dynamic>.from(
          invalidFonts.first as Map<String, dynamic>,
        );
        extra['file'] = 'Extra$index.ttf';
        extra['assetPath'] = 'assets/fonts/mt5-reference/Extra$index.ttf';
        extra['sha256'] = '${index + 1}'.padLeft(64, '0');
        invalidFonts.add(extra);
      }
      final temporary = File(
        '${Directory.systemTemp.createTempSync('font-lock-count.').path}/lock.json',
      )..writeAsStringSync(jsonEncode(invalid));
      expect(
        () => ReferenceFontLock.read(temporary),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('exactly five or six'),
          ),
        ),
      );
    },
  );

  test('a sixth record is restricted to the typed lawful numeric contract', () {
    final invalid =
        jsonDecode(
              File(
                'assets/fonts/mt5-reference/font-lock.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final fonts = invalid['fonts'] as List<dynamic>;
    final extra = Map<String, dynamic>.from(
      fonts.first as Map<String, dynamic>,
    );
    extra['file'] = 'Numeric.ttf';
    extra['assetPath'] = 'assets/fonts/mt5-reference/Numeric.ttf';
    extra['sha256'] =
        '0000000000000000000000000000000000000000000000000000000000000000';
    extra['flutterFamily'] = 'WrongNumericFamily';
    extra['approvedRoleGroups'] = <String>['navigation'];
    fonts.add(extra);
    final temporary = File(
      '${Directory.systemTemp.createTempSync('font-lock-numeric.').path}/lock.json',
    )..writeAsStringSync(jsonEncode(invalid));
    expect(
      () => ReferenceFontLock.read(temporary),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Mt5ReferenceNumeric'),
        ),
      ),
    );
  });

  test('baseline roles and sixth evidence hashes cannot be weakened', () {
    final weakened = _fontLockJson();
    final weakenedFont =
        (weakened['fonts'] as List<dynamic>).first as Map<String, dynamic>;
    weakenedFont['approvedRoleGroups'] = <String>['navigation'];
    expect(
      () => ReferenceFontLock.read(_temporaryLock('weakened', weakened)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('approvedRoleGroups'),
        ),
      ),
    );

    final badLicense = _fontLockJson();
    final badLicenseExtra = _appendNumericRecord(badLicense);
    badLicenseExtra['licenseEvidenceSha256'] =
        '0000000000000000000000000000000000000000000000000000000000000000';
    expect(
      () => ReferenceFontLock.read(_temporaryLock('bad-license', badLicense)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('license evidence SHA mismatch'),
        ),
      ),
    );

    final badSource = _fontLockJson();
    final badSourceExtra = _appendNumericRecord(badSource);
    (badSourceExtra['sourceArtifact'] as Map<String, dynamic>)['sha256'] =
        '1111111111111111111111111111111111111111111111111111111111111111';
    expect(
      () => ReferenceFontLock.read(_temporaryLock('bad-source', badSource)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('source SHA'),
        ),
      ),
    );
  });

  test(
    'current sources are diagnostic because capture provenance is absent',
    () {
      expect(
        referenceTypographySources,
        everyElement(
          isA<ReferenceTypographySource>()
              .having(
                (item) => item.hasCaptureProvenance,
                'provenance',
                isFalse,
              )
              .having(
                (item) => item.certificationEligible,
                'eligible',
                isFalse,
              ),
        ),
      );
    },
  );

  test('all reference fonts match their hash, metadata, axes, and license', () {
    final lock = ReferenceFontLock.read(
      File('assets/fonts/mt5-reference/font-lock.json'),
    );
    expect(lock.sourcePackage.package, 'net.metaquotes.metatrader5');
    expect(lock.sourcePackage.versionName, '500.6140');
    expect(lock.sourcePackage.versionCode, 6140);
    expect(lock.sourcePackage.retrievedAt, '2026-08-31');
    expect(
      lock.sourcePackage.downloadUrl,
      'https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk',
    );
    expect(
      lock.sourcePackage.apkSha256,
      'c76582495cdd55061a38942bae9a4d2d33ed140840af94dec82cc6ad7001782b',
    );
    expect(
      lock.sourcePackage.licenseTextSha256,
      'c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4',
    );
    const requiredBaseShas = <String>{
      'f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27',
      '9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70',
      'f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8',
      'ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a',
      'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0',
    };
    final lockedShas = lock.fonts.map((entry) => entry.sha256).toSet();
    expect(lockedShas, containsAll(requiredBaseShas));
    expect(
      lock.fonts.where((entry) => requiredBaseShas.contains(entry.sha256)),
      hasLength(5),
    );
    const expectedBaseRecords =
        <
          String,
          ({
            String file,
            String family,
            String flutterFamily,
            int weight,
            String path,
            String archivePath,
            String sourceUrl,
            String retrievedAt,
            String license,
            int axisCount,
          })
        >{
          'f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27': (
            file: 'Roboto-Regular.ttf',
            family: 'Roboto',
            flutterFamily: 'Mt5ReferenceRoboto',
            weight: 400,
            path: 'assets/fonts/mt5-reference/Roboto-Regular.ttf',
            archivePath: 'assets/fonts/Roboto-Regular.ttf',
            sourceUrl:
                'https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk',
            retrievedAt: '2026-08-31',
            license: 'Apache-2.0',
            axisCount: 0,
          ),
          '9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70': (
            file: 'Roboto-Bold.ttf',
            family: 'Roboto',
            flutterFamily: 'Mt5ReferenceRoboto',
            weight: 700,
            path: 'assets/fonts/mt5-reference/Roboto-Bold.ttf',
            archivePath: 'assets/fonts/Roboto-Bold.ttf',
            sourceUrl:
                'https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk',
            retrievedAt: '2026-08-31',
            license: 'Apache-2.0',
            axisCount: 0,
          ),
          'f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8': (
            file: 'RobotoCondensed-Regular.ttf',
            family: 'Roboto Condensed',
            flutterFamily: 'Mt5ReferenceRobotoCondensed',
            weight: 400,
            path: 'assets/fonts/mt5-reference/RobotoCondensed-Regular.ttf',
            archivePath: 'assets/fonts/RobotoCondensed-Regular.ttf',
            sourceUrl:
                'https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk',
            retrievedAt: '2026-08-31',
            license: 'Apache-2.0',
            axisCount: 0,
          ),
          'ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a': (
            file: 'RobotoCondensed-Bold.ttf',
            family: 'Roboto Condensed',
            flutterFamily: 'Mt5ReferenceRobotoCondensed',
            weight: 700,
            path: 'assets/fonts/mt5-reference/RobotoCondensed-Bold.ttf',
            archivePath: 'assets/fonts/RobotoCondensed-Bold.ttf',
            sourceUrl:
                'https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk',
            retrievedAt: '2026-08-31',
            license: 'Apache-2.0',
            axisCount: 0,
          ),
          'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0': (
            file: 'RobotoCondensed-Variable.ttf',
            family: 'Roboto Condensed',
            flutterFamily: 'Mt5ReferenceRobotoCondensedVariable',
            weight: 400,
            path: 'assets/fonts/RobotoCondensed-Variable.ttf',
            archivePath: 'RobotoCondensed-Variable.ttf',
            sourceUrl:
                'https://raw.githubusercontent.com/google/fonts/main/ofl/robotocondensed/RobotoCondensed%5Bwght%5D.ttf',
            retrievedAt: '2026-08-26',
            license: 'Apache-2.0',
            axisCount: 1,
          ),
        };
    for (final entry in lock.fonts) {
      entry.verifyBytesAndSfntMetadata();
      expect(entry.approvedRoleGroups, isNotEmpty);
      expect(entry.redistributable, isTrue);
      expect(entry.licenseEvidencePath, isNotEmpty);
      expect(File(entry.licenseEvidencePath).existsSync(), isTrue);
      if (requiredBaseShas.contains(entry.sha256)) {
        final expected = expectedBaseRecords[entry.sha256]!;
        expect(entry.file, expected.file);
        expect(entry.family, expected.family);
        expect(entry.flutterFamily, expected.flutterFamily);
        expect(entry.weight, expected.weight);
        expect(entry.path, expected.path);
        expect(entry.archivePath, expected.archivePath);
        expect(entry.sourceUrl, expected.sourceUrl);
        expect(entry.retrievedAt, expected.retrievedAt);
        expect(entry.license, expected.license);
        expect(entry.axes, hasLength(expected.axisCount));
      } else {
        expect(
          entry.approvedRoleGroups,
          everyElement(
            isIn(const <String>[
              'pricesNumeric',
              'chartNumeric',
              'tradeNumeric',
              'historyNumeric',
            ]),
          ),
        );
      }
    }
  });

  test('the variable baseline is approved only for reviewed role groups', () {
    final entry = ReferenceFontLock.current.bySha(
      'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0',
    );
    expect(
      entry.approvedRoleGroups,
      unorderedEquals(const <String>[
        'tradeMetrics',
        'tradeDense',
        'historySummary',
      ]),
    );
  });

  test(
    'the forensic Avenir hash is absent unless a licensed lock approves it',
    () {
      const forensicSha =
          '94c0952db172bed2d0c030488a9d3f7f4bebb1398baf9e46e6a1acf5173ac192';
      final shipped = ReferenceFontLock.scanProductFonts();
      for (final font in shipped.where((item) => item.sha256 == forensicSha)) {
        final entry = ReferenceFontLock.current.bySha(font.sha256);
        expect(entry.licenseEvidencePath, isNotEmpty);
        expect(File(entry.licenseEvidencePath).existsSync(), isTrue);
        expect(entry.redistributable, isTrue);
      }
    },
  );
}

Map<String, dynamic> _fontLockJson() =>
    jsonDecode(
          File('assets/fonts/mt5-reference/font-lock.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _appendNumericRecord(Map<String, dynamic> lock) {
  final fonts = lock['fonts'] as List<dynamic>;
  final extra = Map<String, dynamic>.from(fonts.first as Map<String, dynamic>);
  extra['file'] = 'Numeric.ttf';
  extra['assetPath'] = 'assets/fonts/mt5-reference/Numeric.ttf';
  extra['sha256'] =
      '0000000000000000000000000000000000000000000000000000000000000000';
  extra['flutterFamily'] = 'Mt5ReferenceNumeric';
  extra['approvedRoleGroups'] = <String>[
    'pricesNumeric',
    'chartNumeric',
    'tradeNumeric',
    'historyNumeric',
  ];
  extra['sourceArtifact'] = <String, dynamic>{
    'kind': 'directFontFile',
    'url': extra['sourceUrl'],
    'sha256': extra['sha256'],
    'archivePath': extra['file'],
    'retrievedAt': extra['retrievedAt'],
  };
  fonts.add(extra);
  return extra;
}

File _temporaryLock(String label, Map<String, dynamic> lock) => File(
  '${Directory.systemTemp.createTempSync('font-lock-$label.').path}/lock.json',
)..writeAsStringSync(jsonEncode(lock));
