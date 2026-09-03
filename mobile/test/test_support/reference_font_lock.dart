import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import 'reference_typography_sources.dart';
import 'sfnt_metadata_reader.dart';

class ReferenceFontLock {
  const ReferenceFontLock({
    required this.schemaVersion,
    required this.sourcePackage,
    required this.fonts,
  });

  static const lockPath = 'assets/fonts/mt5-reference/font-lock.json';
  static const requiredBaseShas = <String>{
    'f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27',
    '9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70',
    'f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8',
    'ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a',
    'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0',
  };

  final int schemaVersion;
  final ReferenceFontSourcePackage sourcePackage;
  final List<ReferenceFontEntry> fonts;

  static ReferenceFontLock get current => read(File(lockPath));

  static ReferenceFontLock read(File file) {
    final decoded = jsonDecode(file.readAsStringSync());
    final json = _object(decoded, 'font lock');
    _keys(json, const {'schemaVersion', 'sourcePackage', 'fonts'}, 'font lock');
    final schemaVersion = _integer(json['schemaVersion'], 'schemaVersion');
    if (schemaVersion != 3) {
      throw FormatException('Unsupported font-lock schema: $schemaVersion');
    }
    final sourcePackage = ReferenceFontSourcePackage.fromJson(
      _object(json['sourcePackage'], 'sourcePackage'),
    );
    final rawFonts = _list(json['fonts'], 'fonts');
    if (rawFonts.length != 5 && rawFonts.length != 6) {
      throw const FormatException(
        'Font lock must contain exactly five or six records',
      );
    }
    final fonts = List<ReferenceFontEntry>.unmodifiable(
      rawFonts.map(
        (item) => ReferenceFontEntry.fromJson(_object(item, 'font entry')),
      ),
    );
    if (fonts.isEmpty) throw const FormatException('Font lock is empty');
    if (fonts.map((item) => item.file).toSet().length != fonts.length) {
      throw const FormatException('Font lock contains duplicate files');
    }
    if (fonts.map((item) => item.sha256).toSet().length != fonts.length) {
      throw const FormatException('Font lock contains duplicate hashes');
    }
    if (fonts.map((item) => item.assetPath).toSet().length != fonts.length) {
      throw const FormatException('Font lock contains duplicate asset paths');
    }
    final lock = ReferenceFontLock(
      schemaVersion: schemaVersion,
      sourcePackage: sourcePackage,
      fonts: fonts,
    );
    lock._verifyPolicy();
    lock._verifyEvidence();
    lock._verifyDirectoryInventory();
    return lock;
  }

  ReferenceFontEntry bySha(String sha) => fonts.singleWhere(
    (entry) => entry.sha256 == sha,
    orElse: () => throw StateError('Font SHA is not locked: $sha'),
  );

  static List<ScannedProductFont> scanProductFonts() {
    final root = Directory('assets/fonts');
    if (!root.existsSync()) return const <ScannedProductFont>[];
    final fonts = <ScannedProductFont>[
      for (final entity in root.listSync(recursive: true, followLinks: false))
        if (entity is File && entity.path.toLowerCase().endsWith('.ttf'))
          ScannedProductFont(
            path: entity.path,
            sha256: crypto.sha256.convert(entity.readAsBytesSync()).toString(),
          ),
    ]..sort((left, right) => left.path.compareTo(right.path));
    return List<ScannedProductFont>.unmodifiable(fonts);
  }

  void _verifyDirectoryInventory() {
    final directory = Directory('assets/fonts/mt5-reference');
    final shipped = <String>{
      for (final entity in directory.listSync(followLinks: false))
        if (entity is File && entity.path.toLowerCase().endsWith('.ttf'))
          entity.uri.pathSegments.last,
    };
    final locked = fonts
        .where(
          (entry) => entry.assetPath.startsWith('assets/fonts/mt5-reference/'),
        )
        .map((entry) => entry.file)
        .toSet();
    if (shipped.length != locked.length || !shipped.containsAll(locked)) {
      throw FormatException(
        'Reference font directory differs from lock: '
        'shipped=$shipped locked=$locked',
      );
    }
  }

