import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../config/constants.dart';
import 'backup_media_export.dart';
import 'backup_result.dart';
import 'storage_service.dart';

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
      'platform': 'native',
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final dbPath = p.join(await getDatabasesPath(), 'hexacam-media.db');
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(
        ArchiveFile('hexacam-media.db', dbBytes.length, dbBytes),
      );
    }

    await appendHumanReadableExportToArchive(archive, foldersData);

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      return const BackupResult(
        ok: false,
        message: 'Could not create backup archive.',
      );
    }

    // Prefer a user-visible folder on Android (Downloads); iOS has no public
    // Downloads API — app Documents + UIFileSharingEnabled + share sheet.
    var parent = await getApplicationDocumentsDirectory();
    if (Platform.isAndroid) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        try {
          await Directory(p.join(downloads.path, 'HexaCamBackups'))
              .create(recursive: true);
          parent = downloads;
        } catch (_) {
          // Scoped storage or permission — keep app documents.
        }
      }
    }

    final backupDir = Directory(p.join(parent.path, 'HexaCamBackups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    final name = 'hexacam-backup-${DateTime.now().millisecondsSinceEpoch}.zip';
    final outFile = File(p.join(backupDir.path, name));
    await outFile.writeAsBytes(zipBytes, flush: true);

    unawaited(() async {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(
                outFile.path,
                mimeType: 'application/zip',
                name: name,
              ),
            ],
            text:
                'Hexa Cam backup — folders, photos, videos, PDF reports, and app data',
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Backup share sheet failed: $e');
        }
      }
    }());

    final hint = Platform.isIOS
        ? 'Files app → On My iPhone → Hexa Cam → Documents → HexaCamBackups'
        : Platform.isAndroid
            ? 'Or find ZIP under Download/HexaCamBackups (if allowed) — path below'
            : 'Path:';

    return BackupResult(
      ok: true,
      message:
          'Backup created. Use Share to save the ZIP to Files, Drive, or Downloads.\n'
          '$hint\n${outFile.path}',
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('BackupService runBackup (io) failed: $e');
    }
    return BackupResult(ok: false, message: 'Backup failed: $e');
  }
}
