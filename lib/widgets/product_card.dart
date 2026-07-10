import 'package:flutter/material.dart';
import '../models/grocery_product.dart';

class ProductCard extends StatefulWidget {
  final GroceryProduct product;
  final bool inCart;
  final List<String> images;
  final VoidCallback onAdd;
  final VoidCallback onFav;
  final bool isFav;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.inCart = false,
    this.images = const [],
    required this.onAdd,
    required this.onFav,
    this.isFav = false,
    required this.onTap,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  int _quantity = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW - 44) / 2;
    final imgH = cardW * 0.52;
    final sz = cardW * 0.035;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: imgH,
              width: double.infinity,
              decoration: BoxDecoration(
                color: p.imageBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  widget.images.isNotEmpty && widget.images[0].startsWith('http')
                      ? Image.network(widget.images[0], fit: BoxFit.cover, width: double.infinity, height: imgH, errorBuilder: (_, __, ___) => Center(child: Text(p.emoji, style: TextStyle(fontSize: cardW * 0.3))))
                      : Center(child: Text(p.emoji, style: TextStyle(fontSize: cardW * 0.3))),
                  if (p.discountPercent != null)
                    Positioned(
                      top: 0, left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomRight: Radius.circular(6)),
                        ),
                        child: Text('${p.discountPercent}%', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text(p.weight, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${p.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                          if (p.originalPrice != null)
                            Text('₹${p.originalPrice!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Color(0xFF999999), decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                      _quantity == 0 ? _buildAddBtn() : _buildStepper(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddBtn() {
    return GestureDetector(
      onTap: () {
        setState(() => _quantity = 1);
        widget.onAdd();
      },
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF8C38)]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B00),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (_quantity > 1) { _quantity--; } else { _quantity = 0; }
              });
            },
            child: Container(
              width: 30, height: 30,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),
          Container(
            width: 30, height: 30,
            color: Colors.white,
            alignment: Alignment.center,
            child: Text(_quantity.toString(), style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          GestureDetector(
            onTap: () => setState(() => _quantity++),
            child: Container(
              width: 30, height: 30,
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
