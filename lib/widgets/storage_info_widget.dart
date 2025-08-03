import 'package:flutter/material.dart';

class StorageInfoWidget extends StatelessWidget {
  const StorageInfoWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}