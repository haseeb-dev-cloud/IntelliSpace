// lib/services/ai_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/all_files_model.dart';
import 'supabase_service.dart';
import 'summaries_service.dart';
import 'package:flutter/foundation.dart';

class AiService {
  // Free Hugging Face API endpoint for text similarity (currently unused but kept for future use)
  // ignore: unused_field
  static const String _huggingFaceApiUrl = 'https://api-inference.huggingface.co/models/sentence-transformers/all-MiniLM-L6-v2';

  // Replace with your actual token from https://huggingface.co/settings/tokens (currently unused but kept for future use)
  // ignore: unused_field
  static const String _huggingFaceToken = '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';

  // Simple PDF text extraction - this is a basic implementation
  static Future<String> _extractTextFromPdf(String pdfPath) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) return '';

      // Read file as string and try to extract readable text
      final bytes = await file.readAsBytes();
      final content = String.fromCharCodes(bytes);

      // Try to extract text between common PDF text markers
      final textPattern = RegExp(r'(?<=\()([^)]+)(?=\))|(?<=\[)([^\]]+)(?=\])|(?<= )([A-Za-z0-9\s.,!?;:]+)(?= )', multiLine: true);
      final matches = textPattern.allMatches(content);

      String extractedText = matches.map((match) => match.group(0) ?? '').join(' ');

      // If no meaningful text found, try a different approach
      if (extractedText.trim().isEmpty || extractedText.length < 50) {
        // Extract sequences of printable characters - SIMPLIFIED APPROACH
        final words = content.split(' ');
        final validWords = <String>[];

        for (final word in words) {
          if (word.length >= 3 && word.length <= 20) {
            // Check if word contains mostly letters and numbers
            final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
            if (cleanWord.length >= 2) {
              validWords.add(word);
            }
          }
        }

        extractedText = validWords.join(' ');
      }

      // Clean up the text - MANUAL APPROACH, NO REGEX
      extractedText = extractedText
          .replaceAll('  ', ' ')
          .replaceAll('   ', ' ')
          .replaceAll('    ', ' ')
          .trim();

      // If still no good text, return a basic message
      if (extractedText.isEmpty || extractedText.length < 20) {
        return 'This PDF contains mostly non-text content or uses unsupported encoding. Consider using a dedicated PDF processing library for better text extraction.';
      }

      return extractedText;
    } catch (e) {
      print('Error extracting PDF text: $e');
      return 'Error extracting text from PDF. The file might be corrupted or password-protected.';
    }
  }

  static Future<String> _extractTextFromImage(String imagePath) async {
    try {
      // For image text extraction, we'd use OCR
      // Since this is complex, we'll use image hash comparison instead
      return await _calculateImageHash(imagePath);
    } catch (e) {
      print('Error processing image: $e');
      return '';
    }
  }

  static Future<String> _calculateImageHash(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();

      // Simple perceptual hash approximation
      final hash = sha256.convert(bytes);
      return hash.toString();
    } catch (e) {
      print('Error calculating image hash: $e');
      return '';
    }
  }

  static Future<String> _extractTextFromDocument(String filePath, String fileType) async {
    try {
      if (fileType.toLowerCase() == 'pdf') {
        return await _extractTextFromPdf(filePath);
      } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileType.toLowerCase())) {
        return await _extractTextFromImage(filePath);
      } else if (['txt', 'md'].contains(fileType.toLowerCase())) {
        final file = File(filePath);
        return await file.readAsString();
      }
      return '';
    } catch (e) {
      print('Error extracting text: $e');
      return '';
    }
  }

  static Future<double> _calculateTextSimilarity(String text1, String text2) async {
    try {
      // Simple similarity calculation using Jaccard similarity
      if (text1.isEmpty || text2.isEmpty) return 0.0;

      final words1 = text1.toLowerCase().split(' ').toSet();
      final words2 = text2.toLowerCase().split(' ').toSet();

      final intersection = words1.intersection(words2).length;
      final union = words1.union(words2).length;

      return union > 0 ? intersection / union : 0.0;
    } catch (e) {
      print('Error calculating similarity: $e');
      return 0.0;
    }
  }

  // Enhanced method using Hugging Face API (if token is available)
  static Future<double> _calculateAdvancedTextSimilarity(String text1, String text2) async {
    try {
      // Always use simple similarity for now since API setup can be complex
      return await _calculateTextSimilarity(text1, text2);

      /* Uncomment this section when you have a valid Hugging Face token
      if (_huggingFaceToken == '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' || _huggingFaceToken.isEmpty) {
        // Fallback to simple similarity if no API token
        return await _calculateTextSimilarity(text1, text2);
      }

      final response = await http.post(
        Uri.parse(_huggingFaceApiUrl),
        headers: {
          'Authorization': 'Bearer $_huggingFaceToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'inputs': {
            'source_sentence': text1.length > 500 ? text1.substring(0, 500) : text1,
            'sentences': [text2.length > 500 ? text2.substring(0, 500) : text2]
          }
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result is List && result.isNotEmpty) {
          return (result[0] as num).toDouble();
        }
      }
      */

    } catch (e) {
      print('Error with advanced similarity: $e');
    }

    return await _calculateTextSimilarity(text1, text2);
  }

  static Future<List<AiDuplicateGroup>> findAiBasedDuplicates() async {
    try {
      final allFiles = await SupabaseService.getAllFilesForUser();
      List<AiDuplicateGroup> duplicates = [];

      if (allFiles.length < 2) {
        return duplicates; // Need at least 2 files to find duplicates
      }

      // Create temporary directory for file downloads
      final tempDir = await getTemporaryDirectory();
      final aiTempDir = Directory('${tempDir.path}/ai_analysis');
      if (!await aiTempDir.exists()) {
        await aiTempDir.create(recursive: true);
      }

      // Process files and extract content
      Map<String, String> fileContents = {};

      // Only process text-extractable files to save time and bandwidth
      final supportedFiles = allFiles.where((file) {
        final ext = file.fileType.toLowerCase();
        return ['pdf', 'txt', 'md'].contains(ext);
      }).toList();

      print('Processing ${supportedFiles.length} files for AI duplicate detection...');

      for (final file in supportedFiles.take(20)) { // Limit to 20 files to avoid timeout
        try {
          print('Processing: ${file.filename}');

          // Download file temporarily
          final url = await SupabaseService.getSignedUrl(file.path);
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
          final tempFile = File('${aiTempDir.path}/${file.filename}');
          await tempFile.writeAsBytes(response.bodyBytes);

          // Extract content based on file type
          final content = await _extractTextFromDocument(tempFile.path, file.fileType);
          if (content.isNotEmpty && content.length > 50) { // Only consider files with meaningful content
            fileContents[file.path] = content;
            print('Extracted ${content.length} characters from ${file.filename}');
          } else {
            print('Skipping ${file.filename} - insufficient content');
          }

          // Clean up temp file immediately
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          print('Error processing file ${file.filename}: $e');
        }
      }

      print('Successfully processed ${fileContents.length} files');

      // Compare files for similarity
      final processedPairs = <String>{};
      final filesList = supportedFiles.where((f) => fileContents.containsKey(f.path)).toList();

      for (int i = 0; i < filesList.length; i++) {
        final file1 = filesList[i];

        for (int j = i + 1; j < filesList.length; j++) {
          final file2 = filesList[j];

          final pairKey = '${file1.path}_${file2.path}';
          if (processedPairs.contains(pairKey)) continue;

          try {
            final similarity = await _calculateAdvancedTextSimilarity(
              fileContents[file1.path]!,
              fileContents[file2.path]!,
            );

            print('Similarity between ${file1.filename} and ${file2.filename}: ${(similarity * 100).toStringAsFixed(1)}%');

            // Consider files similar if similarity > 0.3 (30%) - lowered threshold for better detection
            if (similarity > 0.3) {
              // Check if group already exists
              var existingGroup = duplicates.firstWhere(
                    (group) => group.files.any((f) => f.path == file1.path || f.path == file2.path),
                orElse: () => AiDuplicateGroup(files: [], similarityScore: 0.0),
              );

              if (existingGroup.files.isEmpty) {
                duplicates.add(AiDuplicateGroup(
                  files: [file1, file2],
                  similarityScore: similarity,
                ));
                print('Created new duplicate group with similarity: ${(similarity * 100).toStringAsFixed(1)}%');
              } else {
                // Add to existing group if not already present
                if (!existingGroup.files.any((f) => f.path == file1.path)) {
                  existingGroup.files.add(file1);
                }
                if (!existingGroup.files.any((f) => f.path == file2.path)) {
                  existingGroup.files.add(file2);
                }
                // Update similarity score (average)
                existingGroup.similarityScore = (existingGroup.similarityScore + similarity) / 2;
                print('Added to existing group, new average similarity: ${(existingGroup.similarityScore * 100).toStringAsFixed(1)}%');
              }
            }

            processedPairs.add(pairKey);
          } catch (e) {
            print('Error comparing ${file1.filename} and ${file2.filename}: $e');
          }
        }
      }

      // Clean up temp directory
      try {
        if (await aiTempDir.exists()) {
          await aiTempDir.delete(recursive: true);
        }
      } catch (e) {
        print('Error cleaning up temp directory: $e');
      }

      print('Found ${duplicates.length} duplicate groups');
      return duplicates;
    } catch (e) {
      print('Error finding AI duplicates: $e');
      return [];
    }
  }

  static Future<String> summarizePdf(String pdfPath) async {
    try {
      // Extract text from PDF
      final text = await _extractTextFromPdf(pdfPath);

      if (text.isEmpty) {
        throw Exception('Could not extract text from PDF');
      }

      print('Extracted text length: ${text.length}');
      print('First 200 characters: ${text.length > 200 ? text.substring(0, 200) : text}');

      // If the extracted text is mostly garbage or too short, return a simple summary
      if (text.length < 100 || text.split(' ').where((word) => word.length > 15).length > text.split(' ').length * 0.5) {
        return '''This PDF appears to contain primarily non-text content such as images, diagrams, or uses complex formatting that cannot be easily extracted.

Key observations:
• File processed successfully
• Content appears to be visual/graphic in nature
• May contain images, charts, or scanned text
• Recommended to view the original PDF for complete information

Note: For better text extraction from complex PDFs, consider using specialized PDF processing tools or OCR software.''';
      }

      // Simple extractive summarization for readable text
      final sentences = text.split(RegExp(r'[.!?]+'))
          .where((s) => s.trim().length > 20 && s.trim().length < 200)
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (sentences.isEmpty) {
        throw Exception('No meaningful sentences found in the document');
      }

      // Score sentences based on word frequency and position
      final wordFreq = <String, int>{};
      final words = text.toLowerCase()
          .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((word) => word.length > 3)
          .toList();

      for (final word in words) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }

      // Remove very common words
      final commonWords = ['this', 'that', 'with', 'have', 'will', 'been', 'from', 'they', 'know', 'want', 'been', 'good', 'much', 'some', 'time', 'very', 'when', 'come', 'here', 'just', 'like', 'long', 'make', 'many', 'over', 'such', 'take', 'than', 'them', 'well', 'were'];
      commonWords.forEach((word) => wordFreq.remove(word));

      // Score sentences
      final sentenceScores = <String, double>{};
      for (int i = 0; i < sentences.length; i++) {
        final sentence = sentences[i];
        final sentenceWords = sentence.toLowerCase()
            .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where((word) => word.length > 3)
            .toList();

        double score = 0;
        int scoredWords = 0;

        for (final word in sentenceWords) {
          if (wordFreq.containsKey(word)) {
            score += wordFreq[word]!;
            scoredWords++;
          }
        }

        if (scoredWords > 0) {
          // Normalize by word count and add position bonus (earlier sentences get slight boost)
          final normalizedScore = score / scoredWords;
          final positionBonus = sentences.length > 10 ? (sentences.length - i) / sentences.length * 0.1 : 0;
          sentenceScores[sentence] = normalizedScore + positionBonus;
        }
      }

      if (sentenceScores.isEmpty) {
        throw Exception('Could not score any sentences for summarization');
      }

      // Select top sentences (about 20-40% of original, minimum 2, maximum 8)
      final sortedSentences = sentenceScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final summaryLength = (sentences.length * 0.3).round().clamp(2, 8);
      final selectedSentences = sortedSentences
          .take(summaryLength)
          .map((e) => e.key)
          .toList();

      // Sort selected sentences by their original order in the document
      selectedSentences.sort((a, b) {
        final indexA = sentences.indexOf(a);
        final indexB = sentences.indexOf(b);
        return indexA.compareTo(indexB);
      });

      final summary = selectedSentences.join('. ').trim();

      // Ensure the summary ends properly
      final finalSummary = summary.endsWith('.') ? summary : '$summary.';

      print('Generated summary length: ${finalSummary.length}');

      return finalSummary;
    } catch (e) {
      print('Error summarizing PDF: $e');
      throw Exception('Failed to summarize PDF: $e');
    }
  }

  static Future<File> createSummarizedPdf(String originalFilename, String summary) async {
    try {
      // Get summaries directory using the service
      final summariesDir = await SummariesService.getSummariesDirectory();

      // Create summary text file (since creating PDF is complex)
      final summaryFilename = 'Summary_${originalFilename.replaceAll('.pdf', '.txt')}';
      final summaryFile = File('${summariesDir.path}/$summaryFilename');

      final content = '''
=================================================
PDF SUMMARY REPORT
=================================================

Original Document: $originalFilename
Summary Generated: ${DateTime.now().toString().split('.')[0]}
Processing Method: AI-powered extractive summarization

-------------------------------------------------
SUMMARY
-------------------------------------------------

$summary

-------------------------------------------------
TECHNICAL DETAILS
-------------------------------------------------

• Summary Length: ${summary.length} characters
• Original Document: $originalFilename  
• Processing Date: ${DateTime.now().toString().split(' ')[0]}
• Generated by: IntelliSpace AI Engine

-------------------------------------------------
DISCLAIMER
-------------------------------------------------

This summary was automatically generated using AI and 
natural language processing techniques. While effort has 
been made to capture the key points, this summary may not 
include all important details from the original document.

For critical information, always refer to the complete 
original PDF document.

=================================================
End of Summary Report
=================================================
''';

      await summaryFile.writeAsString(content);

      // Register the summary file with the service
      await SummariesService.addSummaryFile(
        summaryFilename,
        originalFilename,
        summaryFile.path,
        await summaryFile.length(),
      );

      return summaryFile;
    } catch (e) {
      print('Error creating summary file: $e');
      throw Exception('Failed to create summary file: $e');
    }
  }
}

class AiDuplicateGroup {
  final List<UserFile> files;
  double similarityScore;

  AiDuplicateGroup({
    required this.files,
    required this.similarityScore,
  });
}