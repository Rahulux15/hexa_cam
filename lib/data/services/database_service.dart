import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class MediaDatabase {
  static Database? _db;
  static const String _dbName = 'hexacam-media.db';
  static const String _tableName = 'media_assets';
  static const int _schemaVersion = 2;
  static final Map<String, Uint8List> _webStore = {};

  static Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('MediaDatabase uses an in-memory web store on web');
    }
    if (_db != null) return _db!;
    _db = await openDatabase(
      join(await getDatabasesPath(), _dbName),
      version: _schemaVersion,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $_tableName (id TEXT PRIMARY KEY, data BLOB NOT NULL, created_at INTEGER NOT NULL)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // No schema change from v1 → v2; hook for future migrations.
        }
      },
    );
    return _db!;
  }

  static Future<void> saveAsset(String id, Uint8List data) async {
    if (kIsWeb) {
      _webStore[id] = data;
      return;
    }
    final db = await database;
    await db.insert(_tableName, {'id': id, 'data': data, 'created_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Uint8List?> getAsset(String id) async {
    if (kIsWeb) {
      return _webStore[id];
    }
    final db = await database;
    final results = await db.query(_tableName, where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return results.first['data'] as Uint8List;
  }

  static Future<void> deleteAsset(String id) async {
    if (kIsWeb) {
      _webStore.remove(id);
      return;
    }
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> clearAll() async {
    if (kIsWeb) {
      _webStore.clear();
      return;
    }
    final db = await database;
    await db.delete(_tableName);
  }

  /// All blob bytes keyed by asset id — used to build `Media/` inside backup ZIP.
  static Future<Map<String, Uint8List>> loadAllAssetsForBackup() async {
    if (kIsWeb) {
      return Map<String, Uint8List>.from(_webStore);
    }
    final db = await database;
    final rows = await db.query(_tableName, columns: ['id', 'data']);
    final out = <String, Uint8List>{};
    for (final r in rows) {
      final id = r['id'] as String?;
      final data = r['data'] as Uint8List?;
      if (id == null || data == null || data.isEmpty) continue;
      out[id] = data;
    }
    return out;
  }

  /// JSON snapshot of in-memory web blobs for ZIP backup (web only).
  static String webStoreSnapshotJsonForBackup() {
    if (!kIsWeb) {
      return jsonEncode(<String, dynamic>{'version': 1, 'assets': <String, String>{}});
    }
    final map = <String, String>{};
    for (final e in _webStore.entries) {
      map[e.key] = base64Encode(e.value);
    }
    return jsonEncode(<String, dynamic>{'version': 1, 'assets': map});
  }
}
