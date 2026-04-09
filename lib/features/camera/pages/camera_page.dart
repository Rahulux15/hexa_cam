import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../../config/constants.dart';
import '../../../config/theme.dart';
import '../../../data/models/annotation.dart';
import '../../../data/models/camera_settings.dart';
import '../../../data/models/image_data.dart';
import '../../../data/models/point.dart';
import '../../../data/models/stored_calibration.dart';
import '../../../data/services/database_service.dart';
import '../../../data/services/file_service.dart';
import '../../../data/services/video_export_service.dart';
import '../../../data/services/video_thumbnail_service.dart';
import '../../../state/app_registry.dart';
import '../camera_color_matrix.dart';
import '../camera_types.dart';
import '../widgets/camera_measurement_grid_painter.dart';
import '../../../utils/app_logger.dart';
import '../../../utils/annotation_painter.dart';
import '../../../utils/calibration_calculator.dart';
import '../../../utils/image_bytes_codec.dart';
import '../../../utils/marked_media_renderer.dart';
import '../../../utils/measurement_calculator.dart';
import '../../../utils/responsive.dart';
import '../../../ui/common/hexa_toast.dart';
import '../../../ui/common/save_dialog.dart'; 

class CameraPage extends StatefulWidget {
  final String folderId;
  const CameraPage({super.key, required this.folderId});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  cam.CameraController? _controller;
  bool _isInitialized = false;
  bool _isInitializingCamera = false;
  String? _cameraInitError;
  DateTime? _lastCameraNotReadyToastAt;
  DateTime? _lastAutoCameraRetryAt;
  int _cameraInitVersion = 0;
  CameraViewMode _viewMode = CameraViewMode.defaultOpen;

  bool _isPaused = false;
  bool _isLocked = false;
  bool _isRecording = false;
  bool _flipH = false;
  bool _flipV = false;
  bool _mirror = false;
  int _rotation = 0;

  bool _showColorPickerSection = false;
  bool _showThicknessSection = false;
  bool _showCalibrationSection = false;
  bool _showCameraSettings = false;
  bool _useFourByThreeViewport = true;
  bool _awaitingCalibrationLine = false;
  bool _stampEnabled = false;
  bool _eraserMode = false;
  bool _moveMode = false;
  String _calibrationUnit = 'μm';
  final TextEditingController _manualOverrideController = TextEditingController(
    text: '0',
  );

  String _selectedLens = '4X';
  AnnotationType? _selectedTool;
  Color _drawingColor = const Color(0xFFFF00FF);
  double _drawingStrokeWidth = 4.0;

  final List<Annotation> _annotations = [];
  final List<Annotation> _redoStack = [];
  List<HexaPoint> _currentPoints = [];
  bool _isDrawing = false;
  int? _activeAnnotationIndex;
  List<HexaPoint>? _moveStartPoints;
  HexaPoint? _moveStartCursor;
  HexaPoint? _lastDrawPoint;
  final Uuid _uuid = const Uuid();
  Size _lastSourceSize = Size.zero;
  double _pinchStartZoom = 1.0;
  int _activePreviewPointers = 0;

  /// Last [CameraValue.previewSize] seen by [_onCameraPreviewValueChanged] (stream/orientation).
  Size? _previewListenerSize;
  // Keep preview fully live/adaptive; avoid sticky locks that can feel non-responsive.
  DateTime? _lastPreviewMetricsLogAt;

  /// Returns a fallback source size when camera preview size is unavailable
  /// Uses a 4:3 aspect ratio adjusted for device orientation
  Size _getFallbackSourceSize() {
    final viewportSize = MediaQuery.sizeOf(context);
    // Use 4:3 aspect ratio (common for cameras)
    // Adjust based on whether device is in portrait or landscape
    final double width, height;
    if (viewportSize.width > viewportSize.height) {
      // Landscape orientation
      height = viewportSize.height;
      width = height * 4 / 3;
    } else {
      // Portrait orientation
      width = viewportSize.width;
      height = width * 4 / 3;
    }

    // Ensure reasonable bounds to prevent extremely large/small values
    // Fix clamp arguments to ensure min <= max
    final double maxWidth = math.max(64.0, viewportSize.width * 2);
    final double maxHeight = math.max(64.0, viewportSize.height * 2);
    return Size(
      _safeClampDouble(width, 64.0, maxWidth),
      _safeClampDouble(height, 64.0, maxHeight),
    );
  }

  double _safeClampDouble(double value, double minValue, double maxValue) {
    if (value.isNaN || value.isInfinite) return minValue;
    var lower = minValue;
    var upper = maxValue;
    if (lower.isNaN || lower.isInfinite) lower = 0;
    if (upper.isNaN || upper.isInfinite) upper = lower + 1;
    if (lower > upper) {
      final tmp = lower;
      lower = upper;
      upper = tmp;
    }
    return value.clamp(lower, upper).toDouble();
  }

  CameraSettings _settings = const CameraSettings();
  double _maxSupportedZoom = AppConstants.maxZoom;

  /// Web and devices without optical zoom: scale preview + overlay together.
  bool _useDigitalPreviewZoom = false;

  double get _previewDigitalZoomScale =>
      _useDigitalPreviewZoom ? _settings.zoom : 1.0;

  bool get _isCameraReady =>
      _isInitialized && _controller != null && _controller!.value.isInitialized;

  void _detachCameraListener() {
    _controller?.removeListener(_onCameraPreviewValueChanged);
  }

  /// Some devices update [CameraValue.previewSize] after the first frame; keep overlay + gestures aligned.
  void _onCameraPreviewValueChanged() {
    if (!mounted) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final p = c.value.previewSize;
    if (p == null) return;
    _logPreviewMetrics(c.value, _previewUiAspectRatio(c.value));
    final next = Size(p.width.toDouble(), p.height.toDouble());
    final prev = _previewListenerSize;
    if (prev != null &&
        prev.width == next.width &&
        prev.height == next.height) {
      return;
    }
    _previewListenerSize = next;
    setState(() {});
  }

