import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const _baseUrl = 'https://delivery-app-api-16t0.onrender.com';
  static const _tokenKey = 'auth_token';
  static const _userNameKey = 'user_name';
  static const _userEmailKey = 'user_email';
  static const _userPhoneKey = 'user_phone';
  static const _userRoleKey = 'user_role';

  final _secureStorage = const FlutterSecureStorage();

  // ─── Token Management ──────────────────────────────────────────

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<void> _saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<void> _clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userNameKey);
    await _secureStorage.delete(key: _userEmailKey);
    await _secureStorage.delete(key: _userPhoneKey);
    await _secureStorage.delete(key: _userRoleKey);
  }

  // ─── API Calls ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
      throw ApiException('Invalid response (${res.statusCode})');
    }
    if (kDebugMode) debugPrint('API Error ${res.statusCode}: ${res.body}');
    final msg = _tryDecodeDetail(res.body) ?? 'Request failed (${res.statusCode})';
    throw ApiException(msg);
  }

  List<dynamic> _handleListResponse(http.Response res) {
    if (res.statusCode != 200) {
      if (kDebugMode) debugPrint('API Error ${res.statusCode}: ${res.body}');
      throw ApiException(_tryDecodeDetail(res.body) ?? 'Request failed (${res.statusCode})');
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is List<dynamic>) return decoded;
    } catch (_) {}
    throw ApiException('Invalid response (${res.statusCode})');
  }

  String? _tryDecodeDetail(String body) {
    try {
      final map = jsonDecode(body);
      if (map is Map) return map['detail'] as String?;
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> register(String name, String email, String phone, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'phone': phone, 'password': password}),
    ).timeout(const Duration(seconds: 60));
    final body = await _handleResponse(res);
    await _saveToken(body['token']);
    await _saveUserLocally(body['user']['name'], body['user']['email'], phone, body['user']['role'] ?? 'user');
    return body;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 60));
    final body = await _handleResponse(res);
    await _saveToken(body['token']);
    await _saveUserLocally(body['user']['name'], body['user']['email'], '', body['user']['role'] ?? 'user');
    return body;
  }

  Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}),
        ).timeout(const Duration(seconds: 60));
      } catch (_) {}
    }
    await _clearToken();
  }

  // ─── Local User Storage (fallback) ─────────────────────────────

  Future<Map<String, dynamic>> getSavedUser() async {
    return {
      'name': await _secureStorage.read(key: _userNameKey) ?? 'User',
      'email': await _secureStorage.read(key: _userEmailKey) ?? '',
      'phone': await _secureStorage.read(key: _userPhoneKey) ?? '',
      'role': await _secureStorage.read(key: _userRoleKey) ?? 'user',
    };
  }

  Future<void> _saveUserLocally(String name, String email, String phone, [String role = 'user']) async {
    await _secureStorage.write(key: _userNameKey, value: name);
    await _secureStorage.write(key: _userEmailKey, value: email);
    await _secureStorage.write(key: _userPhoneKey, value: phone);
    await _secureStorage.write(key: _userRoleKey, value: role);
  }

  Future<Map<String, dynamic>> updateProfile(String name, String email, {String phone = ''}) async {
    final headers = await _authHeaders(required: true);
    final res = await http.put(
      Uri.parse('$_baseUrl/api/auth/profile'),
      headers: headers,
      body: jsonEncode({'name': name, 'email': email, 'phone': phone}),
    ).timeout(const Duration(seconds: 60));
    final body = await _handleResponse(res);
    await _saveUserLocally(body['user']['name'], body['user']['email'], phone, body['user']['role'] ?? 'user');
    return body;
  }

  Future<void> saveUser(String name, String email, {String phone = ''}) async {
    await _saveUserLocally(name, email, phone);
  }

  Future<void> clearToken() async {
    await _clearToken();
  }

  Future<Map<String, String>> _authHeaders({bool required = false}) async {
    final token = await getToken();
    if (token == null && required) throw ApiException('Login required');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Addresses ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> createGpsAddress(double latitude, double longitude, {String? landmark, String? addressType, String? houseNumber, String? floorNumber}) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) {
      return {'id': '', 'address_line1': '', 'address_line2': '', 'city': '', 'latitude': latitude.toString(), 'longitude': longitude.toString()};
    }
    final bodyMap = <String, dynamic>{'latitude': latitude, 'longitude': longitude};
    if (landmark != null && landmark.isNotEmpty) bodyMap['landmark'] = landmark;
    if (addressType != null && addressType.isNotEmpty) bodyMap['address_type'] = addressType;
    if (houseNumber != null && houseNumber.isNotEmpty) bodyMap['house_number'] = houseNumber;
    if (floorNumber != null && floorNumber.isNotEmpty) bodyMap['floor_number'] = floorNumber;
    final res = await http.post(Uri.parse('$_baseUrl/api/addresses/auto'), headers: headers, body: jsonEncode(bodyMap)).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) {
      return {'id': '', 'address_line1': data['address_line1'] ?? ''};
    }
    final res = await http.post(Uri.parse('$_baseUrl/api/addresses'), headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<List<dynamic>> getAddresses() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/addresses'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<void> deleteAddress(String addressId) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) throw ApiException('Login required');
    final res = await http.delete(Uri.parse('$_baseUrl/api/addresses/$addressId'), headers: headers).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      if (kDebugMode) debugPrint('API Error ${res.statusCode}: ${res.body}');
      throw ApiException(_tryDecodeDetail(res.body) ?? 'Failed to delete address');
    }
  }

  Future<Map<String, dynamic>> updateAddress(String addressId, Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) throw ApiException('Login required');
    final res = await http.put(Uri.parse('$_baseUrl/api/addresses/$addressId'), headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  /// Map ward/division numbers to locality names for Chennai.
  /// Used when Nominatim only returns zone-based admin names.
  /// Source: Chennai Ward GeoJSON + manual research.
  /// Zone X (Kodambakkam) wards that are actually part of Vadapalani locality.
  static const _wardToLocality = <String, String>{
    '0': 'St. Thomas Mount Cantonment',
    '1': 'Ennore',
    '2': 'Kathivakkam',
    '3': 'Ernavur',
    '4': 'Ernavur',
    '5': 'Ernavur',
    '6': 'Kargil Nagar',
    '7': 'Tiruvottiyur',
    '8': 'Tiruvottiyur',
    '9': 'Tiruvottiyur',
    '10': 'Tiruvottiyur',
    '11': 'Tiruvottiyur',
    '12': 'Tiruvottiyur',
    '13': 'Tiruvottiyur',
    '14': 'Tiruvottiyur',
    '15': 'Edayanchavadi',
    '16': 'Dwaraka Nagar',
    '17': 'Mathur',
    '18': 'Manali',
    '19': 'Mathur',
    '20': 'Manali',
    '21': 'Manali',
    '22': 'Puzhal',
    '23': 'Puzhal',
    '24': 'Surapattu',
    '25': 'Kathirvedu',
    '26': 'Kathirvedu',
    '27': 'Madhavaram Milk Colony',
    '28': 'Madhavaram Milk Colony',
    '29': 'Manali',
    '30': 'Madhavaram',
    '31': 'Madhavaram',
    '32': 'Kolathur',
    '33': 'Madhavaram',
    '34': 'Chinna Kodungaiyur',
    '35': 'Kodungaiyur',
    '36': 'Vyasarpadi',
    '37': 'Vyasarpadi',
    '38': 'New Washermanpet',
    '39': 'New Washermanpet',
    '40': 'New Washermanpet',
    '41': 'Korukkupet',
    '42': 'Korukkupet',
    '43': 'Tondiarpet',
    '44': 'Perambur',
    '45': 'Vyasarpadi',
    '46': 'Thiru Vi Ka Nagar',
    '47': 'Washermanpet',
    '48': 'Washermanpet',
    '49': 'Royapuram',
    '50': 'Royapuram',
    '51': 'Washermanpet',
    '52': 'Royapuram',
    '53': 'Basin Bridge',
    '54': 'Vallalar Nagar',
    '55': 'Vallalar Nagar',
    '56': 'Vallalar Nagar',
    '57': 'George Town',
    '58': 'Vepery',
    '59': 'Island Grounds',
    '60': 'George Town',
    '61': 'Egmore',
    '62': 'Chintadripet',
    '63': 'Triplicane',
    '64': 'Periyar Nagar',
    '65': 'Villivakkam',
    '66': 'Periyar Nagar',
    '67': 'Periyar Nagar',
    '68': 'Perambur',
    '69': 'Perambur',
    '70': 'Perambur',
    '71': 'Otteri',
    '72': 'Pulianthope',
    '73': 'Otteri',
    '74': 'Otteri',
    '75': 'Otteri',
    '76': 'Choolai',
    '77': 'Pulianthope',
    '78': 'Choolai',
    '79': 'Venkatapuram',
    '80': 'Venkatapuram',
    '81': 'Ambattur',
    '82': 'Venkatapuram',
    '83': 'Korattur',
    '84': 'Korattur',
    '85': 'Ambattur',
    '86': 'Nolambur',
    '87': 'Anna Nagar West',
    '88': 'Anna Nagar West',
    '89': 'Mogappair East',
    '90': 'Anna Nagar West',
    '91': 'Nolambur',
    '92': 'Mogappair East',
    '93': 'Mogappair East',
    '94': 'Villivakkam',
    '95': 'Villivakkam',
    '96': 'ICF Colony',
    '97': 'Ayanavaram',
    '98': 'Ayanavaram',
    '99': 'Anna Nagar West',
    '100': 'Anna Nagar',
    '101': 'Anna Nagar',
    '102': 'Shenoy Nagar',
    '103': 'Kilpauk',
    '104': 'Purasawalkam',
    '105': 'Arumbakkam',
    '106': 'Aminjikarai',
    '107': 'Chetpet',
    '108': 'Aminjikarai',
    '109': 'Aminjikarai',
    '110': 'Nungambakkam',
    '111': 'Thousand Lights',
    '112': 'Kodambakkam',
    '113': 'Nungambakkam',
    '114': 'Chepauk',
    '115': 'Royapettah',
    '116': 'Triplicane',
    '117': 'Teynampet',
    '118': 'Teynampet',
    '119': 'Gopalapuram',
    '120': 'Triplicane',
    '121': 'Mylapore',
    '122': 'Nandanam',
    '123': 'Abhiramapuram',
    '124': 'Mylapore',
    '125': 'Santhome',
    '126': 'Mylapore',
    '127': 'Saligramam',
    '128': 'Virugambakkam',
    '129': 'Vadapalani',
    '130': 'Vadapalani',
    '131': 'K.K.Nagar',
    '132': 'Ashok Nagar',
    '133': 'Ashok Nagar',
    '134': 'Kodambakkam',
    '135': 'West Mambalam',
    '136': 'West Mambalam',
    '137': 'K.K.Nagar',
    '138': 'Jafferkhanpet',
    '139': 'Ekkattuthangal',
    '140': 'Thiyagaraya Nagar',
    '141': 'Thiyagaraya Nagar',
    '142': 'Saidapet',
    '143': 'Nolambur',
    '144': 'Nerkundram',
    '145': 'Nerkundram',
    '146': 'Alapakkam',
    '147': 'Alapakkam',
    '148': 'Virugambakkam',
    '149': 'Valasaravakkam',
    '150': 'Karampakkam',
    '151': 'Porur',
    '152': 'Valasaravakkam',
    '153': 'Porur',
    '154': 'Ramapuram',
    '155': 'Nesapakkam',
    '156': 'Porur',
    '157': 'Manapakkam',
    '158': 'Nandambakkam',
    '159': 'Alandur',
    '160': 'St. Thomas Mount Cantonment',
    '161': 'St. Thomas Mount Cantonment',
    '162': 'St. Thomas Mount Cantonment',
    '163': 'St. Thomas Mount Cantonment',
    '164': 'St. Thomas Mount Cantonment',
    '165': 'Alandur',
    '166': 'Alandur',
    '167': 'Alandur',
    '168': 'Perungudi',
    '169': 'Perungudi',
    '170': 'SIDCO Industrial Estate',
    '171': 'Little Mount',
    '172': 'Kotturpuram',
    '173': 'MRC Nagar',
    '174': 'Guindy',
    '175': 'Adyar',
    '176': 'Adyar',
    '177': 'Adyar',
    '178': 'Adyar',
    '179': 'Adyar',
    '180': 'Adyar',
    '181': 'Adyar',
    '182': 'Adyar',
    '183': 'Perungudi',
    '184': 'Perungudi',
    '185': 'Perungudi',
    '186': 'Perungudi',
    '187': 'Perungudi',
    '188': 'Perungudi',
    '189': 'Perungudi',
    '190': 'Perungudi',
    '191': 'Perungudi',
    '192': 'Sozhinganallur',
    '193': 'Sozhinganallur',
    '194': 'Sozhinganallur',
    '195': 'Sozhinganallur',
    '196': 'Sozhinganallur',
    '197': 'Sozhinganallur',
    '198': 'Sozhinganallur',
    '199': 'Sozhinganallur',
    '200': 'Sozhinganallur',
  };

  /// Extract locality name from Nominatim address.
  ///
  /// Strategy:
  /// 1. If primary admin fields contain "Zone N" (zone-based name), check
  ///    locality-specific fields (railway, station, metro, etc.).
  ///    Only use them if the zone-stripped primary is NOT a substring of the
  ///    specific value (avoids picking POI names like "Anna Nagar Tower Exit"
  ///    over the correct "Anna Nagar").
  /// 2. If no suitable specific field found, try to extract a ward/division
  ///    number from the neighbourhood field and look it up in [_wardToLocality].
  /// 3. Fall back to zone-stripped primary name.
  String _extractArea(Map<String, dynamic> addr) {
    final zoneRe = RegExp(r'\s*Zone\s+\d+\s*', caseSensitive: false);

    String pick(Iterable<String> keys) {
      for (final key in keys) {
        final val = addr[key] as String?;
        if (val != null && val.isNotEmpty) return val;
      }
      return '';
    }

    final primary = pick(['suburb', 'neighbourhood', 'city_district', 'city']);

    if (primary.toLowerCase().contains('zone')) {
      final strippedPrimary = primary.replaceAll(zoneRe, '').trim().toLowerCase();

      // Try locality-specific fields (railway, station, metro, locality, hamlet)
      for (final key in ['railway', 'station', 'metro', 'locality', 'hamlet']) {
        final val = addr[key] as String?;
        if (val != null &&
            val.isNotEmpty &&
            !val.toLowerCase().contains('zone')) {
          // Skip if the specific value is just a POI named after the primary area
          // e.g. railway="Anna Nagar Tower Exit" while zone-stripped="Anna Nagar"
          if (strippedPrimary.isEmpty ||
              !val.toLowerCase().contains(strippedPrimary)) {
            return val.replaceAll(zoneRe, '').trim();
          }
        }
      }

      // Try ward/division number mapping from neighbourhood field
      final neighbourhood = (addr['neighbourhood'] as String? ?? '');
      final wardMatch =
          RegExp(r'(?:Division|Ward)\s*(\d+)', caseSensitive: false)
              .firstMatch(neighbourhood);
      if (wardMatch != null) {
        final wardNo = wardMatch.group(1);
        if (wardNo != null && _wardToLocality.containsKey(wardNo)) {
          return _wardToLocality[wardNo]!;
        }
      }
    }

    return primary.replaceAll(zoneRe, '').trim();
  }

  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    try {
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1'),
        headers: {'User-Agent': 'DeliveryApp/1.0'},
      ).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return {};
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>? ?? {};
      final road = (addr['road'] as String?) ?? '';
      final house = (addr['house_number'] as String?) ?? '';
      final parts = <String>[];
      if (road.isNotEmpty) parts.add(road);
      if (house.isNotEmpty) parts.add(house);
      final area = _extractArea(addr);
      var cityRaw = (addr['city'] as String?) ?? (addr['town'] as String?) ?? (addr['village'] as String?) ?? (addr['county'] as String?) ?? '';
      cityRaw = cityRaw.replaceAll(RegExp(r'\s+(Corporation|Municipal|Municipality|Municipal\s+Corporation)\s*$'), '').trim();
      return {
        'display_name': data['display_name'] as String? ?? '',
        'address_line1': parts.isNotEmpty ? parts.join(', ') : (data['display_name'] as String? ?? ''),
        'address_line2': area.isNotEmpty && cityRaw.isNotEmpty ? '$area, $cityRaw' : (area.isNotEmpty ? area : ''),
        'city': cityRaw,
        'state': addr['state'] as String? ?? '',
        'pincode': addr['postcode'] as String? ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<dynamic>> searchPlaces(String query) async {
    try {
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(query)}&format=json&limit=10&addressdetails=1'),
        headers: {'User-Agent': 'DeliveryApp/1.0'},
      ).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((item) {
        final addr = (item['address'] as Map<String, dynamic>?) ?? {};
        return {
          'display_name': item['display_name'] as String? ?? '',
          'latitude': (item['lat'] as num?)?.toDouble() ?? 0.0,
          'longitude': (item['lon'] as num?)?.toDouble() ?? 0.0,
          'address_line1': [addr['road'], addr['house_number']].whereType<String>().where((s) => s.isNotEmpty).join(', '),
          'address_line2': _extractArea(addr),
          'city': (addr['city'] as String?) ?? (addr['town'] as String?) ?? (addr['village'] as String?) ?? (addr['county'] as String?) ?? '',
          'state': addr['state'] as String? ?? '',
          'pincode': addr['postcode'] as String? ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Products & Categories (user-facing) ───────────────────────

  Future<List<dynamic>> getCategories() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_baseUrl/api/categories'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<List<dynamic>> getProducts() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$_baseUrl/api/products'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> createOrder(List<Map<String, dynamic>> items, String paymentMethod, {String? addressId}) async {
    final headers = await _authHeaders(required: true);
    final bodyMap = <String, dynamic>{
      'items': items,
      'payment_method': paymentMethod,
    };
    if (addressId != null) bodyMap['address_id'] = addressId;
    final res = await http.post(Uri.parse('$_baseUrl/api/orders/direct'), headers: headers, body: jsonEncode(bodyMap)).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<List<dynamic>> getOrders() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/orders'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  // ─── Combo Packs ──────────────────────────────────────────────────

  Future<List<dynamic>> getComboPacks() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/combo-packs')).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is List<dynamic>) return decoded;
    } catch (_) {}
    return [];
  }

  // ─── Forgot Password ────────────────────────────────────────────

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'new_password': newPassword}),
    ).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  // ─── Cart ────────────────────────────────────────────────────────

  Future<List<dynamic>> getCart() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/cart'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> addToCart(String productId, {int quantity = 1}) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(
      Uri.parse('$_baseUrl/api/cart'),
      headers: headers,
      body: jsonEncode({'product_id': productId, 'quantity': quantity}),
    ).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<void> updateCartItem(String itemId, int quantity) async {
    final headers = await _authHeaders(required: true);
    final res = await http.put(
      Uri.parse('$_baseUrl/api/cart/$itemId'),
      headers: headers,
      body: jsonEncode({'quantity': quantity}),
    ).timeout(const Duration(seconds: 60));
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw ApiException('Failed to update cart');
  }

  Future<void> removeCartItem(String itemId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.delete(Uri.parse('$_baseUrl/api/cart/$itemId'), headers: headers).timeout(const Duration(seconds: 60));
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw ApiException('Failed to remove cart item');
  }

  Future<void> clearCart() async {
    final headers = await _authHeaders(required: true);
    await http.delete(Uri.parse('$_baseUrl/api/cart'), headers: headers).timeout(const Duration(seconds: 60));
  }

  // ─── Wishlist ────────────────────────────────────────────────────

  Future<List<dynamic>> getWishlist() async {
    final headers = await _authHeaders();
    if (headers['Authorization'] == null) return [];
    final res = await http.get(Uri.parse('$_baseUrl/api/wishlist'), headers: headers).timeout(const Duration(seconds: 60));
    return _handleListResponse(res);
  }

  Future<Map<String, dynamic>> addToWishlist(String productId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(
      Uri.parse('$_baseUrl/api/wishlist'),
      headers: headers,
      body: jsonEncode({'product_id': productId}),
    ).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<void> removeFromWishlist(String productId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.delete(Uri.parse('$_baseUrl/api/wishlist/$productId'), headers: headers).timeout(const Duration(seconds: 60));
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw ApiException('Failed to remove from wishlist');
  }

  // ─── Suggest Product ─────────────────────────────────────────────

  Future<Map<String, dynamic>> suggestProduct(String productName, String reason) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/suggest-product'),
      headers: headers,
      body: jsonEncode({'product_name': productName, 'reason': reason}),
    ).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> addPackToCart(String packId) async {
    final headers = await _authHeaders(required: true);
    final res = await http.post(
      Uri.parse('$_baseUrl/api/combo-packs/add-to-cart'),
      headers: headers,
      body: jsonEncode({'pack_id': packId}),
    ).timeout(const Duration(seconds: 60));
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> getAppVersion() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/app-version'),
    ).timeout(const Duration(seconds: 15));
    return _handleResponse(res);
  }

  Future<void> warmUp() async {
    try {
      await http.get(
        Uri.parse('$_baseUrl/api/app-version'),
      ).timeout(const Duration(seconds: 20));
    } catch (_) {}
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
