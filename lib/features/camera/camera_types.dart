import 'package:flutter/material.dart';

enum CameraViewMode { defaultOpen, toolsExpanded }

enum CameraSideAction {
  lens,
  flipVertical,
  flipHorizontal,
  rotate,
  calibration,
  move,
  status,
  sparkle,
  zoomIn,
  zoomOut,
  record,
  capture,
  inspect,
  pen,
}

class CameraLayoutTokens {
  static const Color background = Color(0xFF04072A);
  static const Color railButtonBg = Color(0x220D1238);
  static const Color railButtonBorder = Color(0x55A7B6FF);
  static const Color railIcon = Color(0xFFE7ECFF);
  static const Color railSubtleIcon = Color(0xCCDFE5FF);
  static const Color statusOn = Color(0xFF6B5DFF);
  static const Color recordRed = Color(0xFFFF3D42);
  static const Color panelBg = Color(0xF2191A49);

  static double railButtonSize(bool isTablet) => isTablet ? 54 : 40;
  static double railTinyFont(bool isTablet) => isTablet ? 16 : 12;
  static double railIconSize(bool isTablet) => isTablet ? 24 : 18;
  static double recordButtonSize(bool isTablet) => isTablet ? 66 : 56;
  static double edgePadding(bool isTablet) => isTablet ? 28 : 14;
  static double railGap(bool isTablet) => isTablet ? 14 : 10;
}
