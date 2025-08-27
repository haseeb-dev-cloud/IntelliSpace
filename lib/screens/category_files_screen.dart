// lib/screens/category_files_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/file_type_icon.dart';
import '../models/all_files_model.dart';
import '../services/supabase_service.dart';
import '../services/ai_service.dart';
import '../services/downloads_service.dart';
import '../services/compression_service.dart';

class CategoryFilesScreen extends StatefulWidget {
  final String fileType;

  const CategoryFilesScreen({Key? key, required this.fileType})
      : super(key: key);

  @override
  State<CategoryFilesScreen> createState() => CategoryFilesScreenState();
}

class CategoryFilesScreenState extends State<CategoryFilesScreen> {
  List<UserFile> categoryFiles = [];
  bool isLoading = true;
  String? _previewUrl;

  @override
  void initState() {
    super.initState();
    fetchCategoryFiles();
  }

  Future<void> fetchCategoryFiles() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Get all files and filter by category
    final response = await Supabase.instance.client
        .from('user_files')
        .select()
        .eq('user_id', userId)
        .order('uploaded_at', ascending: false);

    final allFiles = (response as List).map((e) => UserFile.fromJson(e)).toList();

    // Filter files based on category
    List<UserFile> filteredFiles = [];

    if (widget.fileType == 'image') {
      filteredFiles = allFiles.where((file) {
        final ext = file.fileType.toLowerCase();
        return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'].contains(ext);
      }).toList();
    } else if (widget.fileType == 'video') {
      filteredFiles = allFiles.where((file) {
        final ext = file.fileType.toLowerCase();
        return ['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm'].contains(ext);
      }).toList();
    } else if (widget.fileType == 'pdf') {
      filteredFiles = allFiles.where((file) {
        final ext = file.fileType.toLowerCase();
        return ext == 'pdf';
      }).toList();
    }

    setState(() {
      categoryFiles = filteredFiles;
      isLoading = false;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  Future<void> _compressFile(UserFile file) async {
    if (!mounted) return;

    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text("Compressing file..."),
              const SizedBox(height: 8),
              Text(
                "Applying compression to: ${file.filename}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Download file temporarily for compression
      final url = await SupabaseService.getSignedUrl(file.path);
      final response = await http.get(Uri.parse(url));
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${file.filename}');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Compress the file
      final compressedFile = await CompressionService.compressFile(
        tempFile.path,
        file.filename,
      );

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // Close progress dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.compress, color: Colors.green),
                const SizedBox(width: 8),
                const Text("File Compressed"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Successfully compressed: ${file.filename}"),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Original Size:"),
                    Text(formatBytes(compressedFile.originalSize)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Compressed Size:"),
                    Text(formatBytes(compressedFile.compressedSize),
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Space Saved:"),
                    Text("${compressedFile.compressionRatio.toStringAsFixed(1)}%",
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Method: ${compressedFile.compressionMethod}",
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
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
    } catch (e) {
      // Close progress dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Error compressing file: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _summarizePdf(UserFile file) async {
    if (!mounted) return;

    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text("Analyzing PDF with AI..."),
              const SizedBox(height: 8),
              Text(
                "Summarizing: ${file.filename}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Download PDF temporarily
      final url = await SupabaseService.getSignedUrl(file.path);
      final response = await http.get(Uri.parse(url));
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${file.filename}');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Generate summary
      final summary = await AiService.summarizePdf(tempFile.path);

      // Create summary file
      final summaryFile = await AiService.createSummarizedFile(file.filename, summary);

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // Close progress dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show simple success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.smart_toy, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("AI Summary generated successfully!"),
                      Text(
                        "Summary saved to Archives • ${file.filename}",
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 4),

          ),
        );
      }
    } catch (e) {
      // Close progress dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Error summarizing PDF: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFileOptions(UserFile file) {
    final isPdf = file.fileType.toLowerCase() == 'pdf';

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

                try {
                  await SupabaseService.downloadFile(file.path, file.filename);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.download_done, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text("Downloaded: ${file.filename}"),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Download failed: $e')),
                          ],
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            // Add compression option for all file types
            ListTile(
              leading: const Icon(Icons.compress, color: Colors.green),
              title: const Text('Compress File', style: TextStyle(color: Colors.green)),
              onTap: () {
                Navigator.pop(context);
                _compressFile(file);
              },
            ),
            if (isPdf) // Add summarize option for PDFs
              ListTile(
                leading: const Icon(Icons.summarize, color: Colors.blue),
                title: const Text('Summarize with AI', style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.pop(context);
                  _summarizePdf(file);
                },
              ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete File'),
                    content: const Text('Are you sure you want to delete this file?'),
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
                  await SupabaseService.deleteFile(file.path);
                  fetchCategoryFiles(); // Refresh the list
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("File deleted successfully."))
                    );
                  }
                }
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
                    content: SingleChildScrollView(
                      child: Column(
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
                          if (isPdf) ...[
                            const SizedBox(height: 8),
                            const Divider(),
                            const Row(
                              children: [
                                Icon(Icons.smart_toy, size: 16, color: Colors.blue),
                                SizedBox(width: 4),
                                Text(
                                  "AI Features Available",
                                  style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Text(
                              "• AI Summarization",
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
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
    final ext = file.fileType.toLowerCase();

    // Check if it's an image
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'].contains(ext)) {
      setState(() {
        _previewUrl = url;
      });
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(
                    file.filename,
                    style: const TextStyle(fontSize: 16),
                  ),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.error, size: 64, color: Colors.red),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Check if it's a video - USE SAME LOGIC AS BROWSE SECTION
    else if (['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm'].contains(ext)) {
      // Download and open video file using system gallery/player
      try {
        final response = await http.get(Uri.parse(url));
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/${file.filename}';
        final localFile = File(filePath);
        await localFile.writeAsBytes(response.bodyBytes);
        await OpenFilex.open(filePath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening video: $e')),
          );
        }
      }
    }
    // Check if it's a PDF
    else if (ext == 'pdf') {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              children: [
                AppBar(
                  title: Text(
                    file.filename,
                    style: const TextStyle(fontSize: 16),
                  ),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.summarize),
                      onPressed: () {
                        Navigator.pop(context);
                        _summarizePdf(file);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: SfPdfViewer.network(url),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // For other file types, download and open
    else {
      try {
        final response = await http.get(Uri.parse(url));
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/${file.filename}';
        final localFile = File(filePath);
        await localFile.writeAsBytes(response.bodyBytes);
        await OpenFilex.open(filePath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening file: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0A3D62);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${widget.fileType.toUpperCase()} Files',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.fileType == 'pdf') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : categoryFiles.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.fileType == 'image'
                  ? Icons.image
                  : widget.fileType == 'pdf'
                  ? Icons.picture_as_pdf
                  : Icons.videocam,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${widget.fileType} files found.',
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload some files to get started',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categoryFiles.length,
        itemBuilder: (context, index) {
          final file = categoryFiles[index];
          final isPdf = file.fileType.toLowerCase() == 'pdf';

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Stack(
                children: [
                  FileTypeIcon(filename: file.filename),
                  if (isPdf)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.smart_toy,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                file.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatBytes(file.size)} • ${formatDate(file.uploadedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isPdf)
                    const Text(
                      'AI features available',
                      style: TextStyle(color: Colors.blue, fontSize: 11),
                    ),
                ],
              ),
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