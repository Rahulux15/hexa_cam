import 'package:demo_app/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calibration stamp size stays within bounds', () {
    final small = Responsive.calibrationStampFontSize(const Size(200, 120));
    final large = Responsive.calibrationStampFontSize(const Size(3000, 2000));

    expect(small, greaterThanOrEqualTo(24.0));
    expect(small, lessThanOrEqualTo(120.0));
    expect(large, greaterThanOrEqualTo(24.0));
    expect(large, lessThanOrEqualTo(120.0));
  });

  test('calibration stamp anchor stays in the safe corner', () {
    final anchor = Responsive.calibrationStampAnchor(const Size(1000, 800));
    expect(anchor.dx, lessThan(1000));
    expect(anchor.dy, lessThan(800));
  });
}
