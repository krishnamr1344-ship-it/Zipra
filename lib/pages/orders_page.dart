import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';
import '../services/api_service.dart';
import '../widgets/state_widgets.dart';
import 'login_page.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _apiOrders = [];
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = false; });
    try {
      final api = ApiService();
      final hadToken = await api.getToken() != null;
      final orders = await api.getOrders();
      if (!mounted) return;
      if (hadToken && await api.getToken() == null) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
        return;
      }
      setState(() { _apiOrders = orders.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
        debugPrint("pages.orders_page: $e");
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ? const LoadingWidget(message: 'Loading orders\u2026')
            : _error
                ? ErrorStateWidget(onRetry: _refresh)
                : !hasApi
                    ? const EmptyStateWidget(
                        icon: Icons.shopping_bag_outlined,
                        title: 'No orders yet',
                        subtitle: 'Your placed orders will appear here',
                      )
                    : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (hasApi) ...[
                        ..._apiOrders.map((o) => _OrderCard(
                          id: o['id']?.toString() ?? '',
                          status: o['status'] ?? 'Pending',
                          total: ((o['total_amount'] ?? 0) as num).toDouble().round(),
                          itemCount: (o['items'] as List?)?.length ?? 0,
                          date: DateTime.tryParse(o['created_at'] ?? '') ?? DateTime.now(),
                          items: ((o['items'] as List?)?.cast<Map<String, dynamic>>() ?? []).map((i) => _OrderItemPreview(name: i['product_name'] ?? '', qty: i['quantity'] ?? 1, price: ((i['product_price'] ?? 0) as num).toDouble().round())).toList(),
                          onTap: () => _openApiDetail(context, o),
                        )),
                      ],

                    ],
                  ),
      ),
    );
  }

  Future<void> _openApiDetail(BuildContext context, Map<String, dynamic> o) async {
    final items = (o['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    String? addr;
    if (o['delivery_address'] != null) {
      final da = o['delivery_address'] as Map<String, dynamic>;
      addr = '${da['address_line1'] ?? ''}, ${da['city'] ?? ''}';
    }
    final orderId = o['id']?.toString() ?? '';
    String? deliveryOtp;
    String? detailStatus;
    try {
      final detail = await ApiService().getOrderById(orderId);
      deliveryOtp = detail['delivery_otp'] as String?;
      detailStatus = detail['status'] as String?;
    } catch (e) {
      debugPrint("pages.orders_page: getOrderById failed: $e");
    }
    if (!context.mounted) return;
    final orderData = OrderData(
      id: orderId,
      total: ((o['total_amount'] ?? 0) as num).toDouble().round(),
      status: detailStatus ?? o['status'] ?? 'Pending',
      date: DateTime.tryParse(o['created_at'] ?? '') ?? DateTime.now(),
      deliveryAddress: addr,
      deliveryOtp: deliveryOtp,
      items: items.map((i) => CartItem(
        id: i['product_id'] ?? '',
        productId: i['product_id'] ?? '',
        name: i['product_name'] ?? '',
        qty: '',
        price: ((i['product_price'] ?? 0) as num).toDouble().round(),
        icon: Icons.shopping_bag,
        color: AppColors.success,
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
