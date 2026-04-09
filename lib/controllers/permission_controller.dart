import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/common/permission_required_dialog.dart';

class PermissionController extends GetxController {
  PermissionController(this._prefs);

  final SharedPreferences _prefs;
  static const _requestedKey = 'startup_permissions_requested';
  final RxBool isStorageGranted = false.obs;

  /// Runs once on first install (full permission batch), then if anything is
  /// still missing shows [showPermissionRequiredDialog]. On later launches,
  /// skips the automatic batch but still prompts when permissions are missing.
  Future<void> runStartupPermissionFlow() async {
    if (kIsWeb) return;

    final isFirstStartup = _prefs.getBool(_requestedKey) != true;
    if (isFirstStartup) {
      await _requestAllPermissions();
      await _prefs.setBool(_requestedKey, true);
    }

    await _showPermissionDialogIfNeeded();
  }

  /// Re-run the same startup batch (used by "Try Again" and can be called from UI).
  Future<void> requestAllPermissionsAgain() async {
    if (kIsWeb) return;
    await _requestAllPermissions();
  }

  Future<void> _requestAllPermissions() async {
    if (Platform.isAndroid) {
      await _androidStartupPermissions();
    } else if (Platform.isIOS) {
      await _iosStartupPermissions();
    }
  }

  Future<void> _androidStartupPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    final manage = await Permission.manageExternalStorage.request();
    final storage = await Permission.storage.request();
    isStorageGranted.value = manage.isGranted || storage.isGranted;
    await Permission.photos.request();
    await Permission.videos.request();
  }

  Future<void> _iosStartupPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.photos.request();
    await Permission.photosAddOnly.request();
  }

  Future<void> _showPermissionDialogIfNeeded() async {
    if (await hasAllRequiredPermissions()) return;
    if (Get.isDialogOpen == true) return;
    showPermissionRequiredDialog(onTryAgain: _onPermissionTryAgain);
  }

  Future<void> _onPermissionTryAgain() async {
    if (Get.isDialogOpen == true) {
      Get.back<void>();
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _requestAllPermissions();

    if (await hasAllRequiredPermissions()) {
      return;
    }

    if (await anyRequiredPermissionPermanentlyDenied()) {
      await openAppSettings();
      await Future<void>.delayed(const Duration(milliseconds: 320));
    }

    if (!await hasAllRequiredPermissions()) {
      await _showPermissionDialogIfNeeded();
    }
  }

  static bool _statusOk(PermissionStatus s) =>
      s.isGranted || s.isLimited || s.isProvisional;

  /// Whether the app has every permission needed for camera / gallery flows.
  Future<bool> hasAllRequiredPermissions() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      final cam = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      final photos = await Permission.photos.status;
      final videos = await Permission.videos.status;
      final manage = await Permission.manageExternalStorage.status;
      final storage = await Permission.storage.status;
      final storageOk = _statusOk(manage) || _statusOk(storage);
      return _statusOk(cam) &&
          _statusOk(mic) &&
          _statusOk(photos) &&
          _statusOk(videos) &&
          storageOk;
    }
    if (Platform.isIOS) {
      final cam = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      final photos = await Permission.photos.status;
      final addOnly = await Permission.photosAddOnly.status;
      final photosOk = _statusOk(photos) || _statusOk(addOnly);
      return _statusOk(cam) && _statusOk(mic) && photosOk;
    }
    return true;
  }

  Future<bool> anyRequiredPermissionPermanentlyDenied() async {
    if (kIsWeb) return false;
    final statuses = await _collectPermissionStatuses();
    return statuses.any((s) => s.isPermanentlyDenied);
  }

  Future<List<PermissionStatus>> _collectPermissionStatuses() async {
    if (Platform.isAndroid) {
      return [
        await Permission.camera.status,
        await Permission.microphone.status,
        await Permission.photos.status,
        await Permission.videos.status,
        await Permission.manageExternalStorage.status,
        await Permission.storage.status,
      ];
    }
    if (Platform.isIOS) {
      return [
        await Permission.camera.status,
        await Permission.microphone.status,
        await Permission.photos.status,
        await Permission.photosAddOnly.status,
      ];
    }
    return [];
  }

  Future<bool> requestStoragePermissionIfNeeded() async {
    if (kIsWeb || !Platform.isAndroid) {
      isStorageGranted.value = true;
      return true;
    }
    if (isStorageGranted.value) return true;
    final manage = await Permission.manageExternalStorage.request();
    final storage = await Permission.storage.request();
    isStorageGranted.value = manage.isGranted || storage.isGranted;
    return isStorageGranted.value;
  }
}
