import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? error;

  LocationResult({required this.latitude, required this.longitude, this.error});
}

class LocationService {
  final ApiService _api = ApiService();

  Future<LocationResult> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult(
        latitude: 0,
        longitude: 0,
        error: 'Location services are disabled',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult(
          latitude: 0,
          longitude: 0,
          error: 'Location permissions are denied',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult(
        latitude: 0,
        longitude: 0,
        error: 'Location permissions are permanently denied',
      );
    }

    try {
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      return LocationResult(
        latitude: 0,
        longitude: 0,
        error: 'Failed to get location: $e',
      );
    }
  }

  Future<void> saveLocationToServer(double latitude, double longitude) async {
    try {
      final addr = await _api.createGpsAddress(latitude, longitude);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gps_address_id', addr['id'] ?? '');
      await prefs.setString('gps_address_line', addr['address_line1'] ?? '');
      await prefs.setString('gps_address_line2', addr['address_line2'] ?? '');
      await prefs.setString('gps_city', addr['city'] ?? '');
      await prefs.setString('gps_landmark', addr['landmark'] ?? '');
      await prefs.setString('gps_latitude', '${addr['latitude'] ?? ''}');
      await prefs.setString('gps_longitude', '${addr['longitude'] ?? ''}');
      await prefs.setString('gps_pincode', addr['pincode'] ?? '');
    } catch (_) {}
  }

  static Future<Map<String, String>> getSavedGpsAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getString('gps_address_id') ?? '',
      'address_line1': prefs.getString('gps_address_line') ?? '',
      'address_line2': prefs.getString('gps_address_line2') ?? '',
      'city': prefs.getString('gps_city') ?? '',
      'landmark': prefs.getString('gps_landmark') ?? '',
      'latitude': prefs.getString('gps_latitude') ?? '',
      'longitude': prefs.getString('gps_longitude') ?? '',
      'pincode': prefs.getString('gps_pincode') ?? '',
    };
  }
}
