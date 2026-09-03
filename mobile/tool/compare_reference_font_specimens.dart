import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const _primaryRenderer = 'ios';
const _forensicRenderer = 'host-coretext-forensic';
const _shaPattern = r'^[0-9a-f]{64}$';
const _directGuardPolicy = 'directGuard';
const _trailingBeforeScrollbarPolicy = 'trailingBeforeScrollbar';
const _leadingBeforeArrowJpegNoisePolicy = 'leadingBeforeArrowJpegNoise';
const _trailingBeforeAdjacentColoredTextJpegNoisePolicy =
    'trailingBeforeAdjacentColoredTextJpegNoise';
const _lockedTradeReferenceSha256 =
    '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc';
const _exactCoverageStrings = <String>[
  'Giá  Biểu đồ  Giao dịch  Lịch sử  Cài đặt',
  'Số dư:  Vốn:  Tiền ký quỹ:  Mức ký quỹ (%):',
  'XAUUSD buy 1',
  '4637.05 → 4640.81',
  '376.00  -341.00  103 310.00  203.24',
  'L:  H:  M1  Orders  Deals',
];

class _ReviewedTrailingScrollbarContract {
  const _ReviewedTrailingScrollbarContract({
    required this.roleId,
    required this.text,
    required this.pointSize,
    required this.sourceNominalWeight,
    required this.physicalWidth,
    required this.physicalHeight,
    required this.baseline,
    required this.anchor,
    required this.letterSpacing,
    required this.sourceLeft,
    required this.sourceTop,
    required this.sourceWidth,
    required this.paddingLeft,
    required this.paddingRight,
  });

  final String roleId;
  final String text;
  final double pointSize;
  final int sourceNominalWeight;
  final int physicalWidth;
  final int physicalHeight;
  final double baseline;
  final double anchor;
  final double letterSpacing;
  final int sourceLeft;
  final int sourceTop;
  final int sourceWidth;
  final int paddingLeft;
  final int paddingRight;
}

const _reviewedTrailingScrollbarContracts =
    <String, _ReviewedTrailingScrollbarContract>{
      'trade-profit-positive': _ReviewedTrailingScrollbarContract(
        roleId: 'tradePositionProfit',
        text: '376.00',
        pointSize: 21,
        sourceNominalWeight: 550,
        physicalWidth: 115,
        physicalHeight: 46,
        baseline: 34,
        anchor: 107,
        letterSpacing: .17,
        sourceLeft: 475,
        sourceTop: 375,
        sourceWidth: 107,
        paddingLeft: 0,
        paddingRight: 8,
      ),
      'trade-profit-negative': _ReviewedTrailingScrollbarContract(
        roleId: 'tradePositionProfit',
        text: '-341.00',
        pointSize: 21,
        sourceNominalWeight: 550,
        physicalWidth: 136,
        physicalHeight: 42,
        baseline: 30,
        anchor: 123,
        letterSpacing: .17,
        sourceLeft: 467,
        sourceTop: 857,
        sourceWidth: 115,
        paddingLeft: 8,
        paddingRight: 13,
      ),
      'trade-balance-value': _ReviewedTrailingScrollbarContract(
        roleId: 'tradeMetricValue',
        text: '103 310.00',
        pointSize: 16,
        sourceNominalWeight: 450,
        physicalWidth: 140,
        physicalHeight: 40,
        baseline: 29,
        anchor: 134,
        letterSpacing: .2,
        sourceLeft: 448,
        sourceTop: 156,
        sourceWidth: 134,
        paddingLeft: 0,
        paddingRight: 6,
      ),
      'trade-margin-level-value': _ReviewedTrailingScrollbarContract(
        roleId: 'tradeMetricValue',
        text: '203.24',
        pointSize: 16,
        sourceNominalWeight: 450,
        physicalWidth: 96,
        physicalHeight: 37,
        baseline: 23,
        anchor: 90,
        letterSpacing: .2,
        sourceLeft: 492,
        sourceTop: 291,
        sourceWidth: 90,
        paddingLeft: 0,
        paddingRight: 6,
      ),
    };

void main(List<String> arguments) {
  try {
    final configuration = _Configuration.parse(arguments);
    _run(configuration);
  } on _UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_Configuration.usage);
    exitCode = 64;
  } on _ValidationException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Filesystem error: ${error.message}');
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln('Invalid candidate manifest: ${error.message}');
    exitCode = 1;
  }
}

void _run(_Configuration configuration) {
  final candidateDirectory = Directory(
    configuration.candidateDirectory,
  ).absolute;
  final outputDirectory = Directory(configuration.outputDirectory).absolute;
  if (!candidateDirectory.existsSync()) {
    throw _ValidationException(
      'Candidate directory does not exist: ${candidateDirectory.path}',
    );
  }
  if (outputDirectory.existsSync() || File(outputDirectory.path).existsSync()) {
    throw _ValidationException(
      'Output path already exists; review outputs are immutable: '
      '${outputDirectory.path}',
    );
  }
  final candidateRoot = candidateDirectory.resolveSymbolicLinksSync();
  final outputPath = _resolveProspectivePath(outputDirectory.path);
  if (_isWithin(outputPath, candidateRoot)) {
    throw _ValidationException(
      'Output directory must not be inside the read-only candidate directory.',
    );
  }
  if (configuration.rendererId == _forensicRenderer &&
      !configuration.diagnosticOnly) {
    throw _ValidationException(
      'Renderer $_forensicRenderer requires explicit --diagnostic-only; '
      'host output cannot claim a primary iOS winner.',
    );
  }
  if (configuration.rendererId == _primaryRenderer &&
      configuration.diagnosticOnly) {
    throw _ValidationException(
      'Renderer $_primaryRenderer is the primary profile and does not accept '
      '--diagnostic-only.',
    );
  }

  final manifestFile = _findManifest(candidateDirectory);
  final rawManifest = jsonDecode(manifestFile.readAsStringSync());
  if (rawManifest is! Map<String, dynamic>) {
    throw const FormatException('top level must be an object');
  }
  final manifest = _CandidateManifest.parse(rawManifest);
  if (manifest.rendererId != configuration.rendererId) {
    throw _ValidationException(
      'Renderer id mismatch: CLI requested ${configuration.rendererId}, '
      'manifest records ${manifest.rendererId}.',
    );
  }
  if (manifest.diagnosticOnly != configuration.diagnosticOnly) {
    throw _ValidationException(
      'Diagnostic-mode mismatch between CLI and candidate manifest.',
    );
  }

  final validated = <_ValidatedSpecimen>[];
  for (final specimen in manifest.specimens) {
    if (specimen.rendererId != manifest.rendererId) {
      throw _ValidationException(
        'Specimen ${specimen.id} renderer id ${specimen.rendererId} does not '
        'match manifest renderer ${manifest.rendererId}.',
      );
    }
    final candidateFile = _resolveInputFile(
      candidateDirectory: candidateDirectory,
      candidateRoot: candidateRoot,
      relativePath: specimen.file,
      label: 'candidate ${specimen.id}',
    );
    _verifySha(candidateFile, specimen.sha256, 'candidate ${specimen.id}');
    final decodedCandidate = _decode(candidateFile, 'candidate ${specimen.id}');
    _requireOpaque(decodedCandidate, 'candidate ${specimen.id}');
    _requireGrayscale(decodedCandidate, 'candidate ${specimen.id}');
    if (specimen.scored &&
        (decodedCandidate.width != specimen.physicalWidth ||
            decodedCandidate.height != specimen.physicalHeight)) {
      throw _ValidationException(
        'Candidate canvas dimensions for specimen ${specimen.id} are '
        '${decodedCandidate.width}x${decodedCandidate.height}; contract is '
        '${specimen.physicalWidth}x${specimen.physicalHeight}.',
      );
    }
    final candidateImage = specimen.candidateCrop == null
        ? decodedCandidate
        : _cropImage(
            decodedCandidate,
            specimen.candidateCrop!,
            'candidate ${specimen.id}',
          );
    if (specimen.scored) {
      _requireUnclippedRoleRun(candidateImage, specimen.id);
    }

    File? referenceFile;
    image.Image? referenceImage;
    if (specimen.referenceFile != null) {
      referenceFile = _resolveInputFile(
        candidateDirectory: candidateDirectory,
        candidateRoot: candidateRoot,
        relativePath: specimen.referenceFile!,
        label: 'reference ${specimen.id}',
      );
      _verifySha(
        referenceFile,
        specimen.referenceSha256!,
        'reference ${specimen.id}',
      );
      final decodedReference = _decode(
        referenceFile,
        'reference ${specimen.id}',
      );
      referenceImage = specimen.referenceCrop == null
          ? decodedReference
          : _cropImage(
              decodedReference,
              specimen.referenceCrop!,
              'reference ${specimen.id}',
            );
      if (referenceImage.width != candidateImage.width ||
          referenceImage.height != candidateImage.height) {
        throw _ValidationException(
          'Image dimensions differ for specimen ${specimen.id}: reference '
          '${referenceImage.width}x${referenceImage.height}, candidate '
          '${candidateImage.width}x${candidateImage.height}.',
        );
      }
    }
    if (specimen.scored) {
      _verifyReferenceProvenance(
        specimen: specimen,
        candidateDirectory: candidateDirectory,
        candidateRoot: candidateRoot,
        referenceFile: referenceFile!,
      );
    }
    validated.add(
      _ValidatedSpecimen(
        specimen: specimen,
        candidateImage: candidateImage,
        referenceImage: referenceImage,
      ),
    );
  }

  final verifiedCoverage = <Map<String, Object?>>[];
  for (final coverage in manifest.coverageSpecimens) {
    final coverageFile = _resolveInputFile(
      candidateDirectory: candidateDirectory,
      candidateRoot: candidateRoot,
      relativePath: coverage.file,
      label: 'coverage ${coverage.id}',
    );
    _verifySha(coverageFile, coverage.sha256, 'coverage ${coverage.id}');
    final decoded = _decode(coverageFile, 'coverage ${coverage.id}');
    _requireOpaque(decoded, 'coverage ${coverage.id}');
    _requireGrayscale(decoded, 'coverage ${coverage.id}');
    if (decoded.width != coverage.physicalWidth ||
        decoded.height != coverage.physicalHeight) {
      throw _ValidationException(
        'Coverage canvas dimensions for ${coverage.id} are '
        '${decoded.width}x${decoded.height}; contract is '
        '${coverage.physicalWidth}x${coverage.physicalHeight}.',
      );
    }
    verifiedCoverage.add(<String, Object?>{
      ...coverage.json,
      'verifiedRaster': const <String, bool>{'opaque': true, 'grayscale': true},
    });
  }

  if (configuration.rendererId == _primaryRenderer) {
    final unscored = <String>[
      for (final value in validated)
        if (!value.specimen.scored || value.referenceImage == null)
          value.specimen.id,
    ];
    if (unscored.isNotEmpty) {
      throw _ValidationException(
        'Primary iOS scoring requires a source-hashed reference association '
        '(referenceFile plus referenceSha256) for every specimen; missing: '
        '${unscored.join(', ')}.',
      );
    }
  }

  validated.sort(
    (left, right) => left.specimen.id.compareTo(right.specimen.id),
  );
  final rendered = <_RenderedMeasurement>[
    for (final specimen in validated) _measure(specimen),
  ];
  final proposals = configuration.diagnosticOnly
      ? const <Map<String, Object?>>[]
      : _proposeWinners(rendered);
  final rankings = _diagnosticRankings(rendered);
  final report = <String, Object?>{
    'schemaVersion': 1,
    'rendererId': manifest.rendererId,
    'diagnosticOnly': configuration.diagnosticOnly,
    'hostWinnerClaimsProhibited': configuration.rendererId == _forensicRenderer,
    'parameterPolicy': manifest.parameterPolicy,
    if (manifest.rasterContract != null)
      'rasterContract': manifest.rasterContract,
    'referenceRoleManifestSha256': manifest.referenceRoleManifestSha256,
    'claimLimit': configuration.rendererId == _forensicRenderer
        ? 'Host CoreText evidence is diagnostic only and cannot select or claim a primary iOS winner.'
        : 'Scores are proposals for human review only; this tool does not select canonical role winners.',
    'inputManifest': manifestFile.uri.pathSegments.last,
    'inputManifestSha256': _fileSha(manifestFile),
    'fontSha256Values': manifest.fontSha256Values.toList()..sort(),
    'measurements': <Map<String, Object?>>[
      for (final measurement in rendered) measurement.json,
    ],
    'coverageEvidence': verifiedCoverage,
    'proposedWinners': proposals,
    'diagnosticRankings': rankings,
    'mutationPolicy': <String, Object?>{
      'candidateInputsReadOnly': true,
      'roleColorFontAndProductFilesMutated': false,
      'outputDirectoryWasAbsent': true,
    },
  };

  _writeAtomically(outputDirectory, rendered, report);
  stdout.writeln(
    'Wrote ${rendered.length} specimen measurements to '
    '${outputDirectory.path}.',
  );
  if (configuration.rendererId == _forensicRenderer) {
    stdout.writeln(
      'Diagnostic only: no host-rendered result is eligible for a winner claim.',
    );
  }
}

