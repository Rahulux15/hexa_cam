import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  T? get<T>(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) {
      if (key == 'folders') {
        final backup = _prefs.getString('${key}_backup');
        if (backup != null) {
          try {
            return jsonDecode(backup) as T;
          } catch (_) {}
        }
      }
      return null;
    }
    try { return jsonDecode(raw) as T; } catch (e) { _prefs.remove(key); return null; }
  }

  Future<void> set<T>(String key, T value) async {
    Object payload = value as Object;
    if (key == 'folders' && value is List) {
      payload = _sanitizeFolders(value);
    }
    final encoded = jsonEncode(payload);
    await _prefs.setString(key, encoded);
    if (key == 'folders') {
      await _prefs.setString('${key}_backup', encoded);
    }
  }

  List<Map<String, dynamic>> _sanitizeFolders(List<dynamic> folders) {
    return folders.map((folderRaw) {
      final folder = Map<String, dynamic>.from(folderRaw as Map);
      if (folder['images'] == null) return folder;
      final images = (folder['images'] as List).map((imageRaw) {
        return _sanitizeImageMap(Map<String, dynamic>.from(imageRaw as Map));
      }).toList();
      folder['images'] = images;
      if (folder['reports'] != null) {
        folder['reports'] = (folder['reports'] as List).map((reportRaw) {
          final report = Map<String, dynamic>.from(reportRaw as Map);
          if (report['sourceImages'] != null) {
            report['sourceImages'] = (report['sourceImages'] as List).map((imageRaw) {
              return _sanitizeImageMap(Map<String, dynamic>.from(imageRaw as Map));
            }).toList();
          }
          return report;
        }).toList();
      }
      return folder;
    }).toList();
  }

  Map<String, dynamic> _sanitizeImageMap(Map<String, dynamic> image) {
    final sanitizedImage = Map<String, dynamic>.from(image);
    if (sanitizedImage['mediaId'] != null &&
        (sanitizedImage['imageUrl'] as String?)?.startsWith('data:') == true) {
      sanitizedImage['imageUrl'] = '';
    }
    if ((sanitizedImage['thumbnail'] as String?)?.startsWith('data:') == true &&
        sanitizedImage['type'] != 'video' &&
        (sanitizedImage['thumbnailId'] != null ||
            sanitizedImage['mediaId'] != null)) {
      sanitizedImage['thumbnail'] = '';
    }
    return sanitizedImage;
  }

  Future<void> remove(String key) async => await _prefs.remove(key);
  Future<void> clear() async => await _prefs.clear();
}
