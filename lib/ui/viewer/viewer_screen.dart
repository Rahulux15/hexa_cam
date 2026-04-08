import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../data/models/annotation.dart';
import '../../data/models/camera_settings.dart';
import '../../data/models/image_data.dart';
import '../../data/models/point.dart';
import '../../data/models/stored_calibration.dart';
import '../../state/app_registry.dart';
import '../../utils/annotation_painter.dart';
import '../../utils/calibration_calculator.dart';
import '../../utils/measurement_calculator.dart';
import '../../utils/responsive.dart';
import 'draw_action.dart';
import 'viewer_filters.dart';
import 'viewer_hit_test.dart';

/// Tools that create or modify annotations (CustomPainter-based; mirrors [flutter_painter] UX).
enum ViewerDrawTool {
  move,
  draw,
  text,
  distance,
  point,
  square,
  circle,
  arrow,
  eraser,
}

/// Custom viewer: [Stack] with filtered media, [AnnotationPainter] overlay, drawing tools sheet, undo history.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.image,
    required this.videoController,
    required this.rotation,
    required this.mirrorX,
    required this.mirrorY,
    required this.initialAnnotations,
    required this.onAnnotationsChanged,
    required this.buildMedia,
    this.onFiltersChanged,
    this.onStampChanged,
    this.onEditorVisibilityChanged,
    this.padding,
    this.exportRepaintKey,
    this.showFab = true,
    this.showMeasurements = true,
    this.hiddenAnnotationIds = const <String>{},
  });

  final ImageData image;
  final VideoPlayerController? videoController;
  final int rotation;
  final bool mirrorX;
  final bool mirrorY;
  final List<Annotation> initialAnnotations;
  final ValueChanged<List<Annotation>> onAnnotationsChanged;
  final ValueChanged<ViewerFilters>? onFiltersChanged;
  final ValueChanged<bool>? onStampChanged;
  final ValueChanged<bool>? onEditorVisibilityChanged;

  /// Unfiltered media (image / video); [ViewerScreen] applies [ViewerFilterMatrix.wrap].
  final Widget Function(BuildContext context) buildMedia;

  /// Defaults to viewer padding; use [EdgeInsets.zero] for fullscreen routes.
  final EdgeInsets? padding;

  /// Optional external key to capture the same subtree as this widget’s internal boundary.
  final GlobalKey? exportRepaintKey;

  /// When false, hides the edit FAB and drawing overlay (e.g. header “+ OFF”).
  final bool showFab;

  /// When false, measurement text is hidden (labels are not rendered).
  final bool showMeasurements;

  /// Annotation ids to hide in viewer (e.g. marks already baked into pixels).
  final Set<String> hiddenAnnotationIds;

  @override
  State<ViewerScreen> createState() => ViewerScreenState();
}

class ViewerScreenState extends State<ViewerScreen> {
  final _uuid = const Uuid();
  final _history = DrawHistory();
  final GlobalKey _repaintKey = GlobalKey();

  late List<Annotation> _annotations;
  late ViewerFilters _filters;
  bool _stampEnabled = false;
  bool _showCalibrationSection = false;
  bool _awaitingCalibrationLine = false;
  String _calibrationUnit = 'μm';

  bool _editingPaused = false;
  bool _locked = false;
  ViewerDrawTool? _tool;

  Color _drawingColor = const Color(0xFFFF00FF);
  bool _showColorRow = false;
  bool _showToolsPanel = false;

  List<HexaPoint> _currentPoints = [];
  bool _isDrawing = false;
  Size _lastSourceSize = Size.zero;

  String? _moveId;
  List<HexaPoint>? _moveBefore;
  HexaPoint? _lastDrawPoint;

  final List<DARemoveEntry> _eraserRemoved = [];

