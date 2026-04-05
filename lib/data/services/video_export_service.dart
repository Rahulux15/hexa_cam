import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';

import '../../data/models/annotation.dart';
import '../../utils/marked_media_renderer.dart';

class VideoExportService {
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
    final overlayBytes = await _buildTransparentOverlay(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
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

    final command = [
      '-y',
      '-i',
      _escapePath(inputPath),
      '-i',
      _escapePath(overlayPath),
      '-filter_complex',
      '"[0:v]scale=\'min(1280,iw)\':-2:flags=lanczos[base];[base][1:v]overlay=0:0:format=auto[v]"',
      '-map',
      '"[v]"',
      '-map',
      '0:a?',
      '-c:v',
      'libx264',
      '-preset',
      'medium',
      '-crf',
      '23',
      '-c:a',
      'copy',
      _escapePath(outputPath),
    ].join(' ');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (returnCode == null || !ReturnCode.isSuccess(returnCode)) {
      return null;
    }
    return outputPath;
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

  static String _escapePath(String input) {
    if (input.contains(' ')) return '"$input"';
    return input;
  }
}
