class ShopOrder {
  final String id;
  final String orderId;
  final String shopId;
  final String status;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final List<ShopOrderItem> items;
  final double totalAmount;
  final String paymentMethod;
  final DateTime? acceptedAt;
  final DateTime? packingAt;
  final DateTime? readyAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime createdAt;

  ShopOrder({
    required this.id,
    required this.orderId,
    required this.shopId,
    required this.status,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.items = const [],
    required this.totalAmount,
    required this.paymentMethod,
    this.acceptedAt,
    this.packingAt,
    this.readyAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdAt,
  });

  factory ShopOrder.fromJson(Map<String, dynamic> json) {
    return ShopOrder(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      shopId: json['shop_id'] ?? '',
      status: json['status'] ?? 'new',
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      deliveryAddress: json['delivery_address'],
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => ShopOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] ?? 'COD',
      acceptedAt: json['accepted_at'] != null ? DateTime.tryParse(json['accepted_at'] ?? '') ?? DateTime.now() : null,
      packingAt: json['packing_at'] != null ? DateTime.tryParse(json['packing_at'] ?? '') ?? DateTime.now() : null,
      readyAt: json['ready_at'] != null ? DateTime.tryParse(json['ready_at'] ?? '') ?? DateTime.now() : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.tryParse(json['delivered_at'] ?? '') ?? DateTime.now() : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'] ?? '') ?? DateTime.now() : null,
      cancellationReason: json['cancellation_reason'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class ShopOrderItem {
  final String id;
  final String productId;
  final String productName;
  final double productPrice;
  final int quantity;
  final double subtotal;

  ShopOrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.subtotal,
  });

  factory ShopOrderItem.fromJson(Map<String, dynamic> json) {
    return ShopOrderItem(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      productPrice: (json['product_price'] as num?)?.toDouble() ?? 0,
      quantity: json['quantity'] ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }
}
