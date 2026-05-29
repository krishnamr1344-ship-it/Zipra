import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../widgets/state_widgets.dart';
import 'address_form_page.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final data = await _api.getAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteAddress(id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _edit(Map<String, dynamic> addr) async {
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => AddressFormPage(initialData: addr)));
    if (result != null) _load();
  }

  Future<void> _add() async {
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => const AddressFormPage()));
    if (result != null) _load();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saved Addresses', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Loading addresses\u2026')
          : _error
              ? ErrorStateWidget(onRetry: _load)
              : _addresses.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.location_off,
                      title: 'No saved addresses',
                      subtitle: 'Add your first delivery address',
                      actionLabel: 'Add Address',
                      onAction: _add,
                    )
                  : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _addresses.length,
                    itemBuilder: (_, i) {
                      final addr = _addresses[i];
                      final type = addr['address_type'] ?? 'Home';
                      final line1 = addr['address_line1'] ?? '';
                      final line2 = addr['address_line2'] ?? '';
                      final city = addr['city'] ?? '';
                      final pin = addr['pincode'] ?? '';
                      final house = addr['house_number'] ?? '';
                      final floor = addr['floor_number'] ?? '';
                      final landmark = addr['landmark'] ?? '';
                      final parts = <String>[];
                      if (house.isNotEmpty) parts.add('House $house');
                      if (floor.isNotEmpty) parts.add('Floor $floor');
                      if (line1.isNotEmpty) parts.add(line1);
                      if (line2.isNotEmpty) parts.add(line2);
                      if (city.isNotEmpty) parts.add(city);
                      if (pin.isNotEmpty) parts.add(pin);
                      final fullAddress = parts.join(', ');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(15), borderRadius: BorderRadius.circular(12)),
                              child: Icon(_typeIcon(type), size: 20, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.primary.withAlpha(15), borderRadius: BorderRadius.circular(6)),
                                        child: Text(landmark.isNotEmpty ? landmark : 'Default', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(fullAddress, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textHint),
                                  onPressed: () => _edit(addr),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF5350)),
                                  onPressed: () => _delete(addr['id'] ?? ''),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add New'),
      ),
    );
  }
}
