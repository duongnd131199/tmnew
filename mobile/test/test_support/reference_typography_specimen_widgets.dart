import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reference_typography_role_manifest.dart';

const referenceFontSpecimenLogicalSize = Size(393.3333333333, 620);
const referenceFontSpecimenDevicePixelRatio = 1.5;
const referenceFontSpecimenPhysicalSize = Size(590, 930);

class ReferenceFontSpecimenRasterCapture {
  const ReferenceFontSpecimenRasterCapture({
    required this.pngBytes,
    required this.debugPaintBaselinesEnabledAtCapture,
    required this.opaque,
    required this.grayscale,
  });

  final Uint8List pngBytes;
  final bool debugPaintBaselinesEnabledAtCapture;
  final bool opaque;
  final bool grayscale;

  Map<String, Object> get evidence => {
    'opaque': opaque,
    'grayscale': grayscale,
    'debugPaintBaselinesEnabledAtCapture': debugPaintBaselinesEnabledAtCapture,
  };
}

Future<ReferenceFontSpecimenRasterCapture> captureReferenceFontSpecimenBoundary(
  WidgetTester tester,
  RenderRepaintBoundary boundary,
) async {
  if (debugPaintBaselinesEnabled) {
    throw StateError(
      'Baseline debug paint must be disabled before specimen build and capture',
    );
  }
  final rendered = await boundary.toImage(
    pixelRatio: referenceFontSpecimenDevicePixelRatio,
  );
  try {
    final encoded = await tester.runAsync(
      () => rendered.toByteData(format: ui.ImageByteFormat.png),
    );
    final rgba = await tester.runAsync(
      () => rendered.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    if (encoded == null || rgba == null) {
      throw StateError('Unable to encode reference specimen raster');
    }
    final violation = _firstOpaqueGrayscaleViolation(rgba);
    if (violation != null) {
      throw StateError(
        'Reference specimen raster is not grayscale: $violation',
      );
    }
    return ReferenceFontSpecimenRasterCapture(
      pngBytes: encoded.buffer.asUint8List(
        encoded.offsetInBytes,
        encoded.lengthInBytes,
      ),
      debugPaintBaselinesEnabledAtCapture: debugPaintBaselinesEnabled,
      opaque: true,
      grayscale: true,
    );
  } finally {
    rendered.dispose();
  }
}

Future<T> runReferenceFontSpecimenRasterCaptureScope<T>(
  WidgetTester tester,
  Future<T> Function() buildPumpAndCapture,
) async {
  final externalDebugPaintBaselinesEnabled = debugPaintBaselinesEnabled;
  try {
    debugPaintBaselinesEnabled = false;
    return await buildPumpAndCapture();
  } finally {
    debugPaintBaselinesEnabled = externalDebugPaintBaselinesEnabled;
    _markAllRenderObjectsNeedsPaint();
    await tester.pump();
  }
}

void _markAllRenderObjectsNeedsPaint() {
  late final RenderObjectVisitor markSubtree;
  markSubtree = (child) {
    child.markNeedsPaint();
    child.visitChildren(markSubtree);
  };
  for (final renderView in RendererBinding.instance.renderViews) {
    renderView.markNeedsPaint();
    renderView.visitChildren(markSubtree);
  }
}

String? _firstOpaqueGrayscaleViolation(ByteData rgba) {
  for (var offset = 0; offset < rgba.lengthInBytes; offset += 4) {
    final red = rgba.getUint8(offset);
    final green = rgba.getUint8(offset + 1);
    final blue = rgba.getUint8(offset + 2);
    final alpha = rgba.getUint8(offset + 3);
    if (alpha != 255 || red != green || green != blue) {
      final pixel = offset ~/ 4;
      return 'pixel $pixel is rgba($red,$green,$blue,$alpha)';
    }
  }
  return null;
}

class ReferenceFontSpecimenSheet extends StatelessWidget {
  const ReferenceFontSpecimenSheet({required this.candidate, super.key});

  final ReferenceFontSpecimenCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          for (final run in referenceFontSpecimenOutputRuns)
            if (run.supports(candidate))
              Positioned(
                left:
                    run.physicalRect.left /
                    referenceFontSpecimenDevicePixelRatio,
                top:
                    run.physicalRect.top /
                    referenceFontSpecimenDevicePixelRatio,
                width:
                    run.physicalRect.width /
                    referenceFontSpecimenDevicePixelRatio,
                height:
                    run.physicalRect.height /
                    referenceFontSpecimenDevicePixelRatio,
                child: RepaintBoundary(
                  key: ValueKey(run.keyFor(candidate)),
                  child: ColoredBox(
                    color: Colors.white,
                    child: SizedBox.expand(
                      child: Baseline(
                        baseline:
                            (run.physicalBaseline - run.physicalRect.top) /
                            referenceFontSpecimenDevicePixelRatio,
                        baselineType: TextBaseline.alphabetic,
                        child: SizedBox(
                          width:
                              run.physicalRect.width /
                              referenceFontSpecimenDevicePixelRatio,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left:
                                  run.horizontalLayout ==
                                      ReferenceRunHorizontalLayout.leading
                                  ? run.guardPadding /
                                        referenceFontSpecimenDevicePixelRatio
                                  : 0,
                              right:
                                  run.horizontalLayout ==
                                      ReferenceRunHorizontalLayout.trailing
                                  ? run.guardPadding /
                                        referenceFontSpecimenDevicePixelRatio
                                  : 0,
                            ),
                            child: Align(
                              alignment: switch (run.horizontalLayout) {
                                ReferenceRunHorizontalLayout.leading =>
                                  Alignment.centerLeft,
                                ReferenceRunHorizontalLayout.center =>
                                  Alignment.center,
                                ReferenceRunHorizontalLayout.trailing =>
                                  Alignment.centerRight,
                              },
                              heightFactor: 1,
                              child: Text(
                                run.text,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: Colors.black,
                                  decoration: TextDecoration.none,
                                  fontFamily: candidate.family,
                                  fontSize: run.pointSize,
                                  fontWeight: FontWeight
                                      .values[(candidate.weight ~/ 100) - 1],
                                  height: 1,
                                  letterSpacing: run.letterSpacing,
                                  fontFeatures: run.tabularFigures
                                      ? const <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class ReferenceFontCoverageSheet extends StatelessWidget {
  const ReferenceFontCoverageSheet({required this.candidate, super.key});

  final ReferenceFontSpecimenCandidate candidate;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: Stack(
      children: [
        for (final coverage in referenceFontCoverageRuns)
          Positioned(
            left:
                coverage.physicalRect.left /
                referenceFontSpecimenDevicePixelRatio,
            top:
                coverage.physicalRect.top /
                referenceFontSpecimenDevicePixelRatio,
            width:
                coverage.physicalRect.width /
                referenceFontSpecimenDevicePixelRatio,
            height:
                coverage.physicalRect.height /
                referenceFontSpecimenDevicePixelRatio,
            child: RepaintBoundary(
              key: ValueKey(coverage.keyFor(candidate)),
              child: ColoredBox(
                color: Colors.white,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: coverage.index == 3
                      ? _ReferencePriceCoverageRow(candidate: candidate)
                      : Text(
                          coverage.text,
                          maxLines: 1,
                          textScaler: TextScaler.noScaling,
                          style: _coverageStyle(candidate),
                        ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

TextStyle _coverageStyle(ReferenceFontSpecimenCandidate candidate) => TextStyle(
  color: Colors.black,
  decoration: TextDecoration.none,
  fontFamily: candidate.family,
  fontSize: 12,
  fontWeight: FontWeight.values[(candidate.weight ~/ 100) - 1],
  height: 1,
);

class _ReferencePriceCoverageRow extends StatelessWidget {
  const _ReferencePriceCoverageRow({required this.candidate});

  final ReferenceFontSpecimenCandidate candidate;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('4637.05 ', style: _coverageStyle(candidate)),
      const CustomPaint(
        key: Key('numeric-price-arrow'),
        size: Size(12, 12),
        painter: ReferencePriceArrowPainter(),
      ),
      Text(' 4640.81', style: _coverageStyle(candidate)),
    ],
  );
}

class ReferencePriceArrowPainter extends CustomPainter {
  const ReferencePriceArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final y = size.height / 2;
    canvas.drawLine(Offset(1, y), Offset(size.width - 2, y), paint);
    canvas.drawLine(
      Offset(size.width - 7, y - 5),
      Offset(size.width - 2, y),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 7, y + 5),
      Offset(size.width - 2, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(ReferencePriceArrowPainter oldDelegate) => false;
}
