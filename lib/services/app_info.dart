import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  static String version = '';
  static Future<void> load() async {
    final info = await PackageInfo.fromPlatform();
    version = '${info.version}+${info.buildNumber}';
  }
}
