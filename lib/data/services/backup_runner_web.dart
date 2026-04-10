import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../../config/constants.dart';
import 'backup_media_export.dart';
import 'backup_result.dart';
import 'database_service.dart';
import 'storage_service.dart';
import 'web_download_web.dart';

Future<BackupResult> runBackup(StorageService storage) async {
  try {
    final archive = Archive();
    final foldersData = storage.get<List<dynamic>>(AppConstants.keyFolders);
    final foldersJson = jsonEncode(foldersData ?? <dynamic>[]);
    final foldersBytes = utf8.encode(foldersJson);
    archive.addFile(
      ArchiveFile('folders.json', foldersBytes.length, foldersBytes),
    );

    final manifest = <String, dynamic>{
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'schema': 'hexacam-backup-v1',
      'platform': 'web',
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final webMediaJson = MediaDatabase.webStoreSnapshotJsonForBackup();
    final webMediaBytes = utf8.encode(webMediaJson);
    archive.addFile(
      ArchiveFile('web_media.json', webMediaBytes.length, webMediaBytes),
    );

    await appendHumanReadableExportToArchive(archive, foldersData);

    final zipBytes = ZipEncoder().encode(archive);

    final name = 'hexacam-backup-${DateTime.now().millisecondsSinceEpoch}.zip';
    await downloadBytesWeb(
      Uint8List.fromList(zipBytes),
      name,
      mimeType: 'application/zip',
    );
    return const BackupResult(
      ok: true,
      message: 'Backup download started. Check your Downloads folder.',
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('BackupService runBackup (web) failed: $e');
    }
    return BackupResult(ok: false, message: 'Backup failed: $e');
  }
}