String _resolveProspectivePath(String path) {
  var cursor = Directory(path).absolute.path;
  final missingSegments = <String>[];
  while (!Directory(cursor).existsSync() &&
      !File(cursor).existsSync() &&
      !Link(cursor).existsSync()) {
    final parent = FileSystemEntity.parentOf(cursor);
    if (parent == cursor) {
      throw _ValidationException('Unable to resolve output path: $path');
    }
    final separatorOffset = parent.endsWith(Platform.pathSeparator) ? 0 : 1;
    missingSegments.insert(
      0,
      cursor.substring(parent.length + separatorOffset),
    );
    cursor = parent;
  }
  final resolvedAncestor = Directory(cursor).resolveSymbolicLinksSync();
  return missingSegments.fold<String>(
    resolvedAncestor,
    (value, segment) => '$value${Platform.pathSeparator}$segment',
  );
}

File _findManifest(Directory candidateDirectory) {
  final preferred = <String>[
    'manifest.json',
    'candidate-manifest.json',
    'specimen-manifest.json',
  ];
  final found = <File>[
    for (final name in preferred)
      if (File('${candidateDirectory.path}/$name').existsSync())
        File('${candidateDirectory.path}/$name'),
  ];
  if (found.isEmpty) {
    throw _ValidationException(
      'Candidate directory has no supported manifest (${preferred.join(', ')}).',
    );
  }
  if (found.length != 1) {
    throw _ValidationException(
      'Candidate directory has ambiguous manifests: '
      '${found.map((file) => file.uri.pathSegments.last).join(', ')}.',
    );
  }
  return found.single;
}

File _resolveInputFile({
  required Directory candidateDirectory,
  required String candidateRoot,
  required String relativePath,
  required String label,
}) {
  if (relativePath.isEmpty ||
      relativePath.startsWith('/') ||
      relativePath.startsWith('\\') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(relativePath) ||
      relativePath.split(RegExp(r'[/\\]+')).contains('..')) {
    throw _ValidationException(
      'Unsafe relative path for $label: $relativePath',
    );
  }
  final file = File('${candidateDirectory.path}/$relativePath');
  if (!file.existsSync()) {
    throw _ValidationException('Missing file for $label: $relativePath');
  }
  final resolved = file.resolveSymbolicLinksSync();
  if (!_isWithin(resolved, candidateRoot)) {
    throw _ValidationException(
      'Resolved path for $label leaves the candidate directory: $relativePath',
    );
  }
  return file;
}

bool _isWithin(String child, String parent) {
  final separator = Platform.pathSeparator;
  final normalizedParent = parent.endsWith(separator)
      ? parent.substring(0, parent.length - 1)
      : parent;
  return child == normalizedParent ||
      child.startsWith('$normalizedParent$separator');
}

void _verifySha(File file, String expected, String label) {
  final actual = _fileSha(file);
  if (actual != expected) {
    throw _ValidationException(
      'SHA-256 mismatch for $label: expected $expected, found $actual.',
    );
  }
}

String _fileSha(File file) => sha256.convert(file.readAsBytesSync()).toString();

image.Image _decode(File file, String label) {
  final decoded = image.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    throw _ValidationException('Unable to decode image for $label.');
  }
  return decoded;
}

image.Image _cropImage(image.Image source, _CropRect crop, String label) {
  if (crop.left < 0 ||
      crop.top < 0 ||
      crop.width <= 0 ||
      crop.height <= 0 ||
      crop.left + crop.width > source.width ||
      crop.top + crop.height > source.height) {
    throw _ValidationException(
      'Crop for $label is outside ${source.width}x${source.height}: ${crop.json}.',
    );
  }
  return image.copyCrop(
    source,
    x: crop.left,
    y: crop.top,
    width: crop.width,
    height: crop.height,
  );
}

void _requireOpaque(image.Image value, String label) {
  for (final pixel in value) {
    if (pixel.a.toInt() != 255) {
      throw _ValidationException('$label is not fully opaque.');
    }
  }
}

void _requireGrayscale(image.Image value, String label) {
  for (final pixel in value) {
    if (pixel.r.toInt() != pixel.g.toInt() ||
        pixel.g.toInt() != pixel.b.toInt()) {
      throw _ValidationException(
        '$label must be grayscale-only; colored debug guides are forbidden.',
      );
    }
  }
}

void _requireUnclippedRoleRun(image.Image value, String id) {
  final support = _Support.fromImage(value, jpegAware: false);
  final bounds = support.bounds;
  if (bounds == null) {
    throw _ValidationException('Scored specimen $id has no nonblank support.');
  }
  if (bounds.minX == 0 ||
      bounds.minY == 0 ||
      bounds.maxX == value.width - 1 ||
      bounds.maxY == value.height - 1) {
    throw _ValidationException(
      'Scored specimen $id nonblank support touches a crop edge; '
      'top clipping and edge clipping are forbidden.',
    );
  }
}

void _verifyReferenceProvenance({
  required _CandidateSpecimen specimen,
  required Directory candidateDirectory,
  required String candidateRoot,
  required File referenceFile,
}) {
  final sourceFile = _resolveInputFile(
    candidateDirectory: candidateDirectory,
    candidateRoot: candidateRoot,
    relativePath: specimen.sourceFile!,
    label: 'raw source ${specimen.id}',
  );
  _verifySha(sourceFile, specimen.sourceSha256!, 'raw source ${specimen.id}');
  final sourceImage = _decode(sourceFile, 'raw source ${specimen.id}');
  final sourceCrop = _cropImage(
    sourceImage,
    specimen.sourceCrop!,
    'raw source ${specimen.id}',
  );
  final transform = specimen.referenceTransform;
  if (transform == null) return;

  var allowReviewedRightSeam = false;
  if (transform.boundaryPolicy == _leadingBeforeArrowJpegNoisePolicy) {
    _verifyLeadingArrowBlankGuard(sourceImage, transform, specimen.id);
    allowReviewedRightSeam = true;
  } else if (transform.boundaryPolicy == _trailingBeforeScrollbarPolicy) {
    _verifyTrailingScrollbarBoundary(sourceImage, specimen, transform);
    allowReviewedRightSeam = true;
  } else if (transform.boundaryPolicy ==
      _trailingBeforeAdjacentColoredTextJpegNoisePolicy) {
    _verifyTradeSymbolAdjacentTextBoundary(sourceImage, specimen, transform);
    allowReviewedRightSeam = true;
  }

  _requireBlankPaddingSeams(
    sourceCrop,
    transform,
    specimen.id,
    jpegAware: specimen.isJpegCrop,
    allowReviewedRightSeam: allowReviewedRightSeam,
  );
  final derived = image.Image(
    width: sourceCrop.width + transform.padding.left + transform.padding.right,
    height:
        sourceCrop.height + transform.padding.top + transform.padding.bottom,
    numChannels: 4,
  );
  image.fill(derived, color: image.ColorRgba8(255, 255, 255, 255));
  image.compositeImage(
    derived,
    sourceCrop,
    dstX: transform.padding.left,
    dstY: transform.padding.top,
    blend: image.BlendMode.direct,
  );
  final retained = _decode(referenceFile, 'derived reference ${specimen.id}');
  final pixelDelta = _pixelDelta(derived, retained);
  final hostJpegDecoderEquivalent =
      specimen.rendererId == _forensicRenderer && specimen.isJpegCrop;
  final transformMatches = hostJpegDecoderEquivalent
      ? pixelDelta.maximum <= 96 && pixelDelta.mean <= 4
      : pixelDelta.maximum == 0;
  if (!transformMatches) {
    throw _ValidationException(
      'Derived reference for specimen ${specimen.id} does not match the '
      'declared white-padding transform (maximum channel delta '
      '${pixelDelta.maximum}, mean channel delta '
      '${pixelDelta.mean.toStringAsFixed(6)}).',
    );
  }
}

void _verifyTradeSymbolAdjacentTextBoundary(
  image.Image source,
  _CandidateSpecimen specimen,
  _ReferenceTransform transform,
) {
  final crop = transform.sourceCrop;
  if (source.width <= 87 || crop.top + crop.height > source.height) {
    throw _ValidationException(
      'Specimen ${specimen.id} adjacent-text boundary is outside the retained '
      'raw source.',
    );
  }

  bool inkAt(int x, int y, int threshold) {
    final pixel = source.getPixel(x, y);
    return math.min(
          pixel.r.toInt(),
          math.min(pixel.g.toInt(), pixel.b.toInt()),
        ) <
        threshold;
  }

  var strongInkAtLastGlyphColumn = false;
  var strongInkInGuard = false;
  var strongInkInExcludedNeighbor = false;
  for (var y = crop.top; y < crop.top + crop.height; y++) {
    strongInkAtLastGlyphColumn |= inkAt(80, y, 160);
    strongInkInGuard |= inkAt(81, y, 160);
    strongInkInExcludedNeighbor |= inkAt(87, y, 160);
  }
  if (!strongInkAtLastGlyphColumn || strongInkInGuard) {
    throw _ValidationException(
      'Specimen ${specimen.id} source x80 must retain strong symbol ink and '
      'source x81 must have no strong ink.',
    );
  }
  if (!strongInkInExcludedNeighbor) {
    throw _ValidationException(
      'Specimen ${specimen.id} excluded tradePositionSideVolume neighbour '
      'must begin at x82 with strong source evidence at x87.',
    );
  }
  if (specimen.sourceSha256 != _lockedTradeReferenceSha256) {
    throw _ValidationException(
      'Specimen ${specimen.id} adjacent-text boundary requires the exact '
      'locked trade source SHA-256.',
    );
  }
}

void _verifyTrailingScrollbarBoundary(
  image.Image source,
  _CandidateSpecimen specimen,
  _ReferenceTransform transform,
) {
  final crop = transform.sourceCrop;
  const boundaryX = 582;
  const finalIncludedX = boundaryX - 1;
  if (source.width <= boundaryX || crop.top + crop.height > source.height) {
    throw _ValidationException(
      'Specimen ${specimen.id} trailing scrollbar boundary is outside the '
      'retained raw source.',
    );
  }

  bool isStrongInkAt(int x, int y) {
    final pixel = source.getPixel(x, y);
    return math.min(
          pixel.r.toInt(),
          math.min(pixel.g.toInt(), pixel.b.toInt()),
        ) <
        160;
  }

  bool isSourceInkAt(int x, int y) {
    final pixel = source.getPixel(x, y);
    return math.min(
          pixel.r.toInt(),
          math.min(pixel.g.toInt(), pixel.b.toInt()),
        ) <
        190;
  }

  var finalIncludedColumnHasStrongInk = false;
  var excludedNeighborHasSourceInk = false;
  for (var y = crop.top; y < crop.top + crop.height; y++) {
    finalIncludedColumnHasStrongInk |= isStrongInkAt(finalIncludedX, y);
    excludedNeighborHasSourceInk |= isSourceInkAt(boundaryX, y);
  }
  if (finalIncludedColumnHasStrongInk) {
    throw _ValidationException(
      'Specimen ${specimen.id} source x581 must be blank under the reviewed '
      'strong-ink predicate.',
    );
  }
  if (!excludedNeighborHasSourceInk) {
    throw _ValidationException(
      'Specimen ${specimen.id} scrollbar/neighbour support must begin at '
      'excluded source x582.',
    );
  }
  if (specimen.sourceSha256 != _lockedTradeReferenceSha256) {
    throw _ValidationException(
      'Specimen ${specimen.id} trailingBeforeScrollbar requires the exact '
      'locked trade source SHA-256.',
    );
  }
}

void _verifyLeadingArrowBlankGuard(
  image.Image source,
  _ReferenceTransform transform,
  String id,
) {
  final crop = transform.sourceCrop;
  final lastStrongInkX = transform.lastStrongInkX!;
  final blankStartX = transform.blankGuardStartX!;
  final blankEndX = blankStartX + transform.blankGuardWidth!;
  bool strongInkAt(int x, int y) {
    final pixel = source.getPixel(x, y);
    return math.min(
          pixel.r.toInt(),
          math.min(pixel.g.toInt(), pixel.b.toInt()),
        ) <
        190;
  }

  var lastColumnHasStrongInk = false;
  var guardHasStrongInk = false;
  for (var y = crop.top; y < crop.top + crop.height; y++) {
    lastColumnHasStrongInk |= strongInkAt(lastStrongInkX, y);
    for (var x = blankStartX; x < blankEndX; x++) {
      guardHasStrongInk |= strongInkAt(x, y);
    }
  }
  if (!lastColumnHasStrongInk || guardHasStrongInk) {
    throw _ValidationException(
      'Specimen $id leading-before-arrow blank-guard provenance does not '
      'match the retained raw JPEG source.',
    );
  }
}

