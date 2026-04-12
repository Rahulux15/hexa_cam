import 'dart:ui';
import 'point.dart';

enum AnnotationType {
  draw,
  text,
  arrow,
  arrowOneWay,
  circle,
  rectangle,
  square,
  twoPointer,
  singlePointer
}

class Annotation {
  final String id;
  final AnnotationType type;
  final List<HexaPoint> points;
  final String? text;
  final Color color;
  final double strokeWidth;
  final String timestamp;
  final String? measurement;
  final String coordinateSpace;
  final double? labelFontSize;
  final double labelOffsetX;
  final double labelOffsetY;

  /// When true, [strokeWidth] / [labelFontSize] are in **full-image source
  /// pixels**; [AnnotationPainter] multiplies by the layout scale to canvas px.
  /// When false (legacy), values are treated as canvas pixels (preview/export mismatch).
  final bool strokeInSourcePixels;

  Annotation({
    required this.id,
    required this.type,
    required this.points,
    this.text,
    required this.color,
    this.strokeWidth = 2.0,
    required this.timestamp,
    this.measurement,
    this.coordinateSpace = 'source',
    this.labelFontSize,
    this.labelOffsetX = 0,
    this.labelOffsetY = 0,
    this.strokeInSourcePixels = false,
  });

  Annotation copyWith({
    List<HexaPoint>? points,
    String? coordinateSpace,
    String? measurement,
    double? strokeWidth,
    double? labelFontSize,
    double? labelOffsetX,
    double? labelOffsetY,
    bool? strokeInSourcePixels,
  }) =>
      Annotation(
        id: id,
        type: type,
        points: points ?? this.points,
        text: text,
        color: color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        timestamp: timestamp,
        measurement: measurement ?? this.measurement,
        coordinateSpace: coordinateSpace ?? this.coordinateSpace,
        labelFontSize: labelFontSize ?? this.labelFontSize,
        labelOffsetX: labelOffsetX ?? this.labelOffsetX,
        labelOffsetY: labelOffsetY ?? this.labelOffsetY,
        strokeInSourcePixels: strokeInSourcePixels ?? this.strokeInSourcePixels,
      );

  factory Annotation.fromJson(Map<String, dynamic> json) => Annotation(
        id: json['id'],
        type: AnnotationType.values.byName(json['type'] ?? 'draw'),
        points:
            (json['points'] as List).map((p) => HexaPoint.fromJson(p)).toList(),
        text: json['text'],
        color: _parseColor(json['color']),
        strokeWidth: (json['strokeWidth'] ?? 2.0).toDouble(),
        timestamp: json['timestamp'],
        measurement: json['measurement'],
        coordinateSpace: json['coordinateSpace'] ?? 'source',
        labelFontSize: (json['labelFontSize'] as num?)?.toDouble(),
        labelOffsetX: (json['labelOffsetX'] as num?)?.toDouble() ?? 0,
        labelOffsetY: (json['labelOffsetY'] as num?)?.toDouble() ?? 0,
        strokeInSourcePixels: json['strokeInSourcePixels'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'points': points.map((p) => p.toJson()).toList(),
        if (text != null) 'text': text,
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
        'timestamp': timestamp,
        if (measurement != null) 'measurement': measurement,
        'coordinateSpace': coordinateSpace,
        if (labelFontSize != null) 'labelFontSize': labelFontSize,
        if (labelOffsetX != 0) 'labelOffsetX': labelOffsetX,
        if (labelOffsetY != 0) 'labelOffsetY': labelOffsetY,
        if (strokeInSourcePixels) 'strokeInSourcePixels': true,
      };

  static Color _parseColor(dynamic raw) {
    if (raw is int) return Color(raw);
    if (raw is double) {
      // Legacy/corrupt payloads may store non-int numbers; fall back safely.
      return raw.isFinite ? Color(raw.round()) : const Color(0xFFFF00FF);
    }
    if (raw is String) {
      final value = int.tryParse(raw);
      if (value != null) return Color(value);
    }
    return const Color(0xFFFF00FF);
  }
}
