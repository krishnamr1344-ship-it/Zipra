import 'package:flutter/material.dart';
import 'package:zipra_shop/core/constants/theme.dart';
import 'package:zipra_shop/core/api/shop_api_service.dart';
import 'package:zipra_shop/core/models/shop_order.dart';
import 'shop_order_detail_page.dart';

class ShopOrdersPage extends StatefulWidget {
  const ShopOrdersPage({super.key});

  @override
  State<ShopOrdersPage> createState() => _ShopOrdersPageState();
}

class _ShopOrdersPageState extends State<ShopOrdersPage>
    with SingleTickerProviderStateMixin {
  final _api = ShopApiService();
  late TabController _tabCtrl;
  List<ShopOrder> _allOrders = [];
  List<ShopOrder> _newOrders = [];
  List<ShopOrder> _activeOrders = [];
  List<ShopOrder> _completedOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getOrders();
      final orders = data
          .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _allOrders = orders;
        _newOrders = orders.where((o) => o.status == 'new').toList();
        _activeOrders = orders
            .where((o) =>
                ['accepted', 'packing', 'ready_for_pickup', 'out_for_delivery']
                    .contains(o.status))
            .toList();
        _completedOrders = orders
            .where((o) => ['delivered', 'cancelled'].contains(o.status))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(fontWeight: FontWeight.w600)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(child: _TabBadge(label: 'All', count: _allOrders.length)),
            Tab(child: _TabBadge(label: 'New', count: _newOrders.length)),
            Tab(child: _TabBadge(label: 'Active', count: _activeOrders.length)),
            Tab(child: _TabBadge(label: 'Done', count: _completedOrders.length)),
          ],
        ),
      ),
      body: _loading
          ? _buildShimmer()
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _OrderList(orders: _allOrders, onRefresh: _loadOrders),
                _OrderList(orders: _newOrders, onRefresh: _loadOrders),
                _OrderList(orders: _activeOrders, onRefresh: _loadOrders),
                _OrderList(orders: _completedOrders, onRefresh: _loadOrders),
              ],
            ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  final String label;
  final int count;
  const _TabBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<ShopOrder> orders;
  final Future<void> Function() onRefresh;
  const _OrderList({required this.orders, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            const Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.surfaceDark),
            const SizedBox(height: AppSpacing.lg),
            const Center(
              child: Text(
                'No orders found',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: orders.length,
        itemBuilder: (ctx, i) => _OrderCard(order: orders[i], onRefresh: onRefresh),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final ShopOrder order;
  final Future<void> Function() onRefresh;
  const _OrderCard({required this.order, required this.onRefresh});

  Color _statusColor() {
    switch (order.status) {
      case 'new':
        return AppColors.primary;
      case 'accepted':
        return AppColors.info;
      case 'packing':
        return AppColors.warning;
      case 'ready_for_pickup':
        return AppColors.success;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _statusBg() {
    switch (order.status) {
      case 'new':
        return AppColors.infoLight;
      case 'accepted':
        return AppColors.infoLight;
      case 'packing':
        return AppColors.warningLight;
      case 'ready_for_pickup':
        return AppColors.successLight;
      case 'delivered':
        return AppColors.successLight;
      case 'cancelled':
        return AppColors.errorLight;
      default:
        return AppColors.surfaceDim;
    }
  }

  String _statusText() {
    switch (order.status) {
      case 'new':
        return 'NEW';
      case 'accepted':
        return 'ACCEPTED';
      case 'packing':
        return 'PACKING';
      case 'ready_for_pickup':
        return 'READY';
      case 'out_for_delivery':
        return 'OUT FOR DELIVERY';
      case 'delivered':
        return 'DELIVERED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return order.status.toUpperCase();
    }
  }

  IconData _statusIcon() {
    switch (order.status) {
      case 'new':
        return Icons.fiber_new_rounded;
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'packing':
        return Icons.inventory_2_outlined;
      case 'ready_for_pickup':
        return Icons.done_all_rounded;
      case 'out_for_delivery':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.verified_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _timeAgo() {
    final diff = DateTime.now().difference(order.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusColor();
    final statusBg = _statusBg();

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ShopOrderDetailPage(order: order)),
        );
        onRefresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(), size: 14, color: status),
                      const SizedBox(width: 4),
                      Text(
                        _statusText(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: status,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _timeAgo(),
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.customerName != null)
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                order.customerName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _InfoChip(icon: Icons.shopping_bag_outlined, text: '${order.items.length} item${order.items.length == 1 ? '' : 's'}'),
                          const SizedBox(width: 8),
                          _InfoChip(icon: Icons.payment_rounded, text: order.paymentMethod),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
