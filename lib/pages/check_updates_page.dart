import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/app_info.dart';

class CheckUpdatesPage extends StatefulWidget {
  const CheckUpdatesPage({super.key});

  @override
  State<CheckUpdatesPage> createState() => _CheckUpdatesPageState();
}

class _CheckUpdatesPageState extends State<CheckUpdatesPage> {
  final _api = ApiService();
  bool _checking = true;
  bool _checked = false;
  bool _hasUpdate = false;
  String? _error;
  String _latestVersion = '';
  String _apkUrl = '';
  String? _releaseNotes;

  @override
  void initState() {
    super.initState();
    _performCheck();
  }

  Future<void> _performCheck() async {
    setState(() { _checking = true; _checked = false; _error = null; });
    try {
      final data = await _api.getAppVersion();
      if (!mounted) return;
      _latestVersion = data['latest_version'] as String? ?? '';
      _apkUrl = data['apk_download_url'] as String? ?? '';
      _releaseNotes = data['release_notes'] as String?;

      final installed = AppInfo.version.split('+').first.trim();
      final latest = _latestVersion.trim();

      setState(() {
        _checking = false;
        _checked = true;
        _hasUpdate = _compareVersions(installed, latest) < 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _checked = true;
        _error = 'Failed to check for updates.\nPlease try again later.';
      });
    }
  }

  /// Returns -1 if a < b, 0 if a == b, 1 if a > b
  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;
      if (aVal < bVal) return -1;
      if (aVal > bVal) return 1;
    }
    return 0;
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
        Text('Version ${AppInfo.version.split('+').first}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF757575))),
      ],
    );
  }

  Widget _buildResult() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.error_outline, color: AppColors.primary, size: 72),
            ),
            const SizedBox(height: 20),
            Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF757575), height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _performCheck,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasUpdate) {
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
            Text('Version ${AppInfo.version.split('+').first}',
              style: const TextStyle(fontSize: 15, color: Color(0xFF757575))),
            const SizedBox(height: 16),
            Text(
              'No updates available. You are running the latest version.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 50,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.system_update, color: AppColors.primary, size: 72),
          ),
          const SizedBox(height: 20),
          const Text('Update Available',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('v${AppInfo.version.split('+').first}',
                style: const TextStyle(fontSize: 15, color: Color(0xFF757575), decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                child: Text('v$_latestVersion', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          if (_releaseNotes != null && _releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Release Notes',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF444444))),
                  const SizedBox(height: 6),
                  Text(_releaseNotes!, style: const TextStyle(fontSize: 12, color: Color(0xFF757575), height: 1.5)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Opening download page\u2026'),
                    behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(Icons.download, size: 20),
              label: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 50,
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
