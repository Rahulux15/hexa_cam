import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

class CoordinateTransformer {
  static Matrix4 buildImageTransform({
    required Size imageSize,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
  }) {
    final centerX = imageSize.width / 2;
    final centerY = imageSize.height / 2;
    final matrix = Matrix4.identity();
    matrix.translateByDouble(centerX, centerY, 0.0, 1.0);
    matrix.rotateZ(rotation * math.pi / 180);
    matrix.scaleByDouble(
      mirrorX ? -1.0 : 1.0,
      mirrorY ? -1.0 : 1.0,
      1.0,
      1.0,
    );
    matrix.translateByDouble(-centerX, -centerY, 0.0, 1.0);
    return matrix;
  }

  static Offset imageToScreen(
    Offset point, {
    required Size imageSize,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
  }) {
    final matrix = buildImageTransform(
      imageSize: imageSize,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
    );
    final v = matrix.transform3(Vector3(point.dx, point.dy, 1));
    return Offset(v.x, v.y);
  }

  /// Maps a point from **layout** space (same box as the image, origin
  /// top-left) into source image coordinates when the preview is **not**
  /// wrapped in a [Transform] that already applies [rotation] / mirrors.
  /// Camera preview gestures sit inside such a [Transform] and must **not**
  /// use this — use local positions as source coords instead.
  static Offset screenToImage(
    Offset point, {
    required Size imageSize,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
  }) {
    final matrix = buildImageTransform(
      imageSize: imageSize,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
    );
    final inverse = Matrix4.inverted(matrix);
    final v = inverse.transform3(Vector3(point.dx, point.dy, 1));
    return Offset(v.x, v.y);
  }
}
