import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import '../test/test_support/tab_reference_manifest.dart';

const _maximumEdgeDelta = 1;
const _maximumSemanticColorDelta = 4;
const _maximumInkDensityDeltaPercent = 5.0;
const _staticPixelChannelTolerance = 12;
const _maximumStaticDifferenceRatio = 0.005;

void main(List<String> args) {
  exitCode = runTabTypographyComparison(args);
}

int runTabTypographyComparison(
  List<String> args, {
  StringSink? standardOutput,
  StringSink? errorOutput,
  List<TabReferenceCase> referenceCases = tabReferenceCases,
  String? referenceDirectory,
}) {
  final output = standardOutput ?? stdout;
  final errors = errorOutput ?? stderr;
  late final _ComparisonConfiguration configuration;
  try {
    configuration = _ComparisonConfiguration.parse(args);
  } on _UsageError catch (error) {
    errors.writeln(error.message);
    errors.writeln(_ComparisonConfiguration.usage);
    return 2;
  }

  final manifestErrors = _validateManifest(referenceCases);
  if (manifestErrors.isNotEmpty) {
    errors.writeln('Invalid reference parity manifest:');
    for (final error in manifestErrors) {
      errors.writeln('- $error');
    }
    return 2;
  }

  Directory? artifactDirectory;
  if (configuration.outputDirectory != null) {
    try {
      artifactDirectory = Directory(configuration.outputDirectory!)
        ..createSync(recursive: true);
    } on FileSystemException catch (error) {
      errors.writeln(
        'Could not create output directory '
        '${configuration.outputDirectory}: ${error.message}',
      );
      return 2;
    }
  }

  final report = _CsvReport();
  var failed = false;
  try {
    for (final referenceCase in referenceCases) {
      final referencePath = referenceDirectory == null
          ? referenceCase.referencePath
          : '$referenceDirectory/${referenceCase.fileName}';
      final candidatePath =
          '${configuration.candidateDirectory}/'
          '${referenceCase.id}-590x1280.png';
      final reference = _decode(referencePath);
      final candidate = _decode(candidatePath);
      _expectCanonicalSize(referenceCase, 'reference', reference);
      _expectCanonicalSize(referenceCase, 'candidate', candidate);

      final masks = _MaskMap(
        width: reference.width,
        height: reference.height,
        masks: referenceCase.dynamicMaskRegions,
      );
      final staticAudit = _StaticPixelAudit.measure(
        caseId: referenceCase.id,
        referencePath: referencePath,
        candidatePath: candidatePath,
        reference: reference,
        candidate: candidate,
        masks: masks,
        createArtifacts: artifactDirectory != null,
      );

      final canvasResult = staticAudit.resultFor(
        referenceCase.staticAuditRegion,
      );
      failed |= _writeStaticResult(
        report,
        configuration,
        referenceCase,
        recordType: 'static-canvas',
        regionType: 'fullCanvas',
        regionName: 'static-audit',
        rect: referenceCase.staticAuditRegion,
        result: canvasResult,
      );

      for (final region in referenceCase.visualRegions) {
        failed |= _writeStaticResult(
          report,
          configuration,
          referenceCase,
          recordType: 'static-region',
          regionType: region.type.name,
          regionName: region.name,
          rect: region.rect,
          result: staticAudit.resultFor(region.rect),
        );
      }
      for (final control in referenceCase.staticControlRegions) {
        failed |= _writeStaticResult(
          report,
          configuration,
          referenceCase,
          recordType: 'static-control',
          regionType: 'control',
          regionName: control.name,
          rect: control.rect,
          result: staticAudit.resultFor(control.rect),
        );
      }

      for (final region in referenceCase.staticTextRegions) {
        final geometryInk = geometryInkFor(region.geometryInk ?? region.ink);
        try {
          final referenceSample = _measureText(
            reference,
            region.referenceRect,
            geometryInk,
            masks,
            geometryColorTolerance: region.geometryColorTolerance,
            measureLargestGeometryComponent:
                region.measureLargestGeometryComponent,
          );
          final candidateSample = _measureText(
            candidate,
            region.candidateRect,
            geometryInk,
            masks,
            geometryColorTolerance: _candidateGeometryTolerance(
              region,
              configuration.renderer,
            ),
            measureLargestGeometryComponent:
                region.measureLargestGeometryComponent,
          );
          final edgeDelta = referenceSample.bounds.edgeDelta(
            candidateSample.bounds,
          );
          final semanticInkDelta = referenceSample.semanticInk.edgeDelta(
            candidateSample.semanticInk,
          );
          final densityDelta = referenceSample.inkDensityDeltaPercent(
            candidateSample,
          );
          final densityFailed = densityDelta > _maximumInkDensityDeltaPercent;
          final regionFailed =
              edgeDelta > _maximumEdgeDelta ||
              semanticInkDelta > _maximumSemanticColorDelta ||
              densityFailed;
          failed |= regionFailed;
          final details = <String>[
            if (edgeDelta > _maximumEdgeDelta)
              'edge delta $edgeDelta exceeds $_maximumEdgeDelta physical px',
            if (semanticInkDelta > _maximumSemanticColorDelta)
              'semantic RGB delta $semanticInkDelta exceeds '
                  '$_maximumSemanticColorDelta/channel',
            if (densityFailed)
              'ink density delta ${densityDelta.toStringAsFixed(1)}% exceeds '
                  '${_maximumInkDensityDeltaPercent.toStringAsFixed(1)}%',
          ];
          report.add(
            recordType: 'text',
            renderer: configuration.renderer.name,
            caseId: referenceCase.id,
            regionType: 'staticText',
            regionName: region.name,
            referenceBounds: referenceSample.bounds.toString(),
            candidateBounds: candidateSample.bounds.toString(),
            edgeDelta: '$edgeDelta',
            manifestInkHint: _MeasuredInk.fromReference(region.ink).toString(),
            measuredReferenceInk: referenceSample.semanticInk.toString(),
            candidateInk: candidateSample.semanticInk.toString(),
            semanticInkDelta: '$semanticInkDelta',
            inkDensityDeltaPercent: densityDelta.toStringAsFixed(3),
            candidateInkRatio: referenceSample
                .inkDensityRatio(candidateSample)
                .toStringAsFixed(3),
            status: regionFailed ? 'FAIL' : 'PASS',
            details: details.join('; '),
          );
        } on StateError catch (error) {
          failed = true;
          report.add(
            recordType: 'text',
            renderer: configuration.renderer.name,
            caseId: referenceCase.id,
            regionType: 'staticText',
            regionName: region.name,
            referenceBounds: region.referenceRect.toString(),
            candidateBounds: region.candidateRect.toString(),
            manifestInkHint: _MeasuredInk.fromReference(region.ink).toString(),
            status: 'FAIL',
            details: 'measurement failed: ${error.message}',
          );
        }
      }

      if (artifactDirectory != null) {
        _writePng(
          '${artifactDirectory.path}/${referenceCase.id}-overlay-50-50.png',
          staticAudit.overlay!,
        );
        _writePng(
          '${artifactDirectory.path}/${referenceCase.id}-heatmap.png',
          staticAudit.heatmap!,
        );
      }
    }
  } on _ComparisonInputError catch (error) {
    errors.writeln(error.message);
    return 2;
  } on FileSystemException catch (error) {
    errors.writeln('Could not write comparison evidence: ${error.message}');
    return 2;
  }

  final csv = report.contents;
  output.write(csv);
  if (artifactDirectory != null) {
    try {
      File('${artifactDirectory.path}/comparison.csv').writeAsStringSync(csv);
    } on FileSystemException catch (error) {
      errors.writeln('Could not write comparison CSV: ${error.message}');
      return 2;
    }
  }

  if (failed) {
    errors.writeln(
      'Reference parity failed for ${configuration.renderer.name} candidates. '
      'Required text limits: edge <= $_maximumEdgeDelta physical px, '
      'semantic RGB <= $_maximumSemanticColorDelta/channel against measured '
      'reference ink, optical density delta <= '
      '${_maximumInkDensityDeltaPercent.toStringAsFixed(1)}%. Required static '
      'regions: differing pixel ratio <= '
      '${(_maximumStaticDifferenceRatio * 100).toStringAsFixed(1)}% after '
      'a measured-reference JPEG tolerance of '
      '$_staticPixelChannelTolerance/channel. See FAIL rows for actions.',
    );
    return 1;
  }
  return 0;
}

