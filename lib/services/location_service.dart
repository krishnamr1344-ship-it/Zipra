import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'permission_service.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? error;

  LocationResult({required this.latitude, required this.longitude, this.error});
}

class LocationService {
  final ApiService _api = ApiService();
  final PermissionService _permissionService = PermissionService();

  Future<LocationResult> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult(
        latitude: 0,
        longitude: 0,
        error: 'Location services are disabled',
      );
    }

    PermissionStatus status = await _permissionService.ensure(AppPermission.location);
    if (!_isGranted(status)) {
      return LocationResult(
        latitude: 0,
        longitude: 0,
        error: status == PermissionStatus.permanentlyDenied
            ? 'Location permissions are permanently denied'
            : 'Location permissions are denied',
      );
    }

    try {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        return LocationResult(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (e) {
        debugPrint("services.location_service: $e");
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return LocationResult(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (e) {
      return LocationResult(
        latitude: 0,
        longitude: 0,
        error: 'Failed to get location: $e',
      );
    }
  }

  bool _isGranted(PermissionStatus status) {
    return status == PermissionStatus.granted;
  }

  Future<void> saveLocationToServer(double latitude, double longitude, {String? landmark, String? addressType, String? houseNumber, String? floorNumber}) async {
    try {
      final addr = await _api.createGpsAddress(latitude, longitude, landmark: landmark, addressType: addressType, houseNumber: houseNumber, floorNumber: floorNumber);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gps_address_id', addr['id'] ?? '');
      await prefs.setString('gps_address_line', addr['address_line1'] ?? '');
      await prefs.setString('gps_address_line2', addr['address_line2'] ?? '');
      await prefs.setString('gps_city', addr['city'] ?? '');
      await prefs.setString('gps_landmark', addr['landmark'] ?? '');
      await prefs.setString('gps_latitude', '${addr['latitude'] ?? ''}');
      await prefs.setString('gps_longitude', '${addr['longitude'] ?? ''}');
      await prefs.setString('gps_pincode', addr['pincode'] ?? '');
      await prefs.setString('gps_address_type', addr['address_type'] ?? '');
      await prefs.setString('gps_house_number', addr['house_number'] ?? '');
      await prefs.setString('gps_floor_number', addr['floor_number'] ?? '');
    } catch (e) {
      debugPrint("services.location_service: $e");
      rethrow;
    }
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
      'address_type': prefs.getString('gps_address_type') ?? '',
      'house_number': prefs.getString('gps_house_number') ?? '',
      'floor_number': prefs.getString('gps_floor_number') ?? '',
    };
  }
}
