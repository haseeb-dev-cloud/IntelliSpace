// lib/screens/enhanced_all_files_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/all_files_model.dart';
import '../services/supabase_service.dart';
import '../services/folders_service.dart';
import '../services/file_upload_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/file_type_icon.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart' as provider_package;
import 'duplicates_screen.dart';
import '../services/compression_service.dart';

class AllFilesScreen extends StatefulWidget {
  const AllFilesScreen({Key? key}) : super(key: key);

  @override
  State<AllFilesScreen> createState() => AllFilesScreenState();
}

class AllFilesScreenState extends State<AllFilesScreen> {
  List<UserFile> _allFiles = [];
  List<FolderModel> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllFilesAndFolders();
  }

  Future<void> _loadAllFilesAndFolders() async {
    // Get only files that are NOT in folders (folder_id is null)
    final files = await SupabaseService.getRootFilesForUser();
    final folders = await FoldersService.getUserFolders();
    setState(() {
      _allFiles = files;
      _folders = folders;
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
                "Applying advanced compression to: ${file.filename}",
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
      if (mounted) Navigator.pop(context);

      // Show success dialog with compression stats
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
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await OpenFilex.open(compressedFile.localPath);
                },
                child: const Text("Open Compressed File"),
              ),
            ],
          ),
        );
      }

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.compress, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("File compressed with ${compressedFile.compressionRatio.toStringAsFixed(1)}% space savings"),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: "Open",
              onPressed: () => OpenFilex.open(compressedFile.localPath),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if open
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error compressing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            // Add compression option
            ListTile(
              leading: const Icon(Icons.compress, color: Colors.green),
              title: const Text('Compress File', style: TextStyle(color: Colors.green)),
              subtitle: const Text('Huffman/LZW compression',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                _compressFile(file);
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
                  _loadAllFilesAndFolders();
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
    final isPdf = file.fileType.toLowerCase() == 'pdf';

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
            Text("Size: ${formatBytes(file.size)}", style: TextStyle(color: themeService.textColor)),
            const SizedBox(height: 4),
            Text("Uploaded: ${formatDate(file.uploadedAt)}", style: TextStyle(color: themeService.textColor)),
            const SizedBox(height: 8),
            const Divider(),
            const Row(
              children: [
                Icon(Icons.compress, size: 16, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  "Compression Available",
                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              isPdf ? "• Huffman Coding\n• LZW Algorithm" : "• Advanced Compression",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
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

  void _showBrowseOptions() {
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: themeService.cardColor,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.create_new_folder, color: themeService.textColor),
              title: Text('Create Folder', style: TextStyle(color: themeService.textColor)),
              onTap: () {
                Navigator.pop(context);
                _showCreateFolderDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: themeService.textColor),
              title: Text('Find Duplicates', style: TextStyle(color: themeService.textColor)),
              onTap: () {
                Navigator.pop(context);
                _navigateToDuplicates();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("Create New Folder", style: TextStyle(color: themeService.textColor)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: themeService.textColor),
          decoration: const InputDecoration(
            labelText: "Folder Name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final folderId = await FoldersService.createFolder(controller.text.trim());
                if (folderId != null) {
                  Navigator.pop(context);
                  _loadAllFilesAndFolders();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Folder created successfully")),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to create folder")),
                  );
                }
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToDuplicates() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DuplicatesScreen(),
      ),
    );
  }

  void _openFolder(FolderModel folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderViewScreen(folder: folder),
      ),
    ).then((_) => _loadAllFilesAndFolders());
  }

  @override
  Widget build(BuildContext context) {
    return provider_package.Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text("Browse Files"),
            backgroundColor: themeService.bgColor,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: _showBrowseOptions,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_allFiles.isEmpty && _folders.isEmpty)
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: themeService.subtextColor),
                const SizedBox(height: 16),
                Text("No files or folders found",
                    style: TextStyle(fontSize: 16, color: themeService.subtextColor)),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _folders.length + _allFiles.length,
            itemBuilder: (context, index) {
              // Show folders first
              if (index < _folders.length) {
                final folder = _folders[index];
                return Card(
                  color: themeService.cardColor,
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.folder,
                        color: Colors.amber, size: 32),
                    title: Text(folder.name,
                        style: TextStyle(color: themeService.textColor,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text("${folder.fileCount} files",
                        style: TextStyle(color: themeService.subtextColor)),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: themeService.textColor),
                      onSelected: (value) async {
                        if (value == 'rename') {
                          _showRenameFolderDialog(folder);
                        } else if (value == 'delete') {
                          _showDeleteFolderDialog(folder);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _openFolder(folder),
                  ),
                );
              }

              // Show files after folders
              final file = _allFiles[index - _folders.length];
              return Card(
                color: themeService.cardColor,
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: FileTypeIcon(filename: file.filename),
                  title: Text(file.filename,
                      style: TextStyle(color: themeService.textColor)),
                  subtitle: Text(
                      "${formatBytes(file.size)} • ${formatDate(file.uploadedAt)}",
                      style: TextStyle(color: themeService.subtextColor)),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert, color: themeService.textColor),
                    onPressed: () => _showFileOptions(file),
                  ),
                  onTap: () => _openFile(file),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              FileUploadService.showUploadDialog(
                context,
                    ({onProgress}) => FileUploadService().pickAndUploadMultipleFiles(onProgress: onProgress),
              ).then((_) => _loadAllFilesAndFolders());
            },
            backgroundColor: themeService.bgColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  void _showRenameFolderDialog(FolderModel folder) {
    final controller = TextEditingController(text: folder.name);
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("Rename Folder", style: TextStyle(color: themeService.textColor)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: themeService.textColor),
          decoration: const InputDecoration(
            labelText: "Folder Name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final success = await FoldersService.renameFolder(folder.id, controller.text.trim());
                Navigator.pop(context);
                if (success) {
                  _loadAllFilesAndFolders();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Folder renamed successfully")),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to rename folder")),
                  );
                }
              }
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(FolderModel folder) {
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("Delete Folder", style: TextStyle(color: themeService.textColor)),
        content: Text(
          "Are you sure you want to delete '${folder.name}' and all its files? This action cannot be undone.",
          style: TextStyle(color: themeService.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await FoldersService.deleteFolder(folder.id);
              if (success) {
                _loadAllFilesAndFolders();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Folder deleted successfully")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to delete folder")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Folder View Screen
class FolderViewScreen extends StatefulWidget {
  final FolderModel folder;

  const FolderViewScreen({Key? key, required this.folder}) : super(key: key);

  @override
  State<FolderViewScreen> createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends State<FolderViewScreen> {
  List<UserFile> _folderFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolderFiles();
  }

  Future<void> _loadFolderFiles() async {
    final files = await FoldersService.getFolderFiles(widget.folder.id);
    setState(() {
      _folderFiles = files.map((e) => UserFile.fromJson(e)).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return provider_package.Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(widget.folder.name),
            backgroundColor: themeService.bgColor,
            foregroundColor: Colors.white,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _folderFiles.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: themeService.subtextColor),
                const SizedBox(height: 16),
                Text("This folder is empty",
                    style: TextStyle(fontSize: 16, color: themeService.subtextColor)),
                const SizedBox(height: 8),
                Text("Tap + to add files",
                    style: TextStyle(color: themeService.subtextColor)),
              ],
            ),
          )
              : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _folderFiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final file = _folderFiles[index];
              return Card(
                color: themeService.cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: FileTypeIcon(filename: file.filename),
                  title: Text(file.filename,
                      style: TextStyle(color: themeService.textColor)),
                  subtitle: Text(
                      "${_formatBytes(file.size)} • ${_formatDate(file.uploadedAt)}",
                      style: TextStyle(color: themeService.subtextColor)),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert, color: themeService.textColor),
                    onPressed: () => _showFileOptions(file),
                  ),
                  onTap: () => _openFile(file),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              FileUploadService.showUploadDialog(
                context,
                    ({onProgress}) => FileUploadService().uploadFilesToFolder(widget.folder.id, onProgress: onProgress),
              ).then((_) => _loadFolderFiles());
            },
            backgroundColor: themeService.bgColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
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

  // Helper methods for compression functionality
  String formatBytes(int bytes) {
    return _formatBytes(bytes);
  }

  String formatDate(DateTime dt) {
    return _formatDate(dt);
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
                "Applying advanced compression to: ${file.filename}",
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
      if (mounted) Navigator.pop(context);

      // Show success dialog with compression stats
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
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await OpenFilex.open(compressedFile.localPath);
                },
                child: const Text("Open Compressed File"),
              ),
            ],
          ),
        );
      }

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.compress, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("File compressed with ${compressedFile.compressionRatio.toStringAsFixed(1)}% space savings"),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: "Open",
              onPressed: () => OpenFilex.open(compressedFile.localPath),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if open
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error compressing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            // Add compression option
            ListTile(
              leading: const Icon(Icons.compress, color: Colors.green),
              title: const Text('Compress File', style: TextStyle(color: Colors.green)),
              subtitle: const Text('Huffman/LZW compression',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                _compressFile(file);
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
                  _loadFolderFiles();
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

  void _showFileInfo(UserFile file) {
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);
    final isPdf = file.fileType.toLowerCase() == 'pdf';

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
            Text("Size: ${formatBytes(file.size)}", style: TextStyle(color: themeService.textColor)),
            const SizedBox(height: 4),
            Text("Uploaded: ${formatDate(file.uploadedAt)}", style: TextStyle(color: themeService.textColor)),
            const SizedBox(height: 8),
            const Divider(),
            const Row(
              children: [
                Icon(Icons.compress, size: 16, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  "Compression Available",
                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              isPdf ? "• Huffman Coding\n• LZW Algorithm" : "• Advanced Compression",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
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
}