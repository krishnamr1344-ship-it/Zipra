import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';

class AdminDeliveryFeePage extends StatefulWidget {
  const AdminDeliveryFeePage({super.key});

  @override
  State<AdminDeliveryFeePage> createState() => _AdminDeliveryFeePageState();
}

class _AdminDeliveryFeePageState extends State<AdminDeliveryFeePage> {
  final _api = AdminApiService();
  List<Map<String, dynamic>> _fees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getDeliveryFees();
      if (!mounted) return;
      setState(() { _fees = data.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showForm([Map<String, dynamic>? fee]) {
    final minCtl = TextEditingController(text: fee?['min_order_amount']?.toString() ?? '0');
    final maxCtl = TextEditingController(text: fee?['max_order_amount']?.toString() ?? '');
    final feeCtl = TextEditingController(text: fee?['fee']?.toString() ?? '');
    bool active = fee?['is_active'] ?? true;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.teal.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.local_shipping, color: Colors.teal),
                    ),
                    const SizedBox(width: 12),
                    Text(fee == null ? 'Add Delivery Fee' : 'Edit Delivery Fee', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minCtl,
                        decoration: InputDecoration(labelText: 'Min Order (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxCtl,
                        decoration: InputDecoration(labelText: 'Max Order (₹, optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: feeCtl,
                  decoration: InputDecoration(labelText: 'Delivery Fee (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => setSheetState(() => active = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: saving ? null : () async {
                      final min = double.tryParse(minCtl.text) ?? 0;
                      final max = maxCtl.text.trim().isNotEmpty ? double.tryParse(maxCtl.text) : null;
                      final f = double.tryParse(feeCtl.text);
                      if (f == null || f <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a valid fee amount'), behavior: SnackBarBehavior.floating));
                        return;
                      }
                      setSheetState(() => saving = true);
                      try {
                        final Map<String, dynamic> data = {
                          'min_order_amount': min,
                          if (max != null) 'max_order_amount': max,
                          'fee': f,
                        };
                        if (fee == null) {
                          await _api.createDeliveryFee(data);
                        } else {
                          data['is_active'] = active;
                          await _api.updateDeliveryFee(fee['id'], data);
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _load();
                      } catch (e) {
                        setSheetState(() => saving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating));
                      }
                    },
                    child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(fee == null ? 'Add Fee' : 'Save', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Fees', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showForm()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _fees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_shipping, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No delivery fees configured', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _fees.length,
                    itemBuilder: (_, i) {
                      final f = _fees[i];
                      final min = f['min_order_amount'] ?? 0;
                      final max = f['max_order_amount'];
                      final fee = f['fee'] ?? 0;
                      final active = f['is_active'] ?? false;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: Colors.teal.withAlpha(20), borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.local_shipping, color: Colors.teal),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('₹${(min as num).toStringAsFixed(0)} - ${max != null ? '₹${(max as num).toStringAsFixed(0)}' : 'Unlimited'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text('Fee: ₹${(fee as num).toStringAsFixed(0)}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: active ? Colors.green.withAlpha(20) : Colors.grey.withAlpha(20),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(active ? 'Active' : 'Inactive', style: TextStyle(fontSize: 11, color: active ? Colors.green : Colors.grey)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showForm(f)),
                              IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () async {
                                final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete'), content: Text('Delete this fee tier?'), actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                ]));
                                if (confirm == true) {
                                  try { await _api.deleteDeliveryFee(f['id']); _load(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
                                }
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}