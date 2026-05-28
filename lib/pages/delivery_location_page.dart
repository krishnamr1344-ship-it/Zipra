import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import 'login_page.dart';

class DeliveryLocationPage extends StatefulWidget {
  const DeliveryLocationPage({super.key});

  @override
  State<DeliveryLocationPage> createState() => _DeliveryLocationPageState();
}

class _DeliveryLocationPageState extends State<DeliveryLocationPage> {
  final _api = ApiService();
  final _locationService = LocationService();

  final _line1Ctl = TextEditingController();
  final _line2Ctl = TextEditingController();
  final _landmarkCtl = TextEditingController();
  final _cityCtl = TextEditingController();
  final _pincodeCtl = TextEditingController();

  String _gpsAddressId = '';
  double _latitude = 0;
  double _longitude = 0;
  String _locationArea = 'Fetching location...';
  String _locationDetail = '';
  bool _loadingGps = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    setState(() => _loadingGps = true);
    final saved = await LocationService.getSavedGpsAddress();
    if (saved['address_line1']!.isNotEmpty) {
      final line1 = saved['address_line1']!;
      final line2 = saved['address_line2']!;
      final city = saved['city']!;
      _gpsAddressId = saved['id']!;
      _locationArea = line2.isNotEmpty ? line2 : city.isNotEmpty ? city : 'Your Area';
      _locationDetail = line1;
      _line1Ctl.text = line1;
      _line2Ctl.text = line2;
      _cityCtl.text = city;
      _landmarkCtl.text = saved['landmark']!;
      _pincodeCtl.text = saved['pincode']!;
      _latitude = double.tryParse(saved['latitude']!) ?? 0;
      _longitude = double.tryParse(saved['longitude']!) ?? 0;
    }
    setState(() => _loadingGps = false);
  }

  Future<void> _refreshGps() async {
    setState(() => _loadingGps = true);
    final loc = await _locationService.getCurrentLocation();
    if (loc.error != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.error ?? 'Failed')));
      setState(() => _loadingGps = false);
      return;
    }
    _latitude = loc.latitude;
    _longitude = loc.longitude;
    try {
      final addr = await _api.createGpsAddress(loc.latitude, loc.longitude);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gps_address_id', addr['id'] ?? '');
      await prefs.setString('gps_address_line', addr['address_line1'] ?? '');
      await prefs.setString('gps_address_line2', addr['address_line2'] ?? '');
      await prefs.setString('gps_city', addr['city'] ?? '');
      await prefs.setString('gps_landmark', addr['landmark'] ?? '');
      await prefs.setString('gps_latitude', '${addr['latitude'] ?? ''}');
      await prefs.setString('gps_longitude', '${addr['longitude'] ?? ''}');
      await prefs.setString('gps_pincode', addr['pincode'] ?? '');
      if (!mounted) return;
      await _loadSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPS failed: $e')));
      setState(() => _loadingGps = false);
    }
  }

  Future<Map<String, dynamic>?> confirmAndSave() async {
    if (_line1Ctl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Street address is required'), behavior: SnackBarBehavior.floating));
      return null;
    }
    if (_cityCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('City is required'), behavior: SnackBarBehavior.floating));
      return null;
    }
    if (_pincodeCtl.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valid pincode is required'), behavior: SnackBarBehavior.floating));
      return null;
    }
    if (_gpsAddressId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please refresh your GPS location first'), behavior: SnackBarBehavior.floating));
      return null;
    }
    try {
      final token = await _api.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session expired. Please login again.'), behavior: SnackBarBehavior.floating));
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
        }
        return null;
      }
      final addr = await _api.updateAddress(_gpsAddressId, {
        'address_line1': _line1Ctl.text.trim(),
        'address_line2': _line2Ctl.text.trim(),
        'city': _cityCtl.text.trim(),
        'pincode': _pincodeCtl.text.trim(),
        'landmark': _landmarkCtl.text.trim(),
      });
      return addr;
    } catch (e) {
      final msg = e.toString();
      if (msg.toLowerCase().contains('token') || msg.toLowerCase().contains('unauthorized') || msg.toLowerCase().contains('401')) {
        await _api.clearToken();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session expired. Please login again.'), behavior: SnackBarBehavior.floating));
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), behavior: SnackBarBehavior.floating));
      }
      return null;
    }
  }

  @override
  void dispose() {
    _line1Ctl.dispose();
    _line2Ctl.dispose();
    _landmarkCtl.dispose();
    _cityCtl.dispose();
    _pincodeCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Location'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loadingGps
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.success.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.my_location, color: AppColors.success, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Current Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                              const SizedBox(height: 2),
                              Text(_locationArea, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              if (_locationDetail.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(_locationDetail, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _refreshGps,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh GPS Location'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(80)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('EDIT ADDRESS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _line1Ctl,
                    decoration: InputDecoration(
                      labelText: 'Street / Locality *',
                      hintText: 'eg: Koyambedu Market Road',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _line2Ctl,
                    decoration: InputDecoration(
                      labelText: 'Area / Suburb',
                      hintText: 'eg: Koyambedu, Chennai',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityCtl,
                          decoration: InputDecoration(
                            labelText: 'City *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _pincodeCtl,
                          decoration: InputDecoration(
                            labelText: 'Pincode *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _landmarkCtl,
                    decoration: InputDecoration(
                      labelText: 'Landmark / House No (optional)',
                      hintText: 'eg: Near bus stop, Door No: 123',
                      prefixIcon: const Icon(Icons.flag_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_latitude != 0 && _longitude != 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.withAlpha(10), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.map, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await confirmAndSave();
                        if (result != null && mounted) Navigator.pop(context, result);
                      },
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('Confirm Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
