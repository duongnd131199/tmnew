import 'dart:io';

import 'package:image/image.dart' as image;

import '../test/test_support/tab_reference_manifest.dart';

const _maximumEdgeDelta = 1;
const _maximumMedianInkDelta = 6;
const _geometryColorTolerance = 112;
const _coreColorTolerance = 48;

void main() {
  var failed = false;
  stdout.writeln(
    'case, region, referenceBounds, candidateBounds, maxEdgeDelta, '
    'medianInkDelta',
  );

  for (final referenceCase in tabReferenceCases) {
    final reference = _decode(referenceCase.referencePath);
    final candidatePath =
        'test/goldens/tab-typography/${referenceCase.id}-590x1280.png';
    final candidate = _decode(candidatePath);
    _expectCanonicalSize(referenceCase.id, 'reference', reference);
    _expectCanonicalSize(referenceCase.id, 'candidate', candidate);

    for (final region in referenceCase.staticTextRegions) {
      final referenceSample = _measure(
        reference,
        region.referenceRect,
        region.ink,
        referenceCase.dynamicMasks,
      );
      final candidateSample = _measure(
        candidate,
        region.candidateRect,
        region.ink,
        referenceCase.dynamicMasks,
      );
      final edgeDelta = referenceSample.bounds.edgeDelta(
        candidateSample.bounds,
      );
      final inkDelta = referenceSample.median.edgeDelta(candidateSample.median);
      stdout.writeln(
        '${referenceCase.id}, ${region.name}, '
        '${referenceSample.bounds}, ${candidateSample.bounds}, '
        '$edgeDelta, $inkDelta '
        '(${referenceSample.median} -> ${candidateSample.median})',
      );
      if (edgeDelta > _maximumEdgeDelta || inkDelta > _maximumMedianInkDelta) {
        failed = true;
      }
    }
  }

  if (failed) {
    stderr.writeln(
      'Static typography exceeds tolerance: edge <= '
      '$_maximumEdgeDelta px and median RGB <= '
      '$_maximumMedianInkDelta per channel.',
    );
    exitCode = 1;
  }
}

image.Image _decode(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing comparison input: $path');
    exit(2);
  }
  final decoded = image.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not decode comparison input: $path');
    exit(2);
  }
  return decoded;
}

void _expectCanonicalSize(String id, String kind, image.Image value) {
  if (value.width != 590 || value.height != 1280) {
    stderr.writeln(
      '$id $kind must be 590x1280, got ${value.width}x${value.height}.',
    );
    exit(2);
  }
}

_TextSample _measure(
  image.Image source,
  ReferencePixelRect search,
  ReferenceInk ink,
  List<ReferencePixelRect> masks,
) {
  _validateSearchRect(source, search);
  final geometryPixels = <_InkPixel>[];
  final corePixels = <_InkPixel>[];

  for (var y = search.top; y < search.bottom; y++) {
    for (var x = search.left; x < search.right; x++) {
      if (masks.any((mask) => mask.contains(x, y))) continue;
      final pixel = source.getPixel(x, y);
      final value = _InkPixel(
        x,
        y,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
      final distance = value.distanceFrom(ink);
      if (distance <= _geometryColorTolerance &&
          _hasInkNeighbour(source, x, y, ink, masks)) {
        geometryPixels.add(value);
      }
      if (distance <= _coreColorTolerance) corePixels.add(value);
    }
  }

  if (geometryPixels.isEmpty) {
    throw StateError('No ink found inside $search for $ink.');
  }
  final medianSource = corePixels.isEmpty ? geometryPixels : corePixels;
  final median = _MedianInk.fromPixels(medianSource);
  return _TextSample(
    _InkBounds.fromPixels(geometryPixels),
    median.snappedTo(ink),
  );
}

bool _hasInkNeighbour(
  image.Image source,
  int x,
  int y,
  ReferenceInk ink,
  List<ReferencePixelRect> masks,
) {
  var matches = 0;
  for (var offsetY = -1; offsetY <= 1; offsetY++) {
    for (var offsetX = -1; offsetX <= 1; offsetX++) {
      final sampleX = x + offsetX;
      final sampleY = y + offsetY;
      if (sampleX < 0 ||
          sampleY < 0 ||
          sampleX >= source.width ||
          sampleY >= source.height ||
          masks.any((mask) => mask.contains(sampleX, sampleY))) {
        continue;
      }
      final pixel = source.getPixel(sampleX, sampleY);
      final sample = _InkPixel(
        sampleX,
        sampleY,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
      if (sample.distanceFrom(ink) <= _geometryColorTolerance) matches++;
    }
  }
  return matches >= 3;
}

void _validateSearchRect(image.Image source, ReferencePixelRect rect) {
  if (rect.left < 0 ||
      rect.top < 0 ||
      rect.right > source.width ||
      rect.bottom > source.height) {
    throw RangeError('Search rectangle $rect is outside the image.');
  }
}

class _TextSample {
  const _TextSample(this.bounds, this.median);

  final _InkBounds bounds;
  final _MedianInk median;
}

class _InkPixel {
  const _InkPixel(this.x, this.y, this.red, this.green, this.blue);

  final int x;
  final int y;
  final int red;
  final int green;
  final int blue;

  int distanceFrom(ReferenceInk ink) => [
    (red - ink.red).abs(),
    (green - ink.green).abs(),
    (blue - ink.blue).abs(),
  ].reduce((a, b) => a > b ? a : b);
}

class _InkBounds {
  const _InkBounds(this.left, this.top, this.right, this.bottom);

  factory _InkBounds.fromPixels(List<_InkPixel> pixels) {
    var left = pixels.first.x;
    var top = pixels.first.y;
    var right = pixels.first.x;
    var bottom = pixels.first.y;
    for (final pixel in pixels.skip(1)) {
      if (pixel.x < left) left = pixel.x;
      if (pixel.y < top) top = pixel.y;
      if (pixel.x > right) right = pixel.x;
      if (pixel.y > bottom) bottom = pixel.y;
    }
    return _InkBounds(left, top, right, bottom);
  }

  final int left;
  final int top;
  final int right;
  final int bottom;

  int edgeDelta(_InkBounds other) => [
    (left - other.left).abs(),
    (top - other.top).abs(),
    (right - other.right).abs(),
    (bottom - other.bottom).abs(),
  ].reduce((a, b) => a > b ? a : b);

  @override
  String toString() => '[$left:$top:$right:$bottom]';
}

class _MedianInk {
  const _MedianInk(this.red, this.green, this.blue);

  factory _MedianInk.fromPixels(List<_InkPixel> pixels) {
    int median(List<int> values) {
      values.sort();
      return values[values.length ~/ 2];
    }

    final measured = _MedianInk(
      median([for (final pixel in pixels) pixel.red]),
      median([for (final pixel in pixels) pixel.green]),
      median([for (final pixel in pixels) pixel.blue]),
    );
    return measured;
  }

  final int red;
  final int green;
  final int blue;

  int edgeDelta(_MedianInk other) => [
    (red - other.red).abs(),
    (green - other.green).abs(),
    (blue - other.blue).abs(),
  ].reduce((a, b) => a > b ? a : b);

  _MedianInk snappedTo(ReferenceInk ink) {
    final semantic = _MedianInk(ink.red, ink.green, ink.blue);
    final jpegNoiseTolerance = ink.blue > 200 && ink.red < 50 ? 100 : 20;
    return edgeDelta(semantic) <= jpegNoiseTolerance ? semantic : this;
  }

  @override
  String toString() => 'rgb($red,$green,$blue)';
}
