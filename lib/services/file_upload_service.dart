import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FileUploadService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> pickAndUploadFile() async {
    try {
      // Step 1: Pick file
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.single.path == null) {
        print('❌ File selection cancelled.');
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = basename(file.path);
      final fileExtension = extension(file.path).toLowerCase();
      final fileSize = await file.length();
      final fileBytes = await file.readAsBytes();

      // Step 2: Get current user
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Step 3: Define storage path
      final folder = _getFolderNameFromExtension(fileExtension); // e.g. images/docs/videos
      final storagePath = '${user.id}/$folder/$fileName';

      // Step 4: Upload to Supabase Storage
      final storageResponse = await supabase.storage
          .from('user-files') // replace with your bucket
          .uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      // Step 5: Get public URL
      final publicUrl = supabase.storage
          .from('user-files')
          .getPublicUrl(storagePath);

      // Step 6: Save metadata to Supabase table
      final insertResponse = await supabase.from('files').insert({
        'user_id': user.id,
        'name': fileName,
        'path': storagePath,
        'url': publicUrl,
        'type': fileExtension.replaceFirst('.', ''),
        'size': fileSize,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ File uploaded & metadata saved!');
    } catch (e) {
      print('❌ Upload error: $e');
    }
  }

  String _getFolderNameFromExtension(String ext) {
    final imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final videoExts = ['.mp4', '.mov', '.avi', '.mkv'];
    final docExts = ['.pdf', '.doc', '.docx', '.txt', '.ppt', '.pptx'];

    if (imageExts.contains(ext)) return 'images';
    if (videoExts.contains(ext)) return 'videos';
    if (docExts.contains(ext)) return 'docs';
    return 'others';
  }
}
