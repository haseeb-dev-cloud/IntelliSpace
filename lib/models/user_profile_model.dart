import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? lastSignInAt;
  final DateTime? emailConfirmedAt;
  final Map<String, dynamic>? userMetadata;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
    this.lastSignInAt,
    this.emailConfirmedAt,
    this.userMetadata,
  });

  factory UserProfile.fromUser(User user) {
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      fullName: user.userMetadata?['full_name'],
      displayName: user.userMetadata?['display_name'],
      avatarUrl: user.userMetadata?['avatar_url'],
      createdAt: DateTime.parse(user.createdAt),
      lastSignInAt: user.lastSignInAt != null ? DateTime.parse(user.lastSignInAt!) : null,
      emailConfirmedAt: user.emailConfirmedAt != null ? DateTime.parse(user.emailConfirmedAt!) : null,
      userMetadata: user.userMetadata,
    );
  }

  String get preferredName {
    return fullName ?? displayName ?? email.split('@').first;
  }
}