  @override
  void initState() {
    super.initState();
    _annotations = widget.initialAnnotations
        .where((a) => !widget.hiddenAnnotationIds.contains(a.id))
        .toList();
    _filters = ViewerFilters.fromCameraSettings(widget.image.cameraSettings);
    _stampEnabled = widget.image.showCalibrationStamp ?? false;
    final lens = widget.image.lens;
    final stored = lens == null ? null : calibrationController.calibrations[lens];
    _calibrationUnit = stored?.unit ?? 'μm';
  }

  @override
  void didUpdateWidget(covariant ViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final imageChanged = oldWidget.image.id != widget.image.id;
    final incomingAnnotationsChanged =
        !listEquals(oldWidget.initialAnnotations, widget.initialAnnotations);
    final hiddenIdsChanged =
        !setEquals(oldWidget.hiddenAnnotationIds, widget.hiddenAnnotationIds);
    if (imageChanged || incomingAnnotationsChanged || hiddenIdsChanged) {
      _annotations = widget.initialAnnotations
          .where((a) => !widget.hiddenAnnotationIds.contains(a.id))
          .toList();
      if (imageChanged) {
        _history.clear();
      }
      _filters = ViewerFilters.fromCameraSettings(widget.image.cameraSettings);
      _stampEnabled = widget.image.showCalibrationStamp ?? false;
      final lens = widget.image.lens;
      final stored = lens == null ? null : calibrationController.calibrations[lens];
      _calibrationUnit = stored?.unit ?? 'μm';
    }
  }

  GlobalKey get repaintBoundaryKey => widget.exportRepaintKey ?? _repaintKey;

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void undo() {
    if (_locked || _editingPaused) return;
    setState(() {
      _history.undo(_annotations);
    });
    _notify();
  }

  void redo() {
    if (_locked || _editingPaused) return;
    setState(() {
      _history.redo(_annotations);
    });
    _notify();
  }

  void openEditor() {
    if (!mounted) return;
    setState(() => _showToolsPanel = true);
    widget.onEditorVisibilityChanged?.call(true);
  }

  void closeEditor() {
    if (!mounted) return;
    setState(() {
      _showToolsPanel = false;
      _showColorRow = false;
    });
    widget.onEditorVisibilityChanged?.call(false);
  }

