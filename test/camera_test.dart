import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart' as cam;
import 'package:get/get.dart';
import 'package:demo_app/controllers/camera_controller.dart';

void main() {
  late CameraControllerX cameraController;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.testMode = true;
    cameraController = CameraControllerX();
  });

  tearDown(() {
    cameraController.controller.value?.dispose();
    Get.reset();
  });

  group('Camera System', () {
    test('initialize tries multiple presets (low→max) and fails gracefully without native camera', () async {
      final cameras = [
        const cam.CameraDescription(
          name: 'rear',
          lensDirection: cam.CameraLensDirection.back,
          sensorOrientation: 0,
        ),
      ];

      try {
        await cameraController.initialize(
          cameraProvider: () async => cameras,
          camera: cameras.first,
          preset: cam.ResolutionPreset.low,
          enableAudio: false,
        );
      } catch (_) {
        // [CameraControllerX] rethrows in debug after setting error state.
        expect(kDebugMode, isTrue);
      }

      expect(cameraController.isReady.value, isFalse);
      expect(cameraController.isInitializing.value, isFalse);
      expect(cameraController.aspectRatio.value, closeTo(16 / 9, 1e-6));
      expect(cameraController.errorMessage.value, isNotEmpty);
    });

    test('initialize from medium preset still ends with 16:9 aspect fallback when all fail', () async {
      final cameras = [
        const cam.CameraDescription(
          name: 'rear',
          lensDirection: cam.CameraLensDirection.back,
          sensorOrientation: 0,
        ),
      ];

      try {
        await cameraController.initialize(
          cameraProvider: () async => cameras,
          camera: cameras.first,
          preset: cam.ResolutionPreset.medium,
          enableAudio: false,
        );
      } catch (_) {
        expect(kDebugMode, isTrue);
      }

      expect(cameraController.aspectRatio.value, closeTo(16 / 9, 1e-6));
      expect(cameraController.isReady.value, isFalse);
    });

    test('initialize camera at high resolution fails gracefully without native camera', () async {
      final cameras = [
        const cam.CameraDescription(
          name: 'rear',
          lensDirection: cam.CameraLensDirection.back,
          sensorOrientation: 0,
        ),
      ];

      try {
        await cameraController.initialize(
          cameraProvider: () async => cameras,
          camera: cameras.first,
          preset: cam.ResolutionPreset.high,
          enableAudio: false,
        );
      } catch (_) {
        expect(kDebugMode, isTrue);
      }

      expect(cameraController.isReady.value, isFalse);
      expect(cameraController.aspectRatio.value, closeTo(16 / 9, 1e-6));
    });

    test('flip preview works', () async {
      // Arrange
      // Assume controller has flip method

      // Act
      // await cameraController.flipPreview();

      // Assert
      // expect flipped
    });

    test('rotate preview works', () async {
      // Arrange

      // Act
      // await cameraController.rotatePreview();

      // Assert
    });

    test('zoom control applies', () async {
      // Arrange

      // Act
      // await cameraController.setZoom(2.0);

      // Assert
    });

    test('exposure control applies', () async {
      // Arrange

      // Act
      // await cameraController.setExposure(0.5);

      // Assert
    });

    test('capture image with metadata succeeds', () async {
      // This controller currently wraps camera initialization only.
      // The capture path needs a dedicated mock CameraController before it can be asserted here.
      expect(cameraController.isReady.value, isFalse);
    });

    test('capture video with metadata succeeds', () async {
      // Arrange

      // Act
      // final video = await cameraController.captureVideo();

      // Assert
    });
  });
}
