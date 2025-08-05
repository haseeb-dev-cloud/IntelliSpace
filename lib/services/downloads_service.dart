import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DownloadedFile {
  final String filename;
  final String localPath;
  final int size;
  final DateTime downloadedAt;

  DownloadedFile({
    required this.filename,
    required this.localPath,
    required this.size,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'localPath': localPath,
      'size': size,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  factory DownloadedFile.fromJson(Map<String, dynamic> json) {
    return DownloadedFile(
      filename: json['filename'],
      localPath: json['localPath'],
      size: json['size'],
      downloadedAt: DateTime.parse(json['downloadedAt']),
    );
  }
}

class DownloadsService {
  static const String _downloadsKey = 'downloaded_files';

  static Future<void> addDownloadedFile(String filename, String localPath, int size) async {
    final prefs = await SharedPreferences.getInstance();
    final downloads = await getDownloadedFiles();
    
    // Check if file already exists in downloads list
    final existingIndex = downloads.indexWhere((file) => file.filename == filename);
    
    final downloadedFile = DownloadedFile(
      filename: filename,
      localPath: localPath,
      size: size,
      downloadedAt: DateTime.now(),
    );

    if (existingIndex != -1) {
      // Update existing entry
      downloads[existingIndex] = downloadedFile;
    } else {
      // Add new entry
      downloads.add(downloadedFile);
    }

    final jsonList = downloads.map((file) => file.toJson()).toList();
    await prefs.setString(_downloadsKey, json.encode(jsonList));
  }

  static Future<List<DownloadedFile>> getDownloadedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_downloadsKey);
    
    if (jsonString == null) return [];
    
    final jsonList = json.decode(jsonString) as List;
    final downloads = jsonList.map((json) => DownloadedFile.fromJson(json)).toList();
    
    // Filter out files that no longer exist on disk
    final existingDownloads = <DownloadedFile>[];
    for (final download in downloads) {
      if (await File(download.localPath).exists()) {
        existingDownloads.add(download);
      }
    }
    
    // Update the stored list if any files were removed
    if (existingDownloads.length != downloads.length) {
      final jsonList = existingDownloads.map((file) => file.toJson()).toList();
      await prefs.setString(_downloadsKey, json.encode(jsonList));
    }
    
    // Sort by download date (newest first)
    existingDownloads.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    
    return existingDownloads;
  }

  static Future<void> deleteDownloadedFile(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    final downloads = await getDownloadedFiles();
    
    final fileToDelete = downloads.firstWhere(
      (file) => file.filename == filename,
      orElse: () => throw Exception('File not found in downloads'),
    );
    
    // Delete the actual file
    final file = File(fileToDelete.localPath);
    if (await file.exists()) {
      await file.delete();
    }
    
    // Remove from downloads list
    downloads.removeWhere((file) => file.filename == filename);
    
    final jsonList = downloads.map((file) => file.toJson()).toList();
    await prefs.setString(_downloadsKey, json.encode(jsonList));
  }

  static Future<void> clearAllDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final downloads = await getDownloadedFiles();
    
    // Delete all downloaded files
    for (final download in downloads) {
      final file = File(download.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // Clear the downloads list
    await prefs.remove(_downloadsKey);
  }
}