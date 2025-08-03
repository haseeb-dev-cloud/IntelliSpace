class UserFile {
  final String path;
  final String filename;
  final String fileType;
  final int size;
  final DateTime uploadedAt;

  UserFile({
    required this.path,
    required this.filename,
    required this.fileType,
    required this.size,
    required this.uploadedAt,
  });

  factory UserFile.fromJson(Map<String, dynamic> json) {
    return UserFile(
      path: json['path'],
      filename: json['filename'],
      fileType: json['file_type'], //
      size: json['size'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }
}
