import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models/image_data.dart';
import '../controllers/permission_controller.dart';
import '../data/services/file_service.dart';
import '../utils/app_logger.dart';
import '../utils/marked_media_renderer.dart';

class ReportController extends GetxController {
  ReportController({Future<Directory> Function()? appDocumentsDirectory})
      : _appDocumentsDirectory =
            appDocumentsDirectory ?? getApplicationDocumentsDirectory;

  final RxBool isSaving = false.obs;
  final RxBool isDownloading = false.obs;
  final Future<Directory> Function() _appDocumentsDirectory;

  PermissionController? get _permissionController {
    if (!Get.isRegistered<PermissionController>()) return null;
    return Get.find<PermissionController>();
  }

  Future<bool> saveReport({
    required Uint8List bytes,
    required String filename,
    required String folderName,
    String? folderLabel,
    required void Function(String message, Color color) showMessage,
    void Function(String message, double progress)? onProgress,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      if (kIsWeb) {
        // In-browser storage is [MediaDatabase] + folder list (see report page).
        showMessage('Saved report to ${_label(folderLabel ?? folderName)}',
            Colors.green);
        return true;
      }
      onProgress?.call(
          'Saving report to ${_label(folderLabel ?? folderName)}', 0.2);
      await _saveToAppFolderOnly(
        bytes,
        filename: filename,
        folderName: folderName,
        onProgress: (p) => onProgress?.call(
          'Saving report to ${_label(folderLabel ?? folderName)}',
          0.2 + (p * 0.8),
        ),
      );
      showMessage(
          'Saved report to ${_label(folderLabel ?? folderName)}', Colors.green);
      return true;
    } catch (e) {
      logDebug('Save report failed: $e');
      showMessage(
          'Failed to save report to ${_label(folderLabel ?? folderName)}',
          Colors.red);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<Uint8List> prepareMediaBytes({
    required ImageData image,
    required Uint8List baseBytes,
  }) async {
    if (image.annotations.isEmpty || image.isMarkingsBaked == true) {
      return baseBytes;
    }
    return MarkedMediaRenderer.renderPhotoWithAnnotations(
      baseImageBytes: baseBytes,
      annotations: image.annotations,
      mirrorX: image.mirrored ?? false,
      mirrorY: false,
      rotation: image.rotation ?? 0,
      annotationSourceSize: (image.sourceWidth != null &&
              image.sourceHeight != null &&
              image.sourceWidth! > 0 &&
              image.sourceHeight! > 0)
          ? Size(image.sourceWidth!, image.sourceHeight!)
          : null,
    );
  }

  Future<bool> downloadReport({
    required Uint8List bytes,
    required String filename,
    required String folderName,
    String? folderLabel,
    Rect? sharePositionOrigin,
    required void Function(String message, Color color) showMessage,
    void Function(String message, double progress)? onProgress,
  }) async {
    if (isDownloading.value) return false;
    isDownloading.value = true;
    logDebug(
      'ReportController.downloadReport start filename=$filename folder=$folderName bytes=${bytes.length}',
    );
    try {
      if (kIsWeb) {
        logDebug('ReportController.downloadReport web branch');
        onProgress?.call('Downloading report...', 0.4);
        await FileService.savePdfToDevice(bytes, filename);
        onProgress?.call('Downloading report...', 1.0);
        logDebug('ReportController.downloadReport web download done');
        showMessage('Report downloaded to Downloads', Colors.green);
        return true;
      }
      logDebug('ReportController.downloadReport native app-folder save start');
      onProgress?.call('Saving report to app folder...', 0.18);
      await _saveToAppFolderOnly(
        bytes,
        filename: filename,
        folderName: folderName,
        onProgress: (p) => onProgress?.call(
          'Saving report to app folder...',
          0.18 + (p * 0.12),
        ),
      );
      logDebug('ReportController.downloadReport native app-folder save done');
      if (Platform.isIOS) {
        // Mirror Android: persist a user-visible copy under app Documents/Downloads
        // (Files → On My iPhone → Hexa Cam → Downloads/…), then offer share as fallback.
        const reportFolder = 'Hexa Cam Reports';
        try {
          logDebug('ReportController.downloadReport iOS saveToDownloads start');
          onProgress?.call('Saving report to Downloads…', 0.35);
          final downloadPath = await FileService.saveToDownloads(
            bytes: bytes,
            filename: filename,
            folderName: reportFolder,
            onProgress: (p) => onProgress?.call(
              'Saving report to Downloads…',
              0.35 + (p * 0.45),
            ),
          );
          if (downloadPath.isNotEmpty) {
            onProgress?.call('Report saved', 0.88);
            showMessage(
              'Report saved to Files → Downloads/$reportFolder',
              Colors.green,
            );
          }
        } catch (e) {
          logDebug(
              'ReportController.downloadReport iOS saveToDownloads failed: $e');
          showMessage(
            'Could not copy to Downloads folder; try Share below.',
            Colors.orange,
          );
        }
        try {
          logDebug('ReportController.downloadReport iOS share start');
          onProgress?.call('Opening share sheet…', 0.92);
          await FileService.sharePdfToDevice(
            bytes,
            filename,
            sharePositionOrigin: sharePositionOrigin,
          );
        } catch (_) {
          logDebug(
              'ReportController.downloadReport iOS share retry without anchor');
          onProgress?.call('Retrying share…', 0.96);
          await FileService.sharePdfToDevice(
            bytes,
            filename,
            sharePositionOrigin: null,
          );
        }
        onProgress?.call('Done', 1.0);
        logDebug('ReportController.downloadReport iOS done');
        return true;
      }
      logDebug('ReportController.downloadReport Android/public download start');
      onProgress?.call('Preparing report download...', 0.2);
      final permissionController = _permissionController;
      final permissionOk = permissionController == null
          ? true
          : await permissionController.requestStoragePermissionIfNeeded();
      if (!permissionOk) {
        showMessage(
            'Failed to download report: storage permission denied', Colors.red);
        return false;
      }
      const reportFolder = 'Hexa Cam Reports';
      onProgress?.call('Downloading report to Downloads/$reportFolder', 0.35);
      String downloadPath = '';
      if (permissionOk) {
        downloadPath = await FileService.saveToDownloads(
          bytes: bytes,
          filename: filename,
          folderName: reportFolder,
          onProgress: (p) => onProgress?.call(
            'Downloading report to Downloads/$reportFolder',
            0.35 + (p * 0.65),
          ),
        );
      }
      if (downloadPath.isEmpty) {
        logDebug('ReportController.downloadReport public download path empty');
        showMessage(
          'Failed to download to public storage. Report is still saved in app folder.',
          Colors.red,
        );
        return false;
      }
      logDebug(
          'ReportController.downloadReport public download done path=$downloadPath');
      final normalizedPath = downloadPath.replaceAll('\\', '/');
      if (normalizedPath.contains('/Download/')) {
        showMessage(
            'Report downloaded to Downloads/Hexa Cam Reports', Colors.green);
      } else {
        final folderPath = p.dirname(downloadPath).replaceAll('\\', '/');
        showMessage(
          'Report downloaded to fallback folder: $folderPath',
          Colors.green,
        );
      }
      return true;
    } catch (e) {
      logDebug('Download report failed: $e');
      showMessage('Failed to download report', Colors.red);
      return false;
    } finally {
      isDownloading.value = false;
    }
  }

  Future<String> _saveToAppFolderOnly(
    Uint8List bytes, {
    String? filename,
    required String folderName,
    void Function(double progress)? onProgress,
  }) async {
    // Web builds do not support application-documents directory plugin channels.
    // Caller paths should already guard with kIsWeb, but keep this as a hard safety net.
    if (kIsWeb) {
      onProgress?.call(1.0);
      return filename ?? 'report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
    final dir = await _appDocumentsDirectory();
    final name =
        filename ?? 'report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final safeName = p.basename(name);
    final reportsDir = Directory(p.join(dir.path, 'reports', folderName));
    await reportsDir.create(recursive: true);
    final temp = File(p.join(reportsDir.path, '.$safeName.tmp'));
    await temp.writeAsBytes(bytes, flush: true);
    onProgress?.call(1.0);
    final dest = await _uniqueAppDestination(reportsDir, safeName);
    return temp.rename(dest.path).then((file) => file.path);
  }

  String _label(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'App Folder';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  Future<File> _uniqueAppDestination(Directory dir, String safeName) async {
    final base = p.basenameWithoutExtension(safeName);
    final ext = p.extension(safeName);
    var candidate = File(p.join(dir.path, safeName));
    var index = 1;
    while (await candidate.exists()) {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      candidate = File(p.join(dir.path, '${base}_$stamp$index$ext'));
      index++;
    }
    return candidate;
  }
}
