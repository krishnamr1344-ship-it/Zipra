import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/cloudinary.dart';
import 'api_service.dart';

class CloudinaryService {
  static Future<String> uploadImage(String filePath) async {
    final token = await ApiService().getToken();
    final uri = Uri.parse(CloudinaryConfig.uploadUrl);
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw Exception('Upload failed');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final relative = json['url'] as String;
    final fullUrl = relative.startsWith('http')
        ? relative
        : 'https://delivery-app-api-16t0.onrender.com$relative';
    return fullUrl;
  }
}
