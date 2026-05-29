import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CartItem {
  final String id;
  final String productId;
  String name;
  String qty;
  int price;
  String? image;
  int count;
  IconData icon;
  Color color;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
    this.image,
    this.count = 1,
    this.icon = Icons.shopping_bag,
    this.color = const Color(0xFF4CAF50),
  });
}

class CartNotifier extends ChangeNotifier {
  final ApiService _api = ApiService();
  final List<CartItem> _items = [];
  bool _loaded = false;

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.count);
  int get total => _items.fold(0, (sum, item) => sum + (item.price * item.count));

  Future<void> load() async {
    try {
      final data = await _api.getCart();
      _items.clear();
      for (final item in data as List<dynamic>) {
        final map = item as Map<String, dynamic>;
        _items.add(CartItem(
          id: map['id'] ?? '',
          productId: map['product_id'] ?? '',
          name: map['product_name'] ?? '',
          qty: map['product_unit'] ?? '',
          price: (map['product_price'] ?? 0).toInt(),
          image: map['product_image'],
          count: map['quantity'] ?? 1,
        ));
      }
      _loaded = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> add(String productId, {String name = '', String qty = '', int price = 0, String? image}) async {
    try {
      final result = await _api.addToCart(productId);
      final existing = _items.where((i) => i.productId == productId).firstOrNull;
      if (existing != null) {
        existing.count = (result['quantity'] ?? existing.count) as int;
      } else {
        _items.add(CartItem(
          id: result['id'] ?? '',
          productId: productId,
          name: name,
          qty: qty,
          price: price,
          image: image,
          count: result['quantity'] ?? 1,
        ));
      }
      notifyListeners();
    } catch (_) {
      // Fallback: add locally if API fails
      final existing = _items.where((i) => i.productId == productId).firstOrNull;
      if (existing != null) {
        existing.count++;
      } else {
        _items.add(CartItem(
          id: '',
          productId: productId,
          name: name,
          qty: qty,
          price: price,
          image: image,
        ));
      }
      notifyListeners();
    }
  }

  Future<void> updateCount(String productId, int delta) async {
    final item = _items.where((i) => i.productId == productId).firstOrNull;
    if (item == null) return;

    final newCount = item.count + delta;
    if (newCount <= 0) {
      await removeAll(productId);
      return;
    }

    if (item.id.isNotEmpty) {
      try {
        await _api.updateCartItem(item.id, newCount);
      } catch (_) {}
    }

    item.count = newCount;
    notifyListeners();
  }

  Future<void> removeAll(String productId) async {
    final item = _items.where((i) => i.productId == productId).firstOrNull;
    if (item == null) return;

    if (item.id.isNotEmpty) {
      try {
        await _api.removeCartItem(item.id);
      } catch (_) {}
    }

    _items.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  Future<void> clear() async {
    try {
      await _api.clearCart();
    } catch (_) {}
    _items.clear();
    notifyListeners();
  }

  bool isInCart(String productId) => _items.any((i) => i.productId == productId);
  int itemCountFor(String productId) => _items.where((i) => i.productId == productId).fold(0, (sum, i) => sum + i.count);
}

final cartNotifier = CartNotifier();

class WishlistNotifier extends ChangeNotifier {
  final ApiService _api = ApiService();
  final Set<String> _items = {};
  bool _loaded = false;

  Set<String> get items => Set.unmodifiable(_items);
  int get itemCount => _items.length;

  Future<void> load() async {
    try {
      final data = await _api.getWishlist();
      _items.clear();
      for (final item in data as List<dynamic>) {
        final map = item as Map<String, dynamic>;
        _items.add(map['product_id'] as String);
      }
      _loaded = true;
      notifyListeners();
    } catch (_) {}
  }

  bool contains(String productId) => _items.contains(productId);

  Future<void> toggle(String productId) async {
    if (_items.contains(productId)) {
      _items.remove(productId);
      notifyListeners();
      try {
        await _api.removeFromWishlist(productId);
      } catch (_) {}
    } else {
      _items.add(productId);
      notifyListeners();
      try {
        await _api.addToWishlist(productId);
      } catch (_) {}
    }
  }

  Future<bool> remove(String productId) async {
    final removed = _items.remove(productId);
    if (removed) {
      notifyListeners();
      try {
        await _api.removeFromWishlist(productId);
      } catch (_) {}
    }
    return removed;
  }
}

final wishlistNotifier = WishlistNotifier();

class OrderData {
  final String id;
  final List<CartItem> items;
  final int total;
  final String status;
  final DateTime date;
  final String? deliveryAddress;

  OrderData({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    DateTime? date,
    this.deliveryAddress,
  }) : date = date ?? DateTime.now();
}
