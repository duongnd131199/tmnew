import 'dart:io';

import 'package:image/image.dart' as image;

import '../test/test_support/tab_reference_manifest.dart';

const _maximumEdgeDelta = 1;
const _androidMaximumEdgeDelta = 2;
const _androidSemanticColorTolerance = 12;
const _maximumInkDensityDeltaPercent = 30;
const _androidMaximumInkDensityDeltaPercent = 40;

void main(List<String> args) {
  exitCode = runTabTypographyComparison(args);
}

int runTabTypographyComparison(
  List<String> args, {
  StringSink? standardOutput,
  StringSink? errorOutput,
}) {
  final output = standardOutput ?? stdout;
  final errors = errorOutput ?? stderr;
  final configuration = switch (args) {
    [] => const _ComparisonConfiguration(
      candidateDirectory: 'test/goldens/tab-typography',
      renderer: _CandidateRenderer.deterministic,
    ),
    ['--candidate-dir', final directory] => _ComparisonConfiguration(
      candidateDirectory: directory,
      renderer: _CandidateRenderer.deterministic,
    ),
    ['--candidate-dir', final directory, '--candidate-renderer', 'android'] =>
      _ComparisonConfiguration(
        candidateDirectory: directory,
        renderer: _CandidateRenderer.android,
      ),
    _ => throw ArgumentError(
      'Usage: dart run tool/compare_tab_typography.dart '
      '[--candidate-dir <directory> '
      '[--candidate-renderer android]]',
    ),
  };
  final candidateDirectory = configuration.candidateDirectory;
  final maximumEdgeDelta = configuration.renderer == _CandidateRenderer.android
      ? _androidMaximumEdgeDelta
      : _maximumEdgeDelta;
  final maximumInkDensityDeltaPercent =
      configuration.renderer == _CandidateRenderer.android
      ? _androidMaximumInkDensityDeltaPercent
      : _maximumInkDensityDeltaPercent;
  var failed = false;
  output.writeln('candidateRenderer, ${configuration.renderer.name}');
  output.writeln(
    'case, region, referenceBounds, candidateBounds, maxEdgeDelta, '
    'semanticInkDelta, inkDensityDeltaPercent, candidateInkRatio',
  );

  for (final referenceCase in tabReferenceCases) {
    final reference = _decode(referenceCase.referencePath);
    final candidatePath =
        '$candidateDirectory/${referenceCase.id}-590x1280.png';
    final candidate = _decode(candidatePath);
    _expectCanonicalSize(referenceCase.id, 'reference', reference);
    _expectCanonicalSize(referenceCase.id, 'candidate', candidate);

    for (final region in referenceCase.staticTextRegions) {
      final geometryInk = geometryInkFor(region.geometryInk ?? region.ink);
      final referenceSample = _measure(
        reference,
        region.referenceRect,
        geometryInk,
        referenceCase.dynamicMasks,
        geometryColorTolerance: region.geometryColorTolerance,
        measureLargestGeometryComponent: region.measureLargestGeometryComponent,
      );
      final candidateSample = _measure(
        candidate,
        region.candidateRect,
        geometryInk,
        referenceCase.dynamicMasks,
        geometryColorTolerance: _candidateGeometryTolerance(
          region,
          configuration.renderer,
        ),
        measureLargestGeometryComponent: region.measureLargestGeometryComponent,
      );
      final edgeDelta = referenceSample.bounds.edgeDelta(
        candidateSample.bounds,
      );
      final expectedInk = _MeasuredInk.fromReference(region.ink);
      final inkDelta = expectedInk.edgeDelta(candidateSample.semanticInk);
      final inkDensityDeltaPercent = referenceSample.inkDensityDeltaPercent(
        candidateSample,
      );
      final inkDensityTolerancePercent =
          region.inkDensityTolerancePercent ?? maximumInkDensityDeltaPercent;
      final inkDensityReport = region.measureInkDensity
          ? '${inkDensityDeltaPercent.toStringAsFixed(1)}%'
          : 'not-measured';
      final inkDensityRatio = referenceSample.inkDensityRatio(candidateSample);
      final inkDensityRatioReport = region.measureInkDensity
          ? '${inkDensityRatio.toStringAsFixed(3)}x'
          : 'not-measured';
      output.writeln(
        '${referenceCase.id}, ${region.name}, '
        '${referenceSample.bounds}, ${candidateSample.bounds}, '
        '$edgeDelta, $inkDelta, $inkDensityReport, $inkDensityRatioReport '
        '(reference ${referenceSample.semanticInk}; '
        'expected $expectedInk -> candidate ${candidateSample.semanticInk})',
      );
      final semanticColorTolerance =
          configuration.renderer == _CandidateRenderer.android
          ? _androidSemanticColorTolerance
          : region.semanticColorTolerance;
      if (edgeDelta > maximumEdgeDelta ||
          inkDelta > semanticColorTolerance ||
          (region.measureInkDensity &&
              inkDensityDeltaPercent > inkDensityTolerancePercent)) {
        failed = true;
      }
    }
  }

  if (failed) {
    errors.writeln(
      'Static typography exceeds tolerance: edge <= '
      '$maximumEdgeDelta px, semantic RGB within each renderer tolerance, '
      'and ink density <= $maximumInkDensityDeltaPercent%.',
    );
    return 1;
  }
  return 0;
}

