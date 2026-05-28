import 'package:flutter/material.dart';

class GroceryProduct {
  final int id;
  final String name;
  final String weight;
  final double price;
  final double? originalPrice;
  final int? discountPercent;
  final String emoji;
  final Color imageBg;

  const GroceryProduct({
    required this.id,
    required this.name,
    required this.weight,
    required this.price,
    this.originalPrice,
    this.discountPercent,
    required this.emoji,
    this.imageBg = const Color(0xFFFFF3EA),
  });
}
