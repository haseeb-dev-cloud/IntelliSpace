import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../screens/storage_screen.dart';

class StorageInfoWidget extends StatefulWidget {
  const StorageInfoWidget({Key? key}) : super(key: key);

  @override
  State<StorageInfoWidget> createState() => _StorageInfoWidgetState();
}

class _StorageInfoWidgetState extends State<StorageInfoWidget> {
  StorageInfo? _storageInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    final info = await StorageService.getStorageInfo();
    if (mounted) {
      setState(() {
        _storageInfo = info;
        _isLoading = false;
      });
    }
  }

  String formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StorageScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueAccent[100],
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6),
          ],
        ),
        child: _isLoading
            ? const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Storage Used", style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            LinearProgressIndicator(),
            SizedBox(height: 8),
            Text("Loading..."),
          ],
        )
            : _storageInfo == null
            ? const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Storage Used", style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            LinearProgressIndicator(value: 0),
            SizedBox(height: 8),
            Text("Error loading storage info"),
          ],
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text("Storage Used", style: TextStyle(fontSize: 18)),
                Spacer(),
                Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _storageInfo!.totalUsed / _storageInfo!.totalAvailable,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _storageInfo!.totalUsed / _storageInfo!.totalAvailable > 0.8
                    ? Colors.red
                    : _storageInfo!.totalUsed / _storageInfo!.totalAvailable > 0.6
                    ? Colors.orange
                    : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${formatBytes(_storageInfo!.totalUsed)} of ${formatBytes(_storageInfo!.totalAvailable)} used",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              "${_storageInfo!.totalFiles} files • Tap for details",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}