  void _verifyPolicy() {
    _policySame('package', 'net.metaquotes.metatrader5', sourcePackage.package);
    _policySame('versionName', '500.6140', sourcePackage.versionName);
    _policySame('versionCode', 6140, sourcePackage.versionCode);
    _policySame(
      'downloadUrl',
      'https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk',
      sourcePackage.downloadUrl,
    );
    _policySame('retrievedAt', '2026-08-31', sourcePackage.retrievedAt);
    _policySame(
      'APK SHA-256',
      'c76582495cdd55061a38942bae9a4d2d33ed140840af94dec82cc6ad7001782b',
      sourcePackage.apkSha256,
    );
    _policySame(
      'license SHA-256',
      'c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4',
      sourcePackage.licenseTextSha256,
    );

    _verifyBase(
      _requiredBaseBySha(
        'f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27',
      ),
      file: 'Roboto-Regular.ttf',
      family: 'Roboto',
      subfamily: 'Regular',
      fullName: 'Roboto Regular',
      nameVersion: 'Version 1.200310; 2013',
      os2WeightClass: 400,
      byteLength: 114976,
      flutterFamily: 'Mt5ReferenceRoboto',
      weight: 400,
      approvedRoleGroups: const {
        'navigation',
        'settings',
        'toolbar',
        'tradeMetrics',
        'historySummary',
        'chartCanvas',
      },
    );
    _verifyBase(
      _requiredBaseBySha(
        '9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70',
      ),
      file: 'Roboto-Bold.ttf',
      family: 'Roboto',
      subfamily: 'Bold',
      fullName: 'Roboto Bold',
      nameVersion: 'Version 1.100141; 2013',
      os2WeightClass: 700,
      byteLength: 135820,
      flutterFamily: 'Mt5ReferenceRoboto',
      weight: 700,
      approvedRoleGroups: const {
        'navigation',
        'settings',
        'toolbar',
        'tradeMetrics',
        'historySummary',
        'chartCanvas',
      },
    );
    _verifyBase(
      _requiredBaseBySha(
        'f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8',
      ),
      file: 'RobotoCondensed-Regular.ttf',
      family: 'Roboto Condensed',
      subfamily: 'Regular',
      fullName: 'Roboto Condensed Regular',
      nameVersion: 'Version 1.200311; 2013',
      os2WeightClass: 400,
      byteLength: 114575,
      flutterFamily: 'Mt5ReferenceRobotoCondensed',
      weight: 400,
      approvedRoleGroups: const {
        'pricesDense',
        'chartTicket',
        'tradeDense',
        'historyDense',
      },
    );
    _verifyBase(
      _requiredBaseBySha(
        'ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a',
      ),
      file: 'RobotoCondensed-Bold.ttf',
      family: 'Roboto Condensed',
      subfamily: 'Bold',
      fullName: 'Roboto Condensed Bold',
      nameVersion: 'Version 1.200311; 2013',
      os2WeightClass: 700,
      byteLength: 115036,
      flutterFamily: 'Mt5ReferenceRobotoCondensed',
      weight: 700,
      approvedRoleGroups: const {
        'pricesDense',
        'chartTicket',
        'tradeDense',
        'historyDense',
      },
    );
    _verifyVariableBase(
      _requiredBaseBySha(
        'dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0',
      ),
    );

    final extras = fonts
        .where((entry) => !requiredBaseShas.contains(entry.sha256))
        .toList(growable: false);
    if (extras.length != fonts.length - 5) {
      throw const FormatException('Five literal baseline records are required');
    }
    if (extras.isNotEmpty) _verifyOptionalNumeric(extras.single);
  }

