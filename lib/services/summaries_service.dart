// lib/services/summaries_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SummaryFile {
  final String filename;
  final String originalPdfName;
  final String localPath;
  final int size;
  final DateTime createdAt;

  SummaryFile({
    required this.filename,
    required this.originalPdfName,
    required this.localPath,
    required this.size,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'originalPdfName': originalPdfName,
      'localPath': localPath,
      'size': size,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SummaryFile.fromJson(Map<String, dynamic> json) {
    return SummaryFile(
      filename: json['filename'],
      originalPdfName: json['originalPdfName'],
      localPath: json['localPath'],
      size: json['size'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class SummariesService {
  static const String _summariesKey = 'summary_files';

  /// Get the summaries directory path
  static Future<Directory> getSummariesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final summariesDir = Directory('${appDir.path}/Summaries');
    if (!await summariesDir.exists()) {
      await summariesDir.create(recursive: true);
    }
    return summariesDir;
  }

  /// Add a new summary file to the registry
  static Future<void> addSummaryFile(
    String filename,
    String originalPdfName,
    String localPath,
    int size,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final summaries = await getSummaryFiles();
    
    // Check if summary already exists for this PDF
    final existingIndex = summaries.indexWhere(
      (summary) => summary.originalPdfName == originalPdfName,
    );
    
    final summaryFile = SummaryFile(
      filename: filename,
      originalPdfName: originalPdfName,
      localPath: localPath,
      size: size,
      createdAt: DateTime.now(),
    );

    if (existingIndex != -1) {
      // Update existing entry (replace old summary)
      final oldFile = summaries[existingIndex];
      if (await File(oldFile.localPath).exists()) {
        await File(oldFile.localPath).delete();
      }
      summaries[existingIndex] = summaryFile;
    } else {
      // Add new entry
      summaries.add(summaryFile);
    }

    final jsonList = summaries.map((file) => file.toJson()).toList();
    await prefs.setString(_summariesKey, json.encode(jsonList));
  }

  /// Get all summary files
  static Future<List<SummaryFile>> getSummaryFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_summariesKey);
    
    if (jsonString == null) return [];
    
    final jsonList = json.decode(jsonString) as List;
    final summaries = jsonList.map((json) => SummaryFile.fromJson(json)).toList();
    
    // Filter out files that no longer exist on disk
    final existingSummaries = <SummaryFile>[];
    for (final summary in summaries) {
      if (await File(summary.localPath).exists()) {
        existingSummaries.add(summary);
      }
    }
    
    // Update the stored list if any files were removed
    if (existingSummaries.length != summaries.length) {
      final jsonList = existingSummaries.map((file) => file.toJson()).toList();
      await prefs.setString(_summariesKey, json.encode(jsonList));
    }
    
    // Sort by creation date (newest first)
    existingSummaries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return existingSummaries;
  }

  /// Delete a specific summary file
  static Future<void> deleteSummaryFile(String originalPdfName) async {
    final prefs = await SharedPreferences.getInstance();
    final summaries = await getSummaryFiles();
    
    final fileToDelete = summaries.firstWhere(
      (file) => file.originalPdfName == originalPdfName,
      orElse: () => throw Exception('Summary file not found'),
    );
    
    // Delete the actual file
    final file = File(fileToDelete.localPath);
    if (await file.exists()) {
      await file.delete();
    }
    
    // Remove from summaries list
    summaries.removeWhere((file) => file.originalPdfName == originalPdfName);
    
    final jsonList = summaries.map((file) => file.toJson()).toList();
    await prefs.setString(_summariesKey, json.encode(jsonList));
  }

  /// Clear all summary files
  static Future<void> clearAllSummaries() async {
    final prefs = await SharedPreferences.getInstance();
    final summaries = await getSummaryFiles();
    
    // Delete all summary files
    for (final summary in summaries) {
      final file = File(summary.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // Clear the summaries list
    await prefs.remove(_summariesKey);
  }

  /// Get summary file for a specific PDF
  static Future<SummaryFile?> getSummaryForPdf(String pdfName) async {
    final summaries = await getSummaryFiles();
    try {
      return summaries.firstWhere(
        (summary) => summary.originalPdfName == pdfName,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if a PDF has been summarized
  static Future<bool> hasSummary(String pdfName) async {
    final summary = await getSummaryForPdf(pdfName);
    return summary != null;
  }

  /// Get total storage used by summaries
  static Future<int> getTotalSummariesSize() async {
    final summaries = await getSummaryFiles();
    int totalSize = 0;
    for (final summary in summaries) {
      totalSize += summary.size;
    }
    return totalSize;
  }

  /// Get count of summaries
  static Future<int> getSummariesCount() async {
    final summaries = await getSummaryFiles();
    return summaries.length;
  }

  /// Format bytes to human readable format
  static String formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }
}