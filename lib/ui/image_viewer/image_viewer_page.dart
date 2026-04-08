import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../../config/theme.dart';
import '../../data/models/annotation.dart';
import '../../data/models/folder.dart';
import '../../data/models/image_data.dart';
import '../../data/services/database_service.dart';
import '../../data/services/file_service.dart';
import '../../data/services/video_export_service.dart';
import '../../state/app_registry.dart';
import '../../utils/image_bytes_codec.dart';
import '../../utils/marked_media_renderer.dart';
import '../../utils/measurement_calculator.dart';
import '../../utils/responsive.dart';
import '../common/media_image.dart';
import '../common/hexa_toast.dart';
import '../viewer/viewer_screen.dart';

class ImageViewerPage extends StatefulWidget {
  final String folderId;
  final String imageId;
  const ImageViewerPage({
    super.key,
    required this.folderId,
    required this.imageId,
  });
  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  ImageData? _image;
  VideoPlayerController? _videoController;
  List<Annotation> _annotations = [];
  bool _showMeasurements = false;
  int _rotation = 0;
  bool _flipH = false;
  final bool _flipV = false;
  final bool _mirror = false;
  Timer? _annotationSaveDebounce;
  Timer? _imageMetaSaveDebounce;
  final GlobalKey<ViewerScreenState> _viewerKey =
      GlobalKey<ViewerScreenState>();

