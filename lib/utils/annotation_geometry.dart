import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import 'coordinate_transformer.dart';
import '../data/models/point.dart';

/// Uniform scale from **source image coordinates** to the annotation canvas
/// (same factor used to map [HexaPoint] paths in [AnnotationPainter]).
///
/// Stroke widths chosen in the UI are in **canvas pixels** on this surface.
/// Dividing by this value stores thickness in **source pixels** so full-resolution
/// exports match on-screen proportions.
double annotationContentScale({
  required Size displaySize,
  required Size sourceSize,
  required BoxFit fit,
  required bool mirrorX,
  required bool mirrorY,
  required int rotation,
  double zoom = 1,
}) {
  final sourceW = sourceSize.width <= 0 ? 1.0 : sourceSize.width;
  final sourceH = sourceSize.height <= 0 ? 1.0 : sourceSize.height;
  final displayW = displaySize.width <= 0 ? 1.0 : displaySize.width;
  final displayH = displaySize.height <= 0 ? 1.0 : displaySize.height;
  final transformed = CoordinateTransformer.buildImageTransform(
    imageSize: Size(sourceW, sourceH),
    mirrorX: mirrorX,
    mirrorY: mirrorY,
    rotation: rotation,
  );

  final corners = [
    const HexaPoint(x: 0, y: 0),
    HexaPoint(x: sourceW, y: 0),
    HexaPoint(x: 0, y: sourceH),
    HexaPoint(x: sourceW, y: sourceH),
  ].map((point) {
    final v = transformed.transform3(Vector3(point.x, point.y, 1));
    return Offset(v.x, v.y);
  }).toList();

  final minX = corners.map((p) => p.dx).reduce(math.min);
  final maxX = corners.map((p) => p.dx).reduce(math.max);
  final minY = corners.map((p) => p.dy).reduce(math.min);
  final maxY = corners.map((p) => p.dy).reduce(math.max);
  final transformedW = (maxX - minX).clamp(1.0, double.infinity);
  final transformedH = (maxY - minY).clamp(1.0, double.infinity);
  final baseScale = fit == BoxFit.cover
      ? math.max(displayW / transformedW, displayH / transformedH)
      : math.min(displayW / transformedW, displayH / transformedH);
  return baseScale * zoom;
}

/// Converts a stroke width drawn in **canvas pixels** on the preview to
/// **source pixels** for persistence ([strokeInSourcePixels] == true).
double uiStrokeWidthToSource(double uiWidth, double contentScale) {
  final s = contentScale <= 1e-9 ? 1.0 : contentScale;
  return uiWidth / s;
}

/// Shared layout math with [AnnotationPainter] — source ↔ preview display.
class _PreviewLayout {
  _PreviewLayout({
    required this.transformed,
    required this.minX,
    required this.minY,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  final Matrix4 transformed;
  final double minX;
  final double minY;
  final double scale;
  final double offsetX;
  final double offsetY;

  static _PreviewLayout compute({
    required Size sourceSize,
    required Size displaySize,
    required BoxFit fit,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
    double zoom = 1,
  }) {
    final sourceW = sourceSize.width <= 0 ? 1.0 : sourceSize.width;
    final sourceH = sourceSize.height <= 0 ? 1.0 : sourceSize.height;
    final displayW = displaySize.width <= 0 ? 1.0 : displaySize.width;
    final displayH = displaySize.height <= 0 ? 1.0 : displaySize.height;
    final transformed = CoordinateTransformer.buildImageTransform(
      imageSize: Size(sourceW, sourceH),
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
    );

    final corners = [
      const HexaPoint(x: 0, y: 0),
      HexaPoint(x: sourceW, y: 0),
      HexaPoint(x: 0, y: sourceH),
      HexaPoint(x: sourceW, y: sourceH),
    ].map((point) {
      final v = transformed.transform3(Vector3(point.x, point.y, 1));
      return Offset(v.x, v.y);
    }).toList();

    final minX = corners.map((p) => p.dx).reduce(math.min);
    final maxX = corners.map((p) => p.dx).reduce(math.max);
    final minY = corners.map((p) => p.dy).reduce(math.min);
    final maxY = corners.map((p) => p.dy).reduce(math.max);
    final transformedW = (maxX - minX).clamp(1.0, double.infinity);
    final transformedH = (maxY - minY).clamp(1.0, double.infinity);
    final scale = annotationContentScale(
      displaySize: Size(displayW, displayH),
      sourceSize: Size(sourceW, sourceH),
      fit: fit,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
      zoom: zoom,
    );
    final offsetX = (displayW - transformedW * scale) / 2;
    final offsetY = (displayH - transformedH * scale) / 2;

    return _PreviewLayout(
      transformed: transformed,
      minX: minX,
      minY: minY,
      scale: scale,
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }
}

/// Maps a point from **source image** coords to **preview display** pixels
/// (same transform as [AnnotationPainter]).
Offset mapSourcePointToPreviewDisplay(
  HexaPoint p, {
  required Size sourceSize,
  required Size displaySize,
  BoxFit fit = BoxFit.contain,
  bool mirrorX = false,
  bool mirrorY = false,
  int rotation = 0,
  double zoom = 1,
}) {
  final L = _PreviewLayout.compute(
    sourceSize: sourceSize,
    displaySize: displaySize,
    fit: fit,
    mirrorX: mirrorX,
    mirrorY: mirrorY,
    rotation: rotation,
    zoom: zoom,
  );
  final v = L.transformed.transform3(Vector3(p.x, p.y, 1));
  return Offset(
    L.offsetX + ((v.x - L.minX) * L.scale),
    L.offsetY + ((v.y - L.minY) * L.scale),
  );
}

/// Maps a **source-space** label offset to display pixels (rotation / mirror aware).
Offset mapSourceLabelDeltaToPreviewDisplay(
  HexaPoint delta, {
  required Size sourceSize,
  required Size displaySize,
  BoxFit fit = BoxFit.contain,
  bool mirrorX = false,
  bool mirrorY = false,
  int rotation = 0,
  double zoom = 1,
}) {
  final L = _PreviewLayout.compute(
    sourceSize: sourceSize,
    displaySize: displaySize,
    fit: fit,
    mirrorX: mirrorX,
    mirrorY: mirrorY,
    rotation: rotation,
    zoom: zoom,
  );
  final origin = L.transformed.transform3(Vector3(0, 0, 1));
  final shifted = L.transformed.transform3(Vector3(delta.x, delta.y, 1));
  return Offset(
    (shifted.x - origin.x) * L.scale,
    (shifted.y - origin.y) * L.scale,
  );
}
