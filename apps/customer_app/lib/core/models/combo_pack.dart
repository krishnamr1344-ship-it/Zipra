class ComboPackItem {
  final String id;
  final String productId;
  final String productName;
  final double productPrice;
  final String productUnit;
  final String? productImage;
  final int quantity;

  ComboPackItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.productUnit,
    this.productImage,
    required this.quantity,
  });

  factory ComboPackItem.fromJson(Map<String, dynamic> json) {
    return ComboPackItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name'] ?? '',
      productPrice: (json['product_price'] ?? 0).toDouble(),
      productUnit: json['product_unit'] ?? '',
      productImage: json['product_image'],
      quantity: json['quantity'] ?? 1,
    );
  }
}

class ComboPack {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double totalPrice;
  final String? discountLabel;
  final String? savingsText;
  final bool isEnabled;
  final List<ComboPackItem> items;

  ComboPack({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.totalPrice,
    this.discountLabel,
    this.savingsText,
    this.isEnabled = true,
    required this.items,
  });

  factory ComboPack.fromJson(Map<String, dynamic> json) {
    return ComboPack(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      discountLabel: json['discount_label'],
      savingsText: json['savings_text'],
      isEnabled: json['is_enabled'] ?? true,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ComboPackItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
