import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/models/cart_model.dart';
import '../../core/api/api_service.dart';
import '../auth/login_page.dart';
import '../products/product_detail_page.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _api.getProducts();
      if (!mounted) return;
      setState(() {
        _products = all.cast<Map<String, dynamic>>().where((p) => wishlistNotifier.contains(p['name'] ?? '')).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wishlistNotifier,
      builder: (_, _) {
        final filtered = _products.where((p) => wishlistNotifier.contains(p['name'] ?? '')).toList();
        if (filtered.isEmpty && !_loading) return _empty();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Wishlist', style: TextStyle(color: Colors.white)),
            centerTitle: true,
            flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _productCard(filtered[i]),
                  ),
                ),
        );
      },
    );
  }

  Widget _empty() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Your wishlist is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Save your favorite items here', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> p) {
    final name = p['name'] ?? '';
    final pid = p['id']?.toString() ?? '';
    final price = (p['price'] ?? 0).toInt();
    final originalPrice = (p['original_price'] ?? 0).toInt();
    final unit = p['unit'] ?? '';
    final images = p['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images[0].toString() : '';
    final disc = originalPrice > price ? ((originalPrice - price) * 100 ~/ originalPrice) : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(
          icon: Icons.shopping_bag,
          color: AppColors.success,
          name: name,
          price: price,
          originalPrice: originalPrice,
          qty: unit,
          images: images.map((img) {
            if (img is String) return img;
            if (img is Map) return img['image_url']?.toString() ?? img['url']?.toString() ?? '';
            return '';
          }).where((s) => s.isNotEmpty).toList(),
          productId: p['id'] ?? '',
          onAdd: (qty) => _addToCart(pid, name, price, originalPrice, unit, imageUrl, qty),
        ))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80, height: 80,
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => _fallbackImg())
                      : _fallbackImg(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(unit, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (originalPrice > price) ...[
                          Text('₹$originalPrice', style: const TextStyle(fontSize: 12, color: Color(0xFFB0B0B0), decoration: TextDecoration.lineThrough)),
                          const SizedBox(width: 6),
                        ],
                        Text('₹$price', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary)),
                        if (disc > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.withAlpha(15), borderRadius: BorderRadius.circular(4)),
                            child: Text('$disc% off', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      wishlistNotifier.toggle(name);
                      setState(() => _products.removeWhere((x) => x['name'] == name));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.red.withAlpha(10), shape: BoxShape.circle),
                      child: const Icon(Icons.favorite, size: 20, color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCartBtn(pid, name, price, originalPrice, unit, imageUrl),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartBtn(String pid, String name, int price, int originalPrice, String unit, String imageUrl) {
    final inCart = cartNotifier.items.any((e) => e.productId == pid && pid.isNotEmpty);
    return GestureDetector(
      onTap: inCart ? null : () => _addToCart(pid, name, price, originalPrice, unit, imageUrl, 1),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: inCart ? 10 : 14, vertical: 8),
        decoration: BoxDecoration(
          color: inCart ? const Color(0xFF1CB66D).withAlpha(15) : const Color(0xFF1CB66D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: inCart
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check, size: 16, color: Color(0xFF1CB66D)),
                  SizedBox(width: 4),
                  Text('Added', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1CB66D))),
                ],
              )
            : const Icon(Icons.add_shopping_cart, size: 18, color: Colors.white),
      ),
    );
  }

  Future<void> _addToCart(String pid, String name, int price, int originalPrice, String unit, String imageUrl, int qty) async {
    final token = await _api.getToken();
    if (token == null) {
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }
    final existing = cartNotifier.items.where((e) => e.productId == pid && pid.isNotEmpty).firstOrNull;
    if (existing != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already in cart'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    cartNotifier.add(CartItem(
      name: name, qty: unit, price: price, originalPrice: originalPrice,
      icon: Icons.shopping_bag, color: AppColors.success,
      productId: pid, imageUrl: imageUrl, count: qty,
    ));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name added to cart'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
    );
  }

  Widget _fallbackImg() {
    return Container(
      color: AppColors.chipBg,
      child: const Icon(Icons.shopping_bag_outlined, size: 32, color: AppColors.textHint),
    );
  }
}