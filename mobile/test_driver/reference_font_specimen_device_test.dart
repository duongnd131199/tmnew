import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:integration_test/integration_test_driver_extended.dart';

import '../test/test_support/reference_typography_role_manifest.dart';

const _expectedRasterContract = <String, Object>{
  'colorModel': 'opaqueGrayscale',
  'alpha': 255,
  'redEqualsGreenEqualsBlue': true,
  'debugPaintBaselinesEnabledAtCapture': false,
};

const _expectedRasterEvidence = <String, Object>{
  'opaque': true,
  'grayscale': true,
  'debugPaintBaselinesEnabledAtCapture': false,
};

const _referenceRoleManifestPath =
    'test/test_support/reference_typography_role_manifest.dart';
const _expectedReferenceRoleManifestSha256 =
    '6eafbb63c29a8313df4ec9ffa6f0a2afa455b0e5c7fffd4d2d3ef85183c9f2d0';

Map<String, Object> referenceRoleManifestProvenance() => {
  'referenceRoleManifestSha256': _verifiedReferenceRoleManifestSha256(),
};

void validateReferenceRoleManifestProvenance(Object? value) {
  if (value is! Map) {
    throw StateError('Reference role manifest provenance must be an object');
  }
  final sha = value['referenceRoleManifestSha256'];
  if (sha is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
    throw StateError('referenceRoleManifestSha256 must be lowercase SHA-256');
  }
  final actual = _verifiedReferenceRoleManifestSha256();
  if (sha != actual) {
    throw StateError('referenceRoleManifestSha256 $sha disagrees with $actual');
  }
}

String _verifiedReferenceRoleManifestSha256() {
  final file = File(_referenceRoleManifestPath);
  if (!file.existsSync()) {
    throw StateError('Missing $_referenceRoleManifestPath');
  }
  final actual = sha256.convert(file.readAsBytesSync()).toString();
  if (actual != _expectedReferenceRoleManifestSha256) {
    throw StateError(
      'Pure role manifest changed: expected '
      '$_expectedReferenceRoleManifestSha256, got $actual',
    );
  }
  return actual;
}

void validateTradePositionSymbolBoundaryEvidence({
  required Object? annotationValue,
  required Object? referenceCropValue,
  required Object? paddingValue,
  required String comparisonId,
  required String horizontalLayout,
  required image.Image sourceImage,
}) {
  final annotation = _object(annotationValue, 'trade-position-symbol');
  final referenceCrop = _integerRect(
    referenceCropValue,
    'trade-position-symbol.referenceCrop',
  );
  final padding = _padding(paddingValue, 'trade-position-symbol.padding');
  if (comparisonId != 'trade-position-symbol' ||
      horizontalLayout != 'leading' ||
      annotation['boundaryPolicy'] !=
          'trailingBeforeAdjacentColoredTextJpegNoise' ||
      referenceCrop.left != 3 ||
      referenceCrop.top != 369 ||
      referenceCrop.width != 79 ||
      referenceCrop.height != 35 ||
      referenceCrop.left + referenceCrop.width != 82 ||
      padding.left != 0 ||
      padding.top != 0 ||
      padding.right != 14 ||
      padding.bottom != 4 ||
      annotation['sourceRightExclusiveBoundaryX'] != 82 ||
      annotation['lastStrongInkX'] != 80 ||
      annotation['blankGuardStartX'] != 81 ||
      annotation['blankGuardWidth'] != 1 ||
      annotation['excludedNeighborStartX'] != 82 ||
      annotation['excludedNeighborKind'] != 'tradePositionSideVolume' ||
      !_columnHasStrongJpegInk(sourceImage, 80, 369, 35) ||
      _columnHasStrongJpegInk(sourceImage, 81, 369, 35) ||
      !_columnHasNonWhiteJpegSupport(sourceImage, 81, 369, 35) ||
      !_columnHasNonWhiteJpegSupport(sourceImage, 82, 369, 35) ||
      !_columnHasBlueJpegInk(sourceImage, 87, 369, 35)) {
    throw StateError('trade-position-symbol boundary evidence is stale');
  }
}

