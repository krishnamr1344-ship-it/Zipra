import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/models/cart_model.dart';
import '../../core/api/api_service.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _apiOrders = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final orders = await ApiService().getOrders();
      if (!mounted) return;
      setState(() { _apiOrders = orders.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load orders')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocal = orderNotifier.orders.isNotEmpty;
    final hasApi = _apiOrders.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refresh),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !hasApi && !hasLocal
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.chipBg,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.primary),
                        ),
                        const SizedBox(height: 20),
                        const Text('No orders yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        const Text('Your placed orders will appear here', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildOrderList(hasApi, hasLocal),
      ),
    );
  }

  Widget _buildOrderList(bool hasApi, bool hasLocal) {
    final totalItems = (hasApi ? _apiOrders.length : 0) + (hasLocal ? orderNotifier.orders.length : 0);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: totalItems + (hasApi && hasLocal ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (hasApi && hasLocal && i == _apiOrders.length) {
          return const SizedBox(height: 8);
        }
        if (i < _apiOrders.length) {
          final o = _apiOrders[i];
          return _OrderCard(
            id: o['id']?.toString() ?? '',
            status: o['status'] ?? 'Pending',
            total: (o['total_amount'] ?? 0).toInt(),
            itemCount: (o['items'] as List?)?.length ?? 0,
            date: o['created_at'] != null ? (DateTime.tryParse(o['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
            items: ((o['items'] as List?)?.cast<Map<String, dynamic>>() ?? []).map((i) => _OrderItemPreview(name: i['product_name'] ?? '', qty: i['quantity'] ?? 1, price: (i['product_price'] ?? 0).toInt())).toList(),
            onTap: () => _openApiDetail(context, o),
          );
        }
        final idx = i - _apiOrders.length - (hasApi && hasLocal ? 1 : 0);
        final order = orderNotifier.orders[idx];
        return _OrderCard(
          id: order.id,
          status: order.status,
          total: order.total,
          itemCount: order.items.length,
          date: order.date,
          items: order.items.map((i) => _OrderItemPreview(name: i.name, qty: i.count, price: i.price)).toList(),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(order: order))),
        );
      },
    );
  }

  void _openApiDetail(BuildContext context, Map<String, dynamic> o) {
    final items = (o['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    String? addr;
    if (o['delivery_address'] != null) {
      final da = o['delivery_address'] as Map<String, dynamic>;
      addr = '${da['address_line1'] ?? ''}, ${da['city'] ?? ''}';
    }
    final orderData = OrderData(
      id: o['id']?.toString() ?? '',
      total: (o['total_amount'] ?? 0).toInt(),
      status: o['status'] ?? 'Pending',
      date: o['created_at'] != null ? (DateTime.tryParse(o['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      deliveryAddress: addr,
      items: items.map((i) => CartItem(
        name: i['product_name'] ?? '',
        qty: '',
        price: (i['product_price'] ?? 0).toInt(),
        icon: Icons.shopping_bag,
        color: AppColors.success,
        productId: i['product_id'] ?? '',
        count: i['quantity'] ?? 1,
      )).toList(),
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(order: orderData)));
  }
}

class _OrderItemPreview {
  final String name;
  final int qty;
  final int price;
  const _OrderItemPreview({required this.name, required this.qty, required this.price});
}

class _OrderCard extends StatelessWidget {
  final String id;
  final String status;
  final int total;
  final int itemCount;
  final DateTime date;
  final List<_OrderItemPreview> items;
  final VoidCallback onTap;
  const _OrderCard({required this.id, required this.status, required this.total, required this.itemCount, required this.date, required this.items, required this.onTap});

  Color _color(String s) {
    switch (s) {
      case 'Pending': return AppColors.primaryLight;
      case 'Confirmed': return AppColors.primary;
      case 'Shipped': return const Color(0xFF2196F3);
      case 'Delivered': return AppColors.success;
      case 'Cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _color(status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accent, width: 4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${id.length > 10 ? id.substring(0, 10).toUpperCase() : id.toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: accent.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(status), size: 13, color: accent),
                        const SizedBox(width: 4),
                        Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Divider(height: 1, color: Colors.grey.shade100),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                children: [
                  ...items.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(8)),
                      child: Center(
                        child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ),
                  )),
                  if (items.length > 3)
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Center(
                        child: Text('+${items.length - 3}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                      ),
                    ),
                  const Spacer(),
                      Text('$itemCount item${itemCount > 1 ? 's' : ''} · ₹$total',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(top: BorderSide(color: Colors.grey.shade100))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Tap to view details', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Pending': return Icons.hourglass_empty;
      case 'Confirmed': return Icons.check_circle_outline;
      case 'Shipped': return Icons.local_shipping;
      case 'Delivered': return Icons.inventory_2;
      case 'Cancelled': return Icons.cancel_outlined;
      default: return Icons.help_outline;
    }
  }
}
