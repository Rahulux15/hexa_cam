class CalibrationCalculator {
  static double computeFactor(double pixelDistance, double knownDistance) {
    if (pixelDistance <= 0 || knownDistance <= 0) throw ArgumentError('Both distances must be positive');
    return knownDistance / pixelDistance;
  }

  static double measurePixels({required double unitPerPixel, required double pixels, required String unit, String? outputUnit, String dimension = 'length'}) {
    double rawValue = dimension == 'area' ? pixels * unitPerPixel * unitPerPixel : pixels * unitPerPixel;
    if (outputUnit == null || outputUnit == unit) return rawValue;
    return convertUnit(rawValue, unit, outputUnit, dimension);
  }

  static double convertUnit(double value, String from, String to, [String dim = 'length']) {
    const toMicrometers = {'μm': 1.0, 'nm': 0.001};
    if (from == to) return value;
    final inMicrometers = value * (toMicrometers[from] ?? 1);
    return inMicrometers / (toMicrometers[to] ?? 1);
  }

  static String formatMeasurement(double value, String unit, [String dimension = 'length']) {
    return dimension == 'area' ? '${value.toStringAsFixed(2)} $unit²' : '${value.toStringAsFixed(2)} $unit';
  }
}
