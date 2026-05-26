import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.shopping_bag, size: 48, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 16),
            const Text('Grocery App', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            const Text('Version 1.0.0', style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
          ],
        ),
      ),
    );
  }
}
