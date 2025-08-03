import 'package:flutter/material.dart';
import '../screens/all_files_screen.dart';
import '../screens/ai_tools_screen.dart';
import '../services/file_upload_service.dart';

class QuickActionsWidget extends StatelessWidget {
  const QuickActionsWidget({Key? key}) : super(key: key);

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _actionButton(Icons.upload_file, "Upload", () async {
          final fileName = await FileUploadService().pickAndUploadFile();
          if (fileName != null) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Success"),
                content: Text("✅ File '$fileName' uploaded successfully!"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK"),
                  )
                ],
              ),
            );
          }
        }),
        _actionButton(Icons.search, "Search", () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Search functionality coming soon!")),
          );
        }),
        _actionButton(Icons.folder_open, "Browse", () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AllFilesScreen()),
          );
        }),
        _actionButton(Icons.smart_toy, "AI Tools", () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AiToolsScreen()),
          );
        }),
      ],
    );
  }
}