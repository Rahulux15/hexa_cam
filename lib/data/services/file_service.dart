import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../utils/app_logger.dart';
import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';

class FileService {
  static const _uuid = Uuid();
  static const _startupPermissionKey = 'storage_permissions_requested';

  /// UUID v4 from package:uuid — collision risk is negligible for app-scale IDs.
  static String generateAssetId([String prefix = 'media']) =>
      '$prefix-${_uuid.v4()}';

  /// Returns true when the image was written directly (web download, Android/iOS
  /// gallery/Photos). On iOS, false means the share sheet was used as fallback.
  static Future<bool> saveToDevice(
    Uint8List bytes,
    String filename, {
    Rect? sharePositionOrigin,
  }) async {
    logDebug('FileService.saveToDevice start filename=$filename bytes=${bytes.length}');
    if (kIsWeb) {
      final name = _safeFilename(filename, fallbackExtension: '.jpg');
      logDebug('FileService.saveToDevice web download name=$name');
      await downloadBytesWeb(bytes, name, mimeType: 'image/jpeg');
      logDebug('FileService.saveToDevice web download done');
      return true;
    }
    if (Platform.isIOS) {
      // Match Android: save into Photos when allowed; share sheet as fallback.
      try {
        if (!await Gal.hasAccess(toAlbum: true)) {
          await Gal.requestAccess(toAlbum: true);
        }
        if (await Gal.hasAccess(toAlbum: true)) {
          final name = _galAssetBaseName(filename);
          await Gal.putImageBytes(
            bytes,
            album: 'Hexa Cam',
            name: name,
          );
          logDebug('FileService.saveToDevice iOS Photos (Gal) name=$name');
          return true;
        }
      } catch (e) {
        logDebug('FileService.saveToDevice iOS Gal failed, using share: $e');
      }
      logDebug('FileService.saveToDevice iOS share fallback filename=$filename');
      await shareImageToDevice(
        bytes,
        filename,
        sharePositionOrigin: sharePositionOrigin,
      );
      logDebug('FileService.saveToDevice iOS share flow done');
      return false;
    }
    final sanitized = filename
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-')
        .trim();
    final name = sanitized.isEmpty
        ? 'hexacam-${DateTime.now().millisecondsSinceEpoch}'
        : sanitized;
    logDebug('FileService.saveToDevice gallery write name=$name');
    await Gal.putImageBytes(bytes, name: name);
    logDebug('FileService.saveToDevice gallery write done');
    return true;
  }

