import 'package:flutter/material.dart';
import '../screens/category_files_screen.dart';

class CategoriesWidget extends StatelessWidget {
  const CategoriesWidget({Key? key}) : super(key: key);

  Widget _categoryBox(BuildContext context, IconData icon, String label, String fileType) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryFilesScreen(fileType: fileType),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Icon(icon, size: 32, color: Colors.white),
                if (fileType == 'pdf') // Add AI indicator for PDFs
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
          if (fileType == 'pdf')
            const Text(
              'AI Powered',
              style: TextStyle(color: Colors.blue, fontSize: 10),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Categories",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _categoryBox(context, Icons.image, "Images", "image"),
            _categoryBox(context, Icons.picture_as_pdf, "PDFs", "pdf"),
            _categoryBox(context, Icons.video_file, "Videos", "video"),
          ],
        ),
      ],
    );
  }
}