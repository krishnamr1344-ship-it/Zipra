import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/theme.dart';
import '../../../core/api/api_service.dart';
import '../../addresses/address_form_page.dart';
import '../pages/map_picker_page.dart';

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _api = ApiService();
  List<Map<String, dynamic>> _savedAddresses = [];
  bool _loadingSaved = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    setState(() => _loadingSaved = true);
    try {
      final data = await _api.getAddresses();
      if (!mounted) return;
      setState(() {
        _savedAddresses = data.cast<Map<String, dynamic>>();
        _loadingSaved = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? addr]) async {
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    final result = await nav.push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => AddressFormPage(initialData: addr)));
    if (result != null) {
      await _saveToPrefs(result);
    }
  }

  Future<void> _saveToPrefs(Map<String, dynamic> addr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gps_address_id', addr['id'] ?? '');
    await prefs.setString('gps_address_line', addr['address_line1'] ?? '');
    await prefs.setString('gps_address_line2', addr['address_line2'] ?? '');
    await prefs.setString('gps_city', addr['city'] ?? '');
    await prefs.setString('gps_address_type', addr['address_type'] ?? '');
    await prefs.setString('gps_house_number', addr['house_number'] ?? '');
    await prefs.setString('gps_floor_number', addr['floor_number'] ?? '');
    await prefs.setString('gps_landmark', addr['landmark'] ?? '');
    await prefs.setString('gps_latitude', '${addr['latitude'] ?? ''}');
    await prefs.setString('gps_longitude', '${addr['longitude'] ?? ''}');
    await prefs.setString('gps_pincode', addr['pincode'] ?? '');
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'Home': return Icons.home;
      case 'Work': return Icons.work;
      default: return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Choose Location', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withAlpha(40)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.map, color: AppColors.primary, size: 22),
              ),
              title: const Text('Use Current Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text('Open map to confirm', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary),
              ),
              onTap: () => Navigator.pop(context, true),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('SAVED ADDRESSES', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1)),
              const Spacer(),
              GestureDetector(
                onTap: () => _openForm(null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _loadingSaved
              ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : _savedAddresses.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.grey.withAlpha(8), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [
                          Icon(Icons.location_off, size: 40, color: AppColors.textHint),
                          const SizedBox(height: 8),
                          Text('No saved addresses', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          Text('Use GPS or search to add one', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                        ],
                      ),
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.25),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _savedAddresses.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                        itemBuilder: (_, i) {
                          final addr = _savedAddresses[i];
                          final line2 = addr['address_line2'] ?? '';
                          final line1 = addr['address_line1'] ?? '';
                          final city = addr['city'] ?? '';
                          final type = addr['address_type'] ?? 'Home';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(15), borderRadius: BorderRadius.circular(12)),
                              child: Icon(_typeIcon(type), size: 20, color: theme.colorScheme.primary),
                            ),
                            title: Text(
                              line2.isNotEmpty ? line2 : city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text('$line1', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                                  child: Text(type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                                ),
                              ],
                            ),
                            onTap: () => _openForm(addr),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }
}
