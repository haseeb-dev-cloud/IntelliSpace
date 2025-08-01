import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/all_files_model.dart';
import '../services/supabase_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Download complete.")));
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
              subtitle: Text(
                "Size: ${formatBytes(file.size)}\nUploaded: ${formatDate(file.uploadedAt)}",
              ),
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
      showDialog(
        context: context,
        builder: (_) => _VideoPlayerDialog(url: url),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Files"),
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

class _VideoPlayerDialog extends StatefulWidget {
  final String url;

  const _VideoPlayerDialog({required this.url});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: 300,
        height: 400,
        child: _controller.value.isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
