part of 'api_service_base.dart';

// ─── Products & Categories (user-facing) ───────────────────────

mixin ProductApi on ApiServiceBase {
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
}
