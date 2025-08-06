// lib/services/enhanced_file_upload_service.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class FileUploadService {
  final SupabaseClient supabase = Supabase.instance.client;

  String _getFolderNameFromExtension(String ext) {
    final imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final videoExts = ['.mp4', '.mov', '.avi', '.mkv'];
    final docExts = ['.pdf', '.doc', '.docx', '.txt', '.ppt', '.pptx'];

    if (imageExts.contains(ext)) return 'images';
    if (videoExts.contains(ext)) return 'videos';
    if (docExts.contains(ext)) return 'docs';
    return 'others';
  }

  // Upload multiple files with progress callback
  Future<List<String>> pickAndUploadMultipleFiles({
    Function(int current, int total, String fileName)? onProgress,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return [];

      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      List<String> uploadedFiles = [];

      for (int i = 0; i < result.files.length; i++) {
        final platformFile = result.files[i];
        if (platformFile.path == null) continue;

        final file = File(platformFile.path!);
        final fileName = basename(file.path);
        final fileExtension = extension(file.path).toLowerCase();
        final fileSize = await file.length();
        final fileBytes = await file.readAsBytes();

        onProgress?.call(i + 1, result.files.length, fileName);

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

        await supabase.from('user_files').insert({
          'user_id': user.id,
          'bucket': 'user-files',
          'path': storagePath,
          'filename': fileName,
          'file_type': fileExtension.replaceFirst('.', ''),
          'size': fileSize,
          'uploaded_at': DateTime.now().toIso8601String(),
          'folder_id': null, // For root level files
        });

        uploadedFiles.add(fileName);
      }

      return uploadedFiles;
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }

  // Upload files to specific folder
  Future<List<String>> uploadFilesToFolder(String folderId, {
    Function(int current, int total, String fileName)? onProgress,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return [];

      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      List<String> uploadedFiles = [];

      for (int i = 0; i < result.files.length; i++) {
        final platformFile = result.files[i];
        if (platformFile.path == null) continue;

        final file = File(platformFile.path!);
        final fileName = basename(file.path);
        final fileExtension = extension(file.path).toLowerCase();
        final fileSize = await file.length();
        final fileBytes = await file.readAsBytes();

        onProgress?.call(i + 1, result.files.length, fileName);

        final storagePath = '${user.id}/folders/$folderId/$fileName';

        await supabase.storage.from('user-files').uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );

        await supabase.from('user_files').insert({
          'user_id': user.id,
          'bucket': 'user-files',
          'path': storagePath,
          'filename': fileName,
          'file_type': fileExtension.replaceFirst('.', ''),
          'size': fileSize,
          'uploaded_at': DateTime.now().toIso8601String(),
          'folder_id': folderId,
        });

        uploadedFiles.add(fileName);
      }

      return uploadedFiles;
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }

  // Show upload progress dialog
  static Future<void> showUploadDialog(
      BuildContext context,
      Future<List<String>> Function({Function(int, int, String)? onProgress}) uploadFunction,
      ) async {
    int currentFile = 0;
    int totalFiles = 0;
    String currentFileName = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Uploading Files'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: totalFiles > 0 ? currentFile / totalFiles : 0,
              ),
              const SizedBox(height: 16),
              Text('$currentFile of $totalFiles files uploaded'),
              if (currentFileName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Current: $currentFileName',
                    style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );

    try {
      final uploadedFiles = await uploadFunction(
        onProgress: (current, total, fileName) {
          currentFile = current;
          totalFiles = total;
          currentFileName = fileName;
          // Update dialog if still mounted
        },
      );

      Navigator.pop(context); // Close progress dialog

      if (uploadedFiles.isNotEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Upload Complete"),
            content: Text("✅ Successfully uploaded ${uploadedFiles.length} files!"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close progress dialog

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Upload Error"),
          content: Text("❌ Error uploading files: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }
}