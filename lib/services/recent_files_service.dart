import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recent_file_model.dart';

class RecentFilesService {
  final supabase = Supabase.instance.client;

  Future<List<RecentFile>> fetchRecentFiles() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    // Get the most recent files that haven't been hidden from recents
    // First, check if show_in_recents column exists, if not, add a default true condition
    final response = await supabase
        .from('user_files')
        .select('id, filename, file_type, size, uploaded_at, path, show_in_recents')
        .eq('user_id', user.id)
        .neq('show_in_recents', false) // Only get files where show_in_recents is not false
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

  // Optional: Add a method to restore a file to recents if needed
  Future<void> restoreToRecents(String fileId) async {
    await supabase
        .from('user_files')
        .update({'show_in_recents': true})
        .eq('id', fileId);
  }
}