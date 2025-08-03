import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/all_files_model.dart';
import '../services/supabase_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/file_type_icon.dart';

class AllFilesScreen extends StatefulWidget {
  const AllFilesScreen({Key? key}) : super(key: key);

  @override
  State<AllFilesScreen> createState() => _AllFilesScreenState();
}

class _AllFilesScreenState extends State<AllFilesScreen> {
  List<UserFile> _allFiles = [];
  bool _isLoading = true;
  String? _previewUrl;

  @override
  void initState() {
    super.initState();
    _loadAllFiles();
  }

  Future<void> _loadAllFiles() async {
    final files = await SupabaseService.getAllFilesForUser();
    setState(() {
      _allFiles = files;
      _isLoading = false;
    });
  }

  String formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  String formatDate(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Future<void> _shareFile(UserFile file) async {
    try {
      final url = await SupabaseService.getSignedUrl(file.path);
      final response = await http.get(Uri.parse(url));
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${file.filename}');
      await tempFile.writeAsBytes(response.bodyBytes);

      await Share.shareXFiles([XFile(tempFile.path)], text: 'Shared from IntelliSpace');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing file: $e')),
      );
    }
  }

  void _showFileOptions(UserFile file) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () async {
                Navigator.pop(context);
                await SupabaseService.downloadFile(file.path, file.filename);
                // Show download notification
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.download_done, color: Colors.white),
                        const SizedBox(width: 8),
                        Text("Downloaded: ${file.filename}"),
                      ],
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () async {
                Navigator.pop(context);
                await _shareFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                await SupabaseService.deleteFile(file.path);
                _loadAllFiles();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('File Info'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("File Info"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.filename,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text("Size: ${formatBytes(file.size)}"),
                        const SizedBox(height: 4),
                        Text("Uploaded: ${formatDate(file.uploadedAt)}"),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFile(UserFile file) async {
    final url = await SupabaseService.getSignedUrl(file.path);

    if (file.fileType.startsWith('image/')) {
      setState(() {
        _previewUrl = url;
      });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: Image.network(url),
        ),
      );
    } else if (file.fileType.startsWith('video/')) {
      // Download and open video file using system gallery/player
      final response = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${file.filename}';
      final localFile = File(filePath);
      await localFile.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(filePath);
    } else if (file.filename.toLowerCase().endsWith('.pdf')) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: SizedBox(
            width: 300,
            height: 400,
            child: SfPdfViewer.network(url),
          ),
        ),
      );
    } else {
      // Download and open file
      final response = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${file.filename}';
      final localFile = File(filePath);
      await localFile.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(filePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(0xFF0A3D62);

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Files"),
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allFiles.isEmpty
          ? const Center(child: Text("No files found"))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _allFiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final file = _allFiles[index];
          return ListTile(
            leading: FileTypeIcon(filename: file.filename),
            title: Text(file.filename),
            subtitle: Text(
                "${formatBytes(file.size)} • ${formatDate(file.uploadedAt)}"),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showFileOptions(file),
            ),
            onTap: () => _openFile(file),
          );
        },
      ),
    );
  }
}