import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import '../test/test_support/tab_reference_manifest.dart';

const _maximumEdgeDelta = 1;
const _maximumSemanticColorDelta = 4;
const _maximumInkDensityDeltaPercent = 5.0;
const _staticPixelChannelTolerance = 12;
const _maximumStaticDifferenceRatio = 0.005;
const _atomicEvidenceDeferredDetail =
    'reference-evidence-deferred: lossless shared navigation source required; '
    'restore in Task 7';

void main(List<String> args) {
  exitCode = runTabTypographyComparison(args);
}

int runTabTypographyComparison(
  List<String> args, {
  StringSink? standardOutput,
  StringSink? errorOutput,
  List<TabReferenceCase> referenceCases = tabReferenceCases,
  List<ReferenceForegroundConsensusGroup>? foregroundConsensusGroups,
  String? referenceDirectory,
}) {
  final output = standardOutput ?? stdout;
  final errors = errorOutput ?? stderr;
  final consensusGroups =
      foregroundConsensusGroups ?? tabReferenceForegroundConsensusGroups;
  late final _ComparisonConfiguration configuration;
  try {
    configuration = _ComparisonConfiguration.parse(args);
  } on _UsageError catch (error) {
    errors.writeln(error.message);
    errors.writeln(_ComparisonConfiguration.usage);
    return 2;
  }

  final selectedCases = configuration.caseId == null
      ? referenceCases
      : referenceCases
            .where((referenceCase) => referenceCase.id == configuration.caseId)
            .toList(growable: false);
  if (selectedCases.isEmpty) {
    errors.writeln('Unknown reference parity case: ${configuration.caseId}.');
    return 2;
  }

  final manifestErrors = _validateManifest(referenceCases, consensusGroups);
  if (manifestErrors.isNotEmpty) {
    errors.writeln('Invalid reference parity manifest:');
    for (final error in manifestErrors) {
      errors.writeln('- $error');
    }
    return 2;
  }

  late final List<_DecodedComparisonCase> decodedCases;
  try {
    decodedCases = _preflightInputs(
      referenceCases,
      candidateDirectory: configuration.candidateDirectory,
      referenceDirectory: referenceDirectory,
    );
  } on _ComparisonInputError catch (error) {
    errors.writeln(error.message);
    return 2;
  } on FileSystemException catch (error) {
    errors.writeln('Could not read comparison input: ${error.message}');
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

  final report = _CsvReport(
    deferCanonicalReferenceFailures: identical(
      referenceCases,
      tabReferenceCases,
    ),
  );
  var failed = false;
  try {
    final foregroundConsensus = _buildReferenceForegroundConsensus(
      decodedCases,
      consensusGroups,
    );
    for (final decodedCase in decodedCases.where(
      (item) => selectedCases.contains(item.referenceCase),
    )) {
      final referenceCase = decodedCase.referenceCase;
      final reference = decodedCase.reference;
      final candidate = decodedCase.candidate;
      final calibratedRoles = _calibrateReferenceForegroundRoles(
        referenceCase,
        reference,
      );
      final calibratedSurfaces = _calibrateSurfaceRoles(
        referenceCase,
        reference,
        candidate,
      );

      final masks = _MaskMap(
        width: reference.width,
        height: reference.height,
        masks: referenceCase.dynamicMaskRegions,
      );
      final globalRoleSeeds = _measureGlobalRoleSeeds(
        referenceCase,
        reference,
        masks,
        calibratedRoles,
        calibratedSurfaces,
      );
      final staticAudit = _StaticPixelAudit.measure(
        reference: reference,
        candidate: candidate,
        masks: masks,
        createArtifacts: artifactDirectory != null,
      );
      final identicalRaster = _imagesEqual(reference, candidate);
      final roleAudit = identicalRaster
          ? const _RoleAuditSummary.empty()
          : _measureRoleAudit(
              referenceCase,
              reference,
              candidate,
              masks,
              calibratedRoles,
              calibratedSurfaces,
              globalRoleSeeds,
              foregroundConsensus,
              configuration.renderer,
              staticAudit,
            );
      final shadowAudit = _measureShadowAudit(
        referenceCase,
        reference,
        candidate,
        masks,
      );

      for (final surface in referenceCase.surfaceRegions) {
        final scopedForeground = roleAudit.scoped(
          surface.foregroundRegionNames,
        );
        final transitionOwnership = _measureForegroundTransitionOwnership(
          referenceCase,
          reference,
          candidate,
          surface.foregroundRegionNames,
          calibratedRoles,
          calibratedSurfaces,
          masks,
        );
        failed |= _writeSurfaceResult(
          report,
          configuration,
          referenceCase,
          surface: surface,
          result: _measureSurfaceRegion(
            reference,
            candidate,
            surface,
            masks,
            {...scopedForeground.ownedPixels(), ...transitionOwnership},
            calibratedSurfaces[surface.surfaceRole]!,
            calibratedSurfaces[surface.surroundingRole]!,
            identicalRaster: identicalRaster,
          ),
        );
      }

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
        result: canvasResult,
      );

      for (final region in referenceCase.visualRegions) {
        if ((region.requiredForegroundRoles.isNotEmpty ||
                region.shadowRegionNames.isNotEmpty) &&
            !identicalRaster) {
          failed |= _writeCompositeRoleResult(
            report,
            configuration,
            referenceCase,
            region: region,
            calibratedRoles: calibratedRoles,
            roleAudit: roleAudit,
            reference: reference,
            candidate: candidate,
            masks: masks,
            shadowAudit: shadowAudit,
          );
          continue;
        }
        failed |= _writeStaticResult(
          report,
          configuration,
          referenceCase,
          recordType: 'static-region',
          regionType: region.type.name,
          regionName: region.name,
          result: staticAudit.resultFor(region.rect),
        );
      }
      for (final control in referenceCase.staticControlRegions) {
        final role = referenceCase.foregroundRoleByRegion[control.name];
        if (role != null && !identicalRaster) {
          final rawResult = staticAudit.resultFor(control.rect);
          final surfaceRole = referenceCase.surfaceRoleByRegion[control.name]!;
          try {
            failed |= _writeCalibratedControlResult(
              report,
              configuration,
              referenceCase,
              control: control,
              rawResult: rawResult,
              referenceRole: calibratedRoles[role]!,
              reference: reference,
              candidate: candidate,
              masks: masks,
              calibratedSurface: calibratedSurfaces[surfaceRole]!,
              hasGlobalRoleSeed: globalRoleSeeds.contains((role, surfaceRole)),
              referenceConsensus: foregroundConsensus.forMember(
                referenceCase.id,
                control.name,
              ),
            );
          } on StateError catch (error) {
            failed = true;
            _writeCalibratedControlMeasurementFailure(
              report,
              configuration,
              referenceCase,
              control: control,
              rawResult: rawResult,
              referenceRole: calibratedRoles[role]!,
              error: error,
            );
          }
          continue;
        }
        failed |= _writeStaticResult(
          report,
          configuration,
          referenceCase,
          recordType: 'static-control',
          regionType: 'control',
          regionName: control.name,
          result: staticAudit.resultFor(control.rect),
        );
      }

      for (final shadow in referenceCase.shadowRegions) {
        failed |= _writeShadowResult(
          report,
          configuration,
          referenceCase,
          shadow: shadow,
          result: shadowAudit.results[shadow.name]!,
        );
      }

      for (final region in referenceCase.staticTextRegions) {
        if (region.auditMode == StaticTextAuditMode.dynamicOnly) {
          final mask = _coveringDynamicMask(referenceCase, region);
          if (mask == null) {
            errors.writeln(
              '${referenceCase.id}: dynamic-only text ${region.name} must be '
              'fully covered by one reasoned dynamic mask.',
            );
            return 2;
          }
          report.add(
            recordType: 'text',
            renderer: configuration.renderer.name,
            caseId: referenceCase.id,
            regionType: 'dynamicText',
            regionName: region.name,
            referenceBounds: region.referenceRect.toString(),
            candidateBounds: region.candidateRect.toString(),
            manifestInkHint: _MeasuredInk.fromReference(region.ink).toString(),
            status: 'SKIP',
            details:
                'dynamic-only text excluded by reasoned mask: ${mask.reason}',
          );
          continue;
        }
        final assignedRole = referenceCase.foregroundRoleByRegion[region.name];
        if (assignedRole != null && !identicalRaster) {
          final surfaceRole = referenceCase.surfaceRoleByRegion[region.name]!;
          try {
            failed |= _writeCalibratedTextResult(
              report,
              configuration,
              referenceCase,
              region: region,
              referenceRole: calibratedRoles[assignedRole]!,
              reference: reference,
              candidate: candidate,
              masks: masks,
              calibratedSurface: calibratedSurfaces[surfaceRole]!,
              hasGlobalRoleSeed: globalRoleSeeds.contains((
                assignedRole,
                surfaceRole,
              )),
              referenceConsensus: foregroundConsensus.forMember(
                referenceCase.id,
                region.name,
              ),
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
              manifestInkHint: _MeasuredInk.fromReference(
                region.ink,
              ).toString(),
              measuredReferenceForeground: calibratedRoles[assignedRole]
                  .toString(),
              foregroundColorDelta: 'one-sided',
              status: 'FAIL',
              details: 'measurement failed: ${error.message}',
            );
          }
          continue;
        }
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
          final role = referenceCase.foregroundRoleByRegion[region.name];
          final measuredReferenceInk = role == null || identicalRaster
              ? referenceSample.semanticInk
              : calibratedRoles[role]!;
          final semanticInkDelta = measuredReferenceInk.edgeDelta(
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
            measuredReferenceInk: measuredReferenceInk.toString(),
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
      File(
        '${artifactDirectory.path}/atomic-deferred-evidence.csv',
      ).writeAsStringSync(report.atomicEvidenceContents);
      File(
        '${artifactDirectory.path}/surface-deferred-evidence.csv',
      ).writeAsStringSync(report.surfaceEvidenceContents);
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
      'regions: measured surface and foreground RGB <= '
      '$_maximumSemanticColorDelta/channel, feature edge <= '
      '$_maximumEdgeDelta physical px, and differing pixel ratio <= '
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
  required _StaticRegionResult result,
}) {
  final surfaceFailed = result.surfaceColorDelta > _maximumSemanticColorDelta;
  final foregroundColorFailed =
      result.hasOneSidedMeasuredForeground ||
      result.foregroundColorDelta > _maximumSemanticColorDelta;
  final edgeFailed =
      result.hasOneSidedForeground ||
      result.featureEdgeDelta > _maximumEdgeDelta;
  final residualFailed =
      result.differingPixelRatio > _maximumStaticDifferenceRatio;
  final regionFailed =
      result.auditedPixelCount == 0 ||
      surfaceFailed ||
      foregroundColorFailed ||
      edgeFailed ||
      residualFailed;
  final details = <String>[
    if (result.auditedPixelCount == 0)
      'no unmasked static pixels remain to audit',
    if (surfaceFailed)
      'surface RGB delta ${result.surfaceColorDelta} exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (result.hasOneSidedMeasuredForeground)
      'measured foreground exists on only one side',
    if (!result.hasOneSidedMeasuredForeground && foregroundColorFailed)
      'foreground RGB delta ${result.foregroundColorDelta} exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (result.hasOneSidedForeground) 'foreground exists on only one side',
    if (!result.hasOneSidedForeground &&
        result.featureEdgeDelta > _maximumEdgeDelta)
      'feature edge delta ${result.featureEdgeDelta} exceeds '
          '$_maximumEdgeDelta physical px',
    if (residualFailed)
      '${result.differingPixelCount} pixels differ beyond '
          '$_staticPixelChannelTolerance RGB/channel; ratio '
          '${(result.differingPixelRatio * 100).toStringAsFixed(3)}% '
          'exceeds ${(_maximumStaticDifferenceRatio * 100).toStringAsFixed(1)}%',
  ];
  report.add(
    recordType: recordType,
    renderer: configuration.renderer.name,
    caseId: referenceCase.id,
    regionType: regionType,
    regionName: regionName,
    referenceBounds: result.referenceFeatureBounds?.toString() ?? 'none',
    candidateBounds: result.candidateFeatureBounds?.toString() ?? 'none',
    edgeDelta: result.hasOneSidedForeground
        ? 'one-sided'
        : '${result.featureEdgeDelta}',
    measuredReferenceInk: result.referenceSurface.toString(),
    candidateInk: result.candidateSurface.toString(),
    semanticInkDelta: '${result.surfaceColorDelta}',
    measuredReferenceForeground: result.referenceForeground?.toString() ?? '',
    candidateForeground: result.candidateForeground?.toString() ?? '',
    foregroundColorDelta: result.hasOneSidedMeasuredForeground
        ? 'one-sided'
        : '${result.foregroundColorDelta}',
    differingPixelCount: '${result.differingPixelCount}',
    auditedPixelCount: '${result.auditedPixelCount}',
    differingPixelRatio: result.differingPixelRatio.toStringAsFixed(6),
    status: regionFailed ? 'FAIL' : 'PASS',
    details: details.join('; '),
  );
  return regionFailed;
}

Map<String, _MeasuredInk> _calibrateReferenceForegroundRoles(
  TabReferenceCase referenceCase,
  image.Image reference,
) {
  final samples = <String, List<_MeasuredInk>>{};
  for (final interior in referenceCase.referenceForegroundInteriors) {
    final roleSamples = samples.putIfAbsent(
      interior.role,
      () => <_MeasuredInk>[],
    );
    for (var y = interior.rect.top; y < interior.rect.bottom; y++) {
      for (var x = interior.rect.left; x < interior.rect.right; x++) {
        final pixel = reference.getPixel(x, y);
        roleSamples.add(
          _MeasuredInk(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()),
        );
      }
    }
  }
  final requiredRoles = <String>{
    ...referenceCase.foregroundRoleByRegion.values,
    for (final region in referenceCase.visualRegions)
      ...region.requiredForegroundRoles,
  };
  final result = <String, _MeasuredInk>{};
  for (final role in requiredRoles) {
    final roleSamples = samples[role] ?? const <_MeasuredInk>[];
    if (roleSamples.isEmpty) {
      throw _ComparisonInputError(
        '${referenceCase.id}: foreground role $role has no decoded-reference '
        'interior samples.',
      );
    }
    var largestCluster = <_MeasuredInk>[];
    for (final center in roleSamples) {
      final cluster = roleSamples
          .where((sample) => sample.edgeDelta(center) <= 2)
          .toList(growable: false);
      if (cluster.length > largestCluster.length) largestCluster = cluster;
    }
    if (largestCluster.length != roleSamples.length) {
      throw _ComparisonInputError(
        '${referenceCase.id}: foreground role $role has inconsistent '
        'decoded-reference interior samples (cluster '
        '${largestCluster.length}/${roleSamples.length}, radius 2).',
      );
    }
    final medoids = [...largestCluster]
      ..sort((left, right) {
        int cost(_MeasuredInk candidate) => largestCluster.fold(
          0,
          (sum, sample) => sum + candidate.edgeDelta(sample),
        );
        final costDelta = cost(left).compareTo(cost(right));
        if (costDelta != 0) return costDelta;
        return left.rgbKey.compareTo(right.rgbKey);
      });
    result[role] = medoids.first;
  }
  return result;
}

_ReferenceForegroundConsensusIndex _buildReferenceForegroundConsensus(
  List<_DecodedComparisonCase> decodedCases,
  List<ReferenceForegroundConsensusGroup> groups,
) {
  final decodedById = {
    for (final item in decodedCases) item.referenceCase.id: item,
  };
  final byMember = <(String, String), _ReferenceForegroundConsensus>{};
  for (final group in groups) {
    final members = <_ReferenceCoverage>[];
    final provenanceMembers = <String>[];
    for (final caseId in group.memberCaseIds) {
      final decoded = decodedById[caseId]!;
      final referenceCase = decoded.referenceCase;
      final calibratedRoles = _calibrateReferenceForegroundRoles(
        referenceCase,
        decoded.reference,
      );
      final calibratedSurfaces = _calibrateSurfaceRoles(
        referenceCase,
        decoded.reference,
        decoded.candidate,
      );
      final masks = _MaskMap(
        width: decoded.reference.width,
        height: decoded.reference.height,
        masks: referenceCase.dynamicMaskRegions,
      );
      final name = group.key.controlIdentity;
      final role = calibratedRoles[group.key.semanticRole]!;
      final surface = calibratedSurfaces[group.key.surfaceRole]!.reference;
      ReferenceStaticControlRegion? control;
      for (final item in referenceCase.staticControlRegions) {
        if (item.name == name) control = item;
      }
      StaticTextRegion? text;
      for (final item in referenceCase.staticTextRegions) {
        if (item.name == name && item.auditMode == StaticTextAuditMode.static) {
          text = item;
        }
      }
      if ((control == null) == (text == null)) {
        throw _ComparisonInputError(
          '$caseId: foreground consensus membership $name must resolve to '
          'exactly one eligible atomic reference.',
        );
      }
      final rect = control?.rect ?? text!.referenceRect;
      final tolerance =
          control?.geometryColorTolerance ?? text!.geometryColorTolerance;
      final sample = _measureText(
        decoded.reference,
        rect,
        role.toReferenceInk(),
        masks,
        geometryColorTolerance: tolerance,
        measureLargestGeometryComponent:
            text?.measureLargestGeometryComponent ?? false,
      );
      members.add(
        _classifyReferenceCoverage(sample.geometryPixels, role, surface),
      );
      provenanceMembers.add(
        '$caseId:${decoded.referencePath}#${referenceCase.referenceSha256}',
      );
    }
    final requiredSupport = group.memberCaseIds.length ~/ 2 + 1;
    final allPoints = <(int, int)>{
      for (final member in members) ...member.weights.keys,
    };
    int median(List<int> values) {
      values.sort();
      final middle = values.length ~/ 2;
      return values.length.isOdd
          ? values[middle]
          : (values[middle - 1] + values[middle]) ~/ 2;
    }

    final weights = <(int, int), int>{};
    final seeds = <(int, int)>{};
    for (final point in allPoints) {
      final supportCount = members
          .where((member) => member.weights.containsKey(point))
          .length;
      if (supportCount < requiredSupport) continue;
      weights[point] = median([
        for (final member in members) member.weights[point] ?? 0,
      ]);
      final seedCount = members
          .where((member) => member.seedPixels.contains(point))
          .length;
      if (seedCount >= requiredSupport) seeds.add(point);
    }
    final provenance =
        'key=${group.key}; members=${provenanceMembers.join('|')}; '
        'count=${members.length}; strict-majority '
        '$requiredSupport/${members.length}; coverage=median-with-zero';
    final consensus = _ReferenceForegroundConsensus(
      key: group.key,
      coverage: _ReferenceCoverage(weights, seeds),
      provenance: provenance,
    );
    for (final caseId in group.memberCaseIds) {
      byMember[(caseId, group.key.controlIdentity)] = consensus;
    }
  }
  return _ReferenceForegroundConsensusIndex(byMember);
}

_ReferenceCoverage _classifyReferenceCoverage(
  List<_InkPixel> geometryPixels,
  _MeasuredInk role,
  _MeasuredInk surface,
) {
  const coverageWeightScale = 1000000;
  final projections = <(int, int), double>{};
  final seeds = <(int, int)>{};
  for (final pixel in geometryPixels) {
    final projection = _projectCoverage(pixel, role, surface);
    projections[(pixel.x, pixel.y)] = projection.alpha;
    if (_MeasuredInk(pixel.red, pixel.green, pixel.blue).edgeDelta(role) <=
            _staticPixelChannelTolerance &&
        projection.reconstructionError <= _staticPixelChannelTolerance) {
      seeds.add((pixel.x, pixel.y));
    }
  }
  final opaqueAlpha = projections.values.fold<double>(0, math.max);
  return _ReferenceCoverage({
    if (opaqueAlpha > 0)
      for (final entry in projections.entries)
        entry.key:
            ((entry.value / opaqueAlpha).clamp(0.0, 1.0) * coverageWeightScale)
                .round(),
  }, seeds);
}

Map<String, _SurfaceCalibration> _calibrateSurfaceRoles(
  TabReferenceCase referenceCase,
  image.Image reference,
  image.Image candidate,
) {
  final referenceSamples = <String, List<_InkPixel>>{};
  final candidateSamples = <String, List<_InkPixel>>{};
  for (final interior in referenceCase.referenceSurfaceInteriors) {
    final referenceRoleSamples = referenceSamples.putIfAbsent(
      interior.role,
      () => <_InkPixel>[],
    );
    final candidateRoleSamples = candidateSamples.putIfAbsent(
      interior.role,
      () => <_InkPixel>[],
    );
    for (var y = interior.rect.top; y < interior.rect.bottom; y++) {
      for (var x = interior.rect.left; x < interior.rect.right; x++) {
        final referencePixel = reference.getPixel(x, y);
        final candidatePixel = candidate.getPixel(x, y);
        referenceRoleSamples.add(
          _InkPixel(
            x,
            y,
            referencePixel.r.toInt(),
            referencePixel.g.toInt(),
            referencePixel.b.toInt(),
          ),
        );
        candidateRoleSamples.add(
          _InkPixel(
            x,
            y,
            candidatePixel.r.toInt(),
            candidatePixel.g.toInt(),
            candidatePixel.b.toInt(),
          ),
        );
      }
    }
  }
  final requiredRoles = <String>{
    ...referenceCase.surfaceRoleByRegion.values,
    for (final region in referenceCase.surfaceRegions) region.surfaceRole,
    for (final region in referenceCase.surfaceRegions) region.surroundingRole,
  };
  final result = <String, _SurfaceCalibration>{};
  for (final role in requiredRoles) {
    final referenceRoleSamples = referenceSamples[role] ?? const <_InkPixel>[];
    final candidateRoleSamples = candidateSamples[role] ?? const <_InkPixel>[];
    if (referenceRoleSamples.isEmpty || candidateRoleSamples.isEmpty) {
      throw _ComparisonInputError(
        '${referenceCase.id}: surface role $role has no corresponding '
        'reference/candidate interior samples.',
      );
    }
    result[role] = _SurfaceCalibration(
      _MeasuredInk.modeFromPixels(referenceRoleSamples),
      _MeasuredInk.modeFromPixels(candidateRoleSamples),
      referenceRoleSamples,
    );
  }
  return result;
}

Set<(String, String)> _measureGlobalRoleSeeds(
  TabReferenceCase referenceCase,
  image.Image reference,
  _MaskMap masks,
  Map<String, _MeasuredInk> calibratedRoles,
  Map<String, _SurfaceCalibration> calibratedSurfaces,
) {
  final result = <(String, String)>{};

  void inspect(
    String regionName,
    ReferencePixelRect rect,
    int geometryTolerance,
    bool measureLargestComponent,
  ) {
    final roleName = referenceCase.foregroundRoleByRegion[regionName];
    final surfaceName = referenceCase.surfaceRoleByRegion[regionName];
    if (roleName == null || surfaceName == null) return;
    final role = calibratedRoles[roleName]!;
    final surface = calibratedSurfaces[surfaceName]!;
    if (surface.colorDelta > _maximumSemanticColorDelta) return;
    try {
      final sample = _measureText(
        reference,
        rect,
        role.toReferenceInk(),
        masks,
        geometryColorTolerance: geometryTolerance,
        measureLargestGeometryComponent: measureLargestComponent,
      );
      if (sample.geometryPixels.any((pixel) {
        final seedDelta = _MeasuredInk(
          pixel.red,
          pixel.green,
          pixel.blue,
        ).edgeDelta(role);
        return seedDelta <= _staticPixelChannelTolerance &&
            _projectCoverage(
                  pixel,
                  role,
                  surface.reference,
                ).reconstructionError <=
                _staticPixelChannelTolerance;
      })) {
        result.add((roleName, surfaceName));
      }
    } on StateError {
      // The local atomic writer emits the controlled missing-support failure.
    }
  }

  for (final control in referenceCase.staticControlRegions) {
    inspect(control.name, control.rect, control.geometryColorTolerance, false);
  }
  for (final region in referenceCase.staticTextRegions) {
    if (region.auditMode != StaticTextAuditMode.static) continue;
    inspect(
      region.name,
      region.referenceRect,
      region.geometryColorTolerance,
      region.measureLargestGeometryComponent,
    );
  }
  return result;
}

({double alpha, int reconstructionError}) _projectCoverage(
  _InkPixel pixel,
  _MeasuredInk role,
  _MeasuredInk surface,
) {
  final surfaceToForeground = <double>[
    (role.red - surface.red).toDouble(),
    (role.green - surface.green).toDouble(),
    (role.blue - surface.blue).toDouble(),
  ];
  final denominator = surfaceToForeground.fold<double>(
    0,
    (sum, channel) => sum + channel * channel,
  );
  if (denominator == 0) {
    return (alpha: 0, reconstructionError: 255);
  }
  final surfaceToPixel = <double>[
    (pixel.red - surface.red).toDouble(),
    (pixel.green - surface.green).toDouble(),
    (pixel.blue - surface.blue).toDouble(),
  ];
  var alpha = 0.0;
  for (var index = 0; index < 3; index++) {
    alpha += surfaceToPixel[index] * surfaceToForeground[index];
  }
  alpha = (alpha / denominator).clamp(0.0, 1.0);
  final reconstructed = <double>[
    surface.red + alpha * surfaceToForeground[0],
    surface.green + alpha * surfaceToForeground[1],
    surface.blue + alpha * surfaceToForeground[2],
  ];
  final reconstructionError = _maximum(
    (pixel.red - reconstructed[0]).abs().round(),
    (pixel.green - reconstructed[1]).abs().round(),
    (pixel.blue - reconstructed[2]).abs().round(),
  );
  return (alpha: alpha, reconstructionError: reconstructionError);
}

_RoleAuditSummary _measureRoleAudit(
  TabReferenceCase referenceCase,
  image.Image reference,
  image.Image candidate,
  _MaskMap masks,
  Map<String, _MeasuredInk> calibratedRoles,
  Map<String, _SurfaceCalibration> calibratedSurfaces,
  Set<(String, String)> globalRoleSeeds,
  _ReferenceForegroundConsensusIndex foregroundConsensus,
  _CandidateRenderer renderer,
  _StaticPixelAudit staticAudit,
) {
  final samples = <String, List<_MeasuredInk>>{};
  final referenceBounds = <String, _InkBounds>{};
  final candidateBounds = <String, _InkBounds>{};
  final residuals = <String, _RoleResidualResult>{};
  final measurements = <String, _RoleMeasurement>{};
  final failedRegionNames = <String>{};

  void addMeasurement(
    String role,
    String surfaceRole,
    _SurfaceCalibration surface,
    ReferencePixelRect referenceRect,
    ReferencePixelRect candidateRect,
    _TextSample referenceSample,
    _TextSample candidateSample,
    String regionName,
    bool enforceDensity,
  ) {
    final residual = _measureRoleResidual(
      candidateSample.geometryPixels,
      calibratedRoles[role]!,
      surface,
      hasGlobalRoleSeed: globalRoleSeeds.contains((role, surfaceRole)),
      referenceConsensus: foregroundConsensus.forMember(
        referenceCase.id,
        regionName,
      ),
    );
    if (residual.referenceBounds case final bounds?) {
      referenceBounds[role] = _mergeBounds(referenceBounds[role], bounds);
    }
    if (residual.candidateBounds case final bounds?) {
      candidateBounds[role] = _mergeBounds(candidateBounds[role], bounds);
    }
    final candidateInk =
        residual.candidateCoreInk ?? candidateSample.semanticInk;
    samples.putIfAbsent(role, () => <_MeasuredInk>[]).add(candidateInk);
    residuals[role] = (residuals[role] ?? const _RoleResidualResult.empty())
        .plus(residual);
    measurements[regionName] = _RoleMeasurement(
      role: role,
      candidateInk: candidateInk,
      referenceBounds: residual.referenceBounds ?? referenceSample.bounds,
      candidateBounds: residual.candidateBounds ?? candidateSample.bounds,
      residual: residual,
      failed:
          calibratedRoles[role]!.edgeDelta(candidateInk) >
              _maximumSemanticColorDelta ||
          residual.edgeDelta > _maximumEdgeDelta ||
          residual.differingPixelRatio > _maximumStaticDifferenceRatio ||
          residual.invalidPixelCount > 0 ||
          residual.hasMissingCore ||
          !residual.hasGlobalRoleSeed ||
          !residual.hasReciprocalSeedCoverage ||
          residual.hasComponentCountMismatch ||
          !residual.hasComponentTopologyMatch ||
          residual.coverageMassFailed ||
          residual.coverageCentroidFailed ||
          residual.coverageGridFailed ||
          surface.colorDelta > _maximumSemanticColorDelta ||
          (enforceDensity &&
              residual.coverageDensityDeltaPercent >
                  _maximumInkDensityDeltaPercent),
    );
  }

  for (final control in referenceCase.staticControlRegions) {
    final role = referenceCase.foregroundRoleByRegion[control.name];
    if (role == null) continue;
    final surfaceRole = referenceCase.surfaceRoleByRegion[control.name];
    if (surfaceRole == null) {
      failedRegionNames.add(control.name);
      continue;
    }
    try {
      final referenceSample = _measureText(
        reference,
        control.rect,
        calibratedRoles[role]!.toReferenceInk(),
        masks,
        geometryColorTolerance: control.geometryColorTolerance,
        measureLargestGeometryComponent: false,
      );
      final candidateSample = _measureText(
        candidate,
        control.rect,
        calibratedRoles[role]!.toReferenceInk(),
        masks,
        geometryColorTolerance: control.geometryColorTolerance,
        measureLargestGeometryComponent: false,
      );
      addMeasurement(
        role,
        surfaceRole,
        calibratedSurfaces[surfaceRole]!,
        control.rect,
        control.rect,
        referenceSample,
        candidateSample,
        control.name,
        false,
      );
    } on StateError {
      // The assigned atomic row emits deterministic measurement-failure
      // evidence; a composite row observes the role as missing.
      failedRegionNames.add(control.name);
    }
  }
  for (final region in referenceCase.staticTextRegions) {
    final role = referenceCase.foregroundRoleByRegion[region.name];
    if (role == null || region.auditMode != StaticTextAuditMode.static) {
      continue;
    }
    final surfaceRole = referenceCase.surfaceRoleByRegion[region.name];
    if (surfaceRole == null) {
      failedRegionNames.add(region.name);
      continue;
    }
    try {
      final referenceSample = _measureText(
        reference,
        region.referenceRect,
        calibratedRoles[role]!.toReferenceInk(),
        masks,
        geometryColorTolerance: region.geometryColorTolerance,
        measureLargestGeometryComponent: region.measureLargestGeometryComponent,
      );
      final candidateSample = _measureText(
        candidate,
        region.candidateRect,
        calibratedRoles[role]!.toReferenceInk(),
        masks,
        geometryColorTolerance: _candidateGeometryTolerance(region, renderer),
        measureLargestGeometryComponent: region.measureLargestGeometryComponent,
      );
      addMeasurement(
        role,
        surfaceRole,
        calibratedSurfaces[surfaceRole]!,
        region.referenceRect,
        region.candidateRect,
        referenceSample,
        candidateSample,
        region.name,
        false,
      );
    } on StateError {
      // The static-text row emits deterministic measurement-failure evidence;
      // a composite row observes the role as missing.
      failedRegionNames.add(region.name);
    }
  }
  return _RoleAuditSummary(
    candidateSamples: {
      for (final entry in samples.entries)
        entry.key: _MeasuredInk.clusterMedoid(entry.value, radius: 2),
    },
    referenceBounds: referenceBounds,
    candidateBounds: candidateBounds,
    residuals: residuals,
    measurements: measurements,
    failedRegionNames: failedRegionNames,
  );
}

_InkBounds _mergeBounds(_InkBounds? current, _InkBounds next) => current == null
    ? next
    : _InkBounds(
        math.min(current.left, next.left),
        math.min(current.top, next.top),
        math.max(current.right, next.right),
        math.max(current.bottom, next.bottom),
      );

_InkBounds? _mergeOptionalBounds(_InkBounds? current, _InkBounds? next) =>
    next == null ? current : _mergeBounds(current, next);

_RoleResidualResult _measureRoleResidual(
  List<_InkPixel> candidateGeometryPixels,
  _MeasuredInk role,
  _SurfaceCalibration surface, {
  required bool hasGlobalRoleSeed,
  required _ReferenceForegroundConsensus referenceConsensus,
}) {
  const coverageWeightScale = 1000000;
  final referenceWeights = referenceConsensus.coverage.weights;
  final referenceSeeds = referenceConsensus.coverage.seedPixels;

  final candidateValidWeights = <(int, int), int>{};
  final candidateCores = <_InkPixel>[];
  var candidateInvalidPixels = 0;
  for (final pixel in candidateGeometryPixels) {
    final projection = _projectCoverage(pixel, role, surface.candidate);
    if (projection.reconstructionError > _maximumSemanticColorDelta) {
      candidateInvalidPixels++;
      continue;
    }
    candidateValidWeights[(pixel.x, pixel.y)] =
        (projection.alpha * coverageWeightScale).round();
    if (_MeasuredInk(pixel.red, pixel.green, pixel.blue).edgeDelta(role) <=
        _maximumSemanticColorDelta) {
      candidateCores.add(pixel);
    }
  }

  final candidateWeights = candidateValidWeights;

  final matching = _maximumAtomicCoverageMatches(
    referenceWeights,
    candidateWeights,
  );
  final differing =
      referenceWeights.length + candidateWeights.length - (matching.count * 2);
  final candidateCoreInk = candidateCores.isEmpty
      ? null
      : _MeasuredInk.clusterMedoid([
          for (final pixel in candidateCores)
            _MeasuredInk(pixel.red, pixel.green, pixel.blue),
        ], radius: 2);
  final referenceComponents = _coverageComponents(referenceWeights.keys);
  final candidateComponents = _coverageComponents(candidateWeights.keys);
  final hasComponentTopologyMatch = _componentsHaveLocalBijection(
    referenceComponents,
    candidateComponents,
  );
  final reciprocalSeedCoverage =
      referenceSeeds.every(
        (seed) => _hasCoveragePointWithin(
          candidateWeights.keys,
          seed,
          _maximumEdgeDelta,
        ),
      ) &&
      candidateCores.every(
        (core) => _hasCoveragePointWithin(referenceWeights.keys, (
          core.x,
          core.y,
        ), _maximumEdgeDelta),
      );
  final referenceBounds = _boundsFromPoints(referenceWeights.keys);
  final candidateBounds = _boundsFromPoints(candidateWeights.keys);
  final referenceMass = _coverageMass(referenceWeights);
  final candidateMass = _coverageMass(candidateWeights);
  final referenceCentroid = _coverageCentroid(referenceWeights);
  final candidateCentroid = _coverageCentroid(candidateWeights);
  final gridTotalVariationPercent =
      referenceBounds == null || candidateBounds == null
      ? double.infinity
      : _coverageGridTotalVariationPercent(
          referenceWeights,
          candidateWeights,
          referenceBounds,
          candidateBounds,
        );
  return _RoleResidualResult(
    differing,
    referenceWeights.length + candidateWeights.length,
    candidateCoreInk: candidateCoreInk,
    referencePixels: referenceWeights.keys.toSet(),
    candidatePixels: candidateWeights.keys.toSet(),
    referenceBounds: referenceBounds,
    candidateBounds: candidateBounds,
    candidateInvalidPixelCount: candidateInvalidPixels,
    hasMissingCore: referenceWeights.isEmpty || candidateCores.isEmpty,
    hasGlobalRoleSeed: hasGlobalRoleSeed,
    hasReciprocalSeedCoverage: reciprocalSeedCoverage,
    referenceComponentCount: referenceComponents.length,
    candidateComponentCount: candidateComponents.length,
    hasComponentTopologyMatch: hasComponentTopologyMatch,
    referenceComponentSummary: _describeCoverageComponents(referenceComponents),
    candidateComponentSummary: _describeCoverageComponents(candidateComponents),
    referenceCoverageMass: referenceMass,
    candidateCoverageMass: candidateMass,
    referenceCoverageCentroid: referenceCentroid,
    candidateCoverageCentroid: candidateCentroid,
    coverageGridTotalVariationPercent: gridTotalVariationPercent,
    supportMismatchSummary: _supportMismatchSummary(
      referenceWeights.keys.toSet().difference(matching.referenceMatched),
      candidateWeights.keys.toSet().difference(matching.candidateMatched),
    ),
    consensusProvenance: referenceConsensus.provenance,
  );
}

String _supportMismatchSummary(
  Set<(int, int)> reference,
  Set<(int, int)> candidate,
) {
  String points(Set<(int, int)> values) {
    final sorted = values.toList()..sort(_comparePixelPoint);
    return sorted.map((point) => '${point.$1}:${point.$2}').join('|');
  }

  return 'reference ${points(reference)}; candidate ${points(candidate)}';
}

List<Set<(int, int)>> _coverageComponents(Iterable<(int, int)> points) {
  final remaining = points.toSet();
  final result = <Set<(int, int)>>[];
  while (remaining.isNotEmpty) {
    final seed = remaining.first;
    remaining.remove(seed);
    final component = <(int, int)>{seed};
    final queue = <(int, int)>[seed];
    for (var index = 0; index < queue.length; index++) {
      final point = queue[index];
      for (var offsetY = -1; offsetY <= 1; offsetY++) {
        for (var offsetX = -1; offsetX <= 1; offsetX++) {
          if (offsetX == 0 && offsetY == 0) continue;
          final neighbour = (point.$1 + offsetX, point.$2 + offsetY);
          if (remaining.remove(neighbour)) {
            component.add(neighbour);
            queue.add(neighbour);
          }
        }
      }
    }
    result.add(component);
  }
  return result;
}

String _describeCoverageComponents(List<Set<(int, int)>> components) {
  final descriptions = <String>[];
  for (final component in components) {
    final bounds = _boundsFromPoints(component)!;
    var x = 0;
    var y = 0;
    for (final point in component) {
      x += point.$1;
      y += point.$2;
    }
    descriptions.add(
      '$bounds@(${(x / component.length).toStringAsFixed(2)},'
      '${(y / component.length).toStringAsFixed(2)})#${component.length}',
    );
  }
  descriptions.sort();
  return descriptions.join('|');
}

bool _componentsHaveLocalBijection(
  List<Set<(int, int)>> reference,
  List<Set<(int, int)>> candidate,
) {
  if (reference.isEmpty || reference.length != candidate.length) return false;
  ({Set<(int, int)> points, _InkBounds bounds, double x, double y}) describe(
    Set<(int, int)> points,
  ) {
    final bounds = _boundsFromPoints(points)!;
    var x = 0;
    var y = 0;
    for (final point in points) {
      x += point.$1;
      y += point.$2;
    }
    return (
      points: points,
      bounds: bounds,
      x: x / points.length,
      y: y / points.length,
    );
  }

  int compareDescriptions(
    ({Set<(int, int)> points, _InkBounds bounds, double x, double y}) left,
    ({Set<(int, int)> points, _InkBounds bounds, double x, double y}) right,
  ) {
    for (final comparison in <int>[
      left.bounds.top.compareTo(right.bounds.top),
      left.bounds.left.compareTo(right.bounds.left),
      left.bounds.bottom.compareTo(right.bounds.bottom),
      left.bounds.right.compareTo(right.bounds.right),
    ]) {
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  final referenceComponents = reference.map(describe).toList()
    ..sort(compareDescriptions);
  final candidateComponents = candidate.map(describe).toList()
    ..sort(compareDescriptions);
  double? pairCost(int referenceIndex, int candidateIndex) {
    final left = referenceComponents[referenceIndex];
    final right = candidateComponents[candidateIndex];
    final expandedBoundsOverlap =
        left.bounds.left - _maximumEdgeDelta <= right.bounds.right &&
        right.bounds.left - _maximumEdgeDelta <= left.bounds.right &&
        left.bounds.top - _maximumEdgeDelta <= right.bounds.bottom &&
        right.bounds.top - _maximumEdgeDelta <= left.bounds.bottom;
    final centroidDeltaX = (left.x - right.x).abs();
    final centroidDeltaY = (left.y - right.y).abs();
    final edgeDelta = left.bounds.edgeDelta(right.bounds);
    if (!expandedBoundsOverlap ||
        edgeDelta > _maximumEdgeDelta ||
        centroidDeltaX > _maximumEdgeDelta ||
        centroidDeltaY > _maximumEdgeDelta) {
      return null;
    }
    return edgeDelta * 1000000 +
        (centroidDeltaX + centroidDeltaY) * 1000 +
        candidateIndex;
  }

  final memo = <(int, int), double?>{};
  double? solve(int referenceIndex, int usedCandidates) {
    if (referenceIndex == referenceComponents.length) return 0;
    final key = (referenceIndex, usedCandidates);
    if (memo.containsKey(key)) return memo[key];
    double? best;
    for (
      var candidateIndex = 0;
      candidateIndex < candidateComponents.length;
      candidateIndex++
    ) {
      final bit = 1 << candidateIndex;
      if (usedCandidates & bit != 0) continue;
      final cost = pairCost(referenceIndex, candidateIndex);
      if (cost == null) continue;
      final remainder = solve(referenceIndex + 1, usedCandidates | bit);
      if (remainder == null) continue;
      final total = cost + remainder;
      if (best == null || total < best) best = total;
    }
    memo[key] = best;
    return best;
  }

  return solve(0, 0) != null;
}

bool _hasCoveragePointWithin(
  Iterable<(int, int)> points,
  (int, int) target,
  int tolerance,
) => points.any(
  (point) =>
      math.max((point.$1 - target.$1).abs(), (point.$2 - target.$2).abs()) <=
      tolerance,
);

int _coverageMass(Map<(int, int), int> weights) =>
    weights.values.fold(0, (sum, weight) => sum + weight);

({double x, double y})? _coverageCentroid(Map<(int, int), int> weights) {
  final mass = _coverageMass(weights);
  if (mass == 0) return null;
  var weightedX = 0;
  var weightedY = 0;
  for (final entry in weights.entries) {
    weightedX += entry.key.$1 * entry.value;
    weightedY += entry.key.$2 * entry.value;
  }
  return (x: weightedX / mass, y: weightedY / mass);
}

double _coverageGridTotalVariationPercent(
  Map<(int, int), int> reference,
  Map<(int, int), int> candidate,
  _InkBounds referenceBounds,
  _InkBounds candidateBounds,
) {
  final referenceMass = _coverageMass(reference);
  final candidateMass = _coverageMass(candidate);
  if (referenceMass == 0 || candidateMass == 0) return double.infinity;
  final width = referenceBounds.right - referenceBounds.left + 1;
  final height = referenceBounds.bottom - referenceBounds.top + 1;
  int cellIndex((int, int) point) {
    final column = (((point.$1 - referenceBounds.left) * 3) ~/ width).clamp(
      0,
      2,
    );
    final row = (((point.$2 - referenceBounds.top) * 3) ~/ height).clamp(0, 2);
    return row * 3 + column;
  }

  final referenceCells = List<int>.filled(9, 0);
  final candidateCells = List<int>.filled(9, 0);
  for (final entry in reference.entries) {
    referenceCells[cellIndex(entry.key)] += entry.value;
  }
  for (final entry in candidate.entries) {
    final alignedPoint = (
      entry.key.$1 - candidateBounds.left + referenceBounds.left,
      entry.key.$2 - candidateBounds.top + referenceBounds.top,
    );
    candidateCells[cellIndex(alignedPoint)] += entry.value;
  }
  var absoluteDistributionDelta = 0.0;
  for (var index = 0; index < 9; index++) {
    absoluteDistributionDelta +=
        (referenceCells[index] / referenceMass -
                candidateCells[index] / candidateMass)
            .abs();
  }
  return absoluteDistributionDelta * 50;
}

int _comparePixelPoint((int, int) left, (int, int) right) {
  final byY = left.$2.compareTo(right.$2);
  return byY != 0 ? byY : left.$1.compareTo(right.$1);
}

({
  int count,
  Set<(int, int)> referenceMatched,
  Set<(int, int)> candidateMatched,
})
_maximumAtomicCoverageMatches(
  Map<(int, int), int> reference,
  Map<(int, int), int> candidate,
) {
  final referencePoints = reference.keys.toList()..sort(_comparePixelPoint);
  final candidatePoints = candidate.keys.toList()..sort(_comparePixelPoint);
  final candidateMatch = <(int, int), (int, int)>{};

  bool augment((int, int) referencePoint, Set<(int, int)> visitedReferences) {
    if (!visitedReferences.add(referencePoint)) return false;
    for (final candidatePoint in candidatePoints) {
      if (math.max(
            (referencePoint.$1 - candidatePoint.$1).abs(),
            (referencePoint.$2 - candidatePoint.$2).abs(),
          ) >
          _maximumEdgeDelta) {
        continue;
      }
      final pairedReference = candidateMatch[candidatePoint];
      if (pairedReference == null ||
          augment(pairedReference, visitedReferences)) {
        candidateMatch[candidatePoint] = referencePoint;
        return true;
      }
    }
    return false;
  }

  for (final referencePoint in referencePoints) {
    augment(referencePoint, <(int, int)>{});
  }
  return (
    count: candidateMatch.length,
    referenceMatched: candidateMatch.values.toSet(),
    candidateMatched: candidateMatch.keys.toSet(),
  );
}

({
  int count,
  Set<(int, int)> referenceMatched,
  Set<(int, int)> candidateMatched,
})
_maximumCoverageMatches(
  Map<(int, int), int> reference,
  Map<(int, int), int> candidate,
) {
  final referencePoints = reference.keys.toList()..sort(_comparePixelPoint);
  final candidatePoints = candidate.keys.toSet();
  final referenceMatch = <(int, int), (int, int)>{};
  final candidateMatch = <(int, int), (int, int)>{};

  List<(int, int)> eligible((int, int) referencePoint) =>
      <(int, int)>[
        for (
          var offsetY = -_maximumEdgeDelta;
          offsetY <= _maximumEdgeDelta;
          offsetY++
        )
          for (
            var offsetX = -_maximumEdgeDelta;
            offsetX <= _maximumEdgeDelta;
            offsetX++
          )
            if (candidatePoints.contains((
              referencePoint.$1 + offsetX,
              referencePoint.$2 + offsetY,
            )))
              (referencePoint.$1 + offsetX, referencePoint.$2 + offsetY),
      ]..sort((left, right) {
        final leftDistance = math.max(
          (referencePoint.$1 - left.$1).abs(),
          (referencePoint.$2 - left.$2).abs(),
        );
        final rightDistance = math.max(
          (referencePoint.$1 - right.$1).abs(),
          (referencePoint.$2 - right.$2).abs(),
        );
        final byDistance = leftDistance.compareTo(rightDistance);
        return byDistance != 0 ? byDistance : _comparePixelPoint(left, right);
      });

  final distance = <(int, int), int>{};
  bool buildLayers() {
    final queue = <(int, int)>[];
    for (final point in referencePoints) {
      if (!referenceMatch.containsKey(point)) {
        distance[point] = 0;
        queue.add(point);
      } else {
        distance[point] = -1;
      }
    }
    var foundFreeCandidate = false;
    for (var index = 0; index < queue.length; index++) {
      final point = queue[index];
      for (final candidatePoint in eligible(point)) {
        final pairedReference = candidateMatch[candidatePoint];
        if (pairedReference == null) {
          foundFreeCandidate = true;
        } else if (distance[pairedReference] == -1) {
          distance[pairedReference] = distance[point]! + 1;
          queue.add(pairedReference);
        }
      }
    }
    return foundFreeCandidate;
  }

  bool augment((int, int) referencePoint) {
    for (final candidatePoint in eligible(referencePoint)) {
      final pairedReference = candidateMatch[candidatePoint];
      if (pairedReference == null ||
          (distance[pairedReference] == distance[referencePoint]! + 1 &&
              augment(pairedReference))) {
        referenceMatch[referencePoint] = candidatePoint;
        candidateMatch[candidatePoint] = referencePoint;
        return true;
      }
    }
    distance[referencePoint] = -1;
    return false;
  }

  while (buildLayers()) {
    for (final point in referencePoints) {
      if (!referenceMatch.containsKey(point)) augment(point);
    }
  }
  return (
    count: referenceMatch.length,
    referenceMatched: candidateMatch.values.toSet(),
    candidateMatched: candidateMatch.keys.toSet(),
  );
}

List<String> _coverageFailureDetails(_RoleResidualResult residual) => [
  if (!residual.hasReciprocalSeedCoverage)
    'reference RGB12 seeds and candidate RGB4 cores lack reciprocal support',
  if (residual.hasComponentCountMismatch)
    'foreground component count differs '
        '(${residual.referenceComponentCount} reference, '
        '${residual.candidateComponentCount} candidate)',
  if (!residual.hasComponentCountMismatch &&
      !residual.hasComponentTopologyMatch)
    'foreground components lack a complete one-to-one local bijection '
        '(reference ${residual.referenceComponentSummary}; '
        'candidate ${residual.candidateComponentSummary})',
  if (residual.coverageMassFailed)
    'coverage mass delta '
        '${residual.coverageDensityDeltaPercent.toStringAsFixed(3)}% exceeds '
        '${_maximumInkDensityDeltaPercent.toStringAsFixed(1)}%',
  if (residual.coverageCentroidFailed)
    'coverage centroid delta '
        '(${residual.coverageCentroidDeltaX.toStringAsFixed(3)}, '
        '${residual.coverageCentroidDeltaY.toStringAsFixed(3)}) exceeds '
        '$_maximumEdgeDelta physical px',
  if (residual.coverageGridFailed)
    '3x3 coverage grid total variation '
        '${residual.coverageGridTotalVariationPercent.toStringAsFixed(3)}% '
        'exceeds ${_maximumInkDensityDeltaPercent.toStringAsFixed(1)}%',
];

bool _writeCalibratedControlResult(
  _CsvReport report,
  _ComparisonConfiguration configuration,
  TabReferenceCase referenceCase, {
  required ReferenceStaticControlRegion control,
  required _StaticRegionResult rawResult,
  required _MeasuredInk referenceRole,
  required image.Image reference,
  required image.Image candidate,
  required _MaskMap masks,
  required _SurfaceCalibration calibratedSurface,
  required bool hasGlobalRoleSeed,
  required _ReferenceForegroundConsensus referenceConsensus,
}) {
  final candidateSample = _measureText(
    candidate,
    control.rect,
    referenceRole.toReferenceInk(),
    masks,
    geometryColorTolerance: control.geometryColorTolerance,
    measureLargestGeometryComponent: false,
  );
  final residual = _measureRoleResidual(
    candidateSample.geometryPixels,
    referenceRole,
    calibratedSurface,
    hasGlobalRoleSeed: hasGlobalRoleSeed,
    referenceConsensus: referenceConsensus,
  );
  final surfaceDelta = calibratedSurface.colorDelta;
  final roleEdgeDelta = residual.edgeDelta;
  final candidateForeground =
      residual.candidateCoreInk ?? candidateSample.semanticInk;
  final foregroundDelta = referenceRole.edgeDelta(candidateForeground);
  final densityDelta = residual.coverageDensityDeltaPercent;
  final residualFailed =
      residual.differingPixelRatio > _maximumStaticDifferenceRatio;
  final failed =
      residual.auditedPixelCount == 0 ||
      residual.hasMissingCore ||
      !residual.hasGlobalRoleSeed ||
      residual.invalidPixelCount > 0 ||
      !residual.hasReciprocalSeedCoverage ||
      residual.hasComponentCountMismatch ||
      !residual.hasComponentTopologyMatch ||
      residual.coverageMassFailed ||
      residual.coverageCentroidFailed ||
      residual.coverageGridFailed ||
      surfaceDelta > _maximumSemanticColorDelta ||
      foregroundDelta > _maximumSemanticColorDelta ||
      roleEdgeDelta > _maximumEdgeDelta ||
      residualFailed;
  final details = <String>[
    if (residual.auditedPixelCount == 0)
      'no foreground shape pixels remain to audit',
    if (residual.hasMissingCore) 'foreground core is missing on one side',
    if (!residual.hasGlobalRoleSeed)
      'no decoded-reference RGB12 seed for role and surface',
    if (residual.invalidPixelCount > 0)
      '${residual.invalidPixelCount} off-axis foreground colors fail raw '
          'coverage reconstruction '
          '(reference ${residual.referenceInvalidPixelCount}, '
          'candidate ${residual.candidateInvalidPixelCount})',
    ..._coverageFailureDetails(residual),
    if (surfaceDelta > _maximumSemanticColorDelta)
      'surface RGB delta $surfaceDelta exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (foregroundDelta > _maximumSemanticColorDelta)
      'foreground RGB delta $foregroundDelta exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (roleEdgeDelta > _maximumEdgeDelta)
      'feature edge delta $roleEdgeDelta exceeds '
          '$_maximumEdgeDelta physical px',
    if (residualFailed)
      '${residual.differingPixelCount} foreground core pixels differ '
          '(foreground shape pixels differ); '
          'ratio ${(residual.differingPixelRatio * 100).toStringAsFixed(3)}% '
          'exceeds ${(_maximumStaticDifferenceRatio * 100).toStringAsFixed(1)}%',
    if (residualFailed) 'unmatched support ${residual.supportMismatchSummary}',
    'support counts ${residual.referencePixels.length} reference, '
        '${residual.candidatePixels.length} candidate',
    'foreground owns exact audited coverage support; off-axis pixels remain '
        'parent-owned',
    'consensus provenance ${residual.consensusProvenance}',
  ];
  report.add(
    recordType: 'static-control',
    renderer: configuration.renderer.name,
    caseId: referenceCase.id,
    regionType: 'control',
    regionName: control.name,
    referenceBounds: residual.referenceBounds?.toString() ?? 'none',
    candidateBounds: residual.candidateBounds?.toString() ?? 'none',
    edgeDelta: '$roleEdgeDelta',
    measuredReferenceInk: calibratedSurface.reference.toString(),
    candidateInk: calibratedSurface.candidate.toString(),
    semanticInkDelta: '$surfaceDelta',
    measuredReferenceForeground: referenceRole.toString(),
    candidateForeground: candidateForeground.toString(),
    foregroundColorDelta: '$foregroundDelta',
    inkDensityDeltaPercent: densityDelta.toStringAsFixed(3),
    candidateInkRatio: residual.coverageDensityRatio.toStringAsFixed(3),
    differingPixelCount: '${residual.differingPixelCount}',
    auditedPixelCount: '${residual.auditedPixelCount}',
    differingPixelRatio: residual.differingPixelRatio.toStringAsFixed(6),
    status: failed ? 'FAIL' : 'PASS',
    details: details.join('; '),
  );
  return failed;
}

bool _writeCalibratedTextResult(
  _CsvReport report,
  _ComparisonConfiguration configuration,
  TabReferenceCase referenceCase, {
  required StaticTextRegion region,
  required _MeasuredInk referenceRole,
  required image.Image reference,
  required image.Image candidate,
  required _MaskMap masks,
  required _SurfaceCalibration calibratedSurface,
  required bool hasGlobalRoleSeed,
  required _ReferenceForegroundConsensus referenceConsensus,
}) {
  final candidateSample = _measureText(
    candidate,
    region.candidateRect,
    referenceRole.toReferenceInk(),
    masks,
    geometryColorTolerance: _candidateGeometryTolerance(
      region,
      configuration.renderer,
    ),
    measureLargestGeometryComponent: region.measureLargestGeometryComponent,
  );
  final residual = _measureRoleResidual(
    candidateSample.geometryPixels,
    referenceRole,
    calibratedSurface,
    hasGlobalRoleSeed: hasGlobalRoleSeed,
    referenceConsensus: referenceConsensus,
  );
  final edgeDelta = residual.edgeDelta;
  final candidateForeground =
      residual.candidateCoreInk ?? candidateSample.semanticInk;
  final foregroundDelta = referenceRole.edgeDelta(candidateForeground);
  final densityDelta = residual.coverageDensityDeltaPercent;
  final residualFailed =
      residual.differingPixelRatio > _maximumStaticDifferenceRatio;
  final failed =
      residual.auditedPixelCount == 0 ||
      residual.hasMissingCore ||
      !residual.hasGlobalRoleSeed ||
      residual.invalidPixelCount > 0 ||
      !residual.hasReciprocalSeedCoverage ||
      residual.hasComponentCountMismatch ||
      !residual.hasComponentTopologyMatch ||
      residual.coverageMassFailed ||
      residual.coverageCentroidFailed ||
      residual.coverageGridFailed ||
      calibratedSurface.colorDelta > _maximumSemanticColorDelta ||
      foregroundDelta > _maximumSemanticColorDelta ||
      edgeDelta > _maximumEdgeDelta ||
      residualFailed;
  final details = <String>[
    if (residual.auditedPixelCount == 0)
      'no foreground shape pixels remain to audit',
    if (residual.hasMissingCore) 'foreground core is missing on one side',
    if (!residual.hasGlobalRoleSeed)
      'no decoded-reference RGB12 seed for role and surface',
    if (residual.invalidPixelCount > 0)
      '${residual.invalidPixelCount} off-axis foreground colors fail raw '
          'coverage reconstruction '
          '(reference ${residual.referenceInvalidPixelCount}, '
          'candidate ${residual.candidateInvalidPixelCount})',
    ..._coverageFailureDetails(residual),
    if (calibratedSurface.colorDelta > _maximumSemanticColorDelta)
      'surface RGB delta ${calibratedSurface.colorDelta} exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (foregroundDelta > _maximumSemanticColorDelta)
      'semantic RGB delta $foregroundDelta exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (edgeDelta > _maximumEdgeDelta)
      'edge delta $edgeDelta exceeds $_maximumEdgeDelta physical px',
    if (residualFailed)
      '${residual.differingPixelCount} foreground core pixels differ '
          '(foreground shape pixels differ); '
          'ratio ${(residual.differingPixelRatio * 100).toStringAsFixed(3)}% '
          'exceeds ${(_maximumStaticDifferenceRatio * 100).toStringAsFixed(1)}%',
    if (residualFailed) 'unmatched support ${residual.supportMismatchSummary}',
    'support counts ${residual.referencePixels.length} reference, '
        '${residual.candidatePixels.length} candidate',
    'foreground owns exact audited coverage support; off-axis pixels remain '
        'parent-owned',
    'consensus provenance ${residual.consensusProvenance}',
  ];
  report.add(
    recordType: 'text',
    renderer: configuration.renderer.name,
    caseId: referenceCase.id,
    regionType: 'staticText',
    regionName: region.name,
    referenceBounds: residual.referenceBounds?.toString() ?? 'none',
    candidateBounds: residual.candidateBounds?.toString() ?? 'none',
    edgeDelta: '$edgeDelta',
    manifestInkHint: _MeasuredInk.fromReference(region.ink).toString(),
    measuredReferenceInk: calibratedSurface.reference.toString(),
    candidateInk: calibratedSurface.candidate.toString(),
    semanticInkDelta: '${calibratedSurface.colorDelta}',
    measuredReferenceForeground: referenceRole.toString(),
    candidateForeground: candidateForeground.toString(),
    foregroundColorDelta: '$foregroundDelta',
    inkDensityDeltaPercent: densityDelta.toStringAsFixed(3),
    candidateInkRatio: residual.coverageDensityRatio.toStringAsFixed(3),
    differingPixelCount: '${residual.differingPixelCount}',
    auditedPixelCount: '${residual.auditedPixelCount}',
    differingPixelRatio: residual.differingPixelRatio.toStringAsFixed(6),
    status: failed ? 'FAIL' : 'PASS',
    details: details.join('; '),
  );
  return failed;
}

void _writeCalibratedControlMeasurementFailure(
  _CsvReport report,
  _ComparisonConfiguration configuration,
  TabReferenceCase referenceCase, {
  required ReferenceStaticControlRegion control,
  required _StaticRegionResult rawResult,
  required _MeasuredInk referenceRole,
  required StateError error,
}) {
  report.add(
    recordType: 'static-control',
    renderer: configuration.renderer.name,
    caseId: referenceCase.id,
    regionType: 'control',
    regionName: control.name,
    referenceBounds: rawResult.referenceFeatureBounds?.toString() ?? 'none',
    candidateBounds: rawResult.candidateFeatureBounds?.toString() ?? 'none',
    edgeDelta: rawResult.hasOneSidedForeground
        ? 'one-sided'
        : '${rawResult.featureEdgeDelta}',
    measuredReferenceInk: rawResult.referenceSurface.toString(),
    candidateInk: rawResult.candidateSurface.toString(),
    semanticInkDelta: '${rawResult.surfaceColorDelta}',
    measuredReferenceForeground: referenceRole.toString(),
    candidateForeground: '',
    foregroundColorDelta: 'one-sided',
    differingPixelCount: '${rawResult.differingPixelCount}',
    auditedPixelCount: '${rawResult.auditedPixelCount}',
    differingPixelRatio: rawResult.differingPixelRatio.toStringAsFixed(6),
    status: 'FAIL',
    details: 'measurement failed: ${error.message}',
  );
}

_ShadowAuditSummary _measureShadowAudit(
  TabReferenceCase referenceCase,
  image.Image reference,
  image.Image candidate,
  _MaskMap masks,
) => _ShadowAuditSummary({
  for (final region in referenceCase.shadowRegions)
    region.name: _measureShadowRegion(reference, candidate, region, masks),
});

_ShadowResult _measureShadowRegion(
  image.Image reference,
  image.Image candidate,
  ReferenceShadowRegion region,
  _MaskMap masks,
) {
  List<_InkPixel> pixelsIn(image.Image source, ReferencePixelRect rect) {
    final result = <_InkPixel>[];
    for (var y = rect.top; y < rect.bottom; y++) {
      for (var x = rect.left; x < rect.right; x++) {
        if (masks.contains(x, y)) continue;
        final pixel = source.getPixel(x, y);
        result.add(
          _InkPixel(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()),
        );
      }
    }
    return result;
  }

  int darkness(_MeasuredInk surface, _InkPixel pixel) => math.max(
    0,
    _maximum(
      surface.red - pixel.red,
      surface.green - pixel.green,
      surface.blue - pixel.blue,
    ),
  );

  final referenceSurfacePixels = pixelsIn(reference, region.surfaceSampleRect);
  final candidateSurfacePixels = pixelsIn(candidate, region.surfaceSampleRect);
  if (referenceSurfacePixels.isEmpty || candidateSurfacePixels.isEmpty) {
    return const _ShadowResult.empty();
  }
  final referenceSurface = _MeasuredInk.modeFromPixels(referenceSurfacePixels);
  final candidateSurface = _MeasuredInk.modeFromPixels(candidateSurfacePixels);
  final noiseFloor = referenceSurfacePixels.fold<int>(
    0,
    (result, pixel) => math.max(result, darkness(referenceSurface, pixel)),
  );

  Map<(int, int), int> weightedOccupancy(
    image.Image source,
    _MeasuredInk surface,
  ) {
    final result = <(int, int), int>{};
    for (final pixel in pixelsIn(source, region.rect)) {
      final weight = darkness(surface, pixel) - noiseFloor;
      if (weight > 0) result[(pixel.x, pixel.y)] = weight;
    }
    return result;
  }

  final referenceWeights = weightedOccupancy(reference, referenceSurface);
  final candidateWeights = weightedOccupancy(candidate, candidateSurface);

  bool hasNear(Map<(int, int), int> values, (int, int) point) {
    for (var offsetY = -1; offsetY <= 1; offsetY++) {
      for (var offsetX = -1; offsetX <= 1; offsetX++) {
        if (values.containsKey((point.$1 + offsetX, point.$2 + offsetY))) {
          return true;
        }
      }
    }
    return false;
  }

  var differingDarkness = 0;
  for (final entry in referenceWeights.entries) {
    if (!hasNear(candidateWeights, entry.key)) differingDarkness += entry.value;
  }
  for (final entry in candidateWeights.entries) {
    if (!hasNear(referenceWeights, entry.key)) differingDarkness += entry.value;
  }
  final auditedDarkness =
      referenceWeights.values.fold<int>(0, (sum, value) => sum + value) +
      candidateWeights.values.fold<int>(0, (sum, value) => sum + value);

  _MeasuredInk? coreInk(image.Image source, Map<(int, int), int> weights) {
    if (weights.isEmpty) return null;
    final ordered = weights.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final coreLength = math.max(1, (ordered.length / 4).ceil());
    return _MeasuredInk.channelMedian([
      for (final entry in ordered.take(coreLength))
        _InkPixel(
          entry.key.$1,
          entry.key.$2,
          source.getPixel(entry.key.$1, entry.key.$2).r.toInt(),
          source.getPixel(entry.key.$1, entry.key.$2).g.toInt(),
          source.getPixel(entry.key.$1, entry.key.$2).b.toInt(),
        ),
    ]);
  }

  return _ShadowResult(
    referenceSurface: referenceSurface,
    candidateSurface: candidateSurface,
    referenceCore: coreInk(reference, referenceWeights),
    candidateCore: coreInk(candidate, candidateWeights),
    referenceBounds: _boundsFromPoints(referenceWeights.keys),
    candidateBounds: _boundsFromPoints(candidateWeights.keys),
    referenceWeights: referenceWeights,
    candidateWeights: candidateWeights,
    noiseFloor: noiseFloor,
    differingDarkness: differingDarkness,
    auditedDarkness: auditedDarkness,
  );
}

_InkBounds? _boundsFromPoints(Iterable<(int, int)> points) {
  final values = points.toList(growable: false);
  if (values.isEmpty) return null;
  var left = values.first.$1;
  var top = values.first.$2;
  var right = left;
  var bottom = top;
  for (final point in values.skip(1)) {
    left = math.min(left, point.$1);
    top = math.min(top, point.$2);
    right = math.max(right, point.$1);
    bottom = math.max(bottom, point.$2);
  }
  return _InkBounds(left, top, right, bottom);
}

bool _writeShadowResult(
  _CsvReport report,
  _ComparisonConfiguration configuration,
  TabReferenceCase referenceCase, {
  required ReferenceShadowRegion shadow,
  required _ShadowResult result,
}) {
  final failed = result.failed;
  final details = <String>[
    'surface-relative shadow; reference noise floor ${result.noiseFloor}',
    if (result.auditedDarkness == 0)
      'no shadow darkness remains beyond the reference-derived noise floor',
    if (result.surfaceColorDelta > _maximumSemanticColorDelta)
      'local surface RGB delta ${result.surfaceColorDelta} exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (result.hasOneSidedCore) 'shadow core exists on only one side',
    if (!result.hasOneSidedCore &&
        result.coreColorDelta > _maximumSemanticColorDelta)
      'shadow core RGB delta ${result.coreColorDelta} exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (result.hasOneSidedBounds) 'shadow geometry exists on only one side',
    if (!result.hasOneSidedBounds && result.edgeDelta > _maximumEdgeDelta)
      'feature edge delta ${result.edgeDelta} exceeds '
          '$_maximumEdgeDelta physical px',
    if (result.differingRatio > _maximumStaticDifferenceRatio)
      '${result.differingDarkness} missing or extra darkness weight; ratio '
          '${(result.differingRatio * 100).toStringAsFixed(3)}% exceeds '
          '${(_maximumStaticDifferenceRatio * 100).toStringAsFixed(1)}%',
  ];
  report.add(
    recordType: 'static-shadow',
    renderer: configuration.renderer.name,
    caseId: referenceCase.id,
    regionType: 'shadow',
    regionName: shadow.name,
    referenceBounds: result.referenceBounds?.toString() ?? 'none',
    candidateBounds: result.candidateBounds?.toString() ?? 'none',
    edgeDelta: result.hasOneSidedBounds ? 'one-sided' : '${result.edgeDelta}',
    measuredReferenceInk: result.referenceSurface.toString(),
    candidateInk: result.candidateSurface.toString(),
    semanticInkDelta: '${result.surfaceColorDelta}',
    measuredReferenceForeground: result.referenceCore?.toString() ?? '',
    candidateForeground: result.candidateCore?.toString() ?? '',
    foregroundColorDelta: result.hasOneSidedCore
        ? 'one-sided'
        : '${result.coreColorDelta}',
    candidateInkRatio: result.referenceDarkness == 0
        ? ''
        : (result.candidateDarkness / result.referenceDarkness).toStringAsFixed(
            3,
          ),
    differingPixelCount: '${result.differingDarkness}',
    auditedPixelCount: '${result.auditedDarkness}',
    differingPixelRatio: result.differingRatio.toStringAsFixed(6),
    status: failed ? 'FAIL' : 'PASS',
    details: details.join('; '),
  );
  return failed;
}

_ParentSurfaceResult _measureParentSurface(
  image.Image reference,
  image.Image candidate,
  ReferencePixelRect rect,
  _MaskMap masks,
  Set<(int, int)> childOwnedPixels,
) {
  final referencePixels = <_InkPixel>[];
  final candidatePixels = <_InkPixel>[];
  var differing = 0;
  var audited = 0;
  for (var y = rect.top; y < rect.bottom; y++) {
    for (var x = rect.left; x < rect.right; x++) {
      if (masks.contains(x, y) || childOwnedPixels.contains((x, y))) continue;
      final referencePixel = reference.getPixel(x, y);
      final candidatePixel = candidate.getPixel(x, y);
      final referenceValue = _InkPixel(
        x,
        y,
        referencePixel.r.toInt(),
        referencePixel.g.toInt(),
        referencePixel.b.toInt(),
      );
      final candidateValue = _InkPixel(
        x,
        y,
        candidatePixel.r.toInt(),
        candidatePixel.g.toInt(),
        candidatePixel.b.toInt(),
      );
      referencePixels.add(referenceValue);
      candidatePixels.add(candidateValue);
      audited++;
      if (_maximum(
            (referenceValue.red - candidateValue.red).abs(),
            (referenceValue.green - candidateValue.green).abs(),
            (referenceValue.blue - candidateValue.blue).abs(),
          ) >
          _staticPixelChannelTolerance) {
        differing++;
      }
    }
  }
  if (audited == 0) return const _ParentSurfaceResult.empty();
  final referenceSurface = _MeasuredInk.modeFromPixels(referencePixels);
  final candidateSurface = _MeasuredInk.modeFromPixels(candidatePixels);
  final referenceFeatures = referencePixels
      .where(
        (pixel) =>
            pixel.distanceFromMeasured(referenceSurface) >
            _staticPixelChannelTolerance,
      )
      .toList(growable: false);
  final candidateFeatures = candidatePixels
      .where(
        (pixel) =>
            pixel.distanceFromMeasured(candidateSurface) >
            _staticPixelChannelTolerance,
      )
      .toList(growable: false);
  return _ParentSurfaceResult(
    differingPixelCount: differing,
    auditedPixelCount: audited,
    referenceSurface: referenceSurface,
    candidateSurface: candidateSurface,
    referenceFeatureBounds: referenceFeatures.isEmpty
        ? null
        : _InkBounds.fromPixels(referenceFeatures),
    candidateFeatureBounds: candidateFeatures.isEmpty
        ? null
        : _InkBounds.fromPixels(candidateFeatures),
  );
}

Set<(int, int)> _measureForegroundTransitionOwnership(
  TabReferenceCase referenceCase,
  image.Image reference,
  image.Image candidate,
  List<String> regionNames,
  Map<String, _MeasuredInk> calibratedRoles,
  Map<String, _SurfaceCalibration> calibratedSurfaces,
  _MaskMap masks,
) {
  final result = <(int, int)>{};
  ({
    ReferencePixelRect referenceRect,
    ReferencePixelRect candidateRect,
    int tolerance,
  })?
  geometryFor(String name) {
    for (final control in referenceCase.staticControlRegions) {
      if (control.name == name) {
        return (
          referenceRect: control.rect,
          candidateRect: control.rect,
          tolerance: control.geometryColorTolerance,
        );
      }
    }
    for (final text in referenceCase.staticTextRegions) {
      if (text.name == name) {
        return (
          referenceRect: text.referenceRect,
          candidateRect: text.candidateRect,
          tolerance: text.geometryColorTolerance,
        );
      }
    }
    return null;
  }

  for (final name in regionNames) {
    final geometry = geometryFor(name);
    final roleName = referenceCase.foregroundRoleByRegion[name];
    final surfaceName = referenceCase.surfaceRoleByRegion[name];
    if (geometry == null || roleName == null || surfaceName == null) continue;
    final left = math.max(
      0,
      math.min(geometry.referenceRect.left, geometry.candidateRect.left) - 1,
    );
    final top = math.max(
      0,
      math.min(geometry.referenceRect.top, geometry.candidateRect.top) - 1,
    );
    final right = math.min(
      reference.width,
      math.max(geometry.referenceRect.right, geometry.candidateRect.right) + 1,
    );
    final bottom = math.min(
      reference.height,
      math.max(geometry.referenceRect.bottom, geometry.candidateRect.bottom) +
          1,
    );
    final role = calibratedRoles[roleName]!;
    final surface = calibratedSurfaces[surfaceName]!;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        if (masks.contains(x, y)) continue;
        final referencePixel = reference.getPixel(x, y);
        final candidatePixel = candidate.getPixel(x, y);
        final referenceValue = _InkPixel(
          x,
          y,
          referencePixel.r.toInt(),
          referencePixel.g.toInt(),
          referencePixel.b.toInt(),
        );
        final candidateValue = _InkPixel(
          x,
          y,
          candidatePixel.r.toInt(),
          candidatePixel.g.toInt(),
          candidatePixel.b.toInt(),
        );
        final referenceProjection = _projectCoverage(
          referenceValue,
          role,
          surface.reference,
        );
        final candidateProjection = _projectCoverage(
          candidateValue,
          role,
          surface.candidate,
        );
        if (_MeasuredInk(
                  referenceValue.red,
                  referenceValue.green,
                  referenceValue.blue,
                ).edgeDelta(role) <=
                geometry.tolerance ||
            (referenceProjection.alpha > 0 &&
                referenceProjection.reconstructionError <=
                    _staticPixelChannelTolerance) ||
            (candidateProjection.alpha > 0 &&
                candidateProjection.reconstructionError <=
                    _maximumSemanticColorDelta)) {
          result.add((x, y));
        }
      }
    }
  }
  return result;
}

_SurfaceResult _measureSurfaceRegion(
  image.Image reference,
  image.Image candidate,
  ReferenceSurfaceRegion region,
  _MaskMap masks,
  Set<(int, int)> childOwnedPixels,
  _SurfaceCalibration surface,
  _SurfaceCalibration surrounding, {
  required bool identicalRaster,
}) {
  bool excluded(int x, int y) =>
      masks.contains(x, y) ||
      childOwnedPixels.contains((x, y)) ||
      region.excludedRects.any(
        (rect) =>
            x >= rect.left &&
            x < rect.right &&
            y >= rect.top &&
            y < rect.bottom,
      );

  ({bool support, bool valid}) classify(
    _InkPixel pixel,
    _MeasuredInk expected,
    _MeasuredInk outside,
    int tolerance,
  ) {
    final expectedDelta = _MeasuredInk(
      pixel.red,
      pixel.green,
      pixel.blue,
    ).edgeDelta(expected);
    final outsideDelta = _MeasuredInk(
      pixel.red,
      pixel.green,
      pixel.blue,
    ).edgeDelta(outside);
    if (expected.edgeDelta(outside) == 0) {
      return (
        support: expectedDelta <= tolerance,
        valid: expectedDelta <= tolerance,
      );
    }
    final projection = _projectCoverage(pixel, expected, outside);
    final valid =
        projection.reconstructionError <= tolerance ||
        expectedDelta <= tolerance ||
        outsideDelta <= tolerance;
    return (support: valid && projection.alpha >= .5, valid: valid);
  }

  final referenceSupport = <(int, int), int>{};
  final candidateSupport = <(int, int), int>{};
  var referenceInvalid = 0;
  var candidateInvalid = 0;
  final candidateInvalidSamples = <_InkPixel>[];
  for (var y = region.rect.top; y < region.rect.bottom; y++) {
    for (var x = region.rect.left; x < region.rect.right; x++) {
      if (excluded(x, y)) continue;
      final referencePixel = reference.getPixel(x, y);
      final candidatePixel = candidate.getPixel(x, y);
      final referenceValue = _InkPixel(
        x,
        y,
        referencePixel.r.toInt(),
        referencePixel.g.toInt(),
        referencePixel.b.toInt(),
      );
      final candidateValue = _InkPixel(
        x,
        y,
        candidatePixel.r.toInt(),
        candidatePixel.g.toInt(),
        candidatePixel.b.toInt(),
      );
      final referenceClass = classify(
        referenceValue,
        surface.reference,
        surrounding.reference,
        _staticPixelChannelTolerance,
      );
      final candidateClass = classify(
        candidateValue,
        surface.candidate,
        surrounding.candidate,
        _maximumSemanticColorDelta,
      );
      final referenceIsExpected =
          surface.reference.edgeDelta(surrounding.reference) == 0
          ? true
          : _projectCoverage(
                  referenceValue,
                  surface.reference,
                  surrounding.reference,
                ).alpha >=
                .5;
      final candidateIsExpected = candidateClass.support;
      if (referenceIsExpected || identicalRaster) {
        referenceSupport[(x, y)] = 1;
      }
      if (candidateIsExpected || identicalRaster) {
        candidateSupport[(x, y)] = 1;
      }
      if (!referenceClass.valid && !identicalRaster) {
        // Decoded JPEG pixels can be off-axis even when their nearest declared
        // surface class is unambiguous. The raw candidate remains strict.
      }
      if (!candidateClass.valid && !identicalRaster) {
        candidateInvalid++;
        if (candidateInvalidSamples.length < 8) {
          candidateInvalidSamples.add(candidateValue);
        }
      }
    }
  }
  final matches = _maximumCoverageMatches(referenceSupport, candidateSupport);
  final differing =
      referenceSupport.length +
      candidateSupport.length -
      matches.count * 2 +
      referenceInvalid +
      candidateInvalid;
  final audited =
      referenceSupport.length +
      candidateSupport.length +
      referenceInvalid +
      candidateInvalid;
  return _SurfaceResult(
    referenceSurface: surface.reference,
    candidateSurface: surface.candidate,
    referenceSurrounding: surrounding.reference,
    candidateSurrounding: surrounding.candidate,
    referenceBounds: _boundsFromPoints(referenceSupport.keys),
    candidateBounds: _boundsFromPoints(candidateSupport.keys),
    referenceSupportCount: referenceSupport.length,
    candidateSupportCount: candidateSupport.length,
    referenceInvalidCount: referenceInvalid,
    candidateInvalidCount: candidateInvalid,
    candidateInvalidSamples: candidateInvalidSamples,
    differingCount: differing,
    auditedCount: audited,
  );
}

bool _writeSurfaceResult(
  _CsvReport report,
  _ComparisonConfiguration configuration,
  TabReferenceCase referenceCase, {
  required ReferenceSurfaceRegion surface,
  required _SurfaceResult result,
}) {
  final failed = result.failed;
  final details = <String>[
    if (result.surfaceColorDelta > _maximumSemanticColorDelta)
      'surface RGB delta ${result.surfaceColorDelta} exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (result.surroundingColorDelta > _maximumSemanticColorDelta)
      'surrounding RGB delta ${result.surroundingColorDelta} exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (result.invalidCount > 0)
      '${result.invalidCount} pixels belong to neither declared surface class '
          '(reference ${result.referenceInvalidCount}, candidate '
          '${result.candidateInvalidCount}; candidate samples '
          '${result.candidateInvalidSamples.map((pixel) => '${pixel.x}:${pixel.y}='
              '${pixel.red}/${pixel.green}/${pixel.blue}').join('|')})',
    if (result.hasOneSidedBounds) 'surface geometry exists on only one side',
    if (!result.hasOneSidedBounds && result.edgeDelta > _maximumEdgeDelta)
      'feature edge delta ${result.edgeDelta} exceeds '
          '$_maximumEdgeDelta physical px',
    if (result.differingRatio > _maximumStaticDifferenceRatio)
      '${result.differingCount} surface pixels differ; ratio '
          '${(result.differingRatio * 100).toStringAsFixed(3)}% exceeds '
          '${(_maximumStaticDifferenceRatio * 100).toStringAsFixed(1)}%',
    'surface support counts ${result.referenceSupportCount} reference, '
        '${result.candidateSupportCount} candidate; original coordinates; '
        'one-to-one Chebyshev-1 matching',
  ];
  report.add(
    recordType: 'static-surface',
    renderer: configuration.renderer.name,
    caseId: referenceCase.id,
    regionType: 'surface',
    regionName: surface.name,
    referenceBounds: result.referenceBounds?.toString() ?? 'none',
    candidateBounds: result.candidateBounds?.toString() ?? 'none',
    edgeDelta: result.hasOneSidedBounds ? 'one-sided' : '${result.edgeDelta}',
    measuredReferenceInk: result.referenceSurface.toString(),
    candidateInk: result.candidateSurface.toString(),
    semanticInkDelta: '${result.surfaceColorDelta}',
    measuredReferenceForeground: result.referenceSurrounding.toString(),
    candidateForeground: result.candidateSurrounding.toString(),
    foregroundColorDelta: '${result.surroundingColorDelta}',
    differingPixelCount: '${result.differingCount}',
    auditedPixelCount: '${result.auditedCount}',
    differingPixelRatio: result.differingRatio.toStringAsFixed(6),
    status: failed ? 'FAIL' : 'PASS',
    details: details.join('; '),
  );
  return failed;
}

