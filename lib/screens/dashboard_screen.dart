import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'ai_tools_screen.dart';
import '../services/file_upload_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A3D62), // 💙 IntelliSpace Blue
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
                    FirebaseAuth.instance.currentUser?.email ?? "User",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Account Info'),
              onTap: () {
                Navigator.pop(context); // To be implemented later
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // To be implemented later
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: "Search files...",
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Storage Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueAccent[100],
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Storage Used", style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  LinearProgressIndicator(value: 0.01),
                  SizedBox(height: 8),
                  Text("300 KB of 10 GB used"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                actionButton(Icons.upload_file, "Upload", () async{
                  await FileUploadService().pickAndUploadFile();
                }),
                actionButton(Icons.share, "Share", () {
                  // Share logic placeholder
                }),
                actionButton(Icons.folder_open, "Browse", () {
                  // Browse logic placeholder
                }),
                actionButton(Icons.smart_toy, "AI Tools", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AiToolsScreen()),
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              "Categories",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                categoryBox(Icons.image, "Images"),
                categoryBox(Icons.picture_as_pdf, "PDFs"),
                categoryBox(Icons.video_file, "Videos"),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              "Recent Files",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.insert_drive_file, color: Colors.white),
                    title: Text("Project_Proposal.pdf", style: TextStyle(color: Colors.white)),
                    subtitle: Text("Modified 2 days ago", style: TextStyle(color: Colors.white70)),
                    trailing: Icon(Icons.more_vert, color: Colors.white),
                  ),
                  ListTile(
                    leading: Icon(Icons.image, color: Colors.white),
                    title: Text("screenshot.png", style: TextStyle(color: Colors.white)),
                    subtitle: Text("Uploaded 3 days ago", style: TextStyle(color: Colors.white70)),
                    trailing: Icon(Icons.more_vert, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated actionButton with onTap
  Widget actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white10,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget categoryBox(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 30, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