  void _verifyBase(
    ReferenceFontEntry entry, {
    required String file,
    required String family,
    required String subfamily,
    required String fullName,
    required String nameVersion,
    required int os2WeightClass,
    required int byteLength,
    required String flutterFamily,
    required int weight,
    required Set<String> approvedRoleGroups,
  }) {
    _policySame('$file file', file, entry.file);
    _policySame('$file family', family, entry.family);
    _policySame('$file subfamily', subfamily, entry.subfamily);
    _policySame('$file fullName', fullName, entry.fullName);
    _policySame('$file nameVersion', nameVersion, entry.nameVersion);
    _policySame('$file headRevision', 1.0, entry.headRevision);
    _policySame('$file unitsPerEm', 2048, entry.unitsPerEm);
    _policySame('$file os2WeightClass', os2WeightClass, entry.os2WeightClass);
    _policySame('$file byteLength', byteLength, entry.byteLength);
    _policySame(
      '$file assetPath',
      'assets/fonts/mt5-reference/$file',
      entry.assetPath,
    );
    _policySame('$file archivePath', 'assets/fonts/$file', entry.archivePath);
    _policySame('$file sourceUrl', sourcePackage.downloadUrl, entry.sourceUrl);
    _policySame('$file retrievedAt', '2026-08-31', entry.retrievedAt);
    _policySame('$file flutterFamily', flutterFamily, entry.flutterFamily);
    _policySame('$file weight', weight, entry.weight);
    _policySame('$file license', 'Apache-2.0', entry.license);
    _policySame(
      '$file licenseEvidencePath',
      'assets/fonts/mt5-reference/LICENSE-Apache-2.0.txt',
      entry.licenseEvidencePath,
    );
    _policySame(
      '$file licenseEvidenceSha256',
      sourcePackage.licenseTextSha256,
      entry.licenseEvidenceSha256,
    );
    _policySame('$file redistributable', true, entry.redistributable);
    _policySame(
      '$file approvedRoleGroups count',
      approvedRoleGroups.length,
      entry.approvedRoleGroups.length,
    );
    _policySet(
      '$file approvedRoleGroups',
      approvedRoleGroups,
      entry.approvedRoleGroups.toSet(),
    );
    _policySame('$file axes', 0, entry.axes.length);
    _policySame('$file source kind', 'apkEntry', entry.sourceArtifact.kind);
    _policySame(
      '$file source URL',
      sourcePackage.downloadUrl,
      entry.sourceArtifact.url,
    );
    _policySame(
      '$file source SHA',
      sourcePackage.apkSha256,
      entry.sourceArtifact.sha256,
    );
    _policySame(
      '$file source archivePath',
      entry.archivePath,
      entry.sourceArtifact.archivePath,
    );
    _policySame(
      '$file source retrievedAt',
      entry.retrievedAt,
      entry.sourceArtifact.retrievedAt,
    );
  }