void _requireBlankPaddingSeams(
  image.Image sourceCrop,
  _ReferenceTransform transform,
  String id, {
  required bool jpegAware,
  required bool allowReviewedRightSeam,
}) {
  final padding = transform.padding;
  final support = _Support.fromImage(sourceCrop, jpegAware: jpegAware);
  for (final point in support.points) {
    final x = point % sourceCrop.width;
    final y = point ~/ sourceCrop.width;
    final touchesSeam =
        (padding.left > 0 && x == 0) ||
        (padding.top > 0 && y == 0) ||
        (padding.right > 0 &&
            x == sourceCrop.width - 1 &&
            !allowReviewedRightSeam) ||
        (padding.bottom > 0 && y == sourceCrop.height - 1);
    if (touchesSeam) {
      throw _ValidationException(
        'Specimen $id ink touches the raw crop-to-padding seam.',
      );
    }
  }
}

({int maximum, double mean}) _pixelDelta(image.Image left, image.Image right) {
  if (left.width != right.width || left.height != right.height) {
    return (maximum: 255, mean: 255);
  }
  var maximum = 0;
  var total = 0;
  var count = 0;
  for (var y = 0; y < left.height; y++) {
    for (var x = 0; x < left.width; x++) {
      final leftPixel = left.getPixel(x, y);
      final rightPixel = right.getPixel(x, y);
      for (final delta in <int>[
        (leftPixel.r.toInt() - rightPixel.r.toInt()).abs(),
        (leftPixel.g.toInt() - rightPixel.g.toInt()).abs(),
        (leftPixel.b.toInt() - rightPixel.b.toInt()).abs(),
        (leftPixel.a.toInt() - rightPixel.a.toInt()).abs(),
      ]) {
        maximum = math.max(maximum, delta);
        total += delta;
        count++;
      }
    }
  }
  return (maximum: maximum, mean: count == 0 ? 0 : total / count);
}

_RenderedMeasurement _measure(_ValidatedSpecimen value) {
  final specimen = value.specimen;
  final candidateSupport = _Support.fromImage(
    value.candidateImage,
    jpegAware: specimen.isJpegCrop,
  );
  if (value.referenceImage == null) {
    final overlay = _candidateSupportOverlay(
      value.candidateImage,
      candidateSupport,
    );
    return _RenderedMeasurement(
      specimen: specimen,
      overlay: overlay,
      metricPolicy: specimen.isJpegCrop
          ? 'jpeg-aware-whole-run'
          : 'controlled-lossless',
      score: null,
      metrics: <String, Object?>{
        'comparisonAvailable': false,
        'supportPixelCount': candidateSupport.points.length,
        'componentCount': candidateSupport.componentCount,
        'candidateBounds': candidateSupport.bounds?.json,
        'candidateCentroid': candidateSupport.centroid?.json,
        'candidateCoverageMass': _round(candidateSupport.coverageMass),
        'candidateStrokeWidthProxy': _round(candidateSupport.strokeWidthProxy),
      },
    );
  }

  final referenceSupport = _Support.fromImage(
    value.referenceImage!,
    jpegAware: specimen.isJpegCrop,
  );
  final union = referenceSupport.points.union(candidateSupport.points);
  final intersection = referenceSupport.points.intersection(
    candidateSupport.points,
  );
  final symmetricDifference = union.length - intersection.length;
  final iou = union.isEmpty ? 1.0 : intersection.length / union.length;
  final residual = union.isEmpty ? 0.0 : symmetricDifference / union.length;
  final densityDelta = _ratioDelta(
    referenceSupport.coverageMass,
    candidateSupport.coverageMass,
  );
  final extentDelta = _extentDelta(
    referenceSupport.bounds,
    candidateSupport.bounds,
  );
  final baselineDelta =
      ((referenceSupport.bounds?.maxY ?? -1) -
              (candidateSupport.bounds?.maxY ?? -1))
          .abs()
          .toDouble();
  final metrics = <String, Object?>{
    'comparisonAvailable': true,
    'supportIou': _round(iou),
    'symmetricResidualRatio': _round(residual),
    'densityDeltaRatio': _round(densityDelta),
    'extentDeltaPx': _round(extentDelta),
    'baselineProxyDeltaPx': _round(baselineDelta),
    'referenceBounds': referenceSupport.bounds?.json,
    'candidateBounds': candidateSupport.bounds?.json,
  };
  final annotations = specimen.annotations;
  if (annotations != null) {
    final landmarkDeltas = <double>[
      for (final landmark in annotations.landmarks)
        _pointDistance(landmark.reference, landmark.candidate),
    ];
    metrics.addAll(<String, Object?>{
      'annotatedBaselineDeltaPx': _round(
        (annotations.referenceBaselineY - annotations.candidateBaselineY).abs(),
      ),
      'annotatedLandmarkMeanDeltaPx': _round(
        landmarkDeltas.reduce((left, right) => left + right) /
            landmarkDeltas.length,
      ),
      'annotatedLandmarkMaxDeltaPx': _round(landmarkDeltas.reduce(math.max)),
    });
  }
  var score =
      (1 - iou) * 100 +
      residual * 50 +
      densityDelta * 20 +
      extentDelta +
      baselineDelta;
  final policy = specimen.isJpegCrop
      ? 'jpeg-aware-whole-run'
      : 'controlled-lossless';
  if (!specimen.isJpegCrop) {
    final topologyExact =
        referenceSupport.componentCount == candidateSupport.componentCount;
    final centroidDelta = _pointDistance(
      referenceSupport.centroid,
      candidateSupport.centroid,
    );
    final coverageDelta = _ratioDelta(
      referenceSupport.coverageMass,
      candidateSupport.coverageMass,
    );
    final strokeDelta = _ratioDelta(
      referenceSupport.strokeWidthProxy,
      candidateSupport.strokeWidthProxy,
    );
    final advanceDelta =
        ((referenceSupport.bounds?.width ?? 0) -
                (candidateSupport.bounds?.width ?? 0))
            .abs()
            .toDouble();
    metrics.addAll(<String, Object?>{
      'componentTopologyExact': topologyExact,
      'referenceComponentCount': referenceSupport.componentCount,
      'candidateComponentCount': candidateSupport.componentCount,
      'advanceDeltaPx': _round(advanceDelta),
      'advanceMeasurement': 'whole-run-extent-proxy',
      'centroidDeltaPx': _round(centroidDelta),
      'coverageMassDeltaRatio': _round(coverageDelta),
      'strokeWidthDeltaRatio': _round(strokeDelta),
    });
    score += topologyExact ? 0 : 100;
    score +=
        advanceDelta * 2 +
        centroidDelta * 2 +
        coverageDelta * 20 +
        strokeDelta * 20;
  }
  return _RenderedMeasurement(
    specimen: specimen,
    overlay: _comparisonOverlay(
      value.referenceImage!,
      value.candidateImage,
      referenceSupport,
      candidateSupport,
    ),
    metricPolicy: policy,
    score: score,
    metrics: metrics,
  );
}

List<Map<String, Object?>> _proposeWinners(
  List<_RenderedMeasurement> measurements,
) {
  final groups = <String, List<_RenderedMeasurement>>{};
  for (final measurement in measurements) {
    if (measurement.score == null ||
        !measurement.specimen.scored ||
        !measurement.specimen.crossRendererComparable ||
        !measurement.specimen.selectable) {
      continue;
    }
    groups
        .putIfAbsent(
          measurement.specimen.comparisonId,
          () => <_RenderedMeasurement>[],
        )
        .add(measurement);
  }
  final result = <Map<String, Object?>>[];
  for (final entry in groups.entries) {
    entry.value.sort(_compareMeasurements);
    final winner = entry.value.first;
    result.add(<String, Object?>{
      'comparisonId': entry.key,
      'roleId': winner.specimen.roleId,
      'candidateId': winner.specimen.candidateId,
      'candidateSpecimenId': winner.specimen.id,
      'proposedScore': _round(winner.score!),
      'status': 'raster-score-proposal-requires-primary-ios-human-review',
      'parameterLockEligible': false,
      'reviewedWinner': false,
      'requiresPrimaryIosHumanReview': true,
    });
  }
  result.sort(
    (left, right) => (left['comparisonId']! as String).compareTo(
      right['comparisonId']! as String,
    ),
  );
  return result;
}

List<Map<String, Object?>> _diagnosticRankings(
  List<_RenderedMeasurement> measurements,
) {
  final groups = <String, List<_RenderedMeasurement>>{};
  for (final measurement in measurements) {
    groups
        .putIfAbsent(
          measurement.specimen.comparisonId,
          () => <_RenderedMeasurement>[],
        )
        .add(measurement);
  }
  final result = <Map<String, Object?>>[];
  for (final entry in groups.entries) {
    entry.value.sort(_compareMeasurements);
    result.add(<String, Object?>{
      'comparisonId': entry.key,
      'ranking': <Map<String, Object?>>[
        for (var index = 0; index < entry.value.length; index++)
          <String, Object?>{
            'rank': index + 1,
            'candidateId': entry.value[index].specimen.candidateId,
            'specimenId': entry.value[index].specimen.id,
            'score': entry.value[index].score == null
                ? null
                : _round(entry.value[index].score!),
            'winnerEligible': false,
          },
      ],
    });
  }
  result.sort(
    (left, right) => (left['comparisonId']! as String).compareTo(
      right['comparisonId']! as String,
    ),
  );
  return result;
}

int _compareMeasurements(
  _RenderedMeasurement left,
  _RenderedMeasurement right,
) {
  final leftScore = left.score ?? double.infinity;
  final rightScore = right.score ?? double.infinity;
  final scoreOrder = leftScore.compareTo(rightScore);
  if (scoreOrder != 0) return scoreOrder;
  return left.specimen.candidateId.compareTo(right.specimen.candidateId);
}

void _writeAtomically(
  Directory outputDirectory,
  List<_RenderedMeasurement> measurements,
  Map<String, Object?> report,
) {
  final parent = outputDirectory.parent;
  parent.createSync(recursive: true);
  final staging = parent.createTempSync('.reference-font-review-');
  var moved = false;
  try {
    final overlays = Directory('${staging.path}/overlays')..createSync();
    for (final measurement in measurements) {
      final overlayFile = File('${overlays.path}/${measurement.overlayName}')
        ..writeAsBytesSync(measurement.overlayPng, flush: true);
      final actualSha = _fileSha(overlayFile);
      if (actualSha != measurement.overlaySha256) {
        throw _ValidationException(
          'Overlay SHA-256 verification failed for ${measurement.specimen.id}.',
        );
      }
    }
    File('${staging.path}/report.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      flush: true,
    );
    staging.renameSync(outputDirectory.path);
    moved = true;
  } finally {
    if (!moved && staging.existsSync()) {
      staging.deleteSync(recursive: true);
    }
  }
}

image.Image _comparisonOverlay(
  image.Image reference,
  image.Image candidate,
  _Support referenceSupport,
  _Support candidateSupport,
) {
  final output = image.Image(
    width: reference.width,
    height: reference.height,
    numChannels: 4,
  );
  image.fill(output, color: image.ColorRgba8(255, 255, 255, 255));
  for (var y = 0; y < output.height; y++) {
    for (var x = 0; x < output.width; x++) {
      final key = y * output.width + x;
      final inReference = referenceSupport.points.contains(key);
      final inCandidate = candidateSupport.points.contains(key);
      final color = switch ((inReference, inCandidate)) {
        (true, true) => image.ColorRgba8(35, 35, 35, 255),
        (true, false) => image.ColorRgba8(230, 45, 45, 255),
        (false, true) => image.ColorRgba8(30, 95, 235, 255),
        (false, false) => _backgroundBlend(
          reference.getPixel(x, y),
          candidate.getPixel(x, y),
        ),
      };
      output.setPixel(x, y, color);
    }
  }
  return output;
}

image.ColorRgba8 _backgroundBlend(
  image.Pixel reference,
  image.Pixel candidate,
) {
  return image.ColorRgba8(
    ((reference.r.toInt() + candidate.r.toInt()) ~/ 2),
    ((reference.g.toInt() + candidate.g.toInt()) ~/ 2),
    ((reference.b.toInt() + candidate.b.toInt()) ~/ 2),
    255,
  );
}

image.Image _candidateSupportOverlay(image.Image candidate, _Support support) {
  final output = image.Image(
    width: candidate.width,
    height: candidate.height,
    numChannels: 4,
  );
  image.fill(output, color: image.ColorRgba8(255, 255, 255, 255));
  for (var y = 0; y < output.height; y++) {
    for (var x = 0; x < output.width; x++) {
      final pixel = candidate.getPixel(x, y);
      if (support.points.contains(y * output.width + x)) {
        output.setPixel(x, y, image.ColorRgba8(30, 95, 235, 255));
      } else {
        final gray =
            ((pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) ~/ 3);
        output.setPixel(x, y, image.ColorRgba8(gray, gray, gray, 255));
      }
    }
  }
  return output;
}

