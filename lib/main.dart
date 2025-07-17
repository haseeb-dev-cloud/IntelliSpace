import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intellispace/screens/login_screen.dart';
import 'package:intellispace/screens/signup_screen.dart';
import 'package:intellispace/screens/dashboard_screen.dart';
import 'package:intellispace/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(IntelliSpaceApp());
}

class IntelliSpaceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntelliSpace',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
    );
  }
}