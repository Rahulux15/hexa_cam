import 'annotation.dart';
import 'camera_settings.dart';
import 'calibration.dart';
import 'measurement_data.dart';

enum MediaType { image, video, report }

class ImageData {
  final String id;
  final String imageUrl;
  final String? mediaId;
  final String? mediaMimeType;
  final String? thumbnail;
  final String? thumbnailId;
  final String? comment;
  final String timestamp;
  final CameraSettings cameraSettings;
  final List<Annotation> annotations;
  final List<MeasurementData> measurements;
  final Calibration? calibration;
  final MediaType? type;
  final double? duration;
  final int? rotation;
  final bool? mirrored;
  final String? lens;
  final String? filename;
  final String? description;
  final bool? showCalibrationStamp;
  final double? sourceWidth;
  final double? sourceHeight;
  final bool? isMarkingsBaked;

  ImageData({
    required this.id, required this.imageUrl, this.mediaId, this.mediaMimeType,
    this.thumbnail, this.thumbnailId, this.comment, required this.timestamp,
    required this.cameraSettings, this.annotations = const [], this.measurements = const [],
    this.calibration, this.type = MediaType.image, this.duration, this.rotation,
    this.mirrored, this.lens, this.filename, this.description, this.showCalibrationStamp,
    this.sourceWidth, this.sourceHeight, this.isMarkingsBaked = false,
  });

  ImageData copyWith({
    String? imageUrl,
    String? thumbnail,
    String? thumbnailId,
    List<Annotation>? annotations,
    CameraSettings? cameraSettings,
    bool? showCalibrationStamp,
    int? rotation,
    bool? mirrored,
    String? filename,
    String? description,
    bool? isMarkingsBaked,
  }) =>
      ImageData(
        id: id,
        imageUrl: imageUrl ?? this.imageUrl,
        mediaId: mediaId,
        mediaMimeType: mediaMimeType,
        thumbnail: thumbnail ?? this.thumbnail,
        thumbnailId: thumbnailId ?? this.thumbnailId,
        comment: comment,
        timestamp: timestamp,
        cameraSettings: cameraSettings ?? this.cameraSettings,
        annotations: annotations ?? this.annotations,
        measurements: measurements,
        calibration: calibration,
        type: type,
        duration: duration,
        rotation: rotation ?? this.rotation,
        mirrored: mirrored ?? this.mirrored,
        lens: lens,
        filename: filename ?? this.filename,
        description: description ?? this.description,
        showCalibrationStamp: showCalibrationStamp ?? this.showCalibrationStamp,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        isMarkingsBaked: isMarkingsBaked ?? this.isMarkingsBaked,
      );

  factory ImageData.fromJson(Map<String, dynamic> json) => ImageData(
    id: json['id'], imageUrl: json['imageUrl'] ?? '', mediaId: json['mediaId'],
    mediaMimeType: json['mediaMimeType'], thumbnail: json['thumbnail'],
    thumbnailId: json['thumbnailId'], comment: json['comment'],
    timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    cameraSettings: json['cameraSettings'] != null ? CameraSettings.fromJson(json['cameraSettings']) : const CameraSettings(),
    annotations: json['annotations'] != null ? (json['annotations'] as List).map((a) => Annotation.fromJson(a)).toList() : [],
    measurements: json['measurements'] != null ? (json['measurements'] as List).map((m) => MeasurementData.fromJson(m)).toList() : [],
    calibration: json['calibration'] != null ? Calibration.fromJson(json['calibration']) : null,
    type: MediaType.values.asNameMap()[json['type'] ?? 'image'] ?? MediaType.image,
    duration: json['duration']?.toDouble(), rotation: json['rotation'],
    mirrored: json['mirrored'], lens: json['lens'], filename: json['filename'],
    description: json['description'], showCalibrationStamp: json['showCalibrationStamp'],
    sourceWidth: json['sourceWidth']?.toDouble(), sourceHeight: json['sourceHeight']?.toDouble(),
    isMarkingsBaked: json['isMarkingsBaked'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'imageUrl': imageUrl, if (mediaId != null) 'mediaId': mediaId,
    if (mediaMimeType != null) 'mediaMimeType': mediaMimeType,
    if (thumbnail != null) 'thumbnail': thumbnail, if (thumbnailId != null) 'thumbnailId': thumbnailId,
    if (comment != null) 'comment': comment, 'timestamp': timestamp,
    'cameraSettings': cameraSettings.toJson(), 'annotations': annotations.map((a) => a.toJson()).toList(),
    'measurements': measurements.map((m) => m.toJson()).toList(),
    if (calibration != null) 'calibration': calibration!.toJson(), 'type': type?.name,
    if (duration != null) 'duration': duration, if (rotation != null) 'rotation': rotation,
    if (mirrored != null) 'mirrored': mirrored, if (lens != null) 'lens': lens,
    if (filename != null) 'filename': filename, if (description != null) 'description': description,
    if (showCalibrationStamp != null) 'showCalibrationStamp': showCalibrationStamp,
    if (sourceWidth != null) 'sourceWidth': sourceWidth, if (sourceHeight != null) 'sourceHeight': sourceHeight,
    'isMarkingsBaked': isMarkingsBaked ?? false,
  };
}
