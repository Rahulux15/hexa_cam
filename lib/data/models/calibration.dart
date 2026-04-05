class Calibration {
  final double pixelsPerUnit;
  final String unit;
  final double referenceLength;

  const Calibration({required this.pixelsPerUnit, required this.unit, required this.referenceLength});

  factory Calibration.fromJson(Map<String, dynamic> json) => Calibration(
    pixelsPerUnit: (json['pixelsPerUnit'] ?? 0).toDouble(), unit: json['unit'] ?? 'μm',
    referenceLength: (json['referenceLength'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toJson() => {'pixelsPerUnit': pixelsPerUnit, 'unit': unit, 'referenceLength': referenceLength};
}