  String _currentPreviewPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return defaultTargetPlatform.name;
  }

  void _onPreviewPointerDown(PointerDownEvent _) {
    _activePreviewPointers += 1;
  }

  void _onPreviewPointerEnd(PointerEvent _) {
    if (_activePreviewPointers > 0) {
      _activePreviewPointers -= 1;
    }
  }

  void _logPreviewMetrics(cam.CameraValue value, double uiAspect) {
    final now = DateTime.now();
    final last = _lastPreviewMetricsLogAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }
    _lastPreviewMetricsLogAt = now;
    final size = value.previewSize;
    logDebug(
      'Preview metrics [${_currentPreviewPlatform()}]: '
      'preview=${size?.width.toStringAsFixed(1)}x${size?.height.toStringAsFixed(1)} '
      'deviceOrientation=${value.deviceOrientation.name} '
      'uiAspect=${uiAspect.toStringAsFixed(4)} '
      'ui=${_isUiLandscape() ? 'landscape' : 'portrait'}',
    );
  }

  void _attachCameraListener() {
    _detachCameraListener();
    final c = _controller;
    if (c == null) return;
    final p = c.value.previewSize;
    _previewListenerSize = p == null
        ? null
        : Size(p.width.toDouble(), p.height.toDouble());
    c.addListener(_onCameraPreviewValueChanged);
  }

  double _annotationUiTextScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.65);

  /// Same priority as [cam.CameraPreview] for which orientation drives layout.
  DeviceOrientation _applicablePreviewOrientation(cam.CameraValue v) {
    if (v.isRecordingVideo && v.recordingOrientation != null) {
      return v.recordingOrientation!;
    }
    return v.previewPauseOrientation ??
        v.lockedCaptureOrientation ??
        v.deviceOrientation;
  }

  bool _isLandscapeDeviceOrientation(DeviceOrientation o) =>
      o == DeviceOrientation.landscapeLeft ||
      o == DeviceOrientation.landscapeRight;

  bool _isUiLandscape() {
    final mq = MediaQuery.maybeOf(context);
    if (mq != null) return mq.orientation == Orientation.landscape;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return true;
    final size = views.first.physicalSize;
    return size.width >= size.height;
  }

  double _responsiveViewportAspectRatio(BuildContext context) {
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final base = _useFourByThreeViewport ? (4 / 3) : (16 / 9);
    return isLandscape ? base : (1.0 / base);
  }

  /// Width/height of the live preview **as drawn in UI** — must match
  /// [cam.CameraPreview] (portrait inverts buffer [cam.CameraValue.aspectRatio]).
  double _previewUiAspectRatio(cam.CameraValue v) {
    if (!v.isInitialized || v.previewSize == null) return 1.0;
    if (kIsWeb) {
      final w = v.previewSize!.width;
      final h = v.previewSize!.height;
      final longOverShort = math.max(w, h) / math.max(1.0, math.min(w, h));
      return _isUiLandscape() ? longOverShort : (1.0 / longOverShort);
    }
    final bufferAr = v.aspectRatio;
    return _isLandscapeDeviceOrientation(_applicablePreviewOrientation(v))
        ? bufferAr
        : (1.0 / bufferAr);
  }

  Size _renderSourceSize(cam.CameraValue v, Size raw) {
    if (!v.isInitialized) return raw;
    final uiLandscape = kIsWeb
        ? _isUiLandscape()
        : _isLandscapeDeviceOrientation(_applicablePreviewOrientation(v));
    final long = math.max(raw.width, raw.height);
    final short = math.min(raw.width, raw.height);
    return uiLandscape ? Size(long, short) : Size(short, long);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      uiStateController.setMeasurementMode(true);
    });
    _requestPermissionsAndInitCamera();
  }

  Future<void> _requestPermissionsAndInitCamera() async {
    var shouldInitCamera = true;
    _lastPreviewMetricsLogAt = null;
    if (mounted) {
      setState(() => _cameraInitError = null);
    }
    try {
      // Handle permissions for mobile platforms
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          final cameraStatus = await Permission.camera.request().timeout(
            const Duration(seconds: 6),
            onTimeout: () => PermissionStatus.denied,
          );
          await Permission.microphone.request().timeout(
            const Duration(seconds: 6),
            onTimeout: () => PermissionStatus.denied,
          );
          await Permission.storage.request().timeout(
            const Duration(seconds: 6),
            onTimeout: () => PermissionStatus.denied,
          );
          await Permission.manageExternalStorage.request().timeout(
            const Duration(seconds: 6),
            onTimeout: () => PermissionStatus.denied,
          );
          if (await Permission.photos.isDenied) {
            await Permission.photos.request().timeout(
              const Duration(seconds: 6),
              onTimeout: () => PermissionStatus.denied,
            );
          }
          if (await Permission.videos.isDenied) {
            await Permission.videos.request().timeout(
              const Duration(seconds: 6),
              onTimeout: () => PermissionStatus.denied,
            );
          }
          if (!cameraStatus.isGranted) {
            shouldInitCamera = false;
            if (mounted) {
              await _handleCameraPermissionDenied(cameraStatus);
            }
          }
        } else if (Platform.isIOS) {
          var status = await Permission.camera.status;
          if (!status.isGranted) {
            status = await Permission.camera.request().timeout(
              const Duration(seconds: 10),
              onTimeout: () => PermissionStatus.denied,
            );
          }
          await Permission.microphone.request().timeout(
            const Duration(seconds: 10),
            onTimeout: () => PermissionStatus.denied,
          );
          await Permission.photos.request().timeout(
            const Duration(seconds: 10),
            onTimeout: () => PermissionStatus.denied,
          );
          await Permission.photosAddOnly.request().timeout(
            const Duration(seconds: 10),
            onTimeout: () => PermissionStatus.denied,
          );
          if (!status.isGranted) {
            shouldInitCamera = false;
            if (mounted) {
              await _handleCameraPermissionDenied(status);
            }
          }
        }
      }
      // For web, camera permissions are handled by the browser
      // No explicit permission request needed here
    } catch (error) {
      logDebug('Permission flow error: $error');
    } finally {
      if (shouldInitCamera) {
        await _initCamera();
      }
    }
  }

  Future<void> _initCamera() async {
    if (_isInitializingCamera) return;
    final initVersion = ++_cameraInitVersion;
    setState(() {
      _isInitializingCamera = true;
      _cameraInitError = null;
      _isInitialized = false;
    });

    // Fail-fast watchdog to avoid endless loading UI in real-world scenarios.
    Future<void>.delayed(const Duration(seconds: 20), () {
      if (!mounted) return;
      if (_cameraInitVersion != initVersion) return;
      if (!_isInitializingCamera || _isInitialized) return;
      setState(() {
        _isInitializingCamera = false;
        _cameraInitError =
            'Camera startup timed out. Please tap Retry Camera and allow permission.';
      });
    });

    try {
      final cameras = await cam.availableCameras().timeout(
        const Duration(seconds: 8),
        onTimeout: () => <cam.CameraDescription>[],
      );
      if (cameras.isEmpty) {
        logDebug('No cameras available');
        if (!mounted) return;
        setState(() {
          _isInitialized = false;
          _viewMode = CameraViewMode.defaultOpen;
          _showCameraSettings = false;
          _cameraInitError = 'No camera detected on this device/browser.';
        });
        return;
      }
      final orderedCameras = <cam.CameraDescription>[
        ...cameras.where(
          (c) => c.lensDirection == cam.CameraLensDirection.back,
        ),
        ...cameras.where(
          (c) => c.lensDirection == cam.CameraLensDirection.front,
        ),
        ...cameras.where(
          (c) =>
              c.lensDirection != cam.CameraLensDirection.back &&
              c.lensDirection != cam.CameraLensDirection.front,
        ),
      ];

      // Mobile/tablet: prefer best quality first. Web: avoid max first — browser
      // getUserMedia + camera_web ideal width/height can pick a tight crop; high
      // is usually closer to the native camera preview field of view.
      final resolutions = kIsWeb
          ? <cam.ResolutionPreset>[
              cam.ResolutionPreset.high,
              cam.ResolutionPreset.medium,
              cam.ResolutionPreset.veryHigh,
              cam.ResolutionPreset.ultraHigh,
              cam.ResolutionPreset.max,
              cam.ResolutionPreset.low,
            ]
          : <cam.ResolutionPreset>[
              cam.ResolutionPreset.max,
              cam.ResolutionPreset.ultraHigh,
              cam.ResolutionPreset.veryHigh,
              cam.ResolutionPreset.high,
              cam.ResolutionPreset.medium,
              cam.ResolutionPreset.low,
            ];
      const maxInitAttempts = 2;
      for (var attempt = 1; attempt <= maxInitAttempts; attempt++) {
        for (final camera in orderedCameras) {
          for (final resolution in resolutions) {
            try {
              _detachCameraListener();
              await _controller?.dispose();
              _controller = cam.CameraController(
                camera,
                resolution,
                enableAudio: false,
                imageFormatGroup: kIsWeb
                    ? cam.ImageFormatGroup.unknown
                    : (Platform.isAndroid
                        ? cam.ImageFormatGroup.jpeg
                        : null),
              );
              await _controller!.initialize().timeout(
                const Duration(seconds: 10),
              );
              if (!kIsWeb && Platform.isIOS) {
                try {
                  await _controller!.prepareForVideoRecording();
                } catch (_) {}
              }
              if (_controller!.value.hasError) {
                throw Exception(
                  _controller!.value.errorDescription ?? 'Unknown camera error',
                );
              }
              var resolvedMaxZoom = AppConstants.maxZoom;
              try {
                final deviceMaxZoom = await _controller!.getMaxZoomLevel();
                resolvedMaxZoom = deviceMaxZoom.clamp(
                  AppConstants.minZoom,
                  100.0,
                );
              } catch (_) {}
              const digitalMaxZoom = 5.0;
              var useDigitalPreview = false;
              if (kIsWeb) {
                resolvedMaxZoom = digitalMaxZoom;
                useDigitalPreview = true;
              } else if (resolvedMaxZoom <= 1.02) {
                resolvedMaxZoom = digitalMaxZoom;
                useDigitalPreview = true;
              }
              if (!mounted) return;
              setState(() {
                _isInitialized = true;
                _cameraInitError = null;
                _maxSupportedZoom = resolvedMaxZoom;
                _useDigitalPreviewZoom = useDigitalPreview;
                _settings = _settings.copyWith(
                  zoom: AppConstants.minZoom.clamp(
                    AppConstants.minZoom,
                    resolvedMaxZoom,
                  ),
                );
              });
              _attachCameraListener();
              break;
            } catch (e) {
              logDebug(
                'Attempt $attempt: failed ${camera.name} @ $resolution: $e',
              );
              _detachCameraListener();
              await _controller?.dispose();
              _controller = null;
              final msg = e.toString().toLowerCase();
              if (msg.contains('cameranotreadable') ||
                  msg.contains('not readable')) {
                await Future.delayed(Duration(milliseconds: 1200 * attempt));
              }
              continue;
            }
          }
          if (_controller != null && _isInitialized) break;
        }
        if (_controller != null && _isInitialized) break;
        await Future.delayed(Duration(milliseconds: 800 * attempt));
      }

      if (_controller == null && mounted) {
        logDebug('Failed to initialize any camera');
        setState(() {
          _isInitialized = false;
          _viewMode = CameraViewMode.defaultOpen;
          _showCameraSettings = false;
          _cameraInitError =
              'Camera initialization failed. Please close other camera apps/tabs and retry.';
        });
      }
    } catch (error) {
      logDebug('Camera init error: $error');
      if (mounted) {
        _showMessage(
          'Unable to start camera. Please try a lower resolution or close other camera apps.',
          backgroundColor: AppTheme.danger,
        );
        setState(() {
          _isInitialized = false;
          _viewMode = CameraViewMode.defaultOpen;
          _showCameraSettings = false;
          _cameraInitError = 'Camera initialization failed: $error';
        });
      }
    } finally {
      if (mounted) {
        if (_cameraInitVersion == initVersion) {
          setState(() => _isInitializingCamera = false);
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualOverrideController.dispose();
    _detachCameraListener();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      // Screenshot/permission overlays can briefly trigger inactive on mobile.
      // Keep controller alive so users don't see a forced restart prompt.
      if (controller != null && controller.value.isInitialized) {
        try {
          controller.pausePreview();
        } catch (_) {}
      }
      return;
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (controller != null) {
        _detachCameraListener();
        controller.dispose();
        _controller = null;
      }
      if (mounted) setState(() => _isInitialized = false);
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (controller != null && controller.value.isInitialized) {
        try {
          controller.resumePreview();
          return;
        } catch (_) {}
      }
      _requestPermissionsAndInitCamera();
    }
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    _lastPreviewMetricsLogAt = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final isLandscape = Responsive.isLandscape(context);
    final isPortrait = !isLandscape;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final basePreviewPad = Responsive.cameraPreviewPadding(context);
    final previewPadding = isTablet
        ? basePreviewPad
        : EdgeInsets.only(
            left: basePreviewPad.left,
            right: basePreviewPad.right,
            top: basePreviewPad.top + safeTop,
            bottom: basePreviewPad.bottom,
          );
    final sideRailInset = (viewportHeight * 0.14)
        .clamp(isTablet ? 64.0 : 58.0, isTablet ? 124.0 : 112.0)
        .toDouble();
    final topRailTop = safeTop + (viewportHeight * 0.06).clamp(52.0, 78.0);

    return Scaffold(
      backgroundColor: CameraLayoutTokens.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(color: CameraLayoutTokens.background),
          ),
          Positioned.fill(
            child: Padding(
              padding: previewPadding,
              child: _buildCameraViewport(),
            ),
          ),
          if (isPortrait) ...[
            Positioned(
              top: topRailTop,
              left: 12,
              right: 12,
              child: Center(child: _buildTopHorizontalRail(isTablet)),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: (isTablet ? 22 : 18) + safeBottom,
              child: _buildBottomHorizontalRail(isTablet),
            ),
            if (_settings.zoom > 1)
              Positioned(
                top: safeTop + 18,
                right: 16,
                child: _buildZoomBadge(isTablet),
              ),
          ] else ...[
            Positioned(
              left: CameraLayoutTokens.edgePadding(isTablet),
              top: sideRailInset,
              bottom: sideRailInset,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(child: _buildLeftRail(isTablet)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: CameraLayoutTokens.edgePadding(isTablet),
              top: sideRailInset,
              bottom: sideRailInset,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(child: _buildRightRail(isTablet)),
                  ),
                ),
              ),
            ),
            if (_settings.zoom > 1)
              Positioned(
                top: safeTop + 18,
                right: isTablet ? 98 : 82,
                child: _buildZoomBadge(isTablet),
              ),
          ],
          if (_showCameraSettings)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 80 : 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isTablet ? 520 : 420),
                  child: _buildCameraSettingsPanel(isTablet),
                ),
              ),
            ),
          if (_viewMode == CameraViewMode.toolsExpanded) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _viewMode = CameraViewMode.defaultOpen;
                  });
                },
                child: const SizedBox.expand(),
              ),
            ),
            _buildToolsOverlay(isTablet),
          ],
          // Keep back button on top so other rails/overlays don't steal taps.
          Positioned(
            top: safeTop + 8,
            left: CameraLayoutTokens.edgePadding(isTablet),
            child: _buildBackButton(isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(bool isTablet) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _handleBackNavigation,
          child: Container(
            width: isTablet ? 48 : 38,
            height: isTablet ? 48 : 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: CameraLayoutTokens.railIcon,
              size: isTablet ? 22 : 18,
            ),
          ),
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      Get.back<void>();
      return;
    }
    Get.offAllNamed<void>('/folders');
  }

  Rect _sharePositionOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const Rect.fromLTWH(0, 0, 1, 1);
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  Widget _buildCameraViewport() {
    if (!_isInitialized || _controller == null) {
      if (_isInitializingCamera) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        );
      }
      if (_cameraInitError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_rounded,
                  color: Colors.white70,
                  size: 34,
                ),
                const SizedBox(height: 10),
                Text(
                  _cameraInitError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _requestPermissionsAndInitCamera,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Camera'),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white70,
                size: 34,
              ),
              const SizedBox(height: 10),
              const Text(
                'Camera is not ready yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _requestPermissionsAndInitCamera,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Camera'),
              ),
            ],
          ),
        ),
      );
    }
    if (_controller == null && !_isInitializingCamera) {
      final now = DateTime.now();
      final canRetry = _lastAutoCameraRetryAt == null ||
          now.difference(_lastAutoCameraRetryAt!) > const Duration(seconds: 2);
      if (canRetry) {
        _lastAutoCameraRetryAt = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isInitializingCamera || _controller != null) return;
          _requestPermissionsAndInitCamera();
        });
      }
    }

    final previewSize = _controller!.value.previewSize;
    // Handle null preview size with fallback to prevent crashes
    // Use a 4:3 aspect ratio as fallback (common for cameras) adjusted for device orientation
    final sourceSize = previewSize != null
        ? Size(previewSize.width.toDouble(), previewSize.height.toDouble())
        : _getFallbackSourceSize();
    final renderSize = _renderSourceSize(_controller!.value, sourceSize);
    _lastSourceSize = renderSize;
    return Listener(
      onPointerDown: _onPreviewPointerDown,
      onPointerUp: _onPreviewPointerEnd,
      onPointerCancel: _onPreviewPointerEnd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) => _pinchStartZoom = _settings.zoom,
        onScaleUpdate: (details) => _setZoom(_pinchStartZoom * details.scale),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frame =
                Offset.zero & Size(constraints.maxWidth, constraints.maxHeight);
            final padding = Responsive.cameraPreviewPadding(context);
            final innerFrame = Rect.fromLTWH(
              padding.left,
              padding.top,
              (frame.width - padding.horizontal).clamp(1.0, double.infinity),
              (frame.height - padding.vertical).clamp(1.0, double.infinity),
            );
            // Fit the preview box to the camera’s real aspect ratio (no extra crop).
            final viewport = Responsive.cameraPreviewViewport(
              context,
              innerFrame,
              targetAspectRatio: _responsiveViewportAspectRatio(context),
            );
            final selectedAspect = _responsiveViewportAspectRatio(context);
            final sourceAspect = renderSize.width / math.max(1.0, renderSize.height);
            final shouldCropToFill =
                !_useFourByThreeViewport &&
                (sourceAspect - selectedAspect).abs() > 0.02;
            final previewFit = shouldCropToFill ? BoxFit.cover : BoxFit.contain;
            final uiTextScale = _annotationUiTextScale(context);
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x334C68FF)),
                    ),
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: viewport.width,
                    height: viewport.height,
                    child: ClipRect(
                      child: Transform.scale(
                        scale: _previewDigitalZoomScale,
                        alignment: Alignment.center,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Draw preview in source coordinates and only contain-fit once.
                            FittedBox(
                              fit: previewFit,
                              child: SizedBox(
                                width: renderSize.width,
                                height: renderSize.height,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..rotateZ(_rotation * math.pi / 180)
                                    ..scaleByDouble(
                                      (_flipH || _mirror) ? -1.0 : 1.0,
                                      _flipV ? -1.0 : 1.0,
                                      1,
                                      1,
                                    ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _buildCameraPreviewWithOptionalFilter(),
                                      if (uiStateController.measurementMode)
                                        IgnorePointer(
                                          child: CustomPaint(
                                            painter:
                                                CameraMeasurementGridPainter(),
                                          ),
                                        ),
                                      // Keep gesture capture in source coordinates (so existing transforms stay correct).
                                      Positioned.fill(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTapDown: (details) {
                                            if (_activePreviewPointers > 1) return;
                                            _onTapDown(details);
                                          },
                                          onPanStart: (details) {
                                            if (_activePreviewPointers > 1) return;
                                            _onPanStart(details);
                                          },
                                          onPanUpdate: (details) {
                                            if (_activePreviewPointers > 1) return;
                                            _onPanUpdate(details);
                                          },
                                          onPanEnd: (details) {
                                            if (_activePreviewPointers > 1) return;
                                            _onPanEnd(details);
                                          },
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Draw annotations at viewport resolution (prevents pixelated text/labels).
                            IgnorePointer(
                              child: CustomPaint(
                                painter: AnnotationPainter(
                                  annotations: _displayAnnotations(),
                                  currentDrawing:
                                      _isDrawing && _selectedTool != null
                                      ? Annotation(
                                          id: 'current',
                                          type: _selectedTool!,
                                          points: _currentPoints,
                                          color: _drawingColor,
                                          strokeWidth: _drawingStrokeWidth,
                                          timestamp: '',
                                        )
                                      : null,
                                  displaySize: Size(
                                    viewport.width,
                                    viewport.height,
                                  ),
                                  sourceSize: renderSize,
                                  fit: previewFit,
                                  mirrorX: _flipH || _mirror,
                                  mirrorY: _flipV,
                                  zoom: 1,
                                  rotation: _rotation,
                                  lineWidthScale: 1.0,
                                  uiTextScale: uiTextScale,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_stampEnabled)
                  Positioned(
                    top: 18,
                    right: 18,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC10162E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          _buildStampLabel(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.20),
                          ],
                          stops: const [0, 0.4, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  Widget _buildLeftRail(bool isTablet) {
    final measurementEnabled = uiStateController.measurementMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTextLensButton(isTablet),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet)),
        _buildGhostRailButton(
          isTablet: isTablet,
          icon: Icons.swap_vert_rounded,
          onTap: () => _handleSideAction(CameraSideAction.flipVertical),
          active: _flipV,
        ),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet)),
        _buildGhostRailButton(
          isTablet: isTablet,
          icon: Icons.swap_horiz_rounded,
          onTap: () => _handleSideAction(CameraSideAction.flipHorizontal),
          active: _flipH,
        ),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet)),
        _buildAspectRatioButton(isTablet),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet)),
        _buildGhostRailButton(
          isTablet: isTablet,
          icon: Icons.rotate_right_rounded,
          onTap: () => _handleSideAction(CameraSideAction.rotate),
          active: _rotation != 0,
        ),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet)),
        _buildGhostRailButton(
          isTablet: isTablet,
          icon: Icons.flip_camera_android_outlined,
          onTap: () => _handleSideAction(CameraSideAction.inspect),
          active: _mirror,
        ),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet)),
        GestureDetector(
          onTap: () => _handleSideAction(CameraSideAction.status),
          child: Container(
            height: isTablet ? 48 : 42,
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 18 : 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: measurementEnabled
                  ? const LinearGradient(
                      colors: [Color(0xFF5F69FF), Color(0xFF8D57FF)],
                    )
                  : null,
              color: measurementEnabled ? null : const Color(0xFF232651),
              border: Border.all(
                color: measurementEnabled
                    ? const Color(0xFF9EA0FF)
                    : const Color(0xFF4A57AA),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.straighten_rounded,
                  color: Colors.white,
                  size: isTablet ? 20 : 16,
                ),
                const SizedBox(width: 8),
                Text(
                  measurementEnabled ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopHorizontalRail(bool isTablet) {
    final gap = CameraLayoutTokens.railGap(isTablet);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTextLensButton(isTablet),
          SizedBox(width: gap),
          _buildGhostRailButton(
            isTablet: isTablet,
            icon: Icons.swap_vert_rounded,
            onTap: () => _handleSideAction(CameraSideAction.flipVertical),
            active: _flipV,
          ),
          SizedBox(width: gap),
          _buildGhostRailButton(
            isTablet: isTablet,
            icon: Icons.swap_horiz_rounded,
            onTap: () => _handleSideAction(CameraSideAction.flipHorizontal),
            active: _flipH,
          ),
          SizedBox(width: gap),
          _buildAspectRatioButton(isTablet),
          SizedBox(width: gap),
          _buildGhostRailButton(
            isTablet: isTablet,
            icon: Icons.rotate_right_rounded,
            onTap: () => _handleSideAction(CameraSideAction.rotate),
            active: _rotation != 0,
          ),
          SizedBox(width: gap),
          _buildGhostRailButton(
            isTablet: isTablet,
            icon: Icons.flip_camera_android_outlined,
            onTap: () => _handleSideAction(CameraSideAction.inspect),
            active: _mirror,
          ),
          SizedBox(width: gap),
          GestureDetector(
            onTap: () => _handleSideAction(CameraSideAction.status),
            child: Container(
              height: isTablet ? 48 : 42,
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 18 : 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: uiStateController.measurementMode
                    ? const LinearGradient(
                        colors: [Color(0xFF5F69FF), Color(0xFF8D57FF)],
                      )
                    : null,
                color: uiStateController.measurementMode
                    ? null
                    : const Color(0xFF232651),
                border: Border.all(
                  color: uiStateController.measurementMode
                      ? const Color(0xFF9EA0FF)
                      : const Color(0xFF4A57AA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.straighten_rounded,
                    color: Colors.white,
                    size: isTablet ? 20 : 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    uiStateController.measurementMode ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightRail(bool isTablet) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildGhostRailButton(
          isTablet: isTablet,
          icon: Icons.tune_rounded,
          onTap: () => _handleSideAction(CameraSideAction.sparkle),
          active: _showCameraSettings,
        ),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet)),
        _buildGhostRailButton(
          isTablet: isTablet,
          icon: Icons.zoom_in_rounded,
          onTap: () => _handleSideAction(CameraSideAction.zoomIn),
          active: _settings.zoom > 1,
        ),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet)),
        _buildGhostRailButton(
          isTablet: isTablet,
          icon: Icons.zoom_out_rounded,
          onTap: () => _handleSideAction(CameraSideAction.zoomOut),
          active: _settings.zoom > AppConstants.minZoom,
        ),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet) + 2),
        _buildRecordButton(isTablet),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet) + 2),
        _buildGhostRailButton(
          isTablet: isTablet,
          icon: Icons.camera_alt_outlined,
          onTap: () => _handleSideAction(CameraSideAction.capture),
        ),
        SizedBox(height: CameraLayoutTokens.railGap(isTablet)),
        _buildGhostRailButton(
          isTablet: isTablet,
          icon: Icons.draw_outlined,
          onTap: () => _handleSideAction(CameraSideAction.pen),
          active: _viewMode == CameraViewMode.toolsExpanded,
        ),
      ],
    );
  }

  Widget _buildBottomHorizontalRail(bool isTablet) {
    final gap = CameraLayoutTokens.railGap(isTablet);
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildGhostRailButton(
              isTablet: isTablet,
              icon: Icons.tune_rounded,
              onTap: () => _handleSideAction(CameraSideAction.sparkle),
              active: _showCameraSettings,
            ),
            SizedBox(width: gap),
            _buildGhostRailButton(
              isTablet: isTablet,
              icon: Icons.zoom_in_rounded,
              onTap: () => _handleSideAction(CameraSideAction.zoomIn),
              active: _settings.zoom > 1,
            ),
            SizedBox(width: gap),
            _buildGhostRailButton(
              isTablet: isTablet,
              icon: Icons.zoom_out_rounded,
              onTap: () => _handleSideAction(CameraSideAction.zoomOut),
              active: _settings.zoom > AppConstants.minZoom,
            ),
            SizedBox(width: gap + 2),
            _buildRecordButton(isTablet),
            SizedBox(width: gap + 2),
            _buildGhostRailButton(
              isTablet: isTablet,
              icon: Icons.camera_alt_outlined,
              onTap: () => _handleSideAction(CameraSideAction.capture),
            ),
            SizedBox(width: gap),
            _buildGhostRailButton(
              isTablet: isTablet,
              icon: Icons.draw_outlined,
              onTap: () => _handleSideAction(CameraSideAction.pen),
              active: _viewMode == CameraViewMode.toolsExpanded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextLensButton(bool isTablet) {
    final lensLabel = _selectedLens.toLowerCase();
    return Semantics(
      button: true,
      label: 'Select lens',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _handleSideAction(CameraSideAction.lens),
          child: Container(
            width: CameraLayoutTokens.railButtonSize(isTablet),
            height: CameraLayoutTokens.railButtonSize(isTablet),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CameraLayoutTokens.railButtonBg,
              border: Border.all(color: CameraLayoutTokens.railButtonBorder),
            ),
            child: Center(
              child: Text(
                lensLabel,
                style: TextStyle(
                  color: CameraLayoutTokens.railIcon,
                  fontWeight: FontWeight.w700,
                  fontSize: isTablet ? 14 : 12,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAspectRatioButton(bool isTablet) {
    final ratio = _useFourByThreeViewport ? '4:3' : '16:9';
    return Semantics(
      button: true,
      label: 'Toggle aspect ratio',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _handleSideAction(CameraSideAction.aspectRatio),
          child: Container(
            height: CameraLayoutTokens.railButtonSize(isTablet),
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.88)),
            ),
            child: Center(
              child: Text(
                ratio,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: isTablet ? 14 : 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGhostRailButton({
    required bool isTablet,
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    String? semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel ?? 'Camera action',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: CameraLayoutTokens.railButtonSize(isTablet),
            height: CameraLayoutTokens.railButtonSize(isTablet),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withValues(alpha: 0.22)
                  : CameraLayoutTokens.railButtonBg,
              border: Border.all(
                color: active
                    ? AppTheme.primaryLight.withValues(alpha: 0.88)
                    : CameraLayoutTokens.railButtonBorder,
              ),
            ),
            child: Icon(
              icon,
              size: CameraLayoutTokens.railIconSize(isTablet),
              color: active ? Colors.white : CameraLayoutTokens.railSubtleIcon,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton(bool isTablet) {
    return Semantics(
      button: true,
      label: _isRecording ? 'Stop recording' : 'Start recording',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _handleSideAction(CameraSideAction.record),
          child: Container(
            width: CameraLayoutTokens.recordButtonSize(isTablet),
            height: CameraLayoutTokens.recordButtonSize(isTablet),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CameraLayoutTokens.recordRed,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: CameraLayoutTokens.recordRed.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 0.4,
                ),
              ],
            ),
            child: Icon(
              _isRecording ? Icons.stop_rounded : Icons.videocam_rounded,
              color: Colors.white,
              size: isTablet ? 18 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomBadge(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 9 : 8,
        vertical: isTablet ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '${_settings.zoom.toStringAsFixed(1)}x',
        style: TextStyle(
          color: Colors.white,
          fontSize: isTablet ? 11 : 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildToolsOverlay(bool isTablet) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      top: isTablet ? 78 : 70,
      right: isTablet ? 108 : 84,
      width: isTablet ? 270 : 228,
      bottom: 20.0 + safeBottom,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () {},
        child: Container(
          constraints: BoxConstraints(
            maxHeight: math.min(
              MediaQuery.sizeOf(context).height * 0.82,
              isTablet ? 760 : 620,
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            isTablet ? 12 : 10,
            isTablet ? 12 : 10,
            isTablet ? 12 : 10,
            isTablet ? 14 : 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xF2272459),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4A57AA), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Drawing Tools',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 14 : 12.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _toggleToolsPanel,
                      child: Container(
                        width: isTablet ? 26 : 24,
                        height: isTablet ? 26 : 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppTheme.textMuted,
                          size: isTablet ? 18 : 16,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 10 : 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  childAspectRatio: 0.96,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _buildPanelToolButton(
                      isTablet,
                      Icons.pause_circle_outline_rounded,
                      'Pause',
                      _isPaused,
                      () => _togglePauseMode(),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      'Lock',
                      _isLocked,
                      _toggleLockMode,
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.open_with_rounded,
                      'Move',
                      _moveMode,
                      _activateMoveMode,
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.brush_rounded,
                      'Draw',
                      _selectedTool == AnnotationType.draw,
                      () => _selectDrawingTool(AnnotationType.draw),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.text_fields_rounded,
                      'Text',
                      _selectedTool == AnnotationType.text,
                      () => _selectDrawingTool(AnnotationType.text),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.straighten_rounded,
                      'Distance',
                      _selectedTool == AnnotationType.twoPointer,
                      () => _selectDrawingTool(AnnotationType.twoPointer),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.my_location_rounded,
                      'Point',
                      _selectedTool == AnnotationType.singlePointer,
                      () => _selectDrawingTool(AnnotationType.singlePointer),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.crop_square_rounded,
                      'Square',
                      _selectedTool == AnnotationType.square,
                      () => _selectDrawingTool(AnnotationType.square),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.trip_origin_rounded,
                      'Circle',
                      _selectedTool == AnnotationType.circle,
                      () => _selectDrawingTool(AnnotationType.circle),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.trending_flat_rounded,
                      'Arrow',
                      _selectedTool == AnnotationType.arrowOneWay,
                      () => _selectDrawingTool(AnnotationType.arrowOneWay),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.palette_outlined,
                      'Color',
                      _showColorPickerSection,
                      () => setState(
                        () =>
                            _showColorPickerSection = !_showColorPickerSection,
                      ),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.line_weight_rounded,
                      'Thickness',
                      _showThicknessSection,
                      () => setState(
                        () => _showThicknessSection = !_showThicknessSection,
                      ),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.straighten_rounded,
                      'Calibrate',
                      _showCalibrationSection,
                      () => setState(
                        () =>
                            _showCalibrationSection = !_showCalibrationSection,
                      ),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.bookmark_border_rounded,
                      _buildStampLabel(),
                      _stampEnabled,
                      () => setState(() => _stampEnabled = !_stampEnabled),
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.undo_rounded,
                      'Undo',
                      _annotations.isNotEmpty,
                      _undoAnnotation,
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.redo_rounded,
                      'Redo',
                      _redoStack.isNotEmpty,
                      _redoAnnotation,
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.auto_fix_off_rounded,
                      'Eraser',
                      _eraserMode,
                      _toggleEraserMode,
                    ),
                    _buildPanelToolButton(
                      isTablet,
                      Icons.delete_outline_rounded,
                      'Delete',
                      false,
                      () => setState(() {
                        _annotations.clear();
                        _redoStack.clear();
                      }),
                    ),
                  ],
                ),
                if (_showColorPickerSection) ...[
                  SizedBox(height: isTablet ? 14 : 12),
                  _buildColorPickerSection(isTablet),
                ],
                if (_showThicknessSection) ...[
                  SizedBox(height: isTablet ? 14 : 12),
                  _buildThicknessSection(isTablet),
                ],
                if (_showCalibrationSection) ...[
                  SizedBox(height: isTablet ? 14 : 12),
                  _buildCalibrationSection(isTablet),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelToolButton(
    bool isTablet,
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8057F7) : const Color(0xFF2B295C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFAB9CFF) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFFE0E3FF),
              size: isTablet ? 18 : 16,
            ),
            SizedBox(height: isTablet ? 4 : 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFAFB5D9),
                fontSize: isTablet ? 9.5 : 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPickerSection(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 12 : 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ...AppConstants.annotationColors.map((color) {
            final isSelected = _drawingColor.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => setState(() => _drawingColor = color),
              child: Container(
                width: isTablet ? 30 : 26,
                height: isTablet ? 30 : 26,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                _buildRgbSlider(
                  label: 'R',
                  value: (_drawingColor.r * 255).round().toDouble(),
                  onChanged: (value) => _updateDrawingColor(red: value.round()),
                ),
                _buildRgbSlider(
                  label: 'G',
                  value: (_drawingColor.g * 255).round().toDouble(),
                  onChanged: (value) =>
                      _updateDrawingColor(green: value.round()),
                ),
                _buildRgbSlider(
                  label: 'B',
                  value: (_drawingColor.b * 255).round().toDouble(),
                  onChanged: (value) =>
                      _updateDrawingColor(blue: value.round()),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1C48),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B427C)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _drawingColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '#${_drawingColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRgbSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            value: value.clamp(0, 255),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildThicknessSection(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 12 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2B295C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3B427C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.line_weight_rounded,
                color: Color(0xFFAFB5D9),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Marking Thickness',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 13 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_drawingStrokeWidth.toStringAsFixed(1)} px',
                style: TextStyle(
                  color: const Color(0xFFD9DCF4),
                  fontSize: isTablet ? 12 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            min: 2.0,
            max: 16.0,
            divisions: 28,
            value: _drawingStrokeWidth,
            onChanged: (value) {
              setState(() {
                _drawingStrokeWidth = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationSection(bool isTablet) {
    final stored = calibrationController.calibrations[_selectedLens];
    final microCalibration = microscopeCalibrationController;
    final microEntry = microCalibration.getCalibrationForMagnification(
      _selectedLens,
    );
    final effectiveCalibration = microEntry != null
        ? StoredCalibration(
            lens: microEntry.magnification,
            unit: microEntry.unit,
            unitPerPixel: microEntry.unitPerPixel,
            pixelsPerUnit: microEntry.pixelsPerUnit,
            referenceLength: microEntry.referenceLength,
            measuredPixelDistance: microEntry.measuredPixelDistance,
            unitPerDivision: microEntry.unitPerDivision,
            measuredDivisions: microEntry.measuredDivisions,
            createdAt: microEntry.createdAt,
          )
        : stored;
    final hasStored = effectiveCalibration != null;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 12 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2B295C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3B427C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CALIBRATION',
            style: TextStyle(
              color: const Color(0xFF9DA5CB),
              fontSize: isTablet ? 9 : 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: isTablet ? 6 : 5),
          Text(
            '$_selectedLens lens calibration',
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: isTablet ? 6 : 5),
          Text(
            hasStored
                ? 'Saved calibration available for $_selectedLens.'
                : 'No saved calibration for $_selectedLens yet.',
            style: TextStyle(
              color: const Color(0xFFD9DCF4),
              fontSize: isTablet ? 12 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isTablet ? 4 : 3),
          Text(
            'Measurements stay in px until you calibrate this lens.',
            style: TextStyle(
              color: const Color(0xFFAFB5D9),
              fontSize: isTablet ? 11 : 10,
              height: 1.35,
            ),
          ),
          SizedBox(height: isTablet ? 12 : 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _beginCalibrationMarking,
                  child: _buildCalibrationMiniCard(
                    isTablet,
                    'ACTION',
                    'Set\nCalibration',
                    highlighted: true,
                  ),
                ),
              ),
              SizedBox(width: isTablet ? 8 : 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _calibrationUnit = _calibrationUnit == 'μm' ? 'nm' : 'μm';
                  }),
                  child: _buildCalibrationMiniCard(
                    isTablet,
                    'UNIT',
                    _calibrationUnit == 'μm' ? 'Micron' : 'Nanometer',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 8 : 6),
          Row(
            children: [
              Expanded(
                child: _buildCalibrationMiniCard(
                  isTablet,
                  'CURRENT\nVALUE',
                  hasStored
                      ? '${effectiveCalibration.unitPerPixel.toStringAsFixed(3)} ${effectiveCalibration.unit}/px'
                      : '0 $_calibrationUnit/px',
                ),
              ),
              SizedBox(width: isTablet ? 8 : 6),
              Expanded(
                child: _buildCalibrationMiniCard(
                  isTablet,
                  'SAVED\nREFERENCE',
                  hasStored
                      ? '${effectiveCalibration.referenceLength.toStringAsFixed(0)} ${effectiveCalibration.unit}\n${effectiveCalibration.measuredPixelDistance.toStringAsFixed(0)} px'
                      : 'No saved\ncalibration\nyet',
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 8 : 6),
          Text(
            'MANUAL OVERRIDE (MM/PX)',
            style: TextStyle(
              color: const Color(0xFF9DA5CB),
              fontSize: isTablet ? 9 : 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: isTablet ? 6 : 5),
          Container(
            height: isTablet ? 44 : 40,
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1C48),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B427C)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualOverrideController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Text(
                  'MM/PX',
                  style: TextStyle(
                    color: const Color(0xFF7F86AE),
                    fontSize: isTablet ? 11 : 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isTablet ? 10 : 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 12 : 10),
            decoration: BoxDecoration(
              color: const Color(0xFF3C2B70),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF5F4AA1)),
            ),
            child: Text(
              'Drag one reference line on the image, then enter the real calibration distance to save it for $_selectedLens.',
              style: TextStyle(
                color: const Color(0xFFE6E0FF),
                fontSize: isTablet ? 11 : 10,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: isTablet ? 8 : 6),
          Text(
            'Click Set Calibration, draw the reference line, then enter value in popup.',
            style: TextStyle(
              color: const Color(0xFFAFB5D9),
              fontSize: isTablet ? 11 : 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationMiniCard(
    bool isTablet,
    String label,
    String value, {
    bool highlighted = false,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: isTablet ? 82 : 72),
      padding: EdgeInsets.all(isTablet ? 10 : 8),
      decoration: BoxDecoration(
        gradient: highlighted ? AppTheme.primaryGradient : null,
        color: highlighted ? null : const Color(0xFF1E1C48),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFAB9CFF)
              : const Color(0xFF3B427C),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlighted
                  ? Colors.white.withValues(alpha: 0.82)
                  : const Color(0xFF8E97C4),
              fontSize: isTablet ? 8.5 : 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: isTablet ? 7 : 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 14 : 12.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSettingsPanel(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 18 : 14),
      decoration: BoxDecoration(
        color: const Color(0xEE2B295C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3B427C)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Camera Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 20 : 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: _resetCameraSettings,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset'),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _showCameraSettings = false),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSettingSlider(
            icon: Icons.wb_sunny_outlined,
            label: 'Exposure',
            valueLabel: '${_settings.exposure.round()}%',
            min: 25,
            max: 200,
            value: _settings.exposure,
            onChanged: (value) =>
                setState(() => _settings = _settings.copyWith(exposure: value)),
          ),
          _buildSettingSlider(
            icon: Icons.blur_circular_rounded,
            label: 'ISO',
            valueLabel: _settings.iso.round().toString(),
            min: 100,
            max: 1600,
            value: _settings.iso,
            onChanged: (value) =>
                setState(() => _settings = _settings.copyWith(iso: value)),
          ),
          _buildSettingSlider(
            icon: Icons.thermostat_outlined,
            label: 'Temperature',
            valueLabel: '${_settings.temperature.round()}K',
            min: 2500,
            max: 9000,
            value: _settings.temperature,
            onChanged: (value) => setState(
              () => _settings = _settings.copyWith(temperature: value),
            ),
          ),
          _buildSettingSlider(
            icon: Icons.invert_colors_on_outlined,
            label: 'Tint',
            valueLabel: _settings.tint.round().toString(),
            min: -100,
            max: 100,
            value: _settings.tint,
            onChanged: (value) =>
                setState(() => _settings = _settings.copyWith(tint: value)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSlider({
    required IconData icon,
    required String label,
    required String valueLabel,
    required double min,
    required double max,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFC9D0F2), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFDDE3FF),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                valueLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: const Color(0xFF1B2850),
              thumbColor: const Color(0xFF7C63FF),
              overlayColor: AppTheme.primary.withValues(alpha: 0.18),
              trackHeight: 4,
            ),
            child: Slider(
              min: min,
              max: max,
              value: value.clamp(min, max),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  void _resetCameraSettings() {
    setState(() {
      _settings = const CameraSettings();
    });
  }

  void _selectDrawingTool(AnnotationType tool) {
    if (_isLocked) {
      _showMessage('Unlock to edit drawings', backgroundColor: AppTheme.danger);
      return;
    }
    setState(() {
      _selectedTool = _selectedTool == tool ? null : tool;
      _moveMode = false;
      _eraserMode = false;
      // Auto-collapse tools panel when a tool is selected
      if (_viewMode == CameraViewMode.toolsExpanded) {
        _viewMode = CameraViewMode.defaultOpen;
      }
    });
  }

  void _toggleToolsPanel() {
    if (_isLocked) {
      _showMessage(
        'Unlock to open drawing tools',
        backgroundColor: AppTheme.danger,
      );
      return;
    }
    setState(() {
      _viewMode = _viewMode == CameraViewMode.defaultOpen
          ? CameraViewMode.toolsExpanded
          : CameraViewMode.defaultOpen;
    });
  }

  void _handleSideAction(CameraSideAction action) {
    switch (action) {
      case CameraSideAction.lens:
        _showLensPicker();
        break;
      case CameraSideAction.aspectRatio:
        setState(() => _useFourByThreeViewport = !_useFourByThreeViewport);
        _showMessage(
          'Aspect ratio set to ${_useFourByThreeViewport ? '4:3' : '16:9'}',
          backgroundColor: const Color(0xFF2563EB),
        );
        break;
      case CameraSideAction.flipVertical:
        setState(() => _flipV = !_flipV);
        break;
      case CameraSideAction.flipHorizontal:
        setState(() => _flipH = !_flipH);
        _refreshAnnotationMeasurements();
        break;
      case CameraSideAction.rotate:
        setState(() {
          _rotation = (_rotation + 90) % 360;
        });
        break;
      case CameraSideAction.calibration:
        setState(() => _showCalibrationSection = true);
        if (_viewMode == CameraViewMode.defaultOpen) {
          _toggleToolsPanel();
        }
        break;
      case CameraSideAction.move:
        setState(() => _selectedTool = null);
        break;
      case CameraSideAction.status:
        uiStateController.toggleMeasurementMode();
        _refreshAnnotationMeasurements();
        break;
      case CameraSideAction.sparkle:
        if (!_ensureCameraReady()) return;
        setState(() => _showCameraSettings = !_showCameraSettings);
        break;
      case CameraSideAction.zoomIn:
        if (!_ensureCameraReady()) return;
        _adjustZoom(1.0);
        break;
      case CameraSideAction.zoomOut:
        if (!_ensureCameraReady()) return;
        _adjustZoom(-1.0);
        break;
      case CameraSideAction.record:
        if (!_ensureCameraReady()) return;
        if (_isPaused || _isLocked) {
          _showMessage(
            'Disable Pause/Lock to record',
            backgroundColor: AppTheme.danger,
          );
          return;
        }
        _toggleRecording();
        break;
      case CameraSideAction.capture:
        if (!_ensureCameraReady()) return;
        if (_isPaused || _isLocked) {
          _showMessage(
            'Disable Pause/Lock to capture',
            backgroundColor: AppTheme.danger,
          );
          return;
        }
        _handleCapture();
        break;
      case CameraSideAction.inspect:
        if (!_ensureCameraReady()) return;
        setState(() => _mirror = !_mirror);
        break;
      case CameraSideAction.pen:
        if (!_ensureCameraReady()) return;
        _toggleToolsPanel();
        break;
    }
  }

  bool _ensureCameraReady() {
    if (_isCameraReady) return true;
    final now = DateTime.now();
    if (_lastCameraNotReadyToastAt == null ||
        now.difference(_lastCameraNotReadyToastAt!) >
            const Duration(seconds: 2)) {
      _lastCameraNotReadyToastAt = now;
      _showMessage(
        _isInitializingCamera
            ? 'Camera is starting, please wait...'
            : 'Camera is not ready yet.',
        backgroundColor: AppTheme.danger,
      );
    }
    return false;
  }

  void _adjustZoom(double delta) {
    final nextZoom = (_settings.zoom + delta).clamp(
      AppConstants.minZoom,
      _maxSupportedZoom,
    );
    _setZoom(nextZoom);
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopVideoRecording();
    } else {
      _startVideoRecording();
    }
  }

  void _undoAnnotation() {
    if (_annotations.isEmpty) return;
    setState(() {
      final last = _annotations.removeLast();
      _redoStack.add(last);
    });
  }

  void _redoAnnotation() {
    if (_redoStack.isEmpty) return;
    setState(() {
      final recovered = _redoStack.removeLast();
      _annotations.add(recovered);
    });
  }

  void _showLensPicker() {
    final isTab = Responsive.isTablet(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final safeBottom = MediaQuery.paddingOf(sheetContext).bottom;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isTab ? 24 : 20,
              isTab ? 24 : 20,
              isTab ? 24 : 20,
              (isTab ? 24 : 20) + safeBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Text(
              'Select Magnification',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: isTab ? 18 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isTab ? 18 : 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppConstants.magnificationLevels.map((lens) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedLens = lens;
                      final microEntry = microscopeCalibrationController
                          .getCalibrationForMagnification(lens);
                      final stored = calibrationController.calibrations[lens];
                      final effective = microEntry != null
                          ? StoredCalibration(
                              lens: microEntry.magnification,
                              unit: microEntry.unit,
                              unitPerPixel: microEntry.unitPerPixel,
                              pixelsPerUnit: microEntry.pixelsPerUnit,
                              referenceLength: microEntry.referenceLength,
                              measuredPixelDistance:
                                  microEntry.measuredPixelDistance,
                              unitPerDivision: microEntry.unitPerDivision,
                              measuredDivisions: microEntry.measuredDivisions,
                              createdAt: microEntry.createdAt,
                            )
                          : stored;
                      if (effective != null) {
                        _calibrationUnit = effective.unit;
                      }
                    });
                    _refreshAnnotationMeasurements();
                    Navigator.pop(sheetContext);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTab ? 22 : 20,
                      vertical: isTab ? 14 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedLens == lens
                          ? AppTheme.primary
                          : AppTheme.bgTertiary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      lens,
                      style: TextStyle(
                        color: _selectedLens == lens
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: isTab ? 16 : 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// When every slider matches app defaults, show the platform preview without a color matrix
  /// so the feed matches the device camera (no extra grading until the user adjusts settings).
  bool get _previewUsesDeviceColorPassthrough =>
      (_settings.exposure - AppConstants.defaultExposure).abs() < 0.01 &&
      (_settings.iso - AppConstants.defaultIso).abs() < 0.01 &&
      (_settings.temperature - AppConstants.defaultTemperature).abs() < 0.5 &&
      (_settings.tint - AppConstants.defaultTint).abs() < 0.01;

  Widget _buildCameraPreviewWithOptionalFilter() {
    final w = cam.CameraPreview(_controller!);
    if (_previewUsesDeviceColorPassthrough) {
      return w;
    }
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(cameraPreviewColorMatrix(_settings)),
      child: w,
    );
  }

  void _onPanStart(DragStartDetails details) {
    final point = _displayToSource(details.localPosition);
    if (_isPaused || _isLocked) return;

    if (_eraserMode) {
      _eraseAtPoint(point);
      return;
    }

    if (_moveMode) {
      final index = _findClosestAnnotationIndex(point, maxDistance: 40);
      if (index == null) return;
      setState(() {
        _activeAnnotationIndex = index;
        _moveStartCursor = point;
        _moveStartPoints = List<HexaPoint>.from(_annotations[index].points);
        _viewMode = CameraViewMode.defaultOpen;
      });
      return;
    }

    if (_selectedTool == null) return;
    setState(() {
      _currentPoints = [point];
      _lastDrawPoint = point;
      _isDrawing = true;
    });
  }

  void _onTapDown(TapDownDetails details) {
    if (_isPaused || _isLocked) return;
    final point = _displayToSource(details.localPosition);

    if (_eraserMode) {
      _eraseAtPoint(point);
      return;
    }

    if (_moveMode || _selectedTool == null) return;

    setState(() {
      if (_selectedTool == AnnotationType.singlePointer) {
        _currentPoints = [point];
        _isDrawing = true;
        _onPanEnd(DragEndDetails());
      } else if (_selectedTool == AnnotationType.text) {
        _viewMode = CameraViewMode.defaultOpen;
        _showTextDialog(point);
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final point = _displayToSource(details.localPosition);

    if (_eraserMode) {
      _eraseAtPoint(point);
      return;
    }

    if (_moveMode) {
      final index = _activeAnnotationIndex;
      final startCursor = _moveStartCursor;
      final startPoints = _moveStartPoints;
      if (index == null || startCursor == null || startPoints == null) return;
      final dx = point.x - startCursor.x;
      final dy = point.y - startCursor.y;
      final sourceW = _lastSourceSize.width <= 0 ? 1.0 : _lastSourceSize.width;
      final sourceH = _lastSourceSize.height <= 0
          ? 1.0
          : _lastSourceSize.height;
      setState(() {
        final movedPoints = startPoints
            .map(
              (p) => HexaPoint(
                x: (p.x + dx).clamp(0.0, sourceW),
                y: (p.y + dy).clamp(0.0, sourceH),
              ),
            )
            .toList();
        _annotations[index] = _annotations[index].copyWith(points: movedPoints);
      });
      return;
    }

    if (!_isDrawing) return;
    final prev = _lastDrawPoint;
    if (prev != null) {
      final dx = point.x - prev.x;
      final dy = point.y - prev.y;
      if ((dx * dx + dy * dy) < 1.8) {
        return;
      }
    }

    setState(() {
      if (_selectedTool == AnnotationType.draw) {
        _currentPoints.add(point);
      } else {
        _currentPoints = [_currentPoints.first, point];
      }
      _lastDrawPoint = point;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_moveMode) {
      setState(() {
        _activeAnnotationIndex = null;
        _moveStartCursor = null;
        _moveStartPoints = null;
      });
      _refreshAnnotationMeasurements();
      return;
    }

    if (!_isDrawing || _selectedTool == null) return;

    final measurement = uiStateController.measurementMode
        ? _buildMeasurementForPoints(_currentPoints, _selectedTool!)
        : null;

    late final Annotation createdAnnotation;
    setState(() {
      createdAnnotation = Annotation(
        id: _uuid.v4(),
        type: _selectedTool!,
        points: List<HexaPoint>.from(_currentPoints),
        color: _drawingColor,
        strokeWidth: _drawingStrokeWidth,
        timestamp: DateTime.now().toIso8601String(),
        measurement: measurement,
      );
      _annotations.add(
        Annotation(
          id: createdAnnotation.id,
          type: createdAnnotation.type,
          points: createdAnnotation.points,
          color: createdAnnotation.color,
          strokeWidth: createdAnnotation.strokeWidth,
          timestamp: createdAnnotation.timestamp,
          measurement: createdAnnotation.measurement,
        ),
      );
      _redoStack.clear();
      _currentPoints = [];
      _isDrawing = false;
      _lastDrawPoint = null;
      _viewMode = CameraViewMode.defaultOpen;
    });

    final shouldPromptCalibration =
        _awaitingCalibrationLine &&
        createdAnnotation.type == AnnotationType.twoPointer &&
        createdAnnotation.points.length >= 2;
    if (shouldPromptCalibration) {
      _awaitingCalibrationLine = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCalibrationDialogForLine(createdAnnotation);
      });
    }
  }

  Future<void> _handleCapture() async {
    if (_isPaused) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot capture while paused')),
      );
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      _showMessage(
        'Camera not ready. Please retry initialization.',
        backgroundColor: AppTheme.danger,
      );
      return;
    }
    if (_controller!.value.isTakingPicture) return;

    try {
      final file = await _controller!.takePicture();
      if (!mounted) return;
      await _showCaptureReview(filePath: file.path, isVideo: false);
    } catch (error) {
      logDebug('Capture error: $error');
      _showMessage('Unable to capture image', backgroundColor: AppTheme.danger);
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _showMessage(
        'Camera not ready. Please retry initialization.',
        backgroundColor: AppTheme.danger,
      );
      return;
    }
    if (_controller!.value.isRecordingVideo) return;
    try {
      if (!kIsWeb && Platform.isIOS) {
        try {
          await _controller!.prepareForVideoRecording();
        } catch (_) {}
      }
      await _controller!.startVideoRecording();
      if (!mounted) return;
      setState(() => _isRecording = true);
      _showMessage('Recording started');
    } catch (error) {
      logDebug('Video start error: $error');
      _showMessage(
        'Unable to start recording',
        backgroundColor: AppTheme.danger,
      );
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        !_controller!.value.isRecordingVideo) {
      return;
    }
    try {
      final file = await _controller!.stopVideoRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);
      await _showCaptureReview(filePath: file.path, isVideo: true);
    } catch (error) {
      logDebug('Video stop error: $error');
      if (!mounted) return;
      setState(() => _isRecording = false);
      _showMessage(
        'Unable to save recording',
        backgroundColor: AppTheme.danger,
      );
    }
  }

  Future<void> _showCaptureReview({
    required String filePath,
    required bool isVideo,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.bgCardSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final extension = isVideo ? '.mp4' : '.jpg';
        final defaultName =
            'hexa_cam_${DateTime.now().millisecondsSinceEpoch}$extension';
        return SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mq = MediaQuery.of(context);
              final bottomInset = mq.viewInsets.bottom + mq.padding.bottom;
              final compactHeight = constraints.maxHeight < 740;
              final previewHeight = compactHeight
                  ? (constraints.maxHeight * 0.32).clamp(150.0, 220.0)
                  : 220.0;
              final stackButtons = constraints.maxWidth < 520;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 16 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  isVideo ? 'Recording Captured' : 'Image Captured',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: previewHeight,
                    width: double.infinity,
                    color: AppTheme.bgTertiary,
                    child: isVideo
                        ? (kIsWeb
                            ? const Center(
                                child: Icon(
                                  Icons.videocam_rounded,
                                  size: 56,
                                  color: Colors.white,
                                ),
                              )
                            : FutureBuilder<Uint8List?>(
                                future: VideoExportService.extractVideoThumbnailBytes(
                                  sourcePath: filePath,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    );
                                  }
                                  final bytes = snapshot.data;
                                  if (bytes == null || bytes.isEmpty) {
                                    return const Center(
                                      child: Icon(
                                        Icons.videocam_rounded,
                                        size: 56,
                                        color: Colors.white,
                                      ),
                                    );
                                  }
                                  return Image.memory(bytes, fit: BoxFit.contain);
                                },
                              ))
                        : kIsWeb
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              final size = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              final source = _lastSourceSize == Size.zero
                                  ? size
                                  : _lastSourceSize;
                              return FutureBuilder<Uint8List>(
                                future: cam.XFile(filePath).readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }
                                  final bytes = snapshot.data;
                                  if (bytes == null || bytes.isEmpty) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: AppTheme.textMuted,
                                        size: 36,
                                      ),
                                    );
                                  }
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..rotateZ(_rotation * math.pi / 180)
                                          ..scaleByDouble(
                                            (_mirror || _flipH) ? -1.0 : 1.0,
                                            _flipV ? -1.0 : 1.0,
                                            1.0,
                                            1.0,
                                          ),
                                        child: Image.memory(
                                          bytes,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      CustomPaint(
                                        painter: AnnotationPainter(
                                          annotations: _annotationsForSave(),
                                          displaySize: size,
                                          sourceSize: source,
                                          fit: BoxFit.contain,
                                          mirrorX: _mirror || _flipH,
                                          mirrorY: _flipV,
                                          rotation: _rotation,
                                          uiTextScale:
                                              _annotationUiTextScale(context),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final size = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              final source = _lastSourceSize == Size.zero
                                  ? size
                                  : _lastSourceSize;
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..rotateZ(_rotation * math.pi / 180)
                                      ..scaleByDouble(
                                        (_mirror || _flipH) ? -1.0 : 1.0,
                                        _flipV ? -1.0 : 1.0,
                                        1.0,
                                        1.0,
                                      ),
                                    child: Image.file(
                                      File(filePath),
                                      fit: BoxFit.contain,
                                      errorBuilder: (c, e, s) => const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: AppTheme.textMuted,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ),
                                  CustomPaint(
                                    painter: AnnotationPainter(
                                      annotations: _annotationsForSave(),
                                      displaySize: size,
                                      sourceSize: source,
                                      fit: BoxFit.contain,
                                      mirrorX: _mirror || _flipH,
                                      mirrorY: _flipV,
                                      rotation: _rotation,
                                      uiTextScale:
                                          _annotationUiTextScale(context),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Flex(
                  direction: stackButtons ? Axis.vertical : Axis.horizontal,
                  children: [
                    Expanded(
                      flex: stackButtons ? 0 : 1,
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            if (!mounted) return;
                            await _persistMedia(
                              sourcePath: filePath,
                              preferredName: defaultName,
                              isVideo: isVideo,
                              exportToDevice: true,
                            );
                          },
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Download'),
                        ),
                      ),
                    ),
                    SizedBox(width: stackButtons ? 0 : 12, height: stackButtons ? 10 : 0),
                    Expanded(
                      flex: stackButtons ? 0 : 1,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            if (!mounted) return;
                            await SaveDialog.show(
                              context,
                              imageUrl: isVideo
                                  ? null
                                  : (kIsWeb ? filePath : 'file://$filePath'),
                              mediaId: null,
                              annotations: _annotationsForSave(),
                              isVideo: isVideo,
                              onSave: (filename, description) async {
                                await _persistMedia(
                                  sourcePath: filePath,
                                  preferredName: filename.trim().isEmpty
                                      ? defaultName
                                      : filename.trim(),
                                  description: description,
                                  isVideo: isVideo,
                                  exportToDevice: false,
                                );
                              },
                            );
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      if (!mounted) return;
                      final previewMedia = await _buildPreviewMediaForReport(
                        filePath: filePath,
                        isVideo: isVideo,
                        defaultName: defaultName,
                      );
                      if (!mounted) return;
                      Get.toNamed<void>(
                        '/report/${widget.folderId}',
                        arguments: {
                          'images': [previewMedia.toJson()],
                        },
                      );
                    },
                    icon: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                    label: const Text(
                      'Create report from this capture',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<ImageData?> _persistMedia({
    required String sourcePath,
    required String preferredName,
    required bool isVideo,
    required bool exportToDevice,
    String description = '',
  }) async {
    try {
      final annotations = _annotationsForSave();
      final mediaId = FileService.generateAssetId(isVideo ? 'video' : 'image');
      String mediaSourcePath;
      late final Uint8List rawBytes;

      if (kIsWeb) {
        // Web camera output is not a local filesystem path.
        final capture = cam.XFile(sourcePath);
        rawBytes = await capture.readAsBytes();
        mediaSourcePath = sourcePath;
      } else {
        mediaSourcePath = await FileService.persistCapture(
          sourcePath: sourcePath,
          filename: preferredName,
          folderName: widget.folderId,
        );
        rawBytes = await FileService.readBytes(mediaSourcePath);
      }

      Uint8List finalBytes = rawBytes;
      final shouldBakeStillForExport =
          exportToDevice && annotations.isNotEmpty && !isVideo;
      if (shouldBakeStillForExport) {
        finalBytes = await MarkedMediaRenderer.renderPhotoWithAnnotations(
          baseImageBytes: rawBytes,
          annotations: annotations,
          mirrorX: _mirror || _flipH,
          mirrorY: _flipV,
          rotation: _rotation,
          annotationSourceSize: _lastSourceSize.width > 0 &&
                  _lastSourceSize.height > 0
              ? _lastSourceSize
              : null,
        );
        finalBytes = kIsWeb
            ? compressMarkedStillForStore(finalBytes)
            : await compute(compressMarkedStillForStore, finalBytes);
        if (!kIsWeb) {
          await File(mediaSourcePath).writeAsBytes(finalBytes, flush: true);
        }
      } else if (isVideo &&
          exportToDevice &&
          annotations.isNotEmpty &&
          !kIsWeb) {
        final exported = await VideoExportService.burnAnnotationsIntoVideo(
          sourcePath: mediaSourcePath,
          annotations: annotations,
          mirrorX: _mirror || _flipH,
          mirrorY: _flipV,
          rotation: _rotation,
          sourceWidth: _lastSourceSize.width > 0 ? _lastSourceSize.width : 1280,
          sourceHeight: _lastSourceSize.height > 0
              ? _lastSourceSize.height
              : 720,
          outputFilename: preferredName,
        );
        if (exported != null) {
          mediaSourcePath = await FileService.persistCapture(
            sourcePath: exported,
            filename: preferredName,
            folderName: widget.folderId,
          );
          // Ensure the bytes we store/download match the burned-in video.
          finalBytes = await FileService.readBytes(mediaSourcePath);
        }
      }

      await MediaDatabase.saveAsset(mediaId, finalBytes);
      String? thumbnailId = isVideo ? null : mediaId;
      if (!isVideo && annotations.isNotEmpty) {
        final thumbId = FileService.generateAssetId('thumb');
        await MediaDatabase.saveAsset(thumbId, finalBytes);
        thumbnailId = thumbId;
      }
      if (isVideo && !kIsWeb) {
        try {
          final thumbBytes = await VideoExportService.extractVideoThumbnailBytes(
            sourcePath: mediaSourcePath,
          );
          if (thumbBytes != null && thumbBytes.isNotEmpty) {
            final thumbWithMarks = annotations.isEmpty
                ? thumbBytes
                : await MarkedMediaRenderer.renderPhotoWithAnnotations(
                    baseImageBytes: thumbBytes,
                    annotations: annotations,
                    mirrorX: _mirror || _flipH,
                    mirrorY: _flipV,
                    rotation: _rotation,
                    annotationSourceSize: _lastSourceSize.width > 0 &&
                            _lastSourceSize.height > 0
                        ? _lastSourceSize
                        : null,
                  );
            thumbnailId = FileService.generateAssetId('thumb');
            await MediaDatabase.saveAsset(thumbnailId, thumbWithMarks);
          }
        } catch (_) {}
      }
      if (isVideo && kIsWeb) {
        try {
          final thumbBytes = await extractVideoThumbnailForSource(sourcePath);
          if (thumbBytes != null && thumbBytes.isNotEmpty) {
            final thumbWithMarks = annotations.isEmpty
                ? thumbBytes
                : await MarkedMediaRenderer.renderPhotoWithAnnotations(
                    baseImageBytes: thumbBytes,
                    annotations: annotations,
                    mirrorX: _mirror || _flipH,
                    mirrorY: _flipV,
                    rotation: _rotation,
                    annotationSourceSize: _lastSourceSize.width > 0 &&
                            _lastSourceSize.height > 0
                        ? _lastSourceSize
                        : null,
                  );
            thumbnailId = FileService.generateAssetId('thumb');
            await MediaDatabase.saveAsset(thumbnailId, thumbWithMarks);
          }
        } catch (_) {}
      }

      final image = ImageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imageUrl: kIsWeb ? sourcePath : 'file://$mediaSourcePath',
        mediaId: mediaId,
        thumbnailId: thumbnailId ?? mediaId,
        timestamp: DateTime.now().toIso8601String(),
        cameraSettings: _settings,
        annotations: annotations,
        filename: preferredName,
        description: description.trim().isEmpty ? null : description.trim(),
        lens: _selectedLens,
        rotation: _rotation,
        mirrored: _mirror || _flipH,
        showCalibrationStamp: _stampEnabled,
        type: isVideo ? MediaType.video : MediaType.image,
        sourceWidth: _lastSourceSize.width > 0 ? _lastSourceSize.width : null,
        sourceHeight: _lastSourceSize.height > 0
            ? _lastSourceSize.height
            : null,
        isMarkingsBaked: shouldBakeStillForExport,
      );

      await foldersController.addImage(widget.folderId, image);

      var exportedDirectToGallery = true;
      if (exportToDevice) {
        try {
          if (kIsWeb) {
            exportedDirectToGallery = await FileService.saveToDevice(
              finalBytes,
              preferredName,
              sharePositionOrigin: _sharePositionOrigin(),
            );
          } else if (isVideo) {
            exportedDirectToGallery = await FileService.saveVideoToDevice(
              mediaSourcePath,
              preferredName,
              sharePositionOrigin: _sharePositionOrigin(),
            );
          } else {
            exportedDirectToGallery = await FileService.saveToDevice(
              finalBytes,
              preferredName,
              sharePositionOrigin: _sharePositionOrigin(),
            );
          }
        } catch (exportError) {
          logDebug('Export to device failed: $exportError');
          if (mounted) {
            _showMessage(
              'Saved to ${_folderLabel(_displayFolderName())}. Export to gallery/files failed — check permissions.',
              backgroundColor: AppTheme.warning,
            );
          }
          return image;
        }
      }

      _showMessage(
        exportToDevice
            ? (isVideo
                ? (Platform.isIOS
                    ? (exportedDirectToGallery
                        ? 'Video saved to Photos'
                        : 'Share opened — save video to Photos or Files')
                    : 'Video downloaded to Gallery')
                : (Platform.isIOS
                    ? (exportedDirectToGallery
                        ? 'Image saved to Photos'
                        : 'Share opened — save image to Photos or Files')
                    : 'Image downloaded to Gallery'))
            : (isVideo
                ? 'Saved video to ${_folderLabel(_displayFolderName())}'
                : 'Saved image to ${_folderLabel(_displayFolderName())}'),
      );
      return image;
    } catch (error) {
      logDebug('Persist media error: $error');
      _showMessage('Unable to save media', backgroundColor: AppTheme.danger);
      return null;
    }
  }

  List<Annotation> _annotationsForSave() {
    final base = _displayAnnotations();
    if (!_stampEnabled) return base;
    final stampPoint = Responsive.calibrationStampAnchor(
      _lastSourceSize == Size.zero ? _getFallbackSourceSize() : _lastSourceSize,
    );
    return [
      ...base,
      Annotation(
        id: _uuid.v4(),
        type: AnnotationType.text,
        points: [HexaPoint(x: stampPoint.dx, y: stampPoint.dy)],
        color: Colors.white,
        timestamp: DateTime.now().toIso8601String(),
        text: _buildStampLabel(),
      ),
    ];
  }

  String? _buildMeasurementForPoints(
    List<HexaPoint> points,
    AnnotationType type,
  ) {
    if (!uiStateController.measurementMode) return null;
    final effectiveCalibration = _effectiveCalibrationForLens(_selectedLens);
    final needsCalibrationLabel =
        effectiveCalibration == null &&
        type != AnnotationType.text &&
        type != AnnotationType.singlePointer;
    if (needsCalibrationLabel) {
      return 'Calibration not set';
    }
    return MeasurementCalculator.getMeasurementText(
      Annotation(
        id: 'preview',
        type: type,
        points: points,
        color: _drawingColor,
        strokeWidth: _drawingStrokeWidth,
        timestamp: '',
      ),
      pixelsPerUnit: effectiveCalibration?.pixelsPerUnit,
      unit: effectiveCalibration?.unit,
    );
  }

  /// Maps a gesture [point] to source (sensor) coordinates.
  ///
  /// Touches are handled inside the same [Transform] as the preview (rotate /
  /// mirror). Flutter hit-testing already inverse-maps into this child's
  /// coordinate system, which matches raw preview buffer space — do **not** apply
  /// [CoordinateTransformer.screenToImage] here (that would double-invert and
  /// break strokes, arrows, and erase hit targets when rotated or flipped).
  HexaPoint _displayToSource(Offset point) {
    final sw = _lastSourceSize.width <= 0 ? 1.0 : _lastSourceSize.width;
    final sh = _lastSourceSize.height <= 0 ? 1.0 : _lastSourceSize.height;
    return HexaPoint(
      x: point.dx.clamp(0.0, sw),
      y: point.dy.clamp(0.0, sh),
    );
  }

  Future<ImageData> _buildPreviewMediaForReport({
    required String filePath,
    required bool isVideo,
    required String defaultName,
  }) async {
    final annotations = _annotationsForSave();
    String? mediaId;
    String? thumbnailId;
    try {
      final bytes = kIsWeb
          ? await cam.XFile(filePath).readAsBytes()
          : await FileService.readBytes(filePath);
      if (bytes.isNotEmpty) {
        mediaId = FileService.generateAssetId(isVideo ? 'video' : 'image');
        await MediaDatabase.saveAsset(mediaId, bytes);
        if (!isVideo) {
          thumbnailId = mediaId;
        }
      }
    } catch (_) {}
    if (isVideo && !kIsWeb) {
      try {
        final thumbBytes = await VideoExportService.extractVideoThumbnailBytes(
          sourcePath: filePath,
        );
        if (thumbBytes != null && thumbBytes.isNotEmpty) {
          final thumbWithMarks = annotations.isEmpty
              ? thumbBytes
              : await MarkedMediaRenderer.renderPhotoWithAnnotations(
                  baseImageBytes: thumbBytes,
                  annotations: annotations,
                  mirrorX: _mirror || _flipH,
                  mirrorY: _flipV,
                  rotation: _rotation,
                  annotationSourceSize: _lastSourceSize.width > 0 &&
                          _lastSourceSize.height > 0
                      ? _lastSourceSize
                      : null,
                );
          thumbnailId = FileService.generateAssetId('thumb');
          await MediaDatabase.saveAsset(thumbnailId, thumbWithMarks);
        }
      } catch (_) {}
    }
    if (isVideo && kIsWeb) {
      try {
        final thumbBytes = await extractVideoThumbnailForSource(filePath);
        if (thumbBytes != null && thumbBytes.isNotEmpty) {
          final thumbWithMarks = annotations.isEmpty
              ? thumbBytes
              : await MarkedMediaRenderer.renderPhotoWithAnnotations(
                  baseImageBytes: thumbBytes,
                  annotations: annotations,
                  mirrorX: _mirror || _flipH,
                  mirrorY: _flipV,
                  rotation: _rotation,
                  annotationSourceSize: _lastSourceSize.width > 0 &&
                          _lastSourceSize.height > 0
                      ? _lastSourceSize
                      : null,
                );
          thumbnailId = FileService.generateAssetId('thumb');
          await MediaDatabase.saveAsset(thumbnailId, thumbWithMarks);
        }
      } catch (_) {}
    }
    return ImageData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imageUrl: kIsWeb ? filePath : 'file://$filePath',
      mediaId: mediaId,
      thumbnailId: thumbnailId,
      timestamp: DateTime.now().toIso8601String(),
      cameraSettings: _settings,
      annotations: annotations,
      filename: defaultName,
      lens: _selectedLens,
      rotation: _rotation,
      mirrored: _mirror || _flipH,
      showCalibrationStamp: _stampEnabled,
      type: isVideo ? MediaType.video : MediaType.image,
      sourceWidth: _lastSourceSize.width > 0 ? _lastSourceSize.width : null,
      sourceHeight: _lastSourceSize.height > 0 ? _lastSourceSize.height : null,
      isMarkingsBaked: false,
    );
  }

  Future<void> _setZoom(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final zoom = value.clamp(AppConstants.minZoom, _maxSupportedZoom);
    if (!_useDigitalPreviewZoom) {
      try {
        await controller.setZoomLevel(zoom);
      } catch (_) {
        if (mounted) {
          setState(() {
            _useDigitalPreviewZoom = true;
            if (_maxSupportedZoom < 5.0) {
              _maxSupportedZoom = 5.0;
            }
          });
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _settings = _settings.copyWith(zoom: zoom);
    });
  }

  Future<void> _togglePauseMode() async {
    if (!_isCameraReady) {
      _showMessage(
        'Camera is not ready yet.',
        backgroundColor: AppTheme.danger,
      );
      return;
    }
    final nextPaused = !_isPaused;
    try {
      if (nextPaused) {
        await _controller?.pausePreview();
      } else {
        await _controller?.resumePreview();
      }
    } catch (_) {
      // Best-effort for platforms without pause/resume preview support.
    }
    if (!mounted) return;
    setState(() {
      _isPaused = nextPaused;
      if (_isPaused) {
        _selectedTool = null;
        _moveMode = false;
        _eraserMode = false;
        _viewMode = CameraViewMode.defaultOpen;
      }
    });
    _showMessage(_isPaused ? 'Preview paused' : 'Preview resumed');
  }

  void _toggleLockMode() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        _selectedTool = null;
        _moveMode = false;
        _eraserMode = false;
        _viewMode = CameraViewMode.defaultOpen;
      }
    });
    _showMessage(_isLocked ? 'Editing locked' : 'Editing unlocked');
  }

  void _beginCalibrationMarking() {
    if (_isLocked) {
      _showMessage('Unlock to calibrate', backgroundColor: AppTheme.danger);
      return;
    }
    setState(() {
      _awaitingCalibrationLine = true;
      _selectedTool = AnnotationType.twoPointer;
      _showCalibrationSection = true;
      _viewMode = CameraViewMode.defaultOpen;
      _moveMode = false;
      _eraserMode = false;
      _isPaused = false;
    });
    _showMessage('Draw the reference distance line to continue calibration');
  }

  List<Annotation> _syncedAnnotations() {
    final showMeasurements = uiStateController.measurementMode;
    return _annotations
        .map(
          (annotation) => Annotation(
            id: annotation.id,
            type: annotation.type,
            points: annotation.points,
            text: annotation.text,
            color: annotation.color,
            strokeWidth: annotation.strokeWidth,
            timestamp: annotation.timestamp,
            coordinateSpace: annotation.coordinateSpace,
            measurement: showMeasurements
                ? _buildMeasurementForPoints(annotation.points, annotation.type)
                : null,
          ),
        )
        .toList();
  }

  List<Annotation> _displayAnnotations() => _syncedAnnotations();

  StoredCalibration? _effectiveCalibrationForLens(String lens) {
    final microEntry = microscopeCalibrationController
        .getCalibrationForMagnification(lens);
    final storedCalibration = calibrationController.calibrations[lens];
    return microEntry != null
        ? StoredCalibration(
            lens: microEntry.magnification,
            unit: microEntry.unit,
            unitPerPixel: microEntry.unitPerPixel,
            pixelsPerUnit: microEntry.pixelsPerUnit,
            referenceLength: microEntry.referenceLength,
            measuredPixelDistance: microEntry.measuredPixelDistance,
            unitPerDivision: microEntry.unitPerDivision,
            measuredDivisions: microEntry.measuredDivisions,
            createdAt: microEntry.createdAt,
          )
        : storedCalibration;
  }

  void _showMessage(
    String text, {
    Color backgroundColor = AppTheme.success,
  }) {
    if (!mounted) return;
    final HexaToastType type;
    if (backgroundColor == AppTheme.danger) {
      type = HexaToastType.error;
    } else if (backgroundColor == AppTheme.warning) {
      type = HexaToastType.warning;
    } else {
      type = HexaToastType.success;
    }
    HexaToast.show(
      context,
      text,
      type: type,
    );
  }

  Future<void> _handleCameraPermissionDenied(PermissionStatus status) async {
    if (!mounted) return;
    final permanent = status.isPermanentlyDenied;
    setState(() {
      _cameraInitError = permanent
          ? 'Camera access is off for this app. Open Settings to allow the camera, then tap Retry.'
          : 'Camera permission is required. Tap Retry to allow access.';
    });
    _showMessage(
      permanent
          ? 'Camera is blocked. Open Settings to allow camera access for this app.'
          : 'Camera permission is required to capture photos.',
      backgroundColor: AppTheme.danger,
    );
    if (!permanent) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF2B295C),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Camera access needed',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hexa Cam needs camera permission. You can enable it in Settings → Privacy & Security → Camera.',
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Not now',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        openAppSettings();
                      },
                      child: const Text(
                        'Open Settings',
                        style: TextStyle(color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _folderLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'App Folder';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _displayFolderName() {
    try {
      final folder =
          foldersController.folders.firstWhere((f) => f.id == widget.folderId);
      final name = folder.name.trim();
      return name.isEmpty ? widget.folderId : name;
    } catch (_) {
      return widget.folderId;
    }
  }

  Future<void> _showTextDialog(HexaPoint tapPoint) async {
    final TextEditingController controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF2B295C),
        insetPadding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Text',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Enter text',
                    hintStyle: TextStyle(color: Color(0xFFAFB5D9)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4A57AA)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Add', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    final annotation = Annotation(
      id: _uuid.v4(),
      type: AnnotationType.text,
      points: [tapPoint],
      color: _drawingColor,
      strokeWidth: _drawingStrokeWidth,
      timestamp: DateTime.now().toIso8601String(),
      text: text,
    );
    setState(() {
      _annotations.add(annotation);
      _redoStack.clear();
    });
  }

  void _updateDrawingColor({int? red, int? green, int? blue}) {
    setState(() {
      final alpha = (_drawingColor.a * 255).round().clamp(0, 255);
      final currentRed = (_drawingColor.r * 255).round().clamp(0, 255);
      final currentGreen = (_drawingColor.g * 255).round().clamp(0, 255);
      final currentBlue = (_drawingColor.b * 255).round().clamp(0, 255);
      _drawingColor = Color.fromARGB(
        alpha,
        red ?? currentRed,
        green ?? currentGreen,
        blue ?? currentBlue,
      );
    });
  }

  void _activateMoveMode() {
    if (_isLocked) {
      _showMessage(
        'Unlock to move annotations',
        backgroundColor: AppTheme.danger,
      );
      return;
    }
    setState(() {
      _moveMode = !_moveMode;
      _selectedTool = null;
      _eraserMode = false;
    });
  }

  void _toggleEraserMode() {
    if (_isLocked) {
      _showMessage(
        'Unlock to erase annotations',
        backgroundColor: AppTheme.danger,
      );
      return;
    }
    setState(() {
      _eraserMode = !_eraserMode;
      _selectedTool = null;
      _moveMode = false;
    });
  }

  String _buildStampLabel() {
    if (!_stampEnabled) return 'Stamp Off';
    final stored = calibrationController.calibrations[_selectedLens];
    if (stored == null) return '$_selectedLens - Not Set';
    final referenceText = stored.referenceLength % 1 == 0
        ? stored.referenceLength.toStringAsFixed(0)
        : stored.referenceLength.toStringAsFixed(2);
    final unitText = stored.unit == 'μm' ? 'Micron' : 'Nanometer';
    return '$_selectedLens - $referenceText $unitText';
  }

  Future<void> _showCalibrationDialogForLine(Annotation latestDistance) async {
    final isTablet = Responsive.isTablet(context);
    final stored = calibrationController.calibrations[_selectedLens];
    final knownController = TextEditingController(
      text: stored == null ? '' : stored.referenceLength.toStringAsFixed(0),
    );
    final manualController = TextEditingController(
      text: _manualOverrideController.text.trim().isNotEmpty
          ? _manualOverrideController.text.trim()
          : (stored == null ? '' : stored.unitPerPixel.toStringAsFixed(3)),
    );
    final result = await showDialog<Map<String, double?>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.viewInsetsOf(dialogContext).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 420 : 360,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9,
          ),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            decoration: AppTheme.softCardDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF2A295D),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Calibration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 22 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter the real distance for this line ($_selectedLens).',
                    style: const TextStyle(color: Color(0xFFD9DCF4), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: knownController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText:
                          'Distance (${_calibrationUnit == 'μm' ? 'Micron' : 'Nanometer'})',
                      labelStyle: const TextStyle(color: Color(0xFF9DA5CB)),
                      filled: true,
                      fillColor: const Color(0xFF1D284D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFF35517A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFF35517A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: manualController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Manual Override (unit/px) - optional',
                      labelStyle: const TextStyle(color: Color(0xFF9DA5CB)),
                      filled: true,
                      fillColor: const Color(0xFF1D284D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFF35517A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFF35517A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D284D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext, <String, double?>{
                                'knownDistance':
                                    double.tryParse(knownController.text.trim()) ??
                                    0,
                                'manualOverride': double.tryParse(
                                  manualController.text.trim(),
                                ),
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: AppTheme.buttonGradient,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Center(
                                child: Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null) {
      knownController.dispose();
      manualController.dispose();
      return;
    }
    final knownDistance = result['knownDistance'] ?? 0;
    final manualOverride = result['manualOverride'];
    _manualOverrideController.text = manualController.text.trim().isEmpty
        ? '0'
        : manualController.text.trim();
    knownController.dispose();
    manualController.dispose();
    _saveCalibrationFromAnnotation(
      latestDistance,
      knownDistance: knownDistance,
      manualOverride: manualOverride,
    );
  }

  void _saveCalibrationFromAnnotation(
    Annotation latestDistance, {
    required double knownDistance,
    double? manualOverride,
  }) {
    if (latestDistance.points.length < 2) {
      _showMessage(
        'Distance annotation is incomplete',
        backgroundColor: AppTheme.danger,
      );
      return;
    }

    if (knownDistance <= 0) {
      _showMessage(
        'Enter a valid known reference value',
        backgroundColor: AppTheme.danger,
      );
      return;
    }

    final dx = latestDistance.points.last.x - latestDistance.points.first.x;
    final dy = latestDistance.points.last.y - latestDistance.points.first.y;
    final pixelDistance = math.sqrt(dx * dx + dy * dy);
    if (pixelDistance <= 0) {
      _showMessage(
        'Measured pixel distance must be positive',
        backgroundColor: AppTheme.danger,
      );
      return;
    }

    final override = manualOverride ?? 0;
    final unitPerPixel = override > 0
        ? override
        : CalibrationCalculator.computeFactor(pixelDistance, knownDistance);

    final calibration = StoredCalibration(
      lens: _selectedLens,
      unit: _calibrationUnit,
      unitPerPixel: unitPerPixel,
      pixelsPerUnit: 1 / unitPerPixel,
      referenceLength: knownDistance,
      measuredPixelDistance: pixelDistance,
      createdAt: DateTime.now().toIso8601String(),
    );

    calibrationController.saveCalibration(calibration);

    final microProvider = microscopeCalibrationController;
    try {
      microProvider.setCalibrationFromPixels(
        magnification: _selectedLens,
        knownDistance: knownDistance,
        measuredPixels: pixelDistance,
        unit: _calibrationUnit,
      );
    } catch (_) {
      // MicroscopeCalibrationProvider may reject invalid magnifications, ignore
    }

    setState(() {
      // Calibration reference line is temporary; remove it after saving calibration.
      _annotations.removeWhere((a) => a.id == latestDistance.id);
      _redoStack.clear();
      _selectedTool = null;
      _awaitingCalibrationLine = false;
    });
    _refreshAnnotationMeasurements();
    _showMessage('Calibration saved for $_selectedLens');
  }

  void _refreshAnnotationMeasurements() {
    if (!mounted) return;
    // Raw annotation data should never be rewritten on lens changes.
    // Rebuild only so measurement labels are re-derived for current magnification.
    setState(() {});
  }

  void _eraseAtPoint(HexaPoint point) {
    final index = _findClosestAnnotationIndex(point, maxDistance: 30);
    if (index == null) return;
    setState(() {
      _annotations.removeAt(index);
      _redoStack.clear();
    });
  }

  int? _findClosestAnnotationIndex(
    HexaPoint point, {
    required double maxDistance,
  }) {
    int? closestIndex;
    double closestDistance = maxDistance;
    for (var i = 0; i < _annotations.length; i++) {
      final annotation = _annotations[i];
      for (final p in annotation.points) {
        final dx = p.x - point.x;
        final dy = p.y - point.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= closestDistance) {
          closestDistance = dist;
          closestIndex = i;
        }
      }
    }
    return closestIndex;
  }
}
