import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/app_info.dart';

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
                color: AppColors.chipBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.shopping_bag, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('Grocery App', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Version ${AppInfo.version}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
