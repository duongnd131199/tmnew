import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'test_support/sfnt_metadata_reader.dart';

void main() {
  Uint8List staticFont() => Uint8List.fromList(
    File('assets/fonts/mt5-reference/Roboto-Regular.ttf').readAsBytesSync(),
  );

  test('rejects unrecognized SFNT scaler types', () {
    final bytes = staticFont();
    ByteData.sublistView(bytes).setUint32(0, 0x12345678, Endian.big);
    expect(
      () => SfntMetadataReader.read(bytes),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('scaler'),
        ),
      ),
    );
  });

  test('counts only Unicode and Windows Unicode cmap records', () {
    final bytes = staticFont();
    final data = ByteData.sublistView(bytes);
    final cmap = _table(bytes, 'cmap');
    final count = data.getUint16(cmap.offset + 2, Endian.big);
    for (var index = 0; index < count; index++) {
      data.setUint16(cmap.offset + 4 + index * 8, 1, Endian.big);
    }
    expect(
      () => SfntMetadataReader.read(bytes),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unicode cmap'),
        ),
      ),
    );
  });

  test('rejects truncated and nonzero-version cmap tables', () {
    final truncated = staticFont();
    final truncatedTable = _table(truncated, 'cmap');
    ByteData.sublistView(
      truncated,
    ).setUint32(truncatedTable.recordOffset + 12, 3, Endian.big);
    expect(
      () => SfntMetadataReader.read(truncated),
      throwsA(isA<FormatException>()),
    );

    final versioned = staticFont();
    final cmap = _table(versioned, 'cmap');
    ByteData.sublistView(versioned).setUint16(cmap.offset, 1, Endian.big);
    expect(
      () => SfntMetadataReader.read(versioned),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('cmap version'),
        ),
      ),
    );
  });

  test('skips unsupported name candidates when Unicode names are valid', () {
    final bytes = staticFont();
    final data = ByteData.sublistView(bytes);
    final name = _table(bytes, 'name');
    final record = _nameRecord(
      bytes,
      name,
      (platform, encoding, language, nameId) => platform == 1 && nameId == 1,
    );
    data.setUint16(record, 2, Endian.big);
    expect(SfntMetadataReader.read(bytes).family, 'Roboto');
  });

  test(
    'decodes Mac Roman names after supported Unicode candidates are absent',
    () {
      final bytes = staticFont();
      final data = ByteData.sublistView(bytes);
      final name = _table(bytes, 'name');
      final count = data.getUint16(name.offset + 2, Endian.big);
      final storage = data.getUint16(name.offset + 4, Endian.big);
      var patchedMac = false;
      for (var index = 0; index < count; index++) {
        final record = name.offset + 6 + index * 12;
        final platform = data.getUint16(record, Endian.big);
        final nameId = data.getUint16(record + 6, Endian.big);
        if (nameId != 1) continue;
        if (platform == 0 || platform == 3) {
          data.setUint16(record, 2, Endian.big);
        } else if (platform == 1) {
          final stringOffset = data.getUint16(record + 10, Endian.big);
          bytes[name.offset + storage + stringOffset] = 0x80;
          patchedMac = true;
        }
      }
      expect(patchedMac, isTrue);
      expect(SfntMetadataReader.read(bytes).family, startsWith('Ä'));
    },
  );

  test(
    'rejects odd UTF-16 names and resolves duplicate names deterministically',
    () {
      final odd = staticFont();
      final oddData = ByteData.sublistView(odd);
      final oddName = _table(odd, 'name');
      final familyRecord = _nameRecord(
        odd,
        oddName,
        (platform, encoding, language, nameId) =>
            platform == 3 && language == 0x0409 && nameId == 1,
      );
      final length = oddData.getUint16(familyRecord + 8, Endian.big);
      oddData.setUint16(familyRecord + 8, length - 1, Endian.big);
      expect(
        () => SfntMetadataReader.read(odd),
        throwsA(isA<FormatException>()),
      );

      final duplicate = staticFont();
      final duplicateName = _table(duplicate, 'name');
      final duplicateRecord = _nameRecord(
        duplicate,
        duplicateName,
        (platform, encoding, language, nameId) =>
            platform == 3 && language == 0x0409 && nameId == 6,
      );
      ByteData.sublistView(
        duplicate,
      ).setUint16(duplicateRecord + 6, 1, Endian.big);
      expect(SfntMetadataReader.read(duplicate).family, 'Roboto');

      final badNameVersion = staticFont();
      final badName = _table(badNameVersion, 'name');
      ByteData.sublistView(
        badNameVersion,
      ).setUint16(badName.offset, 2, Endian.big);
      expect(
        () => SfntMetadataReader.read(badNameVersion),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('rejects truncated format 4 fixed arrays with FormatException', () {
    final source = staticFont();
    final sourceCmap = _table(source, 'cmap');
    final bytes = Uint8List(source.length + sourceCmap.length)
      ..setRange(0, source.length, source)
      ..setRange(
        source.length,
        source.length + sourceCmap.length,
        source,
        sourceCmap.offset,
      );
    final data = ByteData.sublistView(bytes);
    data.setUint32(sourceCmap.recordOffset + 8, source.length, Endian.big);
    final relocatedCmap = _table(bytes, 'cmap');
    final format4 = _cmapSubtable(
      bytes,
      relocatedCmap,
      (platform, encoding, format) => format == 4 && platform == 0,
    );
    data
      ..setUint16(format4 + 2, 14, Endian.big)
      ..setUint16(format4 + 6, 0xfffe, Endian.big);

    expect(
      () => SfntMetadataReader.read(bytes),
      throwsA(isA<FormatException>()),
    );
  });

  test('validates format 12 reserved fields and fvar version and bounds', () {
    final format12Bytes = Uint8List.fromList(
      File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync(),
    );
    final format12Data = ByteData.sublistView(format12Bytes);
    final cmap = _table(format12Bytes, 'cmap');
    final format12 = _cmapSubtable(
      format12Bytes,
      cmap,
      (platform, encoding, format) =>
          format == 12 && (platform == 0 || (platform == 3 && encoding == 10)),
    );
    format12Data.setUint16(format12 + 2, 1, Endian.big);
    expect(
      () => SfntMetadataReader.read(format12Bytes),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('format 12 reserved'),
        ),
      ),
    );

    final badVersion = Uint8List.fromList(
      File('assets/fonts/Roboto-Variable.ttf').readAsBytesSync(),
    );
    final fvarVersion = _table(badVersion, 'fvar');
    ByteData.sublistView(
      badVersion,
    ).setUint16(fvarVersion.offset, 2, Endian.big);
    expect(
      () => SfntMetadataReader.read(badVersion),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('fvar version'),
        ),
      ),
    );

    final badBounds = Uint8List.fromList(
      File('assets/fonts/Roboto-Variable.ttf').readAsBytesSync(),
    );
    final fvarBounds = _table(badBounds, 'fvar');
    ByteData.sublistView(
      badBounds,
    ).setUint16(fvarBounds.offset + 4, 0xffff, Endian.big);
    expect(
      () => SfntMetadataReader.read(badBounds),
      throwsA(isA<FormatException>()),
    );

    final badReserved = Uint8List.fromList(
      File('assets/fonts/Roboto-Variable.ttf').readAsBytesSync(),
    );
    final fvarReserved = _table(badReserved, 'fvar');
    ByteData.sublistView(
      badReserved,
    ).setUint16(fvarReserved.offset + 6, 0, Endian.big);
    expect(
      () => SfntMetadataReader.read(badReserved),
      throwsA(isA<FormatException>()),
    );

    final badFormat4Reserved = staticFont();
    final format4Data = ByteData.sublistView(badFormat4Reserved);
    final format4Cmap = _table(badFormat4Reserved, 'cmap');
    final format4 = _cmapSubtable(
      badFormat4Reserved,
      format4Cmap,
      (platform, encoding, format) => format == 4 && platform == 0,
    );
    final segmentCount = format4Data.getUint16(format4 + 6, Endian.big) ~/ 2;
    format4Data.setUint16(format4 + 14 + segmentCount * 2, 1, Endian.big);
    expect(
      () => SfntMetadataReader.read(badFormat4Reserved),
      throwsA(isA<FormatException>()),
    );
  });
}

