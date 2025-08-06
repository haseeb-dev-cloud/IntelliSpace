// lib/screens/enhanced_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import 'login_screen.dart';
import 'account_info_screen.dart';
import 'settings_screen.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/storage_info_widget.dart';
import '../widgets/quick_actions_widget.dart';
import '../widgets/categories_widget.dart';
import '../widgets/recent_files_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  String? userDisplayName;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        userDisplayName = user.userMetadata?['full_name'] ?? user.userMetadata?['display_name'] ?? 'User';
        userEmail = user.email;
      });
    }
  }

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.bgColor,
          appBar: AppBar(
            title: Row(
              children: [
                Image.asset(
                  'assets/images/intellispace_logo.png',
                  height: 32,
                  width: 32,
                ),
                const SizedBox(width: 8),
                const Text("IntelliSpace"),
              ],
            ),
            backgroundColor: themeService.bgColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          drawer: Drawer(
            backgroundColor: themeService.isDarkMode
                ? const Color(0xFF0F3460)
                : Colors.blueAccent[100],
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: themeService.bgColor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: themeService.bgColor),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        userDisplayName ?? "User",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail ?? "user@example.com",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.dashboard, color: themeService.textColor),
                  title: Text('Dashboard', style: TextStyle(color: themeService.textColor)),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.account_circle, color: themeService.textColor),
                  title: Text('Account Info', style: TextStyle(color: themeService.textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AccountInfoScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: themeService.textColor),
                  title: Text('Settings', style: TextStyle(color: themeService.textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    const SearchBarWidget(),
                    const SizedBox(height: 16),

                    // Storage Card
                    const StorageInfoWidget(),
                    const SizedBox(height: 24),

                    // Quick Actions
                    const QuickActionsWidget(),
                    const SizedBox(height: 32),

                    // Categories
                    const CategoriesWidget(),
                    const SizedBox(height: 24),

                    // Recent Files - Fixed height to prevent overflow
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.35, // 35% of screen height
                      child: const RecentFilesWidget(),
                    ),
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}