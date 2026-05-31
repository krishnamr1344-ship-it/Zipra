import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/combo_pack.dart';
import '../models/cart_model.dart';
import '../services/api_service.dart';

class PackDetailSheet extends StatefulWidget {
  final ComboPack pack;
  const PackDetailSheet({super.key, required this.pack});

  @override
  State<PackDetailSheet> createState() => _PackDetailSheetState();
}

class _PackDetailSheetState extends State<PackDetailSheet> {
  final _api = ApiService();
  bool _adding = false;

  static const _orange = Color(0xFFFF6B00);
  static const _bgWarm = Color(0xFFFFF8F3);

  Future<void> _addToCart() async {
    setState(() => _adding = true);
    try {
      final result = await _api.addPackToCart(widget.pack.id);
      if (!mounted) return;
      for (final item in result['items'] as List<dynamic>) {
        await cartNotifier.add(
          item['product_id']?.toString() ?? '',
          name: item['product_name'] ?? '',
          qty: '${item['quantity'] ?? 1}',
          price: 0,
        );
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 44, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pack.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                            if (pack.description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(pack.description!, style: const TextStyle(fontSize: 14, color: Color(0xFF757575))),
                              ),
                          ],
                        ),
                      ),
                      if (pack.discountLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(pack.discountLabel!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Items included', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 12),
                  ...pack.items.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bgWarm,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: item.productImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(item.productImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag, color: _orange)),
                                )
                              : const Icon(Icons.shopping_bag_outlined, color: _orange, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                              const SizedBox(height: 3),
                              Text('${item.quantity} ${item.productUnit}', style: const TextStyle(fontSize: 13, color: Color(0xFF757575))),
                            ],
                          ),
                        ),
                        Text('₹${(item.productPrice * item.quantity).toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFFF8F3), const Color(0xFFFFF0E0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFE0C0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total MRP', style: TextStyle(fontSize: 14, color: Color(0xFF757575))),
                            Text('₹${totalMrp.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, color: Color(0xFF757575), decoration: TextDecoration.lineThrough)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: Color(0xFFFFE0C0)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pack Price', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                            Text('₹${pack.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _orange)),
                          ],
                        ),
                        if (savings > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.savings, size: 16, color: Color(0xFF4CAF50)),
                                const SizedBox(width: 6),
                                Text('You save ₹${savings.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50))),
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
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 16, offset: const Offset(0, -4))],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _adding ? null : _addToCart,
                    icon: _adding
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Icon(Icons.add_shopping_cart, size: 20),
                    label: Text(
                      _adding ? 'Adding...' : 'Add to Cart  •  ₹${pack.totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
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
