import 'package:flutter/material.dart';

import '../../data/models/camera_settings.dart';
import '../../features/camera/camera_color_matrix.dart';

/// Live preview + export: exposure %, ISO, color temperature (K), tint (−100…100).
class ViewerFilters {
  double exposurePercent;
  double iso;
  double temperatureK;
  double tint;

  ViewerFilters({
    this.exposurePercent = 100,
    this.iso = 400,
    this.temperatureK = 6500,
    this.tint = 0,
  });

  factory ViewerFilters.fromCameraSettings(CameraSettings s) => ViewerFilters(
        exposurePercent: s.exposure.clamp(10, 200),
        iso: s.iso.clamp(50, 12800),
        temperatureK: s.temperature.clamp(2000, 12000),
        tint: s.tint.clamp(-100, 100),
      );

  CameraSettings toCameraSettings() => CameraSettings(
        exposure: exposurePercent,
        iso: iso,
        temperature: temperatureK,
        tint: tint,
      );

  ViewerFilters copyWith({
    double? exposurePercent,
    double? iso,
    double? temperatureK,
    double? tint,
  }) =>
      ViewerFilters(
        exposurePercent: exposurePercent ?? this.exposurePercent,
        iso: iso ?? this.iso,
        temperatureK: temperatureK ?? this.temperatureK,
        tint: tint ?? this.tint,
      );
}

/// Column-major 4×5 matrices for [ColorFilter.matrix] (Flutter / Skia layout).
class ViewerFilterMatrix {
  ViewerFilterMatrix._();

  /// Applies the same preview pipeline used by the Camera screen.
  ///
  /// Important: This is **preview-only** (ColorFiltered). Saving/exporting is handled
  /// separately (via RepaintBoundary capture or renderer pipelines).
  static Widget wrap(Widget child, ViewerFilters f) {
    final settings = CameraSettings(
      exposure: f.exposurePercent,
      iso: f.iso,
      temperature: f.temperatureK,
      tint: f.tint,
    );
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(cameraPreviewColorMatrix(settings)),
      child: child,
    );
  }
}
