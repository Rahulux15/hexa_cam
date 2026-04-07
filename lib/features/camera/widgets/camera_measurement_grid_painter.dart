import 'package:flutter/material.dart';

/// Subtle grid overlay for measurement mode on the camera preview.
class CameraMeasurementGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x126366F1)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 60; y <= size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
