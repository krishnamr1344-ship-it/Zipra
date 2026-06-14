import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';
import '../services/notification_service.dart';
import '../widgets/state_widgets.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  final _api = AdminApiService();
  List<dynamic> _products = [];
  List<dynamic> _filtered = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _error = false;
  bool _gridMode = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final prods = await _api.getProducts();
      final cats = await _api.getCategories();
      if (!mounted) return;
      setState(() { _products = prods; _filtered = List.from(prods); _categories = cats; _loading = false; });
      _applyFilter();
    } catch (e) {
        debugPrint("pages.admin_products_page: $e");
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _products.where((p) {
        final prod = p as Map<String, dynamic>;
        final q = _search.toLowerCase();
        return _search.isEmpty ||
            (prod['name']?.toString().toLowerCase() ?? '').contains(q) ||
            (prod['price']?.toString() ?? '').contains(q);
      }).toList();
    });
  }

  String _catName(String? id) => _categories.cast<Map<String, dynamic>>().firstWhere((c) => c['id'] == id, orElse: () => {'name': 'Unknown'})['name'] ?? 'Unknown';

  void _showForm([Map<String, dynamic>? product]) {
    final nameCtl = TextEditingController(text: product?['name'] ?? '');
    final priceCtl = TextEditingController(text: product?['price']?.toString() ?? '');
    final unitCtl = TextEditingController(text: product?['unit'] ?? '');
    final stockCtl = TextEditingController(text: product?['stock']?.toString() ?? '0');
    final discountCtl = TextEditingController(text: product?['discount_percent']?.toString() ?? '');
    final images = List.generate(3, (i) => TextEditingController(
      text: product != null && product['images'] != null && i < (product['images'] as List).length
          ? (product['images'] as List)[i] ?? ''
          : '',
    ));
    String? catId = product?['category_id'];
    bool saving = false;
    String? nameError;
    String? priceError;
    String? catError;

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
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(product == null ? Icons.add : Icons.edit, color: Theme.of(ctx).colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(product == null ? 'Add Product' : 'Edit Product', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: catId,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    errorText: catError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: _categories.map<DropdownMenuItem<String>>((c) {
                    final cat = c as Map<String, dynamic>;
                    return DropdownMenuItem<String>(value: cat['id'] as String?, child: Text(cat['name'] ?? ''));
                  }).toList(),
                  onChanged: (v) => setSheetState(() { catId = v; catError = null; }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtl,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: nameError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (_) { if (nameError != null) setSheetState(() => nameError = null); },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtl,
                        decoration: InputDecoration(
                          labelText: 'Price (₹)',
                          errorText: priceError,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) { if (priceError != null) setSheetState(() => priceError = null); },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: unitCtl,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          hintText: 'kg, pcs',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: stockCtl,
                  decoration: InputDecoration(
                    labelText: 'Stock',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: discountCtl,
                  decoration: InputDecoration(
                    labelText: 'Discount %',
                    hintText: 'e.g. 15 for 15% OFF',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                const Text('Product Images (min 3)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D2D3A))),
                const SizedBox(height: 8),
                ...List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: images[i],
                        decoration: InputDecoration(
                          labelText: 'Image URL ${i + 1}',
                          hintText: 'https://example.com/image${i + 1}.jpg',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: images[i].text.trim().isNotEmpty && images[i].text.trim().startsWith('http')
                              ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(images[i].text.trim(), width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: saving ? null : () async {
                      setSheetState(() {
                        nameError = nameCtl.text.trim().isEmpty ? 'Product name is required' : null;
                        priceError = priceCtl.text.trim().isEmpty ? 'Price is required' : (double.tryParse(priceCtl.text) == null ? 'Invalid price' : null);
                        catError = catId == null ? 'Select a category' : null;
                      });
                      if (nameError != null || priceError != null || catError != null) return;
                      if (images.any((c) => c.text.trim().isEmpty)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please provide at least 3 images'), behavior: SnackBarBehavior.floating));
                        return;
                      }
                      setSheetState(() => saving = true);
                      try {
                        final data = {
                          'category_id': catId ?? '',
                          'name': nameCtl.text,
                          'price': double.parse(priceCtl.text),
                          'unit': unitCtl.text,
                          'stock': int.parse(stockCtl.text),
                          'discount_percent': int.tryParse(discountCtl.text) ?? 0,
                          'images': images.map((c) => c.text.trim()).toList(),
                        };
                        if (product == null) {
                          await _api.createProduct(data);
                          notificationService.sendNotification({
                            'title': 'New Product: ${nameCtl.text.trim()}',
                            'message': '${nameCtl.text.trim()} is now available at ₹${priceCtl.text.trim()}/${unitCtl.text.trim()}',
                            'type': 'offer',
                          });
                        } else {
                          await _api.updateProduct(product['id'], data);
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _load();
                      } catch (e) {
                        setSheetState(() => saving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating));
                      }
                    },
                    child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(product == null ? 'Add Product' : 'Save Changes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: primary,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: AppColors.adminHeaderGradient,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.inventory_2, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Products', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text('Manage product catalog', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                            child: IconButton(
                              icon: Icon(_gridMode ? Icons.view_list : Icons.grid_view, color: Colors.white, size: 20),
                              onPressed: () => setState(() => _gridMode = !_gridMode),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white, size: 20),
                              onPressed: () => _showForm(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                onChanged: (v) { _search = v; _applyFilter(); },
                decoration: InputDecoration(
                  hintText: 'Search products by name or price...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.withAlpha(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: LoadingWidget(message: 'Loading products\u2026'))
          else if (_error)
            SliverFillRemaining(child: ErrorStateWidget(onRetry: _load))
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              child: _search.isNotEmpty
                  ? const EmptyStateWidget(icon: Icons.search_off, title: 'No products found', subtitle: 'Try a different search')
                  : const EmptyStateWidget(icon: Icons.inventory_2_outlined, title: 'No products yet', subtitle: 'Tap + to add your first product'),
            )
          else if (!_gridMode)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final p = _filtered[i] as Map<String, dynamic>;
                    final images = (p['images'] as List?) ?? [];
                    final thumb = images.isNotEmpty ? images[0]?.toString() : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Material(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _showForm(p),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withAlpha(15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: thumb != null && thumb.startsWith('http')
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.network(thumb, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(p['name'][0].toString().toUpperCase(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary)))),
                                        )
                                      : Center(child: Text(p['name'][0].toString().toUpperCase(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary))),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                            child: Text('₹${p['price']} / ${p['unit']}', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withAlpha(15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text('Stock: ${p['stock']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: primary.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                                      child: Text(_catName(p['category_id']), style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.w500)),
                                    ),
                                    const SizedBox(height: 6),
                                    if (p['is_enabled'] == false)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: Colors.red.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                        child: const Text('Off', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                                      ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () async {
                                            try {
                                              final enabled = await _api.toggleProduct(p['id']);
                                              if (!context.mounted) return;
                                              _load();
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                content: Text('${p['name']} ${enabled ? 'enabled' : 'disabled'}'),
                                                behavior: SnackBarBehavior.floating,
                                              ));
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating));
                                              }
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: (p['is_enabled'] != false ? Colors.orange : Colors.grey).withAlpha(15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              p['is_enabled'] != false ? Icons.visibility : Icons.visibility_off,
                                              size: 18,
                                              color: p['is_enabled'] != false ? Colors.orange : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                title: const Text('Delete Product'),
                                                content: Text('Remove "${p['name']}"?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              try {
                                                await _api.deleteProduct(p['id']);
                                                if (!context.mounted) return;
                                                _load();
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating));
                                                }
                                              }
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(color: Colors.red.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                                            child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _filtered.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final p = _filtered[i] as Map<String, dynamic>;
                    final images = (p['images'] as List?) ?? [];
                    final thumb = images.isNotEmpty ? images[0]?.toString() : null;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Material(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _showForm(p),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withAlpha(15),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                  ),
                                  child: thumb != null && thumb.startsWith('http')
                                      ? ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                          child: Image.network(thumb, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.image, size: 36, color: Colors.grey.shade300))),
                                        )
                                      : Center(child: Icon(Icons.image, size: 36, color: Colors.grey.shade300)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text('₹${p['price'] ?? '0'} / ${p['unit'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: primary.withAlpha(15), borderRadius: BorderRadius.circular(6)),
                                          child: Text(_catName(p['category_id']), style: TextStyle(fontSize: 9, color: primary, fontWeight: FontWeight.w500)),
                                        ),
                                        const Spacer(),
                                        Text('Stock: ${p['stock']}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
