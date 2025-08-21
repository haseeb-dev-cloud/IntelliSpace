// lib/screens/compressed_files_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/compression_service.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart' as provider_package;

class CompressedFilesScreen extends StatefulWidget {
  const CompressedFilesScreen({Key? key}) : super(key: key);

  @override
  State<CompressedFilesScreen> createState() => _CompressedFilesScreenState();
}

class _CompressedFilesScreenState extends State<CompressedFilesScreen> {
  List<CompressedFile> _compressedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompressedFiles();
  }

  Future<void> _loadCompressedFiles() async {
    final files = await CompressionService.getCompressedFiles();
    setState(() {
      _compressedFiles = files;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  /// Fixed compressed file opening - DECOMPRESS FIRST, then open
  Future<void> _openCompressedFile(CompressedFile compressedFile) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Decompressing file...'),
          ],
        ),
      ),
    );

    try {
      // STEP 1: Decompress the file first
      final decompressedPath = await CompressionService.decompressFile(compressedFile);

      // Close loading dialog
      Navigator.pop(context);

      // STEP 2: Now open the decompressed file
      final ext = compressedFile.originalFilename.split('.').last.toLowerCase();
      final decompressedFile = File(decompressedPath);

      if (!await decompressedFile.exists()) {
        throw Exception('Decompressed file not found');
      }

      // Check if it's an image
      if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'].contains(ext)) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: SizedBox(
              width: 300,
              height: 400,
              child: Image.file(decompressedFile, fit: BoxFit.contain),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      // Check if it's a video
      else if (['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm'].contains(ext)) {
        await OpenFilex.open(decompressedPath);
      }
      // Check if it's a PDF
      else if (ext == 'pdf') {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: SizedBox(
              width: 300,
              height: 400,
              child: SfPdfViewer.file(decompressedFile),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      // For other file types, open with system default
      else {
        await OpenFilex.open(decompressedPath);
      }
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening compressed file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareFile(CompressedFile compressedFile) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing file for sharing...'),
          ],
        ),
      ),
    );

    try {
      // Decompress file first
      final decompressedPath = await CompressionService.decompressFile(compressedFile);

      // Close loading dialog
      Navigator.pop(context);

      // Share the decompressed file
      await Share.shareXFiles([XFile(decompressedPath)],
          text: 'File: ${compressedFile.originalFilename}');
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFileOptions(CompressedFile compressedFile) {
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: themeService.cardColor,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.open_in_new, color: themeService.textColor),
              title: Text('Open File', style: TextStyle(color: themeService.textColor)),
              onTap: () async {
                Navigator.pop(context);
                _openCompressedFile(compressedFile);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: themeService.textColor),
              title: Text('Share Original', style: TextStyle(color: themeService.textColor)),
              onTap: () async {
                Navigator.pop(context);
                await _shareFile(compressedFile);
              },
            ),
            ListTile(
              leading: Icon(Icons.archive, color: Colors.orange),
              title: Text('Share Compressed', style: TextStyle(color: Colors.orange)),
              subtitle: Text('Share as compressed file', style: TextStyle(color: themeService.subtextColor, fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await Share.shareXFiles([XFile(compressedFile.localPath)],
                      text: 'Compressed file: ${compressedFile.originalFilename}');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sharing compressed file: $e')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.download, color: Colors.blue),
              title: Text('Extract to Downloads', style: TextStyle(color: Colors.blue)),
              onTap: () async {
                Navigator.pop(context);
                _extractToDownloads(compressedFile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Compressed File'),
                    content: const Text('Are you sure you want to delete this compressed file?'),
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
                  await CompressionService.deleteCompressedFile(compressedFile.filename);
                  _loadCompressedFiles();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Compressed file deleted successfully.")),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.info, color: themeService.textColor),
              title: Text('File Info', style: TextStyle(color: themeService.textColor)),
              onTap: () {
                Navigator.pop(context);
                _showFileInfo(compressedFile);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _extractToDownloads(CompressedFile compressedFile) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Extracting to Downloads...'),
          ],
        ),
      ),
    );

    try {
      // Decompress file
      final decompressedPath = await CompressionService.decompressFile(compressedFile);

      // Get downloads directory
      final dir = await getDownloadsDirectory();
      Directory downloadsDir;

      if (dir == null) {
        // Fallback to app documents directory if downloads is not available
        final appDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory('${appDir.path}/Downloads');
        if (!downloadsDir.existsSync()) {
          downloadsDir.createSync(recursive: true);
        }
      } else {
        downloadsDir = dir;
      }

      // Copy decompressed file to downloads
      final decompressedFile = File(decompressedPath);
      final downloadPath = '${downloadsDir.path}/${compressedFile.originalFilename}';
      await decompressedFile.copy(downloadPath);

      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File extracted to Downloads: ${compressedFile.originalFilename}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error extracting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFileInfo(CompressedFile compressedFile) {
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Row(
          children: [
            Icon(Icons.compress, color: Colors.green),
            const SizedBox(width: 8),
            Text("Compression Info", style: TextStyle(color: themeService.textColor)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Original File:",
                style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor),
              ),
              Text(compressedFile.originalFilename, style: TextStyle(color: themeService.subtextColor)),
              const SizedBox(height: 12),
              Text(
                "Compressed File:",
                style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor),
              ),
              Text(compressedFile.filename, style: TextStyle(color: themeService.subtextColor)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Original Size:", style: TextStyle(color: themeService.textColor)),
                  Text(CompressionService.formatBytes(compressedFile.originalSize),
                      style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Compressed Size:", style: TextStyle(color: themeService.textColor)),
                  Text(CompressionService.formatBytes(compressedFile.compressedSize),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Compression Ratio:", style: TextStyle(color: themeService.textColor)),
                  Text("${compressedFile.compressionRatio.toStringAsFixed(1)}%",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Method:", style: TextStyle(color: themeService.textColor)),
                  Flexible(
                    child: Text(compressedFile.compressionMethod,
                        style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text("Compressed: ${_formatDate(compressedFile.compressedAt)}",
                  style: TextStyle(color: themeService.textColor)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.compress, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Space Saved: ${CompressionService.formatBytes(compressedFile.originalSize - compressedFile.compressedSize)}",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openCompressedFile(compressedFile);
            },
            child: const Text("Open File"),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllCompressedFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Compressed Files'),
        content: const Text(
          'This will permanently delete all compressed files. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CompressionService.clearAllCompressedFiles();
      _loadCompressedFiles();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All compressed files deleted successfully.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return provider_package.Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.compress, color: Colors.white),
                const SizedBox(width: 8),
                const Text("Compressed Files"),
              ],
            ),
            backgroundColor: themeService.bgColor,
            foregroundColor: Colors.white,
            actions: [
              if (_compressedFiles.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'clear_all') {
                      _clearAllCompressedFiles();
                    } else if (value == 'stats') {
                      _showCompressionStats();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'stats',
                      child: Row(
                        children: [
                          Icon(Icons.bar_chart),
                          SizedBox(width: 8),
                          Text('Compression Stats'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Clear All', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _compressedFiles.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.compress, size: 64, color: themeService.subtextColor),
                const SizedBox(height: 16),
                Text(
                  "No Compressed Files Yet",
                  style: TextStyle(fontSize: 18, color: themeService.textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  "Compressed files will appear here when you use\nthe compression feature",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: themeService.subtextColor),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.green, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        "How to compress files:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "1. Go to Categories or Browse\n2. Tap the 3-dot menu on any file\n3. Select 'Compress File'",
                        style: TextStyle(color: themeService.textColor, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
              : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _compressedFiles.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final file = _compressedFiles[index];
              return Card(
                color: themeService.cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.green.withOpacity(0.2)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.compress, color: Colors.green),
                  ),
                  title: Text(
                    file.originalFilename,
                    style: TextStyle(
                      color: themeService.textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${CompressionService.formatBytes(file.originalSize)} → ${CompressionService.formatBytes(file.compressedSize)}",
                        style: TextStyle(
                          color: themeService.subtextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.trending_down, size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "${file.compressionRatio.toStringAsFixed(1)}% • ${file.compressionMethod} • ${_formatDate(file.compressedAt)}",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert, color: themeService.textColor),
                    onPressed: () => _showFileOptions(file),
                  ),
                  onTap: () => _openCompressedFile(file),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showCompressionStats() async {
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);
    final totalOriginal = await CompressionService.getTotalOriginalSize();
    final totalCompressed = await CompressionService.getTotalCompressedSize();
    final count = await CompressionService.getCompressionCount();
    final spaceSaved = totalOriginal - totalCompressed;
    final overallRatio = totalOriginal > 0 ? (spaceSaved / totalOriginal * 100) : 0.0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Row(
          children: [
            Icon(Icons.bar_chart, color: Colors.green),
            const SizedBox(width: 8),
            Text("Compression Statistics", style: TextStyle(color: themeService.textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total Files:", style: TextStyle(color: themeService.textColor)),
                Text("$count",
                    style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Original Size:", style: TextStyle(color: themeService.textColor)),
                Text(CompressionService.formatBytes(totalOriginal),
                    style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Compressed Size:", style: TextStyle(color: themeService.textColor)),
                Text(CompressionService.formatBytes(totalCompressed),
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Space Saved:", style: TextStyle(color: themeService.textColor, fontWeight: FontWeight.bold)),
                Text(CompressionService.formatBytes(spaceSaved),
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Overall Ratio:", style: TextStyle(color: themeService.textColor, fontWeight: FontWeight.bold)),
                Text("${overallRatio.toStringAsFixed(1)}%",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Files are compressed using RLE and GZIP algorithms. The best algorithm is automatically chosen for optimal compression.",
                style: TextStyle(
                  color: themeService.textColor,
                  fontSize: 12,
                ),
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
}