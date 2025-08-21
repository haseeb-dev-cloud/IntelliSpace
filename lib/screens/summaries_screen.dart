// lib/screens/summaries_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../services/summaries_service.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart' as provider_package;

class SummariesScreen extends StatefulWidget {
  const SummariesScreen({Key? key}) : super(key: key);

  @override
  State<SummariesScreen> createState() => _SummariesScreenState();
}

class _SummariesScreenState extends State<SummariesScreen> {
  List<SummaryFile> _summaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final summaries = await SummariesService.getSummaryFiles();
    setState(() {
      _summaries = summaries;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  // SIMPLIFIED METHOD TO HANDLE TXT SUMMARIES ONLY
  Future<void> _openSummaryFile(SummaryFile summary) async {
    try {
      final file = File(summary.localPath);

      // Check if file exists
      if (!await file.exists()) {
        throw Exception('Summary file not found');
      }

      // Read the text content
      final content = await file.readAsString();

      // Show content in a dialog with scrollable text
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.summarize, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI Summary: ${summary.originalPdfName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Scrollable Content
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                // Footer with actions
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _shareFile(summary);
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await OpenFilex.open(summary.localPath);
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open External'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening summary: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareFile(SummaryFile summary) async {
    try {
      await Share.shareXFiles([XFile(summary.localPath)],
          text: 'AI Summary of ${summary.originalPdfName}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing file: $e')),
      );
    }
  }

  void _showFileOptions(SummaryFile summary) {
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
              title: Text('Open Summary', style: TextStyle(color: themeService.textColor)),
              onTap: () async {
                Navigator.pop(context);
                await _openSummaryFile(summary);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: themeService.textColor),
              title: Text('Share', style: TextStyle(color: themeService.textColor)),
              onTap: () async {
                Navigator.pop(context);
                await _shareFile(summary);
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
                    title: const Text('Delete Summary'),
                    content: const Text('Are you sure you want to delete this summary?'),
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
                  await SummariesService.deleteSummaryFile(summary.originalPdfName);
                  _loadSummaries();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Summary deleted successfully.")),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.info, color: themeService.textColor),
              title: Text('Summary Info', style: TextStyle(color: themeService.textColor)),
              onTap: () {
                Navigator.pop(context);
                _showSummaryInfo(summary);
              },
            ),
          ],
        );
      },
    );
  }

  void _showSummaryInfo(SummaryFile summary) {
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Row(
          children: [
            Icon(Icons.summarize, color: Colors.blue),
            const SizedBox(width: 8),
            Text("Summary Info", style: TextStyle(color: themeService.textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Original PDF:",
              style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor),
            ),
            Text(summary.originalPdfName, style: TextStyle(color: themeService.subtextColor)),
            const SizedBox(height: 12),
            Text(
              "Summary File:",
              style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor),
            ),
            Text(summary.filename, style: TextStyle(color: themeService.subtextColor)),
            const SizedBox(height: 12),
            Text("Size: ${SummariesService.formatBytes(summary.size)}",
                style: TextStyle(color: themeService.textColor)),
            const SizedBox(height: 4),
            Text("Created: ${_formatDate(summary.createdAt)}",
                style: TextStyle(color: themeService.textColor)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.smart_toy, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "AI-Generated Text Summary",
                      style: TextStyle(
                        color: Colors.blue,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openSummaryFile(summary);
            },
            child: const Text("Open Summary"),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllSummaries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Summaries'),
        content: const Text(
          'This will permanently delete all AI-generated summaries. This action cannot be undone.',
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
      await SummariesService.clearAllSummaries();
      _loadSummaries();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All summaries deleted successfully.")),
      );
    }
  }

  void _showStorageInfo() async {
    final themeService = provider_package.Provider.of<ThemeService>(context, listen: false);
    final totalSize = await SummariesService.getTotalSummariesSize();
    final count = await SummariesService.getSummariesCount();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Row(
          children: [
            Icon(Icons.storage, color: Colors.blue),
            const SizedBox(width: 8),
            Text("Storage Info", style: TextStyle(color: themeService.textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total Summaries:", style: TextStyle(color: themeService.textColor)),
                Text("$count",
                    style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Storage Used:", style: TextStyle(color: themeService.textColor)),
                Text(SummariesService.formatBytes(totalSize),
                    style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Summaries are stored locally on your device as text files in the app's Summaries folder. Text files are lightweight and easily shareable.",
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

  @override
  Widget build(BuildContext context) {
    return provider_package.Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.summarize, color: Colors.white),
                const SizedBox(width: 8),
                const Text("AI Summaries"),
              ],
            ),
            backgroundColor: themeService.bgColor,
            foregroundColor: Colors.white,
            actions: [
              if (_summaries.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'clear_all') {
                      _clearAllSummaries();
                    } else if (value == 'info') {
                      _showStorageInfo();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(Icons.info),
                          SizedBox(width: 8),
                          Text('Storage Info'),
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
              : _summaries.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.summarize, size: 64, color: themeService.subtextColor),
                const SizedBox(height: 16),
                Text(
                  "No AI Summaries Yet",
                  style: TextStyle(fontSize: 18, color: themeService.textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  "PDF summaries will appear here when you use\nthe AI summarization feature",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: themeService.subtextColor),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        "How to create summaries:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "1. Go to Categories → PDFs\n2. Tap the 3-dot menu on any PDF\n3. Select 'Summarize with AI'",
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
            itemCount: _summaries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final summary = _summaries[index];
              return Card(
                color: themeService.cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.withOpacity(0.2)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.summarize, color: Colors.blue),
                  ),
                  title: Text(
                    summary.originalPdfName,
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
                        "Summary: ${summary.filename}",
                        style: TextStyle(
                          color: themeService.subtextColor,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.smart_toy, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "${SummariesService.formatBytes(summary.size)} • ${_formatDate(summary.createdAt)} • TXT",
                              style: TextStyle(
                                color: Colors.blue,
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
                    onPressed: () => _showFileOptions(summary),
                  ),
                  onTap: () => _openSummaryFile(summary),
                ),
              );
            },
          ),
        );
      },
    );
  }
}