Future<void> main() async {
  final roleManifestProvenance = referenceRoleManifestProvenance();
  validateReferenceRoleManifestProvenance(roleManifestProvenance);
  final outputPath = Platform.environment['REFERENCE_SPECIMEN_OUTPUT'];
  final deviceId = Platform.environment['REFERENCE_SPECIMEN_DEVICE_ID'];
  if (outputPath == null || outputPath.isEmpty || !outputPath.startsWith('/')) {
    throw StateError('REFERENCE_SPECIMEN_OUTPUT must be an absolute path');
  }
  if (deviceId == null || deviceId.trim().isEmpty) {
    throw StateError('REFERENCE_SPECIMEN_DEVICE_ID is required');
  }
  final outputDirectory = Directory(outputPath);
  if (!outputDirectory.existsSync()) {
    throw StateError('Specimen output directory does not exist: $outputPath');
  }
  final existing = outputDirectory.listSync(followLinks: false);
  if (existing.any(
    (entity) =>
        entity is! File || !entity.path.endsWith('/flutter-devices.json'),
  )) {
    throw StateError(
      'Fresh output may contain only flutter-devices.json: $outputPath',
    );
  }
  final devicesFile = File('$outputPath/flutter-devices.json');
  if (!devicesFile.existsSync()) {
    throw StateError('Missing $outputPath/flutter-devices.json');
  }
  final devices = (jsonDecode(devicesFile.readAsStringSync()) as List<dynamic>)
      .map((value) => _object(value, 'device'))
      .toList(growable: false);
  final matchingDevices = devices
      .where((device) => device['id'] == deviceId)
      .toList(growable: false);
  if (matchingDevices.length != 1) {
    throw StateError(
      'Device $deviceId must match exactly one flutter-devices.json record',
    );
  }
  final device = matchingDevices.single;
  final targetPlatform = device['targetPlatform']?.toString() ?? '';
  if (!targetPlatform.toLowerCase().contains('ios')) {
    throw StateError('Primary renderer requires an iOS device: $device');
  }

  await integrationDriver(
    responseDataCallback: (data) {
      final payload = _object(
        data?['referenceFontSpecimens'],
        'referenceFontSpecimens',
      );
      if (payload['schemaVersion'] != 1 || payload['rendererId'] != 'ios') {
        throw StateError('Unexpected renderer payload: $payload');
      }
      final payloadParameterPolicy = _object(
        payload['parameterPolicy'],
        'parameterPolicy',
      );
      if (payloadParameterPolicy.length != referenceRunParameterPolicy.length ||
          payloadParameterPolicy['provenance'] !=
              referenceRunParameterPolicy['provenance'] ||
          payloadParameterPolicy['lockEligible'] != false ||
          payloadParameterPolicy['requiresRasterScoreForWinner'] != true) {
        throw StateError('App parameter hypothesis policy is missing or stale');
      }
      final payloadRasterContract = _object(
        payload['rasterContract'],
        'rasterContract',
      );
      if (!_sameObject(payloadRasterContract, _expectedRasterContract) ||
          !_sameObject(
            referenceFontSpecimenRasterContract,
            _expectedRasterContract,
          )) {
        throw StateError(
          'App opaque-grayscale raster contract is missing or stale',
        );
      }
      if (payload['appOperatingSystem'] != 'ios') {
        throw StateError(
          'App OS ${payload['appOperatingSystem']} disagrees with $device',
        );
      }
      if (device['emulator'] != true) {
        throw StateError('Primary renderer profile requires an iOS simulator');
      }
      if (!iosSimulatorRuntimeMatchesAppVersion(
        device['sdk']?.toString() ?? '',
        payload['appOperatingSystemVersion']?.toString() ?? '',
      )) {
        throw StateError(
          'Device SDK ${device['sdk']} disagrees with app version '
          '${payload['appOperatingSystemVersion']}',
        );
      }
      final manifestFile = File('$outputPath/manifest.json');
      if (manifestFile.existsSync()) {
        throw StateError('Refusing to overwrite ${manifestFile.path}');
      }
      final annotations = <String, Map<String, dynamic>>{
        for (final annotation in referenceFontSpecimenSourceAnnotations)
          annotation.candidateRunId: _annotationJson(annotation),
      };
      if (annotations.length != referenceFontSpecimenSourceAnnotations.length) {
        throw StateError('Duplicate source annotation ids are forbidden');
      }
      final rawSpecimens = (payload['specimens'] as List<dynamic>)
          .map((value) => _object(value, 'specimen'))
          .toList(growable: false);
      if (rawSpecimens.isEmpty) {
        throw StateError('No specimen PNGs were reported');
      }
      final expectedSpecimenIds = <String>{
        for (final candidate in referenceFontSpecimenCandidates)
          for (final run in referenceFontSpecimenOutputRuns)
            if (run.supports(candidate) &&
                referenceFontScoredRunIds.contains(run.comparisonId))
              '${candidate.id}--${run.comparisonId}',
      };
      if (expectedSpecimenIds.length != 88) {
        throw StateError(
          'Frozen primary specimen matrix must contain exactly 88 entries',
        );
      }
      final reportedSpecimenIds = rawSpecimens
          .map((specimen) => specimen['id']?.toString() ?? '')
          .toSet();
      if (reportedSpecimenIds.length != rawSpecimens.length ||
          reportedSpecimenIds.length != expectedSpecimenIds.length ||
          !reportedSpecimenIds.containsAll(expectedSpecimenIds)) {
        throw StateError(
          'Primary specimen set differs: expected=$expectedSpecimenIds '
          'actual=$reportedSpecimenIds',
        );
      }

      final prepared = <_PreparedFile>[];
      final copiedReferences = <String, String>{};
      final ids = <String>{};
      final manifestSpecimens = <Map<String, dynamic>>[];
      for (final specimen in rawSpecimens) {
        final id = specimen['id']?.toString() ?? '';
        if (id.isEmpty || !ids.add(id)) {
          throw StateError('Invalid or duplicate specimen id: $id');
        }
        for (final key in const [
          'comparisonId',
          'roleId',
          'candidateId',
          'text',
          'sourceClass',
          'file',
          'sha256',
        ]) {
          if (specimen[key]?.toString().isEmpty ?? true) {
            throw StateError('$id is missing $key');
          }
        }
        final font = _object(specimen['font'], '$id.font');
        final candidate = referenceFontSpecimenCandidates.singleWhere(
          (candidate) => candidate.id == specimen['candidateId'],
          orElse: () => throw StateError('$id has an unknown candidate'),
        );
        final comparisonId = specimen['comparisonId']?.toString() ?? '';
        final run = referenceFontSpecimenOutputRuns.singleWhere(
          (run) => run.comparisonId == comparisonId,
          orElse: () => throw StateError('$id has an unknown run'),
        );
        final expectedId = '${candidate.id}--${run.comparisonId}';
        final parameterEvidence = _object(
          specimen['parameterEvidence'],
          '$id.parameterEvidence',
        );
        if (parameterEvidence.length != run.parameterEvidence.length ||
            parameterEvidence['provenance'] != run.parameterProvenance.name ||
            parameterEvidence['lockEligible'] != false ||
            parameterEvidence['scope'] != run.parameterEvidence['scope']) {
          throw StateError(
            '$id parameters must remain current-app hypotheses and cannot lock',
          );
        }
        if (id != expectedId ||
            !run.supports(candidate) ||
            specimen['roleId'] != run.roleId ||
            specimen['text'] != run.text ||
            specimen['sourceAnnotationId'] != run.comparisonId ||
            specimen['file'] != '$expectedId.png' ||
            specimen['pointSize'] != run.pointSize ||
            specimen['sourceNominalWeight'] != run.sourceNominalWeight ||
            specimen['letterSpacing'] != run.letterSpacing ||
            specimen['tabularFigures'] != run.tabularFigures ||
            specimen['physicalWidth'] != run.physicalRect.width.toInt() ||
            specimen['physicalHeight'] != run.physicalRect.height.toInt() ||
            specimen['candidateBaseline'] !=
                run.physicalBaseline - run.physicalRect.top ||
            specimen['horizontalLayout'] != run.horizontalLayout.name ||
            specimen['candidateAnchorX'] != run.horizontalAnchor) {
          throw StateError(
            '$id app-reported run contract is stale or remapped',
          );
        }
        if (font['family'] != candidate.family ||
            font['weight'] != candidate.weight ||
            font['faceSha256'] != candidate.faceSha256 ||
            font['selectable'] != candidate.isSelectableForRole(run.roleId) ||
            !_sameStrings(
              (font['selectableRoleIds'] as List<dynamic>).cast<String>(),
              candidate.selectableRoleIds.toList()..sort(),
            ) ||
            font['assetPath'] != candidate.assetPath ||
            font['provenance'] != candidate.provenance) {
          throw StateError('$id candidate/font contract mismatch');
        }
        if (specimen['devicePixelRatio'] != 1.5 ||
            specimen['textScale'] != 1.0 ||
            specimen['locale'] != 'vi-VN' ||
            specimen['candidateWeight'] != candidate.weight) {
          throw StateError('$id renderer metrics are not frozen');
        }
        _validateRasterEvidence(specimen['rasterEvidence'], id);
        final fontSha = font['faceSha256']?.toString() ?? '';
        if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(fontSha)) {
          throw StateError('$id has invalid face SHA-256: $fontSha');
        }
        final fontPath = font['assetPath']?.toString() ?? '';
        final fontFile = File(fontPath);
        if (!fontFile.existsSync() ||
            sha256.convert(fontFile.readAsBytesSync()).toString() != fontSha) {
          throw StateError('$id font bytes disagree with $fontSha');
        }
        final png = base64Decode(specimen['pngBase64'] as String);
        final actualSha = sha256.convert(png).toString();
        if (actualSha != specimen['sha256']) {
          throw StateError('$id PNG SHA mismatch');
        }
        final decoded = image.decodePng(png);
        if (decoded == null ||
            decoded.width != specimen['physicalWidth'] ||
            decoded.height != specimen['physicalHeight']) {
          throw StateError('$id PNG dimensions disagree with app metadata');
        }
        _validateOpaqueGrayscale(decoded, id);
        if (!_hasExactWhiteGuard(decoded, 2)) {
          throw StateError(
            '$id candidate raster lacks a two-pixel white guard',
          );
        }
        final fileName = _safeFileName(specimen['file'], '$id.file');
        prepared.add(_PreparedFile(fileName, Uint8List.fromList(png)));

        final annotation = annotations[comparisonId];
        if (annotation == null ||
            annotation['comparisonId'] != comparisonId ||
            annotation['roleId'] != specimen['roleId'] ||
            annotation['text'] != specimen['text']) {
          throw StateError('$id has no exact source annotation');
        }
        final sourcePath = annotation['sourcePath'] as String;
        final sourceFile = File(sourcePath);
        final sourceAbsolute = sourceFile.absolute.path;
        if (!sourceAbsolute.contains('/iconMau/anhmau/') ||
            sourceAbsolute.contains('/goldens/')) {
          throw StateError('$id source is outside the reviewed reference set');
        }
        final sourceBytes = sourceFile.readAsBytesSync();
        final sourceSha = sha256.convert(sourceBytes).toString();
        if (sourceSha != annotation['sourceSha256']) {
          throw StateError('$id source SHA mismatch for $sourcePath');
        }
        final sourceId = annotation['sourceId'] as String;
        if (!RegExp(r'^[a-z0-9-]+$').hasMatch(sourceId)) {
          throw StateError('$id source id is unsafe: $sourceId');
        }
        final extension = sourcePath.toLowerCase().endsWith('.png')
            ? 'png'
            : 'jpg';
        final sourceReferenceFile = 'references/$sourceId.$extension';
        final previousSha = copiedReferences[sourceReferenceFile];
        if (previousSha != null && previousSha != sourceSha) {
          throw StateError(
            '$sourceReferenceFile resolves to conflicting sources',
          );
        }
        if (previousSha == null) {
          copiedReferences[sourceReferenceFile] = sourceSha;
          prepared.add(
            _PreparedFile(sourceReferenceFile, Uint8List.fromList(sourceBytes)),
          );
        }
        final sourceImage = image.decodeImage(sourceBytes);
        if (sourceImage == null) {
          throw StateError('$id source image cannot be decoded');
        }
        final referenceCrop = _integerRect(
          annotation['physicalRect'],
          '$id.referenceCrop',
        );
        if (!referenceCrop.isInside(sourceImage.width, sourceImage.height)) {
          throw StateError('$id reference crop is outside $sourcePath');
        }
        final padding = _padding(annotation['padding'], '$id.padding');
        if (annotation['boundaryPolicy'] == 'leadingBeforeArrowJpegNoise') {
          final boundary = annotation['sourceRightExclusiveBoundaryX'];
          final lastInk = annotation['lastStrongInkX'];
          final guardStart = annotation['blankGuardStartX'];
          final guardWidth = annotation['blankGuardWidth'];
          final neighborStart = annotation['excludedNeighborStartX'];
          if (comparisonId != 'numeric-price-open' ||
              specimen['horizontalLayout'] != 'leading' ||
              boundary != 100 ||
              referenceCrop.left + referenceCrop.width != boundary ||
              lastInk != 90 ||
              guardStart != 91 ||
              guardWidth != 9 ||
              neighborStart != 100 ||
              annotation['excludedNeighborKind'] != 'vectorArrow' ||
              padding.right != 13 ||
              !_columnHasStrongJpegInk(
                sourceImage,
                lastInk as int,
                referenceCrop.top,
                referenceCrop.height,
              ) ||
              _rangeHasStrongJpegInk(
                sourceImage,
                guardStart as int,
                guardWidth as int,
                referenceCrop.top,
                referenceCrop.height,
              ) ||
              !_columnHasStrongJpegInk(
                sourceImage,
                neighborStart as int,
                referenceCrop.top,
                referenceCrop.height,
              )) {
            throw StateError('$id arrow/JPEG boundary evidence is stale');
          }
        }
        if (annotation['boundaryPolicy'] ==
            'trailingBeforeAdjacentColoredTextJpegNoise') {
          validateTradePositionSymbolBoundaryEvidence(
            annotationValue: annotation,
            referenceCropValue: referenceCrop.toJson(),
            paddingValue: padding.toJson(),
            comparisonId: comparisonId,
            horizontalLayout: specimen['horizontalLayout']?.toString() ?? '',
            sourceImage: sourceImage,
          );
        }
        if (referenceCrop.width + padding.left + padding.right !=
                decoded.width ||
            referenceCrop.height + padding.top + padding.bottom !=
                decoded.height) {
          throw StateError(
            '$id candidate/padded-reference sizes differ: '
            '${decoded.width}x${decoded.height} vs '
            '${referenceCrop.width + padding.left + padding.right}x'
            '${referenceCrop.height + padding.top + padding.bottom}',
          );
        }
        var referenceFile = sourceReferenceFile;
        var referenceSha = sourceSha;
        var manifestReferenceCrop = referenceCrop;
        Map<String, dynamic>? referenceTransform;
        if (!padding.isZero) {
          final cropped = image.copyCrop(
            sourceImage,
            x: referenceCrop.left,
            y: referenceCrop.top,
            width: referenceCrop.width,
            height: referenceCrop.height,
          );
          final padded = image.Image(
            width: decoded.width,
            height: decoded.height,
            numChannels: 4,
          );
          image.fill(padded, color: image.ColorRgba8(255, 255, 255, 255));
          image.compositeImage(
            padded,
            cropped,
            dstX: padding.left,
            dstY: padding.top,
            blend: image.BlendMode.direct,
          );
          final paddedBytes = Uint8List.fromList(image.encodePng(padded));
          referenceFile = 'references/$sourceId--$comparisonId-padded.png';
          referenceSha = sha256.convert(paddedBytes).toString();
          final priorDerived = copiedReferences[referenceFile];
          if (priorDerived != null && priorDerived != referenceSha) {
            throw StateError('$referenceFile has conflicting transforms');
          }
          if (priorDerived == null) {
            copiedReferences[referenceFile] = referenceSha;
            prepared.add(_PreparedFile(referenceFile, paddedBytes));
          }
          manifestReferenceCrop = _IntegerRect(
            0,
            0,
            decoded.width,
            decoded.height,
          );
          referenceTransform = {
            'kind': 'whitePaddingNoResample',
            'boundaryPolicy': annotation['boundaryPolicy'],
            if (annotation['boundaryPolicy'] != 'directGuard') ...{
              'sourceRightExclusiveBoundaryX':
                  annotation['sourceRightExclusiveBoundaryX'],
              'coordinateSpace': 'sourceImagePhysicalPixels',
              'exclusive': true,
            },
            if (annotation['boundaryPolicy'] == 'leadingBeforeArrowJpegNoise' ||
                annotation['boundaryPolicy'] ==
                    'trailingBeforeAdjacentColoredTextJpegNoise') ...{
              'lastStrongInkX': annotation['lastStrongInkX'],
              'blankGuardStartX': annotation['blankGuardStartX'],
              'blankGuardWidth': annotation['blankGuardWidth'],
              'excludedNeighborStartX': annotation['excludedNeighborStartX'],
              'excludedNeighborKind': annotation['excludedNeighborKind'],
            },
            'sourceFile': sourceReferenceFile,
            'sourceSha256': sourceSha,
            'sourceCrop': referenceCrop.toJson(),
            'padding': padding.toJson(),
          };
        }
        final referenceBaseline =
            (annotation['baseline'] as num).toDouble() -
            referenceCrop.top +
            padding.top;
        final candidateBaseline = (specimen['candidateBaseline'] as num)
            .toDouble();
        if ((referenceBaseline - candidateBaseline).abs() > .01) {
          throw StateError(
            '$id baseline mismatch: $referenceBaseline vs $candidateBaseline',
          );
        }
        if (referenceBaseline.toInt() != referenceBaseline ||
            candidateBaseline.toInt() != candidateBaseline) {
          throw StateError('$id baselines must be integral physical pixels');
        }
        final referenceBaselineInt = referenceBaseline.toInt();
        final candidateBaselineInt = candidateBaseline.toInt();
        final referenceAnchor =
            (annotation['horizontalAnchor'] as num).toDouble() + padding.left;
        final candidateAnchor = (specimen['candidateAnchorX'] as num)
            .toDouble();
        if (referenceAnchor.toInt() != referenceAnchor ||
            candidateAnchor.toInt() != candidateAnchor ||
            referenceAnchor != candidateAnchor) {
          throw StateError(
            '$id horizontal anchor mismatch: '
            '$referenceAnchor vs $candidateAnchor',
          );
        }
        final referenceAnchorInt = referenceAnchor.toInt();
        final candidateAnchorInt = candidateAnchor.toInt();
        final candidateCrop = _IntegerRect(0, 0, decoded.width, decoded.height);
        manifestSpecimens.add({
          for (final entry in specimen.entries)
            if (entry.key != 'pngBase64') entry.key: entry.value,
          'byteLength': png.length,
          'sourceClass': annotation['sourceClass'] == 'pngLossless'
              ? 'lossless'
              : 'jpegCrop',
          'candidateCrop': candidateCrop.toJson(),
          'referenceFile': referenceFile,
          'referenceSha256': referenceSha,
          'referenceCrop': manifestReferenceCrop.toJson(),
          'sourceFile': sourceReferenceFile,
          'sourceSha256': sourceSha,
          'sourceCrop': referenceCrop.toJson(),
          'referenceTransform': ?referenceTransform,
          'annotations': {
            'baseline': {
              'referenceY': referenceBaselineInt,
              'candidateY': candidateBaselineInt,
            },
            'landmarks': [
              {
                'id': '$comparisonId-${specimen['horizontalLayout']}-anchor',
                'reference': {
                  'x': referenceAnchorInt,
                  'y': referenceBaselineInt,
                },
                'candidate': {
                  'x': candidateAnchorInt,
                  'y': candidateBaselineInt,
                },
              },
            ],
          },
        });
      }

      final coverage = <Map<String, dynamic>>[];
      final rawCoverage = payload['coverageSpecimens'] as List<dynamic>;
      final expectedCoverageIds = {
        for (final candidate in referenceFontSpecimenCandidates)
          '${candidate.id}--coverage',
      };
      final reportedCoverageIds = rawCoverage
          .map((value) => _object(value, 'coverage specimen')['id'])
          .toSet();
      if (rawCoverage.length != 8 ||
          reportedCoverageIds.length != 8 ||
          !reportedCoverageIds.containsAll(expectedCoverageIds)) {
        throw StateError('Coverage sheet candidate set is incomplete');
      }
      for (final value in rawCoverage) {
        final specimen = _object(value, 'coverage specimen');
        final id = specimen['id']?.toString() ?? '';
        if (specimen['strings'] is! List ||
            !_sameStrings(
              (specimen['strings'] as List<dynamic>).cast<String>(),
              referenceFontSpecimenStrings,
            ) ||
            specimen['physicalWidth'] != 590 ||
            specimen['physicalHeight'] != 930 ||
            specimen['devicePixelRatio'] != 1.5 ||
            specimen['textScale'] != 1.0 ||
            specimen['locale'] != 'vi-VN' ||
            specimen['scored'] != false) {
          throw StateError('$id exact-six coverage contract mismatch');
        }
        _validateRasterEvidence(specimen['rasterEvidence'], id);
        final png = base64Decode(specimen['pngBase64'] as String);
        if (sha256.convert(png).toString() != specimen['sha256']) {
          throw StateError('$id coverage PNG SHA mismatch');
        }
        final decoded = image.decodePng(png);
        if (decoded == null || decoded.width != 590 || decoded.height != 930) {
          throw StateError(
            '$id coverage PNG dimensions disagree with metadata',
          );
        }
        _validateOpaqueGrayscale(decoded, id);
        final fileName = _safeFileName(specimen['file'], '$id.file');
        prepared.add(_PreparedFile(fileName, Uint8List.fromList(png)));
        coverage.add({
          for (final entry in specimen.entries)
            if (entry.key != 'pngBase64') entry.key: entry.value,
          'byteLength': png.length,
        });
      }

      final outputNames = <String>{};
      for (final file in prepared) {
        if (!outputNames.add(file.relativePath)) {
          throw StateError('Duplicate prepared output: ${file.relativePath}');
        }
        if (File('$outputPath/${file.relativePath}').existsSync()) {
          throw StateError('Refusing to overwrite ${file.relativePath}');
        }
      }
      Directory('$outputPath/references').createSync();
      for (final file in prepared) {
        File(
          '$outputPath/${file.relativePath}',
        ).writeAsBytesSync(file.bytes, flush: true);
      }

      final sourceFiles = _sourceSnapshotFiles();
      final manifest = <String, dynamic>{
        'schemaVersion': 1,
        'rendererId': 'ios',
        'diagnosticOnly': false,
        ...roleManifestProvenance,
        'device': {
          'id': deviceId,
          'name': device['name'],
          'targetPlatform': targetPlatform,
          'simulator': device['emulator'],
          'sdk': device['sdk'],
          'appOperatingSystem': payload['appOperatingSystem'],
          'appOperatingSystemVersion': payload['appOperatingSystemVersion'],
        },
        'fontLockSha256': sha256
            .convert(
              File(
                'assets/fonts/mt5-reference/font-lock.json',
              ).readAsBytesSync(),
            )
            .toString(),
        'sourceSnapshotSha256': _sourceSnapshotSha256(sourceFiles),
        'parameterPolicy': referenceRunParameterPolicy,
        'rasterContract': referenceFontSpecimenRasterContract,
        'sourceFiles': sourceFiles,
        'fonts': [for (final specimen in manifestSpecimens) specimen['font']],
        'specimens': manifestSpecimens,
        'coverageSpecimens': coverage,
      };
      validateReferenceRoleManifestProvenance(manifest);
      manifestFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
        flush: true,
      );
    },
    writeResponseOnFailure: true,
  );
}

