// lib/services/enhanced_ai_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/all_files_model.dart';
import 'supabase_service.dart';
import 'summaries_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {

  // API URLs
  static  String get _huggingFaceSummarizeUrl => dotenv.env['HUGGING_FACE_URL']! ;
  static  String get _geminiApiUrl => dotenv.env['GEMINI_URL'] !;

  // API Keys
  static  String get _huggingFaceToken => dotenv.env['HUGGING_FACE_TOKEN']! ;
  static  String get _geminiApiKey => dotenv.env['GEMINI_API_KEY']! ;

  // ROBUST PDF text extraction with multiple methods
  static Future<String> _extractTextFromPdf(String pdfPath) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        return 'PDF file not found at path: $pdfPath';
      }

      print('Loading PDF file: $pdfPath');
      final bytes = await file.readAsBytes();

      // Method 1: Try Syncfusion PDF extraction
      try {
        final document = PdfDocument(inputBytes: bytes);
        print('PDF loaded successfully. Pages: ${document.pages.count}');

        if (document.pages.count > 0) {
          try {
            final textExtractor = PdfTextExtractor(document);
            final extractedText = textExtractor.extractText();
            document.dispose();

            if (extractedText.isNotEmpty && extractedText.length > 50) {
              final cleanText = _cleanExtractedText(extractedText);
              if (cleanText.isNotEmpty) {
                print('Syncfusion extraction successful: ${cleanText.length} characters');
                return cleanText;
              }
            }
          } catch (extractorError) {
            print('PdfTextExtractor failed: $extractorError');
            document.dispose();
          }
        } else {
          document.dispose();
        }
      } catch (syncfusionError) {
        print('Syncfusion PDF loading failed: $syncfusionError');
      }

      // Method 2: Try manual PDF parsing
      print('Attempting manual PDF text extraction...');
      final rawContent = String.fromCharCodes(bytes);
      final manualText = _extractTextFromPdfContent(rawContent);

      if (manualText.isNotEmpty && manualText.length > 100) {
        print('Manual extraction successful: ${manualText.length} characters');
        return manualText;
      }

      // If both methods failed
      return '''This PDF could not be processed for text extraction.

Possible reasons:
• The PDF contains only images or scanned content
• The PDF uses complex formatting or embedded graphics  
• The PDF may be password-protected
• The PDF structure is not compatible with text extraction

File Information:
• File Size: ${await file.length()} bytes
• Processing: Both Syncfusion and manual extraction failed

To process this PDF:
• Use OCR software for image-based PDFs
• Try converting to text-searchable format
• Check if PDF has selectable text in a PDF viewer''';

    } catch (e) {
      print('Critical error in PDF processing: $e');
      return 'Error processing PDF: ${e.toString()}';
    }
  }

  // Clean extracted text
  static String _cleanExtractedText(String text) {
    if (text.isEmpty) return '';

    // Remove excessive whitespace and control characters
    String cleaned = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();

    return cleaned;
  }

  // Manual PDF content extraction
  static String _extractTextFromPdfContent(String content) {
    final extractedStrings = <String>[];

    try {
      // Extract text from Tj operators
      final tjPattern = RegExp(r'\((.*?)\)\s*Tj', dotAll: true);
      final tjMatches = tjPattern.allMatches(content);

      for (final match in tjMatches) {
        final text = match.group(1) ?? '';
        if (text.length > 2 && _isReadableText(text)) {
          extractedStrings.add(_decodePdfString(text));
        }
      }

      // Extract from text arrays
      final arrayPattern = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
      final arrayMatches = arrayPattern.allMatches(content);

      for (final match in arrayMatches) {
        final textArray = match.group(1) ?? '';
        final stringPattern = RegExp(r'\((.*?)\)');
        final stringMatches = stringPattern.allMatches(textArray);

        for (final stringMatch in stringMatches) {
          final text = stringMatch.group(1) ?? '';
          if (text.length > 1 && _isReadableText(text)) {
            extractedStrings.add(_decodePdfString(text));
          }
        }
      }

      // Extract readable words as fallback
      if (extractedStrings.isEmpty) {
        final wordPattern = RegExp(r'\b[A-Za-z]{3,}\b');
        final wordMatches = wordPattern.allMatches(content);
        final words = wordMatches
            .map((m) => m.group(0) ?? '')
            .where((w) => w.length >= 3)
            .take(200)
            .toList();

        if (words.length > 20) {
          extractedStrings.add(words.join(' '));
        }
      }

      final result = extractedStrings.join(' ').trim();
      return _cleanExtractedText(result);

    } catch (e) {
      print('Error in manual extraction: $e');
      return '';
    }
  }

  // Decode PDF string escapes
  static String _decodePdfString(String pdfString) {
    return pdfString
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\r', ' ')
        .replaceAll(r'\t', ' ')
        .replaceAll(r'\\', '\\')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .trim();
  }

  // Check if text is readable
  static bool _isReadableText(String text) {
    if (text.length < 2) return false;
    final hasLetters = RegExp(r'[A-Za-z]').hasMatch(text);
    if (!hasLetters) return false;
    final letterCount = RegExp(r'[A-Za-z]').allMatches(text).length;
    return letterCount > text.length * 0.3;
  }

  // Gemini summarization
  static Future<String> _summarizeWithGemini(String text) async {
    try {
      final limitedText = text.length > 4000 ? text.substring(0, 4000) : text;

      final prompt = '''Analyze and summarize the following document content. Provide a comprehensive summary that captures:

1. Main topic and purpose
2. Key points and arguments  
3. Important details and findings
4. Conclusions or recommendations

Please write in clear, well-structured paragraphs:

$limitedText

Provide a detailed and informative summary of the above content.''';

      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {
            'maxOutputTokens': 1500,
            'temperature': 0.4,
            'topP': 0.8,
          },
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final content = result['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString().trim();
        }
      }

      throw Exception('Gemini API returned empty response');
    } catch (e) {
      print('Gemini API error: $e');
      throw e;
    }
  }

  // HuggingFace summarization
  static Future<String> _summarizeWithHuggingFace(String text) async {
    try {
      final limitedText = text.length > 3000 ? text.substring(0, 3000) : text;

      final response = await http.post(
        Uri.parse(_huggingFaceSummarizeUrl),
        headers: {
          'Authorization': 'Bearer $_huggingFaceToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'inputs': limitedText,
          'parameters': {
            'max_length': 600,
            'min_length': 100,
            'length_penalty': 2.0,
            'num_beams': 4,
            'early_stopping': true,
          }
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result is List && result.isNotEmpty) {
          final summary = result[0]['summary_text']?.toString()?.trim();
          if (summary != null && summary.isNotEmpty) {
            return summary;
          }
        }
      } else if (response.statusCode == 503) {
        await Future.delayed(const Duration(seconds: 15));
        return await _summarizeWithHuggingFace(text);
      }

      throw Exception('HuggingFace API error: ${response.statusCode}');
    } catch (e) {
      print('HuggingFace API error: $e');
      throw e;
    }
  }

  // Local summarization fallback
  static Future<String> _localExtractiveSummarization(String text) async {
    try {
      if (text.length < 200) {
        return 'Document is too short for meaningful summarization. Content: ${text.substring(0, text.length.clamp(0, 150))}...';
      }

      final sentences = text
          .replaceAll(RegExp(r'([.!?])\s*'), r'$1|SPLIT|')
          .split('|SPLIT|')
          .map((s) => s.trim())
          .where((s) => s.length > 30 && s.split(' ').length >= 5)
          .toList();

      if (sentences.length < 3) {
        return 'Unable to generate meaningful summary. Preview: ${text.substring(0, text.length.clamp(0, 300))}...';
      }

      final wordFreq = <String, int>{};
      final allWords = text.toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3 && !_isCommonWord(w))
          .toList();

      for (final word in allWords) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }

      final sentenceScores = <int, double>{};

      for (int i = 0; i < sentences.length; i++) {
        final sentence = sentences[i];
        final words = sentence.toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where((w) => w.length > 3)
            .toList();

        double score = 0;
        for (final word in words) {
          if (wordFreq.containsKey(word)) {
            score += wordFreq[word]! / allWords.length;
          }
        }

        if (words.isNotEmpty) {
          score = score / words.length;

          if (i < sentences.length * 0.3 || i > sentences.length * 0.7) {
            score *= 1.2;
          }

          if (sentence.toLowerCase().contains(RegExp(r'\b(important|key|main|conclusion|result)\b'))) {
            score *= 1.3;
          }

          sentenceScores[i] = score;
        }
      }

      final topSentenceIndices = sentenceScores.entries
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final summaryLength = (sentences.length * 0.4).round().clamp(3, 6);
      final selectedIndices = topSentenceIndices
          .take(summaryLength)
          .map((e) => e.key)
          .toList()
        ..sort();

      final summary = selectedIndices
          .map((i) => sentences[i])
          .join(' ')
          .trim();

      return summary.isNotEmpty ? summary : 'Could not generate meaningful summary.';

    } catch (e) {
      print('Local summarization error: $e');
      return 'Error during text analysis.';
    }
  }

  // AI summarization with fallback chain
  static Future<String> _summarizeWithPriorityModels(String text) async {
    print('Starting AI summarization...');

    try {
      print('Trying Gemini...');
      final geminiSummary = await _summarizeWithGemini(text);
      if (geminiSummary.isNotEmpty) {
        print('✅ Gemini successful');
        return geminiSummary;
      }
    } catch (e) {
      print('❌ Gemini failed: $e');
    }

    try {
      print('Trying HuggingFace...');
      final hfSummary = await _summarizeWithHuggingFace(text);
      if (hfSummary.isNotEmpty) {
        print('✅ HuggingFace successful');
        return hfSummary;
      }
    } catch (e) {
      print('❌ HuggingFace failed: $e');
    }

    print('Using local summarization...');
    return await _localExtractiveSummarization(text);
  }

  // Check common words
  static bool _isCommonWord(String word) {
    const commonWords = {
      'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i', 'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at', 'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her', 'she', 'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their', 'what', 'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me', 'when', 'make', 'can', 'like', 'time', 'no', 'just', 'him', 'know', 'take', 'people', 'into', 'year', 'your', 'good', 'some', 'could', 'them', 'see', 'other', 'than', 'then', 'now', 'look', 'only', 'come', 'its', 'over', 'think', 'also', 'back', 'after', 'use', 'two', 'how', 'our', 'work', 'first', 'well', 'way', 'even', 'new', 'want', 'because', 'any', 'these', 'give', 'day', 'most', 'us'
    };
    return commonWords.contains(word.toLowerCase());
  }

  // MAIN PDF summarization method
  static Future<String> summarizePdf(String pdfPath) async {
    try {
      print('Starting PDF summarization: $pdfPath');

      final text = await _extractTextFromPdf(pdfPath);

      if (text.isEmpty) {
        throw Exception('Could not extract any text from PDF');
      }

      print('Extracted text length: ${text.length}');

      if (text.contains('could not be processed') ||
          text.contains('password-protected') ||
          text.contains('Error processing')) {
        return '''AI SUMMARY REPORT
=================

⚠️ PDF PROCESSING NOTICE
$text

TECHNICAL DETAILS:
• Processing Method: Syncfusion + Manual Extraction
• Status: Text extraction failed
• Recommendation: Try OCR tools for image-based PDFs''';
      }

      String summary;
      try {
        summary = await _summarizeWithPriorityModels(text);
      } catch (e) {
        print('All summarization failed: $e');
        summary = 'Summarization failed: $e';
      }

      if (summary.isEmpty) {
        throw Exception('All summarization methods returned empty results');
      }

      final formattedSummary = '''AI SUMMARY REPORT
=================

DOCUMENT ANALYSIS:
• Text Length: ${text.length} characters
• Word Count: ~${text.split(RegExp(r'\s+')).length} words
• Processing: Advanced PDF Analysis
• Generated: ${DateTime.now().toString().split('.')[0]}

EXECUTIVE SUMMARY:
$summary

PROCESSING DETAILS:
• PDF Extraction: Syncfusion + Manual Parsing
• AI Models: Gemini → HuggingFace → Local Analysis
• Status: ✅ Successfully Processed

---
Generated by IntelliSpace AI Engine
${DateFormat('dd MMM yyyy \'at\' hh:mm a').format(DateTime.now())}''';

      return formattedSummary;
    } catch (e) {
      print('Error summarizing PDF: $e');
      throw Exception('Failed to summarize PDF: ${e.toString()}');
    }
  }

  // Create summary file
  static Future<File> createSummarizedFile(String originalFilename, String summary) async {
    try {
      final existingSummary = await SummariesService.getSummaryForPdf(originalFilename);
      if (existingSummary != null) {
        final oldFile = File(existingSummary.localPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      final summariesDir = await SummariesService.getSummariesDirectory();
      final summaryFilename = 'Summary_${originalFilename.replaceAll('.pdf', '.txt')}';
      final summaryFile = File('${summariesDir.path}/$summaryFilename');

      await summaryFile.writeAsString(summary, encoding: utf8);

      await SummariesService.addSummaryFile(
        summaryFilename,
        originalFilename,
        summaryFile.path,
        await summaryFile.length(),
      );

      print('Summary file created: ${summaryFile.path}');
      return summaryFile;
    } catch (e) {
      print('Error creating summary file: $e');
      throw Exception('Failed to create summary file: $e');
    }
  }

  // Compatibility methods
  static Future<double> _calculateTextSimilarity(String text1, String text2) async {
    try {
      if (text1.isEmpty || text2.isEmpty) return 0.0;
      final words1 = text1.toLowerCase().split(' ').toSet();
      final words2 = text2.toLowerCase().split(' ').toSet();
      final intersection = words1.intersection(words2).length;
      final union = words1.union(words2).length;
      return union > 0 ? intersection / union : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  static Future<double> _calculateAdvancedTextSimilarity(String text1, String text2) async {
    return await _calculateTextSimilarity(text1, text2);
  }

  static Future<String> _extractTextFromImage(String imagePath) async {
    try {
      return await _calculateImageHash(imagePath);
    } catch (e) {
      return '';
    }
  }

  static Future<String> _calculateImageHash(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes);
      return hash.toString();
    } catch (e) {
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
      return '';
    }
  }

  static Future<List<AiDuplicateGroup>> findAiBasedDuplicates() async {
    try {
      final allFiles = await SupabaseService.getAllFilesForUser();
      List<AiDuplicateGroup> duplicates = [];

      if (allFiles.length < 2) return duplicates;

      final tempDir = await getTemporaryDirectory();
      final aiTempDir = Directory('${tempDir.path}/ai_analysis');
      if (!await aiTempDir.exists()) {
        await aiTempDir.create(recursive: true);
      }

      Map<String, String> fileContents = {};
      final supportedFiles = allFiles.where((file) {
        final ext = file.fileType.toLowerCase();
        return ['pdf', 'txt', 'md'].contains(ext);
      }).toList();

      for (final file in supportedFiles.take(20)) {
        try {
          final url = await SupabaseService.getSignedUrl(file.path);
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
          final tempFile = File('${aiTempDir.path}/${file.filename}');
          await tempFile.writeAsBytes(response.bodyBytes);

          final content = await _extractTextFromDocument(tempFile.path, file.fileType);
          if (content.isNotEmpty && content.length > 50) {
            fileContents[file.path] = content;
          }

          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          print('Error processing ${file.filename}: $e');
        }
      }

      final filesList = supportedFiles.where((f) => fileContents.containsKey(f.path)).toList();

      for (int i = 0; i < filesList.length; i++) {
        final file1 = filesList[i];
        for (int j = i + 1; j < filesList.length; j++) {
          final file2 = filesList[j];

          try {
            final similarity = await _calculateAdvancedTextSimilarity(
              fileContents[file1.path]!,
              fileContents[file2.path]!,
            );

            if (similarity > 0.3) {
              var existingGroup = duplicates.firstWhere(
                    (group) => group.files.any((f) => f.path == file1.path || f.path == file2.path),
                orElse: () => AiDuplicateGroup(files: [], similarityScore: 0.0),
              );

              if (existingGroup.files.isEmpty) {
                duplicates.add(AiDuplicateGroup(
                  files: [file1, file2],
                  similarityScore: similarity,
                ));
              } else {
                if (!existingGroup.files.any((f) => f.path == file1.path)) {
                  existingGroup.files.add(file1);
                }
                if (!existingGroup.files.any((f) => f.path == file2.path)) {
                  existingGroup.files.add(file2);
                }
                existingGroup.similarityScore = (existingGroup.similarityScore + similarity) / 2;
              }
            }
          } catch (e) {
            print('Error comparing files: $e');
          }
        }
      }

      try {
        if (await aiTempDir.exists()) {
          await aiTempDir.delete(recursive: true);
        }
      } catch (e) {
        print('Cleanup error: $e');
      }

      return duplicates;
    } catch (e) {
      print('Error finding duplicates: $e');
      return [];
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