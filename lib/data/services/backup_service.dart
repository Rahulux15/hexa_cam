import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../config/constants.dart';
import 'storage_service.dart';

/// Full local backup: folder JSON + media SQLite blob DB + manifest.
/// Returns path to `.zip` on success (mobile/desktop), or `null` on failure / web.
class BackupService {
  BackupService._();

  static Future<String?> createFullBackupZip(StorageService storage) async {
    if (kIsWeb) return null;
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

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(dir.path, 'HexaCamBackups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final name =
          'hexacam-backup-${DateTime.now().millisecondsSinceEpoch}.zip';
      final outFile = File(p.join(backupDir.path, name));
      await outFile.writeAsBytes(zipBytes, flush: true);
      return outFile.path;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BackupService.createFullBackupZip failed: $e');
      }
      return null;
    }
  }
}