  /// Flattened PNG (filters + annotations). Video: current frame + overlays.
  Future<Uint8List?> captureFlattenedPng() async {
    final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = await boundary.toImage(pixelRatio: dpr);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _notify() {
    widget.onAnnotationsChanged(List<Annotation>.from(_annotations));
  }

  void clearAllMarkings() {
    if (_annotations.isEmpty) return;
    setState(() {
      _annotations.clear();
      _currentPoints = [];
      _isDrawing = false;
      _moveId = null;
      _moveBefore = null;
      _eraserRemoved.clear();
    });
    _history.clear();
    _notify();
  }

  void _pushAdd(Annotation a) {
    _history.record(DAAdd(a));
    _notify();
    if (_awaitingCalibrationLine && a.type == AnnotationType.twoPointer) {
      _awaitingCalibrationLine = false;
      _showCalibrationDialogForLine(a);
    }
  }

  String _buildStampLabel() {
    if (!_stampEnabled) return 'Stamp Off';
    final lens = widget.image.lens ?? '-';
    final stored = calibrationController.calibrations[lens];
    if (stored == null) return '$lens - Not Set';
    final referenceText = stored.referenceLength % 1 == 0
        ? stored.referenceLength.toStringAsFixed(0)
        : stored.referenceLength.toStringAsFixed(2);
    final unitText = stored.unit == 'μm' ? 'Micron' : 'Nanometer';
    return '$lens - $referenceText $unitText';
  }

  List<Annotation> _annotationsForPaint() {
    if (!widget.showMeasurements) return const <Annotation>[];
    final lens = widget.image.lens;
    final cal = lens == null ? null : calibrationController.calibrations[lens];
    return _annotations.map((a) {
      final text = MeasurementCalculator.getMeasurementText(
        a,
        pixelsPerUnit: cal?.pixelsPerUnit,
        unit: cal?.unit,
      );
      if (text.trim().isEmpty) return a.copyWith(measurement: null);
      return a.copyWith(measurement: text);
    }).toList();
  }

  Future<void> _showCalibrationDialogForLine(Annotation latestDistance) async {
    final isTablet = Responsive.isTablet(context);
    final lens = widget.image.lens ?? '-';
    final stored = calibrationController.calibrations[lens];
    final knownController = TextEditingController(
      text: stored == null ? '' : stored.referenceLength.toStringAsFixed(0),
    );
    final px = _pixelDistance(latestDistance);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 420 : 360),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            decoration: AppTheme.softCardDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF2A295D),
            ),
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
                  'Enter the real distance for this line ($lens).',
                  style: const TextStyle(color: Color(0xFFD9DCF4), height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: knownController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Known distance',
                          labelStyle: const TextStyle(color: Color(0xFFAFB5D9)),
                          filled: true,
                          fillColor: const Color(0xFF1E2140),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _calibrationUnit,
                        dropdownColor: const Color(0xFF1E2140),
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'μm', child: Text('μm')),
                          DropdownMenuItem(value: 'nm', child: Text('nm')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _calibrationUnit = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Measured: ${px.toStringAsFixed(0)} px',
                  style: const TextStyle(color: Color(0xFFAFB5D9)),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final known = double.tryParse(knownController.text.trim());
    if (known == null || known <= 0 || px <= 0) return;
    final unitPerPixel = CalibrationCalculator.computeFactor(px, known);
    final calibration = StoredCalibration(
      lens: lens,
      unit: _calibrationUnit,
      unitPerPixel: unitPerPixel,
      pixelsPerUnit: 1.0 / unitPerPixel,
      referenceLength: known,
      measuredPixelDistance: px,
      createdAt: DateTime.now().toIso8601String(),
    );
    calibrationController.saveCalibration(calibration);
    if (!mounted) return;
    setState(() {
      // Reference line is only for calibration and should disappear after save.
      _annotations.removeWhere((a) => a.id == latestDistance.id);
    });
    _notify();
  }

  double _pixelDistance(Annotation ann) {
    if (ann.points.length < 2) return 0;
    final a = ann.points.first;
    final b = ann.points.last;
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return sqrt(dx * dx + dy * dy);
  }

  AnnotationType? get _annotationType {
    switch (_tool) {
      case ViewerDrawTool.draw:
        return AnnotationType.draw;
      case ViewerDrawTool.text:
        return AnnotationType.text;
      case ViewerDrawTool.distance:
        return AnnotationType.twoPointer;
      case ViewerDrawTool.point:
        return AnnotationType.singlePointer;
      case ViewerDrawTool.square:
        return AnnotationType.square;
      case ViewerDrawTool.circle:
        return AnnotationType.circle;
      case ViewerDrawTool.arrow:
        return AnnotationType.arrowOneWay;
      default:
        return null;
    }
  }

  String? _measurementFor(Annotation annotation) {
    if (_tool != ViewerDrawTool.distance) return null;
    final lens = widget.image.lens;
    final calibration =
        lens == null ? null : calibrationController.calibrations[lens];
    return MeasurementCalculator.getMeasurementText(
      annotation,
      pixelsPerUnit: calibration?.pixelsPerUnit,
      unit: calibration?.unit,
    );
  }

  HexaPoint _displayToSource(Offset point) {
    final sw = _lastSourceSize.width <= 0 ? 1.0 : _lastSourceSize.width;
    final sh = _lastSourceSize.height <= 0 ? 1.0 : _lastSourceSize.height;
    return HexaPoint(
      x: point.dx.clamp(0.0, sw),
      y: point.dy.clamp(0.0, sh),
    );
  }

  bool get _canMove =>
      !_locked && !_editingPaused && _tool == ViewerDrawTool.move;
  bool get _canErase =>
      !_locked && !_editingPaused && _tool == ViewerDrawTool.eraser;
  bool get _canStroke =>
      !_locked &&
      !_editingPaused &&
      _tool != null &&
      _tool != ViewerDrawTool.move &&
      _tool != ViewerDrawTool.eraser &&
      _tool != ViewerDrawTool.text;

  Future<void> _promptText(Offset local) async {
    final source = _displayToSource(local);
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF232651),
        title: const Text('Label', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter text',
            hintStyle: TextStyle(color: Colors.white38),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK', style: TextStyle(color: AppTheme.primaryLight)),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    final ann = Annotation(
      id: _uuid.v4(),
      type: AnnotationType.text,
      points: [source],
      text: text,
      color: _drawingColor,
      timestamp: DateTime.now().toIso8601String(),
    );
    setState(() => _annotations.add(ann));
    _pushAdd(ann);
  }

  void _onPanStart(DragStartDetails details) {
    if (_locked || _editingPaused) return;
    if (_tool == ViewerDrawTool.move) {
      final p = _displayToSource(details.localPosition);
      final hit = pickAnnotationAt(p, _annotations);
      if (hit != null) {
        _moveId = hit.id;
        _moveBefore = List.from(hit.points);
      }
      return;
    }
    if (_tool == ViewerDrawTool.eraser) {
      _eraserRemoved.clear();
      _eraseAt(details.localPosition);
      return;
    }
    final t = _annotationType;
    if (t == null) return;
    setState(() {
      _currentPoints = [_displayToSource(details.localPosition)];
      _lastDrawPoint = _currentPoints.first;
      _isDrawing = true;
    });
  }

  void _eraseAt(Offset local) {
    final p = _displayToSource(local);
    final toRemove = <DARemoveEntry>[];
    for (var i = 0; i < _annotations.length; i++) {
      final a = _annotations[i];
      if (annotationHitDistance(p, a) < 36) {
        toRemove.add(DARemoveEntry(annotation: a, index: i));
      }
    }
    if (toRemove.isEmpty) return;
    setState(() {
      for (final r in toRemove) {
        _annotations.removeWhere((x) => x.id == r.annotation.id);
      }
      _eraserRemoved.addAll(toRemove);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_locked || _editingPaused) return;
    if (_tool == ViewerDrawTool.move && _moveId != null) {
      final p0 = _displayToSource(details.localPosition - details.delta);
      final p1 = _displayToSource(details.localPosition);
      final dx = p1.x - p0.x;
      final dy = p1.y - p0.y;
      setState(() {
        final i = _annotations.indexWhere((a) => a.id == _moveId);
        if (i >= 0) {
          final sw = _lastSourceSize.width <= 0 ? 1.0 : _lastSourceSize.width;
          final sh = _lastSourceSize.height <= 0 ? 1.0 : _lastSourceSize.height;
          final pts = _annotations[i].points
              .map(
                (e) => HexaPoint(
                  x: (e.x + dx).clamp(0.0, sw),
                  y: (e.y + dy).clamp(0.0, sh),
                ),
              )
              .toList();
          _annotations[i] = _annotations[i].copyWith(points: pts);
        }
      });
      return;
    }
    if (_tool == ViewerDrawTool.eraser) {
      _eraseAt(details.localPosition);
      return;
    }
    if (!_isDrawing || _annotationType == null) return;
    final point = _displayToSource(details.localPosition);
    final prev = _lastDrawPoint;
    if (prev != null) {
      final dx = point.x - prev.x;
      final dy = point.y - prev.y;
      if ((dx * dx + dy * dy) < 1.8) {
        return;
      }
    }
    setState(() {
      if (_annotationType == AnnotationType.draw) {
        _currentPoints.add(point);
      } else {
        _currentPoints = [_currentPoints.first, point];
      }
      _lastDrawPoint = point;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_tool == ViewerDrawTool.move && _moveId != null && _moveBefore != null) {
      final id = _moveId!;
      final before = _moveBefore!;
      final i = _annotations.indexWhere((a) => a.id == id);
      if (i >= 0) {
        final after = List<HexaPoint>.from(_annotations[i].points);
        if (!_pointsEqual(before, after)) {
          _history.record(DAMove(id: id, before: before, after: after));
          _notify();
        }
      }
      _moveId = null;
      _moveBefore = null;
      return;
    }
    if (_tool == ViewerDrawTool.eraser) {
      if (_eraserRemoved.isNotEmpty) {
        _history.record(DARemoveBatch(List.from(_eraserRemoved)));
        _eraserRemoved.clear();
        _notify();
      }
      return;
    }
    if (!_isDrawing || _annotationType == null) return;
    final type = _annotationType!;
    if (type != AnnotationType.draw &&
        type != AnnotationType.text &&
        type != AnnotationType.singlePointer &&
        _currentPoints.length < 2) {
      setState(() {
        _currentPoints = [];
        _isDrawing = false;
        _lastDrawPoint = null;
      });
      return;
    }
    final preview = Annotation(
      id: '',
      type: type,
      points: _currentPoints,
      color: _drawingColor,
      timestamp: '',
    );
    final measurement = _measurementFor(preview);
    final ann = Annotation(
      id: _uuid.v4(),
      type: type,
      points: List.from(_currentPoints),
      color: _drawingColor,
      timestamp: DateTime.now().toIso8601String(),
      measurement: measurement != null && measurement.isNotEmpty
          ? measurement
          : null,
    );
    setState(() {
      _annotations.add(ann);
      _currentPoints = [];
      _isDrawing = false;
      _lastDrawPoint = null;
    });
    _pushAdd(ann);
  }

  EdgeInsets _resolvedPadding(BuildContext context) {
    if (widget.padding != null) return widget.padding!;
    final isTab = Responsive.isTablet(context);
    if (Responsive.isLandscapeTablet(context)) {
      return Responsive.cameraPreviewPadding(context);
    }
    final s = MediaQuery.sizeOf(context).shortestSide;
    final h = (s * 0.06).clamp(10.0, 22.0);
    final v = (s * 0.045).clamp(8.0, 18.0);
    final bottom = (s * 0.09).clamp(28.0, 56.0);
    return EdgeInsets.fromLTRB(
      isTab ? 72 : h + 36,
      isTab ? 34 : v + 16,
      isTab ? 72 : h + 36,
      isTab ? 56 : bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final uiTextScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.65);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Padding(
            padding: _resolvedPadding(context),
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  final source = Size(
                    image.sourceWidth ?? size.width,
                    image.sourceHeight ?? size.height,
                  );
                  _lastSourceSize = source;
                  final fitted = Size(
                    source.width <= 0 ? size.width : source.width,
                    source.height <= 0 ? size.height : source.height,
                  );
                  return FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: fitted.width,
                      height: fitted.height,
                      child: RepaintBoundary(
                        key: repaintBoundaryKey,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..rotateZ(widget.rotation * pi / 180)
                                  ..scaleByDouble(
                                    widget.mirrorX ? -1.0 : 1.0,
                                    widget.mirrorY ? -1.0 : 1.0,
                                    1.0,
                                    1.0,
                                  ),
                                child: ViewerFilterMatrix.wrap(
                                  widget.buildMedia(context),
                                  _filters,
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
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: _locked || _editingPaused
                                    ? null
                                    : (_tool == ViewerDrawTool.text
                                        ? (d) => _promptText(d.localPosition)
                                        : null),
                                onPanStart: (_canStroke || _canMove || _canErase)
                                    ? _onPanStart
                                    : null,
                                onPanUpdate: (_canStroke || _canMove || _canErase)
                                    ? _onPanUpdate
                                    : null,
                                onPanEnd: (_canStroke && _isDrawing) ||
                                        _canMove ||
                                        _canErase
                                    ? _onPanEnd
                                    : null,
                                child: CustomPaint(
                                  painter: AnnotationPainter(
                                    annotations: _annotationsForPaint(),
                                    currentDrawing: widget.showMeasurements &&
                                            _isDrawing &&
                                            _annotationType != null
                                        ? Annotation(
                                            id: 'current',
                                            type: _annotationType!,
                                            points: _currentPoints,
                                            color: _drawingColor,
                                            timestamp: '',
                                            measurement: _measurementFor(
                                              Annotation(
                                                id: '',
                                                type: _annotationType!,
                                                points: _currentPoints,
                                                color: _drawingColor,
                                                timestamp: '',
                                              ),
                                            ),
                                          )
                                        : null,
                                    displaySize: fitted,
                                    sourceSize: source,
                                    fit: BoxFit.contain,
                                    mirrorX: widget.mirrorX,
                                    mirrorY: widget.mirrorY,
                                    rotation: widget.rotation,
                                    uiTextScale: uiTextScale,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (_showToolsPanel) _buildToolsOverlay(context),
        if (_showColorRow && _showToolsPanel)
          Positioned(
            left: 20,
            right: 20,
            bottom: 120 + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: Wrap(
                spacing: 10,
                children: AppConstants.annotationColors
                    .map(
                      (color) => GestureDetector(
                        onTap: () =>
                            setState(() => _drawingColor = color),
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
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        if (widget.showFab)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: Material(
                color: const Color(0xFF232651),
                shape: const CircleBorder(),
                elevation: 6,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() {
                    _showToolsPanel = !_showToolsPanel;
                    if (!_showToolsPanel) _showColorRow = false;
                    widget.onEditorVisibilityChanged?.call(_showToolsPanel);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      _showToolsPanel ? Icons.close_rounded : Icons.edit_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToolsOverlay(BuildContext context) {
    final isTab = Responsive.isTablet(context);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: const Color(0xFF16182E),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Drawing Tools',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: closeEditor,
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stackLayout = constraints.maxWidth < 500;
                          if (stackLayout) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildToolGrid(context),
                                const SizedBox(height: 12),
                                _buildCameraSliders(context),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildToolGrid(context)),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: isTab ? 180 : 148,
                                child: _buildCameraSliders(context),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildToolBottomRow(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolGrid(BuildContext context) {
    Widget cell({
      required IconData icon,
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) {
      return Material(
        color: const Color(0xFF1E2140),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppTheme.primaryLight : Colors.white12,
                width: active ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.15,
      children: [
        cell(
          icon: Icons.pause_circle_outline_rounded,
          label: 'Pause',
          active: _editingPaused,
          onTap: () => setState(() {
            _editingPaused = !_editingPaused;
            if (_editingPaused) _tool = null;
          }),
        ),
        cell(
          icon: Icons.lock_outline_rounded,
          label: 'Lock',
          active: _locked,
          onTap: () => setState(() => _locked = !_locked),
        ),
        cell(
          icon: Icons.pan_tool_alt_outlined,
          label: 'Move',
          active: _tool == ViewerDrawTool.move,
          onTap: () => setState(() {
            _tool = _tool == ViewerDrawTool.move ? null : ViewerDrawTool.move;
            _showToolsPanel = false;
            _showColorRow = false;
          }),
        ),
        cell(
          icon: Icons.brush_rounded,
          label: 'Draw',
          active: _tool == ViewerDrawTool.draw,
          onTap: () => setState(() {
            _tool = ViewerDrawTool.draw;
            _editingPaused = false;
            _showToolsPanel = false;
            _showColorRow = false;
          }),
        ),
        cell(
          icon: Icons.text_fields_rounded,
          label: 'Text',
          active: _tool == ViewerDrawTool.text,
          onTap: () => setState(() {
            _tool = ViewerDrawTool.text;
            _editingPaused = false;
            _showToolsPanel = false;
            _showColorRow = false;
          }),
        ),
        cell(
          icon: Icons.straighten_rounded,
          label: 'Distance',
          active: _tool == ViewerDrawTool.distance,
          onTap: () => setState(() {
            _tool = ViewerDrawTool.distance;
            _editingPaused = false;
            _showToolsPanel = false;
            _showColorRow = false;
          }),
        ),
        cell(
          icon: Icons.place_outlined,
          label: 'Point',
          active: _tool == ViewerDrawTool.point,
          onTap: () => setState(() {
            _tool = ViewerDrawTool.point;
            _editingPaused = false;
            _showToolsPanel = false;
            _showColorRow = false;
          }),
        ),
        cell(
          icon: Icons.crop_square_rounded,
          label: 'Square',
          active: _tool == ViewerDrawTool.square,
          onTap: () => setState(() {
            _tool = ViewerDrawTool.square;
            _editingPaused = false;
            _showToolsPanel = false;
            _showColorRow = false;
          }),
        ),
        cell(
          icon: Icons.circle_outlined,
          label: 'Circle',
          active: _tool == ViewerDrawTool.circle,
          onTap: () => setState(() {
            _tool = ViewerDrawTool.circle;
            _editingPaused = false;
            _showToolsPanel = false;
            _showColorRow = false;
          }),
        ),
        cell(
          icon: Icons.arrow_right_alt_rounded,
          label: 'Arrow',
          active: _tool == ViewerDrawTool.arrow,
          onTap: () => setState(() {
            _tool = ViewerDrawTool.arrow;
            _editingPaused = false;
            _showToolsPanel = false;
            _showColorRow = false;
          }),
        ),
      ],
    );
  }

  Widget _buildCameraSliders(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Camera Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            InkWell(
              onTap: _resetViewerCameraSettings,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B295C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white70, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _slider(
          'Exposure',
          _filters.exposurePercent / 200,
          (v) => setState(() {
            _filters.exposurePercent = (v * 200).clamp(10, 200);
            widget.onFiltersChanged?.call(_filters);
          }),
          '${_filters.exposurePercent.round()}%',
        ),
        _slider(
          'ISO',
          (_filters.iso - 100) / 12700,
          (v) => setState(() {
            _filters.iso = 100 + v * 12700;
            widget.onFiltersChanged?.call(_filters);
          }),
          _filters.iso.round().toString(),
        ),
        _slider(
          'Temp',
          (_filters.temperatureK - 2000) / 10000,
          (v) => setState(() {
            _filters.temperatureK = 2000 + v * 10000;
            widget.onFiltersChanged?.call(_filters);
          }),
          '${_filters.temperatureK.round()}K',
        ),
        _slider(
          'Tint',
          (_filters.tint + 100) / 200,
          (v) => setState(() {
            _filters.tint = v * 200 - 100;
            widget.onFiltersChanged?.call(_filters);
          }),
          _filters.tint.round().toString(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _smallToggleButton(
                icon: Icons.bookmark_border_rounded,
                label: _buildStampLabel(),
                active: _stampEnabled,
                onTap: () {
                  setState(() => _stampEnabled = !_stampEnabled);
                  widget.onStampChanged?.call(_stampEnabled);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _smallToggleButton(
          icon: Icons.straighten_rounded,
          label: 'Calibrate',
          active: _showCalibrationSection,
          onTap: () => setState(
            () => _showCalibrationSection = !_showCalibrationSection,
          ),
        ),
        if (_showCalibrationSection) ...[
          const SizedBox(height: 10),
          _buildCalibrationSection(),
        ],
      ],
    );
  }

  void _resetViewerCameraSettings() {
    setState(() {
      _filters = ViewerFilters.fromCameraSettings(const CameraSettings());
    });
    widget.onFiltersChanged?.call(_filters);
  }

  Widget _smallToggleButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? const Color(0xFF232651) : const Color(0xFF1E2140),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalibrationSection() {
    final lens = widget.image.lens ?? '-';
    final stored = calibrationController.calibrations[lens];
    final hasStored = stored != null;
    final unit = hasStored ? stored.unit : _calibrationUnit;
    final unitLabel = unit == 'μm' ? 'Micron' : 'Nanometer';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2140),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CALIBRATION',
            style: TextStyle(
              color: const Color(0xFF9DA5CB),
              fontSize: Responsive.isTablet(context) ? 9 : 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$lens lens calibration',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasStored
                ? 'Saved calibration available.'
                : 'No saved calibration yet.',
            style: const TextStyle(color: Color(0xFFD9DCF4), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _smallToggleButton(
                  icon: Icons.edit_rounded,
                  label: _awaitingCalibrationLine
                      ? 'Draw line…'
                      : 'Set Calibration',
                  active: _awaitingCalibrationLine,
                  onTap: () {
                    setState(() {
                      _awaitingCalibrationLine = true;
                      _tool = ViewerDrawTool.distance;
                      _editingPaused = false;
                      _showToolsPanel = false;
                      _showColorRow = false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallToggleButton(
                  icon: Icons.swap_horiz_rounded,
                  label: unitLabel,
                  active: false,
                  onTap: () {
                    setState(() {
                      _calibrationUnit = _calibrationUnit == 'μm' ? 'nm' : 'μm';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasStored
                ? '${stored.unitPerPixel.toStringAsFixed(3)} ${stored.unit}/px'
                : '0 $unit/px',
            style: const TextStyle(color: Color(0xFFAFB5D9), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String name,
    double value01,
    ValueChanged<double> onChanged,
    String valueLabel,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text(valueLabel,
                  style: const TextStyle(color: Color(0xFF93A4D1), fontSize: 10)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value01.clamp(0.0, 1.0),
              activeColor: AppTheme.primaryLight,
              inactiveColor: Colors.white12,
              onChanged: (v) => onChanged(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolBottomRow(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _roundAction(
          icon: Icons.palette_outlined,
          label: 'Color',
          active: _showColorRow,
          onTap: () => setState(() => _showColorRow = !_showColorRow),
        ),
        _roundAction(
          icon: Icons.undo_rounded,
          label: 'Undo',
          highlight: canUndo,
          onTap: canUndo ? undo : null,
        ),
        _roundAction(
          icon: Icons.redo_rounded,
          label: 'Redo',
          highlight: canRedo,
          onTap: canRedo ? redo : null,
        ),
        _roundAction(
          icon: Icons.auto_fix_high_rounded,
          label: 'Eraser',
          active: _tool == ViewerDrawTool.eraser,
          onTap: () => setState(() {
            _tool = _tool == ViewerDrawTool.eraser ? null : ViewerDrawTool.eraser;
            _editingPaused = false;
          }),
        ),
        _roundAction(
          icon: Icons.delete_sweep_outlined,
          label: 'Clear',
          danger: true,
          active: false,
          onTap: _annotations.isEmpty
              ? null
              : () {
                  final snap = List<Annotation>.from(_annotations);
                  setState(() => _annotations.clear());
                  _history.record(DAClear(snap));
                  _notify();
                },
        ),
      ],
    );
  }

  Widget _roundAction({
    required IconData icon,
    required String label,
    bool active = false,
    bool highlight = false,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? AppTheme.danger : Colors.white;
    final borderColor =
        highlight ? AppTheme.primaryLight : Colors.white12;
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF232651) : const Color(0xFF1E2140),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: highlight ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  bool _pointsEqual(List<HexaPoint> a, List<HexaPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].x - b[i].x).abs() > 0.01 || (a[i].y - b[i].y).abs() > 0.01) {
        return false;
      }
    }
    return true;
  }
}
