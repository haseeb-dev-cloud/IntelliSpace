// lib/screens/file_preview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../services/supabase_service.dart';

class FilePreviewScreen extends StatefulWidget {
  final String filePath;
  final String fileType;
  final String fileName;
  final int fileSize;
  final bool isLocalFile;

  const FilePreviewScreen({
    super.key,
    required this.filePath,
    required this.fileType,
    required this.fileName,
    required this.fileSize,
    this.isLocalFile = false,
  });

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  String? _signedUrl;
  VideoPlayerController? _videoController;
  String? _localFilePath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      if (widget.isLocalFile) {
        // File is already local (like compressed files)
        setState(() {
          _localFilePath = widget.filePath;
          _isLoading = false;
        });

        if (widget.fileType.startsWith('video/')) {
          _videoController = VideoPlayerController.file(File(widget.filePath));
          await _videoController!.initialize();
          setState(() {});
        }
      } else {
        // File needs to be downloaded from Supabase
        final url = await SupabaseService.getSignedUrl(widget.filePath);
        setState(() => _signedUrl = url);

        if (widget.fileType.startsWith('video/')) {
          _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
          await _videoController!.initialize();
          setState(() {});
        } else if (widget.fileType == 'application/pdf') {
          final file = await _downloadFileToLocal(url);
          setState(() => _localFilePath = file.path);
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preview: $e')),
        );
      }
    }
  }

  Future<File> _downloadFileToLocal(String url) async {
    final response = await http.get(Uri.parse(url));
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${widget.fileName}');
    return file.writeAsBytes(response.bodyBytes);
  }

  Future<void> _deleteFile() async {
    if (widget.isLocalFile) {
      // Handle local file deletion (for compressed files, etc.)
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: const Text('This file is managed by the application and cannot be deleted from here. Use the Archives screen to manage this file.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

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
      try {
        await SupabaseService.deleteFile(widget.filePath);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting file: $e')),
          );
        }
      }
    }
  }

  Future<void> _downloadFile() async {
    try {
      if (widget.isLocalFile) {
        // For local files, just show a message or copy to downloads
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is already available locally')),
        );
        return;
      }

      await SupabaseService.downloadFile(widget.filePath, widget.fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File downloaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading file: $e')),
        );
      }
    }
  }

  Future<void> _shareFile() async {
    try {
      String pathToShare;

      if (widget.isLocalFile) {
        pathToShare = widget.filePath;
      } else {
        // Download temporarily for sharing
        if (_signedUrl == null) return;
        final response = await http.get(Uri.parse(_signedUrl!));
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${widget.fileName}');
        await tempFile.writeAsBytes(response.bodyBytes);
        pathToShare = tempFile.path;
      }

      await Share.shareXFiles([XFile(pathToShare)], text: 'Shared from IntelliSpace');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  Widget _buildPreview() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.fileType.startsWith('image/')) {
      if (widget.isLocalFile) {
        return Image.file(File(widget.filePath), fit: BoxFit.contain);
      } else if (_signedUrl != null) {
        return Image.network(_signedUrl!, fit: BoxFit.contain);
      }
    } else if (widget.fileType.startsWith('video/')) {
      return _videoController != null && _videoController!.value.isInitialized
          ? Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          VideoProgressIndicator(_videoController!, allowScrubbing: true),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
                icon: Icon(
                  _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            ],
          ),
        ],
      )
          : const Center(child: CircularProgressIndicator());
    } else if (widget.fileType == 'application/pdf') {
      if (widget.isLocalFile) {
        return SfPdfViewer.file(File(widget.filePath));
      } else if (_localFilePath != null) {
        return SfPdfViewer.file(File(_localFilePath!));
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("Preview not available for this file type."),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              if (widget.isLocalFile) {
                // Try to open with system default app
                try {
                  await Process.run('open', [widget.filePath]);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot open file with system app')),
                  );
                }
              } else {
                _downloadFile();
              }
            },
            icon: Icon(widget.isLocalFile ? Icons.open_in_new : Icons.download),
            label: Text(widget.isLocalFile ? 'Open with System App' : 'Download File'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
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
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Download') {
                _downloadFile();
              } else if (value == 'Share') {
                _shareFile();
              } else if (value == 'Delete') {
                _deleteFile();
              } else if (value == 'Info') {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("File Info"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Name: ${widget.fileName}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text("Size: ${_formatFileSize(widget.fileSize)}"),
                        const SizedBox(height: 4),
                        Text("Type: ${widget.fileType}"),
                        if (widget.isLocalFile) ...[
                          const SizedBox(height: 4),
                          const Text("Location: Local file",
                              style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic)),
                        ],
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
              }
            },
            itemBuilder: (_) => [
              if (!widget.isLocalFile) ...[
                const PopupMenuItem(value: 'Download', child: Text("Download")),
                const PopupMenuItem(value: 'Delete', child: Text("Delete")),
              ],
              const PopupMenuItem(value: 'Share', child: Text("Share")),
              const PopupMenuItem(value: 'Info', child: Text("Info")),
            ],
          ),
        ],
      ),
      body: _buildPreview(),
    );
  }
}