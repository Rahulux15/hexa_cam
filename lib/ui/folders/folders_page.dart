import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../data/models/folder.dart';
import '../../data/models/image_data.dart';
import '../../state/providers.dart';
import '../../utils/responsive.dart';

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});
  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _newFolderController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _newFolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folders = foldersController.folders;
    final filtered = _searchQuery.isEmpty
        ? folders
        : folders
            .where((folder) =>
                folder.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
    final totalImages =
        folders.fold<int>(0, (sum, folder) => sum + folder.imageCount);
    final totalVideos =
        folders.fold<int>(0, (sum, folder) => sum + folder.videoCount);
    final totalReports = folders.fold<int>(
        0, (sum, folder) => sum + (folder.reports?.length ?? 0));
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
              padding: EdgeInsets.fromLTRB(pad, 14, pad, 12),
              decoration: const BoxDecoration(
                  color: Color(0xFF141430),
                  border:
                      Border(bottom: BorderSide(color: AppTheme.borderColor))),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: _buildBrand(isTab)),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: _showCreateDialog,
                          ),
                          const SizedBox(width: 5),
                          _circleIconButton(
                              icon: Icons.settings,
                              onTap: () => context.push('/settings'),
                              size: isTab ? 38 : 34)
                        ]),
                        SizedBox(height: isTab ? 10 : 8),
                        TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: isTab ? 14 : 12),
                          decoration: InputDecoration(
                            hintText: 'Search folders...',
                            hintStyle:
                                const TextStyle(color: AppTheme.textMuted),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: AppTheme.textMuted),
                            filled: true,
                            fillColor: const Color(0xFF24234F),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: isTab ? 12 : 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE6E6FA))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE6E6FA))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppTheme.primaryLight)),
                          ),
                        ),
                      ]),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, 14, pad, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(
                            isTab: isTab,
                            folders: folders.length,
                            images: totalImages,
                            videos: totalVideos,
                            reports: totalReports),
                        SizedBox(height: isTab ? 12 : 10),
                        if (filtered.isEmpty)
                          Container(
                            width: double.infinity,
                            padding:
                                EdgeInsets.symmetric(vertical: isTab ? 80 : 60),
                            decoration: AppTheme.softCardDecoration(),
                            child: Text('No folders found',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: isTab ? 18 : 16)),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final crossSpacing = isTab ? 12.0 : 10.0;
                              final columns = constraints.maxWidth >= 1100
                                  ? 3
                                  : constraints.maxWidth >= 720
                                      ? 2
                                      : 1;
                              final itemWidth = (constraints.maxWidth -
                                      (crossSpacing * (columns - 1))) /
                                  columns;
                              return Wrap(
                                spacing: crossSpacing,
                                runSpacing: crossSpacing,
                                children: filtered
                                    .asMap()
                                    .entries
                                    .map((entry) => SizedBox(
                                          width: itemWidth,
                                          child: _buildFolderCard(
                                              entry.value, entry.key),
                                        ))
                                    .toList(),
                              );
                            },
                          ),
                      ]),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                12, 10, 12, 12 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(
                color: Color(0xFF141430),
                border: Border(top: BorderSide(color: AppTheme.borderColor))),
            child: SizedBox(
                width: double.infinity,
                child: _gradientButton(context,
                    icon: Icons.create_new_folder_rounded,
                    label: 'Create New Folder',
                    onTap: _showCreateDialog)),
          ),
        ]),
      ),
    );
  }

  Widget _buildBrand(bool isTab) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ShaderMask(
        shaderCallback: (bounds) => AppTheme.buttonGradient.createShader(bounds),
        child: Text('Hexa-Cam',
            style: TextStyle(
                fontSize: isTab ? 22 : 18,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ),
      const SizedBox(height: 2),
      Text('Organize your microscopy images',
          style: TextStyle(
              color: const Color(0xFF93A4D1), fontSize: isTab ? 12 : 10)),
    ]);
  }

  Widget _buildStatsRow(
      {required bool isTab,
      required int folders,
      required int images,
      required int videos,
      required int reports}) {
    final cards = [
      _StatData(Icons.folder_open_outlined, 'Folders', '$folders',
          const Color(0xFF7472FF)),
      _StatData(Icons.photo_library_outlined, 'Images', '$images',
          const Color(0xFF00C8FF)),
      _StatData(Icons.videocam_outlined, 'Videos', '$videos',
          const Color(0xFFDCE1EE)),
      _StatData(Icons.description_outlined, 'Reports', '$reports',
          const Color(0xFF8F5CFF)),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final twoColumns = constraints.maxWidth < 900;
      final itemWidth = twoColumns
          ? (constraints.maxWidth - 12) / 2
          : (constraints.maxWidth - 36) / 4;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map((card) => SizedBox(
                  width: itemWidth,
                  child: Container(
                    constraints: BoxConstraints(minHeight: isTab ? 78 : 70),
                    padding: EdgeInsets.symmetric(
                        horizontal: isTab ? 12 : 10, vertical: isTab ? 10 : 8),
                    decoration: AppTheme.softCardDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF202050)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(card.icon,
                            color: card.color, size: isTab ? 14 : 13),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: isTab ? 8 : 6),
                            Text(card.value,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTab ? 16 : 14,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(card.label,
                                style: TextStyle(
                                    color: const Color(0xFFAFC0E4),
                                    fontSize: isTab ? 10 : 9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(),
      );
    });
  }

  Widget _buildFolderCard(Folder folder, int index) {
    final isTab = Responsive.isTablet(context);
    final images =
        folder.images.where((item) => item.type != MediaType.video).length;
    final videos =
        folder.images.where((item) => item.type == MediaType.video).length;
    final created = _formatDate(folder.createdAt);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(opacity: value, child: child)),
      child: GestureDetector(
          onTap: () => context.push('/folder/${folder.id}'),
          child: Container(
            constraints: BoxConstraints(minHeight: isTab ? 92 : 82),
            padding: EdgeInsets.symmetric(
              horizontal: isTab ? 16 : 14,
              vertical: isTab ? 10 : 8,
            ),
            decoration: AppTheme.softCardDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF232651)),
            child: Row(children: [
              Container(
                width: isTab ? 46 : 40,
                height: isTab ? 46 : 40,
                decoration: BoxDecoration(
                    gradient: AppTheme.buttonGradient,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.folder_open_outlined,
                    color: Colors.white, size: 20),
              ),
              SizedBox(width: isTab ? 14 : 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: isTab ? 16 : 14)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _tinyMeta(Icons.photo_library_outlined, '$images'),
                      const SizedBox(width: 10),
                      _tinyMeta(Icons.videocam_outlined, '$videos'),
                      const SizedBox(width: 10),
                      _tinyMeta(Icons.calendar_today_outlined, created),
                    ]),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'rename') {
                      _showRenameDialog(folder);
                    } else {
                      try {
                        await foldersController.deleteFolder(folder.id);
                        if (mounted) setState(() {});
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Delete failed: $error')),
                        );
                      }
                    }
                  },
                  padding: EdgeInsets.zero,
                  color: AppTheme.bgCardSoft,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.borderColor)),
                  icon: Container(
                    width: isTab ? 28 : 26,
                    height: isTab ? 28 : 26,
                    decoration: BoxDecoration(
                        color: const Color(0xFF1D2249),
                        borderRadius: BorderRadius.circular(17)),
                    child: const Icon(Icons.more_vert_rounded,
                        color: AppTheme.textMuted),
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete'))
                  ],
                ),
            ]),
          ),
        ),
    );
  }

  Widget _tinyMeta(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: const Color(0xFFAFC0E4)),
      const SizedBox(width: 3),
      Text(text,
          style: const TextStyle(
              color: Color(0xFFAFC0E4), fontSize: 10, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _circleIconButton(
      {required IconData icon,
      required VoidCallback onTap,
      required double size}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: const Color(0xFF232651),
            borderRadius: BorderRadius.circular(size / 2)),
        child: Icon(icon, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _gradientButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    final isTab = Responsive.isTablet(context);
    return SizedBox(
      height: Responsive.bottomBarHeight(context),
      child: ElevatedButton(
        onPressed: onTap,
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
              Icon(icon, color: Colors.white, size: isTab ? 16 : 14),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: isTab ? 12 : 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  void _showCreateDialog() {
    _newFolderController.clear();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => _folderDialog(
        context: dialogContext,
        title: 'Create New Folder',
        controller: _newFolderController,
        hintText: 'Folder name...',
        primaryLabel: 'Create',
        onPrimary: () async {
          if (_newFolderController.text.trim().isEmpty) return;
          try {
            await foldersController.createFolder(_newFolderController.text.trim());
          } catch (error) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text('Create failed: $error')),
              );
            }
            return;
          }
          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _showRenameDialog(Folder folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => _folderDialog(
        context: dialogContext,
        title: 'Rename Folder',
        controller: controller,
        hintText: 'Folder name...',
        primaryLabel: 'Rename',
        onPrimary: () async {
          if (controller.text.trim().isEmpty) return;
          try {
            await foldersController.renameFolder(folder.id, controller.text.trim());
          } catch (error) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text('Rename failed: $error')),
              );
            }
            return;
          }
          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _folderDialog({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
    required String hintText,
    required String primaryLabel,
    required FutureOr<void> Function() onPrimary,
  }) {
    final isTab = Responsive.isTablet(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTab ? 460 : 380),
        child: Container(
          padding: EdgeInsets.all(isTab ? 26 : 24),
          decoration: AppTheme.softCardDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFF2A295D),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTab ? 22 : 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: const Color(0xFF1D284D),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    borderSide: const BorderSide(color: AppTheme.primaryLight),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _dialogActionButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _dialogActionButton(
                      label: primaryLabel,
                      onTap: onPrimary,
                      primary: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogActionButton({
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: primary ? AppTheme.buttonGradient : null,
            color: primary ? null : const Color(0xFF1D284D),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value.length >= 10 ? value.substring(0, 10) : value;
    }
    return '${parsed.month}/${parsed.day}/${parsed.year}';
  }
}

class _StatData {
  const _StatData(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final String value;
  final Color color;
}