double _ratioDelta(double reference, double candidate) {
  if (reference == 0) return candidate == 0 ? 0 : 1;
  return (candidate - reference).abs() / reference;
}

double _extentDelta(_Bounds? reference, _Bounds? candidate) {
  if (reference == null || candidate == null) {
    return reference == candidate ? 0 : double.maxFinite;
  }
  return math
      .max(
        (reference.width - candidate.width).abs(),
        (reference.height - candidate.height).abs(),
      )
      .toDouble();
}

double _pointDistance(_Point? reference, _Point? candidate) {
  if (reference == null || candidate == null) {
    return reference == candidate ? 0 : double.maxFinite;
  }
  return math.sqrt(
    math.pow(reference.x - candidate.x, 2) +
        math.pow(reference.y - candidate.y, 2),
  );
}

double _round(double value) => (value * 1000000).round() / 1000000;

class _Support {
  _Support({
    required this.points,
    required this.bounds,
    required this.centroid,
    required this.coverageMass,
    required this.componentCount,
    required this.strokeWidthProxy,
  });

  factory _Support.fromImage(image.Image value, {required bool jpegAware}) {
    final background = _estimateBackground(value);
    final threshold = jpegAware ? 24.0 : 12.0;
    final points = <int>{};
    var mass = 0.0;
    var sumX = 0.0;
    var sumY = 0.0;
    var minX = value.width;
    var minY = value.height;
    var maxX = -1;
    var maxY = -1;
    for (var y = 0; y < value.height; y++) {
      for (var x = 0; x < value.width; x++) {
        final pixel = value.getPixel(x, y);
        final distance = _colorDistance(pixel, background);
        if (distance <= threshold) continue;
        points.add(y * value.width + x);
        final normalized = math.min(1.0, distance / 441.67295593);
        mass += normalized;
        sumX += x * normalized;
        sumY += y * normalized;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
    }
    final bounds = points.isEmpty ? null : _Bounds(minX, minY, maxX, maxY);
    final centroid = mass == 0 ? null : _Point(sumX / mass, sumY / mass);
    return _Support(
      points: points,
      bounds: bounds,
      centroid: centroid,
      coverageMass: mass,
      componentCount: _componentCount(points, value.width, value.height),
      strokeWidthProxy: _strokeWidth(points, value.width, value.height),
    );
  }

  final Set<int> points;
  final _Bounds? bounds;
  final _Point? centroid;
  final double coverageMass;
  final int componentCount;
  final double strokeWidthProxy;
}

({int red, int green, int blue}) _estimateBackground(image.Image value) {
  final samples = <image.Pixel>[
    value.getPixel(0, 0),
    value.getPixel(value.width - 1, 0),
    value.getPixel(0, value.height - 1),
    value.getPixel(value.width - 1, value.height - 1),
  ];
  return (
    red:
        samples.map((pixel) => pixel.r.toInt()).reduce((a, b) => a + b) ~/
        samples.length,
    green:
        samples.map((pixel) => pixel.g.toInt()).reduce((a, b) => a + b) ~/
        samples.length,
    blue:
        samples.map((pixel) => pixel.b.toInt()).reduce((a, b) => a + b) ~/
        samples.length,
  );
}

double _colorDistance(
  image.Pixel pixel,
  ({int red, int green, int blue}) background,
) {
  final red = pixel.r.toInt() - background.red;
  final green = pixel.g.toInt() - background.green;
  final blue = pixel.b.toInt() - background.blue;
  return math.sqrt(red * red + green * green + blue * blue);
}

int _componentCount(Set<int> points, int width, int height) {
  final remaining = <int>{...points};
  var count = 0;
  while (remaining.isNotEmpty) {
    count++;
    final pending = <int>[remaining.first];
    remaining.remove(pending.first);
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      final x = current % width;
      final y = current ~/ width;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nextX = x + dx;
          final nextY = y + dy;
          if (nextX < 0 || nextY < 0 || nextX >= width || nextY >= height) {
            continue;
          }
          final next = nextY * width + nextX;
          if (remaining.remove(next)) pending.add(next);
        }
      }
    }
  }
  return count;
}

double _strokeWidth(Set<int> points, int width, int height) {
  if (points.isEmpty) return 0;
  var runTotal = 0;
  var runCount = 0;
  for (var y = 0; y < height; y++) {
    var run = 0;
    for (var x = 0; x < width; x++) {
      if (points.contains(y * width + x)) {
        run++;
      } else if (run > 0) {
        runTotal += run;
        runCount++;
        run = 0;
      }
    }
    if (run > 0) {
      runTotal += run;
      runCount++;
    }
  }
  return runCount == 0 ? 0 : runTotal / runCount;
}

class _Bounds {
  const _Bounds(this.minX, this.minY, this.maxX, this.maxY);

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;

  Map<String, int> get json => <String, int>{
    'minX': minX,
    'minY': minY,
    'maxX': maxX,
    'maxY': maxY,
    'width': width,
    'height': height,
  };
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;

  Map<String, double> get json => <String, double>{
    'x': _round(x),
    'y': _round(y),
  };
}

class _RenderedMeasurement {
  _RenderedMeasurement({
    required this.specimen,
    required this.overlay,
    required this.metricPolicy,
    required this.score,
    required this.metrics,
  });

  final _CandidateSpecimen specimen;
  final image.Image overlay;
  final String metricPolicy;
  final double? score;
  final Map<String, Object?> metrics;

  String get overlayName => '${_safeName(specimen.id)}.png';
  late final List<int> overlayPng = image.encodePng(overlay);
  late final String overlaySha256 = sha256.convert(overlayPng).toString();

  Map<String, Object?> get json => <String, Object?>{
    'id': specimen.id,
    'comparisonId': specimen.comparisonId,
    'roleId': specimen.roleId,
    'candidateId': specimen.candidateId,
    'sourceClass': specimen.sourceClass,
    'metricPolicy': metricPolicy,
    'score': score == null ? null : _round(score!),
    'selectable': specimen.selectable,
    'scored': specimen.scored,
    'candidateFaceSha256': specimen.faceSha256,
    'rendererId': specimen.rendererId,
    if (specimen.rasterEvidence != null)
      'rasterEvidence': specimen.rasterEvidence,
    'verifiedRaster': const <String, bool>{'opaque': true, 'grayscale': true},
    'parameterEvidence': specimen.parameterEvidence,
    'annotationsUsed': specimen.annotationsJson,
    'referenceProvenance': specimen.referenceProvenanceJson,
    'overlayFile': 'overlays/$overlayName',
    'overlaySha256': overlaySha256,
    'comparisonContract': specimen.comparisonContractJson,
    'metrics': metrics,
  };
}

String _safeName(String value) {
  final result = value.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
  return result.isEmpty ? 'specimen' : result;
}

class _ValidatedSpecimen {
  const _ValidatedSpecimen({
    required this.specimen,
    required this.candidateImage,
    required this.referenceImage,
  });

  final _CandidateSpecimen specimen;
  final image.Image candidateImage;
  final image.Image? referenceImage;
}

class _CandidateManifest {
  _CandidateManifest({
    required this.rendererId,
    required this.diagnosticOnly,
    required this.parameterPolicy,
    required this.rasterContract,
    required this.referenceRoleManifestSha256,
    required this.specimens,
    required this.coverageSpecimens,
    required this.fontSha256Values,
  });

  factory _CandidateManifest.parse(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('schemaVersion must equal 1');
    }
    final rendererId = _requiredString(json, 'rendererId');
    if (rendererId != _primaryRenderer && rendererId != _forensicRenderer) {
      throw FormatException('unsupported rendererId "$rendererId"');
    }
    final diagnosticOnly = json['diagnosticOnly'];
    if (diagnosticOnly is! bool) {
      throw const FormatException('diagnosticOnly must be a boolean');
    }
    final parameterPolicy = _parseParameterPolicy(json['parameterPolicy']);
    final rasterContract = _parseRasterContract(
      json['rasterContract'],
      isRequired: rendererId == _primaryRenderer,
    );
    final referenceRoleManifestSha256 = _requiredSha(
      json,
      'referenceRoleManifestSha256',
    );
    final rawSpecimens = json['specimens'];
    if (rawSpecimens is! List || rawSpecimens.isEmpty) {
      throw const FormatException('specimens must be a non-empty array');
    }
    final specimens = <_CandidateSpecimen>[];
    final ids = <String>{};
    for (final value in rawSpecimens) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('each specimen must be an object');
      }
      final specimen = _CandidateSpecimen.parse(
        value,
        manifestRendererId: rendererId,
        referenceRoleManifestSha256: referenceRoleManifestSha256,
      );
      if (_safeName(specimen.id) != specimen.id) {
        throw FormatException(
          'specimen ${specimen.id} must itself be a safe unique overlay '
          'filename stem using only A-Z, a-z, 0-9, dot, underscore, or dash',
        );
      }
      if (!ids.add(specimen.id)) {
        throw FormatException('duplicate specimen id "${specimen.id}"');
      }
      specimens.add(specimen);
    }
    final rawCoverageSpecimens = json['coverageSpecimens'];
    if (rendererId == _primaryRenderer &&
        (rawCoverageSpecimens is! List || rawCoverageSpecimens.isEmpty)) {
      throw const FormatException(
        'primary iOS manifest requires non-empty coverageSpecimens',
      );
    }
    if (rawCoverageSpecimens != null && rawCoverageSpecimens is! List) {
      throw const FormatException('coverageSpecimens must be an array');
    }
    final coverageSpecimens = <_CoverageSpecimen>[];
    final coverageFiles = <String>{};
    for (final value in rawCoverageSpecimens as List? ?? const <Object?>[]) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('each coverage specimen must be an object');
      }
      final coverage = _CoverageSpecimen.parse(value);
      if (_safeName(coverage.id) != coverage.id) {
        throw FormatException(
          'coverage specimen ${coverage.id} must itself be a safe unique '
          'filename stem using only A-Z, a-z, 0-9, dot, underscore, or dash',
        );
      }
      if (!ids.add(coverage.id)) {
        throw FormatException('duplicate specimen id "${coverage.id}"');
      }
      if (!coverageFiles.add(coverage.file)) {
        throw FormatException(
          'duplicate coverage specimen file "${coverage.file}"',
        );
      }
      coverageSpecimens.add(coverage);
    }
    if (rendererId == _primaryRenderer) {
      final candidateIds = <String>{
        for (final specimen in specimens) specimen.candidateId,
      };
      final coverageCandidateIds = <String>{
        for (final coverage in coverageSpecimens) coverage.candidateId,
      };
      if (coverageCandidateIds.length != coverageSpecimens.length ||
          !_sameStrings(candidateIds, coverageCandidateIds)) {
        throw const FormatException(
          'primary iOS coverageSpecimens must contain exactly one exact-six '
          'sheet for every scored font candidate',
        );
      }
    }
    final contractByComparison = <String, String>{};
    final faceByCandidate = <String, String>{};
    for (final specimen in specimens.where((value) => value.scored)) {
      final contract = specimen.comparisonContractKey!;
      final previousContract = contractByComparison.putIfAbsent(
        specimen.comparisonId,
        () => contract,
      );
      if (previousContract != contract) {
        throw FormatException(
          'comparison contract mismatch for "${specimen.comparisonId}"; '
          'text, point size, crop/canvas dimensions, top-origin baseline, '
          'horizontal layout/anchor, letter spacing, feature contract, DPR, '
          'scale, locale, vector policy, and source association must agree',
        );
      }
    }
    for (final specimen in specimens) {
      final face = specimen.faceSha256;
      if (face == null) continue;
      final previousFace = faceByCandidate.putIfAbsent(
        specimen.candidateId,
        () => face,
      );
      if (previousFace != face) {
        throw FormatException(
          'candidate ${specimen.candidateId} records multiple face SHA-256 '
          'values',
        );
      }
    }
    final fontHashes = <String>{};
    void addHash(Object? value, String label) {
      if (value == null) return;
      if (value is! String || !RegExp(_shaPattern).hasMatch(value)) {
        throw FormatException('$label must be a lowercase SHA-256');
      }
      fontHashes.add(value);
    }

    addHash(json['fontSha256'], 'fontSha256');
    final rawFont = json['font'];
    if (rawFont != null) {
      if (rawFont is! Map<String, dynamic>) {
        throw const FormatException('font must be an object');
      }
      addHash(rawFont['sha256'], 'font.sha256');
      addHash(rawFont['faceSha256'], 'font.faceSha256');
    }
    final rawFonts = json['fonts'];
    if (rawFonts != null) {
      if (rawFonts is! List) {
        throw const FormatException('fonts must be an array');
      }
      for (final value in rawFonts) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('each font must be an object');
        }
        addHash(value['sha256'], 'fonts[].sha256');
        addHash(value['faceSha256'], 'fonts[].faceSha256');
      }
    }
    if (fontHashes.isEmpty) {
      throw const FormatException(
        'at least one verified face SHA-256 must be recorded',
      );
    }
    for (final specimen in specimens.where((value) => value.scored)) {
      if (!fontHashes.contains(specimen.faceSha256)) {
        throw FormatException(
          'specimen ${specimen.id} face SHA-256 is not declared by the '
          'manifest font set',
        );
      }
    }
    for (final coverage in coverageSpecimens) {
      if (!fontHashes.contains(coverage.faceSha256)) {
        throw FormatException(
          'coverage specimen ${coverage.id} face SHA-256 is not declared by '
          'the manifest font set',
        );
      }
      if (faceByCandidate[coverage.candidateId] != coverage.faceSha256) {
        throw FormatException(
          'coverage specimen ${coverage.id} face SHA-256 does not match its '
          'scored candidate ${coverage.candidateId}',
        );
      }
    }
    return _CandidateManifest(
      rendererId: rendererId,
      diagnosticOnly: diagnosticOnly,
      parameterPolicy: parameterPolicy,
      rasterContract: rasterContract,
      referenceRoleManifestSha256: referenceRoleManifestSha256,
      specimens: specimens,
      coverageSpecimens: coverageSpecimens,
      fontSha256Values: fontHashes,
    );
  }

  final String rendererId;
  final bool diagnosticOnly;
  final Map<String, Object?> parameterPolicy;
  final Map<String, Object?>? rasterContract;
  final String referenceRoleManifestSha256;
  final List<_CandidateSpecimen> specimens;
  final List<_CoverageSpecimen> coverageSpecimens;
  final Set<String> fontSha256Values;
}

