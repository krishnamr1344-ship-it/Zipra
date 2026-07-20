import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrl = 'https://zipra-api-583825347591.asia-south1.run.app';
const String _tokenKey = 'auth_token';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_phone');
    await prefs.remove('user_role');
  }

  Future<Map<String, dynamic>> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('user_name') ?? '',
      'email': prefs.getString('user_email') ?? '',
      'phone': prefs.getString('user_phone') ?? '',
      'role': prefs.getString('user_role') ?? '',
    };
  }

  Future<void> _saveUserLocally(String name, String email, String phone, [String role = 'admin']) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_role', role);
  }

  Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}),
        );
      } catch (_) {}
    }
    await _clearToken();
  }

  Future<Map<String, dynamic>> loginEmail(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/login-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['detail'] ?? 'Login failed';
      throw ApiException(msg);
    }
    final body = jsonDecode(res.body);
    final user = body['user'] as Map<String, dynamic>;
    await _saveToken(body['token'] as String);
    final role = user['role'] as String? ?? '';
    if (role != 'admin') {
      throw ApiException('Access denied. Admin only.');
    }
    await _saveUserLocally(
      user['name'] ?? '',
      user['email'] ?? '',
      '',
      role,
    );
    return body;
  }
}
