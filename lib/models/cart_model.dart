import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String name;
  final String qty;
  final int price;
  final IconData icon;
  final Color color;
  final String productId;
  int count;

  CartItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.icon,
    required this.color,
    this.productId = '',
    this.count = 1,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    'price': price,
    'iconCodePoint': icon.codePoint,
    'colorValue': color.toARGB32(),
    'productId': productId,
    'count': count,
  };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    name: j['name'],
    qty: j['qty'],
    price: j['price'],
    icon: IconData(j['iconCodePoint'], fontFamily: 'MaterialIcons'),
    color: Color(j['colorValue']),
    productId: j['productId'] ?? '',
    count: j['count'] ?? 1,
  );
}

class CartNotifier extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.count);
  int get total => _items.fold(0, (sum, item) => sum + (item.price * item.count));

  void add(CartItem item) {
    final existing = _items.where((i) => i.name == item.name).firstOrNull;
    if (existing != null) {
      existing.count++;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void updateCount(String name, int delta) {
    final item = _items.where((i) => i.name == name).firstOrNull;
    if (item == null) return;
    item.count += delta;
    if (item.count <= 0) {
      _items.remove(item);
    }
    notifyListeners();
  }

  void removeAll(String name) {
    _items.removeWhere((i) => i.name == name);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

final cartNotifier = CartNotifier();

class WishlistNotifier extends ChangeNotifier {
  final Set<String> _items = {};

  Set<String> get items => Set.unmodifiable(_items);
  int get itemCount => _items.length;

  bool contains(String name) => _items.contains(name);

  void toggle(String name) {
    if (_items.contains(name)) {
      _items.remove(name);
    } else {
      _items.add(name);
    }
    notifyListeners();
  }

  bool remove(String name) => _items.remove(name);
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
    id: j['id'],
    total: j['total'],
    status: j['status'],
    date: DateTime.parse(j['date']),
    items: (j['items'] as List).map((i) => CartItem.fromJson(i)).toList(),
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

  Future<void> add(List<CartItem> items, int total) async {
    _orders.insert(0, OrderData(
      id: 'ORD${DateTime.now().millisecondsSinceEpoch}',
      items: items.map((i) => CartItem(name: i.name, qty: i.qty, price: i.price, icon: i.icon, color: i.color, count: i.count)).toList(),
      total: total,
      status: 'Pending',
    ));
    await _save();
    notifyListeners();
  }
}

final orderNotifier = OrderNotifier();
