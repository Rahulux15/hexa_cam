import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Top-level helpers for [compute] — keep in sync with call sites.

/// Full-resolution marked stills: high JPEG quality keeps thin lines/text crisp
/// while staying far smaller than PNG from the GPU renderer.
const int kMarkedStillJpegQuality = 100;

/// Folder/grid thumbnails (backup / small previews). Full-res [mediaId] is used
/// for photo tiles when possible; this remains for videos and fallbacks.
const int kThumbnailMaxEdge = 2400;
const int kThumbnailJpegQuality = 98;

Uint8List? bytesToJpeg(Uint8List input, int quality) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;
  return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
}

Uint8List? bytesToThumbnailJpeg(Uint8List input, int maxEdge, int quality) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;
  var w = decoded.width;
  var h = decoded.height;
  if (w <= 0 || h <= 0) return null;
  if (w > maxEdge || h > maxEdge) {
    if (w >= h) {
      h = (h * maxEdge / w).round();
      w = maxEdge;
    } else {
      w = (w * maxEdge / h).round();
      h = maxEdge;
    }
    w = w.clamp(1, maxEdge);
    h = h.clamp(1, maxEdge);
  }
  final resized = img.copyResize(
    decoded,
    width: w,
    height: h,
    interpolation: img.Interpolation.cubic,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}

/// Isolate entry: marked stills (PNG from renderer) → high-quality JPEG for DB/disk.
Uint8List compressMarkedStillForStore(Uint8List input) =>
    bytesToJpeg(input, kMarkedStillJpegQuality) ?? input;

/// Isolate entry: list/grid thumbnail (separate from full [mediaId] asset).
Uint8List thumbnailOrCompressed(Uint8List input) =>
    bytesToThumbnailJpeg(input, kThumbnailMaxEdge, kThumbnailJpegQuality) ??
    bytesToJpeg(input, kThumbnailJpegQuality) ??
    input;

