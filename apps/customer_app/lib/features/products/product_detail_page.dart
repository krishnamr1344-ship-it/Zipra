import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/models/cart_model.dart';

class ProductDetailPage extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String name;
  final int price;
  final int originalPrice;
  final String qty;
  final List<String> images;
  final String productId;
  final int stock;
  final String description;
  final void Function(int quantity) onAdd;

  const ProductDetailPage({
    super.key,
    required this.icon,
    required this.color,
    required this.name,
    required this.price,
    this.originalPrice = 0,
    required this.qty,
    this.images = const [],
    this.productId = '',
    this.stock = 0,
    this.description = '',
    required this.onAdd,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _pageController = PageController();
  int _currentImage = 0;
  Timer? _timer;
  int _pendingQty = 1;

  int get _discountPercent =>
      widget.originalPrice > widget.price
          ? ((widget.originalPrice - widget.price) * 100 ~/ widget.originalPrice)
          : 0;

  bool get _inCart => cartNotifier.items.any((e) => e.productId == widget.productId && widget.productId.isNotEmpty);

  int get _effectiveQty => _inCart
      ? (cartNotifier.items.where((e) => e.productId == widget.productId).firstOrNull?.count ?? 1)
      : _pendingQty;

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
          colors: [widget.color.withValues(alpha: 0.2), widget.color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: widget.color.withValues(alpha: 0.7))),
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
    return ListenableBuilder(
      listenable: cartNotifier,
      builder: (_, _) {
        final isFav = wishlistNotifier.contains(widget.name);
        final displayImages = widget.images.where((i) => i.isNotEmpty).toList();
        final qty = _effectiveQty;
        final totalPrice = widget.price * qty;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: widget.color,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (displayImages.isNotEmpty)
                        PageView(
                          controller: _pageController,
                          onPageChanged: (i) {
                            setState(() => _currentImage = i);
                            _timer?.cancel();
                            _startAutoPlay();
                          },
                          children: displayImages.map((url) => url.startsWith('http')
                              ? Image.network(url, fit: BoxFit.cover,
                                  loadingBuilder: (ctx, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                  },
                                  errorBuilder: (_, __, ___) => _fallbackImage())
                              : _fallbackImage()).toList(),
                        )
                      else
                        _fallbackImage(),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16, left: 16,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (widget.stock > 0 ? Colors.green : Colors.red).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.stock > 0 ? 'In Stock' : 'Out of Stock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(widget.qty, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey.shade800)),
                            ),
                          ],
                        ),
                      ),
                      if (displayImages.length > 1)
                        Positioned(
                          bottom: 16, right: 16,
                          child: Row(
                            children: List.generate(displayImages.length, (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: _currentImage == i ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _currentImage == i ? Colors.white : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            )),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (widget.originalPrice > widget.price) ...[
                                      Text('₹${widget.originalPrice}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF999999), decoration: TextDecoration.lineThrough)),
                                      const SizedBox(width: 8),
                                    ],
                                    Text('₹$totalPrice', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                    if (_discountPercent > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text('$_discountPercent% off', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => wishlistNotifier.toggle(widget.name),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isFav ? Colors.red.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey.shade400, size: 22),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text('Free Delivery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.replay, color: Color(0xFFF59E0B), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text('Easy Returns', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        widget.description.isNotEmpty
                            ? widget.description
                            : 'Fresh and high-quality ${widget.name}. Carefully sourced to ensure the best taste and nutrition for your family.',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF757575), height: 1.6),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.info_outline, size: 20, color: Colors.blue.shade600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Why choose us?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text('100% fresh products · Fast delivery · Best price guarantee', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Quantity selector synced with cartNotifier
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (_inCart) {
                                      cartNotifier.updateCount(widget.productId, -1);
                                    } else if (_pendingQty > 1) {
                                      setState(() => _pendingQty--);
                                    }
                                  },
                                  child: Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: widget.color,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.remove, color: Colors.white, size: 18),
                                  ),
                                ),
                                SizedBox(
                                  width: 48,
                                  child: Center(
                                    child: Text(
                                      '$qty',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    if (_inCart) {
                                      cartNotifier.updateCount(widget.productId, 1);
                                    } else {
                                      setState(() => _pendingQty++);
                                    }
                                  },
                                  child: Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: widget.color,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Total', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text('₹$totalPrice', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: widget.color)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3))],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onAdd(_pendingQty);
                  },
                  icon: Icon(_inCart ? Icons.check : Icons.add_shopping_cart, size: 20),
                  label: Text(
                    _inCart ? 'Added to Cart' : 'Add to Cart — ₹$totalPrice',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _inCart ? Colors.green.shade100 : widget.color,
                    foregroundColor: _inCart ? widget.color : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
