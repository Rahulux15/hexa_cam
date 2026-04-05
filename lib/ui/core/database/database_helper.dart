import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'hexa_cam.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        full_name TEXT,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Sessions table
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        token TEXT NOT NULL,
        is_logged_in INTEGER DEFAULT 0,
        last_login TEXT,
        login_type TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Intentionally left empty so production builds do not ship with seeded credentials.
  }

  // Get user by email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Validate user credentials
  Future<bool> validateUser(String email, String password) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email.toLowerCase(), password],
    );
    return result.isNotEmpty;
  }

  // Save session
  Future<void> saveSession(int userId, String token, String loginType) async {
    final db = await database;

    // Logout existing sessions
    await db.update(
      'sessions',
      {'is_logged_in': 0},
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    // Insert new session
    await db.insert('sessions', {
      'user_id': userId,
      'token': token,
      'is_logged_in': 1,
      'last_login': DateTime.now().toIso8601String(),
      'login_type': loginType,
    });

    // Save token securely only in encrypted storage.
    await _secureStorage.write(key: 'auth_token', value: token);
  }

  // Get active session
  Future<Map<String, dynamic>?> getActiveSession() async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'sessions',
      where: 'is_logged_in = 1',
      limit: 1,
    );

    if (result.isNotEmpty) {
      Map<String, dynamic> session = result.first;
      List<Map<String, dynamic>> user = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [session['user_id']],
      );

      if (user.isNotEmpty) {
        session['user'] = user.first;
        return session;
      }
    }
    return null;
  }

  // Check if user has previous login
  Future<bool> hasPreviousLogin() async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'sessions',
      where: 'last_login IS NOT NULL',
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Get last login info
  Future<Map<String, dynamic>?> getLastLoginInfo() async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'sessions',
      orderBy: 'last_login DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      Map<String, dynamic> session = result.first;
      List<Map<String, dynamic>> user = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [session['user_id']],
      );

      if (user.isNotEmpty) {
        session['user'] = user.first;
        return session;
      }
    }
    return null;
  }

  // Clear session (logout)
  Future<void> clearSession() async {
    final db = await database;
    await db.update(
      'sessions',
      {'is_logged_in': 0},
      where: 'is_logged_in = 1',
    );
    await _secureStorage.delete(key: 'auth_token');
  }

  // Register new user
  Future<bool> registerUser(String email, String password, String fullName) async {
    final db = await database;
    try {
      await db.insert('users', {
        'email': email.toLowerCase(),
        'password': password,
        'full_name': fullName,
        'role': 'user',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update password
  Future<bool> updatePassword(String email, String newPassword) async {
    final db = await database;
    int result = await db.update(
      'users',
      {'password': newPassword},
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    return result > 0;
  }
}
