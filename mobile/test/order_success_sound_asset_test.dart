import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('order success sound exactly matches the approved video clip', () async {
    final data = await rootBundle.load('assets/sounds/order_success.wav');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final wav = ByteData.sublistView(bytes);

    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(wav.getUint16(22, Endian.little), 2);
    expect(wav.getUint32(24, Endian.little), 44100);
    expect(wav.getUint16(34, Endian.little), 16);

    final dataOffset = _findDataOffset(bytes);
    final dataLength = wav.getUint32(dataOffset + 4, Endian.little);
    final durationSeconds = dataLength / (44100 * 2 * 2);
    expect(durationSeconds, closeTo(.247, 1 / 44100));
    expect(
      sha256.convert(bytes).toString(),
      '2706d447e3d95bfe85c3f655219d886be61fad5af051cd14d4dd54df1d132bb3',
    );

    var peak = 0;
    for (var offset = dataOffset + 8; offset < bytes.length - 1; offset += 2) {
      peak = math.max(peak, wav.getInt16(offset, Endian.little).abs());
    }
    expect(peak, greaterThan(2000));
  });
}

int _findDataOffset(Uint8List bytes) {
  for (var offset = 12; offset <= bytes.length - 8;) {
    if (String.fromCharCodes(bytes.sublist(offset, offset + 4)) == 'data') {
      return offset;
    }
    final chunkLength = ByteData.sublistView(
      bytes,
    ).getUint32(offset + 4, Endian.little);
    offset += 8 + chunkLength + chunkLength.remainder(2);
  }
  throw const FormatException('WAV data chunk not found');
}
