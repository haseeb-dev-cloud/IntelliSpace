import 'package:flutter/material.dart';
import 'package:intellispace/models/all_files_model.dart'; // UserFile model
import 'package:intellispace/services/supabase_service.dart';
import 'package:intellispace/models/file_type_icon.dart';
import 'package:intellispace/screens/file_preview_screen.dart';

class AllFilesScreen extends StatefulWidget {
  const AllFilesScreen({Key? key}) : super(key: key);

  @override
  State<AllFilesScreen> createState() => _AllFilesScreenState();
}

class _AllFilesScreenState extends State<AllFilesScreen> {
  List<UserFile> allFiles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllFiles();
  }

  Future<void> fetchAllFiles() async {
    final files = await SupabaseService.getAllFilesForUser(); // Should return List<UserFile>
    setState(() {
      allFiles = files;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Files"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : allFiles.isEmpty
          ? const Center(child: Text("No files found."))
          : ListView.builder(
        itemCount: allFiles.length,
        itemBuilder: (context, index) {
          final file = allFiles[index];
          return ListTile(
            leading: FileTypeIcon(fileType: file.fileType),
            title: Text(file.filename),
            subtitle: Text(file.uploadedAt.toString()),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FilePreviewScreen(file: file),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
