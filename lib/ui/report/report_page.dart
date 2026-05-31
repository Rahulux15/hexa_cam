import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart' as cam;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/theme.dart';
import '../../data/models/folder.dart';
import '../../data/services/export_prefs.dart';
import '../../data/services/install_id_service.dart';
import '../../controllers/report_controller.dart';
import '../../data/models/annotation.dart';
import '../../data/models/image_data.dart';
import '../../data/models/report_data.dart';
import '../../data/services/database_service.dart';
import '../../data/services/file_service.dart';
import '../../data/services/video_export_service.dart';
import '../../state/app_registry.dart';
import '../../utils/app_logger.dart';
import '../../utils/marked_media_renderer.dart';
import '../../utils/responsive.dart';
import '../common/media_image.dart';
import '../common/responsive_action.dart';
import '../common/hexa_toast.dart';
import '../../controllers/async_action_controller.dart';

class ReportPage extends StatefulWidget {
  final String folderId;
  final Map<String, dynamic>? reportData;
  const ReportPage({super.key, required this.folderId, this.reportData});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final ReportController _reportController =
      Get.put(ReportController(), permanent: true);
  final AsyncActionController _asyncActions =
      Get.put(AsyncActionController(), permanent: true);
  final _orgController = TextEditingController(text: 'Organization Name');
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _reportNameController = TextEditingController();
  final _reportDescriptionController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Timer? _progressToastDebounce;
  final Map<String, Uint8List?> _pdfImageBytesCache = <String, Uint8List?>{};
  final List<_QueuedExportAction> _exportQueue = <_QueuedExportAction>[];
  _QueuedExportAction? _activeExport;
  _QueuedExportAction? _lastFailedExport;
  bool _exportCancelRequested = false;
  bool _processingExportQueue = false;
  String _activeExportStatus = '';
  double _activeExportProgress = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.reportData != null && widget.reportData!['images'] != null) {
      _items =
          (widget.reportData!['images'] as List).cast<Map<String, dynamic>>();
    }
    final formData = widget.reportData?['formData'];
    if (formData is Map<String, dynamic>) {
      final reportForm = ReportFormData.fromJson(formData);
      _orgController.text = reportForm.organizationName.isEmpty
          ? _orgController.text
          : reportForm.organizationName;
      _nameController.text = reportForm.fullName;
      _emailController.text = reportForm.email;
      _phoneController.text = reportForm.phone;
      _locationController.text = reportForm.location;
      _reportNameController.text = reportForm.reportName;
      _reportDescriptionController.text = reportForm.reportDescription;
    }
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _hydrateReportFieldsFromPrefs(notify: true));
  }

  /// Fills empty report fields from login / settings prefs (name, email; optional user_phone / user_address).
  Future<void> _hydrateReportFieldsFromPrefs({bool notify = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      void fillIfEmpty(TextEditingController c, String? v) {
        final t = (v ?? '').trim();
        if (c.text.trim().isEmpty && t.isNotEmpty) {
          c.text = t;
        }
      }

      fillIfEmpty(_nameController, prefs.getString('user_full_name'));
      fillIfEmpty(_emailController, prefs.getString('user_email'));
      fillIfEmpty(_phoneController, prefs.getString('user_phone'));
      fillIfEmpty(_locationController, prefs.getString('user_address'));
      if (notify && mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _progressToastDebounce?.cancel();
    _exportQueue.clear();
    _orgController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _reportNameController.dispose();
    _reportDescriptionController.dispose();
    super.dispose();
  }

  List<ImageData> get _reportImages =>
      _items.map((item) => ImageData.fromJson(item)).toList();

  String _pdfImageCacheKey(ImageData image) {
    final annSig = image.annotations
        .map(
          (a) =>
              '${a.id}:${a.type.name}:${a.strokeWidth}:${a.labelFontSize ?? 0}:${a.labelOffsetX}:${a.labelOffsetY}:${a.measurement ?? ''}:${a.points.length}',
        )
        .join('|');
    return [
      image.id,
      image.mediaId ?? '',
      image.thumbnailId ?? '',
      image.imageUrl,
      image.rotation?.toString() ?? '',
      image.mirrored?.toString() ?? '',
      image.isMarkingsBaked?.toString() ?? '',
      annSig,
    ].join('::');
  }

  ImageData? get _primaryImage =>
      _reportImages.isEmpty ? null : _reportImages.first;

  @override
  Widget build(BuildContext context) {
    final isTab = Responsive.isTablet(context);
    final pad = Responsive.pagePadding(context);
    final maxWidth = MediaQuery.sizeOf(context).width >= 1200 ? 900.0 : 760.0;
    final image = _primaryImage;
    final annotations = image?.annotations ?? const <Annotation>[];

    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: AppTheme.bgPrimary,
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(pad, 14, pad, 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF141430),
                      border: Border(
                          bottom: BorderSide(color: AppTheme.borderColor)),
                    ),
                    child: Row(
                      children: [
                        _circleButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: _goBackSafely),
                        const Spacer(),
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 320;
                              final buttonWidth = compact
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 12) / 2;
                              if (compact) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: constraints.maxWidth,
                                      child: ResponsiveActionButton(
                                        actionKey: 'report_download',
                                        asyncController: _asyncActions,
                                        onPressed: _downloadReport,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF232651),
                                          shadowColor: Colors.transparent,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.download_outlined,
                                                color: Colors.white),
                                            SizedBox(width: 10),
                                            Text(
                                              'Download',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: constraints.maxWidth,
                                      child: ResponsiveActionButton(
                                        actionKey: 'report_save',
                                        asyncController: _asyncActions,
                                        onPressed: _saveReport,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.save_alt_outlined,
                                                color: Colors.white),
                                            SizedBox(width: 10),
                                            Text(
                                              'Save',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: buttonWidth.clamp(120.0, 190.0),
                                    child: ResponsiveActionButton(
                                      actionKey: 'report_download',
                                      asyncController: _asyncActions,
                                      onPressed: _downloadReport,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF232651),
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.download_outlined,
                                              color: Colors.white),
                                          SizedBox(width: 10),
                                          Text(
                                            'Download',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: buttonWidth.clamp(110.0, 160.0),
                                    child: ResponsiveActionButton(
                                      actionKey: 'report_save',
                                      asyncController: _asyncActions,
                                      onPressed: _saveReport,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.save_alt_outlined,
                                              color: Colors.white),
                                          SizedBox(width: 10),
                                          Text(
                                            'Save',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      pad,
                      26,
                      pad,
                      32 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.description_outlined,
                                          color: Color(0xFF7472FF), size: 28),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Report Details',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: isTab ? 20 : 17,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isTab ? 26 : 20),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final twoColumns =
                                          constraints.maxWidth > 640;
                                      final fieldWidth = twoColumns
                                          ? (constraints.maxWidth - 24) / 2
                                          : constraints.maxWidth;
                                      final fields = [
                                        _FieldData(
                                            'Report Name',
                                            _reportNameController,
                                            Icons.badge_outlined,
                                            'Enter report name'),
                                        _FieldData(
                                            'Report Description',
                                            _reportDescriptionController,
                                            Icons.notes_outlined,
                                            'Enter report description',
                                            maxLines: 3),
                                        _FieldData(
                                            'Organization Name',
                                            _orgController,
                                            Icons.apartment_rounded,
                                            'Organization Name'),
                                        _FieldData(
                                            'Full Name',
                                            _nameController,
                                            Icons.person_outline_rounded,
                                            'Enter your name'),
                                        _FieldData(
                                            'Email Address',
                                            _emailController,
                                            Icons.alternate_email_rounded,
                                            'your.email@example.com'),
                                        _FieldData(
                                            'Phone Number',
                                            _phoneController,
                                            Icons.call_rounded,
                                            'Enter your phone number'),
                                        _FieldData(
                                            'Location',
                                            _locationController,
                                            Icons.location_on_outlined,
                                            'City, Country'),
                                      ];
                                      return Wrap(
                                        spacing: 24,
                                        runSpacing: 24,
                                        children: fields
                                            .map((field) => SizedBox(
                                                width: fieldWidth,
                                                child: _inputField(field)))
                                            .toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isTab ? 28 : 22),
                            _sectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons
                                              .settings_input_component_outlined,
                                          color: Color(0xFF7472FF),
                                          size: 26),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Camera Settings',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: isTab ? 20 : 17,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isTab ? 24 : 20),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: [
                                      _MetricCard(
                                          label: 'Exposure',
                                          value:
                                              '${(image?.cameraSettings.exposure ?? 100).round()}%'),
                                      _MetricCard(
                                          label: 'ISO',
                                          value:
                                              '${(image?.cameraSettings.iso ?? 400).round()}'),
                                      _MetricCard(
                                          label: 'Temperature',
                                          value:
                                              '${(image?.cameraSettings.temperature ?? 6500).round()}K'),
                                      _MetricCard(
                                          label: 'Tint',
                                          value:
                                              '${(image?.cameraSettings.tint ?? 0).round()}'),
                                      _MetricCard(
                                          label: 'Objective',
                                          value: image?.lens ?? '4X',
                                          highlight: true),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isTab ? 28 : 22),
                            if (image != null)
                              _sectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Marked Image',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: isTab ? 20 : 17,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Container(
                                        width: double.infinity,
                                        constraints: BoxConstraints(
                                            minHeight: isTab ? 360 : 280),
                                        color: const Color(0xFF1D284D),
                                        child: _buildPreviewImage(image),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (image != null)
                              SizedBox(height: isTab ? 28 : 22),
                            _sectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Summary',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: isTab ? 20 : 17,
                                    ),
                                  ),
                                  SizedBox(height: isTab ? 24 : 20),
                                  Wrap(
                                    spacing: 56,
                                    runSpacing: 18,
                                    children: [
                                      _summaryMetric('Total Annotations',
                                          '${annotations.length}'),
                                      _summaryMetric(
                                          'Measurement Mode',
                                          annotations.any((annotation) =>
                                                  (annotation.measurement ?? '')
                                                      .isNotEmpty)
                                              ? 'ON'
                                              : 'OFF'),
                                    ],
                                  ),
                                  if (annotations.isNotEmpty) ...[
                                    SizedBox(height: isTab ? 24 : 20),
                                    const Divider(color: AppTheme.borderColor),
                                    SizedBox(height: isTab ? 18 : 14),
                                    ...annotations.asMap().entries.map(
                                          (entry) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: _annotationRow(
                                                entry.key + 1, entry.value),
                                          ),
                                        ),
                                  ],
                                  if (annotations.isEmpty &&
                                      image != null &&
                                      image.isMarkingsBaked == true) ...[
                                    SizedBox(height: isTab ? 20 : 16),
                                    Text(
                                      'Markings are embedded in the marked image above '
                                      '(saved as one raster). There is no separate line-by-line list for this capture.',
                                      style: const TextStyle(
                                        color: Color(0xFFAFC0E4),
                                        height: 1.4,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(height: isTab ? 30 : 24),
                            _footerBrand(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_activeExport != null || _exportQueue.isNotEmpty)
            _buildExportQueueOverlay(context),
        ],
      ),
    );
  }

  Widget _buildExportQueueOverlay(BuildContext context) {
    final queuedCount = _exportQueue.length;
    final active = _activeExport;
    final canCancel = active != null && !_exportCancelRequested;
    final canRetry = _lastFailedExport != null && active == null;
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14 + MediaQuery.paddingOf(context).bottom,
      child: Material(
        color: const Color(0xE61A1D38),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      active == null
                          ? 'Export queue ready'
                          : '${active.label} in progress',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (queuedCount > 0)
                    Text(
                      '$queuedCount queued',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                ],
              ),
              if (active != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _activeExportProgress <= 0
                        ? null
                        : _activeExportProgress.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryLight),
                  ),
                ),
                if (_activeExportStatus.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _activeExportStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ],
              if (canCancel || canRetry || queuedCount > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (canCancel)
                      TextButton(
                        onPressed: _requestCancelActiveExport,
                        child: const Text('Cancel current'),
                      ),
                    if (canRetry)
                      TextButton(
                        onPressed: _retryLastFailedExport,
                        child: const Text('Retry failed'),
                      ),
                    if (queuedCount > 0 && active == null)
                      TextButton(
                        onPressed: _processExportQueue,
                        child: const Text('Run queue'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewImage(ImageData image) {
    final previewMediaId = image.type == MediaType.video
        ? ((image.thumbnailId?.isNotEmpty == true)
            ? image.thumbnailId
            : image.mediaId)
        : image.mediaId;
    final shouldOverlay =
        image.annotations.isNotEmpty && image.isMarkingsBaked != true;

    return MediaImage(
      source: image.imageUrl,
      mediaId: previewMediaId,
      // Use one deterministic overlay rule for both image and video previews
      // so report preview always mirrors final rendered output.
      annotations: shouldOverlay ? image.annotations : const [],
      burnAnnotationsIntoPreview: shouldOverlay,
      mirrorX: image.mirrored ?? false,
      rotation: image.rotation ?? 0,
      annotationSourceSize: (image.sourceWidth != null &&
              image.sourceHeight != null &&
              image.sourceWidth! > 0 &&
              image.sourceHeight! > 0)
          ? Size(image.sourceWidth!, image.sourceHeight!)
          : null,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorWidget: const Center(
          child: Icon(Icons.broken_image_outlined, color: AppTheme.textMuted)),
    );
  }

  Widget _annotationRow(int index, Annotation annotation) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1D284D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF343B7A),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('$index',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _annotationTitle(annotation.type),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  annotation.measurement?.isNotEmpty == true
                      ? annotation.measurement!
                      : 'Marked without measurement label',
                  style:
                      const TextStyle(color: Color(0xFFAFC0E4), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _annotationTitle(AnnotationType type) {
    switch (type) {
      case AnnotationType.draw:
        return 'Free Draw';
      case AnnotationType.text:
        return 'Text Label';
      case AnnotationType.arrow:
      case AnnotationType.arrowOneWay:
        return 'Arrow';
      case AnnotationType.circle:
        return 'Circle';
      case AnnotationType.rectangle:
      case AnnotationType.square:
        return 'Rectangle';
      case AnnotationType.twoPointer:
        return 'Distance';
      case AnnotationType.singlePointer:
        return 'Point Marker';
    }
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: const Color(0xFF232651),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.softCardDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF2A295D)),
      child: child,
    );
  }

  Widget _inputField(_FieldData field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(field.icon, color: const Color(0xFFC6CAE8), size: 20),
            const SizedBox(width: 8),
            Text(field.label,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: field.controller,
          maxLines: field.maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: field.hint,
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: const Color(0xFF1D284D),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF35517A))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF35517A))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryLight)),
          ),
        ),
      ],
    );
  }

  Widget _summaryMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFAFC0E4), fontSize: 14)),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _footerBrand() {
    return Container(
      padding: const EdgeInsets.only(top: 22),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/images/report_logo.png',
            width: 192,
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stackTrace) => Image.asset(
              'assets/images/about_logo.png',
              width: 192,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (_, fallbackError, fallbackStackTrace) =>
                  const SizedBox(width: 192, height: 60),
            ),
          ),
          Flexible(
            child: Text(
              'Generated by Hexa-Cam - Scientific Imaging & Microscopy Platform\n© 2026 All Rights Reserved',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFFAFC0E4), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enqueueExportAction(_QueuedExportAction action) async {
    if (_activeExport != null) {
      _exportQueue.add(action);
      if (mounted) setState(() {});
      _showMessage('${action.label} queued', AppTheme.success);
      return;
    }
    _exportQueue.add(action);
    if (mounted) setState(() {});
    await _processExportQueue();
  }

  Future<void> _processExportQueue() async {
    if (_processingExportQueue) return;
    _processingExportQueue = true;
    try {
      while (_exportQueue.isNotEmpty) {
        final action = _exportQueue.removeAt(0);
        _activeExport = action;
        _activeExportStatus = 'Preparing ${action.label.toLowerCase()}';
        _activeExportProgress = 0.0;
        _exportCancelRequested = false;
        if (mounted) setState(() {});
        try {
          await _runExportAction(action);
          _lastFailedExport = null;
        } on _ExportCancelled {
          _showMessage('${action.label} cancelled', AppTheme.warning);
        } catch (_) {
          _lastFailedExport = action;
          _showMessage(
              '${action.label} failed. You can retry.', AppTheme.danger);
        } finally {
          _activeExport = null;
          _activeExportStatus = '';
          _activeExportProgress = 0.0;
          _exportCancelRequested = false;
          if (mounted) setState(() {});
        }
      }
    } finally {
      _processingExportQueue = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _runExportAction(_QueuedExportAction action) async {
    _throwIfExportCancelled();
    if (action == _QueuedExportAction.download) {
      await _downloadReportNow();
    } else {
      await _saveReportNow();
    }
  }

  void _requestCancelActiveExport() {
    _exportCancelRequested = true;
    _activeExportStatus = 'Cancelling current export...';
    if (mounted) setState(() {});
  }

  void _retryLastFailedExport() {
    final failed = _lastFailedExport;
    if (failed == null) return;
    _lastFailedExport = null;
    _exportQueue.insert(0, failed);
    if (mounted) setState(() {});
    unawaited(_processExportQueue());
  }

  void _throwIfExportCancelled() {
    if (_exportCancelRequested) {
      throw const _ExportCancelled();
    }
  }

  Future<_ReportArtifacts> _buildReportArtifacts() async {
    _throwIfExportCancelled();
    await _hydrateReportFieldsFromPrefs();
    final reportImages = _reportImages;
    _throwIfExportCancelled();
    final imageBytes = <Uint8List?>[];
    for (final img in reportImages) {
      _throwIfExportCancelled();
      imageBytes.add(await _collectPdfImageBytes(img));
    }
    _throwIfExportCancelled();
    final logoBytes = await _loadReportLogoBytes();
    final pdfFonts = await _loadReportPdfFonts();
    final fonts = pdfFonts;
    final asciiMeasurementFallback = fonts == null;

    final includeProv = await ExportPrefs.includeProvenanceInPdf();
    final packageInfo = await PackageInfo.fromPlatform();
    final installId = await InstallIdService.getOrCreateId();
    Folder? folder;
    try {
      folder =
          foldersController.folders.firstWhere((f) => f.id == widget.folderId);
    } catch (_) {
      folder = null;
    }

    final appVer = '${packageInfo.version}+${packageInfo.buildNumber}';
    final provenanceLines = <String>[
      'App version: $appVer',
      'Non-secret install ID: $installId',
      'Report generated (UTC): ${DateTime.now().toUtc().toIso8601String()}',
      if (folder != null && (folder.inspectionSiteId?.isNotEmpty ?? false))
        'Inspection site / asset: ${folder.inspectionSiteId}',
      if (folder != null && (folder.inspectionOutcome?.isNotEmpty ?? false))
        'Inspection outcome: ${folder.inspectionOutcome}',
      if (folder != null && (folder.inspectionNotes?.isNotEmpty ?? false))
        'Inspection notes: ${folder.inspectionNotes}',
    ];
    for (var i = 0; i < reportImages.length; i++) {
      final shot = reportImages[i];
      final lens = shot.lens;
      final ts = shot.timestamp;
      final cal =
          lens == null ? null : calibrationController.calibrations[lens];
      provenanceLines.add(
        'Media ${i + 1}: lens=${lens ?? '-'}, capture=$ts, '
        'calibration saved=${cal?.createdAt ?? 'n/a'}',
      );
    }
    final canonical = jsonEncode({
      'appVersion': appVer,
      'installId': installId,
      'folderId': widget.folderId,
      'imageIds': reportImages.map((e) => e.id).toList(),
      'inspectionSiteId': folder?.inspectionSiteId,
      'inspectionOutcome': folder?.inspectionOutcome,
      'inspectionNotes': folder?.inspectionNotes,
    });
    final provenanceHash = sha256.convert(utf8.encode(canonical)).toString();

    final payload = <String, dynamic>{
      'provenanceEnabled': includeProv,
      'provenanceLines': provenanceLines,
      'provenanceHash': provenanceHash,
      'organizationName': _orgController.text.trim().isEmpty
          ? 'Organization Name'
          : _orgController.text.trim(),
      'fullName': _nameController.text.isEmpty ? '-' : _nameController.text,
      'email': _emailController.text.isEmpty ? '-' : _emailController.text,
      'phone': _phoneController.text.isEmpty ? '-' : _phoneController.text,
      'location':
          _locationController.text.isEmpty ? '-' : _locationController.text,
      'reportName': _reportNameController.text.trim(),
      'reportDescription': _reportDescriptionController.text.trim(),
      'date': DateTime.now().toIso8601String(),
      'reportDownloadStamp': _formatReportDownloadStamp(DateTime.now()),
      'logoBytes': logoBytes,
      if (fonts != null) 'fontRegular': fonts.regular,
      if (fonts != null) 'fontBold': fonts.bold,
      'pdfFontAsciiFallback': asciiMeasurementFallback,
      'primaryExposure': (reportImages.isEmpty
              ? 100
              : reportImages.first.cameraSettings.exposure)
          .round(),
      'primaryIso':
          (reportImages.isEmpty ? 400 : reportImages.first.cameraSettings.iso)
              .round(),
      'primaryTemperature': (reportImages.isEmpty
              ? 6500
              : reportImages.first.cameraSettings.temperature)
          .round(),
      'primaryTint':
          (reportImages.isEmpty ? 0 : reportImages.first.cameraSettings.tint)
              .round(),
      'entries':
          List<Map<String, dynamic>>.generate(reportImages.length, (index) {
        final image = reportImages[index];
        return {
          'title':
              reportImages.length > 1 ? 'Media ${index + 1}' : 'Marked Image',
          'imageBytes': imageBytes[index],
          'imageAspect': _imageAspectFromBytes(imageBytes[index]),
          'annotations': image.annotations
              .asMap()
              .entries
              .map(
                (entry) =>
                    '${entry.key + 1}. ${_annotationTitle(entry.value.type)}'
                    '${(entry.value.measurement ?? '').isNotEmpty ? ' - ${_pdfSafeText(entry.value.measurement!, forceAsciiUnits: asciiMeasurementFallback)}' : ''}',
              )
              .toList(),
          // Baked file shows markings but DB may have no annotation rows for PDF text.
          'embeddedMarkingsInImageOnly':
              image.annotations.isEmpty && image.isMarkingsBaked == true,
        };
      }),
    };

    final pdfBytes = await compute(_generateReportPdfInBackground, payload);
    return _ReportArtifacts(
      pdfBytes: pdfBytes,
      primaryPreviewBytes: imageBytes.isEmpty ? null : imageBytes.first,
    );
  }

  Future<({Uint8List regular, Uint8List bold})?> _loadReportPdfFonts() async {
    try {
      final regular =
          await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      final r = regular.buffer.asUint8List();
      final b = bold.buffer.asUint8List();
      if (r.isEmpty || b.isEmpty) return null;
      return (regular: r, bold: b);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _loadReportLogoBytes() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/report_logo.png');
      return logoBytes.buffer.asUint8List();
    } catch (_) {
      try {
        final fallback = await rootBundle.load('assets/images/about_logo.png');
        return fallback.buffer.asUint8List();
      } catch (_) {
        return null;
      }
    }
  }

  /// Local wall-clock stamp for PDF: `DD-MM-YYYY hh:mm:ss AM/PM`
  static String _formatReportDownloadStamp(DateTime dt) {
    final l = dt.toLocal();
    final dd = l.day.toString().padLeft(2, '0');
    final mm = l.month.toString().padLeft(2, '0');
    final yyyy = l.year.toString();
    var hour24 = l.hour;
    final min = l.minute.toString().padLeft(2, '0');
    final sec = l.second.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    var h12 = hour24 % 12;
    if (h12 == 0) h12 = 12;
    final hs = h12.toString().padLeft(2, '0');
    return '$dd-$mm-$yyyy $hs:$min:$sec $period';
  }

  bool _validateForm() {
    // Report form fields are optional; allow generate/save with empty values.
    return true;
  }

  Future<String?> _tryPersistReportPdfBytes(Uint8List bytes) async {
    if (kIsWeb) {
      final id = FileService.generateAssetId('report');
      try {
        await MediaDatabase.saveAsset(id, bytes);
        return id;
      } catch (e) {
        logDebug('Report PDF web store failed: $e');
        return null;
      }
    }
    const maxBlob = 3 * 1024 * 1024;
    if (bytes.length > maxBlob) {
      return null;
    }
    final id = FileService.generateAssetId('report');
    try {
      await MediaDatabase.saveAsset(id, bytes);
      return id;
    } catch (e) {
      logDebug('Report PDF MediaDatabase.saveAsset failed: $e');
      return null;
    }
  }

  Future<void> _downloadReport() async {
    await _enqueueExportAction(_QueuedExportAction.download);
  }

  Future<void> _downloadReportNow() async {
    if (!_validateForm()) return;
    try {
      _throwIfExportCancelled();
      final artifacts = await _buildReportArtifacts();
      _throwIfExportCancelled();
      final bytes = artifacts.pdfBytes;
      final filename = 'report-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final ok = await _reportController.downloadReport(
        bytes: bytes,
        filename: filename,
        folderName: widget.folderId,
        folderLabel: _folderLabel(),
        sharePositionOrigin: _sharePositionOrigin(),
        showMessage: _showMessage,
        onProgress: _showProgress,
      );
      _throwIfExportCancelled();
      if (!ok) return;

      if (!kIsWeb) {
        try {
          await _reportController.saveReportCopyToAppFolder(
            bytes: bytes,
            filename: filename,
            folderName: widget.folderId,
          );
        } catch (e, st) {
          logDebug('Report download: app folder copy failed: $e\n$st');
        }
      }

      final pdfAssetId = await _tryPersistReportPdfBytes(bytes);

      final primaryImage = _primaryImage;
      final previewAssetId = await _storeSavedReportPreviewAsset(
        primaryImage,
        cachedBytes: artifacts.primaryPreviewBytes,
      );
      final report = ReportData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filename: filename,
        timestamp: DateTime.now().toIso8601String(),
        pdfAssetId: pdfAssetId,
        previewImageUrl:
            _items.isNotEmpty ? (_items.first['imageUrl'] as String?) : null,
        previewImageAssetId: previewAssetId,
        description: 'Annotations: ${primaryImage?.annotations.length ?? 0}',
        lens: primaryImage?.lens,
        formData: ReportFormData(
          organizationName: _orgController.text,
          fullName: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          location: _locationController.text,
          reportName: _reportNameController.text,
          reportDescription: _reportDescriptionController.text,
        ),
        sourceImages: _items,
      );
      await foldersController.addReport(widget.folderId, report);
      _throwIfExportCancelled();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    } catch (_) {
      _showMessage('Failed to generate or download report', AppTheme.danger);
    }
  }

  Future<Uint8List?> _collectPdfImageBytes(ImageData? image) async {
    if (image == null) return null;
    _throwIfExportCancelled();
    final cacheKey = _pdfImageCacheKey(image);
    if (_pdfImageBytesCache.containsKey(cacheKey)) {
      return _pdfImageBytesCache[cacheKey];
    }
    try {
      final assetCandidates = <String>[
        // Video report previews should use still thumbnails first.
        if (image.type == MediaType.video &&
            image.thumbnailId != null &&
            image.thumbnailId!.isNotEmpty)
          image.thumbnailId!,
        if (image.type != MediaType.video &&
            image.mediaId != null &&
            image.mediaId!.isNotEmpty)
          image.mediaId!,
        if (image.type != MediaType.video &&
            image.thumbnailId != null &&
            image.thumbnailId!.isNotEmpty)
          image.thumbnailId!,
      ];
      for (final assetId in assetCandidates) {
        _throwIfExportCancelled();
        final bytes = await MediaDatabase.getAsset(assetId);
        if (bytes == null || bytes.isEmpty) continue;
        if (image.type == MediaType.video) {
          final shouldOverlay =
              image.annotations.isNotEmpty && image.isMarkingsBaked != true;
          if (!shouldOverlay) {
            final out = await _optimizePdfImageBytesAsync(bytes);
            _pdfImageBytesCache[cacheKey] = out;
            return out;
          }
          final prepared = await MarkedMediaRenderer.renderPhotoWithAnnotations(
            baseImageBytes: bytes,
            annotations: image.annotations,
            mirrorX: image.mirrored ?? false,
            mirrorY: false,
            rotation: image.rotation ?? 0,
            annotationSourceSize: (image.sourceWidth != null &&
                    image.sourceHeight != null &&
                    image.sourceWidth! > 0 &&
                    image.sourceHeight! > 0)
                ? Size(image.sourceWidth!, image.sourceHeight!)
                : null,
          );
          final out = await _optimizePdfImageBytesAsync(prepared);
          _pdfImageBytesCache[cacheKey] = out;
          return out;
        }
        if (image.isMarkingsBaked == true && image.annotations.isEmpty) {
          final out = await _optimizePdfImageBytesAsync(bytes);
          _pdfImageBytesCache[cacheKey] = out;
          return out;
        }
        final prepared = await _reportController.prepareMediaBytes(
          image: image,
          baseBytes: bytes,
        );
        final out = await _optimizePdfImageBytesAsync(prepared);
        _pdfImageBytesCache[cacheKey] = out;
        return out;
      }
      final source = image.imageUrl;
      if (kIsWeb && source.isNotEmpty) {
        try {
          final bytes = await cam.XFile(source).readAsBytes();
          if (bytes.isNotEmpty) {
            final prepared = await _reportController.prepareMediaBytes(
              image: image,
              baseBytes: bytes,
            );
            final out = await _optimizePdfImageBytesAsync(prepared);
            _pdfImageBytesCache[cacheKey] = out;
            return out;
          }
        } catch (_) {}
        if (source.startsWith('data:image/')) {
          final commaIndex = source.indexOf(',');
          if (commaIndex > 0 && commaIndex + 1 < source.length) {
            try {
              final b64 = source.substring(commaIndex + 1);
              final bytes = Uint8List.fromList(base64Decode(b64));
              if (bytes.isNotEmpty) {
                final prepared = await _reportController.prepareMediaBytes(
                  image: image,
                  baseBytes: bytes,
                );
                final out = await _optimizePdfImageBytesAsync(prepared);
                _pdfImageBytesCache[cacheKey] = out;
                return out;
              }
            } catch (_) {}
          }
        }
      }
      if (!kIsWeb && source.startsWith('file://')) {
        final filePath = source.replaceFirst('file://', '');
        if (image.type == MediaType.video) {
          final thumb = await VideoExportService.extractVideoThumbnailBytes(
            sourcePath: filePath,
          );
          if (thumb != null && thumb.isNotEmpty) {
            final prepared = await _reportController.prepareMediaBytes(
              image: image,
              baseBytes: thumb,
            );
            final out = await _optimizePdfImageBytesAsync(prepared);
            _pdfImageBytesCache[cacheKey] = out;
            return out;
          }
        }
        final bytes = await FileService.readBytes(filePath);
        final prepared = await _reportController.prepareMediaBytes(
          image: image,
          baseBytes: bytes,
        );
        final out = await _optimizePdfImageBytesAsync(prepared);
        _pdfImageBytesCache[cacheKey] = out;
        return out;
      }
      if (!kIsWeb &&
          source.isNotEmpty &&
          !source.startsWith('http://') &&
          !source.startsWith('https://') &&
          !source.startsWith('data:')) {
        if (image.type == MediaType.video) {
          final thumb = await VideoExportService.extractVideoThumbnailBytes(
            sourcePath: source,
          );
          if (thumb != null && thumb.isNotEmpty) {
            final prepared = await _reportController.prepareMediaBytes(
              image: image,
              baseBytes: thumb,
            );
            final out = await _optimizePdfImageBytesAsync(prepared);
            _pdfImageBytesCache[cacheKey] = out;
            return out;
          }
        }
        final bytes = await FileService.readBytes(source);
        final prepared = await _reportController.prepareMediaBytes(
          image: image,
          baseBytes: bytes,
        );
        final out = await _optimizePdfImageBytesAsync(prepared);
        _pdfImageBytesCache[cacheKey] = out;
        return out;
      }
      if (source.startsWith('http://') || source.startsWith('https://')) {
        try {
          final response = await http.get(Uri.parse(source));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            final prepared = await _reportController.prepareMediaBytes(
              image: image,
              baseBytes: Uint8List.fromList(response.bodyBytes),
            );
            final out = await _optimizePdfImageBytesAsync(prepared);
            _pdfImageBytesCache[cacheKey] = out;
            return out;
          }
        } catch (_) {}
      }
      _pdfImageBytesCache[cacheKey] = null;
      return null;
    } catch (_) {
      _pdfImageBytesCache[cacheKey] = null;
      return null;
    }
  }

  Future<Uint8List> _optimizePdfImageBytesAsync(Uint8List bytes) async {
    final optimized = await compute(_reportPdfOptimizeImageBytes, bytes);
    if (!await ExportPrefs.watermarkEnabled()) return optimized;
    return FileService.applyWatermarkForExport(optimized);
  }

  double? _imageAspectFromBytes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.height <= 0) return null;
    return decoded.width / decoded.height;
  }

  Future<void> _saveReport() async {
    await _enqueueExportAction(_QueuedExportAction.save);
  }

  Future<void> _saveReportNow() async {
    if (!_validateForm()) return;
    try {
      _throwIfExportCancelled();
      final artifacts = await _buildReportArtifacts();
      _throwIfExportCancelled();
      final bytes = artifacts.pdfBytes;
      final filename = 'report-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final ok = await _reportController.saveReport(
        bytes: bytes,
        filename: filename,
        folderName: widget.folderId,
        folderLabel: _folderLabel(),
        showMessage: _showMessage,
        onProgress: _showProgress,
      );
      _throwIfExportCancelled();
      if (!ok) return;

      final pdfAssetId = await _tryPersistReportPdfBytes(bytes);

      final primaryImage = _primaryImage;
      final previewAssetId = await _storeSavedReportPreviewAsset(
        primaryImage,
        cachedBytes: artifacts.primaryPreviewBytes,
      );
      final report = ReportData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filename: filename,
        timestamp: DateTime.now().toIso8601String(),
        pdfAssetId: pdfAssetId,
        previewImageUrl:
            _items.isNotEmpty ? (_items.first['imageUrl'] as String?) : null,
        previewImageAssetId: previewAssetId,
        description: 'Annotations: ${primaryImage?.annotations.length ?? 0}',
        lens: primaryImage?.lens,
        formData: ReportFormData(
          organizationName: _orgController.text,
          fullName: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          location: _locationController.text,
          reportName: _reportNameController.text,
          reportDescription: _reportDescriptionController.text,
        ),
        sourceImages: _items,
      );
      await foldersController.addReport(widget.folderId, report);
      _throwIfExportCancelled();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    } catch (_) {
      _showMessage('Failed to generate or save report', AppTheme.danger);
    }
  }

  void _showMessage(String text, Color backgroundColor) {
    if (!mounted) return;
    // Pending debounced progress would fire after success and replace the green
    // toast with a 100% bar (30s timer) — looks "stuck" on Android & iOS.
    _progressToastDebounce?.cancel();
    _progressToastDebounce = null;
    HexaToast.dismiss();
    final type = backgroundColor == AppTheme.danger
        ? HexaToastType.error
        : HexaToastType.success;
    HexaToast.show(context, text, type: type);
  }

  Future<String?> _storeSavedReportPreviewAsset(
    ImageData? image, {
    Uint8List? cachedBytes,
  }) async {
    if (image == null) return null;
    try {
      final previewBytes = cachedBytes ?? await _collectPdfImageBytes(image);
      if (previewBytes == null || previewBytes.isEmpty) return null;
      final previewAssetId = FileService.generateAssetId('report-preview');
      await MediaDatabase.saveAsset(previewAssetId, previewBytes);
      return previewAssetId;
    } catch (_) {
      return null;
    }
  }

  void _showProgress(String text, double progress) {
    if (!mounted) return;
    _activeExportStatus = text;
    _activeExportProgress = progress.clamp(0.0, 1.0);
    if (_exportCancelRequested) return;
    final p = progress.clamp(0.0, 1.0);
    // Final tick would schedule after [showMessage] and steal the overlay — skip.
    if (p >= 1.0) {
      _progressToastDebounce?.cancel();
      _progressToastDebounce = null;
      return;
    }
    // Avoid resetting the overlay on every tick (was 900ms + replace = flicker / "stuck" feel).
    _progressToastDebounce?.cancel();
    _progressToastDebounce = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      HexaToast.show(
        context,
        text,
        type: HexaToastType.info,
        progress: p,
        duration: const Duration(seconds: 30),
      );
    });
  }

  Rect _sharePositionOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const Rect.fromLTWH(0, 0, 1, 1);
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  String _folderLabel() {
    try {
      final folder =
          foldersController.folders.firstWhere((f) => f.id == widget.folderId);
      final name = folder.name.trim();
      return name.isEmpty ? widget.folderId : name;
    } catch (_) {
      return widget.folderId;
    }
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
}

