import 'package:supabase_flutter/supabase_flutter.dart';
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
  Future<String> getFileUrl(String path) async {
    final url = Supabase.instance.client.storage.from('user-files').getPublicUrl(path);
    return url;
  }

}



