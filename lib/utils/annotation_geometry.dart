import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../data/models/point.dart';
import 'coordinate_transformer.dart';

/// Maps a point from annotation [source] space to preview [display] pixels.
/// Matches [AnnotationPainter] / camera preview layout (FittedBox + rotation).
Offset mapSourcePointToPreviewDisplay(
  HexaPoint point, {
  required Size sourceSize,
  required Size displaySize,
  BoxFit fit = BoxFit.contain,
  bool mirrorX = false,
  bool mirrorY = false,
  int rotation = 0,
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
    HexaPoint(x: 0, y: 0),
    HexaPoint(x: sourceW, y: 0),
    HexaPoint(x: 0, y: sourceH),
    HexaPoint(x: sourceW, y: sourceH),
  ].map((pt) {
    final v = transformed.transform3(Vector3(pt.x, pt.y, 1));
    return Offset(v.x, v.y);
  }).toList();

  final minX = corners.map((p) => p.dx).reduce(min);
  final maxX = corners.map((p) => p.dx).reduce(max);
  final minY = corners.map((p) => p.dy).reduce(min);
  final maxY = corners.map((p) => p.dy).reduce(max);
  final transformedW = (maxX - minX).clamp(1.0, double.infinity);
  final transformedH = (maxY - minY).clamp(1.0, double.infinity);
  final baseScale = fit == BoxFit.cover
      ? max(displayW / transformedW, displayH / transformedH)
      : min(displayW / transformedW, displayH / transformedH);
  final scale = baseScale * zoom;
  final offsetX = (displayW - transformedW * scale) / 2;
  final offsetY = (displayH - transformedH * scale) / 2;

  final v = transformed.transform3(Vector3(point.x, point.y, 1));
  return Offset(
    offsetX + ((v.x - minX) * scale),
    offsetY + ((v.y - minY) * scale),
  );
}

/// Label offset delta from source space to display pixel delta (same as painter).
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
    HexaPoint(x: 0, y: 0),
    HexaPoint(x: sourceW, y: 0),
    HexaPoint(x: 0, y: sourceH),
    HexaPoint(x: sourceW, y: sourceH),
  ].map((pt) {
    final v = transformed.transform3(Vector3(pt.x, pt.y, 1));
    return Offset(v.x, v.y);
  }).toList();

  final minX = corners.map((p) => p.dx).reduce(min);
  final maxX = corners.map((p) => p.dx).reduce(max);
  final minY = corners.map((p) => p.dy).reduce(min);
  final maxY = corners.map((p) => p.dy).reduce(max);
  final transformedW = (maxX - minX).clamp(1.0, double.infinity);
  final transformedH = (maxY - minY).clamp(1.0, double.infinity);
  final baseScale = fit == BoxFit.cover
      ? max(displayW / transformedW, displayH / transformedH)
      : min(displayW / transformedW, displayH / transformedH);
  final scale = baseScale * zoom;

  final origin = transformed.transform3(Vector3(0, 0, 1));
  final shifted =
      transformed.transform3(Vector3(delta.x, delta.y, 1));
  return Offset(
    (shifted.x - origin.x) * scale,
    (shifted.y - origin.y) * scale,
  );
}
