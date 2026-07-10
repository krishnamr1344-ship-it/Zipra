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
        if (cartNotifier.items.isEmpty) return _emptyCart(context);
        return Column(
          children: [
            Expanded(child: _cartList()),
            _orderSummary(context),
          ],
        );
      },
    );
  }

  Widget _emptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: AppColors.chipBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 24),
            const Text('Your cart is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Looks like you haven\'t added\nanything to your cart yet', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _cartList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: cartNotifier.items.length,
      itemBuilder: (_, i) {
        final item = cartNotifier.items[i];
        final totalPrice = item.price * item.count;
        final disc = item.originalPrice > item.price ? ((item.originalPrice - item.price) * 100 ~/ item.originalPrice) : 0;
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
                    width: 72, height: 72,
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(item.imageUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => _fallbackIcon(item))
                        : _fallbackIcon(item),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(item.qty, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item.originalPrice > item.price) ...[
                            Text('₹${item.originalPrice}', style: const TextStyle(fontSize: 12, color: Color(0xFFB0B0B0), decoration: TextDecoration.lineThrough, decorationColor: Color(0xFFB0B0B0))),
                            const SizedBox(width: 6),
                          ],
                          Text('₹${item.price}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => cartNotifier.removeAll(item.name),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _qtyBtn(Icons.remove, () => cartNotifier.updateCount(item.name, -1)),
                          Container(
                            constraints: const BoxConstraints(minWidth: 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            child: Text('${item.count}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
                          ),
                          _qtyBtn(Icons.add, () => cartNotifier.updateCount(item.name, 1)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('₹$totalPrice', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _orderSummary(BuildContext context) {
    final total = cartNotifier.total;
    final totalItems = cartNotifier.itemCount;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Items', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                Text('$totalItems', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                Text('₹$total', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Delivery Fee', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                Text('Calculated at checkout', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text('₹$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentPage(total: total))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
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
        width: 36, height: 36,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}