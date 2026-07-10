import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';

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
  bool _gridMode = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prods = await _api.getProducts();
      final cats = await _api.getCategories();
      if (!mounted) return;
      setState(() { _products = prods; _filtered = List.from(prods); _categories = cats; _loading = false; });
      _applyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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
    final originalPriceCtl = TextEditingController(
      text: product?['original_price']?.toString() ?? '',
    );
    final discountCtl = TextEditingController();
    final offerPriceCtl = TextEditingController(
      text: product?['price']?.toString() ?? '',
    );
    final unitCtl = TextEditingController(text: product?['unit'] ?? '');
    final stockCtl = TextEditingController(text: product?['stock']?.toString() ?? '0');
    final images = List.generate(3, (i) => TextEditingController(
      text: product != null && product['images'] != null && i < (product['images'] as List).length
          ? (product['images'] as List)[i] ?? ''
          : '',
    ));
    String? catId = product?['category_id'];
    bool saving = false;

    // If editing, calculate discount % from existing prices
    if (product != null) {
      final orig = double.tryParse(product['original_price']?.toString() ?? '') ?? 0;
      final offer = double.tryParse(product['price']?.toString() ?? '') ?? 0;
      if (orig > 0 && offer > 0 && orig > offer) {
        final disc = ((orig - offer) * 100 / orig).round();
        discountCtl.text = disc.toString();
      }
    }

    void recalculateOffer() {
      final orig = double.tryParse(originalPriceCtl.text) ?? 0;
      final disc = double.tryParse(discountCtl.text) ?? 0;
      if (orig > 0 && disc > 0 && disc < 100) {
        final offer = orig * (100 - disc) ~/ 100;
        offerPriceCtl.text = offer.toString();
      } else if (orig > 0 && (disc <= 0 || disc >= 100)) {
        offerPriceCtl.text = orig.toStringAsFixed(0);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(product == null ? Icons.add : Icons.edit,
                            color: Theme.of(ctx).colorScheme.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product == null ? 'Add Product' : 'Edit Product',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          Text(product == null ? 'Enter product details' : 'Update product information',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Category + Name ──
                  DropdownButtonFormField<String>(
                    initialValue: catId,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: _categories.map<DropdownMenuItem<String>>((c) {
                      final cat = c as Map<String, dynamic>;
                      return DropdownMenuItem<String>(value: cat['id'] as String?, child: Text(cat['name'] ?? ''));
                    }).toList(),
                    onChanged: (v) => setSheetState(() => catId = v),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtl,
                    decoration: InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Pricing Section ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_offer, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Text('Pricing',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Original Price + Discount %
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: originalPriceCtl,
                                decoration: InputDecoration(
                                  labelText: 'Original Price (₹)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) {
                                  recalculateOffer();
                                  setSheetState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: discountCtl,
                                decoration: InputDecoration(
                                  labelText: 'Discount (%)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  suffix: const Text('%', style: TextStyle(fontSize: 15, color: Colors.grey)),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) {
                                  recalculateOffer();
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Auto-calculated Offer Price
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.sell, size: 18, color: Colors.green),
                              const SizedBox(width: 8),
                              const Text('Offer Price: ',
                                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                              Text(
                                offerPriceCtl.text.isNotEmpty ? '₹${offerPriceCtl.text}' : '—',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.green),
                              ),
                              if (discountCtl.text.isNotEmpty && double.tryParse(discountCtl.text) != null && double.parse(discountCtl.text) > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('${discountCtl.text}% OFF',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Stock + Unit ──
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtl,
                          decoration: InputDecoration(
                            labelText: 'Stock',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          keyboardType: TextInputType.number,
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
                  const SizedBox(height: 20),

                  // ── Images ──
                  const Text('Product Images (min 3)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D2D3A))),
                  const SizedBox(height: 4),
                  Text('Add product photos from URL or upload',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                  ...List.generate(3, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: images[i],
                            decoration: InputDecoration(
                              labelText: 'Image ${i + 1}',
                              hintText: images[i].text.isEmpty ? 'URL or upload' : '',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              prefixIcon: images[i].text.trim().isNotEmpty && images[i].text.trim().startsWith('http')
                                  ? Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(images[i].text.trim(), width: 32, height: 32, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                                      ),
                                    )
                                  : const Icon(Icons.image_outlined, size: 20, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: saving ? null : () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(source: ImageSource.gallery);
                              if (picked == null) return;
                              if (product == null) {
                                images[i].text = picked.path;
                                setSheetState(() {});
                                return;
                              }
                              try {
                                final result = await _api.uploadProductImage(product['id'], File(picked.path));
                                images[i].text = result['image_url'];
                                setSheetState(() {});
                              } catch (e) {
                                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.chipBg,
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              elevation: 0,
                            ),
                            child: const Icon(Icons.upload_file, size: 20),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 24),

                  // ── Save Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: saving ? null : () async {
                        if (catId == null || catId!.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Select a category'), behavior: SnackBarBehavior.floating));
                          return;
                        }
                        if (nameCtl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter product name'), behavior: SnackBarBehavior.floating));
                          return;
                        }
                        if (originalPriceCtl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter original price'), behavior: SnackBarBehavior.floating));
                          return;
                        }
                        if (images.any((c) => c.text.trim().isEmpty)) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please provide at least 3 images'), behavior: SnackBarBehavior.floating));
                          return;
                        }

                        final origPrice = double.parse(originalPriceCtl.text);
                        final discPct = double.tryParse(discountCtl.text) ?? 0;
                        final offerPrice = discPct > 0 ? (origPrice * (100 - discPct) / 100).round() : origPrice.round();

                        setSheetState(() => saving = true);
                        try {
                          final List<String> imageUrls = [];
                          for (final c in images) {
                            final val = c.text.trim();
                            if (val.startsWith('http')) {
                              imageUrls.add(val);
                            } else if (val.isNotEmpty) {
                              if (product != null) {
                                final result = await _api.uploadProductImage(product['id'], File(val));
                                imageUrls.add(result['image_url']);
                              }
                            }
                          }
                          if (imageUrls.length < 3) {
                            setSheetState(() => saving = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please provide at least 3 images (URL or upload)'), behavior: SnackBarBehavior.floating));
                            return;
                          }
                          final data = {
                            'category_id': catId ?? '',
                            'name': nameCtl.text,
                            'price': offerPrice,
                            'unit': unitCtl.text,
                            'stock': int.parse(stockCtl.text),
                            'images': imageUrls,
                            'original_price': origPrice,
                          };
                          if (product == null) {
                            await _api.createProduct(data);
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
                      child: saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(product == null ? 'Add Product' : 'Save Changes',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
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
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade200),
                    const SizedBox(height: 12),
                    Text('No products yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Text('Tap + to add your first product', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              ),
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
                                      Row(
                                        children: [
                                          if (p['original_price'] != null && p['original_price'] != p['price'])
                                            Text('₹${p['original_price']}',
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough, decorationColor: Colors.grey.shade400)),
                                          if (p['original_price'] != null && p['original_price'] != p['price']) const SizedBox(width: 4),
                                          Text('₹${p['price']} / ${p['unit']}',
                                              style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                          if (p['original_price'] != null && p['original_price'] != p['price']) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                                              child: Text(
                                                '${((double.parse(p['original_price'].toString()) - double.parse(p['price'].toString())) * 100 / double.parse(p['original_price'].toString())).round()}% off',
                                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green),
                                              ),
                                            ),
                                          ],
                                        ],
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
                                    Row(
                                      children: [
                                        if (p['original_price'] != null && p['original_price'] != p['price'])
                                          Text('₹${p['original_price']}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough, decorationColor: Colors.grey.shade400)),
                                        if (p['original_price'] != null && p['original_price'] != p['price']) const SizedBox(width: 4),
                                        Text('₹${p['price'] ?? '0'} / ${p['unit'] ?? ''}',
                                            style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
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
