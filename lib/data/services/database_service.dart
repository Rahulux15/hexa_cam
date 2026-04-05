import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class MediaDatabase {
  static Database? _db;
  static const String _dbName = 'hexacam-media.db';
  static const String _tableName = 'media_assets';
  static final Map<String, Uint8List> _webStore = {};

  static Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('MediaDatabase uses an in-memory web store on web');
    }
    if (_db != null) return _db!;
    _db = await openDatabase(join(await getDatabasesPath(), _dbName), version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE $_tableName (id TEXT PRIMARY KEY, data BLOB NOT NULL, created_at INTEGER NOT NULL)');
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
}
