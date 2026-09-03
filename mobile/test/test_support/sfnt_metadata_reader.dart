import 'dart:convert';
import 'dart:typed_data';

class SfntAxis {
  const SfntAxis({
    required this.tag,
    required this.minimum,
    required this.defaultValue,
    required this.maximum,
  });

  final String tag;
  final double minimum;
  final double defaultValue;
  final double maximum;
}

class SfntMetadata {
  const SfntMetadata({
    required this.family,
    required this.subfamily,
    required this.fullName,
    required this.nameVersion,
    required this.headRevision,
    required this.unitsPerEm,
    required this.os2WeightClass,
    required this.axes,
    required this.supportedCodePoints,
  });

  final String family;
  final String subfamily;
  final String fullName;
  final String nameVersion;
  final double headRevision;
  final int unitsPerEm;
  final int os2WeightClass;
  final List<SfntAxis> axes;
  final Set<int> supportedCodePoints;

  bool supportsCodePoint(int codePoint) =>
      supportedCodePoints.contains(codePoint);
}

class SfntMetadataReader {
  const SfntMetadataReader._();

  static SfntMetadata read(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    _requireRange(data, 0, 12, 'SFNT header');
    final scalerType = data.getUint32(0, Endian.big);
    if (!const <int>{
      0x00010000,
      0x4f54544f,
      0x74727565,
      0x74797031,
    }.contains(scalerType)) {
      throw FormatException(
        'Unrecognized SFNT scaler type: 0x${scalerType.toRadixString(16)}',
      );
    }
    final tableCount = data.getUint16(4, Endian.big);
    if (tableCount == 0) throw const FormatException('SFNT has no tables');
    _requireRange(data, 12, tableCount * 16, 'SFNT table directory');

    final tables = <String, _SfntTable>{};
    for (var index = 0; index < tableCount; index++) {
      final recordOffset = 12 + index * 16;
      final tag = ascii.decode(
        bytes.sublist(recordOffset, recordOffset + 4),
        allowInvalid: false,
      );
      final offset = data.getUint32(recordOffset + 8, Endian.big);
      final length = data.getUint32(recordOffset + 12, Endian.big);
      _requireRange(data, offset, length, 'SFNT table $tag');
      if (tables.containsKey(tag)) {
        throw FormatException('Duplicate SFNT table: $tag');
      }
      tables[tag] = _SfntTable(offset, length);
    }

    final head = _requiredTable(tables, 'head');
    _requireTableLength(head, 54, 'head');
    if (data.getUint32(head.offset + 12, Endian.big) != 0x5f0f3cf5) {
      throw const FormatException('Invalid head magic number');
    }
    final names = _readNames(bytes, data, _requiredTable(tables, 'name'));
    final os2 = _requiredTable(tables, 'OS/2');
    _requireTableLength(os2, 6, 'OS/2');

    return SfntMetadata(
      family: _requiredName(names, 1),
      subfamily: _requiredName(names, 2),
      fullName: _requiredName(names, 4),
      nameVersion: _requiredName(names, 5),
      headRevision: data.getInt32(head.offset + 4, Endian.big) / 65536,
      unitsPerEm: data.getUint16(head.offset + 18, Endian.big),
      os2WeightClass: data.getUint16(os2.offset + 4, Endian.big),
      axes: tables.containsKey('fvar')
          ? _readAxes(bytes, data, tables['fvar']!)
          : const <SfntAxis>[],
      supportedCodePoints: _readCmap(data, _requiredTable(tables, 'cmap')),
    );
  }

