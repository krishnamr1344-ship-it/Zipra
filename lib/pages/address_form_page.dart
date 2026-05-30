import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';

class AddressFormPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool isNew;
  const AddressFormPage({super.key, this.initialData, this.isNew = false});

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _api = ApiService();
  final _line1Ctl = TextEditingController();
  final _line2Ctl = TextEditingController();
  final _houseCtl = TextEditingController();
  final _floorCtl = TextEditingController();
  final _landmarkCtl = TextEditingController();
  final _cityCtl = TextEditingController();
  final _pincodeCtl = TextEditingController();

  String _addressType = 'Home';
  double _latitude = 0;
  double _longitude = 0;
  String _addressId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _line1Ctl.text = d['address_line1'] ?? '';
      _line2Ctl.text = d['address_line2'] ?? '';
      _houseCtl.text = d['house_number'] ?? '';
      _floorCtl.text = d['floor_number'] ?? '';
      _landmarkCtl.text = d['landmark'] ?? '';
      _cityCtl.text = d['city'] ?? '';
      _pincodeCtl.text = d['pincode'] ?? '';
      _addressType = d['address_type'] ?? 'Home';
      _latitude = (d['latitude'] ?? 0).toDouble();
      _longitude = (d['longitude'] ?? 0).toDouble();
      _addressId = d['id'] ?? '';
    }
  }

  Future<void> _save() async {
    if (_line1Ctl.text.trim().isEmpty || _cityCtl.text.trim().isEmpty || _pincodeCtl.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill required fields'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'address_line1': _line1Ctl.text.trim(),
        'address_line2': _line2Ctl.text.trim(),
        'city': _cityCtl.text.trim(),
        'pincode': _pincodeCtl.text.trim(),
        'address_type': _addressType,
        'label': _addressType,
        'house_number': _houseCtl.text.trim(),
        'floor_number': _floorCtl.text.trim(),
        'landmark': _landmarkCtl.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
      };

      Map<String, dynamic> result;
      if (_addressId.isNotEmpty) {
        result = await _api.updateAddress(_addressId, data);
      } else {
        result = await _api.createAddress(data);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gps_address_id', result['id'] ?? '');
      await prefs.setString('gps_address_line', result['address_line1'] ?? '');
      await prefs.setString('gps_address_line2', result['address_line2'] ?? '');
      await prefs.setString('gps_city', result['city'] ?? '');
      await prefs.setString('gps_address_type', result['address_type'] ?? '');
      await prefs.setString('gps_house_number', result['house_number'] ?? '');
      await prefs.setString('gps_floor_number', result['floor_number'] ?? '');
      await prefs.setString('gps_landmark', result['landmark'] ?? '');
      await prefs.setString('gps_latitude', '${result['latitude'] ?? ''}');
      await prefs.setString('gps_longitude', '${result['longitude'] ?? ''}');
      await prefs.setString('gps_pincode', result['pincode'] ?? '');

      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  void dispose() {
    _line1Ctl.dispose(); _line2Ctl.dispose(); _houseCtl.dispose();
    _floorCtl.dispose(); _landmarkCtl.dispose(); _cityCtl.dispose(); _pincodeCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Add Address' : 'Edit Address'),
        backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: ['Home', 'Work', 'Other'].map((t) {
              final sel = _addressType == t;
              final icons = {'Home': Icons.home, 'Work': Icons.work, 'Other': Icons.place};
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _addressType = t),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? theme.colorScheme.primary.withAlpha(15) : Colors.grey.withAlpha(10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? theme.colorScheme.primary : Colors.grey.withAlpha(40)),
                    ),
                    child: Column(
                      children: [
                        Icon(icons[t]!, size: 24, color: sel ? theme.colorScheme.primary : Colors.grey),
                        const SizedBox(height: 4),
                        Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? theme.colorScheme.primary : Colors.grey)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 24),
            const Text('ADDRESS DETAILS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _houseCtl, decoration: InputDecoration(labelText: 'House / Flat No', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _floorCtl, decoration: InputDecoration(labelText: 'Floor', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _line1Ctl, decoration: InputDecoration(labelText: 'Street / Locality *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
            const SizedBox(height: 12),
            TextField(controller: _line2Ctl, decoration: InputDecoration(labelText: 'Area / Suburb', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
            const SizedBox(height: 12),
            TextField(controller: _landmarkCtl, decoration: InputDecoration(labelText: 'Landmark (optional)', hintText: 'Near bus stop, mall, etc.', prefixIcon: const Icon(Icons.flag_outlined, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _cityCtl, decoration: InputDecoration(labelText: 'City *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _pincodeCtl, decoration: InputDecoration(labelText: 'Pincode *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Save Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
