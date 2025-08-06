// lib/screens/duplicates_screen.dart
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
import '../services/folders_service.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart' as provider_package;

class DuplicateGroup {
  final String filename;
  final int size;
  final List<UserFile> files;

  DuplicateGroup({
    required this.filename,
    required this.size,
    required this.files,
  });
}

class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({Key? key}) : super(key: key);

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  List<DuplicateGroup> _duplicateGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _findDuplicateFiles();
  }

  Future<void> _findDuplicateFiles() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get all user files
      final response = await Supabase.instance.client
          .from('user_files')
          .select('*')
          .eq('user_id', user.id);

      final List<UserFile> allFiles = 
          (response as List).map((e) => UserFile.fromJson(e)).toList();

      // Group files by filename and size
      Map<String, List<UserFile>> fileGroups = {};
      
      for (final file in allFiles) {
        final key = '${file.filename}_${file.size}';
        if (fileGroups.containsKey(key)) {
          fileGroups[key]!.add(file);
        } else {
          fileGroups[key] = [file];
        }
      }

      // Filter groups that have more than one file (duplicates)
      List<DuplicateGroup> duplicates = [];
      fileGroups.forEach((key, group) {
        if (group.length > 1) {
          duplicates.add(DuplicateGroup(
            filename: group.first.filename,
            size: group.first.size,
            files: group,
          ));
        }
      });

      setState(() {
        _duplicateGroups = duplicates;
        _isLoading = false;
      });
    } catch (e) {
      print('Error finding duplicates: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  String _formatDate(DateTime dt) {
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
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: themeService.cardColor,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.download, color: themeService.textColor),
              title: Text('Download', style: TextStyle(color: themeService.textColor)),
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
              leading: Icon(Icons.share, color: themeService.textColor),
              title: Text('Share', style: TextStyle(color: themeService.textColor)),
              onTap: () async {
                Navigator.pop(context);
                await _shareFile(file);
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
                  _findDuplicateFiles(); // Refresh the list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("File deleted successfully.")),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.info, color: themeService.textColor),
              title: Text('File Info', style: TextStyle(color: themeService.textColor)),
              onTap: () {
                Navigator.pop(context);
                _showFileInfo(file);
              },
            ),
          ],
        );
      },
    );
  }

  void _showFileInfo(UserFile file) {
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("File Info", style: TextStyle(color: themeService.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.filename,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeService.textColor),
            ),
            const SizedBox(height: 8),
            Text("Size: ${_formatBytes(file.size)}", style: TextStyle(color: themeService.textColor)),
            const SizedBox(height: 4),
            Text("Uploaded: ${_formatDate(file.uploadedAt)}", style: TextStyle(color: themeService.textColor)),
            const SizedBox(height: 4),
            Text("Path: ${file.path}", style: TextStyle(color: themeService.subtextColor, fontSize: 12)),
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
    // Check if it's a video
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

  Future<void> _deleteAllButOne(DuplicateGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Duplicates'),
        content: Text(
          'This will delete ${group.files.length - 1} duplicate files and keep the most recent one. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Duplicates', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Sort by upload date and keep the most recent
      final sortedFiles = List<UserFile>.from(group.files)
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      // Delete all but the first (most recent)
      for (int i = 1; i < sortedFiles.length; i++) {
        await SupabaseService.deleteFile(sortedFiles[i].path);
      }

      _findDuplicateFiles(); // Refresh the list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Deleted ${sortedFiles.length - 1} duplicate files"),
        ),
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
            title: const Text("Duplicate Files"),
            backgroundColor: themeService.bgColor,
            foregroundColor: Colors.white,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _duplicateGroups.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  "No duplicate files found!",
                  style: TextStyle(fontSize: 18, color: themeService.textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your storage is optimized",
                  style: TextStyle(color: themeService.subtextColor),
                ),
              ],
            ),
          )
              : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _duplicateGroups.length,
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, groupIndex) {
              final group = _duplicateGroups[groupIndex];
              return Container(
                decoration: BoxDecoration(
                  color: themeService.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.copy, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.filename,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: themeService.textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "${group.files.length} duplicates • ${_formatBytes(group.size)} each",
                                  style: TextStyle(
                                    color: themeService.subtextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _deleteAllButOne(group),
                            icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 16),
                            label: const Text(
                              "Clean Up",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Files in group
                    ...group.files.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      final isLast = index == group.files.length - 1;
                      
                      return Container(
                        decoration: BoxDecoration(
                          border: isLast ? null : Border(
                            bottom: BorderSide(
                              color: themeService.subtextColor.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: ListTile(
                          leading: FileTypeIcon(filename: file.filename),
                          title: Text(
                            file.filename,
                            style: TextStyle(color: themeService.textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Uploaded: ${_formatDate(file.uploadedAt)}",
                                style: TextStyle(
                                  color: themeService.subtextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                "Path: ${file.path}",
                                style: TextStyle(
                                  color: themeService.subtextColor,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.more_vert, color: themeService.textColor),
                            onPressed: () => _showFileOptions(file),
                          ),
                          onTap: () => _openFile(file),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}