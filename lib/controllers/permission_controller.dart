import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/common/permission_required_dialog.dart';
import '../utils/app_logger.dart';

class PermissionController extends GetxController {
  PermissionController(this._prefs);

  final SharedPreferences _prefs;
  static const _requestedKey = 'startup_permissions_requested';
  static const _retryCountKey = 'permission_retry_count';
  final RxBool isStorageGranted = false.obs;
  bool _permissionDialogScheduled = false;
  int _retryCount = 0;

  /// Runs once on first install (full permission batch), then if anything is
  /// still missing shows [showPermissionRequiredDialog]. On later launches,
  /// skips the automatic batch but still prompts when permissions are missing.
  Future<void> runStartupPermissionFlow() async {
    if (kIsWeb) return;

    _retryCount = _prefs.getInt(_retryCountKey) ?? 0;
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
    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    await Permission.camera.request();
    await Permission.microphone.request();
    final storageOk = await _requestAndroidMediaOrStoragePermission(sdkInt);
    isStorageGranted.value = storageOk;
    logDebug(
      'PermissionController android startup sdk=$sdkInt storageReady=$storageOk',
    );
  }

  Future<void> _iosStartupPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.photos.request();
    await Permission.photosAddOnly.request();
    final photos = await Permission.photos.status;
    final addOnly = await Permission.photosAddOnly.status;
    // Treat library access like Android “storage ready” for saves/Gal.
    isStorageGranted.value = _statusOk(photos) || _statusOk(addOnly);
  }

  Future<void> _showPermissionDialogIfNeeded() async {
    if (await hasAllRequiredPermissions()) return;
    if (Get.isDialogOpen == true) return;
    if (_permissionDialogScheduled) return;
    _permissionDialogScheduled = true;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _permissionDialogScheduled = false;
    if (Get.isDialogOpen == true || await hasAllRequiredPermissions()) return;
    showPermissionRequiredDialog(onTryAgain: _onPermissionTryAgain);
  }

  Future<void> _onPermissionTryAgain() async {
    if (Get.isDialogOpen == true) {
      Get.back<void>();
    }
    _retryCount++;
    await _prefs.setInt(_retryCountKey, _retryCount);
    final backoffMs = (120 * (1 << (_retryCount.clamp(0, 4)))).clamp(120, 2000);
    await Future<void>.delayed(Duration(milliseconds: backoffMs));
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
      final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      final cam = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      final storageOk = await _hasAndroidMediaOrStoragePermission(sdkInt);
      return _statusOk(cam) && _statusOk(mic) && storageOk;
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
      final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      return [
        await Permission.camera.status,
        await Permission.microphone.status,
        if (sdkInt >= 33) await Permission.photos.status,
        if (sdkInt >= 33) await Permission.videos.status,
        if (sdkInt < 33) await Permission.storage.status,
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
      return true;
    }
    if (isStorageGranted.value) return true;
    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    isStorageGranted.value = await _requestAndroidMediaOrStoragePermission(
      sdkInt,
    );
    return isStorageGranted.value;
  }

  Future<bool> _requestAndroidMediaOrStoragePermission(int sdkInt) async {
    if (sdkInt >= 33) {
      final photos = await Permission.photos.request();
      final videos = await Permission.videos.request();
      return _statusOk(photos) && _statusOk(videos);
    }
    final storage = await Permission.storage.request();
    return _statusOk(storage);
  }

  Future<bool> _hasAndroidMediaOrStoragePermission(int sdkInt) async {
    if (sdkInt >= 33) {
      final photos = await Permission.photos.status;
      final videos = await Permission.videos.status;
      return _statusOk(photos) && _statusOk(videos);
    }
    final storage = await Permission.storage.status;
    return _statusOk(storage);
  }

  Future<void> clearPermissionState() async {
    await _prefs.remove(_requestedKey);
    await _prefs.remove(_retryCountKey);
    _retryCount = 0;
    isStorageGranted.value = false;
  }
}
