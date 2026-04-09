import 'image_data.dart';
import 'report_data.dart';

class Folder {
  final String id;
  final String name;
  final String createdAt;
  final List<ImageData> images;
  final List<ReportData>? reports;

  /// Optional inspection context for field reports (stored with folder, not per-image).
  final String? inspectionSiteId;
  /// One of: `pass`, `fail`, `na`, or empty / null = not set.
  final String? inspectionOutcome;
  final String? inspectionNotes;

  Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.images,
    this.reports,
    this.inspectionSiteId,
    this.inspectionOutcome,
    this.inspectionNotes,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    id: json['id'],
    name: json['name'],
    createdAt: json['createdAt'],
    images: json['images'] != null
        ? (json['images'] as List).map((i) => ImageData.fromJson(i)).toList()
        : [],
    reports: json['reports'] != null
        ? (json['reports'] as List).map((r) => ReportData.fromJson(r)).toList()
        : null,
    inspectionSiteId: json['inspectionSiteId'] as String?,
    inspectionOutcome: json['inspectionOutcome'] as String?,
    inspectionNotes: json['inspectionNotes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt,
    'images': images.map((i) => i.toJson()).toList(),
    if (reports != null) 'reports': reports!.map((r) => r.toJson()).toList(),
    if (inspectionSiteId != null) 'inspectionSiteId': inspectionSiteId,
    if (inspectionOutcome != null) 'inspectionOutcome': inspectionOutcome,
    if (inspectionNotes != null) 'inspectionNotes': inspectionNotes,
  };

  Folder copyWith({String? name, List<ImageData>? images, List<ReportData>? reports}) =>
      Folder(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        images: images ?? this.images,
        reports: reports ?? this.reports,
        inspectionSiteId: inspectionSiteId,
        inspectionOutcome: inspectionOutcome,
        inspectionNotes: inspectionNotes,
      );

  int get imageCount => images.where((i) => i.type == MediaType.image || i.type == null).length;
  int get videoCount => images.where((i) => i.type == MediaType.video).length;
}