  static Map<int, String> _readNames(
    Uint8List bytes,
    ByteData data,
    _SfntTable table,
  ) {
    _requireTableLength(table, 6, 'name');
    final format = data.getUint16(table.offset, Endian.big);
    if (format != 0 && format != 1) {
      throw FormatException('Unsupported name table format: $format');
    }
    final count = data.getUint16(table.offset + 2, Endian.big);
    final storageOffset = data.getUint16(table.offset + 4, Endian.big);
    _requireRelativeRange(table, 6, count * 12, 'name records');
    if (storageOffset > table.length) {
      throw const FormatException('name storage starts outside table');
    }
    if (format == 1) {
      final languageCountOffset = 6 + count * 12;
      _requireRelativeRange(
        table,
        languageCountOffset,
        2,
        'name language-tag count',
      );
      final languageCount = data.getUint16(
        table.offset + languageCountOffset,
        Endian.big,
      );
      _requireRelativeRange(
        table,
        languageCountOffset + 2,
        languageCount * 4,
        'name language-tag records',
      );
    }

    final candidates = <int, List<_NameCandidate>>{};
    for (var index = 0; index < count; index++) {
      final record = table.offset + 6 + index * 12;
      final platform = data.getUint16(record, Endian.big);
      final encoding = data.getUint16(record + 2, Endian.big);
      final language = data.getUint16(record + 4, Endian.big);
      final nameId = data.getUint16(record + 6, Endian.big);
      if (!const <int>{1, 2, 4, 5}.contains(nameId)) {
        continue;
      }
      if (!_isSupportedNameEncoding(platform, encoding)) continue;
      final length = data.getUint16(record + 8, Endian.big);
      final offset = data.getUint16(record + 10, Endian.big);
      final relative = storageOffset + offset;
      _requireRelativeRange(table, relative, length, 'name string $nameId');
      final raw = bytes.sublist(
        table.offset + relative,
        table.offset + relative + length,
      );
      final value = _decodeName(raw, platform);
      candidates
          .putIfAbsent(nameId, () => <_NameCandidate>[])
          .add(
            _NameCandidate(
              value: value,
              priority: _namePriority(platform, encoding, language),
              order: index,
            ),
          );
    }

    return <int, String>{
      for (final entry in candidates.entries)
        entry.key: (entry.value..sort(_NameCandidate.compare)).first.value
            .trim(),
    };
  }

  static bool _isSupportedNameEncoding(int platform, int encoding) =>
      platform == 0 ||
      (platform == 3 && (encoding == 1 || encoding == 10)) ||
      (platform == 1 && encoding == 0);

  static String _decodeName(List<int> raw, int platform) {
    if (platform == 0 || platform == 3) {
      if (raw.length.isOdd) {
        throw const FormatException('Odd byte count in UTF-16BE name');
      }
      final units = <int>[];
      for (var offset = 0; offset < raw.length; offset += 2) {
        units.add((raw[offset] << 8) | raw[offset + 1]);
      }
      return String.fromCharCodes(units);
    }
    if (platform == 1) {
      return String.fromCharCodes(raw.map(_decodeMacRomanByte));
    }
    throw StateError('Unsupported name platform reached decoder: $platform');
  }

  static int _decodeMacRomanByte(int byte) {
    if (byte < 0x80) return byte;
    return _macRomanHighBytes.codeUnitAt(byte - 0x80);
  }

  static const _macRomanHighBytes =
      'ÄÅÇÉÑÖÜáàâäãåçéè'
      'êëíìîïñóòôöõúùûü'
      '†°¢£§•¶ß®©™´¨≠ÆØ'
      '∞±≤≥¥µ∂∑∏π∫ªºΩæø'
      '¿¡¬√ƒ≈∆«»… ÀÃÕŒœ'
      '–—“”‘’÷◊ÿŸ⁄€‹›ﬁﬂ'
      '‡·‚„‰ÂÊÁËÈÍÎÏÌÓÔ'
      'ÒÚÛÙıˆ˜¯˘˙˚¸˝˛ˇ';

  static int _namePriority(int platform, int encoding, int language) {
    if (platform == 3 && language == 0x0409) return 0;
    if (platform == 3 && (encoding == 1 || encoding == 10)) return 1;
    if (platform == 0) return 2;
    if (platform == 3) return 3;
    if (platform == 1) return 4;
    return 5;
  }

  static Set<int> _readCmap(ByteData data, _SfntTable table) {
    _requireTableLength(table, 4, 'cmap');
    final version = data.getUint16(table.offset, Endian.big);
    if (version != 0) {
      throw FormatException('Unsupported cmap version: $version');
    }
    final count = data.getUint16(table.offset + 2, Endian.big);
    _requireRelativeRange(table, 4, count * 8, 'cmap records');
    final supported = <int>{};
    var parsedSupportedFormat = false;
    final seenOffsets = <int>{};

    for (var index = 0; index < count; index++) {
      final record = table.offset + 4 + index * 8;
      final platform = data.getUint16(record, Endian.big);
      final encoding = data.getUint16(record + 2, Endian.big);
      final subtableOffset = data.getUint32(record + 4, Endian.big);
      _requireRelativeRange(table, subtableOffset, 2, 'cmap subtable');
      final absolute = table.offset + subtableOffset;
      final format = data.getUint16(absolute, Endian.big);
      if (!_isUnicodeCmap(platform, encoding, format)) continue;
      if (!seenOffsets.add(subtableOffset)) continue;
      if (format == 4) {
        _readCmap4(data, table, subtableOffset, supported);
        parsedSupportedFormat = true;
      } else if (format == 12) {
        _readCmap12(data, table, subtableOffset, supported);
        parsedSupportedFormat = true;
      }
    }
    if (!parsedSupportedFormat) {
      throw const FormatException(
        'cmap has no supported Unicode cmap format 4 or 12',
      );
    }
    return Set<int>.unmodifiable(supported);
  }