  static Future<void> savePdfToDevice(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      final name = _safeFilename(filename, fallbackExtension: '.pdf');
      await downloadBytesWeb(bytes, name, mimeType: 'application/pdf');
      return;
    }
    await saveToAppFolder(
      bytes: bytes,
      filename: filename,
      folderName: 'reports',
    );
  }

  static Future<void> sharePdfToDevice(
    Uint8List bytes,
    String filename, {
    Rect? sharePositionOrigin,
  }) async {
    if (kIsWeb) {
      final name = _safeFilename(filename, fallbackExtension: '.pdf');
      await downloadBytesWeb(bytes, name, mimeType: 'application/pdf');
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final safeName = _safeFilename(filename, fallbackExtension: '.pdf');
    final tempPath = p.join(
      tempDir.path,
      'share-${DateTime.now().millisecondsSinceEpoch}-$safeName',
    );
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: 'application/pdf')],
          title: safeName,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (_) {
      // iOS fallback for popover-origin failures.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: 'application/pdf')],
          title: safeName,
        ),
      );
    }
  }

  /// Returns true when the video was saved straight into gallery/Photos; false
  /// when iOS fell back to the share sheet.
  static Future<bool> saveVideoToDevice(
    String videoPath,
    String filename, {
    Rect? sharePositionOrigin,
  }) async {
    logDebug('FileService.saveVideoToDevice start filename=$filename path=$videoPath');
    if (kIsWeb) {
      logDebug('FileService.saveVideoToDevice skipped on web');
      return false;
    }
    if (Platform.isIOS) {
      try {
        if (!await Gal.hasAccess(toAlbum: true)) {
          await Gal.requestAccess(toAlbum: true);
        }
        if (await Gal.hasAccess(toAlbum: true)) {
          await Gal.putVideo(videoPath, album: 'Hexa Cam');
          logDebug('FileService.saveVideoToDevice iOS Photos (Gal) path=$videoPath');
          return true;
        }
      } catch (e) {
        logDebug('FileService.saveVideoToDevice iOS Gal failed, using share: $e');
      }
      logDebug('FileService.saveVideoToDevice iOS share flow filename=$filename');
      await shareVideoToDevice(
        videoPath,
        filename,
        sharePositionOrigin: sharePositionOrigin,
      );
      logDebug('FileService.saveVideoToDevice iOS share flow done');
      return false;
    }
    logDebug('FileService.saveVideoToDevice gallery write path=$videoPath');
    await Gal.putVideo(videoPath);
    logDebug('FileService.saveVideoToDevice gallery write done');
    return true;
  }

  static Future<void> shareImageToDevice(
    Uint8List bytes,
    String filename, {
    Rect? sharePositionOrigin,
  }) async {
    if (kIsWeb) {
      final name = _safeFilename(filename, fallbackExtension: '.jpg');
      await downloadBytesWeb(bytes, name, mimeType: 'image/jpeg');
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final safeName = _safeFilename(filename, fallbackExtension: '.jpg');
    final tempPath = p.join(
      tempDir.path,
      'share-${DateTime.now().millisecondsSinceEpoch}-$safeName',
    );
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);
    try {
      logDebug('FileService.shareImageToDevice share anchored path=$tempPath');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: 'image/jpeg')],
          title: safeName,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      logDebug('FileService.shareImageToDevice share anchored done');
    } catch (_) {
      // iOS fallback for popover-origin failures.
      logDebug('FileService.shareImageToDevice fallback share path=$tempPath');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: 'image/jpeg')],
          title: safeName,
        ),
      );
      logDebug('FileService.shareImageToDevice fallback share done');
    }
  }

  static Future<void> shareVideoToDevice(
    String videoPath,
    String filename, {
    Rect? sharePositionOrigin,
  }) async {
    if (kIsWeb) {
      return;
    }
    final safeName = _safeFilename(filename, fallbackExtension: '.mp4');
    final tempDir = await getTemporaryDirectory();
    final source = File(videoPath);
    final safePath = p.join(
      tempDir.path,
      'share-${DateTime.now().millisecondsSinceEpoch}-$safeName',
    );
    final shareFile = await source.copy(safePath);
    try {
      logDebug('FileService.shareVideoToDevice share anchored path=${shareFile.path}');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(shareFile.path, mimeType: 'video/mp4')],
          title: safeName,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      logDebug('FileService.shareVideoToDevice share anchored done');
    } catch (_) {
      // iOS fallback for popover-origin failures.
      logDebug('FileService.shareVideoToDevice fallback share path=${shareFile.path}');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(shareFile.path, mimeType: 'video/mp4')],
          title: safeName,
        ),
      );
      logDebug('FileService.shareVideoToDevice fallback share done');
    }
  }

  static Future<String> getTempPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  static Future<String> persistCapture({
    required String sourcePath,
    required String filename,
    required String folderName,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docs.path, 'captures', folderName));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final safeName = _safeFilename(
      filename,
      fallbackExtension: p.extension(sourcePath),
    );
    final destination = p.join(mediaDir.path, safeName);
    final file = await File(sourcePath).copy(destination);
    return _normalizePath(file.path);
  }

  static Future<String> persistBytes({
    required Uint8List bytes,
    required String filename,
    required String folderName,
    String subdirectory = 'reports',
    bool preferDownloads = true,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      final name = _safeFilename(filename, fallbackExtension: '.pdf');
      await downloadBytesWeb(bytes, name, mimeType: 'application/pdf');
      return name;
    }
    final safeName = _safeFilename(filename);
    final mediaDir = await _resolveTargetDirectory(
      folderName: folderName,
      subdirectory: subdirectory,
      preferDownloads: preferDownloads,
    );
    final destination = await _uniqueDestination(mediaDir, safeName);
    final file = await _atomicWriteBytes(
      destination,
      bytes,
      onProgress: onProgress,
    );
    return _normalizePath(file.path);
  }

  static Future<String> saveToAppFolder({
    required Uint8List bytes,
    required String filename,
    required String folderName,
    String subdirectory = 'reports',
    void Function(double progress)? onProgress,
  }) {
    return persistBytes(
      bytes: bytes,
      filename: filename,
      folderName: folderName,
      subdirectory: subdirectory,
      preferDownloads: false,
      onProgress: onProgress,
    );
  }

  static Future<String> saveToDownloads({
    required Uint8List bytes,
    required String filename,
    required String folderName,
    String subdirectory = 'reports',
    void Function(double progress)? onProgress,
  }) {
    return persistBytes(
      bytes: bytes,
      filename: filename,
      folderName: folderName,
      subdirectory: subdirectory,
      preferDownloads: true,
      onProgress: onProgress,
    );
  }

  static Future<void> requestStoragePermissionsAtStartup({
    required SharedPreferences prefs,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (prefs.getBool(_startupPermissionKey) == true) return;
    await _requestAndroidStoragePermissions();
    await prefs.setBool(_startupPermissionKey, true);
  }

  static Future<void> _requestAndroidStoragePermissions() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    if (deviceInfo.version.sdkInt >= 30) {
      await Permission.manageExternalStorage.request();
      return;
    }
    await Permission.storage.request();
  }

  static Future<Directory> _resolveTargetDirectory({
    required String folderName,
    required String subdirectory,
    required bool preferDownloads,
  }) async {
    if (!preferDownloads) {
      final docs = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(docs.path, subdirectory, folderName));
      await mediaDir.create(recursive: true);
      return mediaDir;
    }
    if (Platform.isAndroid) {
      final preferred = Directory('/storage/emulated/0/Download');
      if (await _ensureVisibleDirectory(preferred)) {
        final target = Directory(p.join(preferred.path, folderName));
        await target.create(recursive: true);
        return target;
      }
      final fallback = Directory('/storage/emulated/0/MyAppDownloads');
      if (await _ensureVisibleDirectory(fallback)) {
        final target = Directory(p.join(fallback.path, folderName));
        await target.create(recursive: true);
        return target;
      }
    } else if (Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      final preferred = Directory(p.join(docs.path, 'Downloads'));
      if (await _ensureVisibleDirectory(preferred)) {
        final target = Directory(p.join(preferred.path, folderName));
        await target.create(recursive: true);
        return target;
      }
      final fallback = Directory(p.join(docs.path, 'MyAppDownloads'));
      if (await _ensureVisibleDirectory(fallback)) {
        final target = Directory(p.join(fallback.path, folderName));
        await target.create(recursive: true);
        return target;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docs.path, subdirectory, folderName));
    await mediaDir.create(recursive: true);
    return mediaDir;
  }

  static Future<File> _atomicWriteBytes(
    String destination,
    Uint8List bytes,
    {void Function(double progress)? onProgress}
  ) async {
    final target = File(destination);
    final temp = File('$destination.tmp');
    final sink = temp.openWrite();
    const chunkSize = 256 * 1024;
    final total = bytes.length;
    if (total == 0) {
      onProgress?.call(1.0);
    } else {
      var offset = 0;
      while (offset < total) {
        final end = (offset + chunkSize).clamp(0, total);
        sink.add(bytes.sublist(offset, end));
        offset = end;
        onProgress?.call(offset / total);
      }
    }
    await sink.flush();
    await sink.close();
    if (await target.exists()) {
      await target.delete();
    }
    return temp.rename(target.path);
  }

  static Future<String> _uniqueDestination(
    Directory directory,
    String safeName,
  ) async {
    final base = p.basenameWithoutExtension(safeName);
    final ext = p.extension(safeName);
    var candidate = p.join(directory.path, safeName);
    var index = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(
        directory.path,
        '$base-${DateTime.now().millisecondsSinceEpoch}-$index$ext',
      );
      index++;
    }
    return candidate;
  }

  static Future<bool> _ensureVisibleDirectory(Directory directory) async {
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return await directory.exists();
    } catch (_) {
      return false;
    }
  }

  static String buildPublicDownloadPath({
    required String filename,
    required String downloadsRoot,
  }) => _normalizePath(p.join(downloadsRoot, _safeFilename(filename)));

  static String buildFallbackDownloadPath({
    required String filename,
    required String downloadsRoot,
  }) => _normalizePath(p.join(downloadsRoot, _safeFilename(filename)));

  static Future<Uint8List> readBytes(String path) async {
    return File(path).readAsBytes();
  }

  /// Base name for [Gal.putImageBytes] (no extension; plugin adds type).
  static String _galAssetBaseName(String filename) {
    final safe = _safeFilename(filename, fallbackExtension: '.jpg');
    var base = p.basenameWithoutExtension(safe);
    base = base.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-').trim();
    if (base.isEmpty) {
      return 'hexacam-${DateTime.now().millisecondsSinceEpoch}';
    }
    return base.length > 200 ? base.substring(0, 200) : base;
  }

  static String _safeFilename(String value, {String fallbackExtension = ''}) {
    var cleaned = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-')
        .trim();
    cleaned = cleaned.replaceAll(RegExp(r'-{2,}'), '-');
    if (cleaned.isEmpty) {
      final extension = fallbackExtension.isEmpty ? '' : fallbackExtension;
      return 'hexacam-${DateTime.now().millisecondsSinceEpoch}$extension';
    }
    cleaned = cleaned.replaceAll(RegExp(r'[-_.]+(?=\.[^.]+$)'), '');
    if (p.extension(cleaned).isEmpty && fallbackExtension.isNotEmpty) {
      return '$cleaned$fallbackExtension';
    }
    return cleaned;
  }

  static String _normalizePath(String path) => path.replaceAll('\\', '/');
}
