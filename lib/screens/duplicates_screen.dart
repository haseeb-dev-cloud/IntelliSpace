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
import '../services/ai_service.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart' as provider_package;

class DuplicateGroup {
  final String filename;
  final int size;
  final List<UserFile> files;
  final String type; // 'exact' or 'ai'
  final double? similarityScore;

  DuplicateGroup({
    required this.filename,
    required this.size,
    required this.files,
    required this.type,
    this.similarityScore,
  });
}

class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({Key? key}) : super(key: key);

  @override
  State<DuplicatesScreen> createState() => DuplicatesScreenState();
}

class DuplicatesScreenState extends State<DuplicatesScreen> with TickerProviderStateMixin {
  List<DuplicateGroup> _exactDuplicates = [];
  List<DuplicateGroup> _aiDuplicates = [];
  bool _isLoadingExact = true;
  bool _isLoadingAi = false;
  bool _hasTriedAiAnalysis = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _findExactDuplicates();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {}); // Trigger rebuild to show/hide refresh button
    }
  }

  Future<void> _findExactDuplicates() async {
    if (!mounted) return;

    setState(() => _isLoadingExact = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingExact = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('user_files')
          .select('*')
          .eq('user_id', user.id);

      final List<UserFile> allFiles =
      (response as List).map((e) => UserFile.fromJson(e)).toList();

      Map<String, List<UserFile>> fileGroups = {};

      for (final file in allFiles) {
        final key = '${file.filename}_${file.size}';
        if (fileGroups.containsKey(key)) {
          fileGroups[key]!.add(file);
        } else {
          fileGroups[key] = [file];
        }
      }

      List<DuplicateGroup> duplicates = [];
      fileGroups.forEach((key, group) {
        if (group.length > 1) {
          duplicates.add(DuplicateGroup(
            filename: group.first.filename,
            size: group.first.size,
            files: group,
            type: 'exact',
          ));
        }
      });

      if (mounted) {
        setState(() {
          _exactDuplicates = duplicates;
          _isLoadingExact = false;
        });
      }
    } catch (e) {
      print('Error finding exact duplicates: $e');
      if (mounted) setState(() => _isLoadingExact = false);
    }
  }

  Future<void> _findAiDuplicates() async {
    if (_isLoadingAi || !mounted) return;

    setState(() {
      _isLoadingAi = true;
      _hasTriedAiAnalysis = true;
    });

    try {
      final aiGroups = await AiService.findAiBasedDuplicates();

      List<DuplicateGroup> duplicates = aiGroups.map((group) => DuplicateGroup(
        filename: group.files.first.filename,
        size: group.files.first.size,
        files: group.files,
        type: 'ai',
        similarityScore: group.similarityScore,
      )).toList();

      if (mounted) {
        setState(() {
          _aiDuplicates = duplicates;
          _isLoadingAi = false;
        });
      }

      // Show completion message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                duplicates.isEmpty
                    ? 'No similar content found. Your files are unique!'
                    : 'Found ${duplicates.length} groups of similar content'
            ),
            backgroundColor: duplicates.isEmpty ? Colors.green : Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Error finding AI duplicates: $e');

      if (mounted) {
        setState(() => _isLoadingAi = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
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
                if (mounted) {
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
                }
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

                if (confirmed == true && mounted) {
                  await SupabaseService.deleteFile(file.path);
                  _findExactDuplicates();
                  if (_hasTriedAiAnalysis) {
                    _findAiDuplicates();
                  }
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
    } else if (['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm'].contains(ext)) {
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
    } else if (ext == 'pdf') {
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
    } else {
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

    if (confirmed == true && mounted) {
      final sortedFiles = List<UserFile>.from(group.files)
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      try {
        for (int i = 1; i < sortedFiles.length; i++) {
          await SupabaseService.deleteFile(sortedFiles[i].path);
        }

        _findExactDuplicates();
        if (_hasTriedAiAnalysis) {
          _findAiDuplicates();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Deleted ${sortedFiles.length - 1} duplicate files"),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting files: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDuplicatesList(List<DuplicateGroup> duplicates, String type) {
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);

    if (duplicates.isEmpty) {
      String title, subtitle;
      IconData icon;
      Color color;

      if (type == 'exact') {
        title = "No exact duplicates found!";
        subtitle = "Your storage is optimized";
        icon = Icons.check_circle;
        color = Colors.green;
      } else {
        if (!_hasTriedAiAnalysis) {
          title = "AI Content Analysis";
          subtitle = "Tap the refresh button to analyze your files\nfor similar content using AI";
          icon = Icons.psychology;
          color = themeService.subtextColor;
        } else {
          title = "No similar content found!";
          subtitle = "Content analysis complete";
          icon = Icons.check_circle;
          color = Colors.green;
        }
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 18, color: themeService.textColor),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: themeService.subtextColor),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: duplicates.length,
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, groupIndex) {
        final group = duplicates[groupIndex];
        final groupColor = type == 'exact' ? Colors.orange : Colors.blue;

        return Container(
          decoration: BoxDecoration(
            color: themeService.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: groupColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: groupColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      type == 'exact' ? Icons.copy : Icons.psychology,
                      color: groupColor,
                    ),
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
                            type == 'exact'
                                ? "${group.files.length} exact duplicates • ${_formatBytes(group.size)} each"
                                : "${group.files.length} similar files • ${(group.similarityScore! * 100).toStringAsFixed(1)}% similarity",
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
    );
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
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.copy),
                  text: "Exact Duplicates",
                ),
                Tab(
                  icon: Icon(Icons.psychology),
                  text: "AI Similar Content",
                ),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
            ),
            actions: [
              if (_tabController.index == 1)
                IconButton(
                  icon: _isLoadingAi
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.refresh),
                  onPressed: _isLoadingAi ? null : _findAiDuplicates,
                  tooltip: 'Analyze with AI',
                ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Exact Duplicates Tab
              _isLoadingExact
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDuplicatesList(_exactDuplicates, 'exact'),

              // AI Similar Content Tab
              _isLoadingAi
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Analyzing content with AI..."),
                    SizedBox(height: 8),
                    Text(
                      "This may take a few minutes",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : _buildDuplicatesList(_aiDuplicates, 'ai'),
            ],
          ),
        );
      },
    );
  }
}