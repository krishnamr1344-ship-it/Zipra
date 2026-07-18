class ShopProduct {
  final String id;
  final String categoryId;
  final String? categoryName;
  final String name;
  final String? description;
  final double price;
  final double? originalPrice;
  final String unit;
  final List<String> images;
  final int stock;
  final String approvalStatus;
  final DateTime createdAt;

  ShopProduct({
    required this.id,
    required this.categoryId,
    this.categoryName,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    required this.unit,
    this.images = const [],
    required this.stock,
    required this.approvalStatus,
    required this.createdAt,
  });

  factory ShopProduct.fromJson(Map<String, dynamic> json) {
    return ShopProduct(
      id: json['id'] ?? '',
      categoryId: json['category_id'] ?? '',
      categoryName: json['category_name'],
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      unit: json['unit'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      stock: json['stock'] ?? 0,
      approvalStatus: json['approval_status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
