import 'package:flutter/material.dart';

class FileTypeIcon extends StatelessWidget {
  final String filename;

  const FileTypeIcon({Key? key, required this.filename}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final extension = filename.split('.').last.toLowerCase();
    IconData iconData;

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        iconData = Icons.image;
        break;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        iconData = Icons.videocam;
        break;
      case 'mp3':
      case 'wav':
      case 'aac':
        iconData = Icons.audiotrack;
        break;
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        break;
      case 'xls':
      case 'xlsx':
        iconData = Icons.table_chart;
        break;
      case 'txt':
      case 'md':
        iconData = Icons.notes;
        break;
      case 'zip':
      case 'rar':
      case '7z':
        iconData = Icons.archive;
        break;
      default:
        iconData = Icons.insert_drive_file;
    }

    return Icon(iconData, size: 30, color: Colors.blueGrey);
  }
}