bool _writeStaticResult(
  _CsvReport report,
  _ComparisonConfiguration configuration,
  TabReferenceCase referenceCase, {
  required String recordType,
  required String regionType,
  required String regionName,
  required ReferencePixelRect rect,
  required _StaticRegionResult result,
}) {
  final regionFailed =
      result.auditedPixelCount == 0 ||
      result.differingPixelRatio > _maximumStaticDifferenceRatio;
  report.add(
    recordType: recordType,
    renderer: configuration.renderer.name,
    caseId: referenceCase.id,
    regionType: regionType,
    regionName: regionName,
    referenceBounds: rect.toString(),
    candidateBounds: rect.toString(),
    differingPixelCount: '${result.differingPixelCount}',
    auditedPixelCount: '${result.auditedPixelCount}',
    differingPixelRatio: result.differingPixelRatio.toStringAsFixed(6),
    status: regionFailed ? 'FAIL' : 'PASS',
    details: result.auditedPixelCount == 0
        ? 'no unmasked static pixels remain to audit'
        : regionFailed
        ? '${result.differingPixelCount} pixels differ beyond '
              '$_staticPixelChannelTolerance RGB/channel; ratio '
              '${(result.differingPixelRatio * 100).toStringAsFixed(3)}% '
              'exceeds ${(_maximumStaticDifferenceRatio * 100).toStringAsFixed(1)}%'
        : '',
  );
  return regionFailed;
}

