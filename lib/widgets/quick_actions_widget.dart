// lib/widgets/quick_actions_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/all_files_screen.dart';
import '../screens/archive_screen.dart';
import '../screens/summaries_screen.dart';
import '../screens/compressed_files_screen.dart';
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
      ThemeService themeService, {
        Color? iconColor,
        Color? badgeColor,
        String? badge,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: themeService.isDarkMode
                    ? const Color(0xFF0F3460)
                    : Colors.white10,
                child: Icon(icon, color: iconColor ?? Colors.white),
              ),
              if (badge != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
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
              Icons.archive,
              "Archives",
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ArchivesScreen()),
                );
              },
              themeService,
              iconColor: Colors.blue,
              badge: "AI",
              badgeColor: Colors.blue,
            ),
          ],
        );
      },
    );
  }
}