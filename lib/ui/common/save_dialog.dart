import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/annotation.dart';
import '../../utils/responsive.dart';
import 'media_image.dart';

class SaveDialog extends StatefulWidget {
  final String? imageUrl;
  final String? mediaId;
  final List<Annotation> annotations;
  final bool isVideo;
  final Function(String filename, String description) onSave;
  final VoidCallback onCancel;

  const SaveDialog({
    super.key,
    this.imageUrl,
    this.mediaId,
    this.annotations = const [],
    this.isVideo = false,
    required this.onSave,
    required this.onCancel,
  });

  static Future<void> show(
    BuildContext context, {
    String? imageUrl,
    String? mediaId,
    List<Annotation> annotations = const [],
    bool isVideo = false,
    required Function(String, String) onSave,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SaveDialog(
        imageUrl: imageUrl,
        mediaId: mediaId,
        annotations: annotations,
        isVideo: isVideo,
        onSave: onSave,
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  State<SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<SaveDialog> {
  final _filenameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _dontAskAgain = false;

  @override
  void dispose() {
    _filenameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTab = Responsive.isTablet(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTab ? 420 : 360),
        child: Container(
          padding: EdgeInsets.all(isTab ? 26 : 22),
          decoration: AppTheme.softCardDecoration(borderRadius: BorderRadius.circular(22), color: const Color(0xFF2A295D)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Save Capture', style: TextStyle(color: Colors.white, fontSize: isTab ? 22 : 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            if (widget.imageUrl != null)
              Container(
                width: double.infinity,
                height: isTab ? 160 : 138,
                decoration: BoxDecoration(color: const Color(0xFF191737), borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MediaImage(
                    source: widget.imageUrl!,
                    mediaId: widget.mediaId,
                    annotations: widget.annotations,
                    fit: BoxFit.contain,
                    errorWidget: const Center(child: Icon(Icons.image_outlined, color: AppTheme.textMuted, size: 28)),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            _field(_filenameController, 'Enter file name'),
            const SizedBox(height: 14),
            _field(_descriptionController, 'Description', maxLines: 4),
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(child: Text("Don't Ask me Again", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              Switch(value: _dontAskAgain, onChanged: (value) => setState(() => _dontAskAgain = value), activeThumbColor: Colors.white, activeTrackColor: AppTheme.primary, inactiveThumbColor: Colors.white70, inactiveTrackColor: Colors.white24),
            ]),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _actionButton(label: 'Cancel', onTap: widget.onCancel),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _actionButton(label: 'Save', gradient: true, onTap: () { widget.onSave(_filenameController.text, _descriptionController.text); Navigator.pop(context); }),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: const Color(0xFF1D284D),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2E4A73))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2E4A73))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryLight)),
      ),
    );
  }

  Widget _actionButton({required String label, required VoidCallback onTap, bool gradient = false}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: gradient ? Colors.transparent : const Color(0xFF1D284D), shadowColor: Colors.transparent, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        child: Ink(
          decoration: BoxDecoration(gradient: gradient ? AppTheme.buttonGradient : null, color: gradient ? null : const Color(0xFF1D284D), borderRadius: BorderRadius.circular(18)),
          child: Center(child: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: Responsive.isTablet(context) ? 18 : 16))),
        ),
      ),
    );
  }
}
