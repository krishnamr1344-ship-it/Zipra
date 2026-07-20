import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/models/combo_pack.dart';
import '../../core/models/cart_model.dart';
import '../../core/api/api_service.dart';

class PackDetailSheet extends StatefulWidget {
  final ComboPack pack;
  const PackDetailSheet({super.key, required this.pack});

  @override
  State<PackDetailSheet> createState() => _PackDetailSheetState();
}

class _PackDetailSheetState extends State<PackDetailSheet> {
  final _api = ApiService();
  bool _adding = false;

  Future<void> _addToCart() async {
    setState(() => _adding = true);
    try {
      final result = await _api.addPackToCart(widget.pack.id);
      if (!mounted) return;
      for (final item in (result['items'] as List<dynamic>? ?? [])) {
        final packItem = widget.pack.items.firstWhere(
          (pi) => pi.productId == item['product_id']?.toString(),
          orElse: () => widget.pack.items.first,
        );
        final itemPrice = packItem.productPrice;
        cartNotifier.add(CartItem(
          name: item['product_name'] ?? '',
          qty: '${item['quantity'] ?? 1}',
          price: itemPrice.round(),
          icon: Icons.shopping_bag,
          color: AppColors.primaryLight,
          productId: item['product_id']?.toString() ?? '',
          count: item['quantity'] ?? 1,
          imageUrl: item['image_url'] ?? '',
        ));
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.pack.name} added to cart!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
      );
    }
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    final totalMrp = pack.items.fold<double>(0, (sum, item) => sum + item.productPrice * item.quantity);
    final savings = totalMrp - pack.totalPrice;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(pack.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ),
                      if (pack.discountLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                          child: Text(pack.discountLabel!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  if (pack.description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(pack.description!, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ),
                  const SizedBox(height: 20),
                  const Text('Items included', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  ...pack.items.map((item) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.divider)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: item.productImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(resolveImageUrl(item.productImage!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag, color: AppColors.primary)),
                                )
                              : const Icon(Icons.shopping_bag, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text('${item.quantity} × ${item.productUnit}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text('₹${(item.productPrice * item.quantity).toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDim,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total MRP', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                            Text('₹${totalMrp.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pack Price', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text('₹${pack.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                        if (savings > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.savings, size: 16, color: AppColors.success),
                                const SizedBox(width: 6),
                                Text('You save ₹${savings.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 12, offset: const Offset(0, -4))],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _adding ? null : _addToCart,
                    icon: _adding
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_shopping_cart),
                    label: Text(_adding ? 'Adding...' : 'Add to Cart — ₹${pack.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
