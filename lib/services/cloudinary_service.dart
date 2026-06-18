import 'dart:convert';
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
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      throw Exception(
        (json['error'] as Map<String, dynamic>?)?['message'] ?? 'Upload failed',
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }
}
