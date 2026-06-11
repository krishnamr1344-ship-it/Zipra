import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';
import '../widgets/empty_cart_widget.dart';
import '../widgets/app_snackbar.dart';
import 'payment_page.dart';

class CartPage extends StatelessWidget {
  final VoidCallback? onBrowse;
  const CartPage({super.key, this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cartNotifier,
      builder: (_, _) {
        if (cartNotifier.items.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildHeader(context),
            body: EmptyCartWidget(onBrowse: onBrowse),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildHeader(context),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: cartNotifier.items.length,
                  itemBuilder: (_, i) => _CartItemCard(index: i),
                ),
              ),
              _PriceSummary(),
              _CheckoutBar(),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'My Cart',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (cartNotifier.items.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${cartNotifier.itemCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: cartNotifier.items.isNotEmpty
          ? [
              IconButton(
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.grey.shade600,
                  size: 22,
                ),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text('Clear Cart'),
                      content: const Text('Remove all items from your cart?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await cartNotifier.clear();
                    if (context.mounted) {
                      AppSnackbar.show(
                        context,
                        'Cart cleared',
                        type: SnackbarType.info,
                      );
                    }
                  }
                },
              ),
            ]
          : null,
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final int index;

  const _CartItemCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final item = cartNotifier.items[index];
    final hasImage = item.image != null && item.image!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(item.productId),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Remove Item'),
              content: Text('Remove ${item.name} from cart?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Remove',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) {
          cartNotifier.removeAll(item.productId);
          if (context.mounted) {
            AppSnackbar.show(
              context,
              '${item.name} removed',
              type: SnackbarType.info,
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: AppColors.chipBg,
                    child: hasImage
                        ? Image.network(
                            item.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholderIcon(item),
                          )
                        : _placeholderIcon(item),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.qty,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${item.price}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                _QuantityControl(item: item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon(CartItem item) {
    return Icon(Icons.shopping_bag, size: 28, color: Colors.grey.shade300);
  }
}

class _QuantityControl extends StatefulWidget {
  final CartItem item;
  const _QuantityControl({required this.item});

  @override
  State<_QuantityControl> createState() => _QuantityControlState();
}

class _QuantityControlState extends State<_QuantityControl>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtl, curve: Curves.elasticIn);
  }

  void _animate() {
    _animCtl.forward().then((_) => _animCtl.reverse());
  }

  @override
  void dispose() {
    _animCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.success, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, () {
            if (widget.item.count > 1) {
              cartNotifier.updateCount(widget.item.productId, -1);
              _animate();
            } else {
              cartNotifier.removeAll(widget.item.productId);
              if (context.mounted) {
                AppSnackbar.show(
                  context,
                  '${widget.item.name} removed',
                  type: SnackbarType.info,
                );
              }
            }
          }),
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, child) => Transform.scale(
              scale: 1 + (_scaleAnim.value * 0.15),
              child: child,
            ),
            child: Container(
              width: 32,
              height: 32,
              color: Colors.white,
              child: Center(
                child: Text(
                  '${widget.item.count}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            ),
          ),
          _btn(Icons.add, () {
            cartNotifier.updateCount(widget.item.productId, 1);
            _animate();
          }),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        color: AppColors.success,
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sub = cartNotifier.total;
    final delivery = sub >= 499 ? 0 : 40;
    final total = sub + delivery;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Subtotal', '₹$sub'),
            const SizedBox(height: 8),
            _row(
              'Delivery Fee',
              delivery == 0 ? 'FREE' : '₹$delivery',
              valueColor: delivery == 0
                  ? AppColors.success
                  : AppColors.textPrimary,
              valueWeight: delivery == 0 ? FontWeight.w700 : FontWeight.w500,
            ),
            if (delivery > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Add ₹${499 - sub} more for free delivery',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            _row(
              'Total',
              '₹$total',
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              valueStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    Color? valueColor,
    FontWeight? valueWeight,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style:
              labelStyle ??
              TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style:
              valueStyle ??
              TextStyle(
                fontSize: 14,
                fontWeight: valueWeight ?? FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final total = cartNotifier.total;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹$total',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PaymentPage(total: total)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Checkout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