bool _writeCompositeRoleResult(
  _CsvReport report,
  _ComparisonConfiguration configuration,
  TabReferenceCase referenceCase, {
  required ReferenceVisualRegion region,
  required Map<String, _MeasuredInk> calibratedRoles,
  required _RoleAuditSummary roleAudit,
  required image.Image reference,
  required image.Image candidate,
  required _MaskMap masks,
  required _ShadowAuditSummary shadowAudit,
}) {
  final scopedAudit = roleAudit.scoped(region.foregroundRegionNames);
  final scopedShadows = shadowAudit.scoped(region.shadowRegionNames);
  final surface = _measureParentSurface(
    reference,
    candidate,
    region.rect,
    masks,
    {...scopedAudit.ownedPixels(), ...scopedShadows.ownedPixels()},
  );
  final required = region.requiredForegroundRoles.toSet();
  final candidateRoles = scopedAudit.candidateSamples;
  final actual = candidateRoles.keys.toSet();
  final missing = required.difference(actual);
  final extra = actual.difference(required);
  var worstDelta = 0;
  for (final role in required.intersection(actual)) {
    worstDelta = math.max(
      worstDelta,
      calibratedRoles[role]!.edgeDelta(candidateRoles[role]!),
    );
  }
  final surfaceFailed =
      surface.auditedPixelCount == 0 ||
      surface.surfaceColorDelta > _maximumSemanticColorDelta ||
      surface.differingPixelRatio > _maximumStaticDifferenceRatio;
  final referenceBounds = _mergeOptionalBounds(
    _mergeOptionalBounds(
      scopedAudit.combinedReferenceBounds(required),
      scopedShadows.referenceBounds,
    ),
    surface.referenceFeatureBounds,
  );
  final candidateBounds = _mergeOptionalBounds(
    _mergeOptionalBounds(
      scopedAudit.combinedCandidateBounds(required),
      scopedShadows.candidateBounds,
    ),
    surface.candidateFeatureBounds,
  );
  final hasOneSidedBounds =
      (referenceBounds == null) != (candidateBounds == null);
  final edgeDelta = referenceBounds == null || candidateBounds == null
      ? 0
      : referenceBounds.edgeDelta(candidateBounds);
  final edgeFailed = hasOneSidedBounds || edgeDelta > _maximumEdgeDelta;
  final childResidual = scopedAudit.combinedResidual(required);
  final residual = _RoleResidualResult(
    childResidual.differingPixelCount +
        scopedShadows.differingDarkness +
        surface.differingPixelCount,
    childResidual.auditedPixelCount +
        scopedShadows.auditedDarkness +
        surface.auditedPixelCount,
  );
  final residualFailed =
      residual.differingPixelRatio > _maximumStaticDifferenceRatio;
  final failed =
      residual.auditedPixelCount == 0 ||
      surfaceFailed ||
      scopedAudit.hasFailedChild ||
      scopedShadows.hasFailedChild ||
      missing.isNotEmpty ||
      extra.isNotEmpty ||
      worstDelta > _maximumSemanticColorDelta ||
      edgeFailed ||
      residualFailed;
  String roleMap(Map<String, _MeasuredInk> values) {
    final keys = values.keys.where(required.contains).toList()..sort();
    return keys.map((role) => '$role=${values[role]}').join('|');
  }

  final details = <String>[
    if (residual.auditedPixelCount == 0)
      'no owned composite pixels remain to audit',
    if (surface.surfaceColorDelta > _maximumSemanticColorDelta)
      'surface RGB delta ${surface.surfaceColorDelta} exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (surface.differingPixelRatio > _maximumStaticDifferenceRatio)
      '${surface.differingPixelCount} parent-surface pixels differ; ratio '
          '${(surface.differingPixelRatio * 100).toStringAsFixed(3)}% exceeds '
          '${(_maximumStaticDifferenceRatio * 100).toStringAsFixed(1)}%',
    if (scopedAudit.hasFailedChild)
      'one or more assigned foreground children failed',
    if (scopedShadows.hasFailedChild)
      'one or more assigned shadow children failed',
    if (missing.isNotEmpty) 'missing foreground roles: ${missing.join('|')}',
    if (extra.isNotEmpty) 'extra foreground roles: ${extra.join('|')}',
    if (worstDelta > _maximumSemanticColorDelta)
      'foreground RGB delta $worstDelta exceeds '
          '$_maximumSemanticColorDelta/channel',
    if (hasOneSidedBounds) 'foreground exists on only one side',
    if (!hasOneSidedBounds && edgeDelta > _maximumEdgeDelta)
      'feature edge delta $edgeDelta exceeds '
          '$_maximumEdgeDelta physical px',
    if (residualFailed)
      '${residual.differingPixelCount} aggregate owned pixels differ; '
          'ratio ${(residual.differingPixelRatio * 100).toStringAsFixed(3)}% '
          'exceeds ${(_maximumStaticDifferenceRatio * 100).toStringAsFixed(1)}%',
    'parent surface owns every pixel outside one-pixel child transitions',
  ];
  report.add(
    recordType: 'static-region',
    renderer: configuration.renderer.name,
    caseId: referenceCase.id,
    regionType: region.type.name,
    regionName: region.name,
    referenceBounds: referenceBounds?.toString() ?? 'none',
    candidateBounds: candidateBounds?.toString() ?? 'none',
    edgeDelta: hasOneSidedBounds ? 'one-sided' : '$edgeDelta',
    measuredReferenceInk: surface.referenceSurface.toString(),
    candidateInk: surface.candidateSurface.toString(),
    semanticInkDelta: '${surface.surfaceColorDelta}',
    measuredReferenceForeground: roleMap(calibratedRoles),
    candidateForeground: roleMap(candidateRoles),
    foregroundColorDelta: missing.isNotEmpty || extra.isNotEmpty
        ? 'one-sided'
        : '$worstDelta',
    differingPixelCount: '${residual.differingPixelCount}',
    auditedPixelCount: '${residual.auditedPixelCount}',
    differingPixelRatio: residual.differingPixelRatio.toStringAsFixed(6),
    status: failed ? 'FAIL' : 'PASS',
    details: details.join('; '),
  );
  return failed;
}

