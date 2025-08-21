// lib/services/compression_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:isolate';

// Compressed File Model
class CompressedFile {
  final String filename;
  final String originalFilename;
  final String localPath;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;
  final String compressionMethod;
  final DateTime compressedAt;

  CompressedFile({
    required this.filename,
    required this.originalFilename,
    required this.localPath,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
    required this.compressionMethod,
    required this.compressedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'originalFilename': originalFilename,
      'localPath': localPath,
      'originalSize': originalSize,
      'compressedSize': compressedSize,
      'compressionRatio': compressionRatio,
      'compressionMethod': compressionMethod,
      'compressedAt': compressedAt.toIso8601String(),
    };
  }

  factory CompressedFile.fromJson(Map<String, dynamic> json) {
    return CompressedFile(
      filename: json['filename'] ?? '',
      originalFilename: json['originalFilename'] ?? '',
      localPath: json['localPath'] ?? '',
      originalSize: json['originalSize'] ?? 0,
      compressedSize: json['compressedSize'] ?? 0,
      compressionRatio: (json['compressionRatio'] ?? 0.0).toDouble(),
      compressionMethod: json['compressionMethod'] ?? 'Unknown',
      compressedAt: DateTime.tryParse(json['compressedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

// Simple Run-Length Encoding for safer compression
class SimpleCompression {
  static List<int> compressRLE(List<int> data) {
    if (data.isEmpty) return [];

    try {
      final result = <int>[];
      int i = 0;

      while (i < data.length) {
        int count = 1;
        final currentByte = data[i];

        // Count consecutive identical bytes (max 255)
        while (i + count < data.length &&
            data[i + count] == currentByte &&
            count < 255) {
          count++;
        }

        if (count >= 3) {
          // Use RLE encoding: 255 (marker), count, byte
          result.addAll([255, count, currentByte]);
        } else {
          // Store raw bytes, avoiding the marker
          for (int j = 0; j < count; j++) {
            if (currentByte == 255) {
              result.addAll([255, 1, 255]); // Escape the marker
            } else {
              result.add(currentByte);
            }
          }
        }
        i += count;
      }

      return result;
    } catch (e) {
      print('RLE compression error: $e');
      return data; // Return original data on error
    }
  }

  static List<int> decompressRLE(List<int> data) {
    if (data.isEmpty) return [];

    try {
      final result = <int>[];
      int i = 0;

      while (i < data.length) {
        if (data[i] == 255 && i + 2 < data.length) {
          final count = data[i + 1];
          final byte = data[i + 2];

          for (int j = 0; j < count; j++) {
            result.add(byte);
          }
          i += 3;
        } else {
          result.add(data[i]);
          i++;
        }
      }

      return result;
    } catch (e) {
      print('RLE decompression error: $e');
      return data; // Return original data on error
    }
  }
}

class CompressionService {
  static String? _currentUserId;
  static const int _maxFileSize = 50 * 1024 * 1024; // 50MB limit
  static const int _chunkSize = 1024 * 1024; // 1MB chunks

  /// Set the current user ID - call this after login
  static void setCurrentUser(String userId) {
    _currentUserId = userId;
  }

  /// Clear current user - call this on logout
  static void clearCurrentUser() {
    _currentUserId = null;
  }

  /// Get user-specific compressed files key
  static String get _compressedFilesKey {
    if (_currentUserId == null) {
      throw Exception('No user logged in. Call CompressionService.setCurrentUser() first.');
    }
    return 'compressed_files_$_currentUserId';
  }

  /// Get the user-specific compressed files directory
  static Future<Directory> getCompressedFilesDirectory() async {
    if (_currentUserId == null) {
      throw Exception('No user logged in. Call CompressionService.setCurrentUser() first.');
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final compressedDir = Directory('${appDir.path}/Users/$_currentUserId/Compressed');
      if (!await compressedDir.exists()) {
        await compressedDir.create(recursive: true);
      }
      return compressedDir;
    } catch (e) {
      print('Error creating compressed directory: $e');
      throw Exception('Failed to create compressed files directory: $e');
    }
  }

  /// Safe compression with multiple fallback methods
  static List<int> _compressWithRLE(List<int> data) {
    try {
      if (data.isEmpty) return [4]; // 4 indicates empty file

      final compressed = SimpleCompression.compressRLE(data);
      return [0, ...compressed]; // 0 indicates RLE
    } catch (e) {
      print('RLE compression failed: $e');
      return [3, ...data]; // Fallback to no compression
    }
  }

  static List<int> _compressWithGZip(List<int> data) {
    try {
      if (data.isEmpty) return [4]; // 4 indicates empty file

      final gzipCodec = GZipCodec(level: 6); // Reduced level for stability
      final compressed = gzipCodec.encode(data);
      return [2, ...compressed]; // 2 indicates GZIP
    } catch (e) {
      print('GZIP compression failed: $e');
      return [3, ...data]; // Fallback to no compression
    }
  }

  static List<int> _decompressData(List<int> compressedData) {
    if (compressedData.isEmpty) return [];

    try {
      final method = compressedData[0];
      final data = compressedData.sublist(1);

      switch (method) {
        case 0: // RLE
          return SimpleCompression.decompressRLE(data);
        case 2: // GZIP
          try {
            final gzipCodec = GZipCodec();
            return gzipCodec.decode(data);
          } catch (e) {
            print('GZIP decompression failed: $e');
            return data;
          }
        case 3: // No compression
          return data;
        case 4: // Empty file
          return [];
        default:
          print('Unknown compression method: $method');
          return data;
      }
    } catch (e) {
      print('Decompression error: $e');
      return compressedData.length > 1 ? compressedData.sublist(1) : [];
    }
  }

  /// Determine best compression method and compress file
  static Future<CompressedFile> compressFile(
      String filePath,
      String originalFilename,
      ) async {
    try {
      print('Starting compression for: $originalFilename');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Source file does not exist: $filePath');
      }

      final fileStat = await file.stat();
      final originalSize = fileStat.size;

      print('Original file size: $originalSize bytes');

      // Check file size limit
      if (originalSize > _maxFileSize) {
        throw Exception('File too large for compression. Maximum size: ${formatBytes(_maxFileSize)}');
      }

      if (originalSize == 0) {
        throw Exception('Cannot compress empty file');
      }

      // Read file data with error handling
      List<int> originalData;
      try {
        originalData = await file.readAsBytes();
        print('Successfully read ${originalData.length} bytes');
      } catch (e) {
        throw Exception('Failed to read file data: $e');
      }

      // Validate data was read correctly
      if (originalData.length != originalSize) {
        print('Warning: Read ${originalData.length} bytes, expected $originalSize');
      }

      // Try compression methods with error handling
      List<int> bestCompressed = [3, ...originalData]; // Default to no compression
      String compressionMethod = 'No Compression';

      // Try RLE compression
      try {
        print('Trying RLE compression...');
        final rleCompressed = _compressWithRLE(originalData);
        print('RLE result: ${rleCompressed.length} bytes');

        if (rleCompressed.length < bestCompressed.length) {
          bestCompressed = rleCompressed;
          compressionMethod = 'Run-Length Encoding';
        }
      } catch (e) {
        print('RLE compression failed: $e');
      }

      // Try GZIP compression (more stable than custom algorithms)
      try {
        print('Trying GZIP compression...');
        final gzipCompressed = _compressWithGZip(originalData);
        print('GZIP result: ${gzipCompressed.length} bytes');

        if (gzipCompressed.length < bestCompressed.length) {
          bestCompressed = gzipCompressed;
          compressionMethod = 'GZIP Deflate';
        }
      } catch (e) {
        print('GZIP compression failed: $e');
      }

      final compressedSize = bestCompressed.length;
      final compressionRatio = originalSize > 0 ?
      max(0.0, (originalSize - compressedSize) / originalSize * 100) : 0.0;

      print('Best method: $compressionMethod');
      print('Final compressed size: $compressedSize bytes');
      print('Compression ratio: ${compressionRatio.toStringAsFixed(2)}%');

      // Create compressed file with timestamp and safe filename
      final compressedDir = await getCompressedFilesDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFilename = originalFilename.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
      final compressedFilename = 'compressed_${timestamp}_$safeFilename';
      final compressedFile = File('${compressedDir.path}/$compressedFilename');

      // Write compressed data with error handling
      try {
        await compressedFile.writeAsBytes(bestCompressed);
        print('Successfully wrote compressed file: ${compressedFile.path}');

        // Verify the file was written correctly
        final writtenSize = await compressedFile.length();
        if (writtenSize != compressedSize) {
          throw Exception('File write verification failed: expected $compressedSize, got $writtenSize');
        }
      } catch (e) {
        throw Exception('Failed to write compressed file: $e');
      }

      // Create compressed file record
      final compressedFileRecord = CompressedFile(
        filename: compressedFilename,
        originalFilename: originalFilename,
        localPath: compressedFile.path,
        originalSize: originalSize,
        compressedSize: compressedSize,
        compressionRatio: compressionRatio,
        compressionMethod: compressionMethod,
        compressedAt: DateTime.now(),
      );

      // Save to registry with error handling
      try {
        await _addToRegistry(compressedFileRecord);
        print('Successfully added to registry');
      } catch (e) {
        // If registry save fails, clean up the file
        try {
          await compressedFile.delete();
        } catch (_) {}
        throw Exception('Failed to save to registry: $e');
      }

      return compressedFileRecord;
    } catch (e) {
      print('Compression failed: $e');
      rethrow;
    }
  }

  /// Decompress a file and return the path to decompressed file
  static Future<String> decompressFile(CompressedFile compressedFile) async {
    try {
      print('Starting decompression for: ${compressedFile.filename}');

      final file = File(compressedFile.localPath);
      if (!await file.exists()) {
        throw Exception('Compressed file does not exist: ${compressedFile.localPath}');
      }

      final compressedData = await file.readAsBytes();
      print('Read compressed data: ${compressedData.length} bytes');

      final decompressedData = _decompressData(compressedData);
      print('Decompressed to: ${decompressedData.length} bytes');

      // Save decompressed file to temp directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final decompressedPath = '${tempDir.path}/decompressed_${timestamp}_${compressedFile.originalFilename}';
      final decompressedFile = File(decompressedPath);

      await decompressedFile.writeAsBytes(decompressedData);
      print('Decompressed file saved to: $decompressedPath');

      return decompressedFile.path;
    } catch (e) {
      print('Decompression failed: $e');
      throw Exception('Failed to decompress file: $e');
    }
  }

  /// Add compressed file to registry
  static Future<void> _addToRegistry(CompressedFile compressedFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final compressedFiles = await getCompressedFiles();

      compressedFiles.add(compressedFile);

      final jsonList = compressedFiles.map((file) => file.toJson()).toList();
      await prefs.setString(_compressedFilesKey, json.encode(jsonList));
    } catch (e) {
      print('Failed to add to registry: $e');
      rethrow;
    }
  }

  /// Get all compressed files
  static Future<List<CompressedFile>> getCompressedFiles() async {
    if (_currentUserId == null) {
      return []; // Return empty list if no user is logged in
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_compressedFilesKey);

      if (jsonString == null || jsonString.isEmpty) return [];

      final jsonList = json.decode(jsonString) as List;
      final compressedFiles = jsonList
          .map((json) => CompressedFile.fromJson(json as Map<String, dynamic>))
          .toList();

      // Filter out files that no longer exist on disk
      final existingFiles = <CompressedFile>[];
      for (final file in compressedFiles) {
        final diskFile = File(file.localPath);
        if (await diskFile.exists()) {
          try {
            final actualSize = await diskFile.length();
            if (actualSize != file.compressedSize) {
              // Update file with actual size
              final updatedFile = CompressedFile(
                filename: file.filename,
                originalFilename: file.originalFilename,
                localPath: file.localPath,
                originalSize: file.originalSize,
                compressedSize: actualSize,
                compressionRatio: file.originalSize > 0 ?
                max(0.0, (file.originalSize - actualSize) / file.originalSize * 100) : 0.0,
                compressionMethod: file.compressionMethod,
                compressedAt: file.compressedAt,
              );
              existingFiles.add(updatedFile);
            } else {
              existingFiles.add(file);
            }
          } catch (e) {
            print('Error checking file ${file.filename}: $e');
            // Keep the file in list even if we can't check its size
            existingFiles.add(file);
          }
        }
      }

      // Update registry if any files were removed or updated
      if (existingFiles.length != compressedFiles.length) {
        final jsonList = existingFiles.map((file) => file.toJson()).toList();
        await prefs.setString(_compressedFilesKey, json.encode(jsonList));
      }

      // Sort by compression date (newest first)
      existingFiles.sort((a, b) => b.compressedAt.compareTo(a.compressedAt));

      return existingFiles;
    } catch (e) {
      print('Error getting compressed files: $e');
      return [];
    }
  }

  /// Delete a compressed file
  static Future<void> deleteCompressedFile(String filename) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final compressedFiles = await getCompressedFiles();

      final fileToDelete = compressedFiles.firstWhere(
            (file) => file.filename == filename,
        orElse: () => throw Exception('Compressed file not found: $filename'),
      );

      // Delete the actual file
      final file = File(fileToDelete.localPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from registry
      compressedFiles.removeWhere((file) => file.filename == filename);

      final jsonList = compressedFiles.map((file) => file.toJson()).toList();
      await prefs.setString(_compressedFilesKey, json.encode(jsonList));
    } catch (e) {
      print('Error deleting compressed file: $e');
      rethrow;
    }
  }

  /// Clear all compressed files
  static Future<void> clearAllCompressedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final compressedFiles = await getCompressedFiles();

      // Delete all compressed files
      for (final file in compressedFiles) {
        try {
          final fileInstance = File(file.localPath);
          if (await fileInstance.exists()) {
            await fileInstance.delete();
          }
        } catch (e) {
          print('Error deleting file ${file.filename}: $e');
        }
      }

      // Clear the registry
      await prefs.remove(_compressedFilesKey);
    } catch (e) {
      print('Error clearing compressed files: $e');
      rethrow;
    }
  }

  /// Get total storage used by compressed files
  static Future<int> getTotalCompressedSize() async {
    try {
      final compressedFiles = await getCompressedFiles();
      int totalSize = 0;
      for (final file in compressedFiles) {
        totalSize += file.compressedSize;
      }
      return totalSize;
    } catch (e) {
      print('Error calculating total compressed size: $e');
      return 0;
    }
  }

  /// Get total original size of compressed files
  static Future<int> getTotalOriginalSize() async {
    try {
      final compressedFiles = await getCompressedFiles();
      int totalSize = 0;
      for (final file in compressedFiles) {
        totalSize += file.originalSize;
      }
      return totalSize;
    } catch (e) {
      print('Error calculating total original size: $e');
      return 0;
    }
  }

  /// Get compression count
  static Future<int> getCompressionCount() async {
    try {
      final compressedFiles = await getCompressedFiles();
      return compressedFiles.length;
    } catch (e) {
      print('Error getting compression count: $e');
      return 0;
    }
  }

  /// Format bytes to human readable format
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 2)} ${suffixes[i]}';
  }

  /// Clean up data for a specific user (call on account deletion)
  static Future<void> clearUserData(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    // Clear SharedPreferences for this user
    await prefs.remove('compressed_files_$userId');

    // Delete user's compressed files directory
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final userCompressedDir = Directory('${appDir.path}/Users/$userId/Compressed');
      if (await userCompressedDir.exists()) {
        await userCompressedDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error deleting user compressed directory: $e');
    }
  }
}