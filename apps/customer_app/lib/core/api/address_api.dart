part of 'api_service_base.dart';

// ─── Address & Place Search Methods ────────────────────────────

mixin AddressApi on ApiServiceBase {
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
}