class _ReportArtifacts {
  const _ReportArtifacts({
    required this.pdfBytes,
    required this.primaryPreviewBytes,
  });

  final Uint8List pdfBytes;
  final Uint8List? primaryPreviewBytes;
}

enum _QueuedExportAction {
  download('Download report'),
  save('Save report');

  const _QueuedExportAction(this.label);
  final String label;
}

class _ExportCancelled implements Exception {
  const _ExportCancelled();
}

class _FieldData {
  const _FieldData(this.label, this.controller, this.icon, this.hint,
      {this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final int maxLines;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: const Color(0xFF1D284D),
          borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFFAFC0E4), fontSize: 14)),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: highlight ? const Color(0xFF00E0FF) : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Measurement / annotation text for PDF. With embedded Noto Sans, keep real µ/nm.
/// Without fonts (bundle missing), fall back to ASCII "um" so Helvetica never tofu.
String _pdfSafeText(String text, {bool forceAsciiUnits = false}) {
  if (forceAsciiUnits) {
    return text
        .replaceAll('\u03BC', 'u')
        .replaceAll('\u03bc', 'u')
        .replaceAll('\u00b5', 'u')
        .replaceAll('\u00B5', 'u')
        .replaceAll('umm', 'um');
  }
  return text.replaceAll('umm', '\u00b5m');
}

