import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _products = [];
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
      final wishlist = await _api.getWishlist();
      if (!mounted) return;
      setState(() {
        _products = wishlist.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _remove(String productId) async {
    await wishlistNotifier.remove(productId);
    _load();
  }

  Future<void> _addToCart(Map<String, dynamic> item) async {
    final pid = item['product_id'] as String;
    final name = item['product_name'] as String? ?? '';
    final unit = item['product_unit'] as String? ?? '';
    final price = (item['product_price'] ?? 0).toInt();
    final image = item['product_image'] as String?;
    await cartNotifier.add(pid, name: name, qty: unit, price: price, image: image);
    if (!mounted) return;
    AppSnackbar.show(context, '$name added to cart');
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Wishlist'),
        content: const Text('Remove all items from your wishlist?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    for (final item in _products) {
      await wishlistNotifier.remove(item['product_id'] as String);
    }
    _load();
    if (!mounted) return;
    AppSnackbar.show(context, 'Wishlist cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wishlist', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_products.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, size: 22),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_error) return _buildError();
    if (_products.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _products.length,
        itemBuilder: (_, i) => _WishlistCard(
          item: _products[i],
          onRemove: () => _remove(_products[i]['product_id'] as String),
          onAddToCart: () => _addToCart(_products[i]),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 12, width: 120, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 60, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.cloud_off, size: 64, color: AppColors.error),
            ),
            const SizedBox(height: 20),
            const Text('Something went wrong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.chipBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.favorite_outline, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            const Text('Your wishlist is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Save your favorite items here', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Browse Products'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;

  const _WishlistCard({
    required this.item,
    required this.onRemove,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['product_name'] as String? ?? '';
    final price = (item['product_price'] ?? 0).toInt();
    final unit = item['product_unit'] as String? ?? '';
    final imageUrl = item['product_image'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Dismissible(
          key: ValueKey(item['product_id']),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Remove Item'),
                content: Text('Remove $name from wishlist?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ) ?? false;
          },
          onDismissed: (_) => onRemove(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder())
                        : _placeholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      if (unit.isNotEmpty)
                        Text(unit, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('₹$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 32, width: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
                        onPressed: onRemove,
                        tooltip: 'Remove',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: onAddToCart,
                          icon: const Icon(Icons.add_shopping_cart, size: 14),
                          label: const Text('Cart', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.chipBg,
      child: const Center(child: Icon(Icons.favorite, color: Colors.red, size: 24)),
    );
  }
}
