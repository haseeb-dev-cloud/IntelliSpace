import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/all_files_model.dart';
import '../models/file_type_icon.dart';
import '../services/supabase_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserFile> _allFiles = [];
  List<UserFile> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadAllFiles();
  }

  Future<void> _loadAllFiles() async {
    setState(() => _isLoading = true);
    final files = await SupabaseService.getAllFilesForUser();
    setState(() {
      _allFiles = files;
      _isLoading = false;
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    final results = _allFiles.where((file) {
      return file.filename.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _searchResults = results;
      _hasSearched = true;
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
                  _loadAllFiles(); // Refresh files
                  _performSearch(_searchController.text); // Refresh search results
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("File deleted successfully.")),
                  );
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
    final ext = file.fileType.toLowerCase();

    // Check if it's an image
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'].contains(ext)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: SizedBox(
            width: 300,
            height: 400,
            child: Image.network(url, fit: BoxFit.contain),
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
    // Check if it's a video - USE SAME LOGIC AS CATEGORIES SECTION
    else if (['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm'].contains(ext)) {
      try {
        final response = await http.get(Uri.parse(url));
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/${file.filename}';
        final localFile = File(filePath);
        await localFile.writeAsBytes(response.bodyBytes);
        await OpenFilex.open(filePath);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening video: $e')),
        );
      }
    }
    // Check if it's a PDF
    else if (ext == 'pdf') {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: SizedBox(
            width: 300,
            height: 400,
            child: SfPdfViewer.network(url),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(0xFF0A3D62);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Search Files"),
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search files by name...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch("");
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _performSearch,
            ),
          ),
          
          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              "Search your files",
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            Text(
                              "Enter a filename to start searching",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  "No files found",
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                Text(
                                  "Try a different search term",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final file = _searchResults[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: FileTypeIcon(filename: file.filename),
                                  title: Text(
                                    file.filename,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    "${formatBytes(file.size)} • ${formatDate(file.uploadedAt)}",
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
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}