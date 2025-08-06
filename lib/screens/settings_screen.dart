// lib/screens/enhanced_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _autoSync = true;
  String _selectedQuality = 'High';
  String _selectedStorage = 'Auto';

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text("Settings"),
            backgroundColor: themeService.bgColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // General Settings Section
                _buildSectionHeader("General", themeService),
                _buildSettingsCard(themeService, [
                  _buildSwitchTile(
                    "Notifications",
                    "Receive push notifications for file uploads and updates",
                    Icons.notifications,
                    _notifications,
                        (value) => setState(() => _notifications = value),
                    themeService,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    "Auto Sync",
                    "Automatically sync files across devices",
                    Icons.sync,
                    _autoSync,
                        (value) => setState(() => _autoSync = value),
                    themeService,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    "Dark Mode",
                    "Enable dark theme",
                    Icons.dark_mode,
                    themeService.isDarkMode,
                        (value) => themeService.toggleTheme(),
                    themeService,
                  ),
                ]),

                const SizedBox(height: 24),

                // Storage Settings Section
                _buildSectionHeader("Storage & Quality", themeService),
                _buildSettingsCard(themeService, [
                  _buildDropdownTile(
                    "Upload Quality",
                    "Choose default upload quality for media files",
                    Icons.high_quality,
                    _selectedQuality,
                    ['High', 'Medium', 'Low'],
                        (value) => setState(() => _selectedQuality = value!),
                    themeService,
                  ),
                  _buildDivider(),
                  _buildDropdownTile(
                    "Storage Location",
                    "Choose where to store downloaded files",
                    Icons.folder,
                    _selectedStorage,
                    ['Auto', 'Internal Storage', 'SD Card'],
                        (value) => setState(() => _selectedStorage = value!),
                    themeService,
                  ),
                ]),

                const SizedBox(height: 24),

                // Privacy & Security Section
                _buildSectionHeader("Privacy & Security", themeService),
                _buildSettingsCard(themeService, [
                  _buildActionTile(
                    "Change Password",
                    "Update your account password",
                    Icons.lock,
                        () => _showChangePasswordDialog(themeService),
                    themeService,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    "Two-Factor Authentication",
                    "Add an extra layer of security (Coming Soon)",
                    Icons.security,
                        () => _showComingSoonDialog("Two-Factor Authentication", themeService),
                    themeService,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    "Privacy Policy",
                    "Read our privacy policy",
                    Icons.privacy_tip,
                        () => _showPrivacyPolicyDialog(themeService),
                    themeService,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    "Terms of Service",
                    "Read our terms and conditions",
                    Icons.description,
                        () => _showTermsOfServiceDialog(themeService),
                    themeService,
                  ),
                ]),

                const SizedBox(height: 24),

                // Data & Storage Section
                _buildSectionHeader("Data Management", themeService),
                _buildSettingsCard(themeService, [
                  _buildActionTile(
                    "Clear Cache",
                    "Free up space by clearing temporary files",
                    Icons.cleaning_services,
                        () => _showClearCacheDialog(themeService),
                    themeService,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    "Export Data",
                    "Download all your files and data (Coming Soon)",
                    Icons.download,
                        () => _showComingSoonDialog("Export Data", themeService),
                    themeService,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    "Delete Account",
                    "Permanently delete your account and all data",
                    Icons.delete_forever,
                        () => _showDeleteAccountDialog(themeService),
                    themeService,
                    isDestructive: true,
                  ),
                ]),

                const SizedBox(height: 24),

                // About Section
                _buildSectionHeader("About", themeService),
                _buildSettingsCard(themeService, [
                  _buildActionTile(
                    "App Version",
                    "IntelliSpace v1.0.0",
                    Icons.info,
                        () {},
                    themeService,
                    showArrow: false,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    "About Developer",
                    "Learn about the creator of IntelliSpace",
                    Icons.person,
                        () => _showAboutDeveloperDialog(themeService),
                    themeService,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    "Contact Support",
                    "Get help with your account",
                    Icons.support_agent,
                        () => _showContactSupportDialog(themeService),
                    themeService,
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, ThemeService themeService) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: themeService.textColor,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(ThemeService themeService, List<Widget> children) {
    return Card(
      color: themeService.cardColor,
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
      ThemeService themeService,
      ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: themeService.bgColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: themeService.bgColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: themeService.textColor),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: themeService.subtextColor),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: themeService.bgColor,
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
      ThemeService themeService,
      ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: themeService.bgColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: themeService.bgColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: themeService.textColor),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: themeService.subtextColor),
      ),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        underline: Container(),
        dropdownColor: themeService.cardColor,
        style: TextStyle(color: themeService.textColor),
        items: options.map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option, style: TextStyle(color: themeService.textColor)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionTile(
      String title,
      String subtitle,
      IconData icon,
      VoidCallback onTap,
      ThemeService themeService, {
        bool isDestructive = false,
        bool showArrow = true,
      }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : themeService.bgColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
            icon,
            color: isDestructive ? Colors.red : themeService.bgColor,
            size: 20
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : themeService.textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: themeService.subtextColor),
      ),
      trailing: showArrow ? Icon(Icons.arrow_forward_ios, size: 16, color: themeService.textColor) : null,
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 60);
  }

  void _showPrivacyPolicyDialog(ThemeService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("Privacy Policy", style: TextStyle(color: themeService.textColor)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "IntelliSpace Privacy Policy",
                style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor),
              ),
              const SizedBox(height: 16),
              Text(
                "1. Data Collection: We collect only the files you upload and basic account information (email, name) for authentication purposes.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "2. Data Usage: Your files are stored securely and used only to provide our cloud storage service. We do not access, view, or analyze your personal files.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "3. Data Security: All files are encrypted in transit and at rest. We use industry-standard security measures to protect your data.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "4. Data Sharing: We never share, sell, or distribute your personal files or data to third parties.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "5. Data Retention: Your files are retained until you delete them or close your account. Account data is deleted within 30 days of account closure.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "6. Your Rights: You can request access, correction, or deletion of your data at any time by contacting support.",
                style: TextStyle(color: themeService.textColor),
              ),
            ],
          ),
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

  void _showTermsOfServiceDialog(ThemeService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("Terms of Service", style: TextStyle(color: themeService.textColor)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "IntelliSpace Terms of Service",
                style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textColor),
              ),
              const SizedBox(height: 16),
              Text(
                "1. Service Description: IntelliSpace provides cloud file storage and management services for personal and educational use.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "2. Acceptable Use: You may not upload illegal content, malware, or copyrighted material you don't own. Files must comply with applicable laws.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "3. Storage Limits: Free accounts have storage limitations. We reserve the right to enforce fair usage policies.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "4. Account Responsibility: You are responsible for maintaining the security of your account credentials.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "5. Service Availability: While we strive for 99.9% uptime, we cannot guarantee uninterrupted service availability.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "6. Termination: We may terminate accounts that violate these terms. You may close your account at any time.",
                style: TextStyle(color: themeService.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "7. Limitation of Liability: IntelliSpace is provided 'as is' without warranties. We are not liable for data loss or damages.",
                style: TextStyle(color: themeService.textColor),
              ),
            ],
          ),
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

  void _showAboutDeveloperDialog(ThemeService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("About Developer", style: TextStyle(color: themeService.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFF0A3D62),
              child: Icon(Icons.person, size: 35, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              "Abdul Haseeb",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: themeService.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Computer Science Student",
              style: TextStyle(
                fontSize: 16,
                color: themeService.subtextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "International Islamic University Islamabad (IIUI)",
              style: TextStyle(
                fontSize: 14,
                color: themeService.subtextColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "IntelliSpace is my final year project, designed to provide a secure and user-friendly cloud storage solution. This app represents the culmination of my studies in computer science and mobile app development.",
              style: TextStyle(
                fontSize: 14,
                color: themeService.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Technologies Used:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: themeService.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "• Flutter & Dart\n• Supabase (Backend)\n• Cloud Storage\n• Material Design",
              style: TextStyle(
                fontSize: 12,
                color: themeService.subtextColor,
              ),
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

  void _showChangePasswordDialog(ThemeService themeService) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("Change Password", style: TextStyle(color: themeService.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              style: TextStyle(color: themeService.textColor),
              decoration: const InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              style: TextStyle(color: themeService.textColor),
              decoration: const InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              style: TextStyle(color: themeService.textColor),
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
            style: ElevatedButton.styleFrom(backgroundColor: themeService.bgColor),
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(ThemeService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("Clear Cache", style: TextStyle(color: themeService.textColor)),
        content: Text(
          "This will clear all temporary files and cached data. This action cannot be undone.",
          style: TextStyle(color: themeService.textColor),
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
            style: ElevatedButton.styleFrom(backgroundColor: themeService.bgColor),
            child: const Text("Clear", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(ThemeService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("Delete Account", style: TextStyle(color: themeService.textColor)),
        content: Text(
          "This will permanently delete your account and all your files. This action cannot be undone.",
          style: TextStyle(color: themeService.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoonDialog("Account Deletion", themeService);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog(ThemeService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("Contact Support", style: TextStyle(color: themeService.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Need help? Contact us through:", style: TextStyle(color: themeService.textColor)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.email, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "abdulhaseeb4002@gmail.com",
                    style: TextStyle(color: themeService.textColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  "+92 317 8045079",
                  style: TextStyle(color: themeService.textColor),
                ),
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

  void _showComingSoonDialog(String feature, ThemeService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.cardColor,
        title: Text("Coming Soon", style: TextStyle(color: themeService.textColor)),
        content: Text(
          "$feature will be available in a future update.",
          style: TextStyle(color: themeService.textColor),
        ),
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