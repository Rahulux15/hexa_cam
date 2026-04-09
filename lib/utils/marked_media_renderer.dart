import 'dart:async';
import 'dart:math' show sqrt;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/models/annotation.dart';
import '../data/models/point.dart';
import 'annotation_painter.dart';

class MarkedMediaRenderer {
  // Keep exported stroke thickness visually consistent with live drawing.
  // High-resolution exports need stronger scale so marks remain legible in
  // gallery thumbnails, reports, and saved media across devices.
  static double _exportUiScale(Size sourceSize) {
    final shortSide = sourceSize.shortestSide <= 0 ? 1.0 : sourceSize.shortestSide;
    return (shortSide / 720.0).clamp(1.35, 4.4).toDouble();
  }

  static Future<Uint8List> renderAnnotationOverlay({
    required Size sourceSize,
    required List<Annotation> annotations,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
  }) async {
    final exportScale = _exportUiScale(sourceSize);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = AnnotationPainter(
      annotations: annotations,
      displaySize: sourceSize,
      sourceSize: sourceSize,
      fit: BoxFit.contain,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      zoom: 1,
      rotation: rotation,
      lineWidthScale: exportScale,
      uiTextScale: exportScale,
    );
    painter.paint(canvas, sourceSize);
    final outImage = await recorder.endRecording().toImage(
          sourceSize.width.round().clamp(1, 8192),
          sourceSize.height.round().clamp(1, 8192),
        );
    final outData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    return outData!.buffer.asUint8List();
  }

  static Future<Uint8List> renderPhotoWithAnnotations({
    required Uint8List baseImageBytes,
    required List<Annotation> annotations,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
    Size? annotationSourceSize,
  }) async {
    final image = await _decodeImage(baseImageBytes);
    final sourceSize = Size(image.width.toDouble(), image.height.toDouble());
    final normalizedAnnotations = _normalizeAnnotationsToTarget(
      annotations: annotations,
      annotationSourceSize: annotationSourceSize,
      targetSize: sourceSize,
    );
    final exportScale = _exportUiScale(sourceSize);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final center = Offset(sourceSize.width / 2, sourceSize.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 3.1415926535897932 / 180.0);
    canvas.scale(mirrorX ? -1.0 : 1.0, mirrorY ? -1.0 : 1.0);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, sourceSize.width, sourceSize.height),
      Rect.fromCenter(
        center: Offset.zero,
        width: sourceSize.width,
        height: sourceSize.height,
      ),
      Paint(),
    );
    canvas.restore();

    final painter = AnnotationPainter(
      annotations: normalizedAnnotations,
      displaySize: sourceSize,
      sourceSize: sourceSize,
      fit: BoxFit.contain,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      zoom: 1,
      rotation: rotation,
      lineWidthScale: exportScale,
      uiTextScale: exportScale,
    );
    painter.paint(canvas, sourceSize);

    final outImage = await recorder
        .endRecording()
        .toImage(image.width, image.height);
    final outData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    return outData!.buffer.asUint8List();
  }

  static List<Annotation> _normalizeAnnotationsToTarget({
    required List<Annotation> annotations,
    required Size? annotationSourceSize,
    required Size targetSize,
  }) {
    final src = annotationSourceSize;
    if (src == null ||
        src.width <= 0 ||
        src.height <= 0 ||
        targetSize.width <= 0 ||
        targetSize.height <= 0) {
      return annotations;
    }
    final sx = targetSize.width / src.width;
    final sy = targetSize.height / src.height;
    final swappedSx = targetSize.width / src.height;
    final swappedSy = targetSize.height / src.width;
    if ((sx - 1.0).abs() < 0.001 && (sy - 1.0).abs() < 0.001) {
      return annotations;
    }
    final raw = annotations;
    final direct = _scaleAnnotations(annotations, sx: sx, sy: sy);
    final swapped = _scaleAnnotations(
      annotations,
      sx: swappedSx,
      sy: swappedSy,
    );
    final rawScore = _placementScore(raw, targetSize);
    final directScore = _placementScore(direct, targetSize);
    final swappedScore = _placementScore(swapped, targetSize);
    if (rawScore >= directScore && rawScore >= swappedScore) {
      return raw;
    }
    return swappedScore > directScore ? swapped : direct;
  }

  static List<Annotation> _scaleAnnotations(
    List<Annotation> annotations, {
    required double sx,
    required double sy,
  }) {
    return annotations
        .map(
          (annotation) => annotation.copyWith(
            points: annotation.points
                .map((p) => HexaPoint(x: p.x * sx, y: p.y * sy))
                .toList(),
          ),
        )
        .toList(growable: false);
  }

  static double _placementScore(List<Annotation> annotations, Size size) {
    if (size.width <= 0 || size.height <= 0) return 0;
    var inBounds = 0;
    var total = 0;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    for (final annotation in annotations) {
      for (final p in annotation.points) {
        total++;
        if (p.x >= -4 &&
            p.y >= -4 &&
            p.x <= size.width + 4 &&
            p.y <= size.height + 4) {
          inBounds++;
        }
        if (p.x < minX) minX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
      }
    }
    if (total == 0) return 0;
    final inBoundsRatio = inBounds / total;
    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return inBoundsRatio;
    }
    final width = (maxX - minX).abs();
    final height = (maxY - minY).abs();
    final imageDiag = sqrt((size.width * size.width) + (size.height * size.height));
    final markDiag = sqrt((width * width) + (height * height));
    final spread = imageDiag <= 0 ? 0.0 : (markDiag / imageDiag).clamp(0.0, 1.0);

    // Prefer mappings that keep points in frame and preserve realistic spread.
    // This avoids selecting tiny clustered overlays when a better mapping exists.
    return (inBoundsRatio * 0.8) + (spread * 0.2);
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }
}
