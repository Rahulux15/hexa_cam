import 'package:demo_app/utils/coordinate_transformer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const imageSize = Size(200, 100);
  const epsilon = 0.001;

  void expectRoundTrip({
    required Offset point,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
  }) {
    final imagePoint = CoordinateTransformer.screenToImage(
      point,
      imageSize: imageSize,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
    );
    final screenPoint = CoordinateTransformer.imageToScreen(
      imagePoint,
      imageSize: imageSize,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
    );

    expect(screenPoint.dx, closeTo(point.dx, epsilon));
    expect(screenPoint.dy, closeTo(point.dy, epsilon));
  }

  test('roundtrips rotation and flip combinations', () {
    final cases = [
      (mirrorX: false, mirrorY: false, rotation: 0),
      (mirrorX: true, mirrorY: false, rotation: 0),
      (mirrorX: false, mirrorY: true, rotation: 0),
      (mirrorX: false, mirrorY: false, rotation: 90),
      (mirrorX: false, mirrorY: false, rotation: 180),
      (mirrorX: false, mirrorY: false, rotation: 270),
      (mirrorX: true, mirrorY: false, rotation: 90),
      (mirrorX: false, mirrorY: true, rotation: 270),
    ];

    for (final c in cases) {
      expectRoundTrip(
        point: const Offset(40, 20),
        mirrorX: c.mirrorX,
        mirrorY: c.mirrorY,
        rotation: c.rotation,
      );
    }
  });
}
