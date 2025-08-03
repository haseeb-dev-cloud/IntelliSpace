import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/storage_info_widget.dart';
import '../widgets/quick_actions_widget.dart';
import '../widgets/categories_widget.dart';
import '../widgets/recent_files_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A3D62),
      appBar: AppBar(
        title: const Text("IntelliSpace"),
        backgroundColor: const Color(0xFF0A3D62),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: Colors.blueAccent[100],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF0A3D62),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Color(0xFF0A3D62)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    Supabase.instance.client.auth.currentUser?.email ?? "User",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Account Info'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            SearchBarWidget(),
            SizedBox(height: 16),

            // Storage Card
            StorageInfoWidget(),
            SizedBox(height: 24),

            // Quick Actions
            QuickActionsWidget(),
            SizedBox(height: 32), // Added more space here

            // Categories
            CategoriesWidget(),
            SizedBox(height: 24),

            // Recent Files
            Expanded(child: RecentFilesWidget()),
          ],
        ),
      ),
    );
  }
}