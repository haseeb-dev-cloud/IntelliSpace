import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/file_type_icon.dart';
import '../services/downloads_service.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadedFile> _downloadedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    final files = await DownloadsService.getDownloadedFiles();
    setState(() {
      _downloadedFiles = files;
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

  Future<void> _shareFile(DownloadedFile file) async {
    try {
      await Share.shareXFiles([XFile(file.localPath)], text: 'Shared from IntelliSpace');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing file: $e')),
      );
    }
  }

  Future<void> _deleteFile(DownloadedFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Downloaded File'),
        content: const Text('Are you sure you want to delete this downloaded file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DownloadsService.deleteDownloadedFile(file.filename);
      _loadDownloadedFiles();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Downloaded file deleted successfully.")),
      );
    }
  }

  void _showFileOptions(DownloadedFile file) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () async {
                Navigator.pop(context);
                await OpenFilex.open(file.localPath);
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
                await _deleteFile(file);
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
                        Text("Downloaded: ${formatDate(file.downloadedAt)}"),
                        const SizedBox(height: 4),
                        Text("Location: ${file.localPath}"),
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

  Future<void> _openFile(DownloadedFile file) async {
    await OpenFilex.open(file.localPath);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(0xFF0A3D62);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Downloads"),
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloadedFiles.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No downloaded files",
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Files you download will appear here",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _downloadedFiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final file = _downloadedFiles[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: FileTypeIcon(filename: file.filename),
                    title: Text(file.filename),
                    subtitle: Text(
                        "${formatBytes(file.size)} • ${formatDate(file.downloadedAt)}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showFileOptions(file),
                    ),
                    onTap: () => _openFile(file),
                  ),
                );
              },
            ),
    );
  }
}