int _candidateGeometryTolerance(
  StaticTextRegion region,
  _CandidateRenderer renderer,
) {
  if (renderer == _CandidateRenderer.deterministic ||
      region.measureLargestGeometryComponent) {
    return region.geometryColorTolerance;
  }
  final expanded = region.geometryColorTolerance + 16;
  return expanded > 128 ? 128 : expanded;
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
  List<ReferencePixelRect> masks, {
  required int geometryColorTolerance,
  required bool measureLargestGeometryComponent,
}) {
  _validateSearchRect(source, search);
  final searchPixels = <_InkPixel>[];
  final geometryPixels = <_InkPixel>[];

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
      searchPixels.add(value);
      final distance = value.distanceFrom(ink);
      if (distance <= geometryColorTolerance &&
          _hasInkNeighbour(
            source,
            x,
            y,
            ink,
            masks,
            geometryColorTolerance: geometryColorTolerance,
          )) {
        geometryPixels.add(value);
      }
    }
  }

  final measuredGeometryPixels = measureLargestGeometryComponent
      ? _largestConnectedComponent(geometryPixels)
      : geometryPixels;
  if (measuredGeometryPixels.isEmpty) {
    throw StateError('No ink found inside $search for $ink.');
  }
  final backgroundInk = _MeasuredInk.modeFromPixels(searchPixels);
  final semanticInk = measureLargestGeometryComponent
      ? _MeasuredInk.modeFromPixels(measuredGeometryPixels)
      : _MeasuredInk.mostOpaqueFromPixels(
          measuredGeometryPixels,
          backgroundInk,
        );
  return _TextSample(
    _InkBounds.fromPixels(measuredGeometryPixels),
    semanticInk,
    measuredGeometryPixels.fold<double>(
      0,
      (total, pixel) => total + pixel.distanceFromMeasured(backgroundInk) / 255,
    ),
  );
}

List<_InkPixel> _largestConnectedComponent(List<_InkPixel> pixels) {
  if (pixels.isEmpty) return const [];
  int keyOf(int x, int y) => (y << 20) | x;
  final remaining = <int, _InkPixel>{
    for (final pixel in pixels) keyOf(pixel.x, pixel.y): pixel,
  };
  var largest = <_InkPixel>[];
  while (remaining.isNotEmpty) {
    final seedKey = remaining.keys.first;
    final seed = remaining.remove(seedKey)!;
    final queue = <_InkPixel>[seed];
    for (var index = 0; index < queue.length; index++) {
      final pixel = queue[index];
      for (final neighbour in <(int, int)>[
        (pixel.x - 1, pixel.y),
        (pixel.x + 1, pixel.y),
        (pixel.x, pixel.y - 1),
        (pixel.x, pixel.y + 1),
      ]) {
        final next = remaining.remove(keyOf(neighbour.$1, neighbour.$2));
        if (next != null) queue.add(next);
      }
    }
    if (queue.length > largest.length) largest = queue;
  }
  return largest;
}

