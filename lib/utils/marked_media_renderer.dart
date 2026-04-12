import 'dart:async';
import 'dart:math' show sqrt;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/models/annotation.dart';
import '../data/models/point.dart';
import 'annotation_painter.dart';

class MarkedMediaRenderer {
  // Keep export paint scale neutral for strict WYSIWYG parity across
  // capture-preview, save/download, and report media.
  static double _exportLineScale(Size sourceSize) => 1.0;

  static double _exportTextScale(Size sourceSize) => 1.0;

  static Future<Uint8List> renderAnnotationOverlay({
    required Size sourceSize,
    required List<Annotation> annotations,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
  }) async {
    final lineScale = _exportLineScale(sourceSize);
    final textScale = _exportTextScale(sourceSize);
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
      lineWidthScale: lineScale,
      uiTextScale: textScale,
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
    int? maxDecodeEdge,
  }) async {
    // Authoring resolution (full file) — used so stroke/text scale with decode
    // downscaling ([maxDecodeEdge]) instead of looking thinner than capture UI.
    final peeked = await peekEncodedImageSize(baseImageBytes);
    final Size authoringSize;
    if (annotationSourceSize != null &&
        annotationSourceSize.width > 0 &&
        annotationSourceSize.height > 0) {
      authoringSize = annotationSourceSize;
    } else if (peeked != null && peeked.width > 0 && peeked.height > 0) {
      authoringSize = peeked;
    } else {
      authoringSize = Size.zero;
    }

    final image = await _decodeImage(
      baseImageBytes,
      maxDecodeEdge: maxDecodeEdge,
    );
    final sourceSize = Size(image.width.toDouble(), image.height.toDouble());
    final normalizedAnnotations = normalizeAnnotationsToTarget(
      annotations: annotations,
      annotationSourceSize:
          authoringSize == Size.zero ? null : authoringSize,
      targetSize: sourceSize,
    );
    final lineScale = _exportLineScale(sourceSize);
    final textScale = _exportTextScale(sourceSize);
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
      lineWidthScale: lineScale,
      uiTextScale: textScale,
    );
    painter.paint(canvas, sourceSize);

    final outImage =
        await recorder.endRecording().toImage(image.width, image.height);
    final outData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    return outData!.buffer.asUint8List();
  }

  static List<Annotation> normalizeAnnotationsToTarget({
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
    // Only skip normalization when decoded size matches authoring size (no downscale).
    if ((sx - 1.0).abs() < 1e-5 && (sy - 1.0).abs() < 1e-5) {
      return annotations;
    }
    final direct = _scaleAnnotations(annotations, sx: sx, sy: sy);
    final swapped = _scaleAnnotations(
      annotations,
      sx: swappedSx,
      sy: swappedSy,
    );

    // Prefer deterministic aspect-ratio matching to avoid drift between
    // preview/save/report when only one axis differs or metadata swaps axes.
    final targetAspect = targetSize.width / targetSize.height;
    final srcAspect = src.width / src.height;
    final swappedAspect = src.height / src.width;
    final directAspectErr = (srcAspect - targetAspect).abs();
    final swappedAspectErr = (swappedAspect - targetAspect).abs();

    final directScore = _placementScore(direct, targetSize);
    final swappedScore = _placementScore(swapped, targetSize);

    // If one mapping clearly fits aspect better, use it.
    if ((directAspectErr - swappedAspectErr).abs() > 0.015) {
      return directAspectErr < swappedAspectErr ? direct : swapped;
    }

    // Otherwise choose the mapping that keeps more points in-bounds.
    return swappedScore > directScore ? swapped : direct;
  }

  static List<Annotation> _scaleAnnotations(
    List<Annotation> annotations, {
    required double sx,
    required double sy,
  }) {
    final sxAbs = sx.abs();
    final syAbs = sy.abs();
    // Isotropic scale for pen thickness / font (matches area scaling of the bitmap).
    // Do **not** cap the upper bound (was 8.0): preview buffers are often much
    // smaller than full-resolution stills, so capping made saved/exported strokes
    // look thinner than on-screen (points used unclamped sx/sy).
    final strokeScale = (sxAbs <= 0 || syAbs <= 0)
        ? 1.0
        : sqrt(sxAbs * syAbs).clamp(0.01, 2048.0).toDouble();
    return annotations
        .map(
          (annotation) => annotation.copyWith(
            strokeWidth:
                (annotation.strokeWidth * strokeScale).clamp(0.5, 256.0),
            labelFontSize: annotation.labelFontSize == null
                ? null
                : (annotation.labelFontSize! * strokeScale)
                    .clamp(8.0, 512.0)
                    .toDouble(),
            labelOffsetX: annotation.labelOffsetX * sx,
            labelOffsetY: annotation.labelOffsetY * sy,
            strokeInSourcePixels: annotation.strokeInSourcePixels,
            points: annotation.points
                .map((p) => HexaPoint(x: p.x * sx, y: p.y * sy))
                .toList(),
          ),
        )
        .toList(growable: false);
  }

  /// Raster dimensions from encoded bytes without full decode (cheap).
  /// Used to scale annotations when [ImageData.sourceWidth]/Height are missing.
  static Future<Size?> peekEncodedImageSize(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      descriptor.dispose();
      buffer.dispose();
      if (w <= 0 || h <= 0) return null;
      return Size(w.toDouble(), h.toDouble());
    } catch (_) {
      return null;
    }
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
    final imageDiag =
        sqrt((size.width * size.width) + (size.height * size.height));
    final markDiag = sqrt((width * width) + (height * height));
    final spread =
        imageDiag <= 0 ? 0.0 : (markDiag / imageDiag).clamp(0.0, 1.0);

    // Prefer mappings that keep points in frame and preserve realistic spread.
    // This avoids selecting tiny clustered overlays when a better mapping exists.
    return (inBoundsRatio * 0.8) + (spread * 0.2);
  }

  static Future<ui.Image> _decodeImage(
    Uint8List bytes, {
    int? maxDecodeEdge,
  }) async {
    final edge = maxDecodeEdge;
    if (edge == null || edge <= 0) {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, completer.complete);
      return completer.future;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width;
    final height = descriptor.height;
    final longest = width > height ? width : height;
    final scale = longest > edge ? (edge / longest) : 1.0;
    final targetWidth = (width * scale).round().clamp(1, edge);
    final targetHeight = (height * scale).round().clamp(1, edge);
    final codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    return frame.image;
  }

  /// Decodes raster dimensions (without rendering annotations).
  static Future<Size?> decodeImageSize(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    final image = await _decodeImage(bytes);
    if (image.width <= 0 || image.height <= 0) return null;
    return Size(image.width.toDouble(), image.height.toDouble());
  }
}
