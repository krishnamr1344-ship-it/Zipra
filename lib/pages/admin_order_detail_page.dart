import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const AdminOrderDetailPage({super.key, required this.order});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  late Map<String, dynamic> _order;
  late List<Map<String, dynamic>> _items;
  final _api = AdminApiService();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _items = (widget.order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  void _openMaps(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFF59E0B);
      case 'Confirmed':
        return const Color(0xFF3B82F6);
      case 'Shipped':
        return const Color(0xFF8B5CF6);
      case 'Delivered':
        return const Color(0xFF10B981);
      case 'Cancelled':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_bottom;
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Shipped':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.inventory_2;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  List<Map<String, dynamic>> get _statusFlow {
    final all = ['Pending', 'Confirmed', 'Shipped', 'Delivered'];
    final idx = all.indexOf(_order['status']);
    if (idx == -1) return [];
    if (_order['status'] == 'Cancelled') {
      final ci = all.indexOf(_getPreviousStatus());
      return all.asMap().entries.map((e) => {
        'status': e.value,
        'done': e.key <= ci,
        'current': false,
      }).toList();
    }
    return all.asMap().entries.map((e) => {
      'status': e.value,
      'done': e.key < idx,
      'current': e.key == idx,
    }).toList();
  }

  String _getPreviousStatus() {
    final all = ['Pending', 'Confirmed', 'Shipped', 'Delivered'];
    final idx = all.indexOf(_order['status'] == 'Cancelled' ? _order['previous_status'] ?? 'Pending' : _order['status']);
    if (idx <= 0) return 'Pending';
    return all[idx - 1];
  }

  void _changeStatus() {
    final statuses = ['Confirmed', 'Shipped', 'Delivered', 'Cancelled'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor(_order['status']).withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_statusIcon(_order['status']),
                      color: _statusColor(_order['status'])),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update Status',
                        style:
                            TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Current: ${_order['status']}',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...statuses
                .where((s) => s != _order['status'])
                .map((s) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _statusColor(s).withAlpha(10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _statusColor(s).withAlpha(40)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _statusColor(s).withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_statusIcon(s),
                              size: 22, color: _statusColor(s)),
                        ),
                        title: Text(s,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _statusColor(s))),
                        subtitle: Text(
                          _statusSubtitle(s),
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _statusColor(s).withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.arrow_forward,
                              size: 16, color: _statusColor(s)),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await _api.updateOrderStatus(
                                _order['id'], s);
                            if (!context.mounted) return;
                            setState(() {
                              if (s == 'Cancelled') {
                                _order['previous_status'] = _order['status'];
                              }
                              _order['status'] = s;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order $s'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: _statusColor(s),
                              ),
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('$e'),
                                    behavior: SnackBarBehavior.floating),
                              );
                            }
                          }
                        },
                      ),
                    )),
          ],
        ),
      ),
    );
  }

  String _statusSubtitle(String status) {
    switch (status) {
      case 'Confirmed':
        return 'Accept the order and confirm stock availability';
      case 'Shipped':
        return 'Order is out for delivery';
      case 'Delivered':
        return 'Mark as successfully delivered';
      case 'Cancelled':
        return 'Cancel this order';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final statusColor = _statusColor(_order['status']);
    final gps = _order['user_gps_address'] as Map<String, dynamic>?;
    final deliveryAddr =
        _order['delivery_address'] as Map<String, dynamic>?;
    final shortId = _order['id'].toString().length > 8
        ? _order['id'].toString().substring(0, 8)
        : _order['id'].toString();
    final statusFlow = _statusFlow;
    final isCancelled = _order['status'] == 'Cancelled';

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: primary,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: AppColors.adminHeaderGradient,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(_statusIcon(_order['status']),
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Order #$shortId',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                Text(_order['user_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.white70)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(35),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: statusColor.withAlpha(80)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon(_order['status']),
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(_order['status'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calendar_today,
                                size: 14, color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _order['created_at']
                                    ?.toString()
                                    .substring(0, 10) ??
                                '',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                          ),
                          const Spacer(),
                          Text(
                            '₹${_order['total_amount']?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!isCancelled && statusFlow.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text('ORDER PROGRESS',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 1)),
              ),
            ),
          if (!isCancelled && statusFlow.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 12,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Row(
                    children: statusFlow.asMap().entries.map((entry) {
                      final i = entry.key;
                      final step = entry.value;
                      final isDone = step['done'] as bool;
                      final isCurrent = step['current'] as bool;
                      final label = step['status'] as String;
                      final stepColor = isDone || isCurrent
                          ? _statusColor(label)
                          : Colors.grey.shade200;

                      return Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                if (i > 0)
                                  Expanded(
                                    child: Container(
                                      height: 3,
                                      color: isDone
                                          ? _statusColor(label)
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                Container(
                                  width: isCurrent ? 36 : 28,
                                  height: isCurrent ? 36 : 28,
                                  decoration: BoxDecoration(
                                    color: isDone || isCurrent
                                        ? stepColor
                                        : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                    border: isCurrent
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 3)
                                        : null,
                                    boxShadow: isCurrent
                                        ? [
                                            BoxShadow(
                                                color:
                                                    stepColor.withAlpha(80),
                                                blurRadius: 12,
                                                offset:
                                                    const Offset(0, 2))
                                          ]
                                        : null,
                                  ),
                                  child: isDone
                                      ? const Icon(Icons.check,
                                          size: 16, color: Colors.white)
                                      : Icon(
                                          _statusIcon(label),
                                          size: isCurrent ? 18 : 14,
                                          color: isCurrent
                                              ? Colors.white
                                              : Colors.grey.shade400,
                                        ),
                                ),
                                if (i < statusFlow.length - 1)
                                  Expanded(
                                    child: Container(
                                      height: 3,
                                      color: isDone
                                          ? _statusColor(
                                              statusFlow[i + 1]['status']
                                                  as String)
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCurrent
                                    ? stepColor
                                    : Colors.grey.shade400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          if (isCancelled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.red.withAlpha(25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cancel,
                            color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order Cancelled',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.red)),
                            Text('This order has been cancelled',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('ORDER ITEMS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 1)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 12,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Column(
                  children: [
                    ...List.generate(_items.length, (i) {
                      final item = _items[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: i < _items.length - 1
                              ? Border(
                                  bottom: BorderSide(
                                      color: Colors.grey.withAlpha(20)))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: primary.withAlpha(12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: primary)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['product_name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Qty: ${item['quantity']} × ₹${item['product_price']?.toStringAsFixed(0) ?? '0'}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${item['subtotal']?.toStringAsFixed(2) ?? '0.00'}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: primary),
                            ),
                          ],
                        ),
                      );
                    }),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primary.withAlpha(6),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(18)),
                      ),
                      child: Row(
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(
                            '₹${_order['total_amount']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('PAYMENT',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 1)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 12,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.payment,
                          color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Method',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            '${_order['payment_method']?.toUpperCase() ?? ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.green.withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          const Text('COD',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('CUSTOMER',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 1)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 12,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primary, primary.withAlpha(180)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              (_order['user_name']?.toString() ?? 'U')[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_order['user_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              if (_order['user_email'] != null)
                                Text(_order['user_email'],
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        if (_order['user_phone'] != null &&
                            _order['user_phone'].toString().isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                _callPhone('${_order['user_phone']}'),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.phone,
                                  size: 20, color: Colors.green.shade600),
                            ),
                          ),
                      ],
                    ),
                    if (gps != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(8),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.green.withAlpha(25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.my_location,
                                      size: 18, color: Colors.green),
                                ),
                                const SizedBox(width: 12),
                                const Text('GPS Location',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const Spacer(),
                                if (gps['maps_link'] != null)
                                  GestureDetector(
                                    onTap: () =>
                                        _openMaps(gps['maps_link']),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withAlpha(20),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.navigation,
                                              size: 14,
                                              color: Colors.blue.shade600),
                                          const SizedBox(width: 4),
                                          Text('Navigate',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      Colors.blue.shade600)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if ((gps['address_line2'] ?? '').isNotEmpty)
                              Text('${gps['address_line2']}',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade800)),
                            Text('${gps['address_line1'] ?? ''}',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600)),
                            if ((gps['landmark'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.flag,
                                      size: 14,
                                      color: Colors.amber.shade600),
                                  const SizedBox(width: 4),
                                  Text('${gps['landmark']}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber.shade700)),
                                ],
                              ),
                            ],
                            if (gps['latitude'] != null &&
                                gps['longitude'] != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withAlpha(10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.map,
                                        size: 13,
                                        color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${gps['latitude']?.toStringAsFixed(4) ?? ''}, ${gps['longitude']?.toStringAsFixed(4) ?? ''}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (deliveryAddr != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text('DELIVERY ADDRESS',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 1)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 12,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.location_on,
                                size: 22, color: Colors.blue),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Delivery Address',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(
                                    '${deliveryAddr['address_line1'] ?? ''}',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700)),
                                Text(
                                  '${deliveryAddr['city'] ?? ''}, ${deliveryAddr['state'] ?? ''} ${deliveryAddr['pincode'] ?? ''}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500),
                                ),
                                if ((deliveryAddr['landmark'] ?? '')
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      children: [
                                        Icon(Icons.flag,
                                            size: 14,
                                            color: Colors.amber.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                            '${deliveryAddr['landmark']}',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color:
                                                    Colors.amber.shade700)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (deliveryAddr['maps_link'] != null) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _openMaps(deliveryAddr['maps_link']),
                            icon: const Icon(Icons.map, size: 18),
                            label: const Text('Open in Google Maps'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: BorderSide(
                                  color: Colors.blue.withAlpha(50)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _changeStatus,
                  icon: const Icon(Icons.swap_horiz, size: 20),
                  label: const Text('Change Status',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
