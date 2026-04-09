import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../data/models/folder.dart';
import '../data/models/image_data.dart';
import '../data/models/report_data.dart';
import '../data/models/camera_settings.dart';
import '../data/models/annotation.dart';
import '../data/models/stored_calibration.dart';
import '../data/services/api_service.dart';
import '../data/services/storage_service.dart';
import '../controllers/camera_controller.dart';
import '../controllers/permission_controller.dart';
import '../config/constants.dart';
import 'microscope_calibration_provider.dart';

/// Registers shared services and GetX controllers for the whole app.
void initAppDependencies(SharedPreferences sharedPreferences) {
  Get.put<SharedPreferences>(sharedPreferences, permanent: true);
  Get.put<ApiService>(ApiService(), permanent: true);
  Get.put<FlutterSecureStorage>(const FlutterSecureStorage(), permanent: true);
  Get.put<StorageService>(StorageService(sharedPreferences), permanent: true);
  Get.put<CameraController>(CameraController(), permanent: true);
  Get.put<PermissionController>(
    PermissionController(sharedPreferences),
    permanent: true,
  );
  Get.put<FoldersController>(
    FoldersController(Get.find<StorageService>()),
    permanent: true,
  );
  Get.put<CalibrationController>(
    CalibrationController(sharedPreferences),
    permanent: true,
  );
  Get.put<MicroscopeCalibrationProvider>(
    MicroscopeCalibrationProvider(sharedPreferences),
    permanent: true,
  );
  Get.put<UiStateController>(UiStateController(), permanent: true);
}

StorageService get storageService => Get.find<StorageService>();
FoldersController get foldersController => Get.find<FoldersController>();
CalibrationController get calibrationController =>
    Get.find<CalibrationController>();
MicroscopeCalibrationProvider get microscopeCalibrationController =>
    Get.find<MicroscopeCalibrationProvider>();
UiStateController get uiStateController => Get.find<UiStateController>();

class FoldersController extends GetxController {
  FoldersController(this._storage) {
    _load();
  }

  final StorageService _storage;
  List<Folder> folders = <Folder>[];
  Timer? _saveDebounce;
  bool _isSaving = false;
  bool _saveQueued = false;

  void _load() {
    final data = _storage.get<List<dynamic>>(AppConstants.keyFolders);
    if (data != null) {
      folders = data
          .map((f) => Folder.fromJson(Map<String, dynamic>.from(f)))
          .toList();
    }
  }

