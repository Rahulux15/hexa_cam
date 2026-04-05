import 'image_data.dart';
import 'report_data.dart';

class Folder {
  final String id;
  final String name;
  final String createdAt;
  final List<ImageData> images;
  final List<ReportData>? reports;

  Folder({required this.id, required this.name, required this.createdAt, required this.images, this.reports});

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    id: json['id'], name: json['name'], createdAt: json['createdAt'],
    images: json['images'] != null ? (json['images'] as List).map((i) => ImageData.fromJson(i)).toList() : [],
    reports: json['reports'] != null ? (json['reports'] as List).map((r) => ReportData.fromJson(r)).toList() : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'createdAt': createdAt,
    'images': images.map((i) => i.toJson()).toList(),
    if (reports != null) 'reports': reports!.map((r) => r.toJson()).toList(),
  };

  Folder copyWith({String? name, List<ImageData>? images, List<ReportData>? reports}) =>
    Folder(id: id, name: name ?? this.name, createdAt: createdAt, images: images ?? this.images, reports: reports ?? this.reports);

  int get imageCount => images.where((i) => i.type == MediaType.image || i.type == null).length;
  int get videoCount => images.where((i) => i.type == MediaType.video).length;
}