List<String> _validateManifest(List<TabReferenceCase> cases) {
  final errors = <String>[];
  final seenIds = <String>{};
  final safeCaseId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$');
  final safeFileName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
  for (final item in cases) {
    if (item.id.trim().isEmpty) {
      errors.add('case id must be non-empty.');
    } else {
      if (!safeCaseId.hasMatch(item.id) || item.id.contains('..')) {
        errors.add(
          '${item.id}: unsafe case id "${item.id}"; use only letters, '
          'digits, underscores, and hyphens.',
        );
      }
      if (!seenIds.add(item.id)) {
        errors.add('duplicate case id "${item.id}".');
      }
    }
    if (item.fileName.trim().isEmpty) {
      errors.add('${item.id}: fileName must be non-empty.');
    } else if (!safeFileName.hasMatch(item.fileName) ||
        item.fileName.contains('/') ||
        item.fileName.contains(r'\') ||
        item.fileName.contains('..')) {
      errors.add(
        '${item.id}: unsafe fileName "${item.fileName}"; provide a basename '
        'without slash, backslash, or traversal segments.',
      );
    }
    final canvas = item.staticAuditRegion;
    if (canvas.left != 0 ||
        canvas.top != 0 ||
        canvas.width <= 0 ||
        canvas.height <= 0) {
      errors.add(
        '${item.id}: static audit canvas must start at (0,0) and have '
        'positive dimensions, got $canvas.',
      );
      continue;
    }
    void validateRect(String label, ReferencePixelRect rect) {
      if (!_isPositiveRect(rect) || !_containsRect(canvas, rect)) {
        errors.add('$label $rect is outside static audit canvas $canvas.');
      }
    }

    for (final region in item.visualRegions) {
      validateRect('${item.id}: visual region ${region.name}', region.rect);
    }
    for (final control in item.staticControlRegions) {
      validateRect('${item.id}: static control ${control.name}', control.rect);
    }
    for (final text in item.staticTextRegions) {
      validateRect(
        '${item.id}: text region ${text.name} reference rect',
        text.referenceRect,
      );
      validateRect(
        '${item.id}: text region ${text.name} candidate rect',
        text.candidateRect,
      );
    }
    for (var index = 0; index < item.dynamicMaskRegions.length; index++) {
      final mask = item.dynamicMaskRegions[index];
      final label = '${item.id}: dynamic mask #$index (${mask.kind.name})';
      validateRect(label, mask.rect);
      if (mask.reason.trim().isEmpty) {
        errors.add('$label must have a non-empty reason.');
      }
      for (final control in item.staticControlRegions) {
        if (_rectsIntersect(mask.rect, control.rect)) {
          errors.add(
            '$label ${mask.rect} intersects required static control '
            '${control.name} ${control.rect}. Narrow or remove the mask.',
          );
        }
      }
      for (final text in item.staticTextRegions) {
        final intersectsReference = _rectsIntersect(
          mask.rect,
          text.referenceRect,
        );
        final intersectsCandidate = _rectsIntersect(
          mask.rect,
          text.candidateRect,
        );
        if (!text.allowsDynamicMask &&
            (intersectsReference || intersectsCandidate)) {
          errors.add(
            '$label ${mask.rect} intersects static text ${text.name} '
            '(reference ${text.referenceRect}, candidate '
            '${text.candidateRect}). Set allowsDynamicMask only for a '
            'genuinely dynamic legacy text region.',
          );
        }
      }
    }
  }
  return errors;
}

bool _isPositiveRect(ReferencePixelRect rect) =>
    rect.width > 0 && rect.height > 0;

bool _containsRect(ReferencePixelRect outer, ReferencePixelRect inner) =>
    inner.left >= outer.left &&
    inner.top >= outer.top &&
    inner.right <= outer.right &&
    inner.bottom <= outer.bottom;

bool _rectsIntersect(ReferencePixelRect left, ReferencePixelRect right) =>
    left.left < right.right &&
    left.right > right.left &&
    left.top < right.bottom &&
    left.bottom > right.top;

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
    throw _ComparisonInputError('Missing comparison input: $path');
  }
  final decoded = image.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    throw _ComparisonInputError('Could not decode comparison input: $path');
  }
  return decoded;
}

