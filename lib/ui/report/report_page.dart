import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart' as cam;
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../config/theme.dart';
import '../../controllers/report_controller.dart';
import '../../data/models/annotation.dart';
import '../../data/models/image_data.dart';
import '../../data/models/report_data.dart';
import '../../data/services/database_service.dart';
import '../../data/services/file_service.dart';
import '../../state/app_registry.dart';
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
  final ReportController _reportController = Get.put(ReportController(), permanent: true);
  final AsyncActionController _asyncActions =
      Get.put(AsyncActionController(), permanent: true);
  final _orgController = TextEditingController(text: 'Organization Name');
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  List<Map<String, dynamic>> _items = [];

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
    }
  }

  @override
  void dispose() {
    _orgController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  List<ImageData> get _reportImages =>
      _items.map((item) => ImageData.fromJson(item)).toList();

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
      body: Container(
        color: AppTheme.bgPrimary,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(pad, 14, pad, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF141430),
                  border:
                      Border(bottom: BorderSide(color: AppTheme.borderColor)),
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: ResponsiveActionButton(
                                    actionKey: 'report_download',
                                    asyncController: _asyncActions,
                                    onPressed: _downloadReport,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF232651),
                                      shadowColor: Colors.transparent,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.download_outlined, color: Colors.white),
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
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.save_alt_outlined, color: Colors.white),
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
                                    backgroundColor: const Color(0xFF232651),
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
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
                                      borderRadius: BorderRadius.circular(18),
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
                                  final twoColumns = constraints.maxWidth > 640;
                                  final fieldWidth = twoColumns
                                      ? (constraints.maxWidth - 24) / 2
                                      : constraints.maxWidth;
                                  final fields = [
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
                                      Icons.settings_input_component_outlined,
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
                        if (image != null) SizedBox(height: isTab ? 28 : 22),
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
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _annotationRow(
                                            entry.key + 1, entry.value),
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
    );
  }

  Widget _buildPreviewImage(ImageData image) {
    final previewMediaId = image.type == MediaType.video
        ? ((image.thumbnailId?.isNotEmpty == true)
              ? image.thumbnailId
              : image.mediaId)
        : image.mediaId;
    return MediaImage(
      source: image.imageUrl,
      mediaId: previewMediaId,
      annotations: image.annotations,
      burnAnnotationsIntoPreview:
          image.annotations.isNotEmpty && image.isMarkingsBaked != true,
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

  Future<Uint8List> _buildReportPdf() async {
    final reportImages = _reportImages;
    final imageBytes = <Uint8List?>[];
    for (final image in reportImages) {
      imageBytes.add(await _collectPdfImageBytes(image));
    }
    final logoBytes = await _loadReportLogoBytes();
    final payload = <String, dynamic>{
      'organizationName': _orgController.text.trim().isEmpty
          ? 'Organization Name'
          : _orgController.text.trim(),
      'fullName': _nameController.text.isEmpty ? '-' : _nameController.text,
      'email': _emailController.text.isEmpty ? '-' : _emailController.text,
      'phone': _phoneController.text.isEmpty ? '-' : _phoneController.text,
      'location': _locationController.text.isEmpty ? '-' : _locationController.text,
      'date': DateTime.now().toIso8601String(),
      'logoBytes': logoBytes,
      'primaryExposure': (reportImages.isEmpty
              ? 100
              : reportImages.first.cameraSettings.exposure)
          .round(),
      'primaryIso': (reportImages.isEmpty ? 400 : reportImages.first.cameraSettings.iso)
          .round(),
      'primaryTemperature': (reportImages.isEmpty
              ? 6500
              : reportImages.first.cameraSettings.temperature)
          .round(),
      'primaryTint': (reportImages.isEmpty ? 0 : reportImages.first.cameraSettings.tint)
          .round(),
      'entries': List<Map<String, dynamic>>.generate(reportImages.length, (index) {
        final image = reportImages[index];
        return {
          'title': reportImages.length > 1 ? 'Media ${index + 1}' : 'Marked Image',
          'imageBytes': imageBytes[index],
          'imageAspect': _imageAspectFromBytes(imageBytes[index]),
          'annotations': image.annotations
              .asMap()
              .entries
              .map(
                (entry) =>
                    '${entry.key + 1}. ${_annotationTitle(entry.value.type)}'
                    '${(entry.value.measurement ?? '').isNotEmpty ? ' - ${_pdfSafeText(entry.value.measurement!)}' : ''}',
              )
              .toList(),
        };
      }),
    };

    return compute(_generateReportPdfInBackground, payload);
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

  bool _validateForm() {
    // Report form fields are optional; allow generate/save with empty values.
    return true;
  }

  Future<void> _downloadReport() async {
    if (!_validateForm()) return;
    try {
      final bytes = await _buildReportPdf();
      final filename = 'report-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final ok = await _reportController.downloadReport(
        bytes: bytes,
        filename: filename,
        folderName: widget.folderId,
        folderLabel: _folderLabel(),
        showMessage: _showMessage,
        onProgress: _showProgress,
      );
      if (!ok) return;

      final assetId = FileService.generateAssetId('report');
      await MediaDatabase.saveAsset(assetId, bytes);

      final primaryImage = _primaryImage;
      final previewAssetId = await _storeSavedReportPreviewAsset(primaryImage);
      final report = ReportData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filename: filename,
        timestamp: DateTime.now().toIso8601String(),
        pdfAssetId: assetId,
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
        ),
        sourceImages: _items,
      );
      await foldersController.addReport(widget.folderId, report);
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
    try {
      final assetCandidates = <String>[
        // Video report previews should use still thumbnails first.
        if (image.type == MediaType.video &&
            image.thumbnailId != null &&
            image.thumbnailId!.isNotEmpty)
          image.thumbnailId!,
        if (image.mediaId != null && image.mediaId!.isNotEmpty) image.mediaId!,
        if (image.type != MediaType.video &&
            image.thumbnailId != null &&
            image.thumbnailId!.isNotEmpty)
          image.thumbnailId!,
      ];
      for (final assetId in assetCandidates) {
        final bytes = await MediaDatabase.getAsset(assetId);
        if (bytes == null || bytes.isEmpty) continue;
        if (image.isMarkingsBaked == true) {
          return _optimizePdfImageBytes(bytes);
        }
        final prepared = await _reportController.prepareMediaBytes(
          image: image,
          baseBytes: bytes,
        );
        return _optimizePdfImageBytes(prepared);
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
            return _optimizePdfImageBytes(prepared);
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
                return _optimizePdfImageBytes(prepared);
              }
            } catch (_) {}
          }
        }
      }
      if (!kIsWeb && source.startsWith('file://')) {
        final bytes = await FileService.readBytes(
          source.replaceFirst('file://', ''),
        );
        final prepared = await _reportController.prepareMediaBytes(
          image: image,
          baseBytes: bytes,
        );
        return _optimizePdfImageBytes(prepared);
      }
      if (!kIsWeb &&
          source.isNotEmpty &&
          !source.startsWith('http://') &&
          !source.startsWith('https://') &&
          !source.startsWith('data:')) {
        final bytes = await FileService.readBytes(source);
        final prepared = await _reportController.prepareMediaBytes(
          image: image,
          baseBytes: bytes,
        );
        return _optimizePdfImageBytes(prepared);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Uint8List _optimizePdfImageBytes(Uint8List bytes) {
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

  double? _imageAspectFromBytes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.height <= 0) return null;
    return decoded.width / decoded.height;
  }

  Future<void> _saveReport() async {
    if (!_validateForm()) return;
    try {
      final bytes = await _buildReportPdf();
      final filename = 'report-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final ok = await _reportController.saveReport(
        bytes: bytes,
        filename: filename,
        folderName: widget.folderId,
        folderLabel: _folderLabel(),
        showMessage: _showMessage,
        onProgress: _showProgress,
      );
      if (!ok) return;
      final assetId = FileService.generateAssetId('report');
      await MediaDatabase.saveAsset(assetId, bytes);

      final primaryImage = _primaryImage;
      final previewAssetId = await _storeSavedReportPreviewAsset(primaryImage);
      final report = ReportData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filename: filename,
        timestamp: DateTime.now().toIso8601String(),
        pdfAssetId: assetId,
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
        ),
        sourceImages: _items,
      );
      await foldersController.addReport(widget.folderId, report);
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
    final type = backgroundColor == AppTheme.danger
        ? HexaToastType.error
        : HexaToastType.success;
    HexaToast.show(context, text, type: type);
  }

  Future<String?> _storeSavedReportPreviewAsset(ImageData? image) async {
    if (image == null) return null;
    try {
      final previewBytes = await _collectPdfImageBytes(image);
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
    HexaToast.show(
      context,
      text,
      type: HexaToastType.info,
      progress: progress.clamp(0.0, 1.0),
      duration: const Duration(milliseconds: 900),
    );
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

class _FieldData {
  const _FieldData(this.label, this.controller, this.icon, this.hint);
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
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

String _pdfSafeText(String text) {
  // PDF default fonts often miss Greek mu (μ). Use micro sign (µ) for reliable rendering.
  final normalized = text.replaceAll('umm', 'μm');
  return normalized.replaceAllMapped(
    RegExp(r'\b(um|µm|μm)\b', caseSensitive: false),
    (_) => 'µm',
  );
}

Future<Uint8List> _generateReportPdfInBackground(Map<String, dynamic> payload) async {
  final pdf = pw.Document();
  final logoBytes = payload['logoBytes'] as Uint8List?;
  final logoProvider = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
  final generatedAt = DateTime.tryParse(payload['date'] as String? ?? '') ?? DateTime.now();
  final entries = (payload['entries'] as List<dynamic>? ?? const <dynamic>[])
      .cast<Map<String, dynamic>>();

  pw.Widget metric(String label, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 8),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
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
                      payload['organizationName'] as String? ?? 'Organization Name',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Email: ${payload['email']}    Full Name: ${payload['fullName']}',
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Phone: ${payload['phone']}'),
                    pw.SizedBox(height: 4),
                    pw.Text('Address: ${payload['location']}'),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Page: ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Date: ${generatedAt.day}-${generatedAt.month}-${generatedAt.year}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 14),
        ],
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logoProvider != null)
                pw.SizedBox(
                  width: 192,
                  height: 60,
                  child: pw.Image(logoProvider, fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(width: 192, height: 60),
              pw.Text(
                'Generated by Hexa-Cam - Scientific Imaging & Microscopy Platform\n© 2026 All Rights Reserved',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
      build: (context) => [
        pw.Text('Camera Settings', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            metric('Exposure', '${payload['primaryExposure']}%'),
            metric('ISO', '${payload['primaryIso']}'),
            metric('Temperature', '${payload['primaryTemperature']}K'),
            metric('Tint', '${payload['primaryTint']}'),
          ],
        ),
        pw.SizedBox(height: 18),
        ...entries.asMap().entries.expand((entry) {
          final section = entry.value;
          final bytes = section['imageBytes'] as Uint8List?;
          final aspect = (section['imageAspect'] as num?)?.toDouble() ?? (4 / 3);
          final safeAspect = aspect <= 0 ? (4 / 3) : aspect;
          final imageHeight = (340.0 / (safeAspect / (4 / 3))).clamp(220.0, 420.0).toDouble();
          final annotations = (section['annotations'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => _pdfSafeText(e.toString()))
              .toList();
          return [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    section['title'] as String? ?? 'Marked Image',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 12),
                  if (bytes != null && bytes.isNotEmpty)
                    pw.Container(
                      height: imageHeight,
                      width: double.infinity,
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Container(
                      height: 340,
                      width: double.infinity,
                      alignment: pw.Alignment.center,
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      child: pw.Text('No image available', style: const pw.TextStyle(fontSize: 10)),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Marking Details', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (annotations.isEmpty)
              pw.Text('No markings available')
            else
              ...annotations.map(
                (text) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(text),
                ),
              ),
            if (entry.key != entries.length - 1) pw.SizedBox(height: 20),
          ];
        }),
      ],
    ),
  );

  return pdf.save();
}
