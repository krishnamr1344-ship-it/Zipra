import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';
import '../services/notification_service.dart';
import '../widgets/state_widgets.dart';

class AdminComboPacksPage extends StatefulWidget {
  const AdminComboPacksPage({super.key});

  @override
  State<AdminComboPacksPage> createState() => _AdminComboPacksPageState();
}

class _AdminComboPacksPageState extends State<AdminComboPacksPage> {
  final _api = AdminApiService();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _packs = [];
  bool _loading = true;
  bool _error = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 && _hasMore && !_loadingMore) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_loadingMore || !_hasMore) return;
    _page++;
    _load(page: _page, append: true).catchError((_) {});
  }

  Future<void> _load({int page = 1, bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() { _loading = true; _error = false; _page = 1; _hasMore = true; _packs = []; });
    }
    try {
      final data = await _api.getComboPacks(page: page);
      if (!mounted) return;
      setState(() {
        if (append) {
          _packs.addAll(data.cast<Map<String, dynamic>>());
          if (data.length < 50) _hasMore = false;
        } else {
          _packs = data.cast<Map<String, dynamic>>();
          if (data.length < 50) _hasMore = false;
        }
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
        debugPrint("pages.admin_combo_packs_page: $e");
      if (mounted) setState(() { _loading = false; _loadingMore = false; _error = !append; });
    }
  }

  void _showForm([Map<String, dynamic>? pack]) {
    final nameCtl = TextEditingController(text: pack?['name'] ?? '');
    final descCtl = TextEditingController(text: pack?['description'] ?? '');
    final priceCtl = TextEditingController(text: pack != null ? '${pack['total_price']}' : '');
    final discountCtl = TextEditingController(text: pack?['discount_label'] ?? '');
    final savingsCtl = TextEditingController(text: pack?['savings_text'] ?? '');
    final imageCtl = TextEditingController(text: pack?['image_url'] ?? '');

    List<Map<String, dynamic>> items = [];
    if (pack != null && pack['items'] != null) {
      items = (pack['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    } else {
      items.add({'product_id': '', 'quantity': 1, 'product_name': ''});
    }

    bool saving = false;
    String? nameError;
    String? priceError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.inventory_2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(pack == null ? 'Add Combo Pack' : 'Edit Combo Pack', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              TextField(controller: nameCtl, decoration: InputDecoration(labelText: 'Pack Name', errorText: nameError, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), onChanged: (_) { if (nameError != null) setSheetState(() => nameError = null); }),
              const SizedBox(height: 12),
              TextField(controller: descCtl, decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), maxLines: 2),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: priceCtl, decoration: InputDecoration(labelText: 'Total Price (₹)', errorText: priceError, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), keyboardType: TextInputType.number, onChanged: (_) { if (priceError != null) setSheetState(() => priceError = null); })),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: discountCtl, decoration: InputDecoration(labelText: 'Discount Label', hintText: 'e.g. 20% OFF', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: savingsCtl, decoration: InputDecoration(labelText: 'Savings Text', hintText: 'e.g. Save ₹500', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
              const SizedBox(height: 12),
              TextField(controller: imageCtl, decoration: InputDecoration(labelText: 'Image URL (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Products in Pack', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setSheetState(() => items.add({'product_id': '', 'quantity': 1, 'product_name': ''}));
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Product'),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Product ID',
                                hintText: item['product_name'] ?? '',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              controller: TextEditingController(text: item['product_id']),
                              onChanged: (v) => item['product_id'] = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Qty',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              controller: TextEditingController(text: '${item['quantity']}'),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => item['quantity'] = int.tryParse(v) ?? 1,
                            ),
                          ),
                          if (items.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                              onPressed: () => setSheetState(() => items.removeAt(i)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    setSheetState(() {
                      nameError = nameCtl.text.trim().isEmpty ? 'Pack name is required' : null;
                      priceError = priceCtl.text.trim().isEmpty ? 'Price is required' : (double.tryParse(priceCtl.text) == null ? 'Invalid price' : null);
                    });
                    if (nameError != null || priceError != null) return;
                    setSheetState(() => saving = true);
                    try {
                      final body = {
                        'name': nameCtl.text.trim(),
                        'description': descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
                        'total_price': double.parse(priceCtl.text.trim()),
                        'discount_label': discountCtl.text.trim().isEmpty ? null : discountCtl.text.trim(),
                        'savings_text': savingsCtl.text.trim().isEmpty ? null : savingsCtl.text.trim(),
                        'image_url': imageCtl.text.trim().isEmpty ? null : imageCtl.text.trim(),
                        'items': items.where((e) => e['product_id'].toString().trim().isNotEmpty).map((e) => {
                          'product_id': e['product_id'].toString().trim(),
                          'quantity': (e['quantity'] as int).clamp(1, 100),
                        }).toList(),
                      };
                      if (pack == null) {
                        await _api.createComboPack(body);
                        notificationService.sendNotification({
                          'title': 'New Offer: ${nameCtl.text.trim()}',
                          'message': 'Check out our new combo pack at just ₹${priceCtl.text.trim()}',
                          'type': 'offer',
                          'image_url': imageCtl.text.trim().isEmpty ? null : imageCtl.text.trim(),
                        });
                      } else {
                        await _api.updateComboPack(pack['id'], body);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      setSheetState(() => saving = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(pack == null ? 'Create Pack' : 'Update Pack', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePack(Map<String, dynamic> pack) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pack'),
        content: Text('Delete "${pack['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.deleteComboPack(pack['id']);
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _togglePack(Map<String, dynamic> pack) async {
    try {
      await _api.toggleComboPack(pack['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Combo Packs'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showForm(),
          ),
        ],
      ),
      body: _loading
          ? const LoadingWidget(message: 'Loading packs\u2026')
          : _error
              ? ErrorStateWidget(onRetry: _load)
              : _packs.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.inventory_2_outlined,
                      title: 'No combo packs yet',
                      actionLabel: 'Create First Pack',
                      onAction: () => _showForm(),
                    )
                  : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _packs.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _packs.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final pack = _packs[i];
                      final isEnabled = pack['is_enabled'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(pack['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isEnabled ? Colors.green.withValues(alpha: 0.20) : Colors.grey.withValues(alpha: 0.20),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(isEnabled ? 'Enabled' : 'Disabled', style: TextStyle(fontSize: 12, color: isEnabled ? Colors.green : Colors.grey, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              if (pack['description'] != null) ...[
                                const SizedBox(height: 4),
                                Text(pack['description'], style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('₹${pack['total_price']?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  if (pack['discount_label'] != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(8)),
                                      child: Text(pack['discount_label'], style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: (pack['items'] as List<dynamic>?)?.map<Widget>((item) {
                                  return Chip(
                                    label: Text('${item['product_name'] ?? '?'} ×${item['quantity'] ?? 1}', style: const TextStyle(fontSize: 11)),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  );
                                }).toList() ?? [],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(isEnabled ? Icons.visibility_off : Icons.visibility, size: 20),
                                    tooltip: isEnabled ? 'Disable' : 'Enable',
                                    onPressed: () => _togglePack(pack),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showForm(pack),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    onPressed: () => _deletePack(pack),
                                  ),
                                ],
                              ),
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