class _PreparedFile {
  const _PreparedFile(this.relativePath, this.bytes);

  final String relativePath;
  final Uint8List bytes;
}

class _IntegerRect {
  const _IntegerRect(this.left, this.top, this.width, this.height);

  final int left;
  final int top;
  final int width;
  final int height;

  bool isInside(int imageWidth, int imageHeight) =>
      left >= 0 &&
      top >= 0 &&
      width > 0 &&
      height > 0 &&
      left + width <= imageWidth &&
      top + height <= imageHeight;

  Map<String, int> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };
}

class _Padding {
  const _Padding(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool get isZero => left == 0 && top == 0 && right == 0 && bottom == 0;

  Map<String, int> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };
}

_Padding _padding(Object? value, String name) {
  final map = _object(value, name);
  int field(String key) {
    final number = map[key];
    if (number is! num || number.toInt() != number || number < 0) {
      throw StateError('$name.$key must be a non-negative integer');
    }
    return number.toInt();
  }

  return _Padding(field('left'), field('top'), field('right'), field('bottom'));
}

bool _hasExactWhiteGuard(image.Image decoded, int inset) {
  bool white(int x, int y) {
    final pixel = decoded.getPixel(x, y);
    return pixel.r.toInt() == 255 &&
        pixel.g.toInt() == 255 &&
        pixel.b.toInt() == 255 &&
        pixel.a.toInt() == 255;
  }

  for (var edge = 0; edge < inset; edge += 1) {
    for (var x = 0; x < decoded.width; x += 1) {
      if (!white(x, edge) || !white(x, decoded.height - 1 - edge)) {
        return false;
      }
    }
    for (var y = 0; y < decoded.height; y += 1) {
      if (!white(edge, y) || !white(decoded.width - 1 - edge, y)) {
        return false;
      }
    }
  }
  return true;
}

