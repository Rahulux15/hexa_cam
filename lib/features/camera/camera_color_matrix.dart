import '../../config/constants.dart';
import '../../data/models/camera_settings.dart';

/// Color matrix for preview-only adjustments (exposure / saturation / WB simulation).
List<double> cameraPreviewColorMatrix(CameraSettings settings) {
  final exposure = (settings.exposure / 100).clamp(0.5, 2.0);
  final saturation = (settings.iso / AppConstants.defaultIso).clamp(0.25, 2.0);
  final invSat = 1 - saturation;
  const lumR = 0.2126;
  const lumG = 0.7152;
  const lumB = 0.0722;

  final temperatureNorm = ((settings.temperature - 6500.0) / 3500.0).clamp(
    -1.0,
    1.0,
  );
  final tempRed = temperatureNorm * 18.0;
  final tempBlue = -temperatureNorm * 18.0;

  final tintNorm = (settings.tint / 100.0).clamp(-1.0, 1.0);
  final tintGreen = -tintNorm * 14.0;
  final tintMagentaRB = tintNorm * 8.0;

  return [
    exposure * (invSat * lumR + saturation),
    exposure * (invSat * lumG),
    exposure * (invSat * lumB),
    0,
    tempRed + tintMagentaRB,
    exposure * (invSat * lumR),
    exposure * (invSat * lumG + saturation),
    exposure * (invSat * lumB),
    0,
    tintGreen,
    exposure * (invSat * lumR),
    exposure * (invSat * lumG),
    exposure * (invSat * lumB + saturation),
    0,
    tempBlue + tintMagentaRB,
    0,
    0,
    0,
    1,
    0,
  ];
}
