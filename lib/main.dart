import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ Added

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

  // ✅ Load .env file
  await dotenv.load(fileName: ".env");

  // ✅ Initialize Supabase with .env variables
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
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
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
