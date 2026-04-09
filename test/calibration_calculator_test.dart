import 'package:demo_app/utils/calibration_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalibrationCalculator', () {
    test('computeFactor rejects non-positive inputs', () {
      expect(
        () => CalibrationCalculator.computeFactor(0, 10),
        throwsArgumentError,
      );
      expect(
        () => CalibrationCalculator.computeFactor(10, 0),
        throwsArgumentError,
      );
      expect(
        () => CalibrationCalculator.computeFactor(-1, 10),
        throwsArgumentError,
      );
    });

    test('μm ↔ nm scaling (positive)', () {
      expect(
        CalibrationCalculator.convertUnit(1.0, 'μm', 'nm'),
        closeTo(1000.0, 1e-9),
      );
      expect(
        CalibrationCalculator.convertUnit(1000.0, 'nm', 'μm'),
        closeTo(1.0, 1e-9),
      );
    });

    test('μm ↔ nm preserves sign (negative offset style values)', () {
      expect(
        CalibrationCalculator.convertUnit(-2.5, 'μm', 'nm'),
        closeTo(-2500.0, 1e-9),
      );
    });

    test('zero passes through convertUnit between same units', () {
      expect(CalibrationCalculator.convertUnit(0, 'μm', 'μm'), 0.0);
    });

    test('measurePixels length with matching units', () {
      final v = CalibrationCalculator.measurePixels(
        unitPerPixel: 0.5,
        pixels: 10,
        unit: 'μm',
      );
      expect(v, 5.0);
    });
  });
}
