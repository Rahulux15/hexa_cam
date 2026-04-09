import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';

import '../../data/models/annotation.dart';
import '../../utils/marked_media_renderer.dart';

/// Video burn / thumbnail FFmpeg work runs via **platform channels** on the
/// main isolate. A Dart [Isolate] cannot host `ffmpeg_kit` without a separate
/// helper process; use UI-level progress (e.g. loading overlays) for long jobs.
class VideoExportService {
  static Future<Uint8List?> extractVideoThumbnailBytes({
    required String sourcePath,
    int timeMs = 120,
  }) async {
    if (kIsWeb) return null;
    final inputPath = sourcePath.startsWith('file://')
        ? sourcePath.replaceFirst('file://', '')
        : sourcePath;
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) return null;

    final tempDir = await getTemporaryDirectory();
    final thumbPath = p.join(
      tempDir.path,
      'thumb-${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final args = <String>[
      '-y',
      '-ss',
      (timeMs / 1000.0).toStringAsFixed(2),
      '-i',
      inputPath,
      '-frames:v',
      '1',
      '-q:v',
      '2',
      thumbPath,
    ];
    final ok = await _runFfmpeg(args);
    if (!ok) return null;
    final thumbFile = File(thumbPath);
    if (!await thumbFile.exists()) return null;
    final bytes = await thumbFile.readAsBytes();
    try {
      await thumbFile.delete();
    } catch (_) {}
    return bytes.isEmpty ? null : bytes;
  }

  static Future<String?> burnAnnotationsIntoVideo({
    required String sourcePath,
    required List<Annotation> annotations,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
    required double sourceWidth,
    required double sourceHeight,
    required String outputFilename,
  }) async {
    if (kIsWeb) return null;
    if (annotations.isEmpty) return sourcePath;

    final inputPath = sourcePath.startsWith('file://')
        ? sourcePath.replaceFirst('file://', '')
        : sourcePath;
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) return null;

    final tempDir = await getTemporaryDirectory();
    final overlaySize = _resolveOverlaySize(
      annotations: annotations,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    final overlayBytes = await _buildTransparentOverlay(
      sourceWidth: overlaySize.$1,
      sourceHeight: overlaySize.$2,
      annotations: annotations,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
    );
    final overlayPath = p.join(
      tempDir.path,
      'overlay-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await File(overlayPath).writeAsBytes(overlayBytes, flush: true);

    final outputPath = p.join(
      tempDir.path,
      _safeOutputName(outputFilename),
    );

    final baseArgs = <String>[
      '-y',
      '-i',
      inputPath,
      '-i',
      overlayPath,
      '-filter_complex',
      '[1:v][0:v]scale2ref[ov][base];[base][ov]overlay=0:0:format=auto[v]',
      '-map',
      '[v]',
      '-c:v',
      'libx264',
      '-preset',
      'slow',
      '-crf',
      '14',
      '-pix_fmt',
      'yuv420p',
    ];

    final argsCopyAudio = <String>[
      ...baseArgs,
      '-map',
      '0:a?',
      '-c:a',
      'copy',
      outputPath,
    ];
    if (await _runFfmpeg(argsCopyAudio)) return outputPath;

    final argsAacAudio = <String>[
      ...baseArgs,
      '-map',
      '0:a?',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      outputPath,
    ];
    if (await _runFfmpeg(argsAacAudio)) return outputPath;

    final argsNoAudio = <String>[
      ...baseArgs,
      '-an',
      outputPath,
    ];
    if (await _runFfmpeg(argsNoAudio)) return outputPath;

    // Device fallback: some builds fail libx264; try MPEG-4 encoder.
    final mpeg4BaseArgs = <String>[
      '-y',
      '-i',
      inputPath,
      '-i',
      overlayPath,
      '-filter_complex',
      '[1:v][0:v]scale2ref[ov][base];[base][ov]overlay=0:0:format=auto[v]',
      '-map',
      '[v]',
      '-c:v',
      'mpeg4',
      '-q:v',
      '2',
      '-pix_fmt',
      'yuv420p',
    ];
    final mpeg4WithAudio = <String>[
      ...mpeg4BaseArgs,
      '-map',
      '0:a?',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      outputPath,
    ];
    if (await _runFfmpeg(mpeg4WithAudio)) return outputPath;

    final mpeg4NoAudio = <String>[
      ...mpeg4BaseArgs,
      '-an',
      outputPath,
    ];
    if (await _runFfmpeg(mpeg4NoAudio)) return outputPath;

    return null;
  }

  static (double, double) _resolveOverlaySize({
    required List<Annotation> annotations,
    required double sourceWidth,
    required double sourceHeight,
  }) {
    var maxX = 0.0;
    var maxY = 0.0;
    for (final annotation in annotations) {
      for (final point in annotation.points) {
        if (point.x > maxX) maxX = point.x;
        if (point.y > maxY) maxY = point.y;
      }
    }
    // Keep extra headroom for text labels and stroke thickness.
    final safeW = (maxX + 48).clamp(1, 8192).toDouble();
    final safeH = (maxY + 48).clamp(1, 8192).toDouble();
    final resolvedW = sourceWidth > 0 ? sourceWidth : safeW;
    final resolvedH = sourceHeight > 0 ? sourceHeight : safeH;
    return (
      resolvedW < safeW ? safeW : resolvedW,
      resolvedH < safeH ? safeH : resolvedH,
    );
  }

  static Future<Uint8List> _buildTransparentOverlay({
    required double sourceWidth,
    required double sourceHeight,
    required List<Annotation> annotations,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
  }) async {
    return MarkedMediaRenderer.renderAnnotationOverlay(
      sourceSize: Size(
        sourceWidth,
        sourceHeight,
      ),
      annotations: annotations,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
    );
  }

  static String _safeOutputName(String filename) {
    final cleaned = filename.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-');
    return cleaned.endsWith('.mp4') ? cleaned : '$cleaned.mp4';
  }

  static Future<bool> _runFfmpeg(List<String> args) async {
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    if (returnCode == null) return false;
    return ReturnCode.isSuccess(returnCode);
  }
}
