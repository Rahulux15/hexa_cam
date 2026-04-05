import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

class FileService {
  static const _uuid = Uuid();
  static const _startupPermissionKey = 'storage_permissions_requested';

  static String generateAssetId([String prefix = 'media']) =>
      '$prefix-${_uuid.v4()}';

  static Future<void> saveToDevice(Uint8List bytes, String filename) async {
    final sanitized =
        filename.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-').trim();
    final name = sanitized.isEmpty
        ? 'hexacam-${DateTime.now().millisecondsSinceEpoch}'
        : sanitized;
    await Gal.putImageBytes(bytes, name: name);
  }

  static Future<void> saveVideoToDevice(
      String videoPath, String filename) async {
    await Gal.putVideo(videoPath);
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

    final safeName =
        _safeFilename(filename, fallbackExtension: p.extension(sourcePath));
    final destination = p.join(mediaDir.path, safeName);
    final file = await File(sourcePath).copy(destination);
    return file.path;
  }

  static Future<String> persistBytes({
    required Uint8List bytes,
    required String filename,
    required String folderName,
    String subdirectory = 'reports',
    bool preferDownloads = true,
  }) async {
    final safeName = _safeFilename(filename);
    final mediaDir = await _resolveTargetDirectory(
      folderName: folderName,
      subdirectory: subdirectory,
      preferDownloads: preferDownloads,
    );
    final destination = p.join(mediaDir.path, safeName);
    final file = File(destination);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
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
        return Directory(p.join(preferred.path, folderName));
      }
      final fallback = Directory('/storage/emulated/0/MyAppDownloads');
      if (await _ensureVisibleDirectory(fallback)) {
        return Directory(p.join(fallback.path, folderName));
      }
    } else if (Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      final preferred = Directory(p.join(docs.path, 'Downloads'));
      if (await _ensureVisibleDirectory(preferred)) {
        return Directory(p.join(preferred.path, folderName));
      }
      final fallback = Directory(p.join(docs.path, 'MyAppDownloads'));
      if (await _ensureVisibleDirectory(fallback)) {
        return Directory(p.join(fallback.path, folderName));
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docs.path, subdirectory, folderName));
    await mediaDir.create(recursive: true);
    return mediaDir;
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
  }) =>
      p.join(downloadsRoot, _safeFilename(filename));

  static String buildFallbackDownloadPath({
    required String filename,
    required String downloadsRoot,
  }) =>
      p.join(downloadsRoot, _safeFilename(filename));

  static Future<Uint8List> readBytes(String path) async {
    return File(path).readAsBytes();
  }

  static String _safeFilename(String value, {String fallbackExtension = ''}) {
    final cleaned =
        value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-').trim();
    if (cleaned.isEmpty) {
      final extension = fallbackExtension.isEmpty ? '' : fallbackExtension;
      return 'hexacam-${DateTime.now().millisecondsSinceEpoch}$extension';
    }
    if (p.extension(cleaned).isEmpty && fallbackExtension.isNotEmpty) {
      return '$cleaned$fallbackExtension';
    }
    return cleaned;
  }
}
