import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({Key? key}) : super(key: key);

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final Color bgColor = const Color(0xFF0A3D62);
  User? currentUser;
  Map<String, dynamic>? userStats;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccountInfo();
  }

  Future<void> _loadAccountInfo() async {
    currentUser = Supabase.instance.client.auth.currentUser;
    
    if (currentUser != null) {
      // Get user file statistics
      final response = await Supabase.instance.client
          .from('user_files')
          .select('size, uploaded_at')
          .eq('user_id', currentUser!.id);
      
      final files = response as List;
      final totalFiles = files.length;
      final totalSize = files.fold<int>(0, (sum, file) => sum + (file['size'] as int? ?? 0));
      
      setState(() {
        userStats = {
          'totalFiles': totalFiles,
          'totalSize': totalSize,
          'storageUsed': _formatBytes(totalSize),
        };
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: bgColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Account Information"),
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentUser == null
              ? const Center(
                  child: Text(
                    "No user information available",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person, size: 50, color: bgColor),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              currentUser!.userMetadata?['full_name'] ?? 
                              currentUser!.userMetadata?['display_name'] ?? 
                              'User',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentUser!.email ?? 'No email',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Account Details Section
                      const Text(
                        "Account Details",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildInfoCard(
                        "User ID",
                        currentUser!.id,
                        Icons.fingerprint,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _buildInfoCard(
                        "Email",
                        currentUser!.email ?? 'N/A',
                        Icons.email,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _buildInfoCard(
                        "Account Created",
                        _formatDate(currentUser!.createdAt),
                        Icons.calendar_today,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _buildInfoCard(
                        "Last Sign In",
                        _formatDate(currentUser!.lastSignInAt),
                        Icons.login,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _buildInfoCard(
                        "Email Confirmed",
                        currentUser!.emailConfirmedAt != null ? "Yes" : "No",
                        currentUser!.emailConfirmedAt != null ? Icons.verified : Icons.warning,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Storage Statistics Section
                      const Text(
                        "Storage Statistics",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (userStats != null) ...[
                        _buildInfoCard(
                          "Total Files",
                          "${userStats!['totalFiles']}",
                          Icons.folder,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        _buildInfoCard(
                          "Storage Used",
                          userStats!['storageUsed'],
                          Icons.storage,
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _loadAccountInfo(); // Refresh data
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("Refresh Information"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: bgColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}