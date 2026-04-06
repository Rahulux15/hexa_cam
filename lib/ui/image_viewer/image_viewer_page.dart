import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../data/models/annotation.dart';
import '../../data/models/folder.dart';
import '../../data/models/image_data.dart';
import '../../data/services/database_service.dart';
import '../../data/services/file_service.dart';
import '../../data/models/point.dart';
import '../../state/providers.dart';
import '../../utils/coordinate_transformer.dart';
import '../../utils/annotation_painter.dart';
import '../../utils/measurement_calculator.dart';
import '../../utils/responsive.dart';
import '../common/media_image.dart';
import '../common/hexa_toast.dart';

class ImageViewerPage extends StatefulWidget {
  final String folderId;
  final String imageId;
  const ImageViewerPage(
      {super.key, required this.folderId, required this.imageId});
  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  ImageData? _image;
  VideoPlayerController? _videoController;
  List<Annotation> _annotations = [];
  bool _showTools = false;
  bool _measurementMode = false;
  int _rotation = 0;
  bool _flipH = false;
  final bool _flipV = false;
  final bool _mirror = false;
  AnnotationType? _selectedTool;
  Color _drawingColor = const Color(0xFFFF00FF);
  bool _showColorRow = false;
  List<HexaPoint> _currentPoints = [];
  bool _isDrawing = false;
  Size _lastSourceSize = Size.zero;
  final _uuid = const Uuid();

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
      context.go('/folders');
      return;
    }
    try {
      final image =
          folder.images.firstWhere((item) => item.id == widget.imageId);
      setState(() {
        _image = image;
        _annotations = List.from(image.annotations);
        _rotation = image.rotation ?? 0;
        _flipH = image.mirrored ?? false;
      });
      if (image.type == MediaType.video) {
        _initVideoController(image.imageUrl);
      }
    } catch (_) {
      context.go('/folder/${widget.folderId}');
    }
  }

  Future<void> _initVideoController(String source) async {
    _videoController?.dispose();
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(source));
      await controller.initialize();
      controller.setLooping(true);
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
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary)));
    }
    final isTab = Responsive.isTablet(context);
    final isVideo = image.type == MediaType.video;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: Padding(
              padding: Responsive.isLandscapeTablet(context)
                  ? Responsive.cameraPreviewPadding(context)
                  : EdgeInsets.fromLTRB(
                      isTab ? 72 : 52, isTab ? 34 : 26, isTab ? 72 : 52, isTab ? 56 : 42),
              child: Center(
                child: LayoutBuilder(builder: (context, constraints) {
                  final size =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  final source = Size(image.sourceWidth ?? size.width,
                      image.sourceHeight ?? size.height);
                  _lastSourceSize = source;
                  final fittedSize = Size(
                    source.width <= 0 ? size.width : source.width,
                    source.height <= 0 ? size.height : source.height,
                  );
                  return FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: fittedSize.width,
                      height: fittedSize.height,
                      child: Stack(children: [
                        Positioned.fill(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..rotateZ(_rotation * pi / 180)
                              ..scaleByDouble(
                                (_flipH || _mirror) ? -1.0 : 1.0,
                                _flipV ? -1.0 : 1.0,
                                1.0,
                                1.0,
                              ),
                            child: isVideo
                                ? _buildVideoSource()
                                : _buildImageSource(image.imageUrl),
                          ),
                        ),
                        if (_selectedTool != null || _isDrawing)
                          Positioned.fill(
                            child: GestureDetector(
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: _onPanEnd,
                              child: CustomPaint(
                                painter: AnnotationPainter(
                                  annotations: _annotations,
                                  currentDrawing: _isDrawing
                                      ? Annotation(
                                          id: 'current',
                                          type: _selectedTool!,
                                          points: _currentPoints,
                                          color: _drawingColor,
                                          timestamp: '')
                                      : null,
                                  displaySize: fittedSize,
                                  sourceSize: source,
                                  fit: BoxFit.contain,
                                  mirrorX: _flipH || _mirror,
                                  mirrorY: _flipV,
                                  rotation: _rotation,
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  );
                }),
              ),
            ),
          ),
          Positioned(
              top: isTab ? 16 : 10,
              left: isTab ? 18 : 14,
              child: _sideCircleButton(
                  icon: Icons.arrow_back_rounded, onTap: () => context.pop())),
          if (_showTools)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    18, 16, 18, 18 + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                    color: Color(0xE6101020),
                    border: Border(top: BorderSide(color: Color(0x22FFFFFF)))),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _toolChip(Icons.straighten_rounded, 'Measure',
                        _measurementMode, _toggleMeasurementMode),
                    _toolChip(
                        Icons.brush_rounded,
                        'Draw',
                        _selectedTool == AnnotationType.draw,
                        () => _selectTool(AnnotationType.draw)),
                    _toolChip(
                        Icons.text_fields_rounded,
                        'Text',
                        _selectedTool == AnnotationType.text,
                        () => _selectTool(AnnotationType.text)),
                    _toolChip(
                        Icons.place_outlined,
                        'Point',
                        _selectedTool == AnnotationType.singlePointer,
                        () => _selectTool(AnnotationType.singlePointer)),
                    _toolChip(
                        Icons.crop_square_rounded,
                        'Square',
                        _selectedTool == AnnotationType.square,
                        () => _selectTool(AnnotationType.square)),
                    _toolChip(
                        Icons.circle_outlined,
                        'Circle',
                        _selectedTool == AnnotationType.circle,
                        () => _selectTool(AnnotationType.circle)),
                    _toolChip(
                        Icons.arrow_right_alt_rounded,
                        'Arrow',
                        _selectedTool == AnnotationType.arrowOneWay,
                        () => _selectTool(AnnotationType.arrowOneWay)),
                    _toolChip(Icons.palette_outlined, 'Color', _showColorRow,
                        () => setState(() => _showColorRow = !_showColorRow)),
                    _toolChip(Icons.undo_rounded, 'Undo', false, () {
                      if (_annotations.isNotEmpty) {
                        setState(() => _annotations.removeLast());
                        _saveAnnotations();
                      }
                    }),
                    _toolChip(
                      Icons.delete_sweep_outlined,
                      'Clear',
                      false,
                      () {
                        setState(() => _annotations.clear());
                        _saveAnnotations();
                      },
                      danger: true,
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: isTab ? 18 : 14,
            top: isTab ? 16 : 10,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  GestureDetector(
                    onTap: () => setState(() => _showTools = !_showTools),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF232651),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _showTools
                              ? AppTheme.primaryLight
                              : Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _showTools ? 'ON' : 'OFF',
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
                    icon: Icons.info_outline_rounded,
                    onTap: _showMediaInfo,
                  ),
                  const SizedBox(width: 10),
                  _sideCircleButton(
                    icon: Icons.download_outlined,
                    onTap: _saveToGallery,
                  ),
                  const SizedBox(width: 10),
                  _sideCircleButton(
                    icon: Icons.undo_rounded,
                    onTap: () {
                      if (_annotations.isEmpty) return;
                      setState(() => _annotations.removeLast());
                      _saveAnnotations();
                    },
                  ),
                  const SizedBox(width: 10),
                  _sideCircleButton(
                    icon: Icons.crop_free_rounded,
                    onTap: () {
                      setState(() => _rotation = (_rotation + 90) % 360);
                      _saveAnnotations();
                    },
                  ),
                  const SizedBox(width: 10),
                  _sideCircleButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: () {
                      setState(() => _annotations.clear());
                      _saveAnnotations();
                    },
                  ),
                ]),
              ),
            ),
          ),
          if (_showColorRow)
            Positioned(
              left: 20,
              right: 20,
              bottom: (_showTools ? 110 : 24) +
                  MediaQuery.paddingOf(context).bottom,
              child: Center(
                child: Wrap(
                  spacing: 10,
                  children: AppConstants.annotationColors
                      .map((color) => GestureDetector(
                            onTap: () => setState(() => _drawingColor = color),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _drawingColor == color
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 3)),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _sideCircleButton(
      {required IconData icon,
      required VoidCallback onTap,
      bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? const Color(0xFF232651)
                : Colors.black.withValues(alpha: 0.25),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _toolChip(IconData icon, String label, bool active, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger
        ? AppTheme.danger
        : active
            ? AppTheme.primary
            : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: active
                ? const Color(0xFF232651)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: active ? AppTheme.primaryLight : Colors.white12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600))
        ]),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (_selectedTool == null) return;
    setState(() {
      _currentPoints = [_displayToSource(details.localPosition)];
      _isDrawing = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing) return;
    final point = _displayToSource(details.localPosition);
    setState(() {
      if (_selectedTool == AnnotationType.draw) {
        _currentPoints.add(point);
      } else {
        _currentPoints = [_currentPoints.first, point];
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDrawing || _selectedTool == null) return;
    final previewAnnotation = Annotation(
      id: '',
      type: _selectedTool!,
      points: _currentPoints,
      color: _drawingColor,
      timestamp: '',
    );
    final measurement =
        _measurementMode ? _measurementFor(previewAnnotation) : null;
    final annotation = Annotation(
        id: _uuid.v4(),
        type: _selectedTool!,
        points: List.from(_currentPoints),
        color: _drawingColor,
        timestamp: DateTime.now().toIso8601String(),
        measurement:
            measurement != null && measurement.isNotEmpty ? measurement : null);
    setState(() {
      _annotations.add(annotation);
      _currentPoints = [];
      _isDrawing = false;
    });
    _saveAnnotations();
  }

  Future<void> _saveAnnotations() async {
    final image = _image;
    if (image == null) return;
    final synced = _syncedAnnotations();
    final updated = image.copyWith(
        annotations: synced, mirrored: _flipH || _mirror, rotation: _rotation);
    await foldersController.updateImage(widget.folderId, widget.imageId, updated);
    setState(() {
      _annotations = synced;
      _image = updated;
    });
    _showMessage('Changes saved', AppTheme.success);
  }

  Future<void> _saveToGallery() async {
    final image = _image;
    if (image == null) return;
    try {
      if (image.type == MediaType.video) {
        final videoSource = image.imageUrl.startsWith('file://')
            ? image.imageUrl.replaceFirst('file://', '')
            : image.imageUrl;
        await FileService.saveVideoToDevice(
            videoSource, image.filename ?? 'hexa-cam-video.mp4');
      } else {
        final assetId = image.thumbnailId?.isNotEmpty == true
            ? image.thumbnailId!
            : image.mediaId;
        final bytes = assetId != null ? await MediaDatabase.getAsset(assetId) : null;
        if (bytes != null && bytes.isNotEmpty) {
          await FileService.saveToDevice(
              bytes, image.filename ?? 'hexa-cam-image.jpg');
        } else if (!kIsWeb && image.imageUrl.startsWith('file://')) {
          final path = image.imageUrl.replaceFirst('file://', '');
          final rawBytes = await FileService.readBytes(path);
          await FileService.saveToDevice(
              rawBytes, image.filename ?? 'hexa-cam-image.jpg');
        }
      }
      if (!mounted) return;
      _showMessage('Download completed', AppTheme.success);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to download media', AppTheme.danger);
    }
  }

  void _toggleMeasurementMode() {
    setState(() => _measurementMode = !_measurementMode);
    _saveAnnotations();
  }

  void _selectTool(AnnotationType tool) {
    setState(() {
      _selectedTool = _selectedTool == tool ? null : tool;
    });
  }

  HexaPoint _displayToSource(Offset point) {
    final transformed = CoordinateTransformer.screenToImage(
      point,
      imageSize: Size(
        _lastSourceSize.width <= 0 ? 1.0 : _lastSourceSize.width,
        _lastSourceSize.height <= 0 ? 1.0 : _lastSourceSize.height,
      ),
      mirrorX: _flipH || _mirror,
      mirrorY: _flipV,
      rotation: _rotation,
    );
    return HexaPoint(x: transformed.dx, y: transformed.dy);
  }

  String? _measurementFor(Annotation annotation) {
    final lens = _image?.lens;
    final calibration =
        lens == null ? null : calibrationController.calibrations[lens];
    return MeasurementCalculator.getMeasurementText(
      annotation,
      pixelsPerUnit: calibration?.pixelsPerUnit,
      unit: calibration?.unit,
    );
  }

  List<Annotation> _syncedAnnotations() {
    return _annotations
        .map((annotation) => annotation.copyWith(
              measurement:
                  _measurementMode ? _measurementFor(annotation) : null,
            ))
        .toList();
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
            Text('Type: ${image.type == MediaType.video ? 'Video' : 'Image'}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Lens: ${image.lens ?? '-'}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Time: ${image.timestamp}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Annotations: ${_annotations.length}',
                style: const TextStyle(color: Colors.white70)),
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
      source: _image?.thumbnailId != null && _image!.thumbnailId!.isNotEmpty
          ? ''
          : source,
      mediaId: _image?.thumbnailId?.isNotEmpty == true
          ? _image?.thumbnailId
          : _image?.mediaId,
      annotations: _annotations,
      mirrorX: _flipH || _mirror,
      mirrorY: _flipV,
      rotation: _rotation,
      fit: BoxFit.contain,
      errorWidget: _placeholder(),
    );
  }

  Widget _placeholder() => Container(
      color: Colors.black12,
      child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: AppTheme.textMuted, size: 36)));
}



