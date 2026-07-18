part of 'api_service_base.dart';

// ─── Payment & Delivery Fee Methods ────────────────────────────

mixin PaymentApi on ApiServiceBase {
  Future<Map<String, dynamic>> getDeliveryFee(double subtotal) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/delivery-fee'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'subtotal': subtotal}),
    );
    if (res.statusCode != 200) return {'fee': 0, 'message': 'Free delivery'};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
