import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Allow self‑signed SSL certificates (development only).
class _AllowSelfSignedCert extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

final _initSsl = () {
  HttpOverrides.global = _AllowSelfSignedCert();
  return true;
}();

class ApiService {
  static const _baseUrl = 'https://zipra-api-583825347591.asia-south1.run.app';
  static const _tokenKey = 'auth_token';

  // ─── Token Management ──────────────────────────────────────────

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

  // ─── API Calls ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    debugPrint('API Error ${res.statusCode}: ${res.body}');
    final msg = _tryDecodeDetail(res.body) ?? 'Request failed (${res.statusCode})';
    throw ApiException(msg);
  }

  List<dynamic> _handleListResponse(http.Response res) {
    if (res.statusCode != 200) {
      debugPrint('API Error ${res.statusCode}: ${res.body}');
      throw ApiException(_tryDecodeDetail(res.body) ?? 'Request failed (${res.statusCode})');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in const ['products', 'items', 'data', 'results']) {
        final v = decoded[key];
        if (v is List) return v;
      }
    }
    return [];
  }

  String? _tryDecodeDetail(String body) {
    try {
      final map = jsonDecode(body);
      if (map is Map) return map['detail'] as String?;
    } catch (_) {}
    return null;
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

  /// Exchange a Firebase ID token for a backend JWT.
  /// Calls POST /api/auth/social with the Firebase ID token. The backend
  /// verifies the token and returns a backend JWT that the app stores locally.
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

  // ─── Local User Storage (fallback) ─────────────────────────────

  Future<Map<String, dynamic>> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('user_name') ?? 'User',
      'email': prefs.getString('user_email') ?? '',
      'phone': prefs.getString('user_phone') ?? '',
      'role': prefs.getString('user_role') ?? 'user',
    };
  }

  Future<void> _saveUserLocally(String name, String email, String phone, [String role = 'user']) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_role', role);
  }

  Future<void> saveUser(String name, String email, {String phone = ''}) async {
    await _saveUserLocally(name, email, phone);
  }

  Future<void> clearToken() async {
    await _clearToken();
  }

  Future<Map<String, String>> _authHeaders({bool required = false}) async {
    final token = await getToken();
    if (token == null && required) throw ApiException('Login required');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Addresses ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> createGpsAddress(double latitude, double longitude, {String? landmark}) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) {
      return {'id': '', 'address_line1': '', 'address_line2': '', 'city': '', 'latitude': latitude.toString(), 'longitude': longitude.toString()};
    }
    final bodyMap = <String, dynamic>{'latitude': latitude, 'longitude': longitude};
    if (landmark != null && landmark.isNotEmpty) bodyMap['landmark'] = landmark;
    final res = await http.post(Uri.parse('$_baseUrl/api/addresses/auto'), headers: headers, body: jsonEncode(bodyMap));
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) {
      return {'id': '', 'address_line1': data['address_line1'] ?? ''};
    }
    final res = await http.post(Uri.parse('$_baseUrl/api/addresses'), headers: headers, body: jsonEncode(data));
    return _handleResponse(res);
  }

  Future<List<dynamic>> getAddresses() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/addresses'), headers: headers);
    return _handleListResponse(res);
  }

  Future<void> deleteAddress(String addressId) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) throw ApiException('Login required');
    final res = await http.delete(Uri.parse('$_baseUrl/api/addresses/$addressId'), headers: headers);
    if (res.statusCode != 200) {
      debugPrint('API Error ${res.statusCode}: ${res.body}');
      throw ApiException(_tryDecodeDetail(res.body) ?? 'Failed to delete address');
    }
  }

  Future<Map<String, dynamic>> updateAddress(String addressId, Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) throw ApiException('Login required');
    final res = await http.put(Uri.parse('$_baseUrl/api/addresses/$addressId'), headers: headers, body: jsonEncode(data));
    return _handleResponse(res);
  }

  Future<List<dynamic>> searchPlaces(String query) async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/places/search?q=${Uri.encodeQueryComponent(query)}'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      debugPrint('API Error ${res.statusCode}: ${res.body}');
      return [];
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  // ─── Products & Categories (user-facing) ───────────────────────

  Future<List<dynamic>> getCategories() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_baseUrl/api/categories'), headers: headers);
    return _handleListResponse(res);
  }

  Future<List<dynamic>> getProducts() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_baseUrl/api/products'), headers: headers);
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> createOrder(List<Map<String, dynamic>> items, String paymentMethod, {String? addressId, double? deliveryFee}) async {
    final headers = await _authHeaders(required: true);
    final bodyMap = <String, dynamic>{
      'items': items,
      'payment_method': paymentMethod,
    };
    if (addressId != null) bodyMap['address_id'] = addressId;
    if (deliveryFee != null) bodyMap['delivery_fee'] = deliveryFee;
    final res = await http.post(Uri.parse('$_baseUrl/api/orders/direct'), headers: headers, body: jsonEncode(bodyMap));
    return _handleResponse(res);
  }

  Future<List<dynamic>> getOrders() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/orders'), headers: headers);
    return _handleListResponse(res);
  }

  // ─── Offers ─────────────────────────────────────────────────────

  Future<List<dynamic>> getOffers() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/offers'));
    if (res.statusCode != 200) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

  // ─── Combo Packs ──────────────────────────────────────────────────

  Future<List<dynamic>> getComboPacks() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/combo-packs'));
    if (res.statusCode != 200) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> addPackToCart(String packId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(
      Uri.parse('$_baseUrl/api/combo-packs/add-to-cart'),
      headers: headers,
      body: jsonEncode({'pack_id': packId}),
    );
    return _handleResponse(res);
  }

  // ─── Delivery Fee ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getDeliveryFee(double subtotal) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/delivery-fee'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'subtotal': subtotal}));
    if (res.statusCode != 200) return {'fee': 0, 'message': 'Free delivery'};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
