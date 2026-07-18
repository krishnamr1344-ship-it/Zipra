part of 'api_service_base.dart';

// ─── Auth Methods ──────────────────────────────────────────────

mixin AuthApi on ApiServiceBase {
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

  /// Exchange a Firebase ID token for a backend JWT.
  Future<Map<String, dynamic>> socialLogin(String email, String name, String idToken, [String phone = '']) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/social'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'name': name, 'phone': phone, 'id_token': idToken}),
    );
    final body = await _handleResponse(res);
    final user = body['user'] as Map<String, dynamic>;
    await _saveToken(body['token'] as String);
    await _saveUserLocally(
      user['name'] ?? '',
      user['email'] ?? '',
      phone,
      user['role'] ?? 'user',
    );
    return body;
  }
}