List<String> _validateManifest(
  List<TabReferenceCase> cases,
  List<ReferenceForegroundConsensusGroup> consensusGroups,
) {
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
      final scopedRoles = <String>{};
      for (final name in region.foregroundRegionNames) {
        final role = item.foregroundRoleByRegion[name];
        if (role == null) {
          errors.add(
            '${item.id}: composite ${region.name} scopes unknown foreground '
            'region $name.',
          );
        } else {
          scopedRoles.add(role);
        }
      }
      for (final role in region.requiredForegroundRoles) {
        final assigned =
            (region.foregroundRegionNames.isEmpty
                    ? item.foregroundRoleByRegion.values
                    : scopedRoles)
                .where((assignedRole) => assignedRole == role);
        if (assigned.isEmpty) {
          errors.add(
            '${item.id}: composite ${region.name} requires foreground role '
            '$role but has no assigned foreground region.',
          );
        }
      }
      final duplicateForegroundNames =
          region.foregroundRegionNames.length -
          region.foregroundRegionNames.toSet().length;
      if (duplicateForegroundNames != 0) {
        errors.add(
          '${item.id}: composite ${region.name} repeats foreground owners.',
        );
      }
      final knownShadows = item.shadowRegions
          .map((shadow) => shadow.name)
          .toSet();
      for (final name in region.shadowRegionNames) {
        if (!knownShadows.contains(name)) {
          errors.add(
            '${item.id}: composite ${region.name} scopes unknown shadow '
            'region $name.',
          );
        }
      }
      if (region.shadowRegionNames.length !=
          region.shadowRegionNames.toSet().length) {
        errors.add(
          '${item.id}: composite ${region.name} repeats shadow owners.',
        );
      }
    }
    final surfaceRegionNames = <String>{};
    final declaredSurfaceRoles = item.referenceSurfaceInteriors
        .map((interior) => interior.role)
        .toSet();
    for (final surface in item.surfaceRegions) {
      validateRect('${item.id}: surface region ${surface.name}', surface.rect);
      if (surface.name.trim().isEmpty ||
          !surfaceRegionNames.add(surface.name)) {
        errors.add(
          '${item.id}: surface region names must be non-empty and unique.',
        );
      }
      for (final role in <String>[
        surface.surfaceRole,
        surface.surroundingRole,
      ]) {
        if (!declaredSurfaceRoles.contains(role)) {
          errors.add(
            '${item.id}: surface region ${surface.name} uses undeclared '
            'surface role $role.',
          );
        }
      }
      for (final rect in surface.excludedRects) {
        validateRect('${item.id}: surface exclusion ${surface.name}', rect);
        if (!_containsRect(surface.rect, rect)) {
          errors.add(
            '${item.id}: surface exclusion $rect is outside ${surface.rect}.',
          );
        }
      }
      for (final name in surface.foregroundRegionNames) {
        if (!item.foregroundRoleByRegion.containsKey(name)) {
          errors.add(
            '${item.id}: surface region ${surface.name} scopes unknown '
            'foreground $name.',
          );
        }
      }
    }
    final shadowNames = <String>{};
    for (final shadow in item.shadowRegions) {
      validateRect('${item.id}: shadow ${shadow.name}', shadow.rect);
      validateRect(
        '${item.id}: shadow ${shadow.name} surface sample',
        shadow.surfaceSampleRect,
      );
      if (shadow.name.trim().isEmpty || !shadowNames.add(shadow.name)) {
        errors.add('${item.id}: shadow names must be non-empty and unique.');
      }
    }
    for (final control in item.staticControlRegions) {
      validateRect('${item.id}: static control ${control.name}', control.rect);
      if (control.geometryColorTolerance < 0 ||
          control.geometryColorTolerance > 255) {
        errors.add(
          '${item.id}: static control ${control.name} has invalid geometry '
          'color tolerance ${control.geometryColorTolerance}.',
        );
      }
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
    final knownForegroundRegions = <String>{
      ...item.staticControlRegions.map((control) => control.name),
      ...item.staticTextRegions.map((text) => text.name),
    };
    for (final assignment in item.foregroundRoleByRegion.entries) {
      if (!knownForegroundRegions.contains(assignment.key)) {
        errors.add(
          '${item.id}: foreground role assignment ${assignment.key} does '
          'not name a static control or text region.',
        );
      }
      if (assignment.value.trim().isEmpty) {
        errors.add(
          '${item.id}: ${assignment.key} has an empty foreground role.',
        );
      }
      if (!item.surfaceRoleByRegion.containsKey(assignment.key)) {
        errors.add(
          '${item.id}: foreground consensus membership ${assignment.key} '
          'has no declared surface role.',
        );
      }
      if (!item.foregroundSelectionByRegion.containsKey(assignment.key)) {
        errors.add(
          '${item.id}: foreground consensus membership ${assignment.key} '
          'has no selected/unselected declaration.',
        );
      }
    }
    for (final name in item.foregroundSelectionByRegion.keys) {
      if (!item.foregroundRoleByRegion.containsKey(name)) {
        errors.add(
          '${item.id}: foreground consensus membership declares unexpected '
          'selection for $name.',
        );
      }
    }
    for (final interior in item.referenceForegroundInteriors) {
      validateRect(
        '${item.id}: foreground interior ${interior.role}',
        interior.rect,
      );
      if (interior.role.trim().isEmpty) {
        errors.add('${item.id}: foreground interior has an empty role.');
      }
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
        if (text.auditMode == StaticTextAuditMode.static &&
            !text.allowsDynamicMask &&
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
    for (final text in item.staticTextRegions.where(
      (text) => text.auditMode == StaticTextAuditMode.dynamicOnly,
    )) {
      if (_coveringDynamicMask(item, text) == null) {
        errors.add(
          '${item.id}: dynamic-only text ${text.name} must be fully covered '
          'by one reasoned dynamic mask (reference ${text.referenceRect}, '
          'candidate ${text.candidateRect}).',
        );
      }
    }
  }
  final casesById = {for (final item in cases) item.id: item};
  final expectedMembers = <(String, String)>{
    for (final item in cases)
      for (final name in item.foregroundRoleByRegion.keys) (item.id, name),
  };
  final assignedMembers = <(String, String)>{};
  final seenConsensusKeys = <ReferenceForegroundConsensusKey>{};
  final sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
  for (final group in consensusGroups) {
    if (!seenConsensusKeys.add(group.key)) {
      errors.add(
        'foreground consensus membership duplicates key ${group.key}.',
      );
    }
    if (group.memberCaseIds.isEmpty) {
      errors.add(
        'foreground consensus membership ${group.key} has no references.',
      );
    }
    final localMembers = <String>{};
    for (final caseId in group.memberCaseIds) {
      if (!localMembers.add(caseId)) {
        errors.add(
          'foreground consensus membership ${group.key} repeats $caseId.',
        );
      }
      final item = casesById[caseId];
      if (item == null) {
        errors.add(
          'foreground consensus membership ${group.key} names unexpected '
          'case $caseId.',
        );
        continue;
      }
      final member = (caseId, group.key.controlIdentity);
      if (!expectedMembers.contains(member)) {
        errors.add(
          'foreground consensus membership ${group.key} names unexpected '
          'reference $caseId/${group.key.controlIdentity}.',
        );
        continue;
      }
      if (!assignedMembers.add(member)) {
        errors.add(
          'foreground consensus membership duplicates '
          '$caseId/${group.key.controlIdentity}.',
        );
      }
      if (item.foregroundRoleByRegion[group.key.controlIdentity] !=
              group.key.semanticRole ||
          item.surfaceRoleByRegion[group.key.controlIdentity] !=
              group.key.surfaceRole ||
          item.foregroundSelectionByRegion[group.key.controlIdentity] !=
              group.key.selection) {
        errors.add(
          'foreground consensus membership ${group.key} contradicts '
          '$caseId/${group.key.controlIdentity}.',
        );
      }
      if (!sha256Pattern.hasMatch(item.referenceSha256)) {
        errors.add(
          'foreground consensus membership $caseId must declare a lowercase '
          'SHA256 reference hash.',
        );
      }
    }
  }
  for (final member in expectedMembers.difference(assignedMembers)) {
    errors.add(
      'foreground consensus membership is missing ${member.$1}/${member.$2}.',
    );
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

ReferenceDynamicMask? _coveringDynamicMask(
  TabReferenceCase referenceCase,
  StaticTextRegion region,
) {
  for (final mask in referenceCase.dynamicMaskRegions) {
    if (_containsRect(mask.rect, region.referenceRect) &&
        _containsRect(mask.rect, region.candidateRect)) {
      return mask;
    }
  }
  return null;
}

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

bool _imagesEqual(image.Image left, image.Image right) {
  if (left.width != right.width || left.height != right.height) return false;
  for (var y = 0; y < left.height; y++) {
    for (var x = 0; x < left.width; x++) {
      final leftPixel = left.getPixel(x, y);
      final rightPixel = right.getPixel(x, y);
      if (leftPixel.r != rightPixel.r ||
          leftPixel.g != rightPixel.g ||
          leftPixel.b != rightPixel.b ||
          leftPixel.a != rightPixel.a) {
        return false;
      }
    }
  }
  return true;
}

List<_DecodedComparisonCase> _preflightInputs(
  List<TabReferenceCase> referenceCases, {
  required String candidateDirectory,
  required String? referenceDirectory,
}) {
  final decodedCases = <_DecodedComparisonCase>[];
  for (final referenceCase in referenceCases) {
    final referencePath = referenceDirectory == null
        ? referenceCase.referencePath
        : '$referenceDirectory/${referenceCase.fileName}';
    final candidatePath =
        '$candidateDirectory/${referenceCase.id}-590x1280.png';
    final reference = _decode(referencePath);
    final candidate = _decode(candidatePath);
    _expectCanonicalSize(referenceCase, 'reference', reference);
    _expectCanonicalSize(referenceCase, 'candidate', candidate);
    _expectFullyOpaque(
      caseId: referenceCase.id,
      kind: 'reference',
      path: referencePath,
      value: reference,
    );
    _expectFullyOpaque(
      caseId: referenceCase.id,
      kind: 'candidate',
      path: candidatePath,
      value: candidate,
    );
    decodedCases.add(
      _DecodedComparisonCase(
        referenceCase: referenceCase,
        reference: reference,
        candidate: candidate,
        referencePath: referencePath,
      ),
    );
  }
  return decodedCases;
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

void _expectFullyOpaque({
  required String caseId,
  required String kind,
  required String path,
  required image.Image value,
}) {
  for (var y = 0; y < value.height; y++) {
    for (var x = 0; x < value.width; x++) {
      final alpha = value.getPixel(x, y).a.toInt();
      if (alpha != 255) {
        throw _ComparisonInputError(
          '$caseId $kind input $path must be fully opaque; '
          'pixel ($x,$y) has alpha $alpha.',
        );
      }
    }
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
    measuredGeometryPixels,
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
    required this.reference,
    required this.candidate,
    required this.masks,
    required this.differencePrefix,
    required this.auditedPrefix,
    this.overlay,
    this.heatmap,
  });

  factory _StaticPixelAudit.measure({
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
      reference: reference,
      candidate: candidate,
      masks: masks,
      differencePrefix: differencePrefix,
      auditedPrefix: auditedPrefix,
      overlay: overlay,
      heatmap: heatmap,
    );
  }

  final int width;
  final image.Image reference;
  final image.Image candidate;
  final _MaskMap masks;
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
    final referenceSurface = _measureSurface(reference, rect);
    final candidateSurface = _measureSurface(candidate, rect);
    return _StaticRegionResult(
      differingPixelCount: differing,
      auditedPixelCount: audited,
      referenceSurface: referenceSurface,
      candidateSurface: candidateSurface,
      referenceFeatureBounds: _measureFeatureBounds(
        reference,
        rect,
        referenceSurface,
      ),
      candidateFeatureBounds: _measureFeatureBounds(
        candidate,
        rect,
        candidateSurface,
      ),
      referenceForeground: _measureForegroundInk(
        reference,
        rect,
        referenceSurface,
      ),
      candidateForeground: _measureForegroundInk(
        candidate,
        rect,
        candidateSurface,
      ),
    );
  }

  _MeasuredInk _measureSurface(image.Image source, ReferencePixelRect rect) {
    final counts = <int, int>{};
    var modeKey = 0;
    var modeCount = 0;
    for (var y = rect.top; y < rect.bottom; y++) {
      for (var x = rect.left; x < rect.right; x++) {
        if (masks.contains(x, y)) continue;
        final pixel = source.getPixel(x, y);
        final key =
            (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();
        final count = (counts[key] ?? 0) + 1;
        counts[key] = count;
        if (count > modeCount) {
          modeKey = key;
          modeCount = count;
        }
      }
    }
    return _MeasuredInk.fromRgbKey(modeKey);
  }

  _InkBounds? _measureFeatureBounds(
    image.Image source,
    ReferencePixelRect rect,
    _MeasuredInk surface,
  ) {
    int? left;
    int? top;
    int? right;
    int? bottom;
    for (var y = rect.top; y < rect.bottom; y++) {
      for (var x = rect.left; x < rect.right; x++) {
        if (masks.contains(x, y)) continue;
        final pixel = source.getPixel(x, y);
        final value = _MeasuredInk(
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
        );
        if (value.edgeDelta(surface) <= _staticPixelChannelTolerance) continue;
        if (left == null || x < left) left = x;
        if (top == null || y < top) top = y;
        if (right == null || x > right) right = x;
        if (bottom == null || y > bottom) bottom = y;
      }
    }
    if (left == null) return null;
    return _InkBounds(left, top!, right!, bottom!);
  }

  _MeasuredInk? _measureForegroundInk(
    image.Image source,
    ReferencePixelRect rect,
    _MeasuredInk surface,
  ) {
    final pixels = <_InkPixel>[];
    for (var y = rect.top; y < rect.bottom; y++) {
      for (var x = rect.left; x < rect.right; x++) {
        if (masks.contains(x, y)) continue;
        final pixel = source.getPixel(x, y);
        final sample = _InkPixel(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
        );
        if (sample.distanceFromMeasured(surface) >
            _staticPixelChannelTolerance) {
          pixels.add(sample);
        }
      }
    }
    if (pixels.isEmpty) return null;
    pixels.sort(
      (left, right) => right
          .distanceFromMeasured(surface)
          .compareTo(left.distanceFromMeasured(surface)),
    );
    final core = pixels.take(math.max(1, (pixels.length / 4).ceil())).toList();
    return _MeasuredInk.channelMedian(core);
  }
}

class _StaticRegionResult {
  const _StaticRegionResult({
    required this.differingPixelCount,
    required this.auditedPixelCount,
    required this.referenceSurface,
    required this.candidateSurface,
    required this.referenceFeatureBounds,
    required this.candidateFeatureBounds,
    required this.referenceForeground,
    required this.candidateForeground,
  });

  final int differingPixelCount;
  final int auditedPixelCount;
  final _MeasuredInk referenceSurface;
  final _MeasuredInk candidateSurface;
  final _InkBounds? referenceFeatureBounds;
  final _InkBounds? candidateFeatureBounds;
  final _MeasuredInk? referenceForeground;
  final _MeasuredInk? candidateForeground;

  int get surfaceColorDelta => referenceSurface.edgeDelta(candidateSurface);

  bool get hasOneSidedForeground =>
      (referenceFeatureBounds == null) != (candidateFeatureBounds == null);

  bool get hasOneSidedMeasuredForeground =>
      (referenceForeground == null) != (candidateForeground == null);

  int get foregroundColorDelta =>
      referenceForeground == null || candidateForeground == null
      ? 0
      : referenceForeground!.edgeDelta(candidateForeground!);

  int get featureEdgeDelta =>
      referenceFeatureBounds == null || candidateFeatureBounds == null
      ? 0
      : referenceFeatureBounds!.edgeDelta(candidateFeatureBounds!);

  double get differingPixelRatio =>
      auditedPixelCount == 0 ? 1 : differingPixelCount / auditedPixelCount;
}

class _ParentSurfaceResult {
  const _ParentSurfaceResult({
    required this.differingPixelCount,
    required this.auditedPixelCount,
    required this.referenceSurface,
    required this.candidateSurface,
    required this.referenceFeatureBounds,
    required this.candidateFeatureBounds,
  });

  const _ParentSurfaceResult.empty()
    : differingPixelCount = 0,
      auditedPixelCount = 0,
      referenceSurface = const _MeasuredInk(0, 0, 0),
      candidateSurface = const _MeasuredInk(0, 0, 0),
      referenceFeatureBounds = null,
      candidateFeatureBounds = null;

  final int differingPixelCount;
  final int auditedPixelCount;
  final _MeasuredInk referenceSurface;
  final _MeasuredInk candidateSurface;
  final _InkBounds? referenceFeatureBounds;
  final _InkBounds? candidateFeatureBounds;

  int get surfaceColorDelta => referenceSurface.edgeDelta(candidateSurface);

  double get differingPixelRatio =>
      auditedPixelCount == 0 ? 1 : differingPixelCount / auditedPixelCount;
}

class _SurfaceResult {
  const _SurfaceResult({
    required this.referenceSurface,
    required this.candidateSurface,
    required this.referenceSurrounding,
    required this.candidateSurrounding,
    required this.referenceBounds,
    required this.candidateBounds,
    required this.referenceSupportCount,
    required this.candidateSupportCount,
    required this.referenceInvalidCount,
    required this.candidateInvalidCount,
    required this.candidateInvalidSamples,
    required this.differingCount,
    required this.auditedCount,
  });

  final _MeasuredInk referenceSurface;
  final _MeasuredInk candidateSurface;
  final _MeasuredInk referenceSurrounding;
  final _MeasuredInk candidateSurrounding;
  final _InkBounds? referenceBounds;
  final _InkBounds? candidateBounds;
  final int referenceSupportCount;
  final int candidateSupportCount;
  final int referenceInvalidCount;
  final int candidateInvalidCount;
  final List<_InkPixel> candidateInvalidSamples;
  final int differingCount;
  final int auditedCount;

  int get surfaceColorDelta => referenceSurface.edgeDelta(candidateSurface);
  int get surroundingColorDelta =>
      referenceSurrounding.edgeDelta(candidateSurrounding);
  int get invalidCount => referenceInvalidCount + candidateInvalidCount;
  bool get hasOneSidedBounds =>
      (referenceBounds == null) != (candidateBounds == null);
  int get edgeDelta => referenceBounds == null || candidateBounds == null
      ? 0
      : referenceBounds!.edgeDelta(candidateBounds!);
  double get differingRatio =>
      auditedCount == 0 ? 1 : differingCount / auditedCount;
  bool get failed =>
      auditedCount == 0 ||
      surfaceColorDelta > _maximumSemanticColorDelta ||
      surroundingColorDelta > _maximumSemanticColorDelta ||
      invalidCount > 0 ||
      hasOneSidedBounds ||
      edgeDelta > _maximumEdgeDelta ||
      differingRatio > _maximumStaticDifferenceRatio;
}

class _ShadowAuditSummary {
  const _ShadowAuditSummary(this.results);

  final Map<String, _ShadowResult> results;

  _ShadowAuditSummary scoped(List<String> names) {
    final selected = <String, _ShadowResult>{};
    for (final name in names) {
      final value = results[name];
      if (value != null) selected[name] = value;
    }
    return _ShadowAuditSummary(selected);
  }

  Set<(int, int)> ownedPixels() {
    final result = <(int, int)>{};
    for (final shadow in results.values) {
      for (final point in <(int, int)>[
        ...shadow.referenceWeights.keys,
        ...shadow.candidateWeights.keys,
      ]) {
        for (var offsetY = -1; offsetY <= 1; offsetY++) {
          for (var offsetX = -1; offsetX <= 1; offsetX++) {
            result.add((point.$1 + offsetX, point.$2 + offsetY));
          }
        }
      }
    }
    return result;
  }

  bool get hasFailedChild => results.values.any((result) => result.failed);

  _InkBounds? get referenceBounds => results.values.fold<_InkBounds?>(
    null,
    (bounds, result) => _mergeOptionalBounds(bounds, result.referenceBounds),
  );

  _InkBounds? get candidateBounds => results.values.fold<_InkBounds?>(
    null,
    (bounds, result) => _mergeOptionalBounds(bounds, result.candidateBounds),
  );

  int get differingDarkness =>
      results.values.fold(0, (sum, result) => sum + result.differingDarkness);

  int get auditedDarkness =>
      results.values.fold(0, (sum, result) => sum + result.auditedDarkness);
}

class _ShadowResult {
  const _ShadowResult({
    required this.referenceSurface,
    required this.candidateSurface,
    required this.referenceCore,
    required this.candidateCore,
    required this.referenceBounds,
    required this.candidateBounds,
    required this.referenceWeights,
    required this.candidateWeights,
    required this.noiseFloor,
    required this.differingDarkness,
    required this.auditedDarkness,
  });

  const _ShadowResult.empty()
    : referenceSurface = const _MeasuredInk(0, 0, 0),
      candidateSurface = const _MeasuredInk(0, 0, 0),
      referenceCore = null,
      candidateCore = null,
      referenceBounds = null,
      candidateBounds = null,
      referenceWeights = const <(int, int), int>{},
      candidateWeights = const <(int, int), int>{},
      noiseFloor = 0,
      differingDarkness = 0,
      auditedDarkness = 0;

  final _MeasuredInk referenceSurface;
  final _MeasuredInk candidateSurface;
  final _MeasuredInk? referenceCore;
  final _MeasuredInk? candidateCore;
  final _InkBounds? referenceBounds;
  final _InkBounds? candidateBounds;
  final Map<(int, int), int> referenceWeights;
  final Map<(int, int), int> candidateWeights;
  final int noiseFloor;
  final int differingDarkness;
  final int auditedDarkness;

  int get referenceDarkness =>
      referenceWeights.values.fold(0, (sum, value) => sum + value);
  int get candidateDarkness =>
      candidateWeights.values.fold(0, (sum, value) => sum + value);
  int get surfaceColorDelta => referenceSurface.edgeDelta(candidateSurface);
  bool get hasOneSidedCore =>
      (referenceCore == null) != (candidateCore == null);
  int get coreColorDelta => referenceCore == null || candidateCore == null
      ? 0
      : referenceCore!.edgeDelta(candidateCore!);
  bool get hasOneSidedBounds =>
      (referenceBounds == null) != (candidateBounds == null);
  int get edgeDelta => referenceBounds == null || candidateBounds == null
      ? 0
      : referenceBounds!.edgeDelta(candidateBounds!);
  double get differingRatio =>
      auditedDarkness == 0 ? 1 : differingDarkness / auditedDarkness;
  bool get failed =>
      auditedDarkness == 0 ||
      surfaceColorDelta > _maximumSemanticColorDelta ||
      hasOneSidedCore ||
      coreColorDelta > _maximumSemanticColorDelta ||
      hasOneSidedBounds ||
      edgeDelta > _maximumEdgeDelta ||
      differingRatio > _maximumStaticDifferenceRatio;
}

class _SurfaceCalibration {
  const _SurfaceCalibration(
    this.reference,
    this.candidate,
    this.referenceSamples,
  );

  final _MeasuredInk reference;
  final _MeasuredInk candidate;
  final List<_InkPixel> referenceSamples;

  int get colorDelta => reference.edgeDelta(candidate);
}

class _ReferenceCoverage {
  const _ReferenceCoverage(this.weights, this.seedPixels);

  final Map<(int, int), int> weights;
  final Set<(int, int)> seedPixels;
}

class _ReferenceForegroundConsensus {
  const _ReferenceForegroundConsensus({
    required this.key,
    required this.coverage,
    required this.provenance,
  });

  final ReferenceForegroundConsensusKey key;
  final _ReferenceCoverage coverage;
  final String provenance;
}

class _ReferenceForegroundConsensusIndex {
  const _ReferenceForegroundConsensusIndex(this._byMember);

  final Map<(String, String), _ReferenceForegroundConsensus> _byMember;

  _ReferenceForegroundConsensus forMember(String caseId, String regionName) =>
      _byMember[(caseId, regionName)]!;
}

class _RoleAuditSummary {
  const _RoleAuditSummary({
    required this.candidateSamples,
    required this.referenceBounds,
    required this.candidateBounds,
    required this.residuals,
    required this.measurements,
    required this.failedRegionNames,
  });

  const _RoleAuditSummary.empty()
    : candidateSamples = const <String, _MeasuredInk>{},
      referenceBounds = const <String, _InkBounds>{},
      candidateBounds = const <String, _InkBounds>{},
      residuals = const <String, _RoleResidualResult>{},
      measurements = const <String, _RoleMeasurement>{},
      failedRegionNames = const <String>{};

  final Map<String, _MeasuredInk> candidateSamples;
  final Map<String, _InkBounds> referenceBounds;
  final Map<String, _InkBounds> candidateBounds;
  final Map<String, _RoleResidualResult> residuals;
  final Map<String, _RoleMeasurement> measurements;
  final Set<String> failedRegionNames;

  _RoleAuditSummary scoped(List<String> regionNames) {
    if (regionNames.isEmpty) return this;
    final selected = <String, _RoleMeasurement>{};
    for (final name in regionNames) {
      final measurement = measurements[name];
      if (measurement != null) selected[name] = measurement;
    }
    final samples = <String, List<_MeasuredInk>>{};
    final reference = <String, _InkBounds>{};
    final candidate = <String, _InkBounds>{};
    final roleResiduals = <String, _RoleResidualResult>{};
    for (final measurement in selected.values) {
      samples
          .putIfAbsent(measurement.role, () => <_MeasuredInk>[])
          .add(measurement.candidateInk);
      reference[measurement.role] = _mergeBounds(
        reference[measurement.role],
        measurement.referenceBounds,
      );
      candidate[measurement.role] = _mergeBounds(
        candidate[measurement.role],
        measurement.candidateBounds,
      );
      roleResiduals[measurement.role] =
          (roleResiduals[measurement.role] ?? const _RoleResidualResult.empty())
              .plus(measurement.residual);
    }
    return _RoleAuditSummary(
      candidateSamples: {
        for (final entry in samples.entries)
          entry.key: _MeasuredInk.clusterMedoid(entry.value, radius: 2),
      },
      referenceBounds: reference,
      candidateBounds: candidate,
      residuals: roleResiduals,
      measurements: selected,
      failedRegionNames: failedRegionNames.where(regionNames.contains).toSet(),
    );
  }

  Set<(int, int)> ownedPixels() {
    final result = <(int, int)>{};
    for (final measurement in measurements.values) {
      result
        ..addAll(measurement.residual.referencePixels)
        ..addAll(measurement.residual.candidatePixels);
    }
    return result;
  }

  bool get hasFailedChild =>
      failedRegionNames.isNotEmpty ||
      measurements.values.any((item) => item.failed);

  _InkBounds? combinedReferenceBounds(Set<String> roles) => _combinedBounds(
    referenceBounds.entries.where((entry) => roles.contains(entry.key)),
  );

  _InkBounds? combinedCandidateBounds(Set<String> roles) => _combinedBounds(
    candidateBounds.entries.where((entry) => roles.contains(entry.key)),
  );

  _RoleResidualResult combinedResidual(Set<String> roles) => residuals.entries
      .where((entry) => roles.contains(entry.key))
      .fold(
        const _RoleResidualResult.empty(),
        (result, entry) => result.plus(entry.value),
      );

  _InkBounds? _combinedBounds(Iterable<MapEntry<String, _InkBounds>> entries) {
    _InkBounds? result;
    for (final entry in entries) {
      result = _mergeBounds(result, entry.value);
    }
    return result;
  }
}

class _RoleMeasurement {
  const _RoleMeasurement({
    required this.role,
    required this.candidateInk,
    required this.referenceBounds,
    required this.candidateBounds,
    required this.residual,
    required this.failed,
  });

  final String role;
  final _MeasuredInk candidateInk;
  final _InkBounds referenceBounds;
  final _InkBounds candidateBounds;
  final _RoleResidualResult residual;
  final bool failed;
}

class _RoleResidualResult {
  const _RoleResidualResult(
    this.differingPixelCount,
    this.auditedPixelCount, {
    this.candidateCoreInk,
    this.referencePixels = const <(int, int)>{},
    this.candidatePixels = const <(int, int)>{},
    this.referenceBounds,
    this.candidateBounds,
    this.referenceInvalidPixelCount = 0,
    this.candidateInvalidPixelCount = 0,
    this.hasMissingCore = false,
    this.hasGlobalRoleSeed = true,
    this.hasReciprocalSeedCoverage = true,
    this.referenceComponentCount = 0,
    this.candidateComponentCount = 0,
    this.hasComponentTopologyMatch = true,
    this.referenceComponentSummary = '',
    this.candidateComponentSummary = '',
    this.referenceCoverageMass = 0,
    this.candidateCoverageMass = 0,
    this.referenceCoverageCentroid,
    this.candidateCoverageCentroid,
    this.coverageGridTotalVariationPercent = 0,
    this.supportMismatchSummary = '',
    this.consensusProvenance = '',
  });

  const _RoleResidualResult.empty()
    : differingPixelCount = 0,
      auditedPixelCount = 0,
      candidateCoreInk = null,
      referencePixels = const <(int, int)>{},
      candidatePixels = const <(int, int)>{},
      referenceBounds = null,
      candidateBounds = null,
      referenceInvalidPixelCount = 0,
      candidateInvalidPixelCount = 0,
      hasMissingCore = false,
      hasGlobalRoleSeed = true,
      hasReciprocalSeedCoverage = true,
      referenceComponentCount = 0,
      candidateComponentCount = 0,
      hasComponentTopologyMatch = true,
      referenceComponentSummary = '',
      candidateComponentSummary = '',
      referenceCoverageMass = 0,
      candidateCoverageMass = 0,
      referenceCoverageCentroid = null,
      candidateCoverageCentroid = null,
      coverageGridTotalVariationPercent = 0,
      supportMismatchSummary = '',
      consensusProvenance = '';

  final int differingPixelCount;
  final int auditedPixelCount;
  final _MeasuredInk? candidateCoreInk;
  final Set<(int, int)> referencePixels;
  final Set<(int, int)> candidatePixels;
  final _InkBounds? referenceBounds;
  final _InkBounds? candidateBounds;
  final int referenceInvalidPixelCount;
  final int candidateInvalidPixelCount;
  final bool hasMissingCore;
  final bool hasGlobalRoleSeed;
  final bool hasReciprocalSeedCoverage;
  final int referenceComponentCount;
  final int candidateComponentCount;
  final bool hasComponentTopologyMatch;
  final String referenceComponentSummary;
  final String candidateComponentSummary;
  final int referenceCoverageMass;
  final int candidateCoverageMass;
  final ({double x, double y})? referenceCoverageCentroid;
  final ({double x, double y})? candidateCoverageCentroid;
  final double coverageGridTotalVariationPercent;
  final String supportMismatchSummary;
  final String consensusProvenance;

  int get invalidPixelCount =>
      referenceInvalidPixelCount + candidateInvalidPixelCount;

  bool get hasComponentCountMismatch =>
      referenceComponentCount != candidateComponentCount;

  bool get coverageMassFailed =>
      coverageDensityDeltaPercent > _maximumInkDensityDeltaPercent;

  double get coverageCentroidDeltaX =>
      referenceCoverageCentroid == null || candidateCoverageCentroid == null
      ? double.infinity
      : (referenceCoverageCentroid!.x - candidateCoverageCentroid!.x).abs();

  double get coverageCentroidDeltaY =>
      referenceCoverageCentroid == null || candidateCoverageCentroid == null
      ? double.infinity
      : (referenceCoverageCentroid!.y - candidateCoverageCentroid!.y).abs();

  bool get coverageCentroidFailed =>
      coverageCentroidDeltaX > _maximumEdgeDelta ||
      coverageCentroidDeltaY > _maximumEdgeDelta;

  bool get coverageGridFailed =>
      coverageGridTotalVariationPercent > _maximumInkDensityDeltaPercent;

  int get edgeDelta => referenceBounds == null || candidateBounds == null
      ? 0
      : referenceBounds!.edgeDelta(candidateBounds!);

  double get coverageDensityDeltaPercent => referenceCoverageMass == 0
      ? (candidateCoverageMass == 0 ? 0 : double.infinity)
      : ((referenceCoverageMass - candidateCoverageMass).abs() /
                referenceCoverageMass) *
            100;

  double get coverageDensityRatio => referenceCoverageMass == 0
      ? double.infinity
      : candidateCoverageMass / referenceCoverageMass;

  double get differingPixelRatio =>
      auditedPixelCount == 0 ? 1 : differingPixelCount / auditedPixelCount;

  _RoleResidualResult plus(_RoleResidualResult other) => _RoleResidualResult(
    differingPixelCount + other.differingPixelCount,
    auditedPixelCount + other.auditedPixelCount,
    candidateCoreInk: candidateCoreInk ?? other.candidateCoreInk,
    referencePixels: {...referencePixels, ...other.referencePixels},
    candidatePixels: {...candidatePixels, ...other.candidatePixels},
    referenceBounds: _mergeOptionalBounds(
      referenceBounds,
      other.referenceBounds,
    ),
    candidateBounds: _mergeOptionalBounds(
      candidateBounds,
      other.candidateBounds,
    ),
    referenceInvalidPixelCount:
        referenceInvalidPixelCount + other.referenceInvalidPixelCount,
    candidateInvalidPixelCount:
        candidateInvalidPixelCount + other.candidateInvalidPixelCount,
    hasMissingCore: hasMissingCore || other.hasMissingCore,
    hasGlobalRoleSeed: hasGlobalRoleSeed && other.hasGlobalRoleSeed,
    hasReciprocalSeedCoverage:
        hasReciprocalSeedCoverage && other.hasReciprocalSeedCoverage,
    referenceComponentCount:
        referenceComponentCount + other.referenceComponentCount,
    candidateComponentCount:
        candidateComponentCount + other.candidateComponentCount,
    hasComponentTopologyMatch:
        hasComponentTopologyMatch && other.hasComponentTopologyMatch,
    referenceComponentSummary: [
      referenceComponentSummary,
      other.referenceComponentSummary,
    ].where((value) => value.isNotEmpty).join('|'),
    candidateComponentSummary: [
      candidateComponentSummary,
      other.candidateComponentSummary,
    ].where((value) => value.isNotEmpty).join('|'),
    referenceCoverageMass: referenceCoverageMass + other.referenceCoverageMass,
    candidateCoverageMass: candidateCoverageMass + other.candidateCoverageMass,
    referenceCoverageCentroid: _mergeCoverageCentroids(
      referenceCoverageCentroid,
      referenceCoverageMass,
      other.referenceCoverageCentroid,
      other.referenceCoverageMass,
    ),
    candidateCoverageCentroid: _mergeCoverageCentroids(
      candidateCoverageCentroid,
      candidateCoverageMass,
      other.candidateCoverageCentroid,
      other.candidateCoverageMass,
    ),
    coverageGridTotalVariationPercent: math.max(
      coverageGridTotalVariationPercent,
      other.coverageGridTotalVariationPercent,
    ),
    supportMismatchSummary: [
      supportMismatchSummary,
      other.supportMismatchSummary,
    ].where((value) => value.isNotEmpty).join('|'),
    consensusProvenance: [
      consensusProvenance,
      other.consensusProvenance,
    ].where((value) => value.isNotEmpty).join('|'),
  );
}

({double x, double y})? _mergeCoverageCentroids(
  ({double x, double y})? left,
  int leftMass,
  ({double x, double y})? right,
  int rightMass,
) {
  final totalMass = leftMass + rightMass;
  if (totalMass == 0) return null;
  return (
    x: ((left?.x ?? 0) * leftMass + (right?.x ?? 0) * rightMass) / totalMass,
    y: ((left?.y ?? 0) * leftMass + (right?.y ?? 0) * rightMass) / totalMass,
  );
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
  const _TextSample(
    this.bounds,
    this.semanticInk,
    this.opticalInkArea,
    this.geometryPixels,
  );

  final _InkBounds bounds;
  final _MeasuredInk semanticInk;
  final double opticalInkArea;
  final List<_InkPixel> geometryPixels;

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

  factory _MeasuredInk.fromRgbKey(int key) =>
      _MeasuredInk((key >> 16) & 0xff, (key >> 8) & 0xff, key & 0xff);

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

  factory _MeasuredInk.channelMedian(List<_InkPixel> pixels) {
    int median(Iterable<int> source) {
      final values = source.toList()..sort();
      final lower = values[(values.length - 1) ~/ 2];
      final upper = values[values.length ~/ 2];
      return (lower + upper) ~/ 2;
    }

    return _MeasuredInk(
      median(pixels.map((pixel) => pixel.red)),
      median(pixels.map((pixel) => pixel.green)),
      median(pixels.map((pixel) => pixel.blue)),
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

  int get rgbKey => (red << 16) | (green << 8) | blue;

  ReferenceInk toReferenceInk() => ReferenceInk(red, green, blue);

  static _MeasuredInk clusterMedoid(
    List<_MeasuredInk> samples, {
    required int radius,
  }) {
    if (samples.isEmpty) throw StateError('Cannot cluster empty ink samples.');
    var largest = <_MeasuredInk>[];
    for (final center in samples) {
      final cluster = samples
          .where((sample) => sample.edgeDelta(center) <= radius)
          .toList(growable: false);
      if (cluster.length > largest.length) largest = cluster;
    }
    final ordered = [...largest]
      ..sort((left, right) {
        int cost(_MeasuredInk candidate) =>
            largest.fold(0, (sum, sample) => sum + candidate.edgeDelta(sample));
        final byCost = cost(left).compareTo(cost(right));
        return byCost != 0 ? byCost : left.rgbKey.compareTo(right.rgbKey);
      });
    return ordered.first;
  }

  int edgeDelta(_MeasuredInk other) => _maximum(
    (red - other.red).abs(),
    (green - other.green).abs(),
    (blue - other.blue).abs(),
  );

  @override
  String toString() => 'rgb($red,$green,$blue)';
}

class _CsvReport {
  _CsvReport({this.deferCanonicalReferenceFailures = false}) {
    _buffer.writeln(_header);
    _atomicEvidenceBuffer.writeln(_header);
    _surfaceEvidenceBuffer.writeln(_header);
  }

  static const _header =
      'recordType,candidateRenderer,case,regionType,region,referenceBounds,'
      'candidateBounds,edgeDelta,manifestInkHint,measuredReferenceInk,'
      'candidateInk,semanticInkDelta,measuredReferenceForeground,'
      'candidateForeground,foregroundColorDelta,inkDensityDeltaPercent,candidateInkRatio,'
      'differingPixelCount,auditedPixelCount,differingPixelRatio,status,details';

  final bool deferCanonicalReferenceFailures;
  final StringBuffer _buffer = StringBuffer();
  final StringBuffer _atomicEvidenceBuffer = StringBuffer();
  final StringBuffer _surfaceEvidenceBuffer = StringBuffer();

  String get contents => _buffer.toString();
  String get atomicEvidenceContents => _atomicEvidenceBuffer.toString();
  String get surfaceEvidenceContents => _surfaceEvidenceBuffer.toString();

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
    String measuredReferenceForeground = '',
    String candidateForeground = '',
    String foregroundColorDelta = '',
    String inkDensityDeltaPercent = '',
    String candidateInkRatio = '',
    String differingPixelCount = '',
    String auditedPixelCount = '',
    String differingPixelRatio = '',
    required String status,
    String details = '',
  }) {
    final cells = <String>[
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
      measuredReferenceForeground,
      candidateForeground,
      foregroundColorDelta,
      inkDensityDeltaPercent,
      candidateInkRatio,
      differingPixelCount,
      auditedPixelCount,
      differingPixelRatio,
      status,
      details,
    ];
    final isAtomicNavigation =
        (recordType == 'static-control' || recordType == 'text') &&
        regionName.startsWith('navigation-') &&
        (regionName.endsWith('-icon') || regionName.endsWith('-label'));
    if (deferCanonicalReferenceFailures && isAtomicNavigation) {
      _atomicEvidenceBuffer.writeln(cells.map(_csvCell).join(','));
      if (status == 'FAIL') {
        cells[cells.length - 1] = _atomicEvidenceDeferredDetail;
      }
    }
    final isNavigationSurface =
        recordType == 'static-surface' &&
        (regionName == 'bottom-navigation-capsule-surface' ||
            regionName == 'bottom-navigation-selected-pill-surface');
    if (deferCanonicalReferenceFailures && isNavigationSurface) {
      _surfaceEvidenceBuffer.writeln(cells.map(_csvCell).join(','));
      if (status == 'FAIL') {
        cells[cells.length - 1] = _atomicEvidenceDeferredDetail;
      }
    }
    _buffer.writeln(cells.map(_csvCell).join(','));
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

class _DecodedComparisonCase {
  const _DecodedComparisonCase({
    required this.referenceCase,
    required this.reference,
    required this.candidate,
    required this.referencePath,
  });

  final TabReferenceCase referenceCase;
  final image.Image reference;
  final image.Image candidate;
  final String referencePath;
}

class _ComparisonConfiguration {
  const _ComparisonConfiguration({
    required this.candidateDirectory,
    required this.renderer,
    this.caseId,
    this.outputDirectory,
  });

  factory _ComparisonConfiguration.parse(List<String> args) {
    var candidateDirectory = 'test/goldens/tab-typography';
    var renderer = _CandidateRenderer.deterministic;
    String? outputDirectory;
    String? caseId;
    final seen = <String>{};
    for (var index = 0; index < args.length; index++) {
      final flag = args[index];
      if (!const {
        '--candidate-dir',
        '--candidate-renderer',
        '--output-dir',
        '--case',
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
        case '--case':
          caseId = value;
      }
    }
    return _ComparisonConfiguration(
      candidateDirectory: candidateDirectory,
      renderer: renderer,
      outputDirectory: outputDirectory,
      caseId: caseId,
    );
  }

  static const usage =
      'Usage: dart run tool/compare_tab_typography.dart '
      '[--candidate-dir <directory>] '
      '[--candidate-renderer deterministic|android] '
      '[--output-dir <directory>] '
      '[--case <case-id>]';

  final String candidateDirectory;
  final _CandidateRenderer renderer;
  final String? outputDirectory;
  final String? caseId;
}

class _ComparisonInputError implements Exception {
  const _ComparisonInputError(this.message);

  final String message;
}

class _UsageError implements Exception {
  const _UsageError(this.message);

  final String message;
}
