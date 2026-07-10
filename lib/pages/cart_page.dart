import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';
import 'payment_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  static const double _freeDeliveryThreshold = 499;
  static const int _shippingCharge = 29;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cartNotifier,
      builder: (_, _) {
        if (cartNotifier.items.isEmpty) return _emptyCart(context);
        return Column(
          children: [
            Expanded(child: _cartContent(context)),
            _orderSummary(context),
          ],
        );
      },
    );
  }

  // ─── Empty State ───────────────────────────────────────────
  Widget _emptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 28),
            const Text('Your cart is empty',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text(
              'Looks like you haven\'t added\nanything to your cart yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Cart Items + Progress Banner ──────────────────────────
  Widget _cartContent(BuildContext context) {
    final items = cartNotifier.items;
    final subtotal = cartNotifier.total;
    final remaining = _freeDeliveryThreshold - subtotal;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: items.length + 1, // +1 for delivery progress banner
      itemBuilder: (_, i) {
        if (i == 0) return _deliveryProgress(remaining.toDouble(), subtotal.toDouble());
        final item = items[i - 1];
        return _cartItemCard(item, key: ValueKey('${item.name}_${item.count}'));
      },
    );
  }

  // ─── Free Delivery Progress ────────────────────────────────
  Widget _deliveryProgress(double remaining, double subtotal) {
    final isFree = remaining <= 0;
    final progress = (subtotal / _freeDeliveryThreshold).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFree
              ? [const Color(0xFF2E7D32), const Color(0xFF43A047)]
              : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFree ? Icons.check_circle : Icons.local_shipping,
                color: isFree ? Colors.white : AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFree
                      ? 'You\'ve qualified for Free Delivery!'
                      : 'Add ₹${remaining.toInt()} more for free delivery',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isFree ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (!isFree) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.5),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Cart Item Card ────────────────────────────────────────
  Widget _cartItemCard(CartItem item, {Key? key}) {
    final disc = item.discountPercent;
    final subtotal = item.price * item.count;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Image ──
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 100,
                height: 100,
                color: AppColors.chipBg,
                child: item.imageUrl.isNotEmpty
                    ? Image.network(item.imageUrl, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _fallbackIcon(item))
                    : _fallbackIcon(item),
              ),
            ),
            const SizedBox(width: 14),

            // ── Details ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Remove button
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => cartNotifier.removeAll(item.name),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close, size: 16, color: Color(0xFFB0B0B0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Name
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(item.qty,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),

                  const SizedBox(height: 8),

                  // Pricing row
                  Row(
                    children: [
                      if (disc > 0) ...[
                        Text('₹${item.originalPrice}',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.grey.shade400)),
                        const SizedBox(width: 8),
                      ],
                      Text('₹${item.price}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                      if (disc > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$disc% off',
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green)),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Quantity selector + subtotal
                  Row(
                    children: [
                      _quantitySelector(item),
                      const Spacer(),
                      Text('₹$subtotal',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quantity Selector ─────────────────────────────────────
  Widget _quantitySelector(CartItem item) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => cartNotifier.updateCount(item.name, -1),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
              ),
              child: const Icon(Icons.remove, size: 18, color: AppColors.primary),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Text('${item.count}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
          ),
          GestureDetector(
            onTap: () => cartNotifier.updateCount(item.name, 1),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Order Summary ─────────────────────────────────────────
  Widget _orderSummary(BuildContext context) {
    final items = cartNotifier.items;
    final subtotal = cartNotifier.total;
    final totalItems = cartNotifier.itemCount;
    final isFreeDelivery = subtotal >= _freeDeliveryThreshold;
    final deliveryFee = isFreeDelivery ? 0 : _shippingCharge;
    final savings = items.fold<int>(0, (sum, i) => sum + ((i.originalPrice - i.price) * i.count));

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Savings highlight
            if (savings > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.savings, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'You\'re saving ₹$savings on this order!',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),

            // Summary rows
            _summaryRow('Items ($totalItems)', '₹$subtotal'),
            const SizedBox(height: 6),
            _summaryRow(
              'Delivery Fee',
              isFreeDelivery ? 'FREE' : '₹$deliveryFee',
              valueColor: isFreeDelivery ? Colors.green : null,
            ),
            if (!isFreeDelivery && subtotal < _freeDeliveryThreshold)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Free delivery on orders above ₹$_freeDeliveryThreshold',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFF0F0F0)),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Text('₹${subtotal + deliveryFee}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),

            if (savings > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('incl. ₹$savings in savings',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade600)),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Proceed to Checkout
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PaymentPage(total: subtotal + deliveryFee)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Proceed to Checkout',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }

  Widget _fallbackIcon(CartItem item) {
    return Container(
      color: AppColors.chipBg,
      child: Icon(item.icon, color: AppColors.primary.withValues(alpha: 0.5), size: 36),
    );
  }
}