  Future<void> createFolder(String name) async {
    folders = [
      ...folders,
      Folder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        createdAt: DateTime.now().toIso8601String(),
        images: const <ImageData>[],
      ),
    ];
    await _saveAndRefresh(immediate: true);
  }

  Future<void> deleteFolder(String id) async {
    folders = folders.where((f) => f.id != id).toList();
    await _saveAndRefresh(immediate: true);
  }

  Future<void> renameFolder(String id, String newName) async {
    folders = folders
        .map((f) => f.id == id ? f.copyWith(name: newName) : f)
        .toList();
    await _saveAndRefresh(immediate: true);
  }

  Future<void> addImage(String folderId, ImageData image) async {
    folders = folders.map((f) {
      if (f.id != folderId) return f;
      return f.copyWith(images: [...f.images, image]);
    }).toList();
    await _saveAndRefresh(immediate: true);
  }

  Future<void> removeImage(String folderId, String imageId) async {
    folders = folders.map((f) {
      if (f.id != folderId) return f;
      return f.copyWith(
        images: f.images.where((i) => i.id != imageId).toList(),
      );
    }).toList();
    await _saveAndRefresh(immediate: true);
  }

  Future<void> removeImages(String folderId, Set<String> imageIds) async {
    folders = folders.map((f) {
      if (f.id != folderId) return f;
      return f.copyWith(
        images: f.images.where((i) => !imageIds.contains(i.id)).toList(),
      );
    }).toList();
    await _saveAndRefresh(immediate: true);
  }

  Future<void> updateImage(
    String folderId,
    String imageId,
    ImageData updated,
  ) async {
    var changed = false;
    folders = folders.map((f) {
      if (f.id != folderId) return f;
      final nextImages = f.images.map((i) {
        if (i.id != imageId) return i;
        if (identical(i, updated)) return i;
        changed = true;
        return updated;
      }).toList();
      return f.copyWith(
        images: nextImages,
      );
    }).toList();
    if (!changed) return;
    await _saveAndRefresh();
  }

  Future<void> addReport(String folderId, ReportData report) async {
    folders = folders.map((folder) {
      if (folder.id != folderId) return folder;
      final existing = [...?folder.reports];
      final alreadyExists = existing.any(
        (r) =>
            r.id == report.id ||
            (r.pdfAssetId != null &&
                report.pdfAssetId != null &&
                r.pdfAssetId == report.pdfAssetId),
      );
      if (alreadyExists) return folder;
      return folder.copyWith(reports: [...existing, report]);
    }).toList();
    await _saveAndRefresh(immediate: true);
  }

  Future<void> removeReports(String folderId, Set<String> reportIds) async {
    folders = folders.map((folder) {
      if (folder.id != folderId) return folder;
      final existing = [...?folder.reports];
      if (existing.isEmpty) return folder;
      return folder.copyWith(
        reports: existing.where((report) => !reportIds.contains(report.id)).toList(),
      );
    }).toList();
    await _saveAndRefresh(immediate: true);
  }

  Future<void> clearAll() async {
    folders = <Folder>[];
    update();
    await _storage.remove(AppConstants.keyFolders);
    await _storage.remove('${AppConstants.keyFolders}_backup');
  }

  Future<void> _saveAndRefresh({bool immediate = false}) async {
    update();
    if (immediate) {
      await _flushSaveNow();
      return;
    }
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_flushSaveNow());
    });
  }

  Future<void> _flushSaveNow() async {
    if (_isSaving) {
      _saveQueued = true;
      return;
    }
    _isSaving = true;
    try {
      await _storage.set(
        AppConstants.keyFolders,
        folders.map((f) => f.toJson()).toList(),
      );
    } finally {
      _isSaving = false;
      if (_saveQueued) {
        _saveQueued = false;
        unawaited(_flushSaveNow());
      }
    }
  }

  @override
  void onClose() {
    _saveDebounce?.cancel();
    super.onClose();
  }
}

class CalibrationController extends GetxController {
  CalibrationController(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  Map<String, StoredCalibration> calibrations = <String, StoredCalibration>{};

  void _load() {
    final raw = _prefs.getString(AppConstants.keyCalibrations);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      calibrations = decoded.map(
        (k, v) => MapEntry(
          k,
          StoredCalibration.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      );
    } catch (_) {
      calibrations = <String, StoredCalibration>{};
    }
  }

  void saveCalibration(StoredCalibration cal) {
    calibrations = {...calibrations, cal.lens: cal};
    _saveAndRefresh();
  }

  StoredCalibration? getForLens(String lens) => calibrations[lens];

  Future<void> clearAll() async {
    calibrations = <String, StoredCalibration>{};
    update();
    await _prefs.remove(AppConstants.keyCalibrations);
  }

  void _saveAndRefresh() {
    final map = calibrations.map((k, v) => MapEntry(k, v.toJson()));
    _prefs.setString(AppConstants.keyCalibrations, jsonEncode(map));
    update();
  }
}

class UiStateController extends GetxController {
  AnnotationType? selectedTool;
  Color drawingColor = const Color(0xFFFF00FF);
  bool measurementMode = false;
  CameraSettings cameraSettings = const CameraSettings();

  void setSelectedTool(AnnotationType? tool) {
    selectedTool = tool;
    update();
  }

  void setDrawingColor(Color color) {
    drawingColor = color;
    update();
  }

  void setMeasurementMode(bool enabled) {
    measurementMode = enabled;
    update();
  }

  void toggleMeasurementMode() {
    measurementMode = !measurementMode;
    update();
  }

  void setCameraSettings(CameraSettings settings) {
    cameraSettings = settings;
    update();
  }
}
