import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final _locationService = LocationService();
  final _api = ApiService();
  final _searchCtl = TextEditingController();
  final _mapCtl = MapController();

  LatLng _center = const LatLng(13.05, 80.2125);
  LatLng _selected = const LatLng(13.05, 80.2125);
  bool _loading = true;
  String _addressLine1 = '';
  String _addressLine2 = '';
  String _city = '';
  bool _geocoding = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final loc = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (loc.error == null) {
      final pos = LatLng(loc.latitude, loc.longitude);
      setState(() {
        _center = pos;
        _selected = pos;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _mapCtl.move(pos, 15));
    } else if (mounted) {
      AppSnackbar.show(context, loc.error!, type: SnackbarType.error);
    }
    setState(() => _loading = false);
    _reverseGeocode();
  }

  Future<void> _reverseGeocode() async {
    setState(() => _geocoding = true);
    try {
      final data = await _api.reverseGeocode(_selected.latitude, _selected.longitude);
      if (!mounted) return;
      setState(() {
        _addressLine1 = data['address_line1'] ?? '';
        _addressLine2 = data['address_line2'] ?? '';
        _city = data['city'] ?? '';
      });
    } catch (e) {
        debugPrint("pages.map_picker_page: $e");
      if (mounted) AppSnackbar.show(context, 'Could not fetch address', type: SnackbarType.error);
    }
    if (mounted) setState(() => _geocoding = false);
  }

  void _onMapTap(TapPosition tap, LatLng point) {
    setState(() => _selected = point);
    _reverseGeocode();
  }

  Future<void> _goToCurrentLocation() async {
    final loc = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (loc.error == null) {
      final pos = LatLng(loc.latitude, loc.longitude);
      setState(() {
        _center = pos;
        _selected = pos;
      });
      _mapCtl.move(pos, 15);
      _reverseGeocode();
    } else {
      AppSnackbar.show(context, loc.error ?? 'Could not get location', type: SnackbarType.error);
    }
  }

  Future<void> _confirmLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gps_address_line', _addressLine1);
    await prefs.setString('gps_address_line2', _addressLine2);
    await prefs.setString('gps_city', _city);
    await prefs.setString('gps_latitude', '${_selected.latitude}');
    await prefs.setString('gps_longitude', '${_selected.longitude}');

    final token = await _api.getToken();
    if (token != null) {
      try {
        final addr = await _api.createGpsAddress(_selected.latitude, _selected.longitude);
        await prefs.setString('gps_address_id', addr['id'] ?? '');
        await prefs.setString('gps_pincode', addr['pincode'] ?? '');
        await prefs.setString('gps_address_type', addr['address_type'] ?? '');
        await prefs.setString('gps_house_number', addr['house_number'] ?? '');
        await prefs.setString('gps_floor_number', addr['floor_number'] ?? '');
      } catch (e) {
        debugPrint("pages.map_picker_page: $e");}
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boldText = _addressLine2.isNotEmpty ? _addressLine2 : (_city.isNotEmpty ? _city : '');
    final grayText = _addressLine1;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtl,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.myapp',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selected,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: AppColors.primary, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _searchCtl,
                      decoration: InputDecoration(
                        hintText: 'Search area...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _searchCtl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (q) => _searchPlace(q),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _geocoding
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (boldText.isNotEmpty)
                                            Text(boldText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          if (grayText.isNotEmpty)
                                            Text(grayText, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          if (boldText.isEmpty && grayText.isEmpty)
                                            const Text('Tap on map to set location', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _confirmLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: const Text('Confirm Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withAlpha(60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 220,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'my_location',
                        backgroundColor: Colors.white,
                        onPressed: _goToCurrentLocation,
                        child: const Icon(Icons.my_location, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;
    try {
      final results = await _api.searchPlaces(query);
      if (!mounted || results.isEmpty) return;
      final first = results.first;
      final lat = (first['latitude'] as num?)?.toDouble();
      final lon = (first['longitude'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        setState(() {
          _center = LatLng(lat, lon);
          _selected = LatLng(lat, lon);
        });
        _reverseGeocode();
      }
    } catch (e) {
        debugPrint("pages.map_picker_page: $e");}
  }
}
