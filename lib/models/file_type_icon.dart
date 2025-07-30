import 'package:flutter/material.dart';

class FileTypeIcon extends StatelessWidget {
  final String fileType;

  const FileTypeIcon({super.key, required this.fileType});

  @override
  Widget build(BuildContext context) {
    IconData icon;

    if (fileType.startsWith('image')) {
      icon = Icons.image;
    } else if (fileType.startsWith('video')) {
      icon = Icons.videocam;
    } else if (fileType.contains('pdf')) {
      icon = Icons.picture_as_pdf;
    } else {
      icon = Icons.insert_drive_file;
    }

    return Icon(icon, size: 30);
  }
}
