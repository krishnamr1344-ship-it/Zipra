import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api_service.dart';

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
      setState(() {
        _products = prods;
        _filtered = List.from(prods);
        _categories = cats;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products: $e')),
      );
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

  String _catName(String? id) => _categories
      .cast<Map<String, dynamic>>()
      .firstWhere((c) => c['id'] == id, orElse: () => {'name': 'Unknown'})['name'] ??
      'Unknown';

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
    final stockCtl =
        TextEditingController(text: product?['stock']?.toString() ?? '0');
    final images = List.generate(
        3,
        (i) => TextEditingController(
              text: product != null &&
                      product['images'] != null &&
                      i < (product['images'] as List).length
                  ? (product['images'] as List)[i] ?? ''
                  : '',
            ));
    String? catId = product?['category_id'];
    bool saving = false;

    if (product != null) {
      final orig =
          double.tryParse(product['original_price']?.toString() ?? '') ?? 0;
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

    InputDecoration inputDeco(String label, {String? hint, Widget? prefix, Widget? suffix}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
        labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        prefixIcon: prefix,
        suffixText: suffix is TextSpan ? null : null,
        filled: true,
        fillColor: AppColors.surfaceDim,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    left: 24,
                    right: 24,
                    top: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // -- Header --
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              product == null ? Icons.add_rounded : Icons.edit_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product == null ? 'Add Product' : 'Edit Product',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  product == null
                                      ? 'Fill in the details below'
                                      : 'Update product information',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // -- Category --
                      DropdownButtonFormField<String>(
                        initialValue: catId,
                        decoration: inputDeco('Category',
                            prefix: const Icon(Icons.category_outlined, size: 20, color: AppColors.textHint)),
                        items: _categories.map<DropdownMenuItem<String>>((c) {
                          final cat = c as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                              value: cat['id'] as String?, child: Text(cat['name'] ?? ''));
                        }).toList(),
                        onChanged: (v) => setSheetState(() => catId = v),
                      ),
                      const SizedBox(height: 14),

                      // -- Name --
                      TextField(
                        controller: nameCtl,
                        decoration: inputDeco('Product Name',
                            prefix: const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textHint)),
                      ),
                      const SizedBox(height: 20),

                      // -- Pricing Section --
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.accentBg,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.accentLight, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.local_offer, size: 16, color: AppColors.accent),
                                SizedBox(width: 8),
                                Text('Pricing',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: originalPriceCtl,
                                    decoration: inputDeco('Original Price', prefix: const Padding(
                                      padding: EdgeInsets.only(left: 12),
                                      child: Text('₹', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    )),
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
                                    decoration: inputDeco('Discount',
                                        suffix: const Padding(
                                          padding: EdgeInsets.only(right: 12),
                                          child: Text('%', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                                        )),
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
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.sell, size: 18, color: AppColors.success),
                                  const SizedBox(width: 8),
                                  const Text('Offer Price: ',
                                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                  Text(
                                    offerPriceCtl.text.isNotEmpty ? '₹${offerPriceCtl.text}' : '—',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.success),
                                  ),
                                  if (discountCtl.text.isNotEmpty &&
                                      double.tryParse(discountCtl.text) != null &&
                                      double.parse(discountCtl.text) > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.successLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('${discountCtl.text}% OFF',
                                          style: const TextStyle(
                                              fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // -- Stock + Unit --
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockCtl,
                              decoration: inputDeco('Stock',
                                  prefix: const Icon(Icons.inventory, size: 20, color: AppColors.textHint)),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: unitCtl,
                              decoration: inputDeco('Unit', hint: 'kg, pcs, ltr',
                                  prefix: const Icon(Icons.straighten, size: 20, color: AppColors.textHint)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // -- Images --
                      const Text('Product Images (min 3)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Add product photos from URL or upload',
                          style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                      const SizedBox(height: 12),
                      ...List.generate(
                          3,
                          (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: images[i],
                                        decoration: InputDecoration(
                                          labelText: 'Image ${i + 1}',
                                          hintText: images[i].text.isEmpty ? 'URL or upload' : '',
                                          labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                          filled: true,
                                          fillColor: AppColors.surfaceDim,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.md),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.md),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.md),
                                            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          prefixIcon: images[i].text.trim().isNotEmpty
                                              ? Padding(
                                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                                    child: CachedNetworkImage(
                                                      imageUrl: AdminApiService.resolveImageUrl(images[i].text.trim()),
                                                      width: 32,
                                                      height: 32,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (_, __, ___) => const SizedBox(),
                                                    ),
                                                  ),
                                                )
                                              : const Icon(Icons.image_outlined, size: 20, color: AppColors.textHint),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 46,
                                      child: ElevatedButton(
                                        onPressed: saving
                                            ? null
                                            : () async {
                                                final picker = ImagePicker();
                                                final picked =
                                                    await picker.pickImage(source: ImageSource.gallery);
                                                if (picked == null) return;
                                                if (product == null) {
                                                  images[i].text = picked.path;
                                                  setSheetState(() {});
                                                  return;
                                                }
                                                try {
                                                  final result = await _api.uploadProductImage(
                                                      product['id'], File(picked.path));
                                                  images[i].text = result['image_url'];
                                                  setSheetState(() {});
                                                } catch (e) {
                                                  if (ctx.mounted) {
                                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                                        adminSnackBar('$e', isError: true));
                                                  }
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.surfaceDim,
                                          foregroundColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(AppRadius.sm)),
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

                      // -- Save Button --
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            elevation: 0,
                          ),
                          onPressed: saving
                              ? null
                              : () async {
                                  if (catId == null || catId!.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        adminSnackBar('Select a category'));
                                    return;
                                  }
                                  if (nameCtl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        adminSnackBar('Enter product name'));
                                    return;
                                  }
                                  if (originalPriceCtl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        adminSnackBar('Enter original price'));
                                    return;
                                  }
                                  if (images.any((c) => c.text.trim().isEmpty)) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        adminSnackBar('Please provide at least 3 images'));
                                    return;
                                  }

                                  final origPrice = double.tryParse(originalPriceCtl.text) ?? 0;
                                  final discPct = double.tryParse(discountCtl.text) ?? 0;
                                  final offerPrice = discPct > 0
                                      ? (origPrice * (100 - discPct) / 100).round()
                                      : origPrice.round();

                                  setSheetState(() => saving = true);
                                  try {
                                    final List<String> imageUrls = [];
                                    final List<String> localPaths = [];
                                    for (final c in images) {
                                      final val = c.text.trim();
                                      if (val.startsWith('http')) {
                                        imageUrls.add(val);
                                      } else if (val.isNotEmpty) {
                                        localPaths.add(val);
                                      }
                                    }
                                    String productId;
                                    if (product == null) {
                                      final data = {
                                        'category_id': catId ?? '',
                                        'name': nameCtl.text,
                                        'price': offerPrice,
                                        'unit': unitCtl.text,
                                        'stock': int.tryParse(stockCtl.text) ?? 0,
                                        'images': imageUrls,
                                        'original_price': origPrice,
                                      };
                                      final created = await _api.createProduct(data);
                                      productId = created['id'];
                                    } else {
                                      productId = product['id'];
                                      final data = {
                                        'category_id': catId ?? '',
                                        'name': nameCtl.text,
                                        'price': offerPrice,
                                        'unit': unitCtl.text,
                                        'stock': int.tryParse(stockCtl.text) ?? 0,
                                        'images': imageUrls,
                                        'original_price': origPrice,
                                      };
                                      await _api.updateProduct(productId, data);
                                    }
                                    for (final path in localPaths) {
                                      try {
                                        final result = await _api.uploadProductImage(productId, File(path));
                                        imageUrls.add(result['image_url']);
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(ctx).showSnackBar(
                                              adminSnackBar('Image upload failed: $e', isError: true));
                                        }
                                      }
                                    }
                    if (imageUrls.length < 3) {
                      setSheetState(() => saving = false);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          adminSnackBar('Please provide at least 3 images (URL or upload)'));
                      return;
                    }
                    if (localPaths.isNotEmpty && imageUrls.isNotEmpty) {
                      await _api.updateProduct(productId, {'images': imageUrls});
                    }
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    _load();
                                  } catch (e) {
                                    setSheetState(() => saving = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        adminSnackBar(e.toString(), isError: true));
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  product == null ? 'Add Product' : 'Save Changes',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // -- AppBar --
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: AppColors.primary,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 2),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Products',
                                    style: TextStyle(
                                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('Manage product catalog',
                                    style: TextStyle(fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _gridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _gridMode = !_gridMode),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                              onPressed: () {
                                showSearch(
                                  context: context,
                                  delegate: _ProductSearchDelegate(
                                    products: _products,
                                    categories: _categories,
                                    onTapProduct: (p) => _showForm(p),
                                    catNameFn: _catName,
                                  ),
                                );
                              },
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

          // -- Search Bar --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [AppShadows.soft],
                ),
                child: TextField(
                  onChanged: (v) {
                    _search = v;
                    _applyFilter();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                    prefixIcon:
                        const Icon(Icons.search_rounded, color: AppColors.textHint, size: 22),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
                            onPressed: () {
                              _search = '';
                              _applyFilter();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // -- Count Badge --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Text(
                    '${_filtered.length} product${_filtered.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  if (_categories.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDim,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        '${_categories.length} categories',
                        style:
                            const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // -- Content --
          if (_loading)
            const SliverFillRemaining(child: _ShimmerSkeleton())
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceDim,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textHint),
                      ),
                      const SizedBox(height: 24),
                      const Text('No products found',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        _search.isNotEmpty
                            ? 'Try a different search term'
                            : 'Tap + to add your first product',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (!_gridMode)
            _buildListView()
          else
            _buildGridView(isTablet),
        ],
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> p) {
    final imgList = (p['images'] as List?) ?? [];
    final thumb = imgList.isNotEmpty ? imgList[0]?.toString() : null;

    return Dismissible(
      key: ValueKey(p['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
            title: const Text('Delete Product'),
            content: Text('Remove "${p['name']}"? This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Delete')),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await _api.deleteProduct(p['id']);
            if (!context.mounted) return false;
            _load();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  adminSnackBar('$e', isError: true));
            }
          }
        }
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => _showForm(p),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDim,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: thumb != null && thumb.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: CachedNetworkImage(imageUrl: AdminApiService.resolveImageUrl(thumb),
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Center(
                                        child: Text(
                                          ((p['name']?.toString().isEmpty ?? true ? '?' : p['name'].toString()[0])).toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.accent),
                                        ))),
                              )
                            : Center(
                                child: Text(
                                  ((p['name']?.toString().isEmpty ?? true ? '?' : p['name'].toString()[0])).toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent),
                                ),
                              ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _showForm(p),
                            child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              boxShadow: [AppShadows.soft],
                            ),
                            child:
                                const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (p['original_price'] != null &&
                                p['original_price'] != p['price'])
                              Text('₹${p['original_price']}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textHint,
                                      decoration: TextDecoration.lineThrough)),
                            if (p['original_price'] != null &&
                                p['original_price'] != p['price'])
                              const SizedBox(width: 4),
                            Text('₹${p['price']} / ${p['unit']}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600)),
                            if (p['original_price'] != null &&
                                p['original_price'] != p['price']) ...[
                              const SizedBox(width: 4),
                              Builder(builder: (context) {
                                final orig =
                                    double.tryParse(p['original_price'].toString()) ?? 0;
                                final price =
                                    double.tryParse(p['price'].toString()) ?? 0;
                                final disc =
                                    orig > 0 ? ((orig - price) * 100 / orig).round() : 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.successLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('$disc% off',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success)),
                                );
                              }),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accentBg,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text(_catName(p['category_id']),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w500)),
                            ),
                            const Spacer(),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDim,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text('Stock: ${p['stock']}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p, bool isTablet) {
    final imgList = (p['images'] as List?) ?? [];
    final thumb = imgList.isNotEmpty ? imgList[0]?.toString() : null;

    return Dismissible(
      key: ValueKey(p['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
            title: const Text('Delete Product'),
            content: Text('Remove "${p['name']}"? This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Delete')),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await _api.deleteProduct(p['id']);
            if (!context.mounted) return false;
            _load();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  adminSnackBar('$e', isError: true));
            }
          }
        }
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => _showForm(p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDim,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                        ),
                        child: thumb != null && thumb.isNotEmpty
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppRadius.lg)),
                                child: CachedNetworkImage(imageUrl: AdminApiService.resolveImageUrl(thumb),
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Center(
                                        child: Icon(Icons.image, size: 36, color: AppColors.textHint))),
                              )
                            : const Center(
                                child: Icon(Icons.image, size: 36, color: AppColors.textHint)),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _showForm(p),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [AppShadows.soft],
                            ),
                            child: const Icon(Icons.edit_rounded,
                                size: 14, color: AppColors.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (p['original_price'] != null &&
                                p['original_price'] != p['price'])
                              Text('₹${p['original_price']}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textHint,
                                      decoration: TextDecoration.lineThrough)),
                            if (p['original_price'] != null &&
                                p['original_price'] != p['price'])
                              const SizedBox(width: 4),
                            Text('₹${p['price'] ?? '0'} / ${p['unit'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(_catName(p['category_id']),
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w500)),
                            ),
                            const Spacer(),
                            Text('Stock: ${p['stock']}',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _buildProductTile(_filtered[i] as Map<String, dynamic>),
          childCount: _filtered.length,
        ),
      ),
    );
  }

  Widget _buildGridView(bool isTablet) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTablet ? 3 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isTablet ? 0.85 : 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => _buildProductCard(_filtered[i] as Map<String, dynamic>, isTablet),
          childCount: _filtered.length,
        ),
      ),
    );
  }
}

