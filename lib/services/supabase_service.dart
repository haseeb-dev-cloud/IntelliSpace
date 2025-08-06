import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/all_files_model.dart';
import 'downloads_service.dart';

class SupabaseService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get only files that are in the root directory (not in folders)
  static Future<List<UserFile>> getRootFilesForUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('user_files')
          .select('*')
          .eq('user_id', user.id)
          .is_('folder_id', null) // Only get files where folder_id is null
          .order('uploaded_at', ascending: false);

      return (response as List).map((e) => UserFile.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching root files: $e');
      return [];
    }
  }

  /// Get all files for user (including those in folders) - for categories and duplicates
  static Future<List<UserFile>> getAllFilesForUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('user_files')
          .select('*')
          .eq('user_id', user.id)
          .order('uploaded_at', ascending: false);

      return (response as List).map((e) => UserFile.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching all files: $e');
      return [];
    }
  }

  /// Create a signed URL for accessing a file
  static Future<String> getSignedUrl(String path) async {
    try {
      final res = await _supabase.storage
          .from('user-files')
          .createSignedUrl(path, 60 * 60);
      return res;
    } catch (e) {
      print('Error creating signed URL: $e');
      throw Exception('Failed to create signed URL: $e');
    }
  }

  /// Delete a file from both storage and database
  static Future<void> deleteFile(String path) async {
    try {
      await _supabase.storage.from('user-files').remove([path]);
      await _supabase.from('user_files').delete().eq('path', path);
    } catch (e) {
      print('Error deleting file: $e');
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Download a file to the device's downloads directory
  static Future<void> downloadFile(String path, String filename) async {
    try {
      final url = await getSignedUrl(path);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: HTTP ${response.statusCode}');
      }

      // Get downloads directory
      final dir = await getDownloadsDirectory();
      File file;

      if (dir == null) {
        // Fallback to app documents directory if downloads is not available
        final appDir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${appDir.path}/Downloads');
        if (!downloadsDir.existsSync()) {
          downloadsDir.createSync(recursive: true);
        }
        file = File('${downloadsDir.path}/$filename');
      } else {
        file = File('${dir.path}/$filename');
      }

      await file.writeAsBytes(response.bodyBytes);

      // Add to downloads service
      await DownloadsService.addDownloadedFile(
        filename,
        file.path,
        response.bodyBytes.length,
      );
    } catch (e) {
      print('Download error: $e');
      throw Exception('Failed to download file: $e');
    }
  }
}