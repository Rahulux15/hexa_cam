import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';

/// User toggles for export behaviour (defaults preserve prior behaviour).
class ExportPrefs {
  ExportPrefs._();

  static Future<bool> watermarkEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyExportWatermark) ?? true;
  }

  static Future<void> setWatermarkEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyExportWatermark, value);
  }

  static Future<bool> includeProvenanceInPdf() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyExportPdfProvenance) ?? true;
  }

  static Future<void> setIncludeProvenanceInPdf(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyExportPdfProvenance, value);
  }
}
