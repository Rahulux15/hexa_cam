import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/theme.dart';
import '../../data/models/folder.dart';
import '../../data/models/image_data.dart';
import '../../data/models/report_data.dart';
import '../../data/services/database_service.dart';
import '../../controllers/report_controller.dart';
import '../../state/app_registry.dart';
import '../../utils/responsive.dart';
import '../common/media_image.dart';

class FolderDetailPage extends StatefulWidget {
  final String folderId;
  const FolderDetailPage({super.key, required this.folderId});
  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  bool _selectionMode = false;
  bool _gridView = true;
  final Set<String> _selectedImages = {};
  final Set<String> _selectedReports = {};
  Timer? _longPressTimer;
  final ReportController _reportController = Get.put(
    ReportController(),
    permanent: true,
  );

  Folder? _getFolder(List<Folder> folders) {
    try {
      return folders.firstWhere((folder) => folder.id == widget.folderId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FoldersController>(
      builder: (controller) {
        final folders = controller.folders;
        final folder = _getFolder(folders);
        if (folder == null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Get.offAllNamed<void>('/folders'));
          return const SizedBox();
        }
        return _buildFolderScaffold(context, folder);
      },
    );
  }

  Widget _buildFolderScaffold(BuildContext context, Folder folder) {
    final photos =
        folder.images.where((image) => image.type != MediaType.video).toList();
    final videos =
        folder.images.where((image) => image.type == MediaType.video).toList();
    final isTab = Responsive.isTablet(context);
    final pad = Responsive.pagePadding(context);
    final contentMaxWidth = Responsive.contentMaxWidth(context);

    return Scaffold(
      body: Container(
        color: AppTheme.bgPrimary,
        child: Column(children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(pad, 18, pad, 16),
              decoration: const BoxDecoration(
                  color: Color(0xFF141430),
                  border:
                      Border(bottom: BorderSide(color: AppTheme.borderColor))),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Row(children: [
                    _roundButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: _goBackSafely,
                        isTab: isTab),
                    SizedBox(width: isTab ? 20 : 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(folder.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTab ? 28 : 22,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Wrap(spacing: 18, runSpacing: 6, children: [
                              _headerStat(Icons.image_outlined,
                                  '${photos.length} photos'),
                              _headerStat(Icons.videocam_outlined,
                                  '${videos.length} videos'),
                            ]),
                          ]),
                    ),
                    _roundButton(
                        icon: _selectionMode
                            ? Icons.check_box_outlined
                            : Icons.checklist_rounded,
                        onTap: () => setState(() {
                              _selectionMode = !_selectionMode;
                              if (!_selectionMode) {
                                _clearSelection();
                              }
                            }),
                        isTab: isTab,
                        active: _selectionMode),
                    SizedBox(width: isTab ? 12 : 8),
                    _roundButton(
                        icon: _gridView
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        onTap: () => setState(() => _gridView = !_gridView),
                        isTab: isTab),
                  ]),
                ),
              ),
            ),
          ),
          if (_selectedCount > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: AppTheme.softCardDecoration(
                        borderRadius: BorderRadius.circular(18)),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 560;
                        if (!compact) {
                          return Row(children: [
                            Text('$_selectedCount selected',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            const Spacer(),
                            if (_selectedImages.isNotEmpty)
                              _selectionChip(
                                  'Report', AppTheme.primary, _generateReport),
                            if (_selectedImages.isNotEmpty)
                              const SizedBox(width: 8),
                            _selectionChip(
                                'Delete', AppTheme.danger, () => _deleteSelected()),
                            const SizedBox(width: 8),
                            _selectionChip(
                                'Cancel',
                                AppTheme.textMuted,
                                () => setState(_exitSelectionMode)),
                          ]);
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_selectedCount selected',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_selectedImages.isNotEmpty)
                                  _selectionChip('Report', AppTheme.primary,
                                      _generateReport),
                                _selectionChip(
                                    'Delete', AppTheme.danger, () => _deleteSelected()),
                                _selectionChip(
                                    'Cancel',
                                    AppTheme.textMuted,
                                    () => setState(_exitSelectionMode)),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, 24, pad, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (folder.images.isEmpty)
                          Container(
                            height: isTab ? 320 : 240,
                            width: double.infinity,
                            decoration: AppTheme.softCardDecoration(
                                borderRadius: BorderRadius.circular(22)),
                            child: Center(
                                child: Text('No media yet',
                                    style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: isTab ? 18 : 16))),
                          )
                        else if (_gridView)
                          Wrap(
                            spacing: isTab ? 22 : 16,
                            runSpacing: isTab ? 22 : 16,
                            children: folder.images
                                .map((image) =>
                                    _buildMediaCard(image, contentMaxWidth))
                                .toList(),
                          )
                        else
                          ...folder.images.map(_buildMediaListCard),
                        if (folder.reports != null &&
                            folder.reports!.isNotEmpty) ...[
                          SizedBox(height: isTab ? 34 : 28),
                          Text('Reports',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTab ? 22 : 18,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: isTab ? 14 : 12),
                          ...folder.reports!.map((report) => GestureDetector(
                                onTap: () => _onReportTap(report),
                                onLongPressStart: (_) => _queueReportSelection(report),
                                onLongPressEnd: (_) => _longPressTimer?.cancel(),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: AppTheme.softCardDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: _selectedReports.contains(report.id)
                                        ? AppTheme.primaryLight
                                        : const Color(0xFF343B7A),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1D284D),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: (report.previewImageUrl != null &&
                                              report.previewImageUrl!.isNotEmpty) ||
                                          (report.previewImageAssetId != null &&
                                              report.previewImageAssetId!.isNotEmpty)
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: MediaImage(
                                                source:
                                                    report.previewImageAssetId != null &&
                                                            report.previewImageAssetId!.isNotEmpty
                                                        ? ''
                                                        : report.previewImageUrl ?? '',
                                                mediaId: report.previewImageAssetId,
                                                annotations: const [],
                                                fit: BoxFit.contain,
                                                errorWidget: const Icon(
                                                    Icons.article_outlined,
                                                    color: Color(0xFF8F5CFF)),
                                              ),
                                            )
                                          : _buildReportPreviewFallback(report)
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                    Text(
                      report.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                                          const SizedBox(height: 6),
                                          Text(
                                            (report.formData != null &&
                                                    report
                                                        .formData!
                                                        .organizationName
                                                        .isNotEmpty)
                                                ? report
                                                    .formData!.organizationName
                                                : 'Saved report',
                                            style: const TextStyle(
                                                color: Color(0xFFAFC0E4)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                              _formatTimestamp(
                                                  report.timestamp),
                                              style: const TextStyle(
                                                  color: Color(0xFFAFC0E4),
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    if (_selectionMode)
                                      Icon(
                                        _selectedReports.contains(report.id)
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        color: _selectedReports.contains(report.id)
                                            ? AppTheme.primary
                                            : AppTheme.textMuted,
                                      )
                                    else
                                      IconButton(
                                        onPressed: () => _downloadReport(report),
                                        icon: const Icon(Icons.download_outlined,
                                            color: AppTheme.textMuted),
                                      ),
                                  ]),
                                ),
                              )),
                        ],
                      ]),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, 16 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(
                color: Color(0xFF141430),
                border: Border(top: BorderSide(color: AppTheme.borderColor))),
            child: SizedBox(
                width: double.infinity, child: _primaryFooterButton(isTab)),
          ),
        ]),
      ),
    );
  }

  Widget _headerStat(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: const Color(0xFFAFC0E4), size: 19),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Color(0xFFAFC0E4), fontSize: 15))
    ]);
  }

  Widget _roundButton(
      {required IconData icon,
      required VoidCallback onTap,
      required bool isTab,
      bool active = false}) {
    return Semantics(
      button: true,
      label: 'Action',
      child: Material(
        color: active ? const Color(0xFF2D2C68) : const Color(0xFF232651),
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: onTap,
          child: SizedBox(
            width: isTab ? 50 : 44,
            height: isTab ? 50 : 44,
            child: Icon(icon,
                color: active ? Colors.white : AppTheme.textSecondary,
                size: isTab ? 24 : 21),
          ),
        ),
      ),
    );
  }

  Widget _selectionChip(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.45))),
        child: Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }

  Widget _buildMediaCard(ImageData image, double screenWidth) {
    final selected = _selectedImages.contains(image.id);
    final cardWidth = screenWidth >= 1200
        ? 286.0
        : screenWidth >= 900
            ? 240.0
            : screenWidth >= 700
                ? (screenWidth - 72) / 2
                : double.infinity;
    return GestureDetector(
      onTap: () => _onMediaTap(image),
      onLongPressStart: (_) => _queueSelection(image),
      onLongPressEnd: (_) => _longPressTimer?.cancel(),
      child: SizedBox(
        width: cardWidth,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.softCardDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF2A2C63),
              border:
                  selected ? AppTheme.primaryLight : const Color(0xFF343B7A)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(children: [
              AspectRatio(
                aspectRatio: 1,
                child: _buildMediaPreview(
                  image,
                  layoutWidth: (cardWidth == double.infinity
                          ? MediaQuery.sizeOf(context).width - 72
                          : cardWidth) -
                      28,
                ),
              ),
              if (image.type == MediaType.video)
                const Positioned.fill(
                  child: Center(
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0x88000000),
                      child: Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
              if (image.annotations.isNotEmpty)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCC10162E),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${image.annotations.length} mark${image.annotations.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (selected)
                const Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.primary,
                        child:
                            Icon(Icons.check, size: 16, color: Colors.white))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaListCard(ImageData image) {
    final selected = _selectedImages.contains(image.id);
    return GestureDetector(
      onTap: () => _onMediaTap(image),
      onLongPressStart: (_) => _queueSelection(image),
      onLongPressEnd: (_) => _longPressTimer?.cancel(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.softCardDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF2A2C63),
            border: selected ? AppTheme.primaryLight : const Color(0xFF343B7A)),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 78,
              height: 78,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildMediaPreview(image, layoutWidth: 78),
                  if (image.annotations.isNotEmpty)
                    Positioned(
                      left: 5,
                      top: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xCC10162E),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '${image.annotations.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                    image.type == MediaType.video
                        ? Icons.videocam_outlined
                        : Icons.photo_outlined,
                    color: const Color(0xFF7472FF),
                    size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    image.filename ??
                        (image.type == MediaType.video ? 'Video' : 'Photo'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Color(0xFFAFC0E4), size: 14),
                const SizedBox(width: 6),
                Text(_formatTimestamp(image.timestamp),
                    style:
                        const TextStyle(color: Color(0xFFAFC0E4), fontSize: 14))
              ]),
            ]),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.primary, size: 24),
        ]),
      ),
    );
  }

  Widget _primaryFooterButton(bool isTab) {
    return SizedBox(
      height: Responsive.bottomBarHeight(context),
      child: ElevatedButton(
        onPressed: () => Get.toNamed<void>('/camera/${widget.folderId}'),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18))),
        child: Ink(
          decoration: BoxDecoration(
              gradient: AppTheme.buttonGradient,
              borderRadius: BorderRadius.circular(18)),
          child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.camera_alt_outlined,
                color: Colors.white, size: isTab ? 22 : 20),
            const SizedBox(width: 10),
            Text('Open Camera',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isTab ? 18 : 16))
          ])),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
      color: const Color(0xFF1D2249),
      child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: AppTheme.textMuted, size: 28)));

  /// [layoutWidth]: logical width of the image area (decode uses DPR × this cap).
  Widget _buildMediaPreview(ImageData image, {required double layoutWidth}) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeW = (layoutWidth * dpr * 1.5).round().clamp(512, 2300);

    final isVideo = image.type == MediaType.video;
    final hasThumb =
        image.thumbnailId != null && image.thumbnailId!.isNotEmpty;

    if (isVideo) {
      final source = hasThumb
          ? ''
          : (image.thumbnail != null && image.thumbnail!.isNotEmpty
              ? image.thumbnail!
              : image.imageUrl);
      return MediaImage(
        source: source,
        // Never decode video binary as image bytes.
        mediaId: hasThumb ? image.thumbnailId : null,
        annotations: const [],
        burnAnnotationsIntoPreview: true,
        mirrorX: image.mirrored ?? false,
        rotation: image.rotation ?? 0,
        annotationSourceSize: (image.sourceWidth != null &&
                image.sourceHeight != null &&
                image.sourceWidth! > 0 &&
                image.sourceHeight! > 0)
            ? Size(image.sourceWidth!, image.sourceHeight!)
            : null,
        fit: BoxFit.contain,
        cacheWidth: decodeW,
        errorWidget: _placeholder(),
      );
    }

    final baked = image.isMarkingsBaked == true;
    final previewMediaId = (image.thumbnailId?.isNotEmpty == true)
        ? image.thumbnailId
        : image.mediaId;
    final previewSource = (image.imageUrl.isNotEmpty)
        ? image.imageUrl
        : (image.thumbnail ?? '');
    return MediaImage(
      source: previewSource,
      mediaId: previewMediaId,
      annotations: baked ? const [] : image.annotations,
      burnAnnotationsIntoPreview: !baked,
      mirrorX: image.mirrored ?? false,
      rotation: image.rotation ?? 0,
      annotationSourceSize: (image.sourceWidth != null &&
              image.sourceHeight != null &&
              image.sourceWidth! > 0 &&
              image.sourceHeight! > 0)
          ? Size(image.sourceWidth!, image.sourceHeight!)
          : null,
      fit: BoxFit.contain,
      cacheWidth: decodeW,
      filterQuality: FilterQuality.high,
      errorWidget: _placeholder(),
    );
  } 

  Widget _buildReportPreviewFallback(ReportData report) {
    final sourceImages = report.sourceImages ?? const <Map<String, dynamic>>[];
    final isVideo = sourceImages.isNotEmpty &&
        (sourceImages.first['type']?.toString() == 'video');
    final annotationsCount = sourceImages.isNotEmpty
        ? ((sourceImages.first['annotations'] as List?)?.length ?? 0)
        : 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1D284D),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Icon(
              isVideo ? Icons.videocam_rounded : Icons.article_outlined,
              color: const Color(0xFF8F5CFF),
              size: 30,
            ),
          ),
        ),
        if (annotationsCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xCC10162E),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                '$annotationsCount mark${annotationsCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _queueSelection(ImageData image) {
    _longPressTimer = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _selectionMode = true;
        _selectedImages.add(image.id);
      });
    });
  }

  void _queueReportSelection(ReportData report) {
    _longPressTimer = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _selectionMode = true;
        _selectedReports.add(report.id);
      });
    });
  }

  void _onMediaTap(ImageData image) {
    if (_selectionMode) {
      setState(() {
        if (_selectedImages.contains(image.id)) {
          _selectedImages.remove(image.id);
        } else {
          _selectedImages.add(image.id);
        }
      });
      return;
    }
    Get.toNamed<void>('/image/${widget.folderId}/${image.id}');
  }

  void _onReportTap(ReportData report) {
    if (_selectionMode) {
      setState(() {
        if (_selectedReports.contains(report.id)) {
          _selectedReports.remove(report.id);
        } else {
          _selectedReports.add(report.id);
        }
        if (_selectedCount == 0) {
          _selectionMode = false;
        }
      });
      return;
    }
    _openSavedReport(report);
  }

  String _formatTimestamp(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final meridiem = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${parsed.month}/${parsed.day}/${parsed.year}, $hour:$minute:$meridiem';
  }

  int get _selectedCount => _selectedImages.length + _selectedReports.length;

  void _clearSelection() {
    _selectedImages.clear();
    _selectedReports.clear();
  }

  void _exitSelectionMode() {
    _clearSelection();
    _selectionMode = false;
  }

  Future<void> _deleteSelected() async {
    final folder = _getFolder(foldersController.folders);
    final selectedReports = folder == null
        ? const <ReportData>[]
        : [...?(folder.reports)]
            .where((report) => _selectedReports.contains(report.id))
            .toList();

    if (_selectedImages.isNotEmpty) {
      await foldersController.removeImages(widget.folderId, _selectedImages);
    }
    if (_selectedReports.isNotEmpty) {
      await foldersController.removeReports(widget.folderId, _selectedReports);
      for (final report in selectedReports) {
        if (report.pdfAssetId != null && report.pdfAssetId!.isNotEmpty) {
          await MediaDatabase.deleteAsset(report.pdfAssetId!);
        }
        if (report.previewImageAssetId != null &&
            report.previewImageAssetId!.isNotEmpty) {
          await MediaDatabase.deleteAsset(report.previewImageAssetId!);
        }
      }
    }
    if (!mounted) return;
    setState(_exitSelectionMode);
  }

  void _generateReport() {
    final folder = _getFolder(foldersController.folders);
    if (folder == null) return;
    final selected = folder.images
        .where((image) => _selectedImages.contains(image.id))
        .toList();
    if (selected.isEmpty) return;
    Get.toNamed<void>(
      '/report/${widget.folderId}',
      arguments: {
        'images': selected.map((image) => image.toJson()).toList(),
      },
    );
  }

  void _openSavedReport(ReportData report) {
    Get.toNamed<void>(
      '/report/${widget.folderId}',
      arguments: {
        'images': report.sourceImages ?? const <Map<String, dynamic>>[],
        'formData': report.formData?.toJson(),
      },
    );
  }

  Future<void> _downloadReport(ReportData report) async {
    if (report.pdfAssetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved PDF not found for this report'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    final bytes = await MediaDatabase.getAsset(report.pdfAssetId!);
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load report file'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    await _reportController.downloadReport(
      bytes: bytes,
      filename: report.filename,
      folderName: widget.folderId,
      showMessage: (message, color) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: color),
        );
      },
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
}



