part of 'api_service_base.dart';

// ─── Order Methods ─────────────────────────────────────────────

mixin OrderApi on ApiServiceBase {
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
}
