import 'dart:async';

import 'package:flutter/material.dart';

enum HexaToastType { success, error, info, warning }

class HexaToast {
  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;

  /// Removes the active toast immediately (e.g. before showing success after progress).
  static void dismiss() {
    _activeTimer?.cancel();
    _activeTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }

  static void show(
    BuildContext context,
    String message, {
    HexaToastType type = HexaToastType.success,
    Duration duration = const Duration(seconds: 2),
    double? progress,
    /// Extra offset below the status bar / safe-area top (e.g. dense top chrome).
    double topExtraInset = 0,
    /// Defaults to 3; use a higher value for multi-line paths (e.g. backup).
    int? maxMessageLines,
  }) {
    // Use root overlay so toasts sit at the top of the screen, not inside a
    // modal/bottom sheet's small overlay (which made them look "stuck" at the bottom).
    late final OverlayState overlay;
    try {
      overlay = Overlay.of(context, rootOverlay: true);
    } catch (_) {
      overlay = Overlay.of(context);
    }

    _activeTimer?.cancel();
    _activeEntry?.remove();
    _activeEntry = null;

    final safeTop = MediaQuery.paddingOf(context).top;
    final Color bgColor = switch (type) {
      HexaToastType.success => const Color(0xEE1E8E5A),
      HexaToastType.error => const Color(0xEEC63D56),
      HexaToastType.info => const Color(0xEE2D3F86),
      HexaToastType.warning => const Color(0xEEE0962C),
    };
    final IconData icon = switch (type) {
      HexaToastType.success => Icons.check_circle_rounded,
      HexaToastType.error => Icons.error_rounded,
      HexaToastType.info => Icons.info_rounded,
      HexaToastType.warning => Icons.warning_rounded,
    };

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: safeTop + 14 + topExtraInset,
        left: 12,
        right: 12,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        bgColor,
                        Color.alphaBlend(
                          Colors.black.withValues(alpha: 0.22),
                          bgColor,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0x22FFFFFF),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(icon, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              message,
                              maxLines: maxMessageLines ?? 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (progress != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: const Color(0x33FFFFFF),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    _activeEntry = entry;
    _activeTimer = Timer(duration, () {
      entry.remove();
      if (identical(_activeEntry, entry)) {
        _activeEntry = null;
      }
    });
  }
}
