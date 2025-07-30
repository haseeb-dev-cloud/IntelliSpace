class RecentFile {
  final String id;
  final String filename;
  final String fileType;
  final int size;
  final DateTime uploadedAt;

  RecentFile({
    required this.id,
    required this.filename,
    required this.fileType,
    required this.size,
    required this.uploadedAt,
  });

  factory RecentFile.fromJson(Map<String, dynamic> json) {
    return RecentFile(
      id: json['id'],
      filename: json['filename'],
      fileType: json['file_type'],
      size: json['size'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }
}
