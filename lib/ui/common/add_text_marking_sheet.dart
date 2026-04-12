import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/responsive.dart';

/// Text tool: bottom sheet with keyboard-safe insets ([isScrollControlled]).
/// Padding uses [MediaQuery.viewInsets.bottom] so the field and slider stay
/// visible without blank scroll gaps.
class AddTextMarkingSheet {
  AddTextMarkingSheet._();

  /// Returns `{'text': String, 'size': double}` or null if dismissed.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required double initialTextSize,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTextMarkingBody(
        initialSize: initialTextSize.clamp(8.0, 52.0),
      ),
    );
  }
}

class _AddTextMarkingBody extends StatefulWidget {
  const _AddTextMarkingBody({required this.initialSize});

  final double initialSize;

  @override
  State<_AddTextMarkingBody> createState() => _AddTextMarkingBodyState();
}

class _AddTextMarkingBodyState extends State<_AddTextMarkingBody> {
  late final TextEditingController _controller;
  late double _textSize;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _textSize = widget.initialSize;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final maxW = Responsive.isTablet(context) ? 520.0 : double.infinity;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + safeBottom),
              child: Material(
                color: const Color(0xFF2B295C),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Add Text',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white54),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _controller,
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
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text(
                            'Font size',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          Text(
                            '${_textSize.toStringAsFixed(1)} px',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        min: 8.0,
                        max: 52.0,
                        divisions: 44,
                        value: _textSize,
                        onChanged: (v) => setState(() => _textSize = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, {
                              'text': _controller.text.trim(),
                              'size': _textSize,
                            }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(color: Colors.white),
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
        ),
      ),
    );
  }
}
