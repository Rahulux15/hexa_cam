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
        (ann.strokeWidth * lineWidthScale).clamp(2.0, 120.0).toDouble();
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
          final textScale = sqrt(uiTextScale.clamp(0.8, 4.0));
          final fontSize = (ann.labelFontSize ??
                  (10.0 + (strokeWidth * 0.9) + ((textScale - 1.0) * 6.0)))
              .clamp(10.0, 120.0)
              .toDouble();
          final anchor = points[0];
          final maxW = (canvasSize.width * 0.55).clamp(120.0, 820.0).toDouble();
          final strokeW =
              (1.4 + (strokeWidth * 0.12)).clamp(1.4, 6.0).toDouble();
          final lum = ann.color.computeLuminance();
          final fillColor = lum > 0.52 ? const Color(0xFF121212) : Colors.white;
          final strokeColor =
              lum > 0.52 ? Colors.white : const Color(0xFF121212);
          const baseWeight = TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.2,
          );
          final strokeTp = TextPainter(
            text: TextSpan(
              text: ann.text,
              style: baseWeight.copyWith(
                fontSize: fontSize,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = strokeW
                  ..color = strokeColor
                  ..strokeJoin = StrokeJoin.round
                  ..isAntiAlias = true,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(minWidth: 0, maxWidth: maxW);
          final fillTp = TextPainter(
            text: TextSpan(
              text: ann.text,
              style: baseWeight.copyWith(
                fontSize: fontSize,
                color: fillColor,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(minWidth: 0, maxWidth: maxW);
          final tw = strokeTp.width;
          final th = strokeTp.height;
          const edge = 8.0;
          const gap = 10.0;
          // Keep label above-left of tap so it does not sit on the anchor.
          var left = (anchor.dx - tw - gap)
              .clamp(
                edge,
                max(edge, canvasSize.width - tw - edge),
              )
              .toDouble();
          var top = (anchor.dy - th - gap)
              .clamp(
                edge,
                max(edge, canvasSize.height - th - edge),
              )
              .toDouble();
          if (top >= anchor.dy - 2) {
            top = (anchor.dy + gap)
                .clamp(
                  edge,
                  max(edge, canvasSize.height - th - edge),
                )
                .toDouble();
          }
          final labelOffset = _sourceDeltaToDisplayDelta(
            HexaPoint(x: ann.labelOffsetX, y: ann.labelOffsetY),
          );
          final labelPos = Offset(left, top) + labelOffset;
          strokeTp.paint(canvas, labelPos);
          fillTp.paint(canvas, labelPos);
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
        canvas.drawLine(Offset(p.dx - 8, p.dy), Offset(p.dx + 8, p.dy), paint);
        canvas.drawLine(Offset(p.dx, p.dy - 8), Offset(p.dx, p.dy + 8), paint);
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
      _drawMeasurementLabel(
        canvas,
        ann.measurement!,
        points,
        canvasSize,
        ann.color,
        ann.type,
        ann.strokeWidth,
        ann.labelFontSize,
        _sourceDeltaToDisplayDelta(
          HexaPoint(x: ann.labelOffsetX, y: ann.labelOffsetY),
        ),
      );
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

  Offset _sourceDeltaToDisplayDelta(HexaPoint sourceDelta) {
    _ensureTransformCache();
    final transformed = _cachedTransform!;
    final zoomedScale = _cachedScale!;
    final origin = transformed.transform3(Vector3(0, 0, 1));
    final shifted =
        transformed.transform3(Vector3(sourceDelta.x, sourceDelta.y, 1));
    return Offset(
      (shifted.x - origin.x) * zoomedScale,
      (shifted.y - origin.y) * zoomedScale,
    );
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

  /// Measurement labels sit **outside** shapes (no pill). Fill / stroke from
  /// [annotationColor] luminance for contrast on the photo.
  void _drawMeasurementLabel(
    Canvas canvas,
    String text,
    List<Offset> points,
    Size canvasSize,
    Color annotationColor,
    AnnotationType type,
    double strokeWidth,
    double? labelFontSize,
    Offset labelOffset,
  ) {
    if (points.isEmpty) return;
    final textScale = sqrt(uiTextScale.clamp(0.8, 4.0));
    final targetFont = (labelFontSize ??
            (10.0 + (strokeWidth * 1.1) + ((textScale - 1.0) * 8.0)))
        .clamp(8.0, 120.0)
        .toDouble();
    final maxLabelWidth =
        (canvasSize.width - (_labelEdgePad * 2) - 4.0).clamp(64.0, 2400.0);
    const baseStyle = TextStyle(
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    final mFont = _fitSingleLineFontSize(
      text: text,
      baseStyle: baseStyle,
      targetFont: targetFont,
      minFont: 8.0,
      maxWidth: maxLabelWidth,
    );
    final strokeW =
        (1.35 + ((textScale - 1.0) * 1.15)).clamp(1.35, 4.2).toDouble();

    final lum = annotationColor.computeLuminance();
    final fillColor = lum > 0.52 ? const Color(0xFF121212) : Colors.white;
    final strokeColor = lum > 0.52 ? Colors.white : const Color(0xFF121212);

    final strokePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: baseStyle.copyWith(
          fontSize: mFont,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..color = strokeColor
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: maxLabelWidth);

    final fillPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: baseStyle.copyWith(
          fontSize: mFont,
          color: fillColor,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: maxLabelWidth);

    final labelWidth = strokePainter.width;
    final labelHeight = strokePainter.height;
    final baseOffset = _measurementLabelTopLeft(
      type: type,
      points: points,
      canvasSize: canvasSize,
      labelWidth: labelWidth,
      labelHeight: labelHeight,
    );
    final shiftedOffset = Offset(
      (baseOffset.dx + labelOffset.dx)
          .clamp(_labelEdgePad,
              max(_labelEdgePad, canvasSize.width - labelWidth - _labelEdgePad))
          .toDouble(),
      (baseOffset.dy + labelOffset.dy)
          .clamp(
              _labelEdgePad,
              max(_labelEdgePad,
                  canvasSize.height - labelHeight - _labelEdgePad))
          .toDouble(),
    );
    strokePainter.paint(canvas, shiftedOffset);
    fillPainter.paint(canvas, shiftedOffset);
  }

  static const double _labelEdgePad = 8.0;
  static const double _labelShapeGap = 10.0;

  double _fitSingleLineFontSize({
    required String text,
    required TextStyle baseStyle,
    required double targetFont,
    required double minFont,
    required double maxWidth,
  }) {
    var font = targetFont;
    final probe = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    for (var i = 0; i < 18; i++) {
      probe.text = TextSpan(
        text: text,
        style: baseStyle.copyWith(fontSize: font),
      );
      probe.layout(minWidth: 0, maxWidth: double.infinity);
      final measured = probe.width;
      if (measured <= maxWidth || font <= minFont + 0.05) break;
      final ratio = maxWidth / measured;
      final next = max(minFont, font * ratio * 0.985);
      if ((font - next).abs() < 0.1) {
        font = max(minFont, font - 0.6);
      } else {
        font = next;
      }
    }
    return font;
  }

  Offset _measurementLabelTopLeft({
    required AnnotationType type,
    required List<Offset> points,
    required Size canvasSize,
    required double labelWidth,
    required double labelHeight,
  }) {
    final pad = _labelEdgePad;
    final gap = _labelShapeGap;

    double clampX(double x) => x
        .clamp(
          pad,
          max(pad, canvasSize.width - labelWidth - pad),
        )
        .toDouble();

    double clampY(double y) => y
        .clamp(
          pad,
          max(pad, canvasSize.height - labelHeight - pad),
        )
        .toDouble();

    switch (type) {
      case AnnotationType.circle:
        if (points.length >= 2) {
          final c = points[0];
          final r = (points[1] - c).distance;
          var top = c.dy - r - gap - labelHeight;
          var left = c.dx - labelWidth / 2;
          if (top < pad) {
            top = c.dy + r + gap;
          }
          return Offset(clampX(left), clampY(top));
        }
        break;
      case AnnotationType.rectangle:
      case AnnotationType.square:
        if (points.length >= 2) {
          final rect = Rect.fromPoints(points[0], points[1]);
          var top = rect.top - gap - labelHeight;
          var left = rect.center.dx - labelWidth / 2;
          if (top < pad) {
            top = rect.bottom + gap;
          }
          return Offset(clampX(left), clampY(top));
        }
        break;
      case AnnotationType.twoPointer:
      case AnnotationType.arrow:
      case AnnotationType.arrowOneWay:
        if (points.length >= 2) {
          final a = points[0];
          final b = points[1];
          final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
          final dx = b.dx - a.dx;
          final dy = b.dy - a.dy;
          final len = sqrt(dx * dx + dy * dy);
          if (len < 1e-6) {
            final left = clampX(mid.dx - labelWidth / 2);
            final top = clampY(mid.dy - gap - labelHeight);
            return Offset(left, top);
          }
          final nx = -dy / len;
          final ny = dx / len;
          final dist = gap + labelHeight * 0.35 + 10.0;
          Offset side(double sign) {
            final cx = mid.dx + nx * dist * sign - labelWidth / 2;
            final cy = mid.dy + ny * dist * sign - labelHeight / 2;
            return Offset(clampX(cx), clampY(cy));
          }

          // Keep label side deterministic to avoid side-switch jumps.
          return side(1);
        }
        break;
      case AnnotationType.singlePointer:
        if (points.isNotEmpty) {
          final p = points[0];
          var top = p.dy - gap - labelHeight;
          var left = p.dx - labelWidth / 2;
          if (top < pad) {
            top = p.dy + gap;
          }
          return Offset(clampX(left), clampY(top));
        }
        break;
      case AnnotationType.draw:
        if (points.isNotEmpty) {
          var minX = points.first.dx;
          var maxX = points.first.dx;
          var minY = points.first.dy;
          var maxY = points.first.dy;
          for (final q in points) {
            minX = min(minX, q.dx);
            maxX = max(maxX, q.dx);
            minY = min(minY, q.dy);
            maxY = max(maxY, q.dy);
          }
          final rect = Rect.fromLTRB(minX, minY, maxX, maxY);
          var top = rect.top - gap - labelHeight;
          var left = rect.center.dx - labelWidth / 2;
          if (top < pad) {
            top = rect.bottom + gap;
          }
          return Offset(clampX(left), clampY(top));
        }
        break;
      case AnnotationType.text:
        break;
    }

    final anchor = points.length == 1
        ? points.first
        : Offset(
            (points.first.dx + points.last.dx) / 2,
            (points.first.dy + points.last.dy) / 2,
          );
    var top = anchor.dy - labelHeight - 22;
    if (top < pad) {
      top = anchor.dy + 22;
    }
    var left = anchor.dx - labelWidth / 2;
    return Offset(clampX(left), clampY(top));
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter old) => true;
}
