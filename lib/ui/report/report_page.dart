import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../config/theme.dart';
import '../../controllers/report_controller.dart';
import '../../data/models/annotation.dart';
import '../../data/models/image_data.dart';
import '../../data/models/report_data.dart';
import '../../data/services/database_service.dart';
import '../../data/services/file_service.dart';
import '../../state/providers.dart';
import '../../utils/responsive.dart';
import '../common/media_image.dart';
import '../common/responsive_action.dart';
import '../../controllers/async_action_controller.dart';

class ReportPage extends ConsumerStatefulWidget {
  final String folderId;
  final Map<String, dynamic>? reportData;
  const ReportPage({super.key, required this.folderId, this.reportData});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
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
                        onTap: () => context.pop()),
                    const Spacer(),
                    SizedBox(
                      width: 170,
                      child: Tooltip(
                        message: 'Download to public Downloads + App Folder',
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
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 132,
                      child: Tooltip(
                        message: 'Save to App Folder only',
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
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, 26, pad, 32),
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
    return MediaImage(
      source: image.imageUrl,
      mediaId: image.mediaId,
      fit: BoxFit.contain,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: const Color(0xFF232651),
            borderRadius: BorderRadius.circular(22)),
        child: Icon(icon, color: Colors.white),
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
    final pdf = pw.Document();
    final logoBytes = await rootBundle.load('assets/images/report_logo.png');
    final logoProvider = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final now = DateTime.now();
    final reportImages = _reportImages;
    final imageProviders = <pw.ImageProvider?>[];
    for (final image in reportImages) {
      imageProviders.add(await _loadPdfImage(image));
    }
    final primary = reportImages.isEmpty ? null : reportImages.first;

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
                        _orgController.text.trim().isEmpty
                            ? 'Organization Name'
                            : _orgController.text.trim(),
                        style: pw.TextStyle(
                            fontSize: 24, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                          'Email: ${_emailController.text.isEmpty ? '-' : _emailController.text}    Full Name: ${_nameController.text.isEmpty ? '-' : _nameController.text}'),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          'Phone: ${_phoneController.text.isEmpty ? '-' : _phoneController.text}'),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          'Address: ${_locationController.text.isEmpty ? '-' : _locationController.text}'),
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
                    pw.Text('Date: ${now.day}-${now.month}-${now.year}',
                        style: const pw.TextStyle(fontSize: 10)),
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
                pw.SizedBox(
                  width: 192,
                  height: 60,
                  child: pw.Image(logoProvider, fit: pw.BoxFit.contain),
                ),
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
          pw.Text('Camera Settings',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pdfMetric('Exposure',
                  '${(primary?.cameraSettings.exposure ?? 100).round()}%'),
              _pdfMetric(
                  'ISO', '${(primary?.cameraSettings.iso ?? 400).round()}'),
              _pdfMetric('Temperature',
                  '${(primary?.cameraSettings.temperature ?? 6500).round()}K'),
              _pdfMetric(
                  'Tint', '${(primary?.cameraSettings.tint ?? 0).round()}'),
            ],
          ),
          pw.SizedBox(height: 18),
          ...reportImages.asMap().entries.expand((entry) {
            final image = entry.value;
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
                      reportImages.length > 1
                          ? 'Media ${entry.key + 1}'
                          : 'Marked Image',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    if (imageProviders.length > entry.key &&
                        imageProviders[entry.key] != null)
                      pw.Container(
                        height: 340,
                        width: double.infinity,
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey100),
                        child: pw.Image(
                          imageProviders[entry.key]!,
                          fit: pw.BoxFit.contain,
                        ),
                      )
                    else
                      pw.Container(
                        height: 340,
                        width: double.infinity,
                        alignment: pw.Alignment.center,
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey100),
                        child: pw.Text(
                          'No image available',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Marking Details',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              if (image.annotations.isEmpty)
                pw.Text('No markings available')
              else
                ...image.annotations.asMap().entries.map(
                      (a) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.Text(
                          '${a.key + 1}. ${_annotationTitle(a.value.type)}${(a.value.measurement ?? '').isNotEmpty ? ' - ${a.value.measurement}' : ''}',
                        ),
                      ),
                    ),
              if (entry.key != reportImages.length - 1) pw.SizedBox(height: 20),
            ];
          }),
        ],
      ),
    );

    return pdf.save();
  }

  bool _validateForm() {
    if (_orgController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty) {
      _showMessage(
        'Fill organization, name, email, and location before generating the report',
        AppTheme.danger,
      );
      return false;
    }
    return true;
  }

  Future<void> _downloadReport() async {
    if (!_validateForm()) return;
    final bytes = await _buildReportPdf();
    final filename = 'report-${DateTime.now().millisecondsSinceEpoch}.pdf';
    final ok = await _reportController.downloadReport(
      bytes: bytes,
      filename: filename,
      folderName: widget.folderId,
      showMessage: _showMessage,
    );
    if (!ok) return;

    final assetId = FileService.generateAssetId('report');
    await MediaDatabase.saveAsset(assetId, bytes);

    final preview =
        _items.isNotEmpty ? (_items.first['imageUrl'] as String?) : null;
    final primaryImage = _primaryImage;
    final report = ReportData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filename: filename,
      timestamp: DateTime.now().toIso8601String(),
      pdfAssetId: assetId,
      previewImageUrl: preview,
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
    ref.read(foldersProvider).addReport(widget.folderId, report);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  pw.Widget _pdfMetric(String label, String value) {
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
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<pw.ImageProvider?> _loadPdfImage(ImageData? image) async {
    if (image == null) return null;
    try {
      if (image.mediaId != null && image.mediaId!.isNotEmpty) {
        final bytes = await MediaDatabase.getAsset(image.mediaId!);
        if (bytes != null && bytes.isNotEmpty) {
          return pw.MemoryImage(bytes);
        }
      }
      final source = image.imageUrl;
      if (!kIsWeb && source.startsWith('file://')) {
        final bytes = await FileService.readBytes(
          source.replaceFirst('file://', ''),
        );
        return pw.MemoryImage(bytes);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveReport() async {
    if (!_validateForm()) return;
    final bytes = await _buildReportPdf();
    final filename = 'report-${DateTime.now().millisecondsSinceEpoch}.pdf';
    final ok = await _reportController.saveReport(
      bytes: bytes,
      filename: filename,
      folderName: widget.folderId,
      showMessage: _showMessage,
    );
    if (!ok) return;
    final assetId = FileService.generateAssetId('report');
    await MediaDatabase.saveAsset(assetId, bytes);

    final preview =
        _items.isNotEmpty ? (_items.first['imageUrl'] as String?) : null;
    final primaryImage = _primaryImage;
    final report = ReportData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filename: filename,
      timestamp: DateTime.now().toIso8601String(),
      pdfAssetId: assetId,
      previewImageUrl: preview,
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
    ref.read(foldersProvider).addReport(widget.folderId, report);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  void _showMessage(String text, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: backgroundColor),
    );
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
