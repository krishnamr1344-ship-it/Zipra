import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrl = 'https://zipra-api-583825347591.asia-south1.run.app';
const String _tokenKey = 'shop_token';

String resolveImageUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  return '$_baseUrl$url';
}

class ShopApiService {
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('shop_name');
    await prefs.remove('shop_owner_name');
    await prefs.remove('shop_owner_email');
    await prefs.remove('shop_id');
  }

  Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'data': decoded};
    }
    debugPrint('API Error ${res.statusCode}: ${res.body}');
    final msg = _tryDecodeDetail(res.body) ?? 'Request failed (${res.statusCode})';
    throw ShopApiException(msg);
  }

  List<dynamic> _handleListResponse(http.Response res) {
    if (res.statusCode != 200) {
      debugPrint('API Error ${res.statusCode}: ${res.body}');
      throw ShopApiException(_tryDecodeDetail(res.body) ?? 'Request failed (${res.statusCode})');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded;
    return [];
  }

  String? _tryDecodeDetail(String body) {
    try {
      final map = jsonDecode(body);
      if (map is Map) return map['detail'] as String?;
    } catch (_) {}
    return null;
  }

  // ─── AUTH ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> shopLogin(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/shop/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _handleResponse(res);
    await _saveToken(body['token']?.toString() ?? '');
    final user = body['user'] as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_owner_name', user['name'] ?? '');
    await prefs.setString('shop_owner_email', user['email'] ?? '');
    final shop = body['shop'] as Map<String, dynamic>?;
    await prefs.setString('shop_id', shop?['id'] ?? '');
    return body;
  }

  Future<void> logout() async {
    await clearToken();
  }

  // ─── SHOP PROFILE ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getShopProfile() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shop/profile'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> updateShopProfile(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/shop/profile'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(res);
  }

  Future<String> toggleOpen() async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/shop/toggle-open'),
      headers: await _headers(),
    );
    final body = _handleResponse(res);
    return body['is_open'] == true ? 'Shop is now open' : 'Shop is now closed';
  }

  // ─── PRODUCTS ─────────────────────────────────────────────────

  Future<List<dynamic>> getProducts({String? status}) async {
    final uri = status != null
        ? Uri.parse('$_baseUrl/api/shop/products?status_filter=$status')
        : Uri.parse('$_baseUrl/api/shop/products');
    final res = await http.get(uri, headers: await _headers());
    return _handleListResponse(res);
  }

  Future<List<dynamic>> getPendingProducts() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shop/products/pending'),
      headers: await _headers(),
    );
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/shop/products'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> updateProduct(String productId, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/shop/products/$productId'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(res);
  }

  Future<String> deleteProduct(String productId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/shop/products/$productId'),
      headers: await _headers(),
    );
    final body = _handleResponse(res);
    return body['message']?.toString() ?? 'Done';
  }

  Future<Map<String, dynamic>> updateStock(String productId, int stock) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/shop/products/$productId/stock'),
      headers: await _headers(),
      body: jsonEncode({'stock': stock}),
    );
    return _handleResponse(res);
  }

  // ─── ORDERS ───────────────────────────────────────────────────

  Future<List<dynamic>> getOrders({String? status}) async {
    final uri = status != null
        ? Uri.parse('$_baseUrl/api/shop/orders?status_filter=$status')
        : Uri.parse('$_baseUrl/api/shop/orders');
    final res = await http.get(uri, headers: await _headers());
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shop/orders/$orderId'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/shop/orders/$orderId/accept'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> startPacking(String orderId) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/shop/orders/$orderId/packing'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> markReady(String orderId) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/shop/orders/$orderId/ready'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> markDelivered(String orderId) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/shop/orders/$orderId/deliver'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId, {String? reason}) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/shop/orders/$orderId/cancel'),
      headers: await _headers(),
      body: jsonEncode({'cancellation_reason': reason}),
    );
    return _handleResponse(res);
  }

  // ─── EARNINGS ─────────────────────────────────────────────────

  Future<List<dynamic>> getEarnings({String? status}) async {
    final uri = status != null
        ? Uri.parse('$_baseUrl/api/shop/earnings?status_filter=$status')
        : Uri.parse('$_baseUrl/api/shop/earnings');
    final res = await http.get(uri, headers: await _headers());
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> getEarningsSummary() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shop/earnings/summary'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  // ─── CATEGORIES ───────────────────────────────────────────────

  Future<List<dynamic>> getCategories() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/categories'),
      headers: await _headers(),
    );
    return _handleListResponse(res);
  }

  // ─── IMAGE UPLOAD ─────────────────────────────────────────────

  Future<String> uploadProductImage(String productId, String filePath) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/shop/products/$productId/upload-image'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['image_url']?.toString() ?? '';
    }
    throw ShopApiException('Image upload failed');
  }

  Future<String> uploadShopLogo(String filePath) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/shop/upload-logo'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['logo_url']?.toString() ?? '';
    }
    throw ShopApiException('Logo upload failed');
  }

  Future<String> uploadShopBanner(String filePath) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/shop/upload-banner'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['banner_url']?.toString() ?? '';
    }
    throw ShopApiException('Banner upload failed');
  }
}

class ShopApiException implements Exception {
  final String message;
  ShopApiException(this.message);
  @override
  String toString() => message;
}
