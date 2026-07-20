import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AdminApiService {
  static const _baseUrl = 'https://zipra-api-583825347591.asia-south1.run.app';
  static const _timeout = Duration(seconds: 30);

  Future<Map<String, String>> _authHeader() async {
    final token = await ApiService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  Never _handleError(http.Response res) {
    if (res.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
    final msg = jsonDecode(res.body)['detail'] ?? 'Request failed';
    throw ApiException('$msg');
  }

  Future<Map<String, dynamic>> getStats() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/stats'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getProducts() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/products'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/products'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 201) _handleError(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/products/$id'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<void> deleteProduct(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/products/$id'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<List<dynamic>> getCategories() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/categories'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<void> createCategory(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/categories'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 201) _handleError(res);
  }

  Future<void> updateCategory(String id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/categories/$id'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<void> deleteCategory(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/categories/$id'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<List<dynamic>> getOrders() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/orders'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/orders/$orderId/status'), headers: await _authHeader(), body: jsonEncode({'status': status})).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<void> deleteOrder(String orderId) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/orders/$orderId'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<List<dynamic>> getUsers() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/users'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getDeliveryZones() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/delivery-zones'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getComboPacks() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/combo-packs'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createComboPack(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/combo-packs'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 201) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> updateComboPack(String id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/combo-packs/$id'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<void> deleteComboPack(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/combo-packs/$id'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<bool> toggleComboPack(String id) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/combo-packs/$id/toggle'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    final body = jsonDecode(res.body);
    return body['is_enabled'] ?? false;
  }

  Future<List<dynamic>> getOffers() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/offers'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createOffer(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/offers'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 201) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> updateOffer(String id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/offers/$id'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<void> deleteOffer(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/offers/$id'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<void> createDeliveryZone(String name, String geojsonData) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/delivery-zone'), headers: await _authHeader(), body: jsonEncode({
      'zone_name': name,
      'geojson_data': geojsonData,
    })).timeout(_timeout);
    if (res.statusCode != 201) _handleError(res);
  }

  Future<void> deleteDeliveryZone(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/delivery-zones/$id'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<void> updateDeliveryZone(String id, String name, String geojsonData) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/delivery-zones/$id'), headers: await _authHeader(), body: jsonEncode({
      'zone_name': name,
      'geojson_data': geojsonData,
    })).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<Map<String, dynamic>> uploadProductImage(String productId, File file) async {
    final token = await ApiService().getToken();
    final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/admin/products/$productId/upload-image'));
    req.headers['Authorization'] = 'Bearer ${token ?? ''}';
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 201) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getDeliveryFees() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/delivery-fees'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createDeliveryFee(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/delivery-fees'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 201) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> updateDeliveryFee(String id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/delivery-fees/$id'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<void> deleteDeliveryFee(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/delivery-fees/$id'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  // ─── SHOPS ─────────────────────────────────────────────────

  Future<List<dynamic>> getShops() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/shops'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createShopOwner(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/admin/shops'), headers: await _authHeader(), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 201) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<void> toggleShop(String shopId) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/shops/$shopId/toggle'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  // ─── PRODUCT APPROVALS ────────────────────────────────────

  Future<List<dynamic>> getPendingProducts() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/products/pending'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
    return jsonDecode(res.body);
  }

  Future<void> approveProduct(String productId) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/products/$productId/approve'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }

  Future<void> rejectProduct(String productId) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/admin/products/$productId/reject'), headers: await _authHeader()).timeout(_timeout);
    if (res.statusCode != 200) _handleError(res);
  }
}