/// Top-level for [compute] — keeps heavy JPEG resize off the UI isolate.
Uint8List _reportPdfOptimizeImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  const maxEdge = 2200;
  if (decoded.width <= maxEdge && decoded.height <= maxEdge) {
    return bytes;
  }
  final resized = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? maxEdge : null,
    height: decoded.height > decoded.width ? maxEdge : null,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 92));
}

Future<Uint8List> _generateReportPdfInBackground(
    Map<String, dynamic> payload) async {
  final regularBytes = payload['fontRegular'] as Uint8List?;
  final boldBytes = payload['fontBold'] as Uint8List?;
  final hasFonts = regularBytes != null &&
      boldBytes != null &&
      regularBytes.isNotEmpty &&
      boldBytes.isNotEmpty;
  final asciiFallback = payload['pdfFontAsciiFallback'] == true;

  final pdf = pw.Document(
    theme: hasFonts
        ? pw.ThemeData.withFont(
            base: pw.Font.ttf(ByteData.sublistView(regularBytes)),
            bold: pw.Font.ttf(ByteData.sublistView(boldBytes)),
          )
        : null,
  );
  final logoBytes = payload['logoBytes'] as Uint8List?;
  final logoProvider = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
  final downloadStamp = payload['reportDownloadStamp'] as String? ?? '';
  final entries = (payload['entries'] as List<dynamic>? ?? const <dynamic>[])
      .cast<Map<String, dynamic>>();

  pw.Widget metricMinimal(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(22),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      payload['organizationName'] as String? ??
                          'Organization Name',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Email: ${payload['email']}    Full name: ${payload['fullName']}',
                      style:
                          pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Phone: ${payload['phone']}    Address: ${payload['location']}',
                      style:
                          pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 10),
        ],
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoProvider != null)
                pw.SizedBox(
                  width: 140,
                  height: 44,
                  child: pw.Image(logoProvider, fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(width: 140, height: 44),
              pw.Expanded(
                child: pw.Text(
                  'Hexa-Cam — Scientific Imaging & Microscopy\n© 2026 All rights reserved',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          ),
        ],
      ),
      build: (context) => [
        if (((payload['reportName'] as String?) ?? '').trim().isNotEmpty)
          pw.Text(
            (payload['reportName'] as String).trim(),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        if (((payload['reportDescription'] as String?) ?? '').trim().isNotEmpty) ...[
          if (((payload['reportName'] as String?) ?? '').trim().isNotEmpty)
            pw.SizedBox(height: 8),
          pw.Text(
            (payload['reportDescription'] as String).trim(),
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
        if ((((payload['reportName'] as String?) ?? '').trim().isNotEmpty) ||
            (((payload['reportDescription'] as String?) ?? '').trim().isNotEmpty))
          pw.SizedBox(height: 16),
        pw.Text(
          'Camera settings',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            metricMinimal('Exposure', '${payload['primaryExposure']}%'),
            pw.SizedBox(width: 8),
            metricMinimal('ISO', '${payload['primaryIso']}'),
            pw.SizedBox(width: 8),
            metricMinimal('Temperature', '${payload['primaryTemperature']}K'),
            pw.SizedBox(width: 8),
            metricMinimal('Tint', '${payload['primaryTint']}'),
          ],
        ),
        pw.SizedBox(height: 18),
        ...entries.asMap().entries.expand((entry) {
          final section = entry.value;
          final bytes = section['imageBytes'] as Uint8List?;
          final aspect =
              (section['imageAspect'] as num?)?.toDouble() ?? (4 / 3);
          final safeAspect = aspect <= 0 ? (4 / 3) : aspect;
          final imageHeight =
              (340.0 / (safeAspect / (4 / 3))).clamp(220.0, 420.0).toDouble();
          final annotations =
              (section['annotations'] as List<dynamic>? ?? const <dynamic>[])
                  .map(
                    (e) => _pdfSafeText(
                      e.toString(),
                      forceAsciiUnits: asciiFallback,
                    ),
                  )
                  .toList();
          // Inseparable: [MultiPage] Column can split children across pages; keep title + image + markings together.
          return [
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(4),
                      border:
                          pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    ),
                    child: pw.Inseparable(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            section['title'] as String? ?? 'Marked Image',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          if (bytes != null && bytes.isNotEmpty)
                            pw.Container(
                              height: imageHeight,
                              width: double.infinity,
                              decoration: const pw.BoxDecoration(
                                  color: PdfColors.white),
                              child: pw.Image(pw.MemoryImage(bytes),
                                  fit: pw.BoxFit.contain),
                            )
                          else
                            pw.Container(
                              height: 340,
                              width: double.infinity,
                              alignment: pw.Alignment.center,
                              decoration: const pw.BoxDecoration(
                                  color: PdfColors.white),
                              child: pw.Text(
                                'No image available',
                                style: pw.TextStyle(
                                    fontSize: 9, color: PdfColors.grey600),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Text(
                    'Marking details',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  if (annotations.isEmpty)
                    pw.Text(
                      (section['embeddedMarkingsInImageOnly'] == true)
                          ? 'Markings are embedded in the image above (rasterized). '
                              'No separate line-by-line list was stored for this capture.'
                          : 'No markings available',
                      style:
                          pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    )
                  else
                    ...annotations.map(
                      (text) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(
                          text,
                          style: pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey800),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (entry.key != entries.length - 1) pw.SizedBox(height: 20),
          ];
        }),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.SizedBox(height: 12),
        if (payload['provenanceEnabled'] == true) ...[
          pw.Text(
            'Provenance & integrity',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          ...(payload['provenanceLines'] as List<dynamic>? ?? const <dynamic>[])
              .map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                e.toString(),
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'SHA-256 (canonical metadata): ${payload['provenanceHash']}',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 10),
        ],
        pw.Text(
          'Report downloaded: $downloadStamp',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  return pdf.save();
}
