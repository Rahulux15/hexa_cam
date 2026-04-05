import 'dart:math';
import '../data/models/annotation.dart';

class MeasurementCalculator {
  static String getMeasurementText(Annotation ann, {double? pixelsPerUnit, String? unit}) {
    if (ann.points.length < 2) return '';
    final start = ann.points.first; final end = ann.points.last;
    final dx = end.x - start.x; final dy = end.y - start.y;
    final distance = sqrt(dx * dx + dy * dy);
    final hasCal = pixelsPerUnit != null && pixelsPerUnit > 0 && unit != null;

    switch (ann.type) {
      case AnnotationType.square: case AnnotationType.rectangle:
        final w = dx.abs(); final h = dy.abs(); final area = w * h;
        if (hasCal) return 'W: ${(w / pixelsPerUnit).toStringAsFixed(2)} $unit\nH: ${(h / pixelsPerUnit).toStringAsFixed(2)} $unit\nA: ${(area / (pixelsPerUnit * pixelsPerUnit)).toStringAsFixed(2)} $unit²';
        return 'W: ${w.toStringAsFixed(1)} px\nH: ${h.toStringAsFixed(1)} px\nA: ${area.toStringAsFixed(1)} px²';
      case AnnotationType.circle:
        final radius = distance; final diameter = radius * 2; final area = pi * radius * radius;
        if (hasCal) return 'Ø ${(diameter / pixelsPerUnit).toStringAsFixed(2)} $unit\nA: ${(area / (pixelsPerUnit * pixelsPerUnit)).toStringAsFixed(2)} $unit²';
        return 'Ø ${diameter.toStringAsFixed(1)} px\nA: ${area.toStringAsFixed(1)} px²';
      case AnnotationType.draw:
        double total = 0;
        for (int i = 1; i < ann.points.length; i++) {
          final sdx = ann.points[i].x - ann.points[i-1].x; final sdy = ann.points[i].y - ann.points[i-1].y;
          total += sqrt(sdx * sdx + sdy * sdy);
        }
        if (hasCal) return '${(total / pixelsPerUnit).toStringAsFixed(2)} $unit';
        return '${total.toStringAsFixed(1)} px';
      case AnnotationType.twoPointer: case AnnotationType.arrow: case AnnotationType.arrowOneWay:
        if (hasCal) return '${(distance / pixelsPerUnit).toStringAsFixed(2)} $unit';
        return '${distance.toStringAsFixed(1)} px';
      default: return '';
    }
  }
}