void _validateRasterEvidence(Object? value, String id) {
  final evidence = _object(value, '$id.rasterEvidence');
  if (!_sameObject(evidence, _expectedRasterEvidence)) {
    throw StateError('$id raster evidence is missing or stale');
  }
}

void _validateOpaqueGrayscale(image.Image decoded, String id) {
  var index = 0;
  for (final pixel in decoded) {
    final red = pixel.r.toInt();
    final green = pixel.g.toInt();
    final blue = pixel.b.toInt();
    final alpha = pixel.a.toInt();
    if (alpha != 255 || red != green || green != blue) {
      final x = index % decoded.width;
      final y = index ~/ decoded.width;
      throw StateError(
        '$id PNG violates opaque grayscale at ($x,$y): '
        'rgba($red,$green,$blue,$alpha)',
      );
    }
    index += 1;
  }
}

bool _sameObject(Map<String, dynamic> actual, Map<String, Object> expected) {
  if (actual.length != expected.length) return false;
  for (final entry in expected.entries) {
    if (actual[entry.key] != entry.value) return false;
  }
  return true;
}

bool _columnHasStrongJpegInk(image.Image source, int x, int top, int height) {
  for (var y = top; y < top + height; y += 1) {
    final pixel = source.getPixel(x, y);
    if (pixel.r.toInt() < 190 ||
        pixel.g.toInt() < 190 ||
        pixel.b.toInt() < 190) {
      return true;
    }
  }
  return false;
}

