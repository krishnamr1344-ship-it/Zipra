import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://delivery-app-api-16t0.onrender.com',
  );
  static const _tokenKey = 'auth_token';
  static const _userNameKey = 'user_name';
  static const _userEmailKey = 'user_email';
  static const _userPhoneKey = 'user_phone';
  static const _userRoleKey = 'user_role';
  static const _userIdKey = 'user_id';
  static const _connectTimeout = Duration(seconds: 15);
  static const _receiveTimeout = Duration(seconds: 30);

  late final http.Client _httpClient;

  final _secureStorage = const FlutterSecureStorage();

  ApiService() {
    _httpClient = http.Client();
  }

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
    await _secureStorage.delete(key: _userIdKey);
  }

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
    if (kDebugMode) debugPrint('API Error ${res.statusCode}');
    final msg = _tryDecodeDetail(res.body) ?? 'Request failed (${res.statusCode})';
    throw ApiException(msg);
  }

  List<dynamic> _handleListResponse(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (kDebugMode) debugPrint('API Error ${res.statusCode}');
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

  Future<T> _withTimeout<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on SocketException {
      throw ApiException('No internet connection');
    } on TimeoutException {
      throw ApiException('Request timed out');
    }
  }

  bool _checkAndHandleUnauthorized(int statusCode) {
    if (statusCode == 401) {
      _clearToken();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    final res = await _withTimeout(() => http.post(
      Uri.parse('$_baseUrl/api/auth/google-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    ).timeout(const Duration(seconds: 60)));
    final body = await _handleResponse(res);
    await _saveToken(body['token']);
    final userMap = body['user'] as Map<String, dynamic>?;
    await _saveUserLocally(
      userMap?['name'] as String? ?? '',
      userMap?['email'] as String? ?? '',
      userMap?['phone'] as String? ?? '',
      userMap?['role'] as String? ?? 'user',
      userMap?['id'] as String? ?? '',
    );
    return body;
  }

  Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      try {
        await _withTimeout(() => http.post(
          Uri.parse('$_baseUrl/api/auth/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 60)));
      } catch (e) {
        if (kDebugMode) debugPrint('ApiService.logout: request failed');
      }
    }
    await _clearToken();
  }

  Future<Map<String, dynamic>> getSavedUser() async {
    return {
      'name': await _secureStorage.read(key: _userNameKey) ?? 'User',
      'email': await _secureStorage.read(key: _userEmailKey) ?? '',
      'phone': await _secureStorage.read(key: _userPhoneKey) ?? '',
      'role': await _secureStorage.read(key: _userRoleKey) ?? 'user',
      'id': await _secureStorage.read(key: _userIdKey) ?? '',
    };
  }

  Future<void> _saveUserLocally(String name, String email, String phone, [String role = 'user', String id = '']) async {
    await _secureStorage.write(key: _userNameKey, value: name);
    await _secureStorage.write(key: _userEmailKey, value: email);
    await _secureStorage.write(key: _userPhoneKey, value: phone);
    await _secureStorage.write(key: _userRoleKey, value: role);
    if (id.isNotEmpty) await _secureStorage.write(key: _userIdKey, value: id);
  }

  Future<Map<String, dynamic>> updateProfile(String name, String email, {String phone = ''}) async {
    final headers = await _authHeaders(required: true);
    final res = await http.put(
      Uri.parse('$_baseUrl/api/auth/profile'),
      headers: headers,
      body: jsonEncode({'name': name, 'phone': phone}),
    ).timeout(const Duration(seconds: 60));
    final body = await _handleResponse(res);
    final u = body['user'] as Map<String, dynamic>?;
    await _saveUserLocally(
      u?['name'] as String? ?? '',
      u?['email'] as String? ?? '',
      u?['phone'] as String? ?? '',
      u?['role'] as String? ?? 'user',
      u?['id'] as String? ?? '',
    );
    return body;
  }

  Future<Map<String, dynamic>> updatePhone(String phone) async {
    final headers = await _authHeaders(required: true);
    final res = await http.put(
      Uri.parse('$_baseUrl/api/auth/profile/phone'),
      headers: headers,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 60));
    final body = await _handleResponse(res);
    final u = body['user'] as Map<String, dynamic>?;
    await _saveUserLocally(
      u?['name'] as String? ?? '',
      u?['email'] as String? ?? '',
      u?['phone'] as String? ?? '',
      u?['role'] as String? ?? 'user',
      u?['id'] as String? ?? '',
    );
    return body;
  }

  Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders(required: true);
    final res = await http.get(
      Uri.parse('$_baseUrl/api/auth/me'),
      headers: headers,
    ).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
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

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    throw ApiException('Password reset is not available. Use Google Sign-In.');
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    throw ApiException('Password reset is not available. Use Google Sign-In.');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    throw ApiException('Email/password login removed. Use Google Sign-In.');
  }

  Future<Map<String, dynamic>> register(String name, String email, String phone, String password) async {
    throw ApiException('Registration removed. Use Google Sign-In.');
  }

  Future<Map<String, dynamic>> verifyRegistration(String email, String otp) async {
    throw ApiException('Registration removed. Use Google Sign-In.');
  }

  // ─── Addresses ──────────────────────────────────────────────────

  Future<List<dynamic>> getAddresses() async {
    final headers = await _authHeaders(required: true);
    final res = await http.get(Uri.parse('$_baseUrl/api/addresses'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> addAddress(Map<String, dynamic> data) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(Uri.parse('$_baseUrl/api/addresses'), headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> data) async {
    return addAddress(data);
  }

  Future<Map<String, dynamic>> createGpsAddress(double latitude, double longitude, {String? landmark, String? addressType, String? houseNumber, String? floorNumber}) async {
    final headers = await _authHeaders(required: true);
    final bodyMap = <String, dynamic>{'latitude': latitude, 'longitude': longitude};
    if (landmark != null && landmark.isNotEmpty) bodyMap['landmark'] = landmark;
    if (addressType != null && addressType.isNotEmpty) bodyMap['address_type'] = addressType;
    if (houseNumber != null && houseNumber.isNotEmpty) bodyMap['house_number'] = houseNumber;
    if (floorNumber != null && floorNumber.isNotEmpty) bodyMap['floor_number'] = floorNumber;
    final res = await http.post(Uri.parse('$_baseUrl/api/addresses/auto'), headers: headers, body: jsonEncode(bodyMap)).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> updateAddress(String id, Map<String, dynamic> data) async {
    final headers = await _authHeaders(required: true);
    final res = await http.put(Uri.parse('$_baseUrl/api/addresses/$id'), headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<void> deleteAddress(String id) async {
    final headers = await _authHeaders(required: true);
    await http.delete(Uri.parse('$_baseUrl/api/addresses/$id'), headers: headers).timeout(const Duration(seconds: 60));
  }

  Future<Map<String, dynamic>> setDefaultAddress(String id) async {
    final headers = await _authHeaders(required: true);
    final res = await http.put(Uri.parse('$_baseUrl/api/addresses/$id/default'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  // ─── Places ─────────────────────────────────────────────────────

  Future<List<dynamic>> searchPlaces(String query) async {
    final res = await http.get(Uri.parse('$_baseUrl/api/places/search?q=$query'), headers: await _authHeaders()).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    final res = await http.get(Uri.parse('$_baseUrl/api/places/reverse?lat=$lat&lng=$lng'), headers: await _authHeaders()).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  // ─── Categories ─────────────────────────────────────────────────

  Future<List<dynamic>> getCategories() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/categories')).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  // ─── Products ───────────────────────────────────────────────────

  Future<List<dynamic>> getProducts({String? categoryId, String? search, int page = 1, int limit = 50}) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (categoryId != null) params['category_id'] = categoryId;
    if (search != null) params['search'] = search;
    final uri = Uri.parse('$_baseUrl/api/products').replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<List<dynamic>> getCart() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/cart'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return [];
    return _handleListResponse(res);
  }

  Future<void> clearCart() async {
    final headers = await _authHeaders(required: true);
    final res = await http.delete(Uri.parse('$_baseUrl/api/cart'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return;
  }

  // ─── Cart ───────────────────────────────────────────────────────

  Future<List<dynamic>> getCartItems() async {
    final headers = await _authHeaders(required: true);
    final res = await http.get(Uri.parse('$_baseUrl/api/cart'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> addToCart(String productId, {int quantity = 1}) async {
    final headers = await _authHeaders(required: true);
    final res = await _withTimeout(() => http.post(Uri.parse('$_baseUrl/api/cart'), headers: headers, body: jsonEncode({'product_id': productId, 'quantity': quantity})).timeout(const Duration(seconds: 60)));
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> updateCartItem(String itemId, int quantity) async {
    final headers = await _authHeaders(required: true);
    final res = await http.put(Uri.parse('$_baseUrl/api/cart/$itemId'), headers: headers, body: jsonEncode({'quantity': quantity})).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<void> removeCartItem(String itemId) async {
    final headers = await _authHeaders(required: true);
    await http.delete(Uri.parse('$_baseUrl/api/cart/$itemId'), headers: headers).timeout(const Duration(seconds: 60));
  }

  // ─── Orders ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data) async {
    final headers = await _authHeaders(required: true);
    final res = await _withTimeout(() => http.post(Uri.parse('$_baseUrl/api/orders'), headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 120)));
    return _handleResponse(res);
  }

  Future<List<dynamic>> getOrders() async {
    final headers = await _authHeaders(required: true);
    final res = await http.get(Uri.parse('$_baseUrl/api/orders'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> getOrder(String id) async {
    final headers = await _authHeaders(required: true);
    final res = await http.get(Uri.parse('$_baseUrl/api/orders/$id'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  // ─── Wishlist ───────────────────────────────────────────────────

  Future<List<dynamic>> getWishlistItems() async {
    final headers = await _authHeaders(required: true);
    final res = await http.get(Uri.parse('$_baseUrl/api/wishlist'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<List<dynamic>> getWishlist() async {
    return getWishlistItems();
  }

  Future<Map<String, dynamic>> addToWishlist(String productId) async {
    final headers = await _authHeaders(required: true);
    final res = await _withTimeout(() => http.post(Uri.parse('$_baseUrl/api/wishlist'), headers: headers, body: jsonEncode({'product_id': productId})).timeout(const Duration(seconds: 60)));
    return _handleResponse(res);
  }

  Future<void> removeFromWishlist(String itemId) async {
    final headers = await _authHeaders(required: true);
    await http.delete(Uri.parse('$_baseUrl/api/wishlist/$itemId'), headers: headers).timeout(const Duration(seconds: 60));
  }

  // ─── Payments ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> createPaymentOrder(Map<String, dynamic> data) async {
    final headers = await _authHeaders(required: true);
    final res = await _withTimeout(() => http.post(Uri.parse('$_baseUrl/api/payments/create-order'), headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 60)));
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> verifyPayment(Map<String, dynamic> data) async {
    final headers = await _authHeaders(required: true);
    final res = await _withTimeout(() => http.post(Uri.parse('$_baseUrl/api/payments/verify'), headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 60)));
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment({String? orderId, String? intentId, required String paymentId, required String signature}) async {
    final headers = await _authHeaders(required: true);
    final body = <String, dynamic>{'razorpay_payment_id': paymentId, 'razorpay_signature': signature};
    if (orderId != null) body['order_id'] = orderId;
    if (intentId != null) body['intent_id'] = intentId;
    final res = await http.post(Uri.parse('$_baseUrl/api/payments/verify'), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> createRazorpayOrder(String orderId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(Uri.parse('$_baseUrl/api/payments/create-order'), headers: headers, body: jsonEncode({'order_id': orderId})).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> createPaymentIntent(List<Map<String, dynamic>> cartItems, String? addressId, {String? phone}) async {
    final headers = await _authHeaders(required: true);
    final body = <String, dynamic>{'cart_items': cartItems};
    if (addressId != null) body['address_id'] = addressId;
    if (phone != null) body['phone'] = phone;
    final res = await http.post(Uri.parse('$_baseUrl/api/payments/create-order'), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> placeOrder(String addressId, String paymentMethod) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(
      Uri.parse('$_baseUrl/api/orders'),
      headers: headers,
      body: jsonEncode({'address_id': addressId, 'payment_method': paymentMethod}),
    ).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> processPayment(String orderId, String method) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(
      Uri.parse('$_baseUrl/api/payments/process'),
      headers: headers,
      body: jsonEncode({'order_id': orderId, 'method': method}),
    ).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> cancelPaymentIntent(String intentId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(Uri.parse('$_baseUrl/api/payments/cancel/$intentId'), headers: headers).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  // ─── Combo Packs ────────────────────────────────────────────────

  Future<List<dynamic>> getComboPacks() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/combo-packs')).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> addPackToCart(String packId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(Uri.parse('$_baseUrl/api/combo-packs/add-to-cart'), headers: headers, body: jsonEncode({'pack_id': packId})).timeout(const Duration(seconds: 60));
    if (_checkAndHandleUnauthorized(res.statusCode)) return {};
    return _handleResponse(res);
  }

  // ─── Banners ───────────────────────────────────────────────────

  Future<List<dynamic>> getBanners() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/banners')).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  // ─── Delivery Zone ──────────────────────────────────────────────

  Future<Map<String, dynamic>> checkZone(double lat, double lng) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/check-zone'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'latitude': lat, 'longitude': lng})).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  // ─── App Version ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAppVersion() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/app-version')).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  // ─── Notifications ─────────────────────────────────────────────

  Future<List<dynamic>> getNotifications() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_baseUrl/api/notifications'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  // ─── Settings ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSettings() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/settings')).timeout(const Duration(seconds: 15));
    return _handleResponse(res);
  }

  // ─── Product Suggestions ────────────────────────────────────────

  Future<Map<String, dynamic>> suggestProduct(String name, String reason) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(Uri.parse('$_baseUrl/api/suggest-product'), headers: headers, body: jsonEncode({'product_name': name, 'reason': reason})).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<void> warmUp() async {
    try {
      await http.get(Uri.parse('$_baseUrl/api/app-version')).timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('ApiService.warmUp: request failed: $e');
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
