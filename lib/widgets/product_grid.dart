import 'package:flutter/material.dart';
import '../models/grocery_product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<GroceryProduct> products;
  final Map<int, bool> cartMap;
  final Map<int, bool> favMap;
  final List<String> Function(GroceryProduct p) getImages;
  final void Function(GroceryProduct p) onAdd;
  final void Function(GroceryProduct p) onFav;
  final void Function(GroceryProduct p) onTap;

  const ProductGrid({
    super.key,
    required this.products,
    required this.cartMap,
    required this.favMap,
    required this.getImages,
    required this.onAdd,
    required this.onFav,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final spacing = screenW * 0.03;
    final crossAxisCount = screenW > 600 ? 3 : 2;
    final cardW = (screenW - 32 - spacing) / crossAxisCount;
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);
    final contentH = 81.0 * scale;
    final aspectRatio = cardW / (cardW * 0.72 + contentH);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        return ProductCard(
          product: p,
          images: getImages(p),
          inCart: cartMap[p.id] ?? false,
          isFav: favMap[p.id] ?? false,
          onAdd: () => onAdd(p),
          onFav: () => onFav(p),
          onTap: () => onTap(p),
        );
      },
    );
  }
}
