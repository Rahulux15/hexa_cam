import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models/annotation.dart';
import '../data/models/point.dart';
import 'coordinate_transformer.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

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
  /// Multiplier for stroke width (e.g. [MediaQuery.devicePixelRatio]) for crisper lines on screen.
  final double lineWidthScale;

  /// Accessibility / device text scaling for labels (pass [MediaQuery.textScalerOf] via `.scale(1.0)`).
  final double uiTextScale;

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
    this.lineWidthScale = 1.0,
    this.uiTextScale = 1.0,
  });

  Matrix4? _cachedTransform;
  double? _cachedMinX;
  double? _cachedMinY;
  double? _cachedScale;
  double? _cachedOffsetX;
  double? _cachedOffsetY;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final ann in annotations) {
      _drawAnnotation(canvas, ann, size);
    }
    if (currentDrawing != null) {
      _drawAnnotation(canvas, currentDrawing!, size);
    }
    canvas.restore();
  }

  void _drawAnnotation(Canvas canvas, Annotation ann, Size canvasSize) {
    final strokeWidth =
        (ann.strokeWidth * lineWidthScale).clamp(2.5, 28.0).toDouble();
    final paint = Paint()
      ..color = ann.color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
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
          final shortSide = sourceSize.shortestSide <= 0 ? 1.0 : sourceSize.shortestSide;
          final fontSize =
              (shortSide * 0.0175 * uiTextScale).clamp(16.0, 132.0).toDouble();
          final tp = TextPainter(
              text: TextSpan(
                  text: ann.text,
                  style: TextStyle(
                      color: ann.color,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold)),
              textDirection: TextDirection.ltr);
          tp.layout(minWidth: 0, maxWidth: shortSide * 0.55);
          final boxWidth = max(tp.width + 20, 96.0);
          final boxHeight = tp.height + 12;
          final anchor = points[0];
          final left = (anchor.dx - boxWidth).clamp(8.0, canvasSize.width - boxWidth - 8.0);
          final top = (anchor.dy - boxHeight).clamp(8.0, canvasSize.height - boxHeight - 8.0);
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, boxWidth, boxHeight),
            const Radius.circular(12),
          );
          canvas.drawRRect(rect, Paint()..color = const Color(0xCC10162E));
          tp.paint(canvas, Offset(rect.left + 10, rect.top + (rect.height - tp.height) / 2));
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
            ..style = PaintingStyle.fill
            ..isAntiAlias = true;
          canvas.drawLine(points[0], points[1], paint);
          canvas.drawCircle(points[0], 3.5, fill);
          canvas.drawCircle(points[1], 3.5, fill);
        }
        break;
      case AnnotationType.singlePointer:
        final fill = Paint()
          ..color = ann.color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        final p = points[0];
        canvas.drawCircle(Offset(p.dx, p.dy), 4, fill);
        canvas.drawLine(
            Offset(p.dx - 8, p.dy), Offset(p.dx + 8, p.dy), paint);
        canvas.drawLine(
            Offset(p.dx, p.dy - 8), Offset(p.dx, p.dy + 8), paint);
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
      _drawMeasurementLabel(canvas, ann.measurement!, points, canvasSize);
    }
  }

  List<Offset> _toDisplayPoints(List<HexaPoint> sourcePoints) {
    _ensureTransformCache();
    final transformed = _cachedTransform!;
    final minX = _cachedMinX!;
    final minY = _cachedMinY!;
    final zoomedScale = _cachedScale!;
    final offsetX = _cachedOffsetX!;
    final offsetY = _cachedOffsetY!;

    return sourcePoints.map((point) {
      final v = transformed.transform3(Vector3(point.x, point.y, 1));
      return Offset(
        offsetX + ((v.x - minX) * zoomedScale),
        offsetY + ((v.y - minY) * zoomedScale),
      );
    }).toList();
  }

  void _ensureTransformCache() {
    if (_cachedTransform != null) return;
    final sourceW = sourceSize.width <= 0 ? 1.0 : sourceSize.width;
    final sourceH = sourceSize.height <= 0 ? 1.0 : sourceSize.height;
    final displayW = displaySize.width <= 0 ? 1.0 : displaySize.width;
    final displayH = displaySize.height <= 0 ? 1.0 : displaySize.height;
    final transformed = CoordinateTransformer.buildImageTransform(
      imageSize: Size(sourceW, sourceH),
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
    );

    final corners = [
      const HexaPoint(x: 0, y: 0),
      HexaPoint(x: sourceW, y: 0),
      HexaPoint(x: 0, y: sourceH),
      HexaPoint(x: sourceW, y: sourceH),
    ].map((point) {
      final v = transformed.transform3(Vector3(point.x, point.y, 1));
      return Offset(v.x, v.y);
    }).toList();

    final minX = corners.map((p) => p.dx).reduce(min);
    final maxX = corners.map((p) => p.dx).reduce(max);
    final minY = corners.map((p) => p.dy).reduce(min);
    final maxY = corners.map((p) => p.dy).reduce(max);
    final transformedW = (maxX - minX).clamp(1.0, double.infinity);
    final transformedH = (maxY - minY).clamp(1.0, double.infinity);
    final baseScale = fit == BoxFit.cover
        ? max(displayW / transformedW, displayH / transformedH)
        : min(displayW / transformedW, displayH / transformedH);
    final scale = baseScale * zoom;
    final offsetX = (displayW - transformedW * scale) / 2;
    final offsetY = (displayH - transformedH * scale) / 2;

    _cachedTransform = transformed;
    _cachedMinX = minX;
    _cachedMinY = minY;
    _cachedScale = scale;
    _cachedOffsetX = offsetX;
    _cachedOffsetY = offsetY;
  }

  void _drawMeasurementLabel(
      Canvas canvas, String text, List<Offset> points, Size canvasSize) {
    if (points.isEmpty) return;
    final anchor = points.length == 1
        ? points.first
        : Offset(
            (points.first.dx + points.last.dx) / 2,
            (points.first.dy + points.last.dy) / 2,
          );
    final mFont = (13 * uiTextScale).clamp(14.0, 64.0);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: mFont,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(minWidth: 0, maxWidth: 220);

    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 4);
    final labelWidth = max(textPainter.width + padding.horizontal, 64.0);
    final labelHeight = textPainter.height + padding.vertical;
    final maxLeft = (canvasSize.width - labelWidth).clamp(0.0, double.infinity);
    final maxTop = (canvasSize.height - labelHeight).clamp(0.0, double.infinity);
    final preferredLeft = anchor.dx - (labelWidth / 2);
    final labelLeft = preferredLeft < 8
        ? 8.0
        : preferredLeft > maxLeft - 8
            ? maxLeft
            : preferredLeft;
    final preferredTop = anchor.dy - labelHeight - 18;
    final labelTop = preferredTop < 8
        ? (anchor.dy + 18).clamp(8.0, maxTop)
        : preferredTop > maxTop - 8
            ? maxTop
            : preferredTop;
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelLeft,
        labelTop,
        labelWidth,
        labelHeight,
      ),
      const Radius.circular(12),
    );

    final labelPaint = Paint()..color = const Color(0xCC10162E);
    final textOffset = Offset(
      labelRect.left + ((labelWidth - textPainter.width) / 2),
      labelRect.top + (labelHeight - textPainter.height) / 2 - 1,
    );

    // Keep labels axis-aligned in display (viewport) space so text stays
    // upright and readable; geometry is already transformed in [points].
    canvas.drawRRect(labelRect, labelPaint);
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter old) => true;
}
