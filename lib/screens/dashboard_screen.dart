import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'all_files_screen.dart';
import 'login_screen.dart';
import 'ai_tools_screen.dart';
import '../services/file_upload_service.dart';
import '../services/recent_files_service.dart';
import '../models/recent_file_model.dart';
import 'package:intellispace/models/file_type_icon.dart';
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A3D62), // 💙 IntelliSpace Blue
      appBar: AppBar(
        title: const Text("IntelliSpace"),
        backgroundColor: const Color(0xFF0A3D62),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: Colors.blueAccent[100],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF0A3D62),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Color(0xFF0A3D62)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    Supabase.instance.client.auth.currentUser?.email ?? "User",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Account Info'),
              onTap: () {
                Navigator.pop(context); // To be implemented later
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // To be implemented later
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: "Search files...",
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Storage Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueAccent[100],
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Storage Used", style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  LinearProgressIndicator(value: 0.01),
                  SizedBox(height: 8),
                  Text("300 KB of 10 GB used"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                actionButton(Icons.upload_file, "Upload", () async {
                  final fileName = await FileUploadService().pickAndUploadFile();
                  if (fileName != null) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text("Success"),
                        content: Text("✅ File '$fileName' uploaded successfully!"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("OK"),
                          )
                        ],
                      ),
                    );
                  }
                }),

                actionButton(Icons.share, "Share", () {
                  // Share logic placeholder
                }),
                actionButton(Icons.folder_open, "Browse", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AllFilesScreen()),
                  );
                }),
                actionButton(Icons.smart_toy, "AI Tools", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AiToolsScreen()),
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              "Categories",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                categoryBox(Icons.image, "Images"),
                categoryBox(Icons.picture_as_pdf, "PDFs"),
                categoryBox(Icons.video_file, "Videos"),
              ],
            ),


            // RECENT FILES
            const SizedBox(height: 24),
            const Text(
              "Recent Files",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 170,
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

                      return ListTile(
                        leading: FileTypeIcon(filename: file.filename),
                        title: Text(file.filename,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          '${file.size} KB • ${_formatDateTime(file.uploadedAt)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'remove') {
                              await RecentFilesService().removeFileFromRecents(file.id);
                              // Trigger UI rebuild
                              (context as Element).markNeedsBuild();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove from recents'),
                            ),
                          ],
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                        ),
                      );
                    },
                  );
                },
              ),
            ),


          ],
        ),
      ),
    );
  }
  String _formatDateTime(DateTime dt) {
    final date = "${dt.day}/${dt.month}/${dt.year}";
    final time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    return "$date • $time";
  }





  // Updated actionButton with onTap
  Widget actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white10,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget categoryBox(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 30, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
class UploadDialog extends StatefulWidget {
  final File file;
  final String fileName;

  const UploadDialog({super.key, required this.file, required this.fileName});

  @override
  State<UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<UploadDialog> {
  bool isUploading = true;
  String statusText = "Uploading...";

  @override
  void initState() {
    super.initState();
    uploadFile();
  }

  Future<void> uploadFile() async {
    try {
      await FileUploadService().pickAndUploadFile();
      setState(() {
        isUploading = false;
        statusText = "✅ Upload Successful!";
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        isUploading = false;
        statusText = "❌ Upload Failed";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Uploading File"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          isUploading
              ? const CircularProgressIndicator()
              : const Icon(Icons.check_circle, color: Colors.green, size: 40),
          const SizedBox(height: 16),
          Text(statusText),
        ],
      ),
    );
  }
}

