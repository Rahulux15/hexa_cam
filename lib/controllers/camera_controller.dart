import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_logger.dart';

class CameraControllerX extends GetxController {
  static const double _defaultAspectRatio = 16 / 9;
  final RxBool isInitializing = false.obs;
  final RxBool isReady = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<cam.CameraController?> controller = Rx<cam.CameraController?>(null);
  final RxList<cam.CameraDescription> cameras = <cam.CameraDescription>[].obs;
  final RxDouble aspectRatio = 1.0.obs;

  List<cam.ResolutionPreset> safeResolutionOrder = const [
    cam.ResolutionPreset.low,
    cam.ResolutionPreset.medium,
    cam.ResolutionPreset.high,
    cam.ResolutionPreset.max,
  ];

  Future<void> _disposeQuietly(cam.CameraController? ctrl) async {
    if (ctrl == null) return;
    try {
      await ctrl.dispose();
    } catch (_) {}
  }

  Future<void> initialize({
    required Future<List<cam.CameraDescription>> Function() cameraProvider,
    required cam.CameraDescription camera,
    required cam.ResolutionPreset preset,
    required bool enableAudio,
  }) async {
    isInitializing.value = true;
    errorMessage.value = '';
    try {
      logDebug(
        'CameraControllerX.initialize platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} preset=$preset enableAudio=$enableAudio',
      );
      final available = await cameraProvider();
      cameras.assignAll(available);
      final orderedResolutions = <cam.ResolutionPreset>{
        preset,
        ...safeResolutionOrder,
      }.toList();
      for (final candidate in orderedResolutions) {
        final formatCandidates = kIsWeb
            ? const <cam.ImageFormatGroup>[
                cam.ImageFormatGroup.yuv420,
                cam.ImageFormatGroup.bgra8888,
              ]
            : const <cam.ImageFormatGroup?>[null];
        for (final format in formatCandidates) {
          cam.CameraController? ctrl;
          try {
            logDebug(
              'CameraControllerX.initialize trying preset=$candidate format=${format?.name ?? 'default'}',
            );
            ctrl = cam.CameraController(
              camera,
              candidate,
              enableAudio: enableAudio,
              imageFormatGroup: format,
            );
            await ctrl.initialize();
            await _disposeQuietly(controller.value);
            controller.value = ctrl;
            aspectRatio.value = ctrl.value.aspectRatio > 0
                ? ctrl.value.aspectRatio
                : _defaultAspectRatio;
            isReady.value = true;
            logDebug(
              'CameraControllerX.initialize success preset=$candidate format=${format?.name ?? 'default'} aspect=${aspectRatio.value}',
            );
            return;
          } catch (error) {
            await _disposeQuietly(ctrl);
            errorMessage.value = error.toString();
            logDebug(
              'CameraControllerX.initialize failed preset=$candidate format=${format?.name ?? 'default'} error=$error',
            );
          }
        }
      }
      throw Exception('Unable to initialize camera at any supported resolution');
    } catch (error) {
      errorMessage.value = error.toString();
      isReady.value = false;
      aspectRatio.value = _defaultAspectRatio;
      logDebug('CameraControllerX.initialize fatal error=$error');
      // In unit tests there is no overlay/context, so avoid surfacing a snackbar.
      if (Get.key.currentState != null) {
        Get.snackbar(
          'Camera error',
          'Unable to start the camera. Please close other camera apps and try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withValues(alpha: 0.9),
          colorText: Colors.white,
        );
      }
      if (kDebugMode) rethrow;
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> pause() async {
    final ctrl = controller.value;
    if (ctrl == null) return;
    try {
      await ctrl.pausePreview();
    } catch (_) {}
  }

  Future<void> resume() async {
    final ctrl = controller.value;
    if (ctrl == null) return;
    try {
      await ctrl.resumePreview();
    } catch (_) {}
  }

  @override
  void onClose() {
    _disposeQuietly(controller.value);
    controller.value = null;
    super.onClose();
  }
}

typedef CameraController = CameraControllerX;
