import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Screens
import 'package:intellispace/screens/splash_screen.dart';
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

  runApp(const IntelliSpaceApp());
}

class IntelliSpaceApp extends StatelessWidget {
  const IntelliSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntelliSpace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // Change to LoginScreen() or DashboardScreen() if needed
    );
  }
}
