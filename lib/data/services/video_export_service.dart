import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';

import '../../data/models/annotation.dart';
import '../../utils/marked_media_renderer.dart';

/// Video burn / thumbnail FFmpeg work runs via **platform channels** on the
/// main isolate. A Dart [Isolate] cannot host `ffmpeg_kit` without a separate
/// helper process; use UI-level progress (e.g. loading overlays) for long jobs.
class VideoExportService {
  static final Map<String, Uint8List> _thumbnailCache = <String, Uint8List>{};
  static final Map<String, Future<Uint8List?>> _thumbnailInFlight =
      <String, Future<Uint8List?>>{};
  static const int _maxThumbnailCacheEntries = 24;
  static Future<void> _ffmpegChain = Future<void>.value();

  /// Returns decoded video frame size (after container/orientation handling).
  static Future<Size?> getVideoDimensions(String sourcePath) async {
    if (kIsWeb) return null;
    final inputPath = sourcePath.startsWith('file://')
        ? sourcePath.replaceFirst('file://', '')
        : sourcePath;
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) return null;
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(inputFile);
      await controller.initialize();
      final size = controller.value.size;
      if (size.width <= 0 || size.height <= 0) return null;
      return size;
    } catch (_) {
      return null;
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
    }
  }

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
    final cacheKey = '$inputPath::$timeMs';
    final cached = _thumbnailCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final inFlight = _thumbnailInFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final task = () async {
      final tempDir = await getTemporaryDirectory();
      final candidates = {
        timeMs,
        0,
        250,
        500,
        1000,
      }.toList();
      for (var i = 0; i < candidates.length; i++) {
        final ms = candidates[i];
        final thumbPath = p.join(
          tempDir.path,
          'thumb-${DateTime.now().millisecondsSinceEpoch}-$i.jpg',
        );
        final args = <String>[
          '-y',
          '-ss',
          (ms / 1000.0).toStringAsFixed(2),
          '-i',
          inputPath,
          '-frames:v',
          '1',
          '-q:v',
          '2',
          thumbPath,
        ];
        final ok = await _runFfmpeg(args);
        if (!ok) continue;
        final thumbFile = File(thumbPath);
        if (!await thumbFile.exists()) continue;
        final bytes = await thumbFile.readAsBytes();
        try {
          await thumbFile.delete();
        } catch (_) {}
        if (bytes.isEmpty) continue;
        _thumbnailCache[cacheKey] = bytes;
        if (_thumbnailCache.length > _maxThumbnailCacheEntries) {
          _thumbnailCache.remove(_thumbnailCache.keys.first);
        }
        return bytes;
      }
      return null;
    }();
    _thumbnailInFlight[cacheKey] = task;
    try {
      return await task;
    } finally {
      _thumbnailInFlight.remove(cacheKey);
    }
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

  /// Overlays [assets/images/report_logo.png] on bottom-right (matches still export).
  /// Returns path to a new temp MP4, or null on failure / web.
  static Future<String?> overlayWatermarkOnVideo({
    required String sourceVideoPath,
    required String outputFilename,
  }) async {
    if (kIsWeb) return null;
    final inputPath = sourceVideoPath.startsWith('file://')
        ? sourceVideoPath.replaceFirst('file://', '')
        : sourceVideoPath;
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) return null;

    final logoData = await _loadWatermarkLogoBytes();
    if (logoData == null || logoData.isEmpty) return null;
    final tempDir = await getTemporaryDirectory();
    final logoPath = p.join(
      tempDir.path,
      'wm-logo-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await File(logoPath).writeAsBytes(logoData, flush: true);

    final outputPath =
        p.join(tempDir.path, _safeOutputName('wm-$outputFilename'));

    const filterComplex =
        '[1:v]scale=200:-1[lg];[0:v][lg]overlay=W-w-16:H-h-16:format=auto[outv]';

    final withAudioCopy = <String>[
      '-y',
      '-i',
      inputPath,
      '-i',
      logoPath,
      '-filter_complex',
      filterComplex,
      '-map',
      '[outv]',
      '-map',
      '0:a?',
      '-c:v',
      'libx264',
      '-preset',
      'medium',
      '-crf',
      '18',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'copy',
      outputPath,
    ];
    try {
      if (await _runFfmpeg(withAudioCopy) && await File(outputPath).exists()) {
        return outputPath;
      }

      final withAac = <String>[
        '-y',
        '-i',
        inputPath,
        '-i',
        logoPath,
        '-filter_complex',
        filterComplex,
        '-map',
        '[outv]',
        '-map',
        '0:a?',
        '-c:v',
        'libx264',
        '-preset',
        'medium',
        '-crf',
        '18',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        outputPath,
      ];
      if (await _runFfmpeg(withAac) && await File(outputPath).exists()) {
        return outputPath;
      }

      final noAudio = <String>[
        '-y',
        '-i',
        inputPath,
        '-i',
        logoPath,
        '-filter_complex',
        filterComplex,
        '-map',
        '[outv]',
        '-an',
        '-c:v',
        'libx264',
        '-preset',
        'medium',
        '-crf',
        '18',
        '-pix_fmt',
        'yuv420p',
        outputPath,
      ];
      if (await _runFfmpeg(noAudio) && await File(outputPath).exists()) {
        return outputPath;
      }

      // Fallback on devices where libx264 is unavailable/unstable.
      final mpeg4WithAudio = <String>[
        '-y',
        '-i',
        inputPath,
        '-i',
        logoPath,
        '-filter_complex',
        filterComplex,
        '-map',
        '[outv]',
        '-map',
        '0:a?',
        '-c:v',
        'mpeg4',
        '-q:v',
        '2',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        outputPath,
      ];
      if (await _runFfmpeg(mpeg4WithAudio) && await File(outputPath).exists()) {
        return outputPath;
      }

      final mpeg4NoAudio = <String>[
        '-y',
        '-i',
        inputPath,
        '-i',
        logoPath,
        '-filter_complex',
        filterComplex,
        '-map',
        '[outv]',
        '-an',
        '-c:v',
        'mpeg4',
        '-q:v',
        '2',
        '-pix_fmt',
        'yuv420p',
        outputPath,
      ];
      if (await _runFfmpeg(mpeg4NoAudio) && await File(outputPath).exists()) {
        return outputPath;
      }
    } finally {
      try {
        await File(logoPath).delete();
      } catch (_) {}
    }
    return null;
  }

  static Future<Uint8List?> _loadWatermarkLogoBytes() async {
    try {
      final primary = await rootBundle.load('assets/images/report_logo.png');
      final bytes = primary.buffer.asUint8List();
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {}
    try {
      final fallback = await rootBundle.load('assets/images/about_logo.png');
      final bytes = fallback.buffer.asUint8List();
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {}
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
    final completion = Completer<bool>();
    _ffmpegChain = _ffmpegChain.catchError((_) {}).then((_) async {
      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();
      if (returnCode == null) {
        completion.complete(false);
        return;
      }
      completion.complete(ReturnCode.isSuccess(returnCode));
    }).catchError((_) {
      if (!completion.isCompleted) completion.complete(false);
    });
    return completion.future;
  }
}