  /// When the stored image already had baked marks, only these ids were burned in.
  Set<String>? _bakedAnnotationIdsAtOpen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImage());
  }

  void _loadImage() {
    final folders = foldersController.folders;
    Folder? folder;
    try {
      folder = folders.firstWhere((item) => item.id == widget.folderId);
    } catch (_) {
      Get.offAllNamed<void>('/folders');
      return;
    }
    try {
      final image = folder.images.firstWhere(
        (item) => item.id == widget.imageId,
      );
      setState(() {
        _image = image;
        _annotations = List.from(image.annotations);
        _rotation = image.rotation ?? 0;
        _flipH = image.mirrored ?? false;
        _bakedAnnotationIdsAtOpen = image.isMarkingsBaked == true
            ? image.annotations.map((a) => a.id).toSet()
            : null;
      });
      if (image.type == MediaType.video) {
        _initVideoController(image.imageUrl);
      }
    } catch (_) {
      Get.offAllNamed<void>('/folder/${widget.folderId}');
    }
  }

  Future<void> _initVideoController(String source) async {
    _videoController?.dispose();
    try {
      late final VideoPlayerController controller;
      if (!kIsWeb &&
          (source.startsWith('file://') ||
              (!source.startsWith('http://') &&
                  !source.startsWith('https://') &&
                  !source.startsWith('asset:')))) {
        final path = source.startsWith('file://')
            ? source.replaceFirst('file://', '')
            : source;
        controller = VideoPlayerController.file(File(path));
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(source));
      }
      await controller.initialize();
      controller.setLooping(true);
      await controller.setVolume(0);
      unawaited(controller.play());
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _videoController = controller);
    } catch (_) {
      if (!mounted) return;
      setState(() => _videoController = null);
    }
  }

  @override
  void dispose() {
    _annotationSaveDebounce?.cancel();
    _imageMetaSaveDebounce?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    final isTab = Responsive.isTablet(context);
    final isVideo = image.type == MediaType.video;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ViewerScreen(
                key: _viewerKey,
                image: image,
                videoController: _videoController,
                rotation: _rotation,
                mirrorX: _flipH || _mirror,
                mirrorY: _flipV,
                initialAnnotations: _annotations,
                hiddenAnnotationIds: _bakedAnnotationIdsAtOpen ?? const <String>{},
                showFab: false,
                showMeasurements: _showMeasurements,
                onAnnotationsChanged: (list) {
                  _annotations = list;
                  _schedulePersistAnnotations();
                },
                onFiltersChanged: (f) {
                  final img = _image;
                  if (img == null) return;
                  final upd = img.copyWith(cameraSettings: f.toCameraSettings());
                  _image = upd;
                  _schedulePersistImageMeta(upd);
                },
                onStampChanged: (enabled) {
                  final img = _image;
                  if (img == null) return;
                  final upd = img.copyWith(showCalibrationStamp: enabled);
                  _image = upd;
                  _schedulePersistImageMeta(upd);
                },
                buildMedia: (ctx) => isVideo
                    ? _buildVideoSource()
                    : _buildImageSource(image.imageUrl),
              ),
            ),
            Positioned(
              top: isTab ? 16 : 10,
              left: isTab ? 18 : 14,
              child: _sideCircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: _goBackSafely,
              ),
            ),
            Positioned(
              right: isTab ? 18 : 14,
              top: isTab ? 16 : 10,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(
                            () => _showMeasurements = !_showMeasurements),
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF232651),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _showMeasurements
                                  ? AppTheme.primaryLight
                                  : Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showMeasurements ? 'ON' : 'OFF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _sideCircleButton(
                        icon: Icons.edit_rounded,
                        onTap: () => _viewerKey.currentState?.openEditor(),
                      ),
                      const SizedBox(width: 10),
                      _sideCircleButton(
                        icon: Icons.info_outline_rounded,
                        onTap: _showMediaInfo,
                      ),
                      const SizedBox(width: 10),
                      _sideCircleButton(
                        icon: Icons.download_outlined,
                        onTap: _showDownloadOptionsSheet,
                      ),
                      const SizedBox(width: 10),
                      _sideCircleButton(
                        icon: Icons.undo_rounded,
                        onTap: () => _viewerKey.currentState?.undo(),
                      ),
                      const SizedBox(width: 10),
                      _sideCircleButton(
                        icon: Icons.rotate_right_rounded,
                        onTap: () {
                          setState(() => _rotation = (_rotation + 90) % 360);
                          _schedulePersistAnnotations();
                        },
                      ),
                      const SizedBox(width: 10),
                      _sideCircleButton(
                        icon: Icons.fullscreen_rounded,
                        onTap: _openFullscreenViewer,
                      ),
                      const SizedBox(width: 10),
                      _sideCircleButton(
                        icon: Icons.delete_outline_rounded,
                        onTap: _confirmDeleteOrClear,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Semantics(
      button: true,
      label: 'Action',
      child: Material(
        color: active
            ? const Color(0xFF232651)
            : Colors.black.withValues(alpha: 0.25),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _openFullscreenViewer() {
    final image = _image;
    if (image == null) return;
    final isVideo = image.type == MediaType.video;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ViewerScreen(
                  padding: EdgeInsets.zero,
                  showFab: true,
                  image: image,
                  videoController: _videoController,
                  rotation: _rotation,
                  mirrorX: _flipH || _mirror,
                  mirrorY: _flipV,
                  initialAnnotations: List<Annotation>.from(_annotations),
                  hiddenAnnotationIds: _bakedAnnotationIdsAtOpen ?? const <String>{},
                  onAnnotationsChanged: (list) {
                    _annotations = list;
                    _schedulePersistAnnotations();
                  },
                  onFiltersChanged: (f) {
                    final img = _image;
                    if (img == null) return;
                    final upd = img.copyWith(cameraSettings: f.toCameraSettings());
                    _image = upd;
                    _schedulePersistImageMeta(upd);
                  },
                  buildMedia: (c) => isVideo
                      ? _buildVideoSource()
                      : _buildImageSource(image.imageUrl),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadOptionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16182E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        final bottom = MediaQuery.paddingOf(sheetCtx).bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Download Options',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 18),
                _downloadOptionRow(
                  icon: Icons.save_alt_rounded,
                  iconBg: const Color(0xFF3B82F6),
                  title: 'Save to Gallery',
                  subtitle: 'Download image or video to your device',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showMessage('Download started...', AppTheme.success);
                    unawaited(_saveToGalleryWithMarks());
                  },
                ),
                const SizedBox(height: 12),
                _downloadOptionRow(
                  icon: Icons.picture_as_pdf_outlined,
                  iconBg: const Color(0xFF8F5CFF),
                  title: 'Generate Report',
                  subtitle: 'Create a PDF report (saved in app + Downloads)',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _openGenerateReportFlow();
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _downloadOptionRow({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1E2140),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF93A4D1),
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _videoBurnWidth(ImageData image) {
    if (image.sourceWidth != null && image.sourceWidth! > 0) {
      return image.sourceWidth!;
    }
    final c = _videoController;
    if (c != null && c.value.isInitialized) {
      return c.value.size.width;
    }
    return 1280;
  }

  double _videoBurnHeight(ImageData image) {
    if (image.sourceHeight != null && image.sourceHeight! > 0) {
      return image.sourceHeight!;
    }
    final c = _videoController;
    if (c != null && c.value.isInitialized) {
      return c.value.size.height;
    }
    return 720;
  }

  Future<void> _saveToGalleryWithMarks() async {
    final image = _image;
    if (image == null) return;
    await _flushPersistAnnotations();

    try {
      if (image.type == MediaType.video) {
        if (kIsWeb) {
          _showMessage(
            'Video download is not supported in the browser.',
            AppTheme.danger,
          );
          return;
        }
        var videoPath = image.imageUrl.startsWith('file://')
            ? image.imageUrl.replaceFirst('file://', '')
            : image.imageUrl;
        final synced = _syncedAnnotations();
        String pathToExport = videoPath;
        if (synced.isNotEmpty) {
          final burned = await VideoExportService.burnAnnotationsIntoVideo(
            sourcePath: videoPath,
            annotations: synced,
            mirrorX: _flipH || _mirror,
            mirrorY: _flipV,
            rotation: _rotation,
            sourceWidth: _videoBurnWidth(image),
            sourceHeight: _videoBurnHeight(image),
            outputFilename:
                image.filename ?? 'hexa-cam-${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          if (burned != null) {
            pathToExport = burned;
          } else {
            _showMessage(
              'Could not burn markings into video; saving original file.',
              AppTheme.danger,
            );
          }
        }
        await FileService.saveVideoToDevice(
          pathToExport,
          image.filename ?? 'hexa-cam-video.mp4',
        );
        if (pathToExport != videoPath) {
          try {
            await File(pathToExport).delete();
          } catch (_) {}
        }
      } else {
        final bytes = await _buildStillExportBytes();
        if (bytes == null || bytes.isEmpty) {
          _showMessage('Unable to read image data', AppTheme.danger);
          return;
        }
        await FileService.saveToDevice(
          bytes,
          image.filename ?? 'hexa-cam-image.jpg',
        );
      }
      if (!mounted) return;
      _showMessage('Downloaded to Gallery', AppTheme.success);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to download media', AppTheme.danger);
    }
  }

  Future<void> _openGenerateReportFlow() async {
    final image = _image;
    if (image == null) return;
    await _flushPersistAnnotations();

    if (image.type == MediaType.video) {
      _showMessage(
        'PDF reports use still images. Save the marked video from Download, or use a photo.',
        AppTheme.danger,
      );
      return;
    }

    final forReport = ImageData(
      id: image.id,
      imageUrl: image.imageUrl,
      mediaId: image.mediaId,
      thumbnailId: image.thumbnailId,
      timestamp: image.timestamp,
      cameraSettings: image.cameraSettings,
      annotations: _syncedAnnotations(),
      measurements: image.measurements,
      calibration: image.calibration,
      type: MediaType.image,
      duration: image.duration,
      rotation: _rotation,
      mirrored: _flipH || _mirror,
      lens: image.lens,
      filename: image.filename,
      description: image.description,
      showCalibrationStamp: image.showCalibrationStamp,
      sourceWidth: image.sourceWidth,
      sourceHeight: image.sourceHeight,
      isMarkingsBaked: image.isMarkingsBaked == true,
    );

    if (!mounted) return;
    Get.toNamed<void>(
      '/report/${widget.folderId}',
      arguments: {
        'images': [forReport.toJson()],
      },
    );
  }

  void _schedulePersistAnnotations() {
    _annotationSaveDebounce?.cancel();
    _annotationSaveDebounce = Timer(
      const Duration(milliseconds: 450),
      _flushPersistAnnotations,
    );
  }

  Future<void> _flushPersistAnnotations() async {
    final image = _image;
    if (image == null) return;
    final synced = _syncedAnnotations();
    final updated = image.copyWith(
      annotations: synced,
      mirrored: _flipH || _mirror,
      rotation: _rotation,
    );
    await foldersController.updateImage(
      widget.folderId,
      widget.imageId,
      updated,
    );
    _annotations = synced;
    _image = updated;
  }

  void _schedulePersistImageMeta(ImageData updated) {
    _imageMetaSaveDebounce?.cancel();
    _imageMetaSaveDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(
        foldersController.updateImage(
          widget.folderId,
          widget.imageId,
          updated,
        ),
      );
    });
  }

  Future<Uint8List?> _buildStillExportBytes() async {
    final image = _image;
    if (image == null) return null;
    if (image.type != MediaType.video) {
      final captured = await _viewerKey.currentState?.captureFlattenedPng();
      if (captured != null && captured.isNotEmpty) {
        return kIsWeb
            ? compressMarkedStillForStore(captured)
            : await compute(compressMarkedStillForStore, captured);
      }
    }
    final assetId = image.thumbnailId?.isNotEmpty == true
        ? image.thumbnailId!
        : image.mediaId;
    Uint8List? bytes = assetId != null && assetId.isNotEmpty
        ? await MediaDatabase.getAsset(assetId)
        : null;
    if ((bytes == null || bytes.isEmpty) &&
        !kIsWeb &&
        image.imageUrl.startsWith('file://')) {
      final path = image.imageUrl.replaceFirst('file://', '');
      bytes = await FileService.readBytes(path);
    }
    if (bytes == null || bytes.isEmpty) return null;

    if (_annotations.isEmpty) return bytes;

    final bakedIds = _bakedAnnotationIdsAtOpen;
    if (bakedIds != null) {
      final overlay = _annotations
          .where((a) => !bakedIds.contains(a.id))
          .toList();
      if (overlay.isEmpty) return bytes;
      final rendered = await MarkedMediaRenderer.renderPhotoWithAnnotations(
        baseImageBytes: bytes,
        annotations: overlay,
        mirrorX: _flipH || _mirror,
        mirrorY: _flipV,
        rotation: _rotation,
      );
      return kIsWeb
          ? compressMarkedStillForStore(rendered)
          : await compute(compressMarkedStillForStore, rendered);
    }

    if (image.isMarkingsBaked == true) return bytes;

    final rendered = await MarkedMediaRenderer.renderPhotoWithAnnotations(
      baseImageBytes: bytes,
      annotations: _annotations,
      mirrorX: _flipH || _mirror,
      mirrorY: _flipV,
      rotation: _rotation,
    );
    return kIsWeb
        ? compressMarkedStillForStore(rendered)
        : await compute(compressMarkedStillForStore, rendered);
  }

  Future<void> _confirmDeleteOrClear() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF232651),
        title: const Text('Delete', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Remove all markings on this image, or delete the image from the folder?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'clear'),
            child: const Text(
              'Clear markings',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'remove'),
            child: Text(
              'Delete image',
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'cancel') return;
    if (choice == 'clear') {
      setState(() => _annotations.clear());
      _schedulePersistAnnotations();
      return;
    }
    if (choice == 'remove') {
      await foldersController.removeImage(widget.folderId, widget.imageId);
      if (mounted) Get.back<void>();
    }
  }

  String? _measurementFor(Annotation annotation) {
    final lens = _image?.lens;
    final calibration = lens == null
        ? null
        : calibrationController.calibrations[lens];
    return MeasurementCalculator.getMeasurementText(
      annotation,
      pixelsPerUnit: calibration?.pixelsPerUnit,
      unit: calibration?.unit,
    );
  }

  List<Annotation> _syncedAnnotations() {
    final bakedIds = _bakedAnnotationIdsAtOpen;
    return _annotations
        .where((annotation) => bakedIds == null || !bakedIds.contains(annotation.id))
        .map((annotation) {
      if (annotation.type == AnnotationType.twoPointer) {
        return annotation.copyWith(measurement: _measurementFor(annotation));
      }
      return annotation;
    }).toList();
  }

  void _showMessage(String text, Color backgroundColor) {
    if (!mounted) return;
    final type = backgroundColor == AppTheme.danger
        ? HexaToastType.error
        : HexaToastType.success;
    HexaToast.show(context, text, type: type);
  }

  void _showMediaInfo() {
    final image = _image;
    if (image == null) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF232651),
        title: const Text('Media Info', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${image.type == MediaType.video ? 'Video' : 'Image'}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Lens: ${image.lens ?? '-'}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Time: ${image.timestamp}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Annotations: ${_annotations.length}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _goBackSafely() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      Get.back<void>();
      return;
    }
    Get.offAllNamed<void>('/folders');
  }

  Widget _buildVideoSource() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return _placeholder();
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        GestureDetector(
          onTap: () {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
            setState(() {});
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSource(String source) {
    return MediaImage(
      // Keep source path/url even when mediaId exists, so viewer can fall back
      // immediately if in-app asset cache is missing.
      source: source,
      mediaId: _image?.mediaId?.isNotEmpty == true
          ? _image?.mediaId
          : _image?.thumbnailId,
      annotations: const [],
      burnAnnotationsIntoPreview: false,
      mirrorX: _flipH || _mirror,
      mirrorY: _flipV,
      rotation: _rotation,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorWidget: _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    color: Colors.black12,
    child: const Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: AppTheme.textMuted,
        size: 36,
      ),
    ),
  );
}
