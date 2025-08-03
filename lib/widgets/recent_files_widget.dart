import 'package:flutter/material.dart';
import '../models/recent_file_model.dart';
import '../services/recent_files_service.dart';
import '../screens/file_preview_screen.dart';
import '../models/file_type_icon.dart';

class RecentFilesWidget extends StatefulWidget {
  const RecentFilesWidget({Key? key}) : super(key: key);

  @override
  State<RecentFilesWidget> createState() => _RecentFilesWidgetState();
}

class _RecentFilesWidgetState extends State<RecentFilesWidget> {
  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  String _formatDateTime(DateTime dt) {
    final date = "${dt.day}/${dt.month}/${dt.year}";
    final time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    return "$date • $time";
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

  void _refreshRecentFiles() {
    setState(() {
      // This will trigger FutureBuilder to rebuild
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recent Files",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<RecentFile>>(
            future: RecentFilesService().fetchRecentFiles(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return const Center(
                    child: Text('Error loading files',
                        style: TextStyle(color: Colors.white)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child: Text('No recent files found',
                        style: TextStyle(color: Colors.white70)));
              }

              final files = snapshot.data!;

              return ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: FileTypeIcon(filename: file.filename),
                        title: Text(
                          file.filename.length > 25
                              ? '${file.filename.substring(0, 25)}...'
                              : file.filename,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        // No subtitle/metadata as requested
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'remove') {
                              await RecentFilesService().removeFileFromRecents(file.id);
                              _refreshRecentFiles(); // Refresh the widget
                            } else if (value == 'info') {
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
                                      Text("Size: ${_formatBytes(file.size)}"),
                                      const SizedBox(height: 4),
                                      Text("Uploaded: ${_formatDateTime(file.uploadedAt)}"),
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
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'info',
                              child: Text('File Info'),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove from recents'),
                            ),
                          ],
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FilePreviewScreen(
                                filePath: file.path ?? '',
                                fileType: file.fileType,
                                fileName: file.filename,
                                fileSize: file.size,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}