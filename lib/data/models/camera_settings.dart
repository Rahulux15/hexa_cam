class CameraSettings {
  final double exposure;
  final double iso;
  final double temperature;
  final double tint;
  final double zoom;

  const CameraSettings({this.exposure = 100, this.iso = 400, this.temperature = 6500, this.tint = 0, this.zoom = 1});

  factory CameraSettings.fromJson(Map<String, dynamic> json) => CameraSettings(
    exposure: (json['exposure'] ?? 100).toDouble(), iso: (json['iso'] ?? 400).toDouble(),
    temperature: (json['temperature'] ?? 6500).toDouble(), tint: (json['tint'] ?? 0).toDouble(),
    zoom: (json['zoom'] ?? 1).toDouble(),
  );

  Map<String, dynamic> toJson() => {'exposure': exposure, 'iso': iso, 'temperature': temperature, 'tint': tint, 'zoom': zoom};

  CameraSettings copyWith({double? exposure, double? iso, double? temperature, double? tint, double? zoom}) =>
    CameraSettings(exposure: exposure ?? this.exposure, iso: iso ?? this.iso,
      temperature: temperature ?? this.temperature, tint: tint ?? this.tint, zoom: zoom ?? this.zoom);
}
