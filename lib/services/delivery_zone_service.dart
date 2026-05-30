import 'dart:convert';
import 'package:http/http.dart' as http;

class DeliveryZoneException implements Exception {
  final String message;
  DeliveryZoneException(this.message);
  @override
  String toString() => message;
}

class DeliveryZoneService {
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://delivery-app-api-16t0.onrender.com',
  );

  Future<ZoneCheckResult> checkLocation(double lat, double lng) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/check-zone'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'lat': lat, 'lng': lng}),
    ).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw DeliveryZoneException('Zone check failed (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final serviceable = data['serviceable'] == true;
    return ZoneCheckResult(serviceable, data['message'] as String?);
  }
}

class ZoneCheckResult {
  final bool serviceable;
  final String? message;
  ZoneCheckResult(this.serviceable, this.message);
}