bool _columnHasNonWhiteJpegSupport(
  image.Image source,
  int x,
  int top,
  int height,
) {
  for (var y = top; y < top + height; y += 1) {
    final pixel = source.getPixel(x, y);
    if (pixel.r.toInt() != 255 ||
        pixel.g.toInt() != 255 ||
        pixel.b.toInt() != 255) {
      return true;
    }
  }
  return false;
}

bool _columnHasBlueJpegInk(image.Image source, int x, int top, int height) {
  for (var y = top; y < top + height; y += 1) {
    final pixel = source.getPixel(x, y);
    final red = pixel.r.toInt();
    final green = pixel.g.toInt();
    final blue = pixel.b.toInt();
    if (blue - (red > green ? red : green) > 15 && red < 190) return true;
  }
  return false;
}

bool _rangeHasStrongJpegInk(
  image.Image source,
  int startX,
  int width,
  int top,
  int height,
) {
  for (var x = startX; x < startX + width; x += 1) {
    if (_columnHasStrongJpegInk(source, x, top, height)) return true;
  }
  return false;
}

_IntegerRect _integerRect(Object? value, String name) {
  final map = _object(value, name);
  int field(String key) {
    final number = map[key];
    if (number is! num || number.toInt() != number) {
      throw StateError('$name.$key must be an integer');
    }
    return number.toInt();
  }

  return _IntegerRect(
    field('left'),
    field('top'),
    field('width'),
    field('height'),
  );
}

