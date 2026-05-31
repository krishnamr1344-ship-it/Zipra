import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/app_info.dart';

class CheckUpdatesPage extends StatefulWidget {
  const CheckUpdatesPage({super.key});

  @override
  State<CheckUpdatesPage> createState() => _CheckUpdatesPageState();
}

class _CheckUpdatesPageState extends State<CheckUpdatesPage> {
  bool _checking = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _performCheck();
  }

  Future<void> _performCheck() async {
    setState(() { _checking = true; _checked = false; });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() { _checking = false; _checked = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Check for Updates', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _checking ? _buildChecking() : _buildResult(),
      ),
    );
  }

  Widget _buildChecking() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 64, height: 64,
          child: CircularProgressIndicator(strokeWidth: 4, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        const Text('Checking for updates\u2026',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 8),
        Text('Version ${AppInfo.version}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF757575))),
      ],
    );
  }

  Widget _buildResult() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 72),
          ),
          const SizedBox(height: 20),
          const Text('You\u2019re up to date!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          Text('Version ${AppInfo.version}',
            style: const TextStyle(fontSize: 15, color: Color(0xFF757575))),
          const SizedBox(height: 16),
          Text(
            'No updates available. You are running the latest version of the app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _performCheck,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Check Again', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
