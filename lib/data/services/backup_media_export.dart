import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/folder.dart';
import '../models/image_data.dart';
import '../models/report_data.dart';
import 'database_service.dart';

final _invalidPathChars = RegExp(r'[<>:"/\\|?*\x00-\x1f]');

String _sanitizePathSegment(String name) {
  var s = name.trim().replaceAll(_invalidPathChars, '_').replaceAll('..', '_');
  if (s.isEmpty) s = 'item';
  if (s.length > 120) s = s.substring(0, 120);
  return s;
}

String _extensionForImage(ImageData img) {
  if (img.type == MediaType.video) return 'mp4';
  final m = img.mediaMimeType?.toLowerCase() ?? '';
  if (m.contains('png')) return 'png';
  if (m.contains('webp')) return 'webp';
  if (m.contains('jpeg') || m.contains('jpg')) return 'jpg';
  return 'jpg';
}

/// Prefer main file, then thumbnail (e.g. video poster).
Future<Uint8List?> _loadImageBytes(ImageData img) async {
  final ids = <String>[
    if (img.mediaId != null && img.mediaId!.isNotEmpty) img.mediaId!,
    if (img.type == MediaType.video &&
        img.thumbnailId != null &&
        img.thumbnailId!.isNotEmpty)
      img.thumbnailId!,
  ];
  for (final id in ids) {
    final b = await MediaDatabase.getAsset(id);
    if (b != null && b.isNotEmpty) return b;
  }
  return null;
}

String _imageArchiveName(ImageData img, int index) {
  final fn = img.filename?.trim();
  if (fn != null && fn.isNotEmpty) {
    return _sanitizePathSegment(fn);
  }
  final stamp = img.timestamp
      .replaceAll(':', '-')
      .replaceAll(RegExp(r'[^\w\-]'), '_');
  final ext = _extensionForImage(img);
  return 'image_${index + 1}_$stamp.$ext';
}

String _reportArchiveName(ReportData rep, int index) {
  var base = rep.filename.trim();
  if (base.isEmpty) {
    base = 'report_${index + 1}.pdf';
  }
  if (!base.toLowerCase().endsWith('.pdf')) {
    base = '$base.pdf';
  }
  return _sanitizePathSegment(base);
}

/// Adds `Media/<folder name>/...` with real image, video, and PDF files so users can
/// browse the ZIP without opening JSON/SQLite. Does not remove DB export (needed for app restore).
Future<void> appendHumanReadableExportToArchive(
  Archive archive,
  List<dynamic>? foldersRaw,
) async {
  if (foldersRaw == null || foldersRaw.isEmpty) return;

  final usedNames = <String>{};

  for (final raw in foldersRaw) {
    if (raw is! Map) continue;
    late final Folder folder;
    try {
      folder = Folder.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      continue;
    }

    var base = _sanitizePathSegment(folder.name);
    var unique = base;
    var n = 1;
    while (usedNames.contains(unique)) {
      n++;
      unique = '${base}_$n';
    }
    usedNames.add(unique);
    final root = 'Media/$unique';

    final usedInFolder = <String>{};

    for (var i = 0; i < folder.images.length; i++) {
      final img = folder.images[i];
      final bytes = await _loadImageBytes(img);
      if (bytes == null) continue;

      var name = _imageArchiveName(img, i);
      if (usedInFolder.contains(name)) {
        final dot = name.lastIndexOf('.');
        final stem = dot > 0 ? name.substring(0, dot) : name;
        final ext = dot > 0 ? name.substring(dot) : '';
        name = '${stem}_${img.id}$ext';
      }
      usedInFolder.add(name);

      final path = '$root/$name';
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    final reports = folder.reports ?? <ReportData>[];
    for (var r = 0; r < reports.length; r++) {
      final rep = reports[r];
      final id = rep.pdfAssetId;
      if (id == null || id.isEmpty) continue;
      final bytes = await MediaDatabase.getAsset(id);
      if (bytes == null || bytes.isEmpty) continue;

      var name = _reportArchiveName(rep, r);
      if (usedInFolder.contains(name)) {
        final dot = name.toLowerCase().lastIndexOf('.pdf');
        if (dot > 0) {
          name = '${name.substring(0, dot)}_${rep.id}.pdf';
        } else {
          name = '${name}_$r.pdf';
        }
      }
      usedInFolder.add(name);

      final path = '$root/$name';
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }
  }

  const readme = '''
Hexa-Cam backup (human-readable)
---------------------------------
Media/ — photos, videos, and PDF reports by folder. Open or copy these files on any computer.

Other files (folders.json, manifest.json, hexacam-media.db or web_media.json) are for the Hexa-Cam app to load your full library. The database holds the same media in app form; the Media/ folder is for easy browsing.
''';
  final b = utf8.encode(readme);
  archive.addFile(ArchiveFile('README.txt', b.length, b));
}
