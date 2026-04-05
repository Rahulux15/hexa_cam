import 'dart:async';

import 'package:flutter/material.dart';

enum HexaToastType { success, error, info }

class HexaToast {
  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;

  static void show(
    BuildContext context,
    String message, {
    HexaToastType type = HexaToastType.success,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);

    _activeTimer?.cancel();
    _activeEntry?.remove();
    _activeEntry = null;

    final safeTop = MediaQuery.paddingOf(context).top;
    final Color bgColor = switch (type) {
      HexaToastType.success => const Color(0xEE1E8E5A),
      HexaToastType.error => const Color(0xEEC63D56),
      HexaToastType.info => const Color(0xEE2D3F86),
    };
    final IconData icon = switch (type) {
      HexaToastType.success => Icons.check_circle_rounded,
      HexaToastType.error => Icons.error_rounded,
      HexaToastType.info => Icons.info_rounded,
    };

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: safeTop + 10,
        left: 12,
        right: 12,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
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
