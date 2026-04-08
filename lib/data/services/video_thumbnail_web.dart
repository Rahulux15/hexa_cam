// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> extractVideoThumbnailForSource(String source) async {
  if (source.trim().isEmpty) return null;
  final video = html.VideoElement()
    ..src = source
    ..muted = true
    ..autoplay = false
    ..preload = 'metadata';

  try {
    await video.onLoadedMetadata.first.timeout(const Duration(seconds: 6));
    if (video.duration.isFinite && video.duration > 0.15) {
      video.currentTime = 0.12;
      await video.onSeeked.first.timeout(const Duration(seconds: 4));
    }
    final width = video.videoWidth;
    final height = video.videoHeight;
    if (width <= 0 || height <= 0) return null;

    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;
    ctx.drawImage(video, 0, 0);
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.88);
    final comma = dataUrl.indexOf(',');
    if (comma < 0 || comma + 1 >= dataUrl.length) return null;
    return Uint8List.fromList(base64Decode(dataUrl.substring(comma + 1)));
  } catch (_) {
    return null;
  } finally {
    video.pause();
    video.removeAttribute('src');
    video.load();
  }
}
