class ReportData {
  final String id;
  final String filename;
  final String timestamp;
  final String? pdfAssetId;
  final String? previewImageUrl;
  final String? previewImageAssetId;
  final String? description;
  final String? lens;
  final ReportFormData? formData;
  final List<Map<String, dynamic>>? sourceImages;

  ReportData(
      {required this.id,
      required this.filename,
      required this.timestamp,
      this.pdfAssetId,
      this.previewImageUrl,
      this.previewImageAssetId,
      this.description,
      this.lens,
      this.formData,
      this.sourceImages});

  factory ReportData.fromJson(Map<String, dynamic> json) => ReportData(
        id: json['id'],
        filename: json['filename'],
        timestamp: json['timestamp'],
        pdfAssetId: json['pdfAssetId'],
        previewImageUrl: json['previewImageUrl'],
        previewImageAssetId: json['previewImageAssetId'],
        description: json['description'],
        lens: json['lens'],
        formData: json['formData'] != null
            ? ReportFormData.fromJson(json['formData'])
            : null,
        sourceImages: json['sourceImages'] != null
            ? (json['sourceImages'] as List)
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'timestamp': timestamp,
        if (pdfAssetId != null) 'pdfAssetId': pdfAssetId,
        if (previewImageUrl != null) 'previewImageUrl': previewImageUrl,
        if (previewImageAssetId != null)
          'previewImageAssetId': previewImageAssetId,
        if (description != null) 'description': description,
        if (lens != null) 'lens': lens,
        if (formData != null) 'formData': formData!.toJson(),
        if (sourceImages != null) 'sourceImages': sourceImages,
      };
}

class ReportFormData {
  final String organizationName;
  final String fullName;
  final String email;
  final String phone;
  final String location;
  final String reportName;
  final String reportDescription;

  ReportFormData(
      {this.organizationName = '',
      this.fullName = '',
      this.email = '',
      this.phone = '',
      this.location = '',
      this.reportName = '',
      this.reportDescription = ''});

  factory ReportFormData.fromJson(Map<String, dynamic> json) => ReportFormData(
        organizationName: json['organizationName'] ?? '',
        fullName: json['fullName'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        location: json['location'] ?? '',
        reportName: json['reportName'] ?? '',
        reportDescription: json['reportDescription'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'organizationName': organizationName,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'location': location,
        'reportName': reportName,
        'reportDescription': reportDescription,
      };
}
