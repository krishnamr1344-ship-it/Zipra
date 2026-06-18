import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/cloudinary.dart';

class CloudinaryService {
  static Future<String> uploadImage(String filePath) async {
    final uri = Uri.parse(CloudinaryConfig.uploadUrl);
    debugPrint('Uploading to: $uri');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    debugPrint('Backend upload URL: $uri');
    final response = await request.send();
    final body = await response.stream.bytesToString();
    debugPrint('Backend upload response ($response.statusCode): $body');
    if (response.statusCode != 200) {
      throw Exception('Upload failed: HTTP ${response.statusCode} — $body');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final relative = json['url'] as String;
    final fullUrl = relative.startsWith('http')
        ? relative
        : 'https://delivery-app-api-16t0.onrender.com$relative';
    debugPrint('Upload success: $fullUrl');
    return fullUrl;
  }
}
