import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/app_info.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('Preferences'),
          const SizedBox(height: 8),
          _switchTile(Icons.notifications_outlined, 'Push Notifications', _notifications, (v) => setState(() => _notifications = v)),
          _switchTile(Icons.dark_mode_outlined, 'Dark Mode', false, null, subtitle: 'Coming soon'),
          _switchTile(Icons.face_outlined, 'Face ID / Fingerprint', false, null, subtitle: 'Coming soon'),
          const SizedBox(height: 24),
          _section('Account'),
          const SizedBox(height: 8),
          _navTile(Icons.lock_outlined, 'Change Password', 'Update your password'),
          _navTile(Icons.language_outlined, 'Language', 'English'),
          const SizedBox(height: 24),
          _section('App Info'),
          const SizedBox(height: 8),
          _infoTile(Icons.info_outline, 'Version', AppInfo.version),
          _infoTile(Icons.update_outlined, 'Check for Updates', 'Tap to check'),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
    );
  }

  Widget _switchTile(IconData icon, String title, bool value, ValueChanged<bool>? onChanged, {String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF5F5FF), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: const Color(0xFF6C63FF)),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textHint)) : null,
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
        activeThumbColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _navTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF5F5FF), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: const Color(0xFF6C63FF)),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
