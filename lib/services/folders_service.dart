// lib/services/folders_service.dart - Enhanced version
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/all_files_model.dart';

class FolderModel {
  final String id;
  final String name;
  final String userId;
  final DateTime createdAt;
  final int fileCount;

  FolderModel({
    required this.id,
    required this.name,
    required this.userId,
    required this.createdAt,
    this.fileCount = 0,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'],
      name: json['name'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      fileCount: json['file_count'] ?? 0,
    );
  }
}

class DuplicateFileGroup {
  final String filename;
  final int size;
  final List<UserFile> files;

  DuplicateFileGroup({
    required this.filename,
    required this.size,
    required this.files,
  });
}

class FoldersService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Create new folder
  static Future<String?> createFolder(String folderName) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Generate unique folder ID
      final folderData = '${user.id}_${folderName}_${DateTime.now().millisecondsSinceEpoch}';
      final folderId = md5.convert(utf8.encode(folderData)).toString();

      await _supabase.from('user_folders').insert({
        'id': folderId,
        'name': folderName,
        'user_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      return folderId;
    } catch (e) {
      print('Error creating folder: $e');
      return null;
    }
  }

  // Get all folders for user
  static Future<List<FolderModel>> getUserFolders() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      // Get folders with file counts using a subquery approach
      final foldersResponse = await _supabase
          .from('user_folders')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      List<FolderModel> folders = [];

      for (final folderData in foldersResponse) {
        // Get file count for each folder separately
        final fileCountResponse = await _supabase
            .from('user_files')
            .select('*')
            .eq('user_id', user.id)
            .eq('folder_id', folderData['id']);

        final fileCount = (fileCountResponse as List).length;

        folders.add(FolderModel(
          id: folderData['id'],
          name: folderData['name'],
          userId: folderData['user_id'],
          createdAt: DateTime.parse(folderData['created_at']),
          fileCount: fileCount,
        ));
      }

      return folders;
    } catch (e) {
      print('Error fetching folders: $e');
      return [];
    }
  }

  // Get files in folder
  static Future<List<dynamic>> getFolderFiles(String folderId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('user_files')
          .select('*')
          .eq('user_id', user.id)
          .eq('folder_id', folderId)
          .order('uploaded_at', ascending: false);

      return response as List;
    } catch (e) {
      print('Error fetching folder files: $e');
      return [];
    }
  }

  // Delete folder and all its files
  static Future<bool> deleteFolder(String folderId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Get all files in folder to delete from storage
      final files = await getFolderFiles(folderId);

      // Delete files from storage
      for (final file in files) {
        await _supabase.storage.from('user-files').remove([file['path']]);
      }

      // Delete files from database
      await _supabase
          .from('user_files')
          .delete()
          .eq('folder_id', folderId);

      // Delete folder
      await _supabase
          .from('user_folders')
          .delete()
          .eq('id', folderId)
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      print('Error deleting folder: $e');
      return false;
    }
  }

  // Rename folder
  static Future<bool> renameFolder(String folderId, String newName) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('user_folders')
          .update({'name': newName})
          .eq('id', folderId)
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      print('Error renaming folder: $e');
      return false;
    }
  }

  // Enhanced duplicate finding that returns full file details
  static Future<List<DuplicateFileGroup>> findDuplicateFileGroups() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      // Get all user files
      final response = await _supabase
          .from('user_files')
          .select('*')
          .eq('user_id', user.id);

      final List<UserFile> files =
      (response as List).map((e) => UserFile.fromJson(e)).toList();

      // Create a map to track file duplicates
      Map<String, List<UserFile>> fileGroups = {};

      // Group files by filename and size
      for (final file in files) {
        final key = '${file.filename}_${file.size}';
        if (fileGroups.containsKey(key)) {
          fileGroups[key]!.add(file);
        } else {
          fileGroups[key] = [file];
        }
      }

      // Filter groups that have more than one file (duplicates)
      List<DuplicateFileGroup> duplicates = [];
      fileGroups.forEach((key, group) {
        if (group.length > 1) {
          duplicates.add(DuplicateFileGroup(
            filename: group.first.filename,
            size: group.first.size,
            files: group,
          ));
        }
      });

      return duplicates;
    } catch (e) {
      print('Error finding duplicate file groups: $e');
      return [];
    }
  }

  // Legacy method for backward compatibility
  static Future<List<Map<String, dynamic>>> findDuplicateFiles() async {
    final duplicateGroups = await findDuplicateFileGroups();
    return duplicateGroups.map((group) => {
      'filename': group.filename,
      'size': group.size,
      'count': group.files.length,
    }).toList();
  }
}