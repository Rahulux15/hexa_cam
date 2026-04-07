import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_logger.dart';

class AsyncActionController extends GetxController {
  final RxMap<String, bool> _running = <String, bool>{}.obs;

  bool isRunning(String key) => _running[key] ?? false;

  Future<T> run<T>(
    String key,
    Future<T> Function() action, {
    bool showOverlay = false,
    String? successMessage,
    String? errorMessage,
    bool logErrors = true,
  }) async {
    if (isRunning(key)) {
      throw StateError('Action "$key" is already running');
    }
    _running[key] = true;
    update([key]);
    try {
      final result = await action();
      if (successMessage != null && Get.context != null) {
        Get.snackbar(
          'Success',
          successMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withValues(alpha: 0.9),
          colorText: Colors.white,
        );
      }
      return result;
    } catch (error, stackTrace) {
      if (logErrors) {
        logDebug('Async action "$key" failed: $error');
        if (kDebugMode) {
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      if (errorMessage != null && Get.context != null) {
        Get.snackbar(
          'Error',
          errorMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withValues(alpha: 0.9),
          colorText: Colors.white,
        );
      }
      rethrow;
    } finally {
      _running[key] = false;
      update([key]);
    }
  }
}
