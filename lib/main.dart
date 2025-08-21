import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

// Services
import 'package:intellispace/services/theme_service.dart';
import 'package:intellispace/services/user_session_service.dart';

// Screens
import 'package:intellispace/screens/splash_screen.dart';
import 'package:intellispace/screens/email_verification_screen.dart';
import 'package:intellispace/screens/login_screen.dart';
import 'package:intellispace/screens/signup_screen.dart';
import 'package:intellispace/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Supabase
  await Supabase.initialize(
    url: 'https://dhgwbzlpeahmlkvttskz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoZ3diemxwZWFobWxrdnR0c2t6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMwNDEzOTYsImV4cCI6MjA2ODYxNzM5Nn0.ljwtf9CZDksXe-wdHqPpp8ra-9uP2UyEhBT39odhD2M',
  );

  // ✅ Initialize user session service
  await UserSessionService.initialize();

  runApp(const IntelliSpaceApp());
}

class IntelliSpaceApp extends StatelessWidget {
  const IntelliSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeService>(
      create: (context) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'IntelliSpace',
            debugShowCheckedModeBanner: false,
            theme: themeService.theme,
            home: const SplashScreen(), // Change to LoginScreen() or DashboardScreen() if needed
          );
        },
      ),
    );
  }
}