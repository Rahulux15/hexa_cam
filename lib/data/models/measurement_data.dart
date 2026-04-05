class MeasurementData {
  final String annotationId;
  final double value;
  final String unit;
  final String formatted;

  const MeasurementData({required this.annotationId, required this.value, required this.unit, required this.formatted});

  factory MeasurementData.fromJson(Map<String, dynamic> json) => MeasurementData(
    annotationId: json['annotationId'], value: (json['value'] ?? 0).toDouble(),
    unit: json['unit'] ?? 'px', formatted: json['formatted'] ?? '',
  );

  Map<String, dynamic> toJson() => {'annotationId': annotationId, 'value': value, 'unit': unit, 'formatted': formatted};
}
