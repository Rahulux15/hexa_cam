import 'package:flutter/material.dart';

class AppConstants {
  static const double minExposure = 50.0;
  static const double maxExposure = 200.0;
  static const double defaultExposure = 100.0;
  static const double minIso = 100.0;
  static const double maxIso = 3200.0;
  static const double defaultIso = 400.0;
  static const double minTemperature = 2000.0;
  static const double maxTemperature = 10000.0;
  static const double defaultTemperature = 6500.0;
  static const double minTint = -100.0;
  static const double maxTint = 100.0;
  static const double defaultTint = 0.0;
  static const double minZoom = 1.0;
  static const double maxZoom = 100.0;
  static const double defaultZoom = 1.0;
  static const List<String> magnificationLevels = ['4X', '10X', '20X', '40X', '60X', '100X'];
  static const List<Color> annotationColors = [
    Color(0xFFFF00FF), Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFF0000FF),
    Color(0xFFFFFF00), Color(0xFF00FFFF), Color(0xFFFFFFFF), Color(0xFFFF8800),
  ];
  static const List<String> drawingTools = ['move','draw','text','two-pointer','single-pointer','square','circle','arrow-one-way'];
  static const Duration longPressDuration = Duration(milliseconds: 500);
  static const Duration splashDuration = Duration(milliseconds: 2500);
  static const Duration loginDelay = Duration(milliseconds: 1000);
  static const double slideshowFrameDuration = 1.2;
  static const double annotationStrokeWidth = 3.0;
  static const double arrowHeadLength = 20.0;
  static const double arrowHeadAngle = 0.523599;
  static const double twoPointerRadius = 5.0;
  static const double singlePointerCrosshair = 12.0;
  static const double singlePointerDotRadius = 6.0;
  static const double annotationFontSize = 24.0;
  static const double measurementLabelFontSize = 14.0;
  static const double measurementLabelLineHeight = 18.0;
  static const double measurementLabelPadding = 12.0;
  static const double calibrationStampFontSize = 16.0;
  static const double calibrationStampPaddingX = 12.0;
  static const double calibrationStampPaddingY = 9.0;
  static const double calibrationStampRadius = 10.0;
  static const double eraserThreshold = 20.0;
  static const double pointTolerance = 6.0;
  static const double boundsTolerancePercent = 0.08;
  static const String keyFolders = 'folders';
  static const String keyProfile = 'profile';
  static const String keyNotifications = 'notifications';
  static const String keyAppearance = 'appearance';
  static const String keyCalibration = 'calibration';
  static const String keyCalibrations = 'hexacam_calibrations';
  static const String keyExportWatermark = 'hexacam_export_watermark';
  static const String keyExportPdfProvenance = 'hexacam_export_pdf_provenance';
  static const String keyLastSeenReleaseNotesVersion =
      'hexacam_last_seen_release_notes';
  static const String demoEmail = 'test@hexacam.com';
}