  static bool _isUnicodeCmap(int platform, int encoding, int format) {
    if (platform == 0) return format == 4 || format == 12;
    if (platform != 3) return false;
    return (encoding == 1 && format == 4) || (encoding == 10 && format == 12);
  }

  static void _readCmap4(
    ByteData data,
    _SfntTable table,
    int relativeOffset,
    Set<int> supported,
  ) {
    _requireRelativeRange(table, relativeOffset, 14, 'cmap format 4 header');
    final base = table.offset + relativeOffset;
    final length = data.getUint16(base + 2, Endian.big);
    _requireRelativeRange(table, relativeOffset, length, 'cmap format 4');
    final segmentCountX2 = data.getUint16(base + 6, Endian.big);
    if (segmentCountX2 == 0 || segmentCountX2.isOdd) {
      throw const FormatException('Invalid cmap format 4 segment count');
    }
    final segmentCount = segmentCountX2 ~/ 2;
    final fixedArrayMinimum = 16 + segmentCount * 8;
    if (length < fixedArrayMinimum) {
      throw const FormatException('Truncated cmap format 4 arrays');
    }
    final endCodes = base + 14;
    final reservedPad = endCodes + segmentCount * 2;
    if (data.getUint16(reservedPad, Endian.big) != 0) {
      throw const FormatException('cmap format 4 reservedPad must be zero');
    }
    final startCodes = endCodes + segmentCount * 2 + 2;
    final deltas = startCodes + segmentCount * 2;
    final rangeOffsets = deltas + segmentCount * 2;
    if (rangeOffsets + segmentCount * 2 > base + length) {
      throw const FormatException('Truncated cmap format 4 arrays');
    }

    for (var index = 0; index < segmentCount; index++) {
      final start = data.getUint16(startCodes + index * 2, Endian.big);
      final end = data.getUint16(endCodes + index * 2, Endian.big);
      if (start > end) {
        throw const FormatException('Invalid cmap format 4 range');
      }
      final delta = data.getInt16(deltas + index * 2, Endian.big);
      final rangeWord = rangeOffsets + index * 2;
      final rangeOffset = data.getUint16(rangeWord, Endian.big);
      for (var codePoint = start; codePoint <= end; codePoint++) {
        if (codePoint == 0xffff) continue;
        int glyph;
        if (rangeOffset == 0) {
          glyph = (codePoint + delta) & 0xffff;
        } else {
          final glyphOffset = rangeWord + rangeOffset + (codePoint - start) * 2;
          if (glyphOffset + 2 > base + length) {
            throw const FormatException('cmap format 4 glyph outside table');
          }
          glyph = data.getUint16(glyphOffset, Endian.big);
          if (glyph != 0) glyph = (glyph + delta) & 0xffff;
        }
        if (glyph != 0) supported.add(codePoint);
      }
    }
  }

  static void _readCmap12(
    ByteData data,
    _SfntTable table,
    int relativeOffset,
    Set<int> supported,
  ) {
    _requireRelativeRange(table, relativeOffset, 16, 'cmap format 12 header');
    final base = table.offset + relativeOffset;
    if (data.getUint16(base + 2, Endian.big) != 0) {
      throw const FormatException('cmap format 12 reserved field must be zero');
    }
    final length = data.getUint32(base + 4, Endian.big);
    _requireRelativeRange(table, relativeOffset, length, 'cmap format 12');
    final groupCount = data.getUint32(base + 12, Endian.big);
    if (groupCount > (length - 16) ~/ 12) {
      throw const FormatException('Truncated cmap format 12 groups');
    }
    for (var index = 0; index < groupCount; index++) {
      final group = base + 16 + index * 12;
      final start = data.getUint32(group, Endian.big);
      final end = data.getUint32(group + 4, Endian.big);
      final startGlyph = data.getUint32(group + 8, Endian.big);
      if (start > end || end > 0x10ffff) {
        throw const FormatException('Invalid cmap format 12 range');
      }
      for (var codePoint = start; codePoint <= end; codePoint++) {
        if (startGlyph + codePoint - start != 0) supported.add(codePoint);
      }
    }
  }