  void _verifyVariableBase(ReferenceFontEntry entry) {
    const file = 'RobotoCondensed-Variable.ttf';
    _policySame('$file file', file, entry.file);
    _policySame('$file family', 'Roboto Condensed', entry.family);
    _policySame('$file subfamily', 'Regular', entry.subfamily);
    _policySame('$file fullName', 'Roboto Condensed Regular', entry.fullName);
    _policySame('$file nameVersion', 'Version 3.008; 2023', entry.nameVersion);
    _policySame('$file headRevision', 3.00799560546875, entry.headRevision);
    _policySame('$file unitsPerEm', 2048, entry.unitsPerEm);
    _policySame('$file os2WeightClass', 400, entry.os2WeightClass);
    _policySame('$file byteLength', 371616, entry.byteLength);
    _policySame(
      '$file assetPath',
      'assets/fonts/RobotoCondensed-Variable.ttf',
      entry.assetPath,
    );
    _policySame('$file archivePath', file, entry.archivePath);
    _policySame(
      '$file sourceUrl',
      'https://raw.githubusercontent.com/google/fonts/main/ofl/robotocondensed/RobotoCondensed%5Bwght%5D.ttf',
      entry.sourceUrl,
    );
    _policySame('$file retrievedAt', '2026-08-26', entry.retrievedAt);
    _policySame(
      '$file flutterFamily',
      'Mt5ReferenceRobotoCondensedVariable',
      entry.flutterFamily,
    );
    _policySame('$file weight', 400, entry.weight);
    _policySame('$file license', 'Apache-2.0', entry.license);
    _policySame(
      '$file licenseEvidencePath',
      'assets/fonts/LICENSE-RobotoCondensed-Apache-2.0.txt',
      entry.licenseEvidencePath,
    );
    _policySame(
      '$file licenseEvidenceSha256',
      'c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4',
      entry.licenseEvidenceSha256,
    );
    _policySame('$file redistributable', true, entry.redistributable);
    _policySet('$file approvedRoleGroups', const {
      'tradeMetrics',
      'tradeDense',
      'historySummary',
    }, entry.approvedRoleGroups.toSet());
    _policySame(
      '$file approvedRoleGroups count',
      3,
      entry.approvedRoleGroups.length,
    );
    _policySame('$file axes count', 1, entry.axes.length);
    final axis = entry.axes.single;
    _policySame('$file axis tag', 'wght', axis.tag);
    _policySame('$file axis minimum', 100.0, axis.minimum);
    _policySame('$file axis default', 400.0, axis.defaultValue);
    _policySame('$file axis maximum', 900.0, axis.maximum);
    _policySame(
      '$file source kind',
      'directFontFile',
      entry.sourceArtifact.kind,
    );
    _policySame('$file source URL', entry.sourceUrl, entry.sourceArtifact.url);
    _policySame('$file source SHA', entry.sha256, entry.sourceArtifact.sha256);
    _policySame(
      '$file source archivePath',
      entry.file,
      entry.sourceArtifact.archivePath,
    );
    _policySame(
      '$file source retrievedAt',
      entry.retrievedAt,
      entry.sourceArtifact.retrievedAt,
    );
  }

  void _verifyOptionalNumeric(ReferenceFontEntry entry) {
    _policySame(
      'Mt5ReferenceNumeric assetPath',
      'assets/fonts/mt5-reference/${entry.file}',
      entry.assetPath,
    );
    _policySame(
      'Optional sixth flutterFamily must be Mt5ReferenceNumeric',
      'Mt5ReferenceNumeric',
      entry.flutterFamily,
    );
    _policySet('Mt5ReferenceNumeric approvedRoleGroups', const {
      'pricesNumeric',
      'chartNumeric',
      'tradeNumeric',
      'historyNumeric',
    }, entry.approvedRoleGroups.toSet());
    _policySame(
      'Mt5ReferenceNumeric approvedRoleGroups count',
      4,
      entry.approvedRoleGroups.length,
    );
    _policySame(
      'Mt5ReferenceNumeric redistributable',
      true,
      entry.redistributable,
    );
    _policySame(
      'Mt5ReferenceNumeric source kind',
      'directFontFile',
      entry.sourceArtifact.kind,
    );
    _policySame(
      'Mt5ReferenceNumeric source SHA',
      entry.sha256,
      entry.sourceArtifact.sha256,
    );
    _policySame(
      'Mt5ReferenceNumeric source URL',
      entry.sourceUrl,
      entry.sourceArtifact.url,
    );
    _policySame(
      'Mt5ReferenceNumeric source archivePath',
      entry.file,
      entry.sourceArtifact.archivePath,
    );
    _policySame(
      'Mt5ReferenceNumeric source retrievedAt',
      entry.retrievedAt,
      entry.sourceArtifact.retrievedAt,
    );
  }

