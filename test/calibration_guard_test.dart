import 'package:flutter_test/flutter_test.dart';

import 'package:demo_app/utils/calibration_guard.dart';

void main() {
  test('CalibrationGuard rejects absurd scale', () {
    expect(
      CalibrationGuard.validateScale(
        unitPerPixel: 1e20,
        pixelsPerUnit: 1e-20,
        measuredPixelDistance: 100,
        referenceLength: 10,
      ),
      isNotNull,
    );
  });

  test('CalibrationGuard accepts reasonable scale', () {
    expect(
      CalibrationGuard.validateScale(
        unitPerPixel: 0.01,
        pixelsPerUnit: 100,
        measuredPixelDistance: 500,
        referenceLength: 100,
      ),
      isNull,
    );
  });
}
