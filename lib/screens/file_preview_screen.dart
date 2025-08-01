import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';

class FilePreviewScreen extends StatefulWidget {
  final String filePath;
  final String fileType;
  final String fileName;
  final int fileSize;

  const FilePreviewScreen({
    super.key,
    required this.filePath,
    required this.fileType,
    required this.fileName,
    required this.fileSize,
  });

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  String? _signedUrl;
  VideoPlayerController? _videoController;
  String? _localPdfPath;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final url = await SupabaseService.getSignedUrl(widget.filePath);
    setState(() => _signedUrl = url);

    if (widget.fileType.startsWith('video/')) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      setState(() {});
      _videoController!.play();
    } else if (widget.fileType == 'application/pdf') {
      final file = await _downloadFileToLocal(url);
      setState(() => _localPdfPath = file.path);
    }
  }

  Future<File> _downloadFileToLocal(String url) async {
    final response = await http.get(Uri.parse(url));
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${widget.fileName}');
    return file.writeAsBytes(response.bodyBytes);
  }

  Future<void> _deleteFile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete File'),
        content: const Text('Are you sure you want to delete this file?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await SupabaseService.deleteFile(widget.filePath);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildPreview() {
    if (_signedUrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.fileType.startsWith('image/')) {
      return Image.network(_signedUrl!, fit: BoxFit.contain);
    } else if (widget.fileType.startsWith('video/')) {
      return _videoController != null && _videoController!.value.isInitialized
          ? AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      )
          : const Center(child: CircularProgressIndicator());
    } else if (widget.fileType == 'application/pdf') {
      return _localPdfPath != null
          ? PDFView(filePath: _localPdfPath!)
          : const Center(child: CircularProgressIndicator());
    } else {
      return const Center(child: Text("Preview not available for this file type."));
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Download') {
                SupabaseService.downloadFile(widget.filePath, widget.fileName);
              } else if (value == 'Delete') {
                _deleteFile();
              } else if (value == 'Info') {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("File Info"),
                    content: Text("Name: ${widget.fileName}\nSize: ${widget.fileSize} bytes"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Download', child: Text("Download")),
              PopupMenuItem(value: 'Delete', child: Text("Delete")),
              PopupMenuItem(value: 'Info', child: Text("Info")),
            ],
          ),
        ],
      ),
      body: _buildPreview(),
    );
  }
}
