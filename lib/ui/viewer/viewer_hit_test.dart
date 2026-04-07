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
      return (p.x - a.points.first.x).abs() + (p.y - a.points.first.y).abs();
    case AnnotationType.arrow:
    case AnnotationType.arrowOneWay:
    case AnnotationType.twoPointer:
      if (a.points.length < 2) return double.infinity;
      return _distPointToSegment(p, a.points.first, a.points.last);
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
  for (final a in list) {
    final d = annotationHitDistance(sourcePoint, a);
    if (d < bestD) {
      bestD = d;
      best = a;
    }
  }
  return best;
}
