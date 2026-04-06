import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CameraControllerX extends GetxController {
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
      final available = await cameraProvider();
      cameras.assignAll(available);
      final orderedResolutions = <cam.ResolutionPreset>{
        preset,
        ...safeResolutionOrder,
      }.toList();
      cam.CameraController? lastController;
      for (final candidate in orderedResolutions) {
        cam.CameraController? ctrl;
        try {
          ctrl = cam.CameraController(
            camera,
            candidate,
            enableAudio: enableAudio,
            imageFormatGroup: kIsWeb ? cam.ImageFormatGroup.yuv420 : null,
          );
          await ctrl.initialize();
          await _disposeQuietly(lastController);
          await _disposeQuietly(controller.value);
          controller.value = ctrl;
          aspectRatio.value = ctrl.value.aspectRatio;
          isReady.value = true;
          return;
        } catch (error) {
          await _disposeQuietly(ctrl);
          await _disposeQuietly(lastController);
          lastController = null;
          errorMessage.value = error.toString();
        }
      }
      throw Exception('Unable to initialize camera at any supported resolution');
    } catch (error) {
      errorMessage.value = error.toString();
      isReady.value = false;
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
      rethrow;
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
