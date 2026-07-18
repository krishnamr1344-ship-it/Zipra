part of 'api_service_base.dart';

// ─── Offers & Combo Packs Methods ──────────────────────────────

mixin OfferApi on ApiServiceBase {
  Future<List<dynamic>> getOffers() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/offers'));
    if (res.statusCode != 200) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

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
}