  void _verifyEvidence() {
    for (final entry in fonts) {
      final license = File(entry.licenseEvidencePath);
      if (!license.existsSync()) {
        throw FormatException('Missing license evidence: ${license.path}');
      }
      final actualLicenseSha = crypto.sha256
          .convert(license.readAsBytesSync())
          .toString();
      if (actualLicenseSha != entry.licenseEvidenceSha256) {
        throw FormatException(
          '${entry.file} license evidence SHA mismatch: expected '
          '${entry.licenseEvidenceSha256}, got $actualLicenseSha',
        );
      }
      if (entry.sourceArtifact.kind == 'directFontFile') {
        if (!File(entry.path).existsSync()) {
          throw FormatException(
            '${entry.file} source artifact is not present at ${entry.path}',
          );
        }
        final actualSourceSha = crypto.sha256
            .convert(File(entry.path).readAsBytesSync())
            .toString();
        if (actualSourceSha != entry.sourceArtifact.sha256) {
          throw FormatException(
            '${entry.file} source artifact SHA mismatch: expected '
            '${entry.sourceArtifact.sha256}, got $actualSourceSha',
          );
        }
      }
    }
  }

  ReferenceFontEntry _requiredBaseBySha(String sha) {
    final matching = fonts.where((entry) => entry.sha256 == sha).toList();
    if (matching.length != 1) {
      throw FormatException('Required baseline font SHA is missing: $sha');
    }
    return matching.single;
  }

  void _policySame(String field, Object expected, Object actual) {
    if (expected != actual) {
      throw FormatException('$field mismatch: expected $expected, got $actual');
    }
  }

  void _policySet(String field, Set<String> expected, Set<String> actual) {
    if (expected.length != actual.length || !actual.containsAll(expected)) {
      throw FormatException('$field mismatch: expected $expected, got $actual');
    }
  }
}

class ReferenceFontSourcePackage {
  const ReferenceFontSourcePackage({
    required this.package,
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    required this.retrievedAt,
    required this.apkSha256,
    required this.licenseTextSha256,
  });

  final String package;
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String retrievedAt;
  final String apkSha256;
  final String licenseTextSha256;

  factory ReferenceFontSourcePackage.fromJson(Map<String, Object?> json) {
    _keys(json, const {
      'package',
      'versionName',
      'versionCode',
      'downloadUrl',
      'retrievedAt',
      'apkSha256',
      'licenseTextSha256',
    }, 'sourcePackage');
    return ReferenceFontSourcePackage(
      package: _string(json['package'], 'sourcePackage.package'),
      versionName: _string(json['versionName'], 'sourcePackage.versionName'),
      versionCode: _integer(json['versionCode'], 'sourcePackage.versionCode'),
      downloadUrl: _string(json['downloadUrl'], 'sourcePackage.downloadUrl'),
      retrievedAt: _string(json['retrievedAt'], 'sourcePackage.retrievedAt'),
      apkSha256: _sha(json['apkSha256'], 'sourcePackage.apkSha256'),
      licenseTextSha256: _sha(
        json['licenseTextSha256'],
        'sourcePackage.licenseTextSha256',
      ),
    );
  }
}

class ReferenceFontEntry {
  const ReferenceFontEntry({
    required this.file,
    required this.assetPath,
    required this.family,
    required this.subfamily,
    required this.fullName,
    required this.nameVersion,
    required this.headRevision,
    required this.unitsPerEm,
    required this.os2WeightClass,
    required this.byteLength,
    required this.archivePath,
    required this.sourceUrl,
    required this.retrievedAt,
    required this.flutterFamily,
    required this.weight,
    required this.sha256,
    required this.license,
    required this.licenseEvidencePath,
    required this.licenseEvidenceSha256,
    required this.sourceArtifact,
    required this.redistributable,
    required this.approvedRoleGroups,
    required this.axes,
  });

  final String file;
  final String assetPath;
  final String family;
  final String subfamily;
  final String fullName;
  final String nameVersion;
  final double headRevision;
  final int unitsPerEm;
  final int os2WeightClass;
  final int byteLength;
  final String archivePath;
  final String sourceUrl;
  final String retrievedAt;
  final String flutterFamily;
  final int weight;
  final String sha256;
  final String license;
  final String licenseEvidencePath;
  final String licenseEvidenceSha256;
  final ReferenceFontSourceArtifact sourceArtifact;
  final bool redistributable;
  final List<String> approvedRoleGroups;
  final List<ReferenceFontAxis> axes;

