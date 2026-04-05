import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models/annotation.dart';
import '../data/models/point.dart';

class AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final Annotation? currentDrawing;
  final Size displaySize;
  final Size sourceSize;
  final BoxFit fit;
  final bool mirrorX;
  final bool mirrorY;
  final double zoom;
  final int rotation;

  AnnotationPainter({
    required this.annotations,
    this.currentDrawing,
    required this.displaySize,
    required this.sourceSize,
    this.fit = BoxFit.contain,
    this.mirrorX = false,
    this.mirrorY = false,
    this.zoom = 1,
    this.rotation = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ann in annotations) {
      _drawAnnotation(canvas, ann);
    }
    if (currentDrawing != null) {
      _drawAnnotation(canvas, currentDrawing!);
    }
  }

  void _drawAnnotation(Canvas canvas, Annotation ann) {
    final paint = Paint()
      ..color = ann.color
      ..strokeWidth = ann.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final points = _toDisplayPoints(ann.points);
    if (points.isEmpty) return;

    switch (ann.type) {
      case AnnotationType.draw:
        final path = Path();
        path.moveTo(points[0].dx, points[0].dy);
        for (final p in points) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
        break;
      case AnnotationType.text:
        if (ann.text != null) {
          final tp = TextPainter(
              text: TextSpan(
                  text: ann.text,
                  style: TextStyle(
                      color: ann.color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              textDirection: TextDirection.ltr);
          tp.layout();
          tp.paint(canvas, Offset(points[0].dx, points[0].dy));
        }
        break;
      case AnnotationType.arrow:
      case AnnotationType.arrowOneWay:
        if (points.length >= 2) {
          final start = points[0];
          final end = points[points.length - 1];
          final angle = atan2(end.dy - start.dy, end.dx - start.dx);
          canvas.drawLine(start, end, paint);
          final path = Path();
          path.moveTo(end.dx, end.dy);
          path.lineTo(end.dx - 20 * cos(angle - pi / 6),
              end.dy - 20 * sin(angle - pi / 6));
          path.moveTo(end.dx, end.dy);
          path.lineTo(end.dx - 20 * cos(angle + pi / 6),
              end.dy - 20 * sin(angle + pi / 6));
          canvas.drawPath(path, paint);
        }
        break;
      case AnnotationType.twoPointer:
        if (points.length >= 2) {
          final fill = Paint()
            ..color = ann.color
            ..style = PaintingStyle.fill;
          canvas.drawLine(points[0], points[1], paint);
          canvas.drawCircle(points[0], 5, fill);
          canvas.drawCircle(points[1], 5, fill);
        }
        break;
      case AnnotationType.singlePointer:
        final fill = Paint()
          ..color = ann.color
          ..style = PaintingStyle.fill;
        final p = points[0];
        canvas.drawCircle(Offset(p.dx, p.dy), 6, fill);
        canvas.drawLine(
            Offset(p.dx - 12, p.dy), Offset(p.dx + 12, p.dy), paint);
        canvas.drawLine(
            Offset(p.dx, p.dy - 12), Offset(p.dx, p.dy + 12), paint);
        break;
      case AnnotationType.rectangle:
      case AnnotationType.square:
        if (points.length >= 2) {
          canvas.drawRect(
              Rect.fromPoints(points[0], points[points.length - 1]), paint);
        }
        break;
      case AnnotationType.circle:
        if (points.length >= 2) {
          final radius = (points[points.length - 1] - points[0]).distance;
          canvas.drawCircle(points[0], radius, paint);
        }
        break;
    }

    if (ann.measurement != null && ann.measurement!.trim().isNotEmpty) {
      _drawMeasurementLabel(canvas, ann.measurement!, points);
    }
  }

  List<Offset> _toDisplayPoints(List<HexaPoint> sourcePoints) {
    final sourceW = sourceSize.width <= 0 ? 1.0 : sourceSize.width;
    final sourceH = sourceSize.height <= 0 ? 1.0 : sourceSize.height;
    final displayW = displaySize.width <= 0 ? 1.0 : displaySize.width;
    final displayH = displaySize.height <= 0 ? 1.0 : displaySize.height;

    final transformedCorners = _transformedCorners(sourceW, sourceH);
    final minX = transformedCorners
        .map((p) => p.dx)
        .reduce((a, b) => a < b ? a : b);
    final maxX = transformedCorners
        .map((p) => p.dx)
        .reduce((a, b) => a > b ? a : b);
    final minY = transformedCorners
        .map((p) => p.dy)
        .reduce((a, b) => a < b ? a : b);
    final maxY = transformedCorners
        .map((p) => p.dy)
        .reduce((a, b) => a > b ? a : b);

    final transformedW = (maxX - minX).clamp(1.0, double.infinity);
    final transformedH = (maxY - minY).clamp(1.0, double.infinity);

    final scale = fit == BoxFit.cover
        ? max(displayW / transformedW, displayH / transformedH)
        : min(displayW / transformedW, displayH / transformedH);
    final zoomedScale = scale * zoom;
    final renderedW = transformedW * zoomedScale;
    final renderedH = transformedH * zoomedScale;
    final offsetX = (displayW - renderedW) / 2;
    final offsetY = (displayH - renderedH) / 2;

    return sourcePoints.map((point) {
      final transformed = _applyPreviewTransform(point, sourceW, sourceH);
      final x = transformed.x - minX;
      final y = transformed.y - minY;
      return Offset(
        offsetX + (x * zoomedScale),
        offsetY + (y * zoomedScale),
      );
    }).toList();
  }

  List<Offset> _transformedCorners(double sourceW, double sourceH) {
    return [
      _applyPreviewTransform(const HexaPoint(x: 0, y: 0), sourceW, sourceH),
      _applyPreviewTransform(HexaPoint(x: sourceW, y: 0), sourceW, sourceH),
      _applyPreviewTransform(HexaPoint(x: 0, y: sourceH), sourceW, sourceH),
      _applyPreviewTransform(
          HexaPoint(x: sourceW, y: sourceH), sourceW, sourceH),
    ].map((p) => Offset(p.x, p.y)).toList();
  }

  HexaPoint _applyPreviewTransform(
      HexaPoint point, double sourceW, double sourceH) {
    final centerX = sourceW / 2;
    final centerY = sourceH / 2;
    final angle = rotation * pi / 180;

    double dx = point.x - centerX;
    double dy = point.y - centerY;

    if (rotation % 360 != 0) {
      final rotatedX = (dx * cos(angle)) - (dy * sin(angle));
      final rotatedY = (dx * sin(angle)) + (dy * cos(angle));
      dx = rotatedX;
      dy = rotatedY;
    }

    double x = dx + centerX;
    double y = dy + centerY;

    if (mirrorX) x = sourceW - x;
    if (mirrorY) y = sourceH - y;

    return HexaPoint(x: x, y: y);
  }

  void _drawMeasurementLabel(Canvas canvas, String text, List<Offset> points) {
    if (points.isEmpty) return;
    final anchor = points.length == 1
        ? points.first
        : Offset(
            (points.first.dx + points.last.dx) / 2,
            (points.first.dy + points.last.dy) / 2,
          );
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 160);

    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        anchor.dx - (textPainter.width / 2) - padding.horizontal / 2,
        anchor.dy - textPainter.height - 18,
        textPainter.width + padding.horizontal,
        textPainter.height + padding.vertical,
      ),
      const Radius.circular(12),
    );

    final labelPaint = Paint()..color = const Color(0xCC10162E);
    canvas.drawRRect(labelRect, labelPaint);
    textPainter.paint(
      canvas,
      Offset(
        labelRect.left + padding.left,
        labelRect.top + padding.top / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter old) => true;
}