bool _hasInkNeighbour(
  image.Image source,
  int x,
  int y,
  ReferenceInk ink,
  List<ReferencePixelRect> masks, {
  required int geometryColorTolerance,
}) {
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
      if (sample.distanceFrom(ink) <= geometryColorTolerance) matches++;
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
  const _TextSample(this.bounds, this.semanticInk, this.opticalInkArea);

  final _InkBounds bounds;
  final _MeasuredInk semanticInk;
  final double opticalInkArea;

  double inkDensityDeltaPercent(_TextSample other) =>
      ((opticalInkArea - other.opticalInkArea).abs() / opticalInkArea) * 100;

  double inkDensityRatio(_TextSample other) =>
      other.opticalInkArea / opticalInkArea;
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

  int distanceFromMeasured(_MeasuredInk ink) => [
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

class _MeasuredInk {
  const _MeasuredInk(this.red, this.green, this.blue);

  factory _MeasuredInk.fromReference(ReferenceInk ink) =>
      _MeasuredInk(ink.red, ink.green, ink.blue);

  factory _MeasuredInk.modeFromPixels(List<_InkPixel> pixels) {
    final counts = <int, int>{};
    var modeKey = 0;
    var modeCount = 0;
    for (final pixel in pixels) {
      final key = (pixel.red << 16) | (pixel.green << 8) | pixel.blue;
      final count = (counts[key] ?? 0) + 1;
      counts[key] = count;
      if (count > modeCount) {
        modeKey = key;
        modeCount = count;
      }
    }
    return _MeasuredInk(
      (modeKey >> 16) & 0xff,
      (modeKey >> 8) & 0xff,
      modeKey & 0xff,
    );
  }

  factory _MeasuredInk.mostOpaqueFromPixels(
    List<_InkPixel> pixels,
    _MeasuredInk background,
  ) {
    final counts = <int, int>{};
    for (final pixel in pixels) {
      final key = (pixel.red << 16) | (pixel.green << 8) | pixel.blue;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    var opaqueKey = counts.keys.first;
    var opaqueDistance = -1;
    var opaqueCount = -1;
    for (final entry in counts.entries) {
      final candidate = _MeasuredInk(
        (entry.key >> 16) & 0xff,
        (entry.key >> 8) & 0xff,
        entry.key & 0xff,
      );
      final distance = candidate.edgeDelta(background);
      if (distance > opaqueDistance ||
          (distance == opaqueDistance && entry.value > opaqueCount)) {
        opaqueKey = entry.key;
        opaqueDistance = distance;
        opaqueCount = entry.value;
      }
    }
    return _MeasuredInk(
      (opaqueKey >> 16) & 0xff,
      (opaqueKey >> 8) & 0xff,
      opaqueKey & 0xff,
    );
  }

  final int red;
  final int green;
  final int blue;

  int edgeDelta(_MeasuredInk other) => [
    (red - other.red).abs(),
    (green - other.green).abs(),
    (blue - other.blue).abs(),
  ].reduce((a, b) => a > b ? a : b);

  @override
  String toString() => 'rgb($red,$green,$blue)';
}

enum _CandidateRenderer { deterministic, android }

class _ComparisonConfiguration {
  const _ComparisonConfiguration({
    required this.candidateDirectory,
    required this.renderer,
  });

  final String candidateDirectory;
  final _CandidateRenderer renderer;
}
