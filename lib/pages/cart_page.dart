import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_cart_widget.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/order_summary.dart';
import '../widgets/bottom_checkout_bar.dart';

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
            backgroundColor: const Color(0xFFF8F7F5),
            appBar: _buildHeader(context),
            body: const EmptyCartWidget(),
          );
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF8F7F5),
          appBar: _buildHeader(context),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  itemCount: cartNotifier.items.length + 1,
                  itemBuilder: (_, i) {
                    if (i == cartNotifier.items.length) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: OrderSummary(),
                      );
                    }
                    return CartItemCard(item: cartNotifier.items[i], index: i);
                  },
                ),
              ),
              const BottomCheckoutBar(),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    final itemCount = cartNotifier.itemCount;
    final showCart = cartNotifier.items.isNotEmpty;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      leading: onBrowse == null
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.grey.shade700, size: 20),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'My Cart',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
              if (showCart) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$itemCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (showCart) ...[
            const SizedBox(height: 2),
            Text(
              'You have $itemCount ${itemCount == 1 ? 'item' : 'items'} in your cart',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
      actions: showCart
          ? [
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade600, size: 22),
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
                          child: const Text('Clear', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await cartNotifier.clear();
                    if (context.mounted) {
                      AppSnackbar.show(context, 'Cart cleared', type: SnackbarType.info);
                    }
                  }
                },
              ),
            ]
          : null,
    );
  }
}
