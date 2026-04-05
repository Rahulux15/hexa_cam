import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/annotation.dart';
import '../../data/services/database_service.dart';
import '../../utils/marked_media_renderer.dart';

class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.source,
    this.mediaId,
    this.annotations = const [],
    this.mirrorX = false,
    this.mirrorY = false,
    this.rotation = 0,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  final String source;
  final String? mediaId;
  final List<Annotation> annotations;
  final bool mirrorX;
  final bool mirrorY;
  final int rotation;
  final BoxFit fit;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty && (mediaId == null || mediaId!.isEmpty)) {
      return _fallback();
    }

    if (mediaId != null && mediaId!.isNotEmpty) {
      return FutureBuilder<Uint8List?>(
        future: _buildBytes(),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(
              bytes,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _buildFromSource(),
            );
          }
          return _buildFromSource();
        },
      );
    }

    return _buildFromSource();
  }

  Future<Uint8List?> _buildBytes() async {
    final bytes = await MediaDatabase.getAsset(mediaId!);
    if (bytes == null || bytes.isEmpty) return null;
    if (annotations.isEmpty) return bytes;
    return MarkedMediaRenderer.renderPhotoWithAnnotations(
      baseImageBytes: bytes,
      annotations: annotations,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
    );
  }

  Widget _buildFromSource() {
    if (!kIsWeb && source.startsWith('file://')) {
      return Image.file(
        File(source.replaceFirst('file://', '')),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    if (source.startsWith('file://')) {
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
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _fallback(),
            );
          }
          return _fallback();
        },
      );
    }

    return Image.network(
      source.startsWith('file://') ? source.replaceFirst('file://', '') : source,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Future<Uint8List?> _loadSourceBytes() async {
    if (!source.startsWith('file://')) return null;
    try {
      return await MediaDatabase.getAsset(source.replaceFirst('file://', ''));
    } catch (_) {
      return null;
    }
  }

  Widget _fallback() => errorWidget ?? const SizedBox.shrink();
}
