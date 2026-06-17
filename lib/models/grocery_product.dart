import 'package:flutter/material.dart';

class GroceryProduct {
  final String id;
  final String name;
  final String unit;
  final double sellingPrice;
  final double mrp;
  final int? discountPercent;
  final List<String> images;
  final int stock;
  final bool isEnabled;
  final String category;
  final String emoji;
  final Color imageBg;

  const GroceryProduct({
    required this.id,
    required this.name,
    required this.unit,
    required this.sellingPrice,
    required this.mrp,
    this.discountPercent,
    this.images = const [],
    this.stock = 0,
    this.isEnabled = true,
    this.category = '',
    this.emoji = '\u{1F6D2}',
    this.imageBg = const Color(0xFFFFF3EA),
  });

  factory GroceryProduct.fromMap(Map<String, dynamic> map) {
    final price = (map['price'] ?? 0).runtimeType == double
        ? (map['price'] as double)
        : ((map['price'] ?? 0) as num).toDouble();
    final mrp = (map['mrp'] ?? map['original_price'] ?? price).runtimeType == double
        ? (map['mrp'] ?? map['original_price'] ?? price) as double
        : ((map['mrp'] ?? map['original_price'] ?? price) as num).toDouble();
    final images = map['images'] is List ? (map['images'] as List).cast<String>() : <String>[];
    final name = map['name'] as String? ?? '';
    final category = map['category_name'] as String? ?? '';
    final isEnabled = map['is_enabled'] != false;
    final stock = (map['stock'] ?? 0) as int;
    final discount = mrp > price ? ((1 - price / mrp) * 100).round() : (map['discount_percent'] ?? 0) as int;
    return GroceryProduct(
      id: map['id']?.toString() ?? '',
      name: name,
      unit: map['unit'] as String? ?? '',
      sellingPrice: price,
      mrp: mrp,
      discountPercent: discount > 0 ? discount : null,
      images: images,
      stock: stock,
      isEnabled: isEnabled,
      category: category,
      emoji: _emojiFor(name),
      imageBg: _colorFor(category),
    );
  }
}

String _emojiFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('rice')) return '\u{1F35A}';
  if (n.contains('milk') || n.contains('curd') || n.contains('paneer') || n.contains('cheese') || n.contains('butter') || n.contains('ghee')) return '\u{1F95B}';
  if (n.contains('coffee') || n.contains('boost') || n.contains('horlicks') || n.contains('tea')) return '\u2615';
  if (n.contains('dal')) return '\u{1F330}';
  if (n.contains('oil')) return '\u{1F6ED}';
  if (n.contains('powder') || n.contains('masala')) return '\u{1F336}\uFE0F';
  if (n.contains('soap') || n.contains('shampoo') || n.contains('tooth')) return '\u{1F9F4}';
  return '\u{1F6D2}';
}

Color _colorFor(String category) {
  final c = category.toLowerCase();
  if (c.contains('dairy')) return const Color(0xFFFEF3E2);
  if (c.contains('rice') || c.contains('grocery')) return const Color(0xFFE8F5E9);
  if (c.contains('dal')) return const Color(0xFFFFF8E1);
  if (c.contains('oil')) return const Color(0xFFFFF3E0);
  if (c.contains('masala')) return const Color(0xFFFCE4EC);
  if (c.contains('beverage')) return const Color(0xFFE3F2FD);
  if (c.contains('bathroom') || c.contains('personal') || c.contains('care')) return const Color(0xFFF3E5F5);
  return const Color(0xFFFFF3EA);
}
