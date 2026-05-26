import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cart_model.dart';

class ProductDetailPage extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String name;
  final int price;
  final String qty;
  final List<String> images;
  final bool inCart;
  final VoidCallback onAdd;

  const ProductDetailPage({
    super.key,
    required this.icon,
    required this.color,
    required this.name,
    required this.price,
    required this.qty,
    this.images = const [],
    required this.inCart,
    required this.onAdd,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _pageController = PageController();
  int _currentImage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    final count = widget.images.where((i) => i.isNotEmpty).toList().length;
    if (count < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentImage + 1) % count;
      _pageController.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  Widget _fallbackImage() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.color.withAlpha(40), widget.color.withAlpha(10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(widget.name[0].toUpperCase(), style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: widget.color.withAlpha(180))),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFav = wishlistNotifier.contains(widget.name);
    final displayImages = widget.images.where((i) => i.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_outline, color: isFav ? Colors.red : null),
            onPressed: () => wishlistNotifier.toggle(widget.name),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    onPageChanged: (i) {
                      setState(() => _currentImage = i);
                      _timer?.cancel();
                      _startAutoPlay();
                    },
                    children: displayImages.isNotEmpty
                        ? displayImages.map((url) => url.startsWith('http')
                            ? SizedBox.expand(child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackImage()))
                            : _fallbackImage())
                            .toList()
                        : [_fallbackImage()],
                  ),
                  if (displayImages.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(displayImages.length, (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImage == i ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentImage == i ? widget.color : Colors.grey.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('₹${widget.price}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(widget.qty, style: TextStyle(fontWeight: FontWeight.w600, color: widget.color)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('In Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
                  ),
                  const SizedBox(height: 32),
                  const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 8),
                  Text(
                    'Fresh and high-quality ${widget.name}. Carefully sourced to ensure the best taste and nutrition for your family.',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF757575), height: 1.6),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: widget.onAdd,
                      icon: Icon(widget.inCart ? Icons.check : Icons.add_shopping_cart),
                      label: Text(widget.inCart ? 'Added to Cart' : 'Add to Cart', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.inCart ? widget.color.withValues(alpha: 0.15) : widget.color,
                        foregroundColor: widget.inCart ? widget.color : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
