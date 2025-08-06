// lib/widgets/enhanced_quick_actions_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/all_files_screen.dart';
import '../screens/ai_tools_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/search_screen.dart';
import '../services/file_upload_service.dart';
import '../services/theme_service.dart';

class QuickActionsWidget extends StatelessWidget {
  const QuickActionsWidget({Key? key}) : super(key: key);

  Widget _actionButton(
      IconData icon,
      String label,
      VoidCallback onTap,
      ThemeService themeService,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: themeService.isDarkMode
                ? const Color(0xFF0F3460)
                : Colors.white10,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _actionButton(
              Icons.upload_file,
              "Upload",
                  () async {
                await FileUploadService.showUploadDialog(
                  context,
                      ({onProgress}) => FileUploadService().pickAndUploadMultipleFiles(onProgress: onProgress),
                );
              },
              themeService,
            ),
            _actionButton(
              Icons.download,
              "Downloads",
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DownloadsScreen()),
                );
              },
              themeService,
            ),
            _actionButton(
              Icons.folder_open,
              "Browse",
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AllFilesScreen()),
                );
              },
              themeService,
            ),
            _actionButton(
              Icons.smart_toy,
              "AI Tools",
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AiToolsScreen()),
                );
              },
              themeService,
            ),
          ],
        );
      },
    );
  }
}