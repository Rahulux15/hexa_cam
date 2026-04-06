import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionController extends GetxController {
  PermissionController(this._prefs);

  final SharedPreferences _prefs;
  static const _requestedKey = 'startup_permissions_requested';
  final RxBool isStorageGranted = false.obs;

  Future<void> requestStartupPermissions() async {
    if (kIsWeb || _prefs.getBool(_requestedKey) == true) return;

    if (Platform.isAndroid) {
      await Permission.camera.request();
      await Permission.microphone.request();
      final manage = await Permission.manageExternalStorage.request();
      final storage = await Permission.storage.request();
      isStorageGranted.value = manage.isGranted || storage.isGranted;
      await Permission.photos.request();
      await Permission.videos.request();
    } else if (Platform.isIOS) {
      await Permission.camera.request();
      await Permission.microphone.request();
      await Permission.photos.request();
    }

    await _prefs.setBool(_requestedKey, true);
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