  String get path => assetPath;

  factory ReferenceFontEntry.fromJson(Map<String, Object?> json) {
    _keys(json, const {
      'file',
      'assetPath',
      'family',
      'subfamily',
      'fullName',
      'nameVersion',
      'headRevision',
      'unitsPerEm',
      'os2WeightClass',
      'byteLength',
      'archivePath',
      'sourceUrl',
      'retrievedAt',
      'flutterFamily',
      'weight',
      'sha256',
      'license',
      'licenseEvidencePath',
      'licenseEvidenceSha256',
      'sourceArtifact',
      'redistributable',
      'approvedRoleGroups',
      'axes',
    }, 'font entry');
    return ReferenceFontEntry(
      file: _string(json['file'], 'font.file'),
      assetPath: _string(json['assetPath'], 'font.assetPath'),
      family: _string(json['family'], 'font.family'),
      subfamily: _string(json['subfamily'], 'font.subfamily'),
      fullName: _string(json['fullName'], 'font.fullName'),
      nameVersion: _string(json['nameVersion'], 'font.nameVersion'),
      headRevision: _number(json['headRevision'], 'font.headRevision'),
      unitsPerEm: _integer(json['unitsPerEm'], 'font.unitsPerEm'),
      os2WeightClass: _integer(json['os2WeightClass'], 'font.os2WeightClass'),
      byteLength: _integer(json['byteLength'], 'font.byteLength'),
      archivePath: _string(json['archivePath'], 'font.archivePath'),
      sourceUrl: _string(json['sourceUrl'], 'font.sourceUrl'),
      retrievedAt: _string(json['retrievedAt'], 'font.retrievedAt'),
      flutterFamily: _string(json['flutterFamily'], 'font.flutterFamily'),
      weight: _integer(json['weight'], 'font.weight'),
      sha256: _sha(json['sha256'], 'font.sha256'),
      license: _string(json['license'], 'font.license'),
      licenseEvidencePath: _string(
        json['licenseEvidencePath'],
        'font.licenseEvidencePath',
      ),
      licenseEvidenceSha256: _sha(
        json['licenseEvidenceSha256'],
        'font.licenseEvidenceSha256',
      ),
      sourceArtifact: ReferenceFontSourceArtifact.fromJson(
        _object(json['sourceArtifact'], 'font.sourceArtifact'),
      ),
      redistributable: _boolean(
        json['redistributable'],
        'font.redistributable',
      ),
      approvedRoleGroups: List<String>.unmodifiable(
        _list(
          json['approvedRoleGroups'],
          'font.approvedRoleGroups',
        ).map((item) => _string(item, 'font.approvedRoleGroups item')),
      ),
      axes: List<ReferenceFontAxis>.unmodifiable(
        _list(
          json['axes'],
          'font.axes',
        ).map((item) => ReferenceFontAxis.fromJson(_object(item, 'font axis'))),
      ),
    );
  }

  void verifyBytesAndSfntMetadata() {
    final font = File(path);
    if (!font.existsSync()) throw StateError('Missing locked font: $path');
    final bytes = font.readAsBytesSync();
    _same('byte length', byteLength, bytes.length);
    _same('SHA-256', sha256, cryptoSha256(bytes));
    final metadata = SfntMetadataReader.read(bytes);
    _same('family', family, metadata.family);
    _same('subfamily', subfamily, metadata.subfamily);
    _same('full name', fullName, metadata.fullName);
    _same('name version', nameVersion, metadata.nameVersion);
    _same('head revision', headRevision, metadata.headRevision);
    _same('units per em', unitsPerEm, metadata.unitsPerEm);
    _same('OS/2 weight', os2WeightClass, metadata.os2WeightClass);
    _same('axis count', axes.length, metadata.axes.length);
    for (var index = 0; index < axes.length; index++) {
      axes[index].verify(metadata.axes[index], file);
    }
    const numericRoleGroups = <String>{
      'pricesNumeric',
      'chartNumeric',
      'tradeNumeric',
      'historyNumeric',
    };
    final requiredCodePoints =
        approvedRoleGroups.isNotEmpty &&
            approvedRoleGroups.every(numericRoleGroups.contains)
        ? referenceTypographyNumericCodePoints
        : referenceTypographyCodePoints;
    final missing = requiredCodePoints
        .where((codePoint) => !metadata.supportsCodePoint(codePoint))
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw StateError(
        '$file lacks required cmap code points: '
        '${missing.map((item) => 'U+${item.toRadixString(16).toUpperCase()}').join(', ')}',
      );
    }
  }

  String cryptoSha256(List<int> bytes) =>
      crypto.sha256.convert(bytes).toString();

  void _same(String field, Object expected, Object actual) {
    if (actual != expected) {
      throw StateError(
        '$file $field mismatch: expected $expected, got $actual',
      );
    }
  }
}

