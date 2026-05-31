import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/grocery_product.dart';

class ProductCard extends StatefulWidget {
  final GroceryProduct product;
  final bool inCart;
  final List<String> images;
  final VoidCallback onAdd;
  final VoidCallback onFav;
  final bool isFav;
  final VoidCallback onTap;
  final int initialQuantity;

  const ProductCard({
    super.key,
    required this.product,
    this.inCart = false,
    this.images = const [],
    required this.onAdd,
    required this.onFav,
    this.isFav = false,
    required this.onTap,
    this.initialQuantity = 0,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  int _quantity = 0;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
  }

  @override
  void didUpdateWidget(ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inCart != oldWidget.inCart) {
      _quantity = widget.inCart ? (_quantity == 0 ? 1 : _quantity) : 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW - 44) / 2;
    final imgH = cardW * 0.72;
    final sz = cardW * 0.04;

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
                      ? Image.network(widget.images[0], fit: BoxFit.cover, width: double.infinity, height: imgH, errorBuilder: (_, __, ___) => Center(child: Text(p.emoji, style: TextStyle(fontSize: cardW * 0.38))))
                      : Center(child: Text(p.emoji, style: TextStyle(fontSize: cardW * 0.38))),
                  if (p.discountPercent != null)
                    Positioned(
                      top: 0, left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomRight: Radius.circular(6)),
                        ),
                        child: Text('${p.discountPercent}% off', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: widget.onFav,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.9),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Icon(widget.isFav ? Icons.favorite : Icons.favorite_border, size: 14, color: widget.isFav ? Colors.red : Colors.grey.shade500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p.weight, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                  const SizedBox(height: 1),
                  Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
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
                      _quantity == 0 ? _buildAddBtn(sz) : _buildStepper(sz),
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

  Widget _buildAddBtn(double sz) {
    return OutlinedButton(
      onPressed: () {
        setState(() => _quantity = 1);
        widget.onAdd();
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.success, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: sz * 1.5, vertical: sz * 0.6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text('ADD', style: TextStyle(color: AppColors.success, fontSize: sz * 1.4, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStepper(double sz) {
    final btnW = sz * 3;
    final btnH = sz * 3.2;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.success, width: 1.5),
        borderRadius: BorderRadius.circular(8),
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
            child: Container(width: btnW, height: btnH, color: AppColors.success, child: Icon(Icons.remove, color: Colors.white, size: sz * 1.5)),
          ),
          Container(width: btnW, height: btnH, color: Colors.white, child: Center(child: Text(_quantity.toString(), style: TextStyle(color: AppColors.success, fontSize: sz * 1.6, fontWeight: FontWeight.bold)))),
          GestureDetector(
            onTap: () => setState(() => _quantity++),
            child: Container(width: btnW, height: btnH, color: AppColors.success, child: Icon(Icons.add, color: Colors.white, size: sz * 1.5)),
          ),
        ],
      ),
    );
  }
}