  static List<SfntAxis> _readAxes(
    Uint8List bytes,
    ByteData data,
    _SfntTable table,
  ) {
    _requireTableLength(table, 16, 'fvar');
    final majorVersion = data.getUint16(table.offset, Endian.big);
    final minorVersion = data.getUint16(table.offset + 2, Endian.big);
    if (majorVersion != 1 || minorVersion != 0) {
      throw FormatException(
        'Unsupported fvar version: $majorVersion.$minorVersion',
      );
    }
    final axesOffset = data.getUint16(table.offset + 4, Endian.big);
    final reserved = data.getUint16(table.offset + 6, Endian.big);
    if (reserved != 2) {
      throw FormatException('Invalid fvar reserved field: $reserved');
    }
    final axisCount = data.getUint16(table.offset + 8, Endian.big);
    final axisSize = data.getUint16(table.offset + 10, Endian.big);
    final instanceCount = data.getUint16(table.offset + 12, Endian.big);
    final instanceSize = data.getUint16(table.offset + 14, Endian.big);
    if (axisSize < 20) {
      throw const FormatException('Invalid fvar axis record size');
    }
    _requireRelativeRange(table, axesOffset, axisCount * axisSize, 'fvar axes');
    final minimumInstanceSize = axisCount * 4 + 4;
    if (instanceCount > 0 &&
        instanceSize != minimumInstanceSize &&
        instanceSize != minimumInstanceSize + 2) {
      throw const FormatException('Invalid fvar instance record size');
    }
    _requireRelativeRange(
      table,
      axesOffset + axisCount * axisSize,
      instanceCount * instanceSize,
      'fvar instances',
    );
    final axes = <SfntAxis>[
      for (var index = 0; index < axisCount; index++)
        _axisAt(bytes, data, table.offset + axesOffset + index * axisSize),
    ];
    if (axes.map((axis) => axis.tag).toSet().length != axes.length) {
      throw const FormatException('Duplicate fvar axis tag');
    }
    for (final axis in axes) {
      if (axis.minimum > axis.defaultValue ||
          axis.defaultValue > axis.maximum) {
        throw FormatException('Invalid fvar axis bounds: ${axis.tag}');
      }
    }
    return List<SfntAxis>.unmodifiable(axes);
  }

  static SfntAxis _axisAt(Uint8List bytes, ByteData data, int offset) =>
      SfntAxis(
        tag: ascii.decode(
          bytes.sublist(offset, offset + 4),
          allowInvalid: false,
        ),
        minimum: data.getInt32(offset + 4, Endian.big) / 65536,
        defaultValue: data.getInt32(offset + 8, Endian.big) / 65536,
        maximum: data.getInt32(offset + 12, Endian.big) / 65536,
      );

  static _SfntTable _requiredTable(Map<String, _SfntTable> tables, String tag) {
    final table = tables[tag];
    if (table == null) throw FormatException('Missing SFNT table: $tag');
    return table;
  }

  static String _requiredName(Map<int, String> names, int id) {
    final value = names[id];
    if (value == null || value.isEmpty) {
      throw FormatException('Missing SFNT name id $id');
    }
    return value;
  }

  static void _requireTableLength(
    _SfntTable table,
    int required,
    String label,
  ) {
    if (table.length < required) {
      throw FormatException('$label table is truncated');
    }
  }

  static void _requireRelativeRange(
    _SfntTable table,
    int offset,
    int length,
    String label,
  ) {
    if (offset < 0 || length < 0 || offset > table.length - length) {
      throw FormatException('$label is outside its SFNT table');
    }
  }

  static void _requireRange(
    ByteData data,
    int offset,
    int length,
    String label,
  ) {
    if (offset < 0 || length < 0 || offset > data.lengthInBytes - length) {
      throw FormatException('$label is outside the font bytes');
    }
  }
}

class _SfntTable {
  const _SfntTable(this.offset, this.length);

  final int offset;
  final int length;
}

class _NameCandidate {
  const _NameCandidate({
    required this.value,
    required this.priority,
    required this.order,
  });

  final String value;
  final int priority;
  final int order;

  static int compare(_NameCandidate left, _NameCandidate right) {
    final priority = left.priority.compareTo(right.priority);
    return priority != 0 ? priority : left.order.compareTo(right.order);
  }
}
