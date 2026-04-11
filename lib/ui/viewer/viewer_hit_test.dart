import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/models/annotation.dart';
import '../../data/models/point.dart';

/// Distance from [p] to annotation geometry in **source** space (for hit / erase).
double annotationHitDistance(HexaPoint p, Annotation a) {
  if (a.points.isEmpty) return double.infinity;
  switch (a.type) {
    case AnnotationType.draw:
      var d = double.infinity;
      for (var i = 1; i < a.points.length; i++) {
        d = min(d, _distPointToSegment(p, a.points[i - 1], a.points[i]));
      }
      return d;
    case AnnotationType.text:
      final anchor = a.points.first;
      final base = (p.x - anchor.x).abs() + (p.y - anchor.y).abs();
      final textRect = _labelRectForText(a);
      final textRectDistance = _distPointToRect(p, textRect);
      return min(base, textRectDistance);
    case AnnotationType.arrow:
    case AnnotationType.arrowOneWay:
    case AnnotationType.twoPointer:
      if (a.points.length < 2) return double.infinity;
      final lineDist = _distPointToSegment(p, a.points.first, a.points.last);
      if (a.type == AnnotationType.twoPointer &&
          a.measurement != null &&
          a.measurement!.trim().isNotEmpty) {
        final labelRect = _labelRectForMeasurement(a);
        final labelDist = _distPointToRect(p, labelRect);
        return min(lineDist, labelDist);
      }
      return lineDist;
    case AnnotationType.singlePointer:
      return _dist(p, a.points.first);
    case AnnotationType.square:
    case AnnotationType.rectangle:
      if (a.points.length < 2) return double.infinity;
      final r = Rect.fromPoints(
        Offset(a.points.first.x, a.points.first.y),
        Offset(a.points.last.x, a.points.last.y),
      );
      return _distPointToRect(p, r);
    case AnnotationType.circle:
      if (a.points.length < 2) return double.infinity;
      final radius = _dist(
        a.points.first,
        a.points.last,
      );
      final c = a.points.first;
      return (_dist(p, c) - radius).abs();
  }
}

/// Label-only hit test in source coordinates (for move-label tool).
double annotationLabelHitDistance(
  HexaPoint p,
  Annotation a, {
  Size? sourceSize,
}) {
  if (a.points.isEmpty) return double.infinity;
  if (a.type == AnnotationType.text) {
    return _distPointToRect(
      p,
      _labelRectForText(a, sourceSize: sourceSize).inflate(34),
    );
  }
  if (a.measurement != null && a.measurement!.trim().isNotEmpty) {
    return _distPointToRect(
      p,
      _labelRectForMeasurement(a, sourceSize: sourceSize).inflate(34),
    );
  }
  return double.infinity;
}

Rect _labelRectForText(Annotation a, {Size? sourceSize}) {
  final anchor = a.points.first;
  final text = (a.text ?? '').trim();
  final charCount = text.isEmpty ? 1 : text.runes.length.clamp(1, 42);
  final fontSize = (a.labelFontSize ?? (10.0 + (a.strokeWidth * 0.9))).clamp(
    8.0,
    120.0,
  );
  final textWidth = (fontSize * 0.58 * charCount).clamp(28.0, 520.0);
  final textHeight = (fontSize * 1.22).clamp(14.0, 128.0);
  const gap = 10.0;
  var left = anchor.x - textWidth - gap;
  var top = anchor.y - textHeight - gap;
  final bounds = _sourceBounds(sourceSize);
  if (bounds != null) {
    left = _clampLabelX(left, textWidth.toDouble(), bounds);
    top = _clampLabelY(top, textHeight.toDouble(), bounds);
    if (top >= anchor.y - 2) {
      top = _clampLabelY(anchor.y + gap, textHeight.toDouble(), bounds);
    }
  }
  return Rect.fromLTWH(
    left + a.labelOffsetX,
    top + a.labelOffsetY,
    textWidth.toDouble(),
    textHeight.toDouble(),
  );
}

