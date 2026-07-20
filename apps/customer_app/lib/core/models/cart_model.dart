import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String name;
  final String qty;
  final int price;
  final int originalPrice;
  final IconData icon;
  final Color color;
  final String productId;
  final String imageUrl;
  int count;

  CartItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.icon,
    required this.color,
    this.originalPrice = 0,
    this.productId = '',
    this.imageUrl = '',
    this.count = 1,
  });

  int get discountPercent => originalPrice > price ? ((originalPrice - price) * 100 / originalPrice).round() : 0;

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    'price': price,
    'originalPrice': originalPrice,
    'iconCodePoint': icon.codePoint,
    'colorValue': color.toARGB32(),
    'productId': productId,
    'imageUrl': imageUrl,
    'count': count,
  };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    name: j['name']?.toString() ?? '',
    qty: j['qty']?.toString() ?? '',
    price: (j['price'] as num?)?.toInt() ?? 0,
    originalPrice: (j['originalPrice'] as num?)?.toInt() ?? 0,
    icon: IconData(j['iconCodePoint'] ?? 0, fontFamily: 'MaterialIcons'),
    color: Color(j['colorValue'] ?? 0xFF2196F3),
    productId: j['productId']?.toString() ?? '',
    imageUrl: j['imageUrl']?.toString() ?? '',
    count: (j['count'] as num?)?.toInt() ?? 1,
  );
}

class CartNotifier extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.count);
  int get total => _items.fold(0, (sum, item) => sum + (item.price * item.count));

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cart');
    _items.clear();
    if (data != null) {
      try {
        final list = jsonDecode(data) as List;
        _items.addAll(list.map((j) => CartItem.fromJson(j as Map<String, dynamic>)));
        notifyListeners();
      } catch (_) {
        _items.clear();
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cart', jsonEncode(_items.map((i) => i.toJson()).toList()));
  }

  Future<void> add(CartItem item) async {
    final existing = _items.where((i) => i.productId == item.productId && i.productId.isNotEmpty).firstOrNull;
    if (existing != null) {
      existing.count++;
    } else {
      _items.add(item);
    }
    notifyListeners();
    _save();
  }

  Future<void> updateCount(String productId, int delta) async {
    final item = _items.where((i) => i.productId == productId).firstOrNull;
    if (item == null) return;
    item.count += delta;
    if (item.count <= 0) {
      _items.remove(item);
    }
    notifyListeners();
    _save();
  }

  Future<void> removeAll(String productId) async {
    _items.removeWhere((i) => i.productId == productId);
    notifyListeners();
    _save();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    _save();
  }
}

final cartNotifier = CartNotifier();

class WishlistNotifier extends ChangeNotifier {
  final Set<String> _items = {};

  Set<String> get items => Set.unmodifiable(_items);
  int get itemCount => _items.length;

  bool contains(String name) => _items.contains(name);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('wishlist');
    _items.clear();
    if (data != null) {
      _items.addAll(data);
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('wishlist', _items.toList());
  }

  void toggle(String name) {
    if (_items.contains(name)) {
      _items.remove(name);
    } else {
      _items.add(name);
    }
    _save();
    notifyListeners();
  }

  bool remove(String name) {
    final result = _items.remove(name);
    _save();
    notifyListeners();
    return result;
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'total': total,
    'status': status,
    'date': date.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory OrderData.fromJson(Map<String, dynamic> j) => OrderData(
    id: j['id']?.toString() ?? '',
    total: (j['total_amount'] ?? j['total'] ?? 0).toInt(),
    status: j['status']?.toString() ?? 'Pending',
    date: j['created_at'] != null
        ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
        : j['date'] != null
            ? DateTime.tryParse(j['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
    items: (j['items'] as List? ?? []).map((i) => CartItem.fromJson(i as Map<String, dynamic>)).toList(),
  );
}

class OrderNotifier extends ChangeNotifier {
  final List<OrderData> _orders = [];

  List<OrderData> get orders => List.unmodifiable(_orders);
  int get orderCount => _orders.length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('orders');
    _orders.clear();
    if (data != null) {
      final list = jsonDecode(data) as List;
      _orders.addAll(list.map((j) => OrderData.fromJson(j)));
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('orders', jsonEncode(_orders.map((o) => o.toJson()).toList()));
  }

  Future<void> clear() async {
    _orders.clear();
    await _save();
    notifyListeners();
  }

  Future<void> add(List<CartItem> items, int total) async {
    _orders.insert(0, OrderData(
      id: 'ORD${DateTime.now().millisecondsSinceEpoch}',
      items: items.map((i) => CartItem(name: i.name, qty: i.qty, price: i.price, icon: i.icon, color: i.color, originalPrice: i.originalPrice, count: i.count)).toList(),
      total: total,
      status: 'Pending',
    ));
    await _save();
    notifyListeners();
  }
}

final orderNotifier = OrderNotifier();
