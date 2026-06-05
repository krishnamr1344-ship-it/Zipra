import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String latestVersion;
  final String apkUrl;

  UpdateInfo({required this.latestVersion, required this.apkUrl});

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latest_version'] as String? ?? '',
      apkUrl: json['apk_url'] as String? ?? '',
    );
  }
}

class UpdateService {
  static const String _versionUrl =
      'https://raw.githubusercontent.com/selvaabi5555/delivery-app/main/version.json';

  static Future<UpdateInfo?> fetchUpdateInfo() async {
    try {
      final res = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return UpdateInfo.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static String? compareVersions(String installed, String latest) {
    final iParts = _parseVersion(installed);
    final lParts = _parseVersion(latest);
    final maxLen = iParts.length > lParts.length
        ? iParts.length
        : lParts.length;
    for (int i = 0; i < maxLen; i++) {
      final iVal = i < iParts.length ? iParts[i] : 0;
      final lVal = i < lParts.length ? lParts[i] : 0;
      if (lVal > iVal) return latest;
      if (iVal > lVal) return null;
    }
    return null;
  }

  static List<int> _parseVersion(String v) {
    return v
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }

  static Future<void> checkForUpdate(BuildContext context) async {
    final info = await fetchUpdateInfo();
    if (info == null) return;
    final pkg = await PackageInfo.fromPlatform();
    final currentVersion = pkg.version;
    final updateVersion = compareVersions(currentVersion, info.latestVersion);
    if (updateVersion == null) return;
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('New Update Available'),
        content: Text('Please update Zipra to continue.\n\n'
            'Current: v$currentVersion\n'
            'Latest: v$updateVersion'),
        actions: [
          FilledButton(
            onPressed: () async {
              final uri = Uri.parse(info.apkUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
