import 'package:flutter/material.dart';

class AiToolsScreen extends StatelessWidget {
  const AiToolsScreen({Key? key}) : super(key: key);

  final Color backgroundColor = const Color(0xFF0A3D62);
  final Color cardColor = Colors.blueAccent;
  final Color textColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/intellispace_logo.png',
            height: 40,
            width: 40,
          ),
        ),
        title: const Text(
          'IntelliSpace',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Roboto',
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'AI Tools',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            const SizedBox(height: 30),

            buildToolCard('Content Summarization'),
            const SizedBox(height: 16),

            buildToolCard('File Compression'),
            const SizedBox(height: 16),

            buildToolCard('Duplicate File Detection'),
            const SizedBox(height: 16),

            buildToolCard('Intelligent File Organization'),
          ],
        ),
      ),
    );
  }

  Widget buildToolCard(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }
}
