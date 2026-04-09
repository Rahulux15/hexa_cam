/// Sanity checks before persisting a [StoredCalibration]-like payload.
/// Returns a user-visible error string, or `null` when acceptable.
class CalibrationGuard {
  CalibrationGuard._();

  static const double _minUnitPerPixel = 1e-18;
  static const double _maxUnitPerPixel = 1e12;

  /// Hard block: unrealistic or non-finite scale factors.
  static String? validateScale({
    required double unitPerPixel,
    required double pixelsPerUnit,
    required double measuredPixelDistance,
    required double referenceLength,
  }) {
    if (!unitPerPixel.isFinite ||
        !pixelsPerUnit.isFinite ||
        !measuredPixelDistance.isFinite ||
        !referenceLength.isFinite) {
      return 'Calibration values are not valid numbers. Please re-measure.';
    }
    if (measuredPixelDistance <= 0 || referenceLength <= 0) {
      return 'Reference length and measured pixels must be positive.';
    }
    if (unitPerPixel <= 0 || pixelsPerUnit <= 0) {
      return 'Calibration scale must be positive.';
    }
    if (unitPerPixel < _minUnitPerPixel || unitPerPixel > _maxUnitPerPixel) {
      return 'This calibration looks unrealistic. Check units and re-measure.';
    }
    return null;
  }

  /// Soft warning: measured line very short compared to image — may be noisy.
  static bool shouldWarnShortLine({
    required double measuredPixelDistance,
    required double imageWidth,
    required double imageHeight,
  }) {
    final maxDim = imageWidth > 0 && imageHeight > 0
        ? (imageWidth > imageHeight ? imageWidth : imageHeight)
        : 0.0;
    if (maxDim <= 0) return false;
    return measuredPixelDistance < maxDim * 0.02;
  }
}
