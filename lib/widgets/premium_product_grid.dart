import 'package:flutter/material.dart';
import 'premium_product_card.dart';

class PremiumProductGrid extends StatelessWidget {
  final List<PremiumProductItem> items;
  final VoidCallback? onScrollEnd;

  const PremiumProductGrid({
    super.key,
    required this.items,
    this.onScrollEnd,
  });

  int _crossAxisCount(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _crossAxisCount(constraints.maxWidth);
        final screenWidth = constraints.maxWidth;
        final spacing = 12.0;
        final screenPadding = 16.0;
        final totalSpacing = spacing * (crossAxisCount - 1) + screenPadding * 2;
        final childWidth = (screenWidth - totalSpacing) / crossAxisCount;
        final childHeight = childWidth / 0.68;

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                onScrollEnd != null &&
                notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
              onScrollEnd!();
            }
            return false;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: spacing,
                childAspectRatio: childWidth / childHeight,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return PremiumProductCard(
                  imageUrl: item.imageUrl,
                  discountLabel: item.discountLabel,
                  isWishlisted: item.isWishlisted,
                  inCart: item.count > 0,
                  quantity: item.count,
                  weight: item.weight,
                  name: item.name,
                  price: item.price,
                  originalPrice: item.originalPrice,
                  onAdd: item.onAdd,
                  onWishlist: item.onWishlist,
                  onTap: item.onTap,
                  onIncrement: item.onIncrement,
                  onDecrement: item.onDecrement,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class PremiumProductItem {
  final String imageUrl;
  final String? discountLabel;
  final bool isWishlisted;
  final String weight;
  final String name;
  final double price;
  final double? originalPrice;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onWishlist;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const PremiumProductItem({
    required this.imageUrl,
    this.discountLabel,
    this.isWishlisted = false,
    required this.weight,
    required this.name,
    required this.price,
    this.originalPrice,
    this.count = 0,
    required this.onAdd,
    required this.onWishlist,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
  });
}
