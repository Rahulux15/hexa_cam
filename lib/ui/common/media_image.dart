import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/annotation.dart';
import '../../data/services/database_service.dart';
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

  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> {
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
        !_sameAnnotationList(oldWidget.annotations, widget.annotations)) {
      _bytesFuture = _buildBytesFuture();
    }
  }

  bool _sameAnnotationList(List<Annotation> a, List<Annotation> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].points.length != b[i].points.length) {
        return false;
      }
    }
    return true;
  }

  Future<Uint8List?> _buildBytesFuture() async {
    if (widget.mediaId != null && widget.mediaId!.isNotEmpty) {
      final bytes = await MediaDatabase.getAsset(widget.mediaId!);
      if (bytes == null || bytes.isEmpty) return null;
      if (widget.annotations.isEmpty || !widget.burnAnnotationsIntoPreview) {
        return bytes;
      }
      return MarkedMediaRenderer.renderPhotoWithAnnotations(
        baseImageBytes: bytes,
        annotations: widget.annotations,
        mirrorX: widget.mirrorX,
        mirrorY: widget.mirrorY,
        rotation: widget.rotation,
      );
    }
    if (!kIsWeb &&
        widget.source.startsWith('file://') &&
        widget.burnAnnotationsIntoPreview &&
        widget.annotations.isNotEmpty) {
      final path = widget.source.replaceFirst('file://', '');
      final raw = await File(path).readAsBytes();
      return MarkedMediaRenderer.renderPhotoWithAnnotations(
        baseImageBytes: raw,
        annotations: widget.annotations,
        mirrorX: widget.mirrorX,
        mirrorY: widget.mirrorY,
        rotation: widget.rotation,
      );
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
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2));
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

    if (widget.source.startsWith('file://')) {
      return FutureBuilder<Uint8List?>(
        future: _loadSourceBytes(),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (bytes != null && bytes.isNotEmpty) {
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
          return _fallback();
        },
      );
    }

    return Image.network(
      widget.source.startsWith('file://') ? widget.source.replaceFirst('file://', '') : widget.source,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Future<Uint8List?> _loadSourceBytes() async {
    if (!widget.source.startsWith('file://')) return null;
    try {
      return await MediaDatabase.getAsset(widget.source.replaceFirst('file://', ''));
    } catch (_) {
      return null;
    }
  }

  Widget _fallback() => widget.errorWidget ?? const SizedBox.shrink();
}
