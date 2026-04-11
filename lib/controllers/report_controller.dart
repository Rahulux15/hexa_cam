import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart' show ShareResult, ShareResultStatus;
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
    // Video reports use extracted still thumbnails. Those are produced in
    // capture/viewer flows and may already include markings; avoid reburn.
    if (image.type == MediaType.video) {
      return baseBytes;
    }
    if (image.annotations.isEmpty || image.isMarkingsBaked == true) {
      return baseBytes;
    }
    try {
      final safeDecodeEdge = Platform.isIOS ? 2600 : null;
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
        maxDecodeEdge: safeDecodeEdge,
      );
    } catch (e) {
      logDebug('ReportController.prepareMediaBytes fallback to base image: $e');
      return baseBytes;
    }
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
      if (Platform.isIOS) {
        // iOS: system share sheet (Save to Files, AirDrop, …). [ShareResult]
        // tells us if the user dismissed without acting — avoid fake "saved".
        onProgress?.call('Preparing PDF…', 0.25);
        ShareResult shareResult = ShareResult.unavailable;
        try {
          logDebug('ReportController.downloadReport iOS share start');
          onProgress?.call('Opening share sheet…', 0.55);
          shareResult = await FileService.sharePdfToDevice(
            bytes,
            filename,
            sharePositionOrigin: sharePositionOrigin,
          );
        } catch (_) {
          logDebug(
              'ReportController.downloadReport iOS share retry without anchor');
          onProgress?.call('Retrying share…', 0.85);
          shareResult = await FileService.sharePdfToDevice(
            bytes,
            filename,
            sharePositionOrigin: null,
          );
        }
        onProgress?.call('Done', 1.0);
        if (shareResult.status == ShareResultStatus.dismissed) {
          showMessage(
            'Share cancelled — PDF not saved outside the app. Report stays in Hexa Cam.',
            Colors.orange,
          );
        } else if (shareResult.status == ShareResultStatus.unavailable) {
          showMessage(
            'Use Save to Files in the share menu if you want a copy in Files',
            Colors.green,
          );
        } else {
          showMessage(
            'In the share menu, choose Save to Files to keep the PDF',
            Colors.green,
          );
        }
        logDebug('ReportController.downloadReport iOS done');
        return true;
      }
      logDebug('ReportController.downloadReport Android/public download start');
      onProgress?.call('Preparing report download...', 0.1);
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
      onProgress?.call('Downloading report to Downloads/$reportFolder', 0.2);
      String downloadPath = '';
      if (permissionOk) {
        downloadPath = await FileService.saveToDownloads(
          bytes: bytes,
          filename: filename,
          folderName: reportFolder,
          onProgress: (p) => onProgress?.call(
            'Downloading report to Downloads/$reportFolder',
            0.2 + (p * 0.8),
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
        // Fallback paths may not be user-visible on all Android variants.
        // Open share so user can explicitly save to Files/Drive/Downloads.
        try {
          await FileService.sharePdfToDevice(
            bytes,
            filename,
            sharePositionOrigin: sharePositionOrigin,
          );
        } catch (_) {
          await FileService.sharePdfToDevice(
            bytes,
            filename,
            sharePositionOrigin: null,
          );
        }
        final folderPath = p.dirname(downloadPath).replaceAll('\\', '/');
        showMessage(
          'Saved to app folder and opened share to save in Downloads/Files: $folderPath',
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