void _expectCanonicalSize(
  TabReferenceCase referenceCase,
  String kind,
  image.Image value,
) {
  final expectedWidth = referenceCase.staticAuditRegion.right;
  final expectedHeight = referenceCase.staticAuditRegion.bottom;
  if (value.width != expectedWidth || value.height != expectedHeight) {
    throw _ComparisonInputError(
      '${referenceCase.id} $kind must be ${expectedWidth}x$expectedHeight, '
      'got ${value.width}x${value.height}.',
    );
  }
}

void _writePng(String path, image.Image value) {
  File(path).writeAsBytesSync(image.encodePng(value));
}

_TextSample _measureText(
  image.Image source,
  ReferencePixelRect search,
  ReferenceInk ink,
  _MaskMap masks, {
  required int geometryColorTolerance,
  required bool measureLargestGeometryComponent,
}) {
  final searchPixels = <_InkPixel>[];
  final geometryPixels = <_InkPixel>[];

  for (var y = search.top; y < search.bottom; y++) {
    for (var x = search.left; x < search.right; x++) {
      if (masks.contains(x, y)) continue;
      final pixel = source.getPixel(x, y);
      final value = _InkPixel(
        x,
        y,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
      searchPixels.add(value);
      if (value.distanceFrom(ink) <= geometryColorTolerance &&
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
    throw StateError(
      'No ink found inside $search for ${_MeasuredInk.fromReference(ink)}.',
    );
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
    final seed = remaining.remove(remaining.keys.first)!;
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
  _MaskMap masks, {
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
          masks.contains(sampleX, sampleY)) {
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

class _StaticPixelAudit {
  const _StaticPixelAudit({
    required this.width,
    required this.differencePrefix,
    required this.auditedPrefix,
    this.overlay,
    this.heatmap,
  });

  factory _StaticPixelAudit.measure({
    required String caseId,
    required String referencePath,
    required String candidatePath,
    required image.Image reference,
    required image.Image candidate,
    required _MaskMap masks,
    required bool createArtifacts,
  }) {
    final width = reference.width;
    final height = reference.height;
    final stride = width + 1;
    final differencePrefix = Uint32List(stride * (height + 1));
    final auditedPrefix = Uint32List(stride * (height + 1));
    final overlay = createArtifacts
        ? image.Image(width: width, height: height, numChannels: 4)
        : null;
    final heatmap = createArtifacts
        ? image.Image(width: width, height: height, numChannels: 4)
        : null;

    for (var y = 0; y < height; y++) {
      var rowDifferences = 0;
      var rowAudited = 0;
      for (var x = 0; x < width; x++) {
        final referencePixel = reference.getPixel(x, y);
        final candidatePixel = candidate.getPixel(x, y);
        final referenceAlpha = referencePixel.a.toInt();
        if (referenceAlpha != 255) {
          throw _ComparisonInputError(
            '$caseId reference input $referencePath must be fully opaque; '
            'pixel ($x,$y) has alpha $referenceAlpha.',
          );
        }
        final candidateAlpha = candidatePixel.a.toInt();
        if (candidateAlpha != 255) {
          throw _ComparisonInputError(
            '$caseId candidate input $candidatePath must be fully opaque; '
            'pixel ($x,$y) has alpha $candidateAlpha.',
          );
        }
        final redDelta = (referencePixel.r - candidatePixel.r).abs().toInt();
        final greenDelta = (referencePixel.g - candidatePixel.g).abs().toInt();
        final blueDelta = (referencePixel.b - candidatePixel.b).abs().toInt();
        final maximumDelta = _maximum(redDelta, greenDelta, blueDelta);
        final isAudited = !masks.contains(x, y);
        if (isAudited) {
          rowAudited++;
          if (maximumDelta > _staticPixelChannelTolerance) rowDifferences++;
        }
        final prefixIndex = (y + 1) * stride + x + 1;
        differencePrefix[prefixIndex] =
            differencePrefix[y * stride + x + 1] + rowDifferences;
        auditedPrefix[prefixIndex] =
            auditedPrefix[y * stride + x + 1] + rowAudited;

        if (createArtifacts) {
          overlay!.setPixelRgba(
            x,
            y,
            (referencePixel.r.toInt() + candidatePixel.r.toInt()) ~/ 2,
            (referencePixel.g.toInt() + candidatePixel.g.toInt()) ~/ 2,
            (referencePixel.b.toInt() + candidatePixel.b.toInt()) ~/ 2,
            255,
          );
          if (isAudited) {
            heatmap!.setPixelRgba(x, y, maximumDelta, 0, 0, 255);
          } else {
            heatmap!.setPixelRgba(x, y, 0, 0, 0, 0);
          }
        }
      }
    }
    return _StaticPixelAudit(
      width: width,
      differencePrefix: differencePrefix,
      auditedPrefix: auditedPrefix,
      overlay: overlay,
      heatmap: heatmap,
    );
  }

  final int width;
  final Uint32List differencePrefix;
  final Uint32List auditedPrefix;
  final image.Image? overlay;
  final image.Image? heatmap;

  _StaticRegionResult resultFor(ReferencePixelRect rect) {
    final stride = width + 1;
    int sum(Uint32List values) =>
        values[rect.bottom * stride + rect.right] -
        values[rect.top * stride + rect.right] -
        values[rect.bottom * stride + rect.left] +
        values[rect.top * stride + rect.left];
    final differing = sum(differencePrefix);
    final audited = sum(auditedPrefix);
    return _StaticRegionResult(
      differingPixelCount: differing,
      auditedPixelCount: audited,
    );
  }
}

class _StaticRegionResult {
  const _StaticRegionResult({
    required this.differingPixelCount,
    required this.auditedPixelCount,
  });

  final int differingPixelCount;
  final int auditedPixelCount;

  double get differingPixelRatio =>
      auditedPixelCount == 0 ? 1 : differingPixelCount / auditedPixelCount;
}

class _MaskMap {
  _MaskMap({
    required this.width,
    required this.height,
    required List<ReferenceDynamicMask> masks,
  }) : _masked = Uint8List(width * height) {
    for (final mask in masks) {
      for (var y = mask.rect.top; y < mask.rect.bottom; y++) {
        for (var x = mask.rect.left; x < mask.rect.right; x++) {
          _masked[y * width + x] = 1;
        }
      }
    }
  }

  final int width;
  final int height;
  final Uint8List _masked;

  bool contains(int x, int y) => _masked[y * width + x] == 1;
}

class _TextSample {
  const _TextSample(this.bounds, this.semanticInk, this.opticalInkArea);

  final _InkBounds bounds;
  final _MeasuredInk semanticInk;
  final double opticalInkArea;

  double inkDensityDeltaPercent(_TextSample other) {
    if (opticalInkArea == 0) {
      return other.opticalInkArea == 0 ? 0 : double.infinity;
    }
    return ((opticalInkArea - other.opticalInkArea).abs() / opticalInkArea) *
        100;
  }

  double inkDensityRatio(_TextSample other) => opticalInkArea == 0
      ? double.infinity
      : other.opticalInkArea / opticalInkArea;
}

class _InkPixel {
  const _InkPixel(this.x, this.y, this.red, this.green, this.blue);

  final int x;
  final int y;
  final int red;
  final int green;
  final int blue;

  int distanceFrom(ReferenceInk ink) => _maximum(
    (red - ink.red).abs(),
    (green - ink.green).abs(),
    (blue - ink.blue).abs(),
  );

  int distanceFromMeasured(_MeasuredInk ink) => _maximum(
    (red - ink.red).abs(),
    (green - ink.green).abs(),
    (blue - ink.blue).abs(),
  );
}

int _maximum(int first, int second, int third) {
  var result = first;
  if (second > result) result = second;
  if (third > result) result = third;
  return result;
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

  int edgeDelta(_InkBounds other) => _maximum(
    (left - other.left).abs(),
    (top - other.top).abs(),
    _maximum((right - other.right).abs(), (bottom - other.bottom).abs(), 0),
  );

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

  int edgeDelta(_MeasuredInk other) => _maximum(
    (red - other.red).abs(),
    (green - other.green).abs(),
    (blue - other.blue).abs(),
  );

  @override
  String toString() => 'rgb($red,$green,$blue)';
}

class _CsvReport {
  _CsvReport() {
    _buffer.writeln(
      'recordType,candidateRenderer,case,regionType,region,referenceBounds,'
      'candidateBounds,edgeDelta,manifestInkHint,measuredReferenceInk,'
      'candidateInk,semanticInkDelta,inkDensityDeltaPercent,candidateInkRatio,'
      'differingPixelCount,auditedPixelCount,differingPixelRatio,status,details',
    );
  }

  final StringBuffer _buffer = StringBuffer();

  String get contents => _buffer.toString();

  void add({
    required String recordType,
    required String renderer,
    required String caseId,
    required String regionType,
    required String regionName,
    String referenceBounds = '',
    String candidateBounds = '',
    String edgeDelta = '',
    String manifestInkHint = '',
    String measuredReferenceInk = '',
    String candidateInk = '',
    String semanticInkDelta = '',
    String inkDensityDeltaPercent = '',
    String candidateInkRatio = '',
    String differingPixelCount = '',
    String auditedPixelCount = '',
    String differingPixelRatio = '',
    required String status,
    String details = '',
  }) {
    _buffer.writeln(
      <String>[
        recordType,
        renderer,
        caseId,
        regionType,
        regionName,
        referenceBounds,
        candidateBounds,
        edgeDelta,
        manifestInkHint,
        measuredReferenceInk,
        candidateInk,
        semanticInkDelta,
        inkDensityDeltaPercent,
        candidateInkRatio,
        differingPixelCount,
        auditedPixelCount,
        differingPixelRatio,
        status,
        details,
      ].map(_csvCell).join(','),
    );
  }
}

String _csvCell(String value) {
  if (!value.contains(',') &&
      !value.contains('"') &&
      !value.contains('\n') &&
      !value.contains('\r')) {
    return value;
  }
  return '"${value.replaceAll('"', '""')}"';
}

enum _CandidateRenderer { deterministic, android }

class _ComparisonConfiguration {
  const _ComparisonConfiguration({
    required this.candidateDirectory,
    required this.renderer,
    this.outputDirectory,
  });

  factory _ComparisonConfiguration.parse(List<String> args) {
    var candidateDirectory = 'test/goldens/tab-typography';
    var renderer = _CandidateRenderer.deterministic;
    String? outputDirectory;
    final seen = <String>{};
    for (var index = 0; index < args.length; index++) {
      final flag = args[index];
      if (!const {
        '--candidate-dir',
        '--candidate-renderer',
        '--output-dir',
      }.contains(flag)) {
        throw _UsageError('Unknown argument: $flag');
      }
      if (!seen.add(flag)) {
        throw _UsageError('Argument may only be supplied once: $flag');
      }
      if (index + 1 >= args.length) {
        throw _UsageError('Missing value for $flag.');
      }
      final value = args[++index];
      if (value.isEmpty || value.startsWith('--')) {
        throw _UsageError('Missing value for $flag.');
      }
      switch (flag) {
        case '--candidate-dir':
          candidateDirectory = value;
        case '--candidate-renderer':
          renderer = switch (value) {
            'deterministic' => _CandidateRenderer.deterministic,
            'android' => _CandidateRenderer.android,
            _ => throw _UsageError(
              'Unsupported candidate renderer "$value"; expected '
              'deterministic or android.',
            ),
          };
        case '--output-dir':
          outputDirectory = value;
      }
    }
    return _ComparisonConfiguration(
      candidateDirectory: candidateDirectory,
      renderer: renderer,
      outputDirectory: outputDirectory,
    );
  }

  static const usage =
      'Usage: dart run tool/compare_tab_typography.dart '
      '[--candidate-dir <directory>] '
      '[--candidate-renderer deterministic|android] '
      '[--output-dir <directory>]';

  final String candidateDirectory;
  final _CandidateRenderer renderer;
  final String? outputDirectory;
}

class _ComparisonInputError implements Exception {
  const _ComparisonInputError(this.message);

  final String message;
}

class _UsageError implements Exception {
  const _UsageError(this.message);

  final String message;
}