// ── Search Delegate ──────────────────────────────────────────────────────────

class _ProductSearchDelegate extends SearchDelegate<String> {
  final List<dynamic> products;
  final List<dynamic> categories;
  final void Function(Map<String, dynamic>) onTapProduct;
  final String Function(String?) catNameFn;

  _ProductSearchDelegate({
    required this.products,
    required this.categories,
    required this.onTapProduct,
    required this.catNameFn,
  });

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded, size: 20),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded, size: 22),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchList(context);

  Widget _buildSearchList(BuildContext context) {
    final q = query.toLowerCase();
    final results = products.where((p) {
      final prod = p as Map<String, dynamic>;
      return q.isEmpty ||
          (prod['name']?.toString().toLowerCase() ?? '').contains(q) ||
          (prod['price']?.toString() ?? '').contains(q);
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('No results for "$query"',
                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final p = results[i] as Map<String, dynamic>;
        final imgList = (p['images'] as List?) ?? [];
        final thumb = imgList.isNotEmpty ? imgList[0]?.toString() : null;

        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceDim,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: thumb != null && thumb.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: CachedNetworkImage(imageUrl: AdminApiService.resolveImageUrl(thumb), fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.image, color: AppColors.textHint)),
                  )
                : Center(
                    child: Text(
                      ((p['name']?.toString().isEmpty ?? true ? '?' : p['name'].toString()[0])).toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: AppColors.accent))),
          ),
          title: Text(p['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text('₹${p['price']} / ${p['unit']}',
              style: const TextStyle(fontSize: 12, color: AppColors.success)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(catNameFn(p['category_id']),
                style: const TextStyle(
                    fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w500)),
          ),
          onTap: () {
            close(context, '');
            onTapProduct(p);
          },
        );
      },
    );
  }
}

// ── Shimmer Skeleton ─────────────────────────────────────────────────────────

class _ShimmerSkeleton extends StatefulWidget {
  const _ShimmerSkeleton();

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: List.generate(5, (_) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim.withValues(alpha: _animation.value),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      margin: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark.withValues(alpha: _animation.value),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 140,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark
                                    .withValues(alpha: _animation.value),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 100,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark
                                    .withValues(alpha: _animation.value),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 60,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark
                                    .withValues(alpha: _animation.value),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
