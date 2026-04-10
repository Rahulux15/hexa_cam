import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class MediaDatabase {
  static Database? _db;
  static const String _dbName = 'hexacam-media.db';
  static const String _tableName = 'media_assets';
  static const int _schemaVersion = 2;
  static final Map<String, Uint8List> _webStore = {};

  /// Android SQLite [CursorWindow] is ~2MB per row; reading a whole BLOB in one
  /// row can throw. Inline reads are safe below this size; larger blobs use
  /// [substr] chunks.
  static const int _maxInlineBlobBytes = 512 * 1024;
  static const int _blobReadChunkBytes = 512 * 1024;

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
    final lenRow = await db.rawQuery(
      'SELECT length(data) AS len FROM $_tableName WHERE id = ?',
      [id],
    );
    if (lenRow.isEmpty) return null;
    final len = lenRow.first['len'] as int?;
    if (len == null || len == 0) return null;

    if (len <= _maxInlineBlobBytes) {
      final results = await db.query(
        _tableName,
        columns: ['data'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (results.isEmpty) return null;
      return results.first['data'] as Uint8List?;
    }
    return _readBlobInChunks(db, id, len);
  }

  static Future<Uint8List> _readBlobInChunks(
    Database db,
    String id,
    int totalLen,
  ) async {
    final builder = BytesBuilder(copy: false);
    var offset = 0;
    while (offset < totalLen) {
      final take = min(_blobReadChunkBytes, totalLen - offset);
      final rows = await db.rawQuery(
        'SELECT substr(data, ?, ?) AS chunk FROM $_tableName WHERE id = ?',
        [offset + 1, take, id],
      );
      if (rows.isEmpty) break;
      final chunk = rows.first['chunk'];
      if (chunk == null) break;
      if (chunk is Uint8List) {
        builder.add(chunk);
      } else if (chunk is List<int>) {
        builder.add(chunk);
      }
      offset += take;
    }
    return builder.toBytes();
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
  /// Loads ids only first, then each asset via [getAsset] (chunked for large BLOBs)
  /// so Android never pulls every row into one [CursorWindow].
  static Future<Map<String, Uint8List>> loadAllAssetsForBackup() async {
    if (kIsWeb) {
      return Map<String, Uint8List>.from(_webStore);
    }
    final db = await database;
    final idRows = await db.query(_tableName, columns: ['id']);
    final out = <String, Uint8List>{};
    for (final r in idRows) {
      final id = r['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final data = await getAsset(id);
      if (data != null && data.isNotEmpty) {
        out[id] = data;
      }
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
