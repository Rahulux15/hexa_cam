import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/models/annotation.dart';
import 'annotation_painter.dart';

class MarkedMediaRenderer {
  static Future<Uint8List> renderAnnotationOverlay({
    required Size sourceSize,
    required List<Annotation> annotations,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = AnnotationPainter(
      annotations: annotations,
      displaySize: sourceSize,
      sourceSize: sourceSize,
      fit: BoxFit.contain,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      zoom: 1,
      rotation: rotation,
    );
    painter.paint(canvas, sourceSize);
    final outImage = await recorder.endRecording().toImage(
          sourceSize.width.round().clamp(1, 8192),
          sourceSize.height.round().clamp(1, 8192),
        );
    final outData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    return outData!.buffer.asUint8List();
  }

  static Future<Uint8List> renderPhotoWithAnnotations({
    required Uint8List baseImageBytes,
    required List<Annotation> annotations,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
  }) async {
    final image = await _decodeImage(baseImageBytes);
    final sourceSize = Size(image.width.toDouble(), image.height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final center = Offset(sourceSize.width / 2, sourceSize.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 3.1415926535897932 / 180.0);
    canvas.scale(mirrorX ? -1.0 : 1.0, mirrorY ? -1.0 : 1.0);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, sourceSize.width, sourceSize.height),
      Rect.fromCenter(
        center: Offset.zero,
        width: sourceSize.width,
        height: sourceSize.height,
      ),
      Paint(),
    );
    canvas.restore();

    final painter = AnnotationPainter(
      annotations: annotations,
      displaySize: sourceSize,
      sourceSize: sourceSize,
      fit: BoxFit.contain,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      zoom: 1,
      rotation: rotation,
    );
    painter.paint(canvas, sourceSize);

    final outImage = await recorder
        .endRecording()
        .toImage(image.width, image.height);
    final outData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    return outData!.buffer.asUint8List();
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }
}
