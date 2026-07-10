import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';
import 'payment_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cartNotifier,
      builder: (_, _) {
        if (cartNotifier.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.textHint),
                ),
                const SizedBox(height: 20),
                const Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text('Add items to get started', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: cartNotifier.items.length,
                  itemBuilder: (_, i) {
                    final item = cartNotifier.items[i];
                    final totalPrice = item.price * item.count;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: item.imageUrl.isNotEmpty
                                    ? Image.network(item.imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallbackIcon(item))
                                    : _fallbackIcon(item),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text('${item.qty}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('₹${item.price}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹$totalPrice', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.chipBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _qtyBtn(Icons.remove, () => cartNotifier.updateCount(item.name, -1)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        child: Text('${item.count}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
                                      ),
                                      _qtyBtn(Icons.add, () => cartNotifier.updateCount(item.name, 1)),
                                    ],
                                  ),
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
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Total Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            Text('₹${cartNotifier.total}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentPage(total: cartNotifier.total)));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            elevation: 0,
                          ),
                          child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fallbackIcon(CartItem item) {
    return Container(
      color: AppColors.chipBg,
      child: Icon(item.icon, color: AppColors.primary, size: 28),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}
