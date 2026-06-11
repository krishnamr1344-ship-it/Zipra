import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AdminApiService {
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://delivery-app-api-16t0.onrender.com',
  );
  static const _timeout = Duration(seconds: 60);

  Future<Map<String, String>> _authHeader() async {
    final token = await ApiService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  dynamic _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (e) {
      throw ApiException('Invalid server response');
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/stats'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Failed to load stats');
    return _decodeJson(res.body);
  }

  Future<List<dynamic>> getProducts() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/products'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Failed to load products');
    return _decodeJson(res.body);
  }

  Future<void> createProduct(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/products'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 201) throw ApiException(_decodeJson(res.body)['detail'] ?? 'Failed to create product');
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/products/$id'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException(_decodeJson(res.body)['detail'] ?? 'Failed to update product');
  }

  Future<bool> toggleProduct(String id) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/products/$id/toggle'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Failed to toggle product');
    final body = _decodeJson(res.body);
    return body['is_enabled'] ?? false;
  }

  Future<void> deleteProduct(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/products/$id'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) {
      final msg = _decodeJson(res.body)['detail'] ?? 'Failed to delete product';
      throw ApiException('$msg');
    }
  }

  Future<List<dynamic>> getCategories() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/categories'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Failed to load categories');
    return _decodeJson(res.body);
  }

  Future<void> createCategory(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/categories'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 201) throw ApiException(_decodeJson(res.body)['detail'] ?? 'Failed to create category');
  }

  Future<void> updateCategory(String id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/categories/$id'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException(_decodeJson(res.body)['detail'] ?? 'Failed to update category');
  }

  Future<void> deleteCategory(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/categories/$id'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) {
      final msg = _decodeJson(res.body)['detail'] ?? 'Failed to delete category';
      throw ApiException('$msg');
    }
  }

  Future<List<dynamic>> getOrders() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/orders'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Failed to load orders');
    return _decodeJson(res.body);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/orders/$orderId/status'), headers: await _authHeader(), body: jsonEncode({'status': status})).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException(_decodeJson(res.body)['detail'] ?? 'Failed to update order');
  }

  Future<void> deleteOrder(String orderId) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/orders/$orderId'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) {
      final msg = _decodeJson(res.body)['detail'] ?? 'Failed to delete order';
      throw ApiException('$msg');
    }
  }

  Future<List<dynamic>> getUsers() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/users'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Failed to load users');
    return _decodeJson(res.body);
  }

  Future<List<dynamic>> getDeliveryZones() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/delivery-zones'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Failed to load delivery zones');
    return _decodeJson(res.body);
  }

  // ─── Combo Packs ──────────────────────────────────────────────────

  Future<List<dynamic>> getComboPacks() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/combo-packs'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Failed to load combo packs');
    return _decodeJson(res.body);
  }

  Future<Map<String, dynamic>> createComboPack(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/combo-packs'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 201) throw ApiException(_decodeJson(res.body)['detail'] ?? 'Failed to create pack');
    return _decodeJson(res.body);
  }

  Future<Map<String, dynamic>> updateComboPack(String id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/combo-packs/$id'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException(_decodeJson(res.body)['detail'] ?? 'Failed to update pack');
    return _decodeJson(res.body);
  }

  Future<void> deleteComboPack(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/combo-packs/$id'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) {
      final msg = _decodeJson(res.body)['detail'] ?? 'Failed to delete pack';
      throw ApiException('$msg');
    }
  }

  Future<bool> toggleComboPack(String id) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/combo-packs/$id/toggle'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Failed to toggle pack');
    final body = _decodeJson(res.body);
    return body['is_enabled'] ?? false;
  }

  Future<void> createDeliveryZone(String name, String geojsonData) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/delivery-zone'), headers: await _authHeader(), body: jsonEncode({
      'zone_name': name,
      'geojson_data': geojsonData,
    })).timeout(_timeout);
    if (res.statusCode != 201) {
      final msg = _decodeJson(res.body)['detail'] ?? 'Failed to create zone';
      throw ApiException('$msg');
    }
  }

  Future<void> updateDeliveryZone(String id, String name, String geojsonData) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/delivery-zones/$id'), headers: await _authHeader(), body: jsonEncode({
      'zone_name': name,
      'geojson_data': geojsonData,
    })).timeout(_timeout);
    if (res.statusCode != 200) {
      final msg = _decodeJson(res.body)['detail'] ?? 'Failed to update zone';
      throw ApiException('$msg');
    }
  }

  Future<void> deleteDeliveryZone(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/delivery-zones/$id'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) {
      final msg = _decodeJson(res.body)['detail'] ?? 'Failed to delete zone';
      throw ApiException('$msg');
    }
  }
}
