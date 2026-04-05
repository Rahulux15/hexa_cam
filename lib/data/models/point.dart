import 'dart:math';

class HexaPoint {
  final double x;
  final double y;
  const HexaPoint({required this.x, required this.y});
  HexaPoint operator +(HexaPoint other) => HexaPoint(x: x + other.x, y: y + other.y);
  HexaPoint operator -(HexaPoint other) => HexaPoint(x: x - other.x, y: y - other.y);
  double distanceTo(HexaPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }
  factory HexaPoint.fromJson(Map<String, dynamic> json) => HexaPoint(x: (json['x'] as num).toDouble(), y: (json['y'] as num).toDouble());
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}
