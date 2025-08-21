// lib/services/user_session_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'downloads_service.dart';
import 'summaries_service.dart';
import 'compression_service.dart';

class UserSessionService {
  static const String _currentUserKey = 'current_user_id';
  static String? _currentUserId;
  
  /// Initialize the session service (call this in main.dart)
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString(_currentUserKey);
    
    if (_currentUserId != null) {
      // Set current user for all services
      _setCurrentUserForAllServices(_currentUserId!);
    }
  }
  
  /// Get current user ID
  static String? get currentUserId => _currentUserId;
  
  /// Check if user is logged in
  static bool get isLoggedIn => _currentUserId != null;
  
  /// Login user - call this after successful authentication
  static Future<void> loginUser(String userId) async {
    if (userId.isEmpty) {
      throw Exception('User ID cannot be empty');
    }
    
    _currentUserId = userId;
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, userId);
    
    // Set current user for all services
    _setCurrentUserForAllServices(userId);
    
    print('User logged in: $userId');
  }
  
  /// Logout current user
  static Future<void> logoutUser() async {
    if (_currentUserId == null) {
      return; // No user to logout
    }
    
    final previousUserId = _currentUserId;
    _currentUserId = null;
    
    // Remove from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    
    // Clear current user from all services
    _clearCurrentUserFromAllServices();
    
    print('User logged out: $previousUserId');
  }
  
  /// Switch to a different user (logout current, login new)
  static Future<void> switchUser(String newUserId) async {
    if (newUserId.isEmpty) {
      throw Exception('User ID cannot be empty');
    }
    
    // Logout current user first
    await logoutUser();
    
    // Login new user
    await loginUser(newUserId);
    
    print('Switched to user: $newUserId');
  }
  
  /// Delete all data for a specific user (call when deleting an account)
  static Future<void> deleteUserData(String userId) async {
    if (userId.isEmpty) {
      throw Exception('User ID cannot be empty');
    }
    
    try {
      // Clear data from all services
      await Future.wait([
        DownloadsService.clearUserData(userId),
        SummariesService.clearUserData(userId),
        CompressionService.clearUserData(userId),
      ]);
      
      print('Deleted all data for user: $userId');
    } catch (e) {
      print('Error deleting user data: $e');
      rethrow;
    }
  }
  
  /// Set current user for all services
  static void _setCurrentUserForAllServices(String userId) {
    DownloadsService.setCurrentUser(userId);
    SummariesService.setCurrentUser(userId);
    CompressionService.setCurrentUser(userId);
  }
  
  /// Clear current user from all services
  static void _clearCurrentUserFromAllServices() {
    DownloadsService.clearCurrentUser();
    SummariesService.clearCurrentUser();
    CompressionService.clearCurrentUser();
  }
  
  /// Get user-specific storage info
  static Future<Map<String, dynamic>> getUserStorageInfo() async {
    if (!isLoggedIn) {
      return {
        'downloads': {'count': 0, 'size': 0},
        'summaries': {'count': 0, 'size': 0},
        'compressed': {'count': 0, 'originalSize': 0, 'compressedSize': 0},
      };
    }
    
    try {
      final results = await Future.wait([
        DownloadsService.getDownloadedFiles(),
        SummariesService.getTotalSummariesSize(),
        SummariesService.getSummariesCount(),
        CompressionService.getTotalOriginalSize(),
        CompressionService.getTotalCompressedSize(),
        CompressionService.getCompressionCount(),
      ]);
      
      final downloads = results[0] as List;
      final summariesSize = results[1] as int;
      final summariesCount = results[2] as int;
      final originalSize = results[3] as int;
      final compressedSize = results[4] as int;
      final compressedCount = results[5] as int;
      
      int downloadsSize = 0;
      for (var download in downloads) {
        downloadsSize += download.size as int;
      }
      
      return {
        'downloads': {'count': downloads.length, 'size': downloadsSize},
        'summaries': {'count': summariesCount, 'size': summariesSize},
        'compressed': {
          'count': compressedCount, 
          'originalSize': originalSize, 
          'compressedSize': compressedSize
        },
      };
    } catch (e) {
      print('Error getting user storage info: $e');
      return {
        'downloads': {'count': 0, 'size': 0},
        'summaries': {'count': 0, 'size': 0},
        'compressed': {'count': 0, 'originalSize': 0, 'compressedSize': 0},
      };
    }
  }
}