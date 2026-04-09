import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';

/// Shows "What's new" for the current [PackageInfo.version] when listed in assets.
/// [force] skips the "already seen" check (e.g. from Settings).
Future<void> showReleaseNotesIfNeeded(
  BuildContext context, {
  bool force = false,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    final key = '${info.version}+${info.buildNumber}';
    if (!force) {
      final last = prefs.getString(AppConstants.keyLastSeenReleaseNotesVersion);
      if (last == key) return;
    }

    final raw = await rootBundle.loadString('assets/release_notes.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final items = map[key];
    if (items is! List || items.isEmpty) {
      if (!force) {
        await prefs.setString(AppConstants.keyLastSeenReleaseNotesVersion, key);
      }
      return;
    }
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF232651),
        title: const Text(
          "What's new",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version $key',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...items.map<Widget>((e) {
                final line = e.toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.white70)),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppTheme.primaryLight)),
          ),
        ],
      ),
    );

    await prefs.setString(AppConstants.keyLastSeenReleaseNotesVersion, key);
  } catch (_) {
    // Non-fatal: never block app start.
  }
}