typedef _NamePredicate =
    bool Function(int platform, int encoding, int language, int nameId);

typedef _CmapPredicate = bool Function(int platform, int encoding, int format);

int _nameRecord(Uint8List bytes, _Table table, _NamePredicate predicate) {
  final data = ByteData.sublistView(bytes);
  final count = data.getUint16(table.offset + 2, Endian.big);
  for (var index = 0; index < count; index++) {
    final record = table.offset + 6 + index * 12;
    if (predicate(
      data.getUint16(record, Endian.big),
      data.getUint16(record + 2, Endian.big),
      data.getUint16(record + 4, Endian.big),
      data.getUint16(record + 6, Endian.big),
    )) {
      return record;
    }
  }
  throw StateError('Required synthetic name fixture record was not found');
}

int _cmapSubtable(Uint8List bytes, _Table table, _CmapPredicate predicate) {
  final data = ByteData.sublistView(bytes);
  final count = data.getUint16(table.offset + 2, Endian.big);
  for (var index = 0; index < count; index++) {
    final record = table.offset + 4 + index * 8;
    final offset = data.getUint32(record + 4, Endian.big);
    final absolute = table.offset + offset;
    if (predicate(
      data.getUint16(record, Endian.big),
      data.getUint16(record + 2, Endian.big),
      data.getUint16(absolute, Endian.big),
    )) {
      return absolute;
    }
  }
  throw StateError('Required synthetic cmap fixture record was not found');
}

_Table _table(Uint8List bytes, String tag) {
  final data = ByteData.sublistView(bytes);
  final count = data.getUint16(4, Endian.big);
  for (var index = 0; index < count; index++) {
    final record = 12 + index * 16;
    if (ascii.decode(bytes.sublist(record, record + 4)) == tag) {
      return _Table(
        recordOffset: record,
        offset: data.getUint32(record + 8, Endian.big),
        length: data.getUint32(record + 12, Endian.big),
      );
    }
  }
  throw StateError('Required synthetic fixture table $tag was not found');
}

class _Table {
  const _Table({
    required this.recordOffset,
    required this.offset,
    required this.length,
  });

  final int recordOffset;
  final int offset;
  final int length;
}