class ReferenceFontSourceArtifact {
  const ReferenceFontSourceArtifact({
    required this.kind,
    required this.url,
    required this.sha256,
    required this.archivePath,
    required this.retrievedAt,
  });

  final String kind;
  final String url;
  final String sha256;
  final String archivePath;
  final String retrievedAt;

  factory ReferenceFontSourceArtifact.fromJson(Map<String, Object?> json) {
    _keys(json, const {
      'kind',
      'url',
      'sha256',
      'archivePath',
      'retrievedAt',
    }, 'font sourceArtifact');
    return ReferenceFontSourceArtifact(
      kind: _string(json['kind'], 'font.sourceArtifact.kind'),
      url: _string(json['url'], 'font.sourceArtifact.url'),
      sha256: _sha(json['sha256'], 'font.sourceArtifact.sha256'),
      archivePath: _string(
        json['archivePath'],
        'font.sourceArtifact.archivePath',
      ),
      retrievedAt: _string(
        json['retrievedAt'],
        'font.sourceArtifact.retrievedAt',
      ),
    );
  }
}

class ReferenceFontAxis {
  const ReferenceFontAxis({
    required this.tag,
    required this.minimum,
    required this.defaultValue,
    required this.maximum,
  });

  final String tag;
  final double minimum;
  final double defaultValue;
  final double maximum;

  factory ReferenceFontAxis.fromJson(Map<String, Object?> json) {
    _keys(json, const {'tag', 'minimum', 'default', 'maximum'}, 'font axis');
    return ReferenceFontAxis(
      tag: _string(json['tag'], 'axis.tag'),
      minimum: _number(json['minimum'], 'axis.minimum'),
      defaultValue: _number(json['default'], 'axis.default'),
      maximum: _number(json['maximum'], 'axis.maximum'),
    );
  }

  void verify(SfntAxis actual, String file) {
    if (tag != actual.tag ||
        minimum != actual.minimum ||
        defaultValue != actual.defaultValue ||
        maximum != actual.maximum) {
      throw StateError('$file fvar axis $tag differs from its lock');
    }
  }
}

class ScannedProductFont {
  const ScannedProductFont({required this.path, required this.sha256});

  final String path;
  final String sha256;
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$field must be an object');
  }
  return value;
}

List<Object?> _list(Object? value, String field) {
  if (value is! List<Object?>) throw FormatException('$field must be a list');
  return value;
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value;
}

String _sha(Object? value, String field) {
  final result = _string(value, field);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(result)) {
    throw FormatException('$field must be a lowercase SHA-256');
  }
  return result;
}

int _integer(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer');
  return value;
}

double _number(Object? value, String field) {
  if (value is! num) throw FormatException('$field must be a number');
  return value.toDouble();
}

bool _boolean(Object? value, String field) {
  if (value is! bool) throw FormatException('$field must be a boolean');
  return value;
}

void _keys(Map<String, Object?> json, Set<String> expected, String field) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw FormatException(
      '$field keys differ: expected $expected, got $actual',
    );
  }
}
