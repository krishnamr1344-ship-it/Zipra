import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';
import '../services/cloudinary_service.dart';
import '../services/notification_service.dart';
import '../widgets/state_widgets.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  final _api = AdminApiService();
  List<dynamic> _allItems = [];
  List<dynamic> _filtered = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _error = false;
  bool _gridMode = false;
  bool _hasMore = true;
  bool _loadingMore = false;
  int _page = 1;
  String _search = '';
  ScrollController _scrollController = ScrollController();

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

  Future<void> _load({int page = 1, bool append = false}) async {
    if (!append) {
      setState(() { _loading = true; _error = false; });
    }
    try {
      final cats = !append ? await _api.getCategories() : null;
      final prods = await _api.getProducts(page: page);
      if (!mounted) return;
      setState(() {
        if (append) {
          _allItems.addAll(prods);
          if (prods.length < 50) _hasMore = false;
          _loadingMore = false;
        } else {
          _allItems = List.from(prods);
          _page = 1;
          _hasMore = true;
          _loading = false;
        }
        if (cats != null) _categories = cats;
        _filtered = List.from(_allItems);
      });
      _applyFilter();
    } catch (e) {
      debugPrint("pages.admin_products_page: $e");
      if (!mounted) return;
      setState(() {
        if (!append) { _loading = false; _error = true; }
        _loadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() { _loadingMore = true; });
    _page++;
    await _load(page: _page, append: true);
  }

  void _applyFilter() {
    setState(() {
      _filtered = _allItems.where((p) {
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
    final uploading = List<bool>.filled(3, false);
    final picker = ImagePicker();
    String? catId = product?['category_id'];
    bool saving = false;
    String? nameError;
    String? priceError;
    String? catError;
    double? displayFinalPrice;
    void calcFinalPrice() {
      final p = double.tryParse(priceCtl.text);
      final d = int.tryParse(discountCtl.text) ?? 0;
      displayFinalPrice = p != null ? p * (100 - d) / 100 : null;
    }

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
                        onChanged: (_) { setSheetState(() { priceError = null; calcFinalPrice(); }); },
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
                  onChanged: (_) => setSheetState(() => calcFinalPrice()),
                ),
                if (displayFinalPrice != null && int.tryParse(discountCtl.text) != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text('Original: ₹${double.tryParse(priceCtl.text)?.toStringAsFixed(0) ?? '0'}',
                            style: TextStyle(fontSize: 12, color: AppColors.textHint, decoration: TextDecoration.lineThrough)),
                          const SizedBox(width: 12),
                          Text('Final: ₹${displayFinalPrice!.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 14, color: AppColors.success, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
                            child: Text('${discountCtl.text}% OFF', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('Product Images (min 1)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D2D3A))),
                const SizedBox(height: 8),
                ...List.generate(3, (i) {
                  final hasUrl = images[i].text.trim().isNotEmpty && images[i].text.trim().startsWith('http');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: uploading[i]
                          ? null
                          : () async {
                              try {
                                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                                if (picked == null) return;
                                setSheetState(() => uploading[i] = true);
                                final url = await CloudinaryService.uploadImage(picked.path);
                                setSheetState(() {
                                  uploading[i] = false;
                                  images[i].text = url;
                                });
                              } catch (e) {
                                setSheetState(() => uploading[i] = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                    content: Text('Upload failed: $e'),
                                    behavior: SnackBarBehavior.floating,
                                  ));
                                }
                              }
                            },
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          color: hasUrl ? Colors.white : AppColors.chipBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasUrl ? Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.2) : const Color(0xFFE0E0E0),
                            width: hasUrl ? 1.5 : 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: uploading[i]
                                  ? const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
                                        SizedBox(height: 8),
                                        Text('Uploading...', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                                      ],
                                    )
                                  : hasUrl
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(13),
                                          child: Image.network(images[i].text.trim(), width: double.infinity, height: 110, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, size: 40, color: Color(0xFFBBBBBB))),
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.cloud_upload_outlined, size: 32, color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.5)),
                                            const SizedBox(height: 6),
                                            Text('Tap to upload Image ${i + 1}', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                            ),
                            if (hasUrl)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setSheetState(() => images[i].text = ''),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            if (hasUrl)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Image ${i + 1}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
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
                      if (images.every((c) => c.text.trim().isEmpty)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please provide at least 1 image'), behavior: SnackBarBehavior.floating));
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
    final primary = AppColors.primary;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: primary,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
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
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
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
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: IconButton(
                              icon: Icon(_gridMode ? Icons.view_list : Icons.grid_view, color: Colors.white, size: 20),
                              onPressed: () => setState(() => _gridMode = !_gridMode),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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
                  hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.chipBg,
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
                    final origPrice = (p['price'] ?? 0).runtimeType == double ? p['price'] as double : ((p['price'] ?? 0) as num).toDouble();
                    final discPct = (p['discount_percent'] ?? 0) as int;
                    final finalPrice = (p['final_price'] ?? origPrice).runtimeType == double ? p['final_price'] as double : ((p['final_price'] ?? origPrice) as num).toDouble();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
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
                                    color: AppColors.chipBg,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: thumb != null && thumb.startsWith('http')
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.network(thumb, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, _, _) => Center(child: Text(p['name'][0].toString().toUpperCase(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary)))),
                                        )
                                      : Center(child: Text(p['name'][0].toString().toUpperCase(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary))),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(8)),
                                            child: discPct > 0
                                              ? RichText(
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(text: '₹${finalPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                                                      TextSpan(text: '  ₹${origPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 9, color: AppColors.textHint, decoration: TextDecoration.lineThrough)),
                                                      TextSpan(text: '  $discPct% off', style: TextStyle(fontSize: 9, color: AppColors.error, fontWeight: FontWeight.w500)),
                                                    ],
                                                  ),
                                                )
                                              : Text('₹${origPrice.toStringAsFixed(0)} / ${p['unit']}', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500)),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.chipBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text('Stock: ${p['stock']}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
                                      decoration: BoxDecoration(color: primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                                      child: Text(_catName(p['category_id']), style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.w500)),
                                    ),
                                    const SizedBox(height: 6),
                                    if (p['is_enabled'] == false)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
                                        child: Text('Off', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w600)),
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
                                              color: (p['is_enabled'] != false ? AppColors.warningLight : AppColors.chipBg).withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              p['is_enabled'] != false ? Icons.visibility : Icons.visibility_off,
                                              size: 18,
                                              color: p['is_enabled'] != false ? AppColors.warning : AppColors.textSecondary,
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
                                            decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
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
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
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
                                    color: AppColors.chipBg,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                  ),
                                  child: thumb != null && thumb.startsWith('http')
                                      ? ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                          child: Image.network(thumb, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => Center(child: Icon(Icons.image, size: 36, color: AppColors.textHint))),
                                        )
                                      : Center(child: Icon(Icons.image, size: 36, color: AppColors.textHint)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text('₹${p['price'] ?? '0'} / ${p['unit'] ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                                          child: Text(_catName(p['category_id']), style: TextStyle(fontSize: 9, color: primary, fontWeight: FontWeight.w500)),
                                        ),
                                        const Spacer(),
                                        Text('Stock: ${p['stock']}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
        if (_loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          ),
        ],
      ),
    );
  }
}
