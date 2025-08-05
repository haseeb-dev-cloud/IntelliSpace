import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color bgColor = const Color(0xFF0A3D62);
  bool _notifications = true;
  bool _autoSync = true;
  bool _darkMode = false;
  String _selectedQuality = 'High';
  String _selectedStorage = 'Auto';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General Settings Section
            _buildSectionHeader("General"),
            _buildSettingsCard([
              _buildSwitchTile(
                "Notifications",
                "Receive push notifications for file uploads and updates",
                Icons.notifications,
                _notifications,
                (value) => setState(() => _notifications = value),
              ),
              _buildDivider(),
              _buildSwitchTile(
                "Auto Sync",
                "Automatically sync files across devices",
                Icons.sync,
                _autoSync,
                (value) => setState(() => _autoSync = value),
              ),
              _buildDivider(),
              _buildSwitchTile(
                "Dark Mode",
                "Enable dark theme",
                Icons.dark_mode,
                _darkMode,
                (value) => setState(() => _darkMode = value),
              ),
            ]),

            const SizedBox(height: 24),

            // Storage Settings Section
            _buildSectionHeader("Storage & Quality"),
            _buildSettingsCard([
              _buildDropdownTile(
                "Upload Quality",
                "Choose default upload quality for media files",
                Icons.high_quality,
                _selectedQuality,
                ['High', 'Medium', 'Low'],
                (value) => setState(() => _selectedQuality = value!),
              ),
              _buildDivider(),
              _buildDropdownTile(
                "Storage Location",
                "Choose where to store downloaded files",
                Icons.folder,
                _selectedStorage,
                ['Auto', 'Internal Storage', 'SD Card'],
                (value) => setState(() => _selectedStorage = value!),
              ),
            ]),

            const SizedBox(height: 24),

            // Privacy & Security Section
            _buildSectionHeader("Privacy & Security"),
            _buildSettingsCard([
              _buildActionTile(
                "Change Password",
                "Update your account password",
                Icons.lock,
                () => _showChangePasswordDialog(),
              ),
              _buildDivider(),
              _buildActionTile(
                "Two-Factor Authentication",
                "Add an extra layer of security",
                Icons.security,
                () => _showComingSoonDialog("Two-Factor Authentication"),
              ),
              _buildDivider(),
              _buildActionTile(
                "Privacy Policy",
                "Read our privacy policy",
                Icons.privacy_tip,
                () => _showComingSoonDialog("Privacy Policy"),
              ),
            ]),

            const SizedBox(height: 24),

            // Data & Storage Section
            _buildSectionHeader("Data Management"),
            _buildSettingsCard([
              _buildActionTile(
                "Clear Cache",
                "Free up space by clearing temporary files",
                Icons.cleaning_services,
                () => _showClearCacheDialog(),
              ),
              _buildDivider(),
              _buildActionTile(
                "Export Data",
                "Download all your files and data",
                Icons.download,
                () => _showComingSoonDialog("Export Data"),
              ),
              _buildDivider(),
              _buildActionTile(
                "Delete Account",
                "Permanently delete your account and all data",
                Icons.delete_forever,
                () => _showDeleteAccountDialog(),
                isDestructive: true,
              ),
            ]),

            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader("About"),
            _buildSettingsCard([
              _buildActionTile(
                "App Version",
                "IntelliSpace v1.0.0",
                Icons.info,
                () {},
                showArrow: false,
              ),
              _buildDivider(),
              _buildActionTile(
                "Terms of Service",
                "Read our terms and conditions",
                Icons.description,
                () => _showComingSoonDialog("Terms of Service"),
              ),
              _buildDivider(),
              _buildActionTile(
                "Contact Support",
                "Get help with your account",
                Icons.support_agent,
                () => _showContactSupportDialog(),
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: bgColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: bgColor,
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    IconData icon,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: bgColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        underline: Container(),
        items: options.map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
    bool showArrow = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red.withOpacity(0.1) 
              : bgColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon, 
          color: isDestructive ? Colors.red : bgColor, 
          size: 20
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: showArrow ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 60);
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm New Password",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Passwords don't match")),
                );
                return;
              }
              
              try {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(password: newPasswordController.text),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password updated successfully")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: bgColor),
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Cache"),
        content: const Text(
          "This will clear all temporary files and cached data. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Cache cleared successfully")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: bgColor),
            child: const Text("Clear", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "This will permanently delete your account and all your files. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoonDialog("Account Deletion");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Contact Support"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Need help? Contact us through:"),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.email, color: Colors.blue),
                SizedBox(width: 8),
                Text("abdulhaseeb4002@gmail.com"),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, color: Colors.green),
                SizedBox(width: 8),
                Text("+92 317 8045079"),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Coming Soon"),
        content: Text("$feature will be available in a future update."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}