String _safeFileName(Object? value, String name) {
  final fileName = value?.toString() ?? '';
  if (fileName.isEmpty ||
      fileName.contains('/') ||
      fileName.contains(r'\') ||
      fileName == '.' ||
      fileName == '..') {
    throw StateError('$name is unsafe: $fileName');
  }
  return fileName;
}

Map<String, dynamic> _object(Object? value, String name) {
  if (value is! Map) throw StateError('$name must be an object');
  return value.cast<String, dynamic>();
}

Map<String, dynamic> _annotationJson(
  ReferenceFontSpecimenSourceAnnotation annotation,
) => {
  'candidateRunId': annotation.candidateRunId,
  'comparisonId': annotation.comparisonId,
  'roleId': annotation.roleId,
  'text': annotation.text,
  'sourceId': annotation.sourceId,
  'sourcePath': annotation.sourcePath,
  'sourceSha256': annotation.sourceSha256,
  'physicalRect': {
    'left': annotation.physicalRect.left,
    'top': annotation.physicalRect.top,
    'width': annotation.physicalRect.width,
    'height': annotation.physicalRect.height,
  },
  'baseline': annotation.baseline,
  'sourceClass': annotation.sourceClass,
  'horizontalAnchor': annotation.horizontalAnchor,
  'padding': {
    'left': annotation.paddingLeft,
    'top': annotation.paddingTop,
    'right': annotation.paddingRight,
    'bottom': annotation.paddingBottom,
  },
  'boundaryPolicy': annotation.boundaryPolicy.name,
  if (annotation.sourceRightExclusiveBoundaryX != null)
    'sourceRightExclusiveBoundaryX': annotation.sourceRightExclusiveBoundaryX,
  if (annotation.lastStrongInkX != null)
    'lastStrongInkX': annotation.lastStrongInkX,
  if (annotation.blankGuardStartX != null)
    'blankGuardStartX': annotation.blankGuardStartX,
  if (annotation.blankGuardWidth != null)
    'blankGuardWidth': annotation.blankGuardWidth,
  if (annotation.excludedNeighborStartX != null)
    'excludedNeighborStartX': annotation.excludedNeighborStartX,
  if (annotation.excludedNeighborKind != null)
    'excludedNeighborKind': annotation.excludedNeighborKind,
};

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

List<Map<String, dynamic>> _sourceSnapshotFiles() {
  final paths = <String>{'pubspec.yaml', 'pubspec.lock'};
  for (final directoryPath in <String>['assets', 'lib', 'test/test_support']) {
    for (final entity in Directory(
      directoryPath,
    ).listSync(recursive: true, followLinks: false)) {
      if (entity is File) paths.add(entity.path);
    }
  }
  paths.addAll(const [
    'integration_test/reference_font_specimen_device_test.dart',
    'test_driver/reference_font_specimen_device_test.dart',
  ]);
  final sorted = paths.toList()..sort();
  return [
    for (final path in sorted)
      {
        'path': path,
        'sha256': sha256.convert(File(path).readAsBytesSync()).toString(),
        'byteLength': File(path).lengthSync(),
      },
  ];
}

String _sourceSnapshotSha256(List<Map<String, dynamic>> files) {
  final builder = BytesBuilder(copy: false);
  for (final file in files) {
    builder.add(utf8.encode(file['path'] as String));
    builder.addByte(0);
    builder.add(_hexToBytes(file['sha256'] as String));
    builder.addByte(0);
  }
  return sha256.convert(builder.takeBytes()).toString();
}

List<int> _hexToBytes(String value) => [
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
];
