import 'package:flutter/material.dart';
import 'package:intellispace/models/all_files_model.dart';

import 'package:video_player/video_player.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:intellispace/services/supabase_service.dart';

class FilePreviewScreen extends StatefulWidget {
  final UserFile file;

  const FilePreviewScreen({super.key, required this.file});

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  late Future<String> fileUrlFuture;

  @override
  void initState() {
    super.initState();
    fileUrlFuture = SupabaseService().getFileUrl(widget.file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.file.filename)),
      body: FutureBuilder<String>(
        future: fileUrlFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("Error loading file"));
          } else {
            final url = snapshot.data!;
            if (widget.file.fileType.startsWith('image')) {
              return Center(child: Image.network(url));
            } else if (widget.file.fileType.startsWith('video')) {
              return VideoPlayerWidget(videoUrl: url);
            } else if (widget.file.fileType.contains('pdf')) {
              return PDFView(filePath: url);
            } else {
              return Center(child: Text("Unsupported file type"));
            }
          }
        },
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    )
        : const Center(child: CircularProgressIndicator());
  }
}
