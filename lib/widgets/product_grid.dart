import 'package:flutter/material.dart';
import '../models/grocery_product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<GroceryProduct> products;
  final Map<String, bool> cartMap;
  final Map<String, bool> favMap;
  final List<String> Function(GroceryProduct p) getImages;
  final void Function(GroceryProduct p) onAdd;
  final void Function(GroceryProduct p) onFav;
  final void Function(GroceryProduct p) onTap;
  final EdgeInsets? padding;
  final bool horizontal;

  const ProductGrid({
    super.key,
    required this.products,
    required this.cartMap,
    required this.favMap,
    required this.getImages,
    required this.onAdd,
    required this.onFav,
    required this.onTap,
    this.padding,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return SizedBox(
        height: 240,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final p = products[i];
            return SizedBox(
              width: 170,
              child: ProductCard(
                product: p,
                images: getImages(p),
                inCart: cartMap[p.id] ?? false,
                isFav: favMap[p.id] ?? false,
                onAdd: () => onAdd(p),
                onFav: () => onFav(p),
                onTap: () => onTap(p),
              ),
            );
          },
        ),
      );
    }

    final screenW = MediaQuery.of(context).size.width;
    final spacing = screenW * 0.03;
    final crossAxisCount = screenW > 600 ? 3 : 2;
    final cardW = (screenW - 16 * 2 - spacing) / crossAxisCount;
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);
    final contentH = 81.0 * scale;
    final aspectRatio = cardW / (cardW * 0.72 + contentH);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.zero,
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