Rect _labelRectForMeasurement(Annotation a, {Size? sourceSize}) {
  final text = (a.measurement ?? '').trim();
  final chars = text.runes.length.clamp(1, 40);
  final fontSize = (a.labelFontSize ?? (10.0 + (a.strokeWidth * 1.1))).clamp(
    8.0,
    120.0,
  );
  final w = (fontSize * 0.56 * chars).clamp(28.0, 520.0);
  final h = (fontSize * 1.22).clamp(14.0, 120.0);
  const gap = 10.0;
  late double left;
  late double top;

  switch (a.type) {
    case AnnotationType.circle:
      if (a.points.length >= 2) {
        final c = a.points.first;
        final r = _dist(a.points[1], c);
        left = c.x - (w / 2);
        top = c.y - r - gap - h;
        final bounds = _sourceBounds(sourceSize);
        if (bounds != null && top < _labelEdgePad) {
          top = c.y + r + gap;
        }
        break;
      }
      left = a.points.first.x - (w / 2);
      top = a.points.first.y - h - gap;
      final bounds = _sourceBounds(sourceSize);
      if (bounds != null && top < _labelEdgePad) {
        top = a.points.first.y + gap;
      }
      break;
    case AnnotationType.rectangle:
    case AnnotationType.square:
      if (a.points.length >= 2) {
        final leftX = min(a.points.first.x, a.points.last.x);
        final rightX = max(a.points.first.x, a.points.last.x);
        final topY = min(a.points.first.y, a.points.last.y);
        final bottomY = max(a.points.first.y, a.points.last.y);
        left = ((leftX + rightX) / 2) - (w / 2);
        top = topY - gap - h;
        final bounds = _sourceBounds(sourceSize);
        if (bounds != null && top < _labelEdgePad) {
          top = bottomY + gap;
        }
        break;
      }
      left = a.points.first.x - (w / 2);
      top = a.points.first.y - h - gap;
      final bounds = _sourceBounds(sourceSize);
      if (bounds != null && top < _labelEdgePad) {
        top = a.points.first.y + gap;
      }
      break;
    case AnnotationType.twoPointer:
    case AnnotationType.arrow:
    case AnnotationType.arrowOneWay:
      if (a.points.length >= 2) {
        final p0 = a.points.first;
        final p1 = a.points.last;
        final mid = HexaPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2);
        final dx = p1.x - p0.x;
        final dy = p1.y - p0.y;
        final len = sqrt(dx * dx + dy * dy);
        if (len < 1e-6) {
          left = mid.x - (w / 2);
          top = mid.y - h - gap;
          break;
        }
        final nx = -dy / len;
        final ny = dx / len;
        final dist = gap + h * 0.35 + 10.0;
        left = mid.x + nx * dist - (w / 2);
        top = mid.y + ny * dist - (h / 2);
        break;
      }
      left = a.points.first.x - (w / 2);
      top = a.points.first.y - h - gap;
      break;
    case AnnotationType.singlePointer:
      left = a.points.first.x - (w / 2);
      top = a.points.first.y - h - gap;
      break;
    case AnnotationType.draw:
      var minX = a.points.first.x;
      var maxX = a.points.first.x;
      var minY = a.points.first.y;
      var maxY = a.points.first.y;
      for (final p in a.points) {
        minX = min(minX, p.x);
        maxX = max(maxX, p.x);
        minY = min(minY, p.y);
        maxY = max(maxY, p.y);
      }
      left = ((minX + maxX) / 2) - (w / 2);
      top = minY - h - gap;
      final bounds = _sourceBounds(sourceSize);
      if (bounds != null && top < _labelEdgePad) {
        top = maxY + gap;
      }
      break;
    case AnnotationType.text:
      left = a.points.first.x - (w / 2);
      top = a.points.first.y - h - gap;
      break;
  }

  final bounds = _sourceBounds(sourceSize);
  if (bounds != null) {
    left = _clampLabelX(left, w.toDouble(), bounds);
    top = _clampLabelY(top, h.toDouble(), bounds);
    final shiftedLeft =
        _clampLabelX(left + a.labelOffsetX, w.toDouble(), bounds);
    final shiftedTop = _clampLabelY(top + a.labelOffsetY, h.toDouble(), bounds);
    return Rect.fromLTWH(shiftedLeft, shiftedTop, w.toDouble(), h.toDouble());
  }

  return Rect.fromLTWH(
      left + a.labelOffsetX, top + a.labelOffsetY, w.toDouble(), h.toDouble());
}

const double _labelEdgePad = 8.0;

Rect? _sourceBounds(Size? sourceSize) {
  if (sourceSize == null) return null;
  if (sourceSize.width <= 0 || sourceSize.height <= 0) return null;
  return Rect.fromLTWH(0, 0, sourceSize.width, sourceSize.height);
}

double _clampLabelX(double left, double width, Rect bounds) {
  final maxLeft = max(_labelEdgePad, bounds.width - width - _labelEdgePad);
  return left.clamp(_labelEdgePad, maxLeft).toDouble();
}

double _clampLabelY(double top, double height, Rect bounds) {
  final maxTop = max(_labelEdgePad, bounds.height - height - _labelEdgePad);
  return top.clamp(_labelEdgePad, maxTop).toDouble();
}

double _dist(HexaPoint a, HexaPoint b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return sqrt(dx * dx + dy * dy);
}

double _distPointToSegment(HexaPoint p, HexaPoint a, HexaPoint b) {
  final l2 = _dist(a, b);
  if (l2 < 1e-6) return _dist(p, a);
  var t = ((p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)) / (l2 * l2);
  t = t.clamp(0.0, 1.0);
  final proj = HexaPoint(
    x: a.x + t * (b.x - a.x),
    y: a.y + t * (b.y - a.y),
  );
  return _dist(p, proj);
}

double _distPointToRect(HexaPoint p, Rect r) {
  final cx = p.x.clamp(r.left, r.right);
  final cy = p.y.clamp(r.top, r.bottom);
  final dx = p.x - cx;
  final dy = p.y - cy;
  return sqrt(dx * dx + dy * dy);
}

/// Nearest annotation within [maxDist] source pixels, or null.
Annotation? pickAnnotationAt(
  HexaPoint sourcePoint,
  List<Annotation> list, {
  double maxDist = 28,
}) {
  Annotation? best;
  var bestD = maxDist;
  for (final a in list.reversed) {
    final d = annotationHitDistance(sourcePoint, a);
    if (d < bestD) {
      bestD = d;
      best = a;
    }
  }
  return best;
}