class _CoverageSpecimen {
  const _CoverageSpecimen({
    required this.id,
    required this.candidateId,
    required this.text,
    required this.strings,
    required this.file,
    required this.sha256,
    required this.physicalWidth,
    required this.physicalHeight,
    required this.faceSha256,
    required this.rasterEvidence,
  });

  factory _CoverageSpecimen.parse(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id');
    final candidateId = _requiredString(json, 'candidateId');
    final text = _requiredString(json, 'text');
    final strings = _orderedStringList(
      json['strings'],
      'coverage specimen $id strings',
    );
    if (strings.length != _exactCoverageStrings.length ||
        !_sameStringsByIndex(strings, _exactCoverageStrings) ||
        text != _exactCoverageStrings.join('\n')) {
      throw FormatException(
        'coverage specimen $id must preserve the exact six controlled strings',
      );
    }
    if (json['scored'] != false) {
      throw FormatException('coverage specimen $id must declare scored=false');
    }
    final physicalWidth = _optionalPositiveInt(json, 'physicalWidth');
    final physicalHeight = _optionalPositiveInt(json, 'physicalHeight');
    final devicePixelRatio = _optionalPositiveNumber(json, 'devicePixelRatio');
    final textScale = _optionalPositiveNumber(json, 'textScale');
    final locale = _optionalString(json, 'locale');
    if (physicalWidth == null ||
        physicalHeight == null ||
        devicePixelRatio != 1.5 ||
        textScale != 1.0 ||
        locale != 'vi-VN') {
      throw FormatException(
        'coverage specimen $id requires a positive physical canvas, DPR 1.5, '
        'text scale 1.0, and locale vi-VN',
      );
    }
    final rawFont = json['font'];
    if (rawFont is! Map<String, dynamic>) {
      throw FormatException('coverage specimen $id font must be an object');
    }
    final faceShaValue = rawFont['faceSha256'] ?? rawFont['sha256'];
    if (faceShaValue is! String ||
        !RegExp(_shaPattern).hasMatch(faceShaValue)) {
      throw FormatException(
        'coverage specimen $id requires an exact candidate face SHA',
      );
    }
    return _CoverageSpecimen(
      id: id,
      candidateId: candidateId,
      text: text,
      strings: strings,
      file: _requiredString(json, 'file'),
      sha256: _requiredSha(json, 'sha256'),
      physicalWidth: physicalWidth,
      physicalHeight: physicalHeight,
      faceSha256: faceShaValue,
      rasterEvidence: _parseRasterEvidence(
        json['rasterEvidence'],
        label: 'coverage specimen $id',
        isRequired: true,
      )!,
    );
  }

  final String id;
  final String candidateId;
  final String text;
  final List<String> strings;
  final String file;
  final String sha256;
  final int physicalWidth;
  final int physicalHeight;
  final String faceSha256;
  final Map<String, Object?> rasterEvidence;

  Map<String, Object?> get json => <String, Object?>{
    'id': id,
    'candidateId': candidateId,
    'text': text,
    'strings': strings,
    'file': file,
    'sha256': sha256,
    'physicalWidth': physicalWidth,
    'physicalHeight': physicalHeight,
    'devicePixelRatio': 1.5,
    'textScale': 1.0,
    'locale': 'vi-VN',
    'candidateFaceSha256': faceSha256,
    'rasterEvidence': rasterEvidence,
  };
}

class _CropRect {
  const _CropRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory _CropRect.fromJson(Map<String, dynamic> json) {
    final left = _requiredInt(json, 'left');
    final top = _requiredInt(json, 'top');
    final width = _requiredInt(json, 'width');
    final height = _requiredInt(json, 'height');
    if (left < 0 || top < 0 || width <= 0 || height <= 0) {
      throw const FormatException(
        'crop coordinates must be nonnegative with positive dimensions',
      );
    }
    return _CropRect(left: left, top: top, width: width, height: height);
  }

  static _CropRect? parseOptional(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('crop metadata must be an object');
    }
    return _CropRect.fromJson(value);
  }

  final int left;
  final int top;
  final int width;
  final int height;

  Map<String, int> get json => <String, int>{
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  bool sameAs(_CropRect other) =>
      left == other.left &&
      top == other.top &&
      width == other.width &&
      height == other.height;
}

class _Padding {
  const _Padding({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory _Padding.fromJson(Map<String, dynamic> json) {
    final result = _Padding(
      left: _requiredInt(json, 'left'),
      top: _requiredInt(json, 'top'),
      right: _requiredInt(json, 'right'),
      bottom: _requiredInt(json, 'bottom'),
    );
    if (result.left < 0 ||
        result.top < 0 ||
        result.right < 0 ||
        result.bottom < 0) {
      throw const FormatException('reference padding must be nonnegative');
    }
    if (result.isZero) {
      throw const FormatException(
        'whitePaddingNoResample requires at least one padded edge',
      );
    }
    return result;
  }

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool get isZero => left == 0 && top == 0 && right == 0 && bottom == 0;

  Map<String, int> get json => <String, int>{
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };
}

class _ReferenceTransform {
  const _ReferenceTransform({
    required this.sourceFile,
    required this.sourceSha256,
    required this.sourceCrop,
    required this.padding,
    required this.boundaryPolicy,
    required this.sourceRightExclusiveBoundaryX,
    required this.coordinateSpace,
    required this.exclusive,
    required this.lastStrongInkX,
    required this.blankGuardStartX,
    required this.blankGuardWidth,
    required this.excludedNeighborStartX,
    required this.excludedNeighborKind,
  });

  factory _ReferenceTransform.fromJson(Map<String, dynamic> json) {
    final kind = _requiredString(json, 'kind');
    if (kind != 'whitePaddingNoResample') {
      throw FormatException('unsupported reference transform "$kind"');
    }
    final rawSourceCrop = json['sourceCrop'];
    final rawPadding = json['padding'];
    if (rawSourceCrop is! Map<String, dynamic> ||
        rawPadding is! Map<String, dynamic>) {
      throw const FormatException(
        'referenceTransform requires sourceCrop and padding objects',
      );
    }
    final boundaryPolicy = _requiredString(json, 'boundaryPolicy');
    int? sourceRightExclusiveBoundaryX;
    String? coordinateSpace;
    bool? exclusive;
    int? lastStrongInkX;
    int? blankGuardStartX;
    int? blankGuardWidth;
    int? excludedNeighborStartX;
    String? excludedNeighborKind;
    switch (boundaryPolicy) {
      case _directGuardPolicy:
        if (json.containsKey('sourceRightExclusiveBoundaryX') ||
            json.containsKey('coordinateSpace') ||
            json.containsKey('exclusive') ||
            json.containsKey('lastStrongInkX') ||
            json.containsKey('blankGuardStartX') ||
            json.containsKey('blankGuardWidth') ||
            json.containsKey('excludedNeighborStartX') ||
            json.containsKey('excludedNeighborKind')) {
          throw const FormatException(
            'directGuard must not declare boundary-exception fields',
          );
        }
        break;
      case _trailingBeforeScrollbarPolicy:
        sourceRightExclusiveBoundaryX = _requiredInt(
          json,
          'sourceRightExclusiveBoundaryX',
        );
        if (sourceRightExclusiveBoundaryX <= 0) {
          throw const FormatException(
            'sourceRightExclusiveBoundaryX must be positive',
          );
        }
        coordinateSpace = _requiredString(json, 'coordinateSpace');
        if (coordinateSpace != 'sourceImagePhysicalPixels') {
          throw const FormatException(
            'trailingBeforeScrollbar coordinateSpace must be '
            'sourceImagePhysicalPixels',
          );
        }
        final rawExclusive = json['exclusive'];
        if (rawExclusive != true) {
          throw const FormatException(
            'trailingBeforeScrollbar requires exclusive=true',
          );
        }
        if (json.containsKey('lastStrongInkX') ||
            json.containsKey('blankGuardStartX') ||
            json.containsKey('blankGuardWidth') ||
            json.containsKey('excludedNeighborStartX') ||
            json.containsKey('excludedNeighborKind')) {
          throw const FormatException(
            'trailingBeforeScrollbar must not declare arrow-boundary fields',
          );
        }
        exclusive = true;
        break;
      case _leadingBeforeArrowJpegNoisePolicy:
        sourceRightExclusiveBoundaryX = _requiredInt(
          json,
          'sourceRightExclusiveBoundaryX',
        );
        coordinateSpace = _requiredString(json, 'coordinateSpace');
        final rawExclusive = json['exclusive'];
        lastStrongInkX = _requiredInt(json, 'lastStrongInkX');
        blankGuardStartX = _requiredInt(json, 'blankGuardStartX');
        blankGuardWidth = _requiredInt(json, 'blankGuardWidth');
        excludedNeighborStartX = _requiredInt(json, 'excludedNeighborStartX');
        excludedNeighborKind = _requiredString(json, 'excludedNeighborKind');
        if (sourceRightExclusiveBoundaryX <= 0 ||
            coordinateSpace != 'sourceImagePhysicalPixels' ||
            rawExclusive != true ||
            blankGuardWidth <= 0 ||
            excludedNeighborKind != 'vectorArrow') {
          throw const FormatException(
            'leadingBeforeArrowJpegNoise requires a positive physical-pixel '
            'exclusive boundary, positive blank guard, and vectorArrow '
            'excluded neighbor',
          );
        }
        exclusive = true;
        break;
      case _trailingBeforeAdjacentColoredTextJpegNoisePolicy:
        sourceRightExclusiveBoundaryX = _requiredInt(
          json,
          'sourceRightExclusiveBoundaryX',
        );
        coordinateSpace = _requiredString(json, 'coordinateSpace');
        final rawExclusive = json['exclusive'];
        lastStrongInkX = _requiredInt(json, 'lastStrongInkX');
        blankGuardStartX = _requiredInt(json, 'blankGuardStartX');
        blankGuardWidth = _requiredInt(json, 'blankGuardWidth');
        excludedNeighborStartX = _requiredInt(json, 'excludedNeighborStartX');
        excludedNeighborKind = _requiredString(json, 'excludedNeighborKind');
        if (sourceRightExclusiveBoundaryX <= 0 ||
            coordinateSpace != 'sourceImagePhysicalPixels' ||
            rawExclusive != true ||
            blankGuardWidth <= 0 ||
            excludedNeighborKind != 'tradePositionSideVolume') {
          throw const FormatException(
            'trailingBeforeAdjacentColoredTextJpegNoise requires a positive '
            'physical-pixel exclusive boundary, positive blank guard, and '
            'tradePositionSideVolume excluded neighbor',
          );
        }
        exclusive = true;
        break;
      default:
        throw FormatException(
          'unsupported reference boundary policy "$boundaryPolicy"',
        );
    }
    final exceptionKeys = switch (boundaryPolicy) {
      _directGuardPolicy => const <String>{},
      _trailingBeforeScrollbarPolicy => const <String>{
        'sourceRightExclusiveBoundaryX',
        'coordinateSpace',
        'exclusive',
      },
      _leadingBeforeArrowJpegNoisePolicy => const <String>{
        'sourceRightExclusiveBoundaryX',
        'coordinateSpace',
        'exclusive',
        'lastStrongInkX',
        'blankGuardStartX',
        'blankGuardWidth',
        'excludedNeighborStartX',
        'excludedNeighborKind',
      },
      _trailingBeforeAdjacentColoredTextJpegNoisePolicy => const <String>{
        'sourceRightExclusiveBoundaryX',
        'coordinateSpace',
        'exclusive',
        'lastStrongInkX',
        'blankGuardStartX',
        'blankGuardWidth',
        'excludedNeighborStartX',
        'excludedNeighborKind',
      },
      _ => const <String>{},
    };
    final unexpectedKeys = json.keys.toSet().difference(<String>{
      'kind',
      'boundaryPolicy',
      'sourceFile',
      'sourceSha256',
      'sourceCrop',
      'padding',
      ...exceptionKeys,
    });
    if (unexpectedKeys.isNotEmpty) {
      throw FormatException(
        'reference boundary policy $boundaryPolicy has unsupported fields: '
        '${unexpectedKeys.toList()..sort()}',
      );
    }
    return _ReferenceTransform(
      sourceFile: _requiredString(json, 'sourceFile'),
      sourceSha256: _requiredSha(json, 'sourceSha256'),
      sourceCrop: _CropRect.fromJson(rawSourceCrop),
      padding: _Padding.fromJson(rawPadding),
      boundaryPolicy: boundaryPolicy,
      sourceRightExclusiveBoundaryX: sourceRightExclusiveBoundaryX,
      coordinateSpace: coordinateSpace,
      exclusive: exclusive,
      lastStrongInkX: lastStrongInkX,
      blankGuardStartX: blankGuardStartX,
      blankGuardWidth: blankGuardWidth,
      excludedNeighborStartX: excludedNeighborStartX,
      excludedNeighborKind: excludedNeighborKind,
    );
  }

  static _ReferenceTransform? parseOptional(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('referenceTransform must be an object');
    }
    return _ReferenceTransform.fromJson(value);
  }

  final String sourceFile;
  final String sourceSha256;
  final _CropRect sourceCrop;
  final _Padding padding;
  final String boundaryPolicy;
  final int? sourceRightExclusiveBoundaryX;
  final String? coordinateSpace;
  final bool? exclusive;
  final int? lastStrongInkX;
  final int? blankGuardStartX;
  final int? blankGuardWidth;
  final int? excludedNeighborStartX;
  final String? excludedNeighborKind;

  Map<String, Object?> get json => <String, Object?>{
    'kind': 'whitePaddingNoResample',
    'sourceFile': sourceFile,
    'sourceSha256': sourceSha256,
    'sourceCrop': sourceCrop.json,
    'padding': padding.json,
    'boundaryPolicy': boundaryPolicy,
    if (sourceRightExclusiveBoundaryX != null)
      'sourceRightExclusiveBoundaryX': sourceRightExclusiveBoundaryX,
    if (coordinateSpace != null) 'coordinateSpace': coordinateSpace,
    if (exclusive != null) 'exclusive': exclusive,
    if (lastStrongInkX != null) 'lastStrongInkX': lastStrongInkX,
    if (blankGuardStartX != null) 'blankGuardStartX': blankGuardStartX,
    if (blankGuardWidth != null) 'blankGuardWidth': blankGuardWidth,
    if (excludedNeighborStartX != null)
      'excludedNeighborStartX': excludedNeighborStartX,
    if (excludedNeighborKind != null)
      'excludedNeighborKind': excludedNeighborKind,
  };
}

class _Landmark {
  const _Landmark({
    required this.id,
    required this.reference,
    required this.candidate,
  });

