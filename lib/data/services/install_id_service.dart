import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

/// Stable, non-secret install id for export provenance (not user PII).
class InstallIdService {
  InstallIdService._();

  static const _key = 'hexacam_install_id_v1';
  static const _uuid = Uuid();

  static Future<String> getOrCreateId() async {
    try {
      final storage = Get.find<FlutterSecureStorage>();
      final existing = await storage.read(key: _key);
      if (existing != null && existing.isNotEmpty) return existing;
      final id = _uuid.v4();
      await storage.write(key: _key, value: id);
      return id;
    } catch (_) {
      return 'unavailable';
    }
  }
}
