import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

@immutable
class CalibrationEntry {
  const CalibrationEntry({
    required this.magnification,
    required this.unit,
    required this.unitPerPixel,
    required this.pixelsPerUnit,
    required this.referenceLength,
    required this.measuredPixelDistance,
    this.unitPerDivision,
    this.measuredDivisions,
    required this.createdAt,
  });

  final String magnification;
  final String unit;
  final double unitPerPixel;
  final double pixelsPerUnit;
  final double referenceLength;
  final double measuredPixelDistance;
  final double? unitPerDivision;
  final double? measuredDivisions;
  final String createdAt;

  factory CalibrationEntry.fromJson(Map<String, dynamic> json) {
    return CalibrationEntry(
      magnification: (json['magnification'] ?? '').toString(),
      unit: (json['unit'] ?? 'μm').toString(),
      unitPerPixel: (json['unitPerPixel'] ?? 0.0).toDouble(),
      pixelsPerUnit: (json['pixelsPerUnit'] ?? 0.0).toDouble(),
      referenceLength: (json['referenceLength'] ?? 0.0).toDouble(),
      measuredPixelDistance: (json['measuredPixelDistance'] ?? 0.0).toDouble(),
      unitPerDivision: json['unitPerDivision']?.toDouble(),
      measuredDivisions: json['measuredDivisions']?.toDouble(),
      createdAt:
          (json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'magnification': magnification,
      'unit': unit,
      'unitPerPixel': unitPerPixel,
      'pixelsPerUnit': pixelsPerUnit,
      'referenceLength': referenceLength,
      'measuredPixelDistance': measuredPixelDistance,
      if (unitPerDivision != null) 'unitPerDivision': unitPerDivision,
      if (measuredDivisions != null) 'measuredDivisions': measuredDivisions,
      'createdAt': createdAt,
    };
  }
}

@immutable
class MeasurementValue {
  const MeasurementValue({
    required this.value,
    required this.unit,
  });

  final double value;
  final String unit;

  String get formatted => '${value.toStringAsFixed(2)} $unit';
}

class MicroscopeCalibrationProvider extends GetxController {
  MicroscopeCalibrationProvider(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  final Map<String, CalibrationEntry> _entries = {};

  static const List<String> supportedMagnifications = <String>[
    '4X',
    '10X',
    '20X',
    '40X',
    '60X',
    '100X',
  ];

  Map<String, CalibrationEntry> get entries =>
      Map<String, CalibrationEntry>.unmodifiable(_entries);

  CalibrationEntry? getCalibrationForMagnification(String magnification) {
    return _entries[magnification];
  }

  CalibrationEntry setCalibrationFromPixels({
    required String magnification,
    required double knownDistance,
    required double measuredPixels,
    double? measuredDivisions,
    required String unit,
  }) {
    _validateMagnification(magnification);
    _validateUnit(unit);
    if (knownDistance <= 0) {
      throw ArgumentError.value(
          knownDistance, 'knownDistance', 'must be greater than zero');
    }
    if (measuredPixels <= 0) {
      throw ArgumentError.value(
          measuredPixels, 'measuredPixels', 'must be greater than zero');
    }

    final unitPerPixel = knownDistance / measuredPixels;
    final pixelsPerUnit = measuredPixels / knownDistance;
    final unitPerDivision = (measuredDivisions != null && measuredDivisions > 0)
        ? knownDistance / measuredDivisions
        : null;

    final entry = CalibrationEntry(
      magnification: magnification,
      unit: unit,
      unitPerPixel: unitPerPixel,
      pixelsPerUnit: pixelsPerUnit,
      referenceLength: knownDistance,
      measuredPixelDistance: measuredPixels,
      unitPerDivision: unitPerDivision,
      measuredDivisions: measuredDivisions,
      createdAt: DateTime.now().toIso8601String(),
    );
    _entries[magnification] = entry;
    _save();
    update();
    return entry;
  }

  CalibrationEntry setManualCalibration({
    required String magnification,
    required double unitPerPixel,
    required String unit,
  }) {
    _validateMagnification(magnification);
    _validateUnit(unit);
    if (unitPerPixel <= 0) {
      throw ArgumentError.value(
          unitPerPixel, 'unitPerPixel', 'must be greater than zero');
    }
    final entry = CalibrationEntry(
      magnification: magnification,
      unit: unit,
      unitPerPixel: unitPerPixel,
      pixelsPerUnit: 1 / unitPerPixel,
      referenceLength: 0,
      measuredPixelDistance: 0,
      createdAt: DateTime.now().toIso8601String(),
    );
    _entries[magnification] = entry;
    _save();
    update();
    return entry;
  }

  MeasurementValue? measurePixels({
    required String magnification,
    required double pixels,
    required String unit,
  }) {
    if (pixels < 0) {
      throw ArgumentError.value(pixels, 'pixels', 'must be non-negative');
    }
    final calibration = _entries[magnification];
    if (calibration == null) return null;
    _validateUnit(unit);

    final rawInCalibrationUnit = pixels * calibration.unitPerPixel;
    final converted = _convertUnit(
      value: rawInCalibrationUnit,
      fromUnit: calibration.unit,
      toUnit: unit,
    );
    return MeasurementValue(value: converted, unit: unit);
  }

  MeasurementValue? measureDivisions({
    required String magnification,
    required double observedDivisions,
  }) {
    if (observedDivisions < 0) {
      throw ArgumentError.value(
          observedDivisions, 'observedDivisions', 'must be non-negative');
    }
    final calibration = _entries[magnification];
    final perDivision = calibration?.unitPerDivision;
    if (calibration == null || perDivision == null || perDivision <= 0) {
      return null;
    }
    return MeasurementValue(
      value: observedDivisions * perDivision,
      unit: calibration.unit,
    );
  }

  void clearCalibration(String magnification) {
    _entries.remove(magnification);
    _save();
    update();
  }

  void clearAll() {
    _entries.clear();
    _prefs.remove(AppConstants.keyCalibrations);
    update();
  }

  bool isCalibrated(String magnification) => _entries.containsKey(magnification);

  void _load() {
    final raw = _prefs.getString(AppConstants.keyCalibrations);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _entries
        ..clear()
        ..addAll(
          decoded.map(
            (key, value) => MapEntry(
              key,
              CalibrationEntry.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            ),
          ),
        );
    } catch (_) {
      _entries.clear();
    }
  }

  void _save() {
    final encoded = jsonEncode(
      _entries.map((key, value) => MapEntry(key, value.toJson())),
    );
    _prefs.setString(AppConstants.keyCalibrations, encoded);
  }

  void _validateMagnification(String magnification) {
    if (!supportedMagnifications.contains(magnification)) {
      throw ArgumentError.value(
        magnification,
        'magnification',
        'must be one of ${supportedMagnifications.join(', ')}',
      );
    }
  }

  void _validateUnit(String unit) {
    if (unit != 'μm' && unit != 'nm') {
      throw ArgumentError.value(unit, 'unit', 'must be either μm or nm');
    }
  }

  double _convertUnit({
    required double value,
    required String fromUnit,
    required String toUnit,
  }) {
    if (fromUnit == toUnit) return value;
    if (fromUnit == 'μm' && toUnit == 'nm') return value * 1000.0;
    if (fromUnit == 'nm' && toUnit == 'μm') return value / 1000.0;
    return value;
  }
}