  final String id;
  final _Point reference;
  final _Point candidate;

  Map<String, Object?> get json => <String, Object?>{
    'id': id,
    'reference': _coordinateJson(reference),
    'candidate': _coordinateJson(candidate),
  };
}

class _SpecimenAnnotations {
  const _SpecimenAnnotations({
    required this.referenceBaselineY,
    required this.candidateBaselineY,
    required this.landmarks,
  });

  factory _SpecimenAnnotations.fromJson(Map<String, dynamic> json) {
    final baselineOrigin = json['baselineOrigin'];
    if (baselineOrigin != null && baselineOrigin != 'top') {
      throw const FormatException(
        'annotations.baselineOrigin must be exactly "top"',
      );
    }
    final baseline = json['baseline'];
    if (baseline is! Map<String, dynamic>) {
      throw const FormatException('annotations.baseline must be an object');
    }
    final rawLandmarks = json['landmarks'];
    if (rawLandmarks is! List || rawLandmarks.isEmpty) {
      throw const FormatException(
        'annotations.landmarks must be a non-empty array',
      );
    }
    final landmarks = <_Landmark>[];
    final ids = <String>{};
    for (final value in rawLandmarks) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('each landmark must be an object');
      }
      final id = _requiredString(value, 'id');
      if (!ids.add(id)) throw FormatException('duplicate landmark id "$id"');
      landmarks.add(
        _Landmark(
          id: id,
          reference: _parseCoordinate(value['reference'], 'reference'),
          candidate: _parseCoordinate(value['candidate'], 'candidate'),
        ),
      );
    }
    return _SpecimenAnnotations(
      referenceBaselineY: _requiredInt(baseline, 'referenceY').toDouble(),
      candidateBaselineY: _requiredInt(baseline, 'candidateY').toDouble(),
      landmarks: landmarks,
    );
  }

  static _SpecimenAnnotations? parseOptional(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('annotations must be an object');
    }
    return _SpecimenAnnotations.fromJson(value);
  }

  final double referenceBaselineY;
  final double candidateBaselineY;
  final List<_Landmark> landmarks;

  void validate({
    required String id,
    required int? referenceWidth,
    required int? referenceHeight,
    required int? candidateWidth,
    required int? candidateHeight,
  }) {
    if (referenceWidth == null ||
        referenceHeight == null ||
        candidateWidth == null ||
        candidateHeight == null) {
      throw FormatException(
        'specimen $id annotations require explicit crop rectangles',
      );
    }
    if (referenceBaselineY < 0 ||
        referenceBaselineY >= referenceHeight ||
        candidateBaselineY < 0 ||
        candidateBaselineY >= candidateHeight) {
      throw FormatException(
        'specimen $id annotated baseline is outside its crop',
      );
    }
    for (final landmark in landmarks) {
      if (!_pointWithin(landmark.reference, referenceWidth, referenceHeight) ||
          !_pointWithin(landmark.candidate, candidateWidth, candidateHeight)) {
        throw FormatException(
          'specimen $id landmark ${landmark.id} is outside its crop',
        );
      }
    }
  }

  Map<String, Object?> get json => <String, Object?>{
    'baselineOrigin': 'top',
    'baseline': <String, int>{
      'referenceY': referenceBaselineY.toInt(),
      'candidateY': candidateBaselineY.toInt(),
    },
    'landmarks': <Map<String, Object?>>[
      for (final landmark in landmarks) landmark.json,
    ],
  };
}

_Point _parseCoordinate(Object? value, String label) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('landmark.$label must be an object');
  }
  return _Point(
    _requiredInt(value, 'x').toDouble(),
    _requiredInt(value, 'y').toDouble(),
  );
}

Map<String, int> _coordinateJson(_Point value) => <String, int>{
  'x': value.x.toInt(),
  'y': value.y.toInt(),
};

bool _pointWithin(_Point value, int width, int height) =>
    value.x >= 0 && value.x < width && value.y >= 0 && value.y < height;

class _CandidateSpecimen {
  _CandidateSpecimen({
    required this.id,
    required this.comparisonId,
    required this.roleId,
    required this.candidateId,
    required this.text,
    required this.file,
    required this.sha256,
    required this.sourceClass,
    required this.referenceFile,
    required this.referenceSha256,
    required this.referenceCrop,
    required this.candidateCrop,
    required this.sourceFile,
    required this.sourceSha256,
    required this.sourceCrop,
    required this.referenceTransform,
    required this.annotations,
    required this.rendererId,
    required this.faceSha256,
    required this.selectable,
    required this.scored,
    required this.pointSize,
    required this.sourceNominalWeight,
    required this.physicalWidth,
    required this.physicalHeight,
    required this.candidateBaseline,
    required this.letterSpacing,
    required this.tabularFigures,
    required this.fontFeatures,
    required this.devicePixelRatio,
    required this.textScale,
    required this.locale,
    required this.vectorPolicy,
    required this.crossRendererComparable,
    required this.horizontalLayout,
    required this.candidateAnchorX,
    required this.parameterEvidence,
    required this.referenceRoleManifestSha256,
    required this.rasterEvidence,
  });

