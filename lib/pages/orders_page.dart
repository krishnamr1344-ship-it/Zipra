import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';
import '../services/api_service.dart';
import '../widgets/state_widgets.dart';
import 'login_page.dart';
import 'order_detail_page.dart';
import 'payment_gateway_screen.dart';

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                          onPayNow: () => _openPayment(o['id']?.toString() ?? '', ((o['total_amount'] ?? 0) as num).toDouble().round()),
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
    if (!context.mounted) return;
    final orderData = OrderData(
      id: orderId,
      total: ((o['total_amount'] ?? 0) as num).toDouble().round(),
      status: o['status'] ?? 'Pending',
      date: DateTime.tryParse(o['created_at'] ?? '') ?? DateTime.now(),
      deliveryAddress: addr,
      deliveryOtp: o['delivery_otp'],
      paymentMethod: o['payment_method'] ?? 'Razorpay',
      deliveryFee: ((o['delivery_fee'] ?? 0) as num).toDouble().round(),
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

  void _openPayment(String orderId, int total) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentGatewayScreen(orderId: orderId, total: total),
      ),
    );
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
  final VoidCallback? onPayNow;
  const _OrderCard({required this.id, required this.status, required this.total, required this.itemCount, required this.date, required this.items, required this.onTap, this.onPayNow});

  Color _color(String s) {
    switch (s) {
      case 'Pending': return AppColors.primaryLight;
      case 'Confirmed': return AppColors.primary;
      case 'Shipped': return const Color(0xFF2196F3);
      case 'Out For Delivery': return const Color(0xFF9C27B0);
      case 'Delivered': return AppColors.success;
      case 'Cancelled': return AppColors.error;
      case 'Failed': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Pending': return Icons.hourglass_empty;
      case 'Confirmed': return Icons.check_circle_outline;
      case 'Shipped': return Icons.local_shipping;
      case 'Out For Delivery': return Icons.directions_bike;
      case 'Delivered': return Icons.inventory_2;
      case 'Cancelled': return Icons.cancel_outlined;
      case 'Failed': return Icons.error_outline;
      default: return Icons.help_outline;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _color(status);
    final shortId = '#${id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}';
    final previewItems = items.take(3).toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(shortId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                  ),
                  Text(_timeAgo(date), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(status), size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 20, color: AppColors.divider),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Row(
                children: [
                  ...List.generate(previewItems.length, (i) {
                    final item = previewItems[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.chipBg,
                        child: Text(
                          item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    );
                  }),
                  if (items.length > 3)
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.chipBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text('+${items.length - 3}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ),
                    ),
                  const Spacer(),
                  Text('₹$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (onPayNow != null && (status == 'Pending' || status == 'Failed'))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: onPayNow,
                    icon: const Icon(Icons.payment_rounded, size: 18),
                    label: Text(status == 'Failed' ? 'Retry Payment' : 'Pay Now',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            if (onPayNow != null && (status == 'Pending' || status == 'Failed'))
              const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider.withAlpha(80))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary.withAlpha(20),
                    child: const Icon(Icons.person, size: 14, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  const Text('View Details', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
