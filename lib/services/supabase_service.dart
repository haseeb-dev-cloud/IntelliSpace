import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/all_files_model.dart';

class SupabaseService {
  static Future<List<UserFile>> getAllFilesForUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final response = await Supabase.instance.client
        .from('user_files')
        .select('*')
        .eq('user_id', userId)
        .order('uploaded_at', ascending: false);
    return (response as List).map((e) => UserFile.fromJson(e)).toList();
  }

  static Future<String> getSignedUrl(String path) async {
    final res = await Supabase.instance.client.storage
        .from('user-files')
        .createSignedUrl(path, 60 * 60);
    return res;
  }

  static Future<void> deleteFile(String path) async {
    await Supabase.instance.client.storage.from('user-files').remove([path]);
    await Supabase.instance.client.from('user_files').delete().eq('path', path);
  }

  static Future<void> downloadFile(String path, String filename) async {
    final url = await getSignedUrl(path);
    final response = await http.get(Uri.parse(url));
    final dir = await getDownloadsDirectory();
    final file = File('${dir!.path}/$filename');
    await file.writeAsBytes(response.bodyBytes);
  }
}