  factory _CandidateSpecimen.parse(
    Map<String, dynamic> json, {
    required String manifestRendererId,
    required String referenceRoleManifestSha256,
  }) {
    final id = _requiredString(json, 'id');
    final file = _requiredString(json, 'file');
    final sha = _requiredSha(json, 'sha256');
    final sourceClass = _requiredString(json, 'sourceClass');
    if (!<String>{
      'controlled',
      'controlledSpecimen',
      'lossless',
      'jpegCrop',
    }.contains(sourceClass)) {
      throw FormatException(
        'specimen $id has unsupported sourceClass "$sourceClass"',
      );
    }
    final rasterEvidence = _parseRasterEvidence(
      json['rasterEvidence'],
      label: 'specimen $id',
      isRequired: manifestRendererId == _primaryRenderer,
    );
    final parameterEvidence = _parseParameterEvidence(
      json['parameterEvidence'],
      id,
    );
    final referenceFile = json['referenceFile'];
    final referenceSha = json['referenceSha256'];
    if ((referenceFile == null) != (referenceSha == null)) {
      throw FormatException(
        'specimen $id must provide referenceFile and referenceSha256 together',
      );
    }
    if (referenceFile != null &&
        (referenceFile is! String || referenceFile.isEmpty)) {
      throw FormatException(
        'specimen $id referenceFile must be a non-empty string',
      );
    }
    if (referenceSha != null &&
        (referenceSha is! String ||
            !RegExp(_shaPattern).hasMatch(referenceSha))) {
      throw FormatException(
        'specimen $id referenceSha256 must be a lowercase SHA-256',
      );
    }
    final referenceCrop = _CropRect.parseOptional(json['referenceCrop']);
    final candidateCrop = _CropRect.parseOptional(json['candidateCrop']);
    if ((referenceCrop == null) != (candidateCrop == null)) {
      throw FormatException(
        'specimen $id must provide referenceCrop and candidateCrop together',
      );
    }
    final sourceFile = json['sourceFile'];
    final sourceSha = json['sourceSha256'];
    final sourceCrop = _CropRect.parseOptional(json['sourceCrop']);
    if (sourceFile != null && (sourceFile is! String || sourceFile.isEmpty)) {
      throw FormatException(
        'specimen $id sourceFile must be a non-empty string',
      );
    }
    if (sourceSha != null &&
        (sourceSha is! String || !RegExp(_shaPattern).hasMatch(sourceSha))) {
      throw FormatException(
        'specimen $id sourceSha256 must be a lowercase SHA-256',
      );
    }
    final referenceTransform = _ReferenceTransform.parseOptional(
      json['referenceTransform'],
    );
    final annotations = _SpecimenAnnotations.parseOptional(json['annotations']);
    final rawScored = json['scored'];
    if (rawScored != null && rawScored is! bool) {
      throw FormatException('specimen $id scored must be a boolean');
    }
    final scored = rawScored as bool? ?? referenceFile != null;
    if (scored &&
        (referenceFile == null ||
            referenceSha == null ||
            referenceCrop == null ||
            candidateCrop == null ||
            annotations == null ||
            sourceFile == null ||
            sourceSha == null ||
            sourceCrop == null)) {
      throw FormatException(
        'scored specimen $id requires a verified reference file and SHA, '
        'verified raw source provenance, integer candidate/reference/source '
        'crops, and mandatory top-origin baseline and landmark annotations',
      );
    }
    if (scored &&
        (referenceCrop!.width != candidateCrop!.width ||
            referenceCrop.height != candidateCrop.height)) {
      throw FormatException(
        'scored specimen $id candidate/reference crop dimensions must agree',
      );
    }
    if (scored && referenceTransform == null) {
      if (sourceFile != referenceFile ||
          sourceSha != referenceSha ||
          !sourceCrop!.sameAs(referenceCrop!)) {
        throw FormatException(
          'scored specimen $id without a transform must use the retained raw '
          'source directly as its reference',
        );
      }
    }
    if (scored && referenceTransform != null) {
      final transform = referenceTransform;
      if (transform.sourceFile != sourceFile ||
          transform.sourceSha256 != sourceSha ||
          !transform.sourceCrop.sameAs(sourceCrop!)) {
        throw FormatException(
          'scored specimen $id transform provenance disagrees with its raw '
          'source declaration',
        );
      }
      final outputWidth =
          sourceCrop.width + transform.padding.left + transform.padding.right;
      final outputHeight =
          sourceCrop.height + transform.padding.top + transform.padding.bottom;
      if (referenceCrop!.left != 0 ||
          referenceCrop.top != 0 ||
          referenceCrop.width != outputWidth ||
          referenceCrop.height != outputHeight) {
        throw FormatException(
          'scored specimen $id derived reference crop disagrees with its '
          'white-padding transform dimensions',
        );
      }
    }
    if (annotations != null) {
      annotations.validate(
        id: id,
        referenceWidth: referenceCrop?.width,
        referenceHeight: referenceCrop?.height,
        candidateWidth: candidateCrop?.width,
        candidateHeight: candidateCrop?.height,
      );
    }
    final rawFont = json['font'];
    String? faceSha;
    bool selectable = true;
    if (rawFont != null) {
      if (rawFont is! Map<String, dynamic>) {
        throw FormatException('specimen $id font must be an object');
      }
      final value = rawFont['faceSha256'] ?? rawFont['sha256'];
      if (value != null) {
        if (value is! String || !RegExp(_shaPattern).hasMatch(value)) {
          throw FormatException('specimen $id font face SHA is invalid');
        }
        faceSha = value;
      }
      final selectableValue = rawFont['selectable'];
      if (selectableValue != null && selectableValue is! bool) {
        throw FormatException('specimen $id font.selectable must be a boolean');
      }
      selectable = selectableValue as bool? ?? true;
    }
    final topSelectable = json['selectable'];
    if (topSelectable != null && topSelectable is! bool) {
      throw FormatException('specimen $id selectable must be a boolean');
    }
    selectable = topSelectable as bool? ?? selectable;
    final text = json['text'];
    final strings = json['strings'];
    if (text is! String && strings is! List) {
      throw FormatException('specimen $id must record text or strings');
    }
    if (strings is List && strings.any((value) => value is! String)) {
      throw FormatException('specimen $id strings must contain only strings');
    }
    final comparisonId = scored
        ? _requiredString(json, 'comparisonId')
        : _optionalString(json, 'comparisonId') ??
              _optionalString(json, 'roleId') ??
              (text is String ? text : (strings as List<dynamic>).join('\n'));
    final roleId = scored
        ? _requiredString(json, 'roleId')
        : _optionalString(json, 'roleId') ?? 'unassigned';
    final candidateId = scored
        ? _requiredString(json, 'candidateId')
        : _optionalString(json, 'candidateId') ?? id;
    if (scored && faceSha == null) {
      throw FormatException(
        'scored specimen $id requires an exact candidate face SHA',
      );
    }
    final pointSize = _optionalPositiveNumber(json, 'pointSize');
    final sourceNominalWeight = _optionalPositiveInt(
      json,
      'sourceNominalWeight',
    );
    final physicalWidth = _optionalPositiveInt(json, 'physicalWidth');
    final physicalHeight = _optionalPositiveInt(json, 'physicalHeight');
    final candidateBaseline = _optionalIntegralNumber(
      json,
      'candidateBaseline',
    );
    final letterSpacing = _optionalNumber(json, 'letterSpacing');
    final tabularFigures = _optionalBool(json, 'tabularFigures');
    final devicePixelRatio = _optionalPositiveNumber(json, 'devicePixelRatio');
    final textScale = _optionalPositiveNumber(json, 'textScale');
    final locale = _optionalString(json, 'locale');
    final horizontalLayout = _optionalString(json, 'horizontalLayout');
    if (horizontalLayout != null &&
        !const <String>{
          'leading',
          'center',
          'trailing',
        }.contains(horizontalLayout)) {
      throw FormatException(
        'specimen $id horizontalLayout must be leading, center, or trailing',
      );
    }
    final candidateAnchorX = _optionalIntegralNumber(json, 'candidateAnchorX');
    final baselineOrigin = _optionalString(json, 'baselineOrigin') ?? 'top';
    if (baselineOrigin != 'top') {
      throw FormatException(
        'specimen $id baselineOrigin must be exactly "top"',
      );
    }
    final rawFeatures = json['fontFeatures'];
    final fontFeatures = rawFeatures == null
        ? <String>[if (tabularFigures == true) 'tnum']
        : _stringList(rawFeatures, 'specimen $id fontFeatures');
    if (tabularFigures == true && !fontFeatures.contains('tnum')) {
      throw FormatException(
        'specimen $id tabularFigures requires the tnum feature contract',
      );
    }
    if (tabularFigures == false && fontFeatures.contains('tnum')) {
      throw FormatException(
        'specimen $id tnum feature disagrees with tabularFigures=false',
      );
    }
    final vectorPolicy = _optionalString(json, 'vectorPolicy') ?? 'none';
    final crossRendererComparable =
        _optionalBool(json, 'crossRendererComparable') ?? scored;
    if (scored &&
        (pointSize == null ||
            sourceNominalWeight == null ||
            physicalWidth == null ||
            physicalHeight == null ||
            candidateBaseline == null ||
            letterSpacing == null ||
            tabularFigures == null ||
            devicePixelRatio == null ||
            textScale == null ||
            locale == null ||
            horizontalLayout == null ||
            candidateAnchorX == null)) {
      throw FormatException(
        'scored specimen $id requires point size, source nominal weight, physical canvas, '
        'top-origin baseline, letter spacing, feature contract, DPR, text '
        'scale, locale, horizontal layout, and candidate anchor',
      );
    }
    if (scored &&
        (devicePixelRatio != 1.5 || textScale != 1.0 || locale != 'vi-VN')) {
      throw FormatException(
        'scored specimen $id renderer contract must use DPR 1.5, text scale '
        '1.0, and locale vi-VN',
      );
    }
    if (scored &&
        referenceTransform?.boundaryPolicy == _trailingBeforeScrollbarPolicy) {
      final transform = referenceTransform!;
      final crop = sourceCrop!;
      final padding = transform.padding;
      final contract = _reviewedTrailingScrollbarContracts[comparisonId];
      final rawRightExclusive = crop.left + crop.width;
      final absoluteSourceAnchor = crop.left + candidateAnchorX! - padding.left;
      final exactFeatureContract =
          tabularFigures == true &&
          fontFeatures.length == 1 &&
          fontFeatures.single == 'tnum';
      final exactCrop =
          contract != null &&
          crop.left == contract.sourceLeft &&
          crop.top == contract.sourceTop &&
          crop.width == contract.sourceWidth &&
          crop.height == contract.physicalHeight;
      final exactPadding =
          contract != null &&
          padding.left == contract.paddingLeft &&
          padding.top == 0 &&
          padding.right == contract.paddingRight &&
          padding.bottom == 0;
      if (contract == null ||
          roleId != contract.roleId ||
          text != contract.text ||
          sourceClass != 'jpegCrop' ||
          horizontalLayout != 'trailing' ||
          pointSize != contract.pointSize ||
          sourceNominalWeight != contract.sourceNominalWeight ||
          physicalWidth != contract.physicalWidth ||
          physicalHeight != contract.physicalHeight ||
          candidateBaseline != contract.baseline ||
          candidateAnchorX != contract.anchor ||
          letterSpacing != contract.letterSpacing ||
          !exactFeatureContract ||
          devicePixelRatio != 1.5 ||
          textScale != 1.0 ||
          locale != 'vi-VN' ||
          vectorPolicy != 'none' ||
          crossRendererComparable != true ||
          transform.sourceRightExclusiveBoundaryX != 582 ||
          transform.coordinateSpace != 'sourceImagePhysicalPixels' ||
          transform.exclusive != true ||
          rawRightExclusive != 582 ||
          absoluteSourceAnchor != 582 ||
          !exactCrop ||
          !exactPadding) {
        throw FormatException(
          'specimen $id trailingBeforeScrollbar is allowed only for a '
          'source-hashed exact reviewed trade contract with its fixed crop, '
          'padding, x582 boundary/absolute anchor, and renderer parameters',
        );
      }
    }
    if (scored &&
        referenceTransform?.boundaryPolicy ==
            _leadingBeforeArrowJpegNoisePolicy) {
      final transform = referenceTransform!;
      final crop = sourceCrop!;
      final padding = transform.padding;
      final exactOpenCrop =
          crop.left == 1 &&
          crop.top == 401 &&
          crop.width == 99 &&
          crop.height == 35;
      final exactGuard =
          transform.sourceRightExclusiveBoundaryX == 100 &&
          transform.lastStrongInkX == 90 &&
          transform.blankGuardStartX == 91 &&
          transform.blankGuardWidth == 9 &&
          transform.excludedNeighborStartX == 100 &&
          transform.excludedNeighborKind == 'vectorArrow' &&
          crop.left + crop.width == 100 &&
          transform.lastStrongInkX! + 1 == transform.blankGuardStartX &&
          transform.blankGuardStartX! + transform.blankGuardWidth! ==
              transform.excludedNeighborStartX;
      final exactPadding =
          padding.left == 0 &&
          padding.top == 0 &&
          padding.right == 13 &&
          padding.bottom == 0;
      if (comparisonId != 'numeric-price-open' ||
          roleId != 'tradePositionSecondary' ||
          text != '4637.05' ||
          sourceClass != 'jpegCrop' ||
          sourceSha != _lockedTradeReferenceSha256 ||
          horizontalLayout != 'leading' ||
          pointSize != 16 ||
          sourceNominalWeight != 400 ||
          physicalWidth != 112 ||
          physicalHeight != 35 ||
          candidateBaseline != 30 ||
          candidateAnchorX != 7 ||
          letterSpacing != .98 ||
          tabularFigures != true ||
          vectorPolicy != 'none' ||
          !exactOpenCrop ||
          !exactGuard ||
          !exactPadding) {
        throw FormatException(
          'specimen $id leadingBeforeArrowJpegNoise is allowed only for the '
          'exact source-hashed numeric-price-open contract and its declared '
          'leading-before-arrow blank-guard provenance',
        );
      }
    }
    if (scored &&
        referenceTransform?.boundaryPolicy ==
            _trailingBeforeAdjacentColoredTextJpegNoisePolicy) {
      final transform = referenceTransform!;
      final crop = sourceCrop!;
      final padding = transform.padding;
      final exactCrop =
          crop.left == 3 &&
          crop.top == 369 &&
          crop.width == 79 &&
          crop.height == 35;
      final exactGuard =
          transform.sourceRightExclusiveBoundaryX == 82 &&
          transform.lastStrongInkX == 80 &&
          transform.blankGuardStartX == 81 &&
          transform.blankGuardWidth == 1 &&
          transform.excludedNeighborStartX == 82 &&
          transform.excludedNeighborKind == 'tradePositionSideVolume' &&
          crop.left + crop.width == 82 &&
          transform.lastStrongInkX! + 1 == transform.blankGuardStartX &&
          transform.blankGuardStartX! + transform.blankGuardWidth! ==
              transform.excludedNeighborStartX;
      final exactPadding =
          padding.left == 0 &&
          padding.top == 0 &&
          padding.right == 14 &&
          padding.bottom == 4;
      final exactFeatureContract =
          tabularFigures == false && fontFeatures.isEmpty;
      final absoluteSourceAnchor = crop.left + candidateAnchorX! - padding.left;
      if (comparisonId != 'trade-position-symbol' ||
          roleId != 'tradePositionSymbol' ||
          text != 'XAUUSD' ||
          sourceClass != 'jpegCrop' ||
          horizontalLayout != 'leading' ||
          pointSize != 15.3 ||
          sourceNominalWeight != 300 ||
          physicalWidth != 93 ||
          physicalHeight != 39 ||
          candidateBaseline != 29 ||
          candidateAnchorX != 4 ||
          absoluteSourceAnchor != 7 ||
          letterSpacing != -.6 ||
          !exactFeatureContract ||
          devicePixelRatio != 1.5 ||
          textScale != 1.0 ||
          locale != 'vi-VN' ||
          vectorPolicy != 'none' ||
          crossRendererComparable != true ||
          transform.coordinateSpace != 'sourceImagePhysicalPixels' ||
          transform.exclusive != true ||
          !exactCrop ||
          !exactGuard ||
          !exactPadding) {
        throw FormatException(
          'specimen $id trailingBeforeAdjacentColoredTextJpegNoise is allowed '
          'only for the exact reviewed trade-position-symbol source crop, '
          'guard, adjacent-neighbour, anchor, and renderer contract',
        );
      }
    }
    if (scored &&
        (candidateBaseline! < 0 ||
            candidateBaseline >= candidateCrop!.height ||
            annotations!.candidateBaselineY != candidateBaseline ||
            annotations.referenceBaselineY != candidateBaseline)) {
      throw FormatException(
        'scored specimen $id top-origin baseline contract disagrees across '
        'candidate, reference, and annotations',
      );
    }
    if (scored &&
        (candidateAnchorX! < 0 ||
            candidateAnchorX >= candidateCrop!.width ||
            !annotations!.landmarks.any(
              (landmark) =>
                  landmark.reference.x == candidateAnchorX &&
                  landmark.candidate.x == candidateAnchorX &&
                  landmark.reference.y == candidateBaseline &&
                  landmark.candidate.y == candidateBaseline,
            ))) {
      throw FormatException(
        'scored specimen $id anchor landmark must match its horizontal '
        'layout, candidate anchor, and top-origin baseline',
      );
    }
    return _CandidateSpecimen(
      id: id,
      comparisonId: comparisonId,
      roleId: roleId,
      candidateId: candidateId,
      text: text is String ? text : (strings as List<dynamic>).join('\n'),
      file: file,
      sha256: sha,
      sourceClass: sourceClass,
      referenceFile: referenceFile as String?,
      referenceSha256: referenceSha as String?,
      referenceCrop: referenceCrop,
      candidateCrop: candidateCrop,
      sourceFile: sourceFile as String?,
      sourceSha256: sourceSha as String?,
      sourceCrop: sourceCrop,
      referenceTransform: referenceTransform,
      annotations: annotations,
      rendererId: _optionalString(json, 'rendererId') ?? manifestRendererId,
      faceSha256: faceSha,
      selectable: selectable,
      scored: scored,
      pointSize: pointSize,
      sourceNominalWeight: sourceNominalWeight,
      physicalWidth: physicalWidth,
      physicalHeight: physicalHeight,
      candidateBaseline: candidateBaseline,
      letterSpacing: letterSpacing,
      tabularFigures: tabularFigures,
      fontFeatures: fontFeatures,
      devicePixelRatio: devicePixelRatio,
      textScale: textScale,
      locale: locale,
      vectorPolicy: vectorPolicy,
      crossRendererComparable: crossRendererComparable,
      horizontalLayout: horizontalLayout,
      candidateAnchorX: candidateAnchorX,
      parameterEvidence: parameterEvidence,
      referenceRoleManifestSha256: referenceRoleManifestSha256,
      rasterEvidence: rasterEvidence,
    );
  }

