import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/cloudinary.dart';

class CloudinaryService {
  static Future<String> uploadImage(String filePath) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    debugPrint('Cloudinary upload URL: $uri');
    debugPrint('Cloudinary upload preset: ${CloudinaryConfig.uploadPreset}');
    final response = await request.send();
    final body = await response.stream.bytesToString();
    debugPrint('Cloudinary response ($response.statusCode): $body');
    if (response.statusCode != 200) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final err = (json['error'] as Map<String, dynamic>?)?['message'] ?? 'Upload failed';
      debugPrint('Cloudinary error: $err');
      throw Exception(err);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final url = json['secure_url'] as String;
    debugPrint('Cloudinary upload success: $url');
    return url;
  }
}
