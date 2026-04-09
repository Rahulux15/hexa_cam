import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';

/// Release notes asset: [assets/release_notes.json] — object map of string keys to string arrays.
///
/// **Keys (checked in order for each app build):**
/// 1. `"<version>+<buildNumber>"` e.g. `"2.0.0+2"` — exact match from [PackageInfo].
/// 2. `"<version>"` e.g. `"2.0.0"` — same notes for every build of that version (until you add a `+build` line).
/// 3. `"default"` — fallback when no entry exists yet for the running version.
///
/// **On each release:** bump `version:` in `pubspec.yaml`, then add or update the matching key
/// in `release_notes.json` so "What's new" stays in sync with the shipped version.

List<dynamic>? _releaseNotesForPackageInfo(
  Map<String, dynamic> map,
  PackageInfo info,
) {
  final fullKey = '${info.version}+${info.buildNumber}';
  final versionOnly = info.version;
  for (final key in <String>[fullKey, versionOnly, 'default']) {
    final raw = map[key];
    if (raw is List && raw.isNotEmpty) {
      return raw;
    }
  }
  return null;
}

/// Call from [LoginPage] / [FoldersPage] **after** splash has navigated — not from [HexaCamApp],
/// or the dialog is disposed when [Get.offAllNamed] replaces the route stack.
void scheduleReleaseNotesAfterNavigation(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_showReleaseNotesDelayed(context));
  });
}

Future<void> _showReleaseNotesDelayed(BuildContext context) async {
  await Future<void>.delayed(const Duration(milliseconds: 500));
  if (!context.mounted) return;
  await showReleaseNotesIfNeeded(context);
}

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
    final items = _releaseNotesForPackageInfo(map, info);
    if (items == null || items.isEmpty) {
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
