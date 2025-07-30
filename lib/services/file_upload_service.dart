// lib/services/file_upload_service.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FileUploadService {
  final SupabaseClient supabase = Supabase.instance.client;

  // Utility method to organize by folder
  String _getFolderNameFromExtension(String ext) {
    final imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final videoExts = ['.mp4', '.mov', '.avi', '.mkv'];
    final docExts = ['.pdf', '.doc', '.docx', '.txt', '.ppt', '.pptx'];

    if (imageExts.contains(ext)) return 'images';
    if (videoExts.contains(ext)) return 'videos';
    if (docExts.contains(ext)) return 'docs';
    return 'others';
  }

  // Upload method returns filename (or null on failure)
  Future<String?> pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.single.path == null) return null;

      final file = File(result.files.single.path!);
      final fileName = basename(file.path);
      final fileExtension = extension(file.path).toLowerCase();
      final fileSize = await file.length();
      final fileBytes = await file.readAsBytes();

      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final folder = _getFolderNameFromExtension(fileExtension);
      final storagePath = '${user.id}/$folder/$fileName';

      await supabase.storage.from('user-files').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      final publicUrl = supabase.storage.from('user-files').getPublicUrl(storagePath);

      // ✅ Save metadata in user_files
      await supabase.from('user_files').insert({
        'user_id': user.id,
        'bucket': 'user-files',
        'path': storagePath,
        'filename': fileName,
        'file_type': fileExtension.replaceFirst('.', ''),
        'size': fileSize,
        'uploaded_at': DateTime.now().toIso8601String(),
      });

      return fileName;
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }
}
