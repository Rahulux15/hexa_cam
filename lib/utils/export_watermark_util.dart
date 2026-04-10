import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Decodes common formats and re-encodes as JPEG so watermark decode succeeds
/// (e.g. flattened PNG from the viewer, wide-gamut stills).
Uint8List? reencodeImageBytesAsJpegForWatermark(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  } catch (_) {
    return null;
  }
}

/// Composites [logoBytes] onto [imageBytes] (bottom-right).
/// Uses moderate alpha so the mark is visible on exports (was ~10% and often invisible).
/// On any failure returns `null` so callers can fall back to original bytes.
Uint8List? applyReportLogoWatermark(Uint8List imageBytes, Uint8List logoBytes) {
  try {
    final original = img.decodeImage(imageBytes);
    final logo = img.decodeImage(logoBytes);
    if (original == null || logo == null) return null;

    final targetW = (original.width * 0.18).round().clamp(1, 512);
    final scaled = img.copyResize(logo, width: targetW);
    _multiplyAlpha(scaled, 0.42);

    final margin = 16;
    final dstX = original.width - scaled.width - margin;
    final dstY = original.height - scaled.height - margin;

    img.compositeImage(
      original,
      scaled,
      dstX: dstX.clamp(0, original.width - 1),
      dstY: dstY.clamp(0, original.height - 1),
    );
    return Uint8List.fromList(img.encodeJpg(original, quality: 92));
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('applyReportLogoWatermark failed: $e $st');
    }
    return null;
  }
}

void _multiplyAlpha(img.Image im, double factor) {
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      final p = im.getPixel(x, y);
      final a = (p.a * factor).round().clamp(0, 255);
      im.setPixel(
        x,
        y,
        img.ColorRgba8(
          p.r.toInt() & 0xff,
          p.g.toInt() & 0xff,
          p.b.toInt() & 0xff,
          a,
        ),
      );
    }
  }
}
