import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recent_file_model.dart';

class RecentFilesService {
  final supabase = Supabase.instance.client;

  Future<List<RecentFile>> fetchRecentFiles() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final response = await supabase
        .from('user_files')
        .select()
        .eq('user_id', user.id)
        .eq('show_in_recents', true)
        .order('uploaded_at', ascending: false)
        .limit(3);

    return (response as List).map((e) => RecentFile.fromJson(e)).toList();
  }

  Future<void> removeFileFromRecents(String fileId) async {
    await supabase
        .from('user_files')
        .update({'show_in_recents': false})
        .eq('id', fileId);
  }
}
