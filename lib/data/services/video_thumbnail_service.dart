import 'dart:typed_data';

import 'video_thumbnail_stub.dart'
    if (dart.library.html) 'video_thumbnail_web.dart' as impl;

Future<Uint8List?> extractVideoThumbnailForSource(String source) {
  return impl.extractVideoThumbnailForSource(source);
}
