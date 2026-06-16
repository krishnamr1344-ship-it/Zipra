import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const _baseUrl = 'https://delivery-app-api-16t0.onrender.com';
  static const _tokenKey = 'auth_token';
  static const _userNameKey = 'user_name';
  static const _userEmailKey = 'user_email';
  static const _userPhoneKey = 'user_phone';
  static const _userRoleKey = 'user_role';

  final _secureStorage = const FlutterSecureStorage();

  // ─── Token Management ──────────────────────────────────────────

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<void> _saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<void> _clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userNameKey);
    await _secureStorage.delete(key: _userEmailKey);
    await _secureStorage.delete(key: _userPhoneKey);
    await _secureStorage.delete(key: _userRoleKey);
  }

  // ─── API Calls ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (e) {
        debugPrint('ApiService._handleResponse: decode failed: $e');
      }
      throw ApiException('Invalid response (${res.statusCode})');
    }
    if (kDebugMode) debugPrint('API Error ${res.statusCode}: ${res.body}');
    final msg = _tryDecodeDetail(res.body) ?? 'Request failed (${res.statusCode})';
    throw ApiException(msg);
  }

  List<dynamic> _handleListResponse(http.Response res) {
    if (res.statusCode != 200) {
      if (kDebugMode) debugPrint('API Error ${res.statusCode}: ${res.body}');
      throw ApiException(_tryDecodeDetail(res.body) ?? 'Request failed (${res.statusCode})');
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is List<dynamic>) return decoded;
      } catch (e) {
        debugPrint('ApiService._handleListResponse: decode failed: $e');
      }
    throw ApiException('Invalid response (${res.statusCode})');
  }

  String? _tryDecodeDetail(String body) {
    try {
      final map = jsonDecode(body);
      if (map is Map) {
        final detail = map['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          // FastAPI 422 returns list of error objects
          final first = detail.first;
          if (first is Map && first['msg'] is String) {
            return first['msg'] as String;
          }
          return detail.first.toString();
        }
      }
    } catch (e) {
      debugPrint('ApiService._tryDecodeDetail: decode failed: $e');
    }
    return null;
  }

  bool _checkAndHandleUnauthorized(int statusCode) {
    if (statusCode == 401) {
      _clearToken();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> register(String name, String email, String phone, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'phone': phone, 'password': password}),
    ).timeout(const Duration(seconds: 60));
    final body = await _handleResponse(res);
    await _saveToken(body['token']);
    await _saveUserLocally((body['user'] as Map<String, dynamic>?)?['name'] as String? ?? '', (body['user'] as Map<String, dynamic>?)?['email'] as String? ?? '', phone, (body['user'] as Map<String, dynamic>?)?['role'] as String? ?? 'user');
    return body;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 60));
    final body = await _handleResponse(res);
    await _saveToken(body['token']);
    final userMap = body['user'] as Map<String, dynamic>?;
    await _saveUserLocally(
      userMap?['name'] as String? ?? '',
      userMap?['email'] as String? ?? '',
      userMap?['phone'] as String? ?? '',
      userMap?['role'] as String? ?? 'user',
    );
    return body;
  }

  Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}),
        ).timeout(const Duration(seconds: 60));
      } catch (e) {
        debugPrint('ApiService.logout: request failed: $e');
      }
    }
    await _clearToken();
  }

  // ─── Local User Storage (fallback) ─────────────────────────────

  Future<Map<String, dynamic>> getSavedUser() async {
    return {
      'name': await _secureStorage.read(key: _userNameKey) ?? 'User',
      'email': await _secureStorage.read(key: _userEmailKey) ?? '',
      'phone': await _secureStorage.read(key: _userPhoneKey) ?? '',
      'role': await _secureStorage.read(key: _userRoleKey) ?? 'user',
    };
  }

  Future<void> _saveUserLocally(String name, String email, String phone, [String role = 'user']) async {
    await _secureStorage.write(key: _userNameKey, value: name);
    await _secureStorage.write(key: _userEmailKey, value: email);
    await _secureStorage.write(key: _userPhoneKey, value: phone);
    await _secureStorage.write(key: _userRoleKey, value: role);
  }

  Future<Map<String, dynamic>> updateProfile(String name, String email, {String phone = ''}) async {
    final headers = await _authHeaders(required: true);
    final res = await http.put(
      Uri.parse('$_baseUrl/api/auth/profile'),
      headers: headers,
      body: jsonEncode({'name': name, 'email': email, 'phone': phone}),
    ).timeout(const Duration(seconds: 60));
    final body = await _handleResponse(res);
    await _saveUserLocally((body['user'] as Map<String, dynamic>?)?['name'] as String? ?? '', (body['user'] as Map<String, dynamic>?)?['email'] as String? ?? '', phone, (body['user'] as Map<String, dynamic>?)?['role'] as String? ?? 'user');
    return body;
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

  Future<Map<String, dynamic>> createGpsAddress(double latitude, double longitude, {String? landmark, String? addressType, String? houseNumber, String? floorNumber}) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) {
      throw Exception('Authentication required to save GPS address');
    }
    final bodyMap = <String, dynamic>{'latitude': latitude, 'longitude': longitude};
    if (landmark != null && landmark.isNotEmpty) bodyMap['landmark'] = landmark;
    if (addressType != null && addressType.isNotEmpty) bodyMap['address_type'] = addressType;
    if (houseNumber != null && houseNumber.isNotEmpty) bodyMap['house_number'] = houseNumber;
    if (floorNumber != null && floorNumber.isNotEmpty) bodyMap['floor_number'] = floorNumber;
    final res = await http.post(Uri.parse('$_baseUrl/api/addresses/auto'), headers: headers, body: jsonEncode(bodyMap)).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) {
      throw Exception('Authentication required to create address');
    }
    final res = await http.post(Uri.parse('$_baseUrl/api/addresses'), headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<List<dynamic>> getAddresses() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/addresses'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return [];
    return _handleListResponse(res);
  }

  Future<void> deleteAddress(String addressId) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) throw ApiException('Login required');
    final res = await http.delete(Uri.parse('$_baseUrl/api/addresses/$addressId'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return;
    if (res.statusCode != 200) {
      if (kDebugMode) debugPrint('API Error ${res.statusCode}: ${res.body}');
      throw ApiException(_tryDecodeDetail(res.body) ?? 'Failed to delete address');
    }
  }

  Future<Map<String, dynamic>> updateAddress(String addressId, Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) throw ApiException('Login required');
    final res = await http.put(Uri.parse('$_baseUrl/api/addresses/$addressId'), headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse('$_baseUrl/api/places/reverse?lat=$lat&lng=$lng'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        if (_checkAndHandleUnauthorized(res.statusCode)) return {};
        return {};
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('ApiService.reverseGeocode: request failed: $e');
      return {};
    }
  }

  Future<List<dynamic>> searchPlaces(String query) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse('$_baseUrl/api/places/search?q=${Uri.encodeQueryComponent(query)}'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return [];
      if (_checkAndHandleUnauthorized(res.statusCode)) return [];
      return jsonDecode(res.body) as List<dynamic>;
    } catch (e) {
      debugPrint('ApiService.searchPlaces: request failed: $e');
      return [];
    }
  }

  // ─── Products & Categories (user-facing) ───────────────────────

  Future<List<dynamic>> getCategories() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_baseUrl/api/categories'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<List<dynamic>> getProducts() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_baseUrl/api/products'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> createOrder(List<Map<String, dynamic>> items, String paymentMethod, {String? addressId}) async {
    final headers = await _authHeaders(required: true);
    final bodyMap = <String, dynamic>{
      'items': items,
      'payment_method': paymentMethod,
    };
    if (addressId != null) bodyMap['address_id'] = addressId;
    final res = await http.post(Uri.parse('$_baseUrl/api/orders/direct'), headers: headers, body: jsonEncode(bodyMap)).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<List<dynamic>> getOrders() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/orders'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return [];
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.get(Uri.parse('$_baseUrl/api/orders/$orderId'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  // ─── Combo Packs ──────────────────────────────────────────────────

  Future<List<dynamic>> getComboPacks() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/combo-packs')).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is List<dynamic>) return decoded;
      } catch (e) {
        debugPrint('ApiService.getComboPacks: request failed: $e');
      }
    return [];
  }

  // ─── Forgot Password ────────────────────────────────────────────

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'new_password': newPassword}),
    ).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  // ─── Cart ────────────────────────────────────────────────────────

  Future<List<dynamic>> getCart() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/cart'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return [];
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> addToCart(String productId, {int quantity = 1}) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(
      Uri.parse('$_baseUrl/api/cart'),
      headers: headers,
      body: jsonEncode({'product_id': productId, 'quantity': quantity}),
    ).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<void> updateCartItem(String itemId, int quantity) async {
    final headers = await _authHeaders(required: true);
    final res = await http.put(
      Uri.parse('$_baseUrl/api/cart/$itemId'),
      headers: headers,
      body: jsonEncode({'quantity': quantity}),
    ).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return;
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw ApiException('Failed to update cart');
  }

  Future<void> removeCartItem(String itemId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.delete(Uri.parse('$_baseUrl/api/cart/$itemId'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return;
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw ApiException('Failed to remove cart item');
  }

  Future<void> clearCart() async {
    final headers = await _authHeaders(required: true);
    final res = await http.delete(Uri.parse('$_baseUrl/api/cart'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return;
  }

  // ─── Wishlist ────────────────────────────────────────────────────

  Future<List<dynamic>> getWishlist() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/wishlist'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return [];
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> addToWishlist(String productId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(
      Uri.parse('$_baseUrl/api/wishlist'),
      headers: headers,
      body: jsonEncode({'product_id': productId}),
    ).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<void> removeFromWishlist(String productId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.delete(Uri.parse('$_baseUrl/api/wishlist/$productId'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return;
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw ApiException('Failed to remove from wishlist');
  }

  // ─── Suggest Product ─────────────────────────────────────────────

  Future<Map<String, dynamic>> suggestProduct(String productName, String reason) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/suggest-product'),
      headers: headers,
      body: jsonEncode({'product_name': productName, 'reason': reason}),
    ).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> addPackToCart(String packId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(
      Uri.parse('$_baseUrl/api/combo-packs/add-to-cart'),
      headers: headers,
      body: jsonEncode({'pack_id': packId}),
    ).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> getAppVersion() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/app-version'),
    ).timeout(const Duration(seconds: 15));
    return _handleResponse(res);
  }

  Future<void> warmUp() async {
    try {
      await http.get(
        Uri.parse('$_baseUrl/api/app-version'),
      ).timeout(const Duration(seconds: 20));
      } catch (e) {
        debugPrint('ApiService.warmUp: request failed: $e');
      }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
