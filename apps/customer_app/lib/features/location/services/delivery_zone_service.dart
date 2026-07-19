import 'dart:convert';
import 'package:http/http.dart' as http;

class DeliveryZoneService {
  static const _baseUrl = 'https://zipra-api-txlyzg2aeq-el.a.run.app';

  Future<ZoneCheckResult> checkLocation(double lat, double lng) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/check-zone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lat': lat, 'lng': lng}),
      );
      if (res.statusCode != 200) {
        return ZoneCheckResult(false, 'Unable to verify delivery area');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final serviceable = data['serviceable'] == true;
      return ZoneCheckResult(serviceable, data['message'] as String?);
    } catch (_) {
      return ZoneCheckResult(false, 'Unable to verify delivery area');
    }
  }
}

class ZoneCheckResult {
  final bool serviceable;
  final String? message;
  ZoneCheckResult(this.serviceable, this.message);
}
