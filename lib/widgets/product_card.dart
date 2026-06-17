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
  bool _imageError = false;

  static const _productAssets = <String, String>{
    'Chilli Powder': 'assets/products img/IMG-20260617-WA0013.jpg.jpeg',
    'Rice': 'assets/products img/file_000000007bc072079d6c76b86db9572c.png',
  };

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
    return GestureDetector(
      onTap: widget.onTap,
      child: Opacity(
        opacity: p.isEnabled ? 1.0 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              _buildImageSection(p),
              _buildInfoSection(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(GroceryProduct p) {
    final assetPath = _productAssets[p.name];
    final hasNetworkImage = widget.images.isNotEmpty && widget.images[0].startsWith('http');
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth;
        final imgH = cardW * 0.75;

        return Container(
          height: imgH,
          width: double.infinity,
          decoration: BoxDecoration(
            color: p.imageBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (assetPath != null)
                Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: imgH,
                  errorBuilder: (_, _, _) => Center(child: Text(p.emoji, style: TextStyle(fontSize: cardW * 0.38))),
                )
              else if (hasNetworkImage && !_imageError)
                Image.network(
                  widget.images[0],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: imgH,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: Container(
                        color: p.imageBg,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) {
                    _imageError = true;
                    return Center(child: Text(p.emoji, style: TextStyle(fontSize: cardW * 0.38)));
                  },
                )
              else
                Center(child: Text(p.emoji, style: TextStyle(fontSize: cardW * 0.38))),
              if (p.discountPercent != null && p.discountPercent! > 0)
                Positioned(
                  top: 0, left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B00),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomRight: Radius.circular(8)),
                    ),
                    child: Text('${p.discountPercent}% OFF', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  ),
                ),
              if (p.stock > 0 && p.stock <= 5)
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomLeft: Radius.circular(8)),
                    ),
                    child: Text('Only ${p.stock} left', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (!p.isEnabled)
                Positioned.fill(
                  child: Container(
                    color: Colors.black38,
                    child: const Center(
                      child: Text('OUT OF STOCK', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ),
              Positioned(
                top: 4, right: 4,
                child: GestureDetector(
                  onTap: widget.onFav,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.9),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)],
                    ),
                    child: Icon(
                      widget.isFav ? Icons.favorite : Icons.favorite_border,
                      size: 14, color: widget.isFav ? Colors.red : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(GroceryProduct p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth;
        final sz = cardW * 0.04;

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.unit, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
              const SizedBox(height: 2),
              Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text('\u20B9${p.sellingPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                          if (p.discountPercent != null) ...[
                            const SizedBox(width: 4),
                            Text('\u20B9${p.mrp.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Color(0xFF999999), decoration: TextDecoration.lineThrough)),
                          ],
                        ],
                      ),
                    ],
                  ),
                  _quantity == 0 ? _buildAddBtn(sz) : _buildStepper(sz),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddBtn(double sz) {
    return OutlinedButton(
      onPressed: () => widget.onAdd(),
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
