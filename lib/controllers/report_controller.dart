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
    required void Function(String message, Color color) showMessage,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      if (kIsWeb) {
        // In-browser storage is [MediaDatabase] + folder list (see report page).
        showMessage('Report saved to app library', Colors.green);
        return true;
      }
      await _saveToAppFolderOnly(
        bytes,
        filename: filename,
        folderName: folderName,
      );
      showMessage('Report saved to App Folder', Colors.green);
      return true;
    } catch (e) {
      logDebug('Save report failed: $e');
      showMessage('Unable to save report', Colors.red);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<Uint8List> prepareMediaBytes({
    required ImageData image,
    required Uint8List baseBytes,
  }) async {
    if (image.isMarkingsBaked == true || image.annotations.isEmpty) {
      return baseBytes;
    }
    return MarkedMediaRenderer.renderPhotoWithAnnotations(
      baseImageBytes: baseBytes,
      annotations: image.annotations,
      mirrorX: image.mirrored ?? false,
      mirrorY: false,
      rotation: image.rotation ?? 0,
    );
  }

  Future<bool> downloadReport({
    required Uint8List bytes,
    required String filename,
    required String folderName,
    required void Function(String message, Color color) showMessage,
  }) async {
    if (isDownloading.value) return false;
    isDownloading.value = true;
    try {
      if (kIsWeb) {
        await FileService.savePdfToDevice(bytes, filename);
        showMessage(
          'Report downloaded; copy kept in app library',
          Colors.green,
        );
        return true;
      }
      final appOk = await FileService.saveToAppFolder(
        bytes: bytes,
        filename: filename,
        folderName: folderName,
      );
      var downloadOk = false;
      final permissionController = _permissionController;
      final permissionOk = permissionController == null
          ? true
          : await permissionController.requestStoragePermissionIfNeeded();
      if (permissionOk) {
        final downloadPath = await FileService.saveToDownloads(
          bytes: bytes,
          filename: filename,
          folderName: folderName,
        );
        downloadOk = downloadPath.isNotEmpty;
      }
      if (appOk.isNotEmpty && downloadOk) {
        showMessage('Report saved to Downloads and App Folder', Colors.green);
        return true;
      }
      if (appOk.isNotEmpty) {
        showMessage('Downloads unavailable. Saved to App Folder only.', Colors.orange);
        return true;
      }
      showMessage('Unable to download report', Colors.red);
      return false;
    } catch (e) {
      logDebug('Download report failed: $e');
      showMessage('Unable to download report', Colors.red);
      return false;
    } finally {
      isDownloading.value = false;
    }
  }

  Future<String> _saveToAppFolderOnly(
    Uint8List bytes, {
    String? filename,
    required String folderName,
  }) async {
    final dir = await _appDocumentsDirectory();
    final name = filename ?? 'report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final safeName = p.basename(name);
    final reportsDir = Directory(p.join(dir.path, 'reports', folderName));
    await reportsDir.create(recursive: true);
    final temp = File(p.join(reportsDir.path, '.$safeName.tmp'));
    await temp.writeAsBytes(bytes, flush: true);
    final dest = await _uniqueAppDestination(reportsDir, safeName);
    return temp.rename(dest.path).then((file) => file.path);
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
