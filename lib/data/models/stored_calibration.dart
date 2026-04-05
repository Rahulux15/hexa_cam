class StoredCalibration {
  final String lens;
  final String unit;
  final double unitPerPixel;
  final double pixelsPerUnit;
  final double referenceLength;
  final double measuredPixelDistance;
  final double? unitPerDivision;
  final double? measuredDivisions;
  final String createdAt;

  const StoredCalibration({
    required this.lens, required this.unit, required this.unitPerPixel,
    required this.pixelsPerUnit, required this.referenceLength,
    required this.measuredPixelDistance, this.unitPerDivision,
    this.measuredDivisions, required this.createdAt,
  });

  factory StoredCalibration.fromJson(Map<String, dynamic> json) => StoredCalibration(
    lens: json['lens'], unit: json['unit'] ?? 'μm',
    unitPerPixel: (json['unitPerPixel'] ?? 0).toDouble(),
    pixelsPerUnit: (json['pixelsPerUnit'] ?? 0).toDouble(),
    referenceLength: (json['referenceLength'] ?? 0).toDouble(),
    measuredPixelDistance: (json['measuredPixelDistance'] ?? 0).toDouble(),
    unitPerDivision: json['unitPerDivision']?.toDouble(),
    measuredDivisions: json['measuredDivisions']?.toDouble(),
    createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
  );

  Map<String, dynamic> toJson() => {
    'lens': lens, 'unit': unit, 'unitPerPixel': unitPerPixel, 'pixelsPerUnit': pixelsPerUnit,
    'referenceLength': referenceLength, 'measuredPixelDistance': measuredPixelDistance,
    if (unitPerDivision != null) 'unitPerDivision': unitPerDivision,
    if (measuredDivisions != null) 'measuredDivisions': measuredDivisions, 'createdAt': createdAt,
  };
}
