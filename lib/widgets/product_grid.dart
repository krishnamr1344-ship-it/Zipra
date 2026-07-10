import 'package:flutter/material.dart';
import '../models/grocery_product.dart';
import 'premium_product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<GroceryProduct> products;
  final Map<int, bool> cartMap;
  final Map<String, bool> favMap;
  final int Function(String name) getQuantity;
  final List<String> Function(GroceryProduct p) getImages;
  final void Function(GroceryProduct p) onAdd;
  final void Function(GroceryProduct p) onIncrement;
  final void Function(GroceryProduct p) onDecrement;
  final void Function(GroceryProduct p) onFav;
  final void Function(GroceryProduct p) onTap;

  const ProductGrid({
    super.key,
    required this.products,
    required this.cartMap,
    required this.favMap,
    required this.getQuantity,
    required this.getImages,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    required this.onFav,
    required this.onTap,
  });

  int _crossAxisCount(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final crossAxisCount = _crossAxisCount(screenW);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.74,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        final images = getImages(p);
        final inCart = cartMap[p.id] ?? false;
        final qty = getQuantity(p.name);
        return PremiumProductCard(
          imageUrl: images.isNotEmpty ? images[0] : '',
          discountLabel: p.discountPercent != null ? '${p.discountPercent}% OFF' : null,
          isWishlisted: favMap[p.name] ?? false,
          inCart: inCart,
          quantity: qty,
          weight: p.weight,
          name: p.name,
          price: p.price,
          originalPrice: p.originalPrice,
          onAdd: () => onAdd(p),
          onIncrement: () => onIncrement(p),
          onDecrement: () => onDecrement(p),
          onWishlist: () => onFav(p),
          onTap: () => onTap(p),
        );
      },
    );
  }
}
