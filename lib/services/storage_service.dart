import 'package:supabase_flutter/supabase_flutter.dart';

class StorageInfo {
  final int totalUsed;
  final int totalAvailable;
  final int imagesSize;
  final int videosSize;
  final int pdfsSize;
  final int othersSize;
  final int totalFiles;
  final int imagesCount;
  final int videosCount;
  final int pdfsCount;
  final int othersCount;

  StorageInfo({
    required this.totalUsed,
    required this.totalAvailable,
    required this.imagesSize,
    required this.videosSize,
    required this.pdfsSize,
    required this.othersSize,
    required this.totalFiles,
    required this.imagesCount,
    required this.videosCount,
    required this.pdfsCount,
    required this.othersCount,
  });
}

class StorageService {
  static Future<StorageInfo> getStorageInfo() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    
    if (userId == null) {
      return StorageInfo(
        totalUsed: 0,
        totalAvailable: 10 * 1024 * 1024 * 1024, // 10 GB
        imagesSize: 0,
        videosSize: 0,
        pdfsSize: 0,
        othersSize: 0,
        totalFiles: 0,
        imagesCount: 0,
        videosCount: 0,
        pdfsCount: 0,
        othersCount: 0,
      );
    }

    try {
      final response = await Supabase.instance.client
          .from('user_files')
          .select('file_type, size')
          .eq('user_id', userId);

      final files = response as List;
      
      int totalUsed = 0;
      int imagesSize = 0;
      int videosSize = 0;
      int pdfsSize = 0;
      int othersSize = 0;
      
      int totalFiles = files.length;
      int imagesCount = 0;
      int videosCount = 0;
      int pdfsCount = 0;
      int othersCount = 0;

      final imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'];
      final videoExts = ['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm'];
      final pdfExts = ['pdf'];

      for (final file in files) {
        final fileType = (file['file_type'] as String).toLowerCase();
        final size = file['size'] as int;
        
        totalUsed += size;

        if (imageExts.contains(fileType)) {
          imagesSize += size;
          imagesCount++;
        } else if (videoExts.contains(fileType)) {
          videosSize += size;
          videosCount++;
        } else if (pdfExts.contains(fileType)) {
          pdfsSize += size;
          pdfsCount++;
        } else {
          othersSize += size;
          othersCount++;
        }
      }

      return StorageInfo(
        totalUsed: totalUsed,
        totalAvailable: 10 * 1024 * 1024 * 1024, // 10 GB limit
        imagesSize: imagesSize,
        videosSize: videosSize,
        pdfsSize: pdfsSize,
        othersSize: othersSize,
        totalFiles: totalFiles,
        imagesCount: imagesCount,
        videosCount: videosCount,
        pdfsCount: pdfsCount,
        othersCount: othersCount,
      );
    } catch (e) {
      print('Error fetching storage info: $e');
      return StorageInfo(
        totalUsed: 0,
        totalAvailable: 10 * 1024 * 1024 * 1024, // 10 GB
        imagesSize: 0,
        videosSize: 0,
        pdfsSize: 0,
        othersSize: 0,
        totalFiles: 0,
        imagesCount: 0,
        videosCount: 0,
        pdfsCount: 0,
        othersCount: 0,
      );
    }
  }
}