  final String id;
  final String comparisonId;
  final String roleId;
  final String candidateId;
  final String text;
  final String file;
  final String sha256;
  final String sourceClass;
  final String? referenceFile;
  final String? referenceSha256;
  final _CropRect? referenceCrop;
  final _CropRect? candidateCrop;
  final String? sourceFile;
  final String? sourceSha256;
  final _CropRect? sourceCrop;
  final _ReferenceTransform? referenceTransform;
  final _SpecimenAnnotations? annotations;
  final String rendererId;
  final String? faceSha256;
  final bool selectable;
  final bool scored;
  final double? pointSize;
  final int? sourceNominalWeight;
  final int? physicalWidth;
  final int? physicalHeight;
  final double? candidateBaseline;
  final double? letterSpacing;
  final bool? tabularFigures;
  final List<String> fontFeatures;
  final double? devicePixelRatio;
  final double? textScale;
  final String? locale;
  final String vectorPolicy;
  final bool crossRendererComparable;
  final String? horizontalLayout;
  final double? candidateAnchorX;
  final Map<String, Object?> parameterEvidence;
  final String referenceRoleManifestSha256;
  final Map<String, Object?>? rasterEvidence;

  bool get isJpegCrop => sourceClass == 'jpegCrop';

  Map<String, Object?>? get comparisonContractJson => !scored
      ? null
      : <String, Object?>{
          'comparisonId': comparisonId,
          'roleId': roleId,
          'text': text,
          'pointSize': pointSize,
          'sourceNominalWeight': sourceNominalWeight,
          'physicalWidth': physicalWidth,
          'physicalHeight': physicalHeight,
          'candidateCrop': candidateCrop!.json,
          'referenceFile': referenceFile,
          'referenceSha256': referenceSha256,
          'referenceCrop': referenceCrop!.json,
          'sourceFile': sourceFile,
          'sourceSha256': sourceSha256,
          'sourceCrop': sourceCrop!.json,
          'referenceTransform': referenceTransform?.json,
          'baselineOrigin': 'top',
          'baseline': candidateBaseline,
          'horizontalLayout': horizontalLayout,
          'candidateAnchorX': candidateAnchorX,
          'letterSpacing': letterSpacing,
          'tabularFigures': tabularFigures,
          'fontFeatures': fontFeatures,
          'devicePixelRatio': devicePixelRatio,
          'textScale': textScale,
          'locale': locale,
          'vectorPolicy': vectorPolicy,
          'sourceClass': sourceClass,
          'crossRendererComparable': crossRendererComparable,
          'parameterEvidence': parameterEvidence,
          'referenceRoleManifestSha256': referenceRoleManifestSha256,
          if (rasterEvidence != null) 'rasterEvidence': rasterEvidence,
        };

  String? get comparisonContractKey => comparisonContractJson == null
      ? null
      : jsonEncode(comparisonContractJson);

  Map<String, Object?>? get annotationsJson {
    if (referenceCrop == null || candidateCrop == null || annotations == null) {
      return null;
    }
    return <String, Object?>{
      'baselineOrigin': 'top',
      'referenceCrop': referenceCrop!.json,
      'candidateCrop': candidateCrop!.json,
      ...annotations!.json,
    };
  }

  Map<String, Object?>? get referenceProvenanceJson => !scored
      ? null
      : <String, Object?>{
          'referenceFile': referenceFile,
          'referenceSha256': referenceSha256,
          'sourceFile': sourceFile,
          'sourceSha256': sourceSha256,
          'sourceCrop': sourceCrop!.json,
          'kind': referenceTransform == null
              ? 'retainedRawSource'
              : 'whitePaddingNoResample',
          'transformVerified': referenceTransform != null,
          if (referenceTransform != null)
            'referenceTransform': referenceTransform!.json,
          if (referenceTransform != null)
            'transformVerification': rendererId == _forensicRenderer
                ? 'coreGraphics-vs-dart-jpeg-decoder-equivalence(maxChannelDelta<=96,meanChannelDelta<=4)'
                : 'exactDecodedRgba',
          'reviewedDiagnosticBoundary':
              referenceTransform?.boundaryPolicy ==
                  _trailingBeforeScrollbarPolicy ||
              referenceTransform?.boundaryPolicy ==
                  _leadingBeforeArrowJpegNoisePolicy ||
              referenceTransform?.boundaryPolicy ==
                  _trailingBeforeAdjacentColoredTextJpegNoisePolicy,
          'certifying': false,
          'topologyEligible':
              sourceClass != 'jpegCrop' &&
              referenceTransform?.boundaryPolicy !=
                  _trailingBeforeScrollbarPolicy &&
              referenceTransform?.boundaryPolicy !=
                  _leadingBeforeArrowJpegNoisePolicy &&
              referenceTransform?.boundaryPolicy !=
                  _trailingBeforeAdjacentColoredTextJpegNoisePolicy,
        };
}

Map<String, Object?> _parseParameterPolicy(Object? value) {
  if (value is! Map<String, dynamic> ||
      value.length != 3 ||
      value['provenance'] != 'currentAppHypothesis' ||
      value['lockEligible'] != false ||
      value['requiresRasterScoreForWinner'] != true) {
    throw const FormatException(
      'parameterPolicy must declare currentAppHypothesis, '
      'lockEligible=false, and requiresRasterScoreForWinner=true',
    );
  }
  return const <String, Object?>{
    'provenance': 'currentAppHypothesis',
    'lockEligible': false,
    'requiresRasterScoreForWinner': true,
  };
}

Map<String, Object?>? _parseRasterContract(
  Object? value, {
  required bool isRequired,
}) {
  if (value == null && !isRequired) return null;
  if (value is! Map<String, dynamic> ||
      value.length != 4 ||
      value['colorModel'] != 'opaqueGrayscale' ||
      value['alpha'] != 255 ||
      value['redEqualsGreenEqualsBlue'] != true ||
      value['debugPaintBaselinesEnabledAtCapture'] != false) {
    throw const FormatException(
      'rasterContract must declare opaqueGrayscale, alpha=255, equal RGB '
      'channels, and debugPaintBaselinesEnabledAtCapture=false',
    );
  }
  return const <String, Object?>{
    'colorModel': 'opaqueGrayscale',
    'alpha': 255,
    'redEqualsGreenEqualsBlue': true,
    'debugPaintBaselinesEnabledAtCapture': false,
  };
}

Map<String, Object?>? _parseRasterEvidence(
  Object? value, {
  required String label,
  required bool isRequired,
}) {
  if (value == null && !isRequired) return null;
  if (value is! Map<String, dynamic> ||
      value.length != 3 ||
      value['opaque'] != true ||
      value['grayscale'] != true ||
      value['debugPaintBaselinesEnabledAtCapture'] != false) {
    throw FormatException(
      '$label rasterEvidence must declare opaque=true, grayscale=true, and '
      'debugPaintBaselinesEnabledAtCapture=false',
    );
  }
  return const <String, Object?>{
    'opaque': true,
    'grayscale': true,
    'debugPaintBaselinesEnabledAtCapture': false,
  };
}

bool _sameStrings(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

bool _sameStringsByIndex(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Map<String, Object?> _parseParameterEvidence(Object? value, String id) {
  if (value is! Map<String, dynamic> ||
      value.length != 3 ||
      value['provenance'] != 'currentAppHypothesis' ||
      value['lockEligible'] != false ||
      value['scope'] !=
          'pointSize-letterSpacing-features-sourceNominalWeight') {
    throw FormatException(
      'specimen $id parameterEvidence must declare currentAppHypothesis, '
      'lockEligible=false, and the exact point-size/letter-spacing/features/'
      'source-weight scope',
    );
  }
  return const <String, Object?>{
    'provenance': 'currentAppHypothesis',
    'lockEligible': false,
    'scope': 'pointSize-letterSpacing-features-sourceNominalWeight',
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string when present');
  }
  return value;
}

String _requiredSha(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (!RegExp(_shaPattern).hasMatch(value)) {
    throw FormatException('$key must be a lowercase SHA-256');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key must be an integer');
  }
  return value;
}

double? _optionalNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('$key must be a finite number when present');
  }
  return value.toDouble();
}

double? _optionalPositiveNumber(Map<String, dynamic> json, String key) {
  final value = _optionalNumber(json, key);
  if (value != null && value <= 0) {
    throw FormatException('$key must be positive when present');
  }
  return value;
}

double? _optionalIntegralNumber(Map<String, dynamic> json, String key) {
  final value = _optionalNumber(json, key);
  if (value != null && value.toInt() != value) {
    throw FormatException('$key must be an integer-valued number when present');
  }
  return value;
}

int? _optionalPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int || value <= 0) {
    throw FormatException('$key must be a positive integer when present');
  }
  return value;
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! bool) {
    throw FormatException('$key must be a boolean when present');
  }
  return value;
}

List<String> _stringList(Object value, String label) {
  if (value is! List || value.any((entry) => entry is! String)) {
    throw FormatException('$label must be an array of strings');
  }
  final result = value.cast<String>().toSet().toList()..sort();
  if (result.length != value.length) {
    throw FormatException('$label must not contain duplicates');
  }
  return result;
}

List<String> _orderedStringList(Object value, String label) {
  if (value is! List || value.any((entry) => entry is! String)) {
    throw FormatException('$label must be an array of strings');
  }
  final result = value.cast<String>().toList(growable: false);
  if (result.toSet().length != result.length) {
    throw FormatException('$label must not contain duplicates');
  }
  return result;
}

class _Configuration {
  const _Configuration({
    required this.rendererId,
    required this.diagnosticOnly,
    required this.candidateDirectory,
    required this.outputDirectory,
  });

  factory _Configuration.parse(List<String> arguments) {
    String? renderer;
    String? candidateDirectory;
    String? outputDirectory;
    var diagnosticOnly = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--diagnostic-only') {
        diagnosticOnly = true;
        continue;
      }
      if (!<String>{
        '--renderer',
        '--candidate-dir',
        '--output-dir',
      }.contains(argument)) {
        throw _UsageException('Unknown argument: $argument');
      }
      if (++index >= arguments.length) {
        throw _UsageException('Missing value for $argument.');
      }
      final value = arguments[index];
      switch (argument) {
        case '--renderer':
          renderer = value;
        case '--candidate-dir':
          candidateDirectory = value;
        case '--output-dir':
          outputDirectory = value;
      }
    }
    if (renderer != _primaryRenderer && renderer != _forensicRenderer) {
      throw _UsageException(
        '--renderer must be $_primaryRenderer or $_forensicRenderer.',
      );
    }
    if (candidateDirectory == null || candidateDirectory.isEmpty) {
      throw _UsageException('--candidate-dir is required.');
    }
    if (outputDirectory == null || outputDirectory.isEmpty) {
      throw _UsageException('--output-dir is required.');
    }
    return _Configuration(
      rendererId: renderer!,
      diagnosticOnly: diagnosticOnly,
      candidateDirectory: candidateDirectory,
      outputDirectory: outputDirectory,
    );
  }

  static const usage =
      'Usage: dart run tool/compare_reference_font_specimens.dart '
      '--renderer ios|host-coretext-forensic [--diagnostic-only] '
      '--candidate-dir PATH --output-dir NEW_PATH';

  final String rendererId;
  final bool diagnosticOnly;
  final String candidateDirectory;
  final String outputDirectory;
}

class _UsageException implements Exception {
  const _UsageException(this.message);
  final String message;
}

class _ValidationException implements Exception {
  const _ValidationException(this.message);
  final String message;
}
