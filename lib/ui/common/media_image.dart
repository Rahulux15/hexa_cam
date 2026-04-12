import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/annotation.dart';
import '../../data/services/database_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/marked_media_renderer.dart';

/// Loads image bytes from [mediaId] and/or [source].
///
/// When [burnAnnotationsIntoPreview] is true (default), annotations are rasterized
/// into the bitmap (expensive). For in-app viewers that already paint annotations with
/// [CustomPaint], set it to false to decode once and avoid huge memory churn.
///
/// [cacheWidth] / [cacheHeight] resize at decode time (device pixels) — use for
/// grids so full-resolution files stay sharp without decoding 12MP+ into RAM.
class MediaImage extends StatefulWidget {
  const MediaImage({
    super.key,
    required this.source,
    this.mediaId,
    this.annotations = const [],
    this.burnAnnotationsIntoPreview = true,
    this.mirrorX = false,
    this.mirrorY = false,
    this.rotation = 0,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.high,
    this.annotationSourceSize,
  });

  final String source;
  final String? mediaId;
  final List<Annotation> annotations;
  final bool burnAnnotationsIntoPreview;
  final bool mirrorX;
  final bool mirrorY;
  final int rotation;
  final BoxFit fit;
  final Widget? errorWidget;
  final int? cacheWidth;
  final int? cacheHeight;
  final FilterQuality filterQuality;
  final Size? annotationSourceSize;

  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> {
  static final Map<String, Uint8List> _assetByteCache = <String, Uint8List>{};
  static const int _maxAssetCacheEntries = 80;
  Future<Uint8List?>? _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _buildBytesFuture();
  }

  @override
  void didUpdateWidget(MediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId ||
        oldWidget.source != widget.source ||
        oldWidget.burnAnnotationsIntoPreview !=
            widget.burnAnnotationsIntoPreview ||
        oldWidget.mirrorX != widget.mirrorX ||
        oldWidget.mirrorY != widget.mirrorY ||
        oldWidget.rotation != widget.rotation ||
        oldWidget.cacheWidth != widget.cacheWidth ||
        oldWidget.cacheHeight != widget.cacheHeight ||
        oldWidget.annotationSourceSize != widget.annotationSourceSize ||
        !_sameAnnotationList(oldWidget.annotations, widget.annotations)) {
      _bytesFuture = _buildBytesFuture();
    }
  }

  bool _sameAnnotationList(List<Annotation> a, List<Annotation> b) {
    try {
      if (identical(a, b)) return true;
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        // Full payload compare: moves, label offsets, stroke, points, text, etc.
        if (jsonEncode(a[i].toJson()) != jsonEncode(b[i].toJson())) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> _buildBytesFuture() async {
    if (widget.mediaId != null && widget.mediaId!.isNotEmpty) {
      // Cache only the raw asset from DB. Always run the burn step when
      // annotations are shown — returning cached bytes early skipped overlays
      // on any second [MediaImage] using the same [mediaId] (folder grid, etc.).
      Uint8List? raw = _assetByteCache[widget.mediaId!];
      if (raw == null || raw.isEmpty) {
        raw = await MediaDatabase.getAsset(widget.mediaId!);
        if (raw == null || raw.isEmpty) return null;
        _assetByteCache[widget.mediaId!] = raw;
        if (_assetByteCache.length > _maxAssetCacheEntries) {
          _assetByteCache.remove(_assetByteCache.keys.first);
        }
      }
      if (widget.annotations.isEmpty || !widget.burnAnnotationsIntoPreview) {
        return raw;
      }
      try {
        return await MarkedMediaRenderer.renderPhotoWithAnnotations(
          baseImageBytes: raw,
          annotations: widget.annotations,
          mirrorX: widget.mirrorX,
          mirrorY: widget.mirrorY,
          rotation: widget.rotation,
          annotationSourceSize: widget.annotationSourceSize,
        );
      } catch (e, st) {
        logDebug('MediaImage burn (mediaId) failed: $e\n$st');
        return null;
      }
    }
    if (!kIsWeb &&
        widget.source.startsWith('file://') &&
        widget.burnAnnotationsIntoPreview &&
        widget.annotations.isNotEmpty) {
      try {
        final path = widget.source.replaceFirst('file://', '');
        final raw = await File(path).readAsBytes();
        return await MarkedMediaRenderer.renderPhotoWithAnnotations(
          baseImageBytes: raw,
          annotations: widget.annotations,
          mirrorX: widget.mirrorX,
          mirrorY: widget.mirrorY,
          rotation: widget.rotation,
          annotationSourceSize: widget.annotationSourceSize,
        );
      } catch (e, st) {
        logDebug('MediaImage burn (file) failed: $e\n$st');
        return null;
      }
    }
    return null;
  }

  bool get _usesBytesFuture {
    final hasMedia = widget.mediaId != null && widget.mediaId!.isNotEmpty;
    final fileBurn = !kIsWeb &&
        widget.source.startsWith('file://') &&
        widget.burnAnnotationsIntoPreview &&
        widget.annotations.isNotEmpty;
    return hasMedia || fileBurn;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.source.isEmpty &&
        (widget.mediaId == null || widget.mediaId!.isEmpty)) {
      return _fallback();
    }

    if (_usesBytesFuture) {
      return FutureBuilder<Uint8List?>(
        future: _bytesFuture,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return widget.source.isNotEmpty
                ? _buildFromSource()
                : const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
          }
          if (snapshot.hasError) {
            logDebug('MediaImage future error: ${snapshot.error}');
            return _buildFromSource();
          }
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(
              bytes,
              fit: widget.fit,
              gaplessPlayback: true,
              cacheWidth: widget.cacheWidth,
              cacheHeight: widget.cacheHeight,
              filterQuality: widget.filterQuality,
              errorBuilder: (context, error, stackTrace) => _buildFromSource(),
            );
          }
          return _buildFromSource();
        },
      );
    }

    return _buildFromSource();
  }

  Widget _buildFromSource() {
    if (!kIsWeb && widget.source.startsWith('file://')) {
      return Image.file(
        File(widget.source.replaceFirst('file://', '')),
        fit: widget.fit,
        gaplessPlayback: true,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        filterQuality: widget.filterQuality,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    // Android/iOS app data paths can come without a file:// scheme.
    if (!kIsWeb &&
        widget.source.isNotEmpty &&
        !widget.source.startsWith('http://') &&
        !widget.source.startsWith('https://') &&
        !widget.source.startsWith('data:')) {
      return Image.file(
        File(widget.source),
        fit: widget.fit,
        gaplessPlayback: true,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        filterQuality: widget.filterQuality,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    if (widget.source.startsWith('data:image/')) {
      final bytes = _decodeDataUrl(widget.source);
      if (bytes == null || bytes.isEmpty) return _fallback();
      return Image.memory(
        bytes,
        fit: widget.fit,
        gaplessPlayback: true,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        filterQuality: widget.filterQuality,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    return Image.network(
      widget.source.startsWith('file://') ? widget.source.replaceFirst('file://', '') : widget.source,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Uint8List? _decodeDataUrl(String source) {
    if (!source.startsWith('data:image/')) return null;
    try {
      final commaIndex = source.indexOf(',');
      if (commaIndex <= 0 || commaIndex + 1 >= source.length) return null;
      return Uint8List.fromList(base64Decode(source.substring(commaIndex + 1)));
    } catch (_) {
      return null;
    }
  }

  Widget _fallback() => widget.errorWidget ?? const SizedBox.shrink();
}
