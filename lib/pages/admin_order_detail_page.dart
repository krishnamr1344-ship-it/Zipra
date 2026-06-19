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
    } catch (e) {
        debugPrint("pages.admin_order_detail_page: $e");}
  }

  void _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
        debugPrint("pages.admin_order_detail_page: $e");}
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
    final statuses = ['Confirmed', 'Shipped', 'Cancelled'];
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
                    color: _statusColor(_order['status']).withValues(alpha: 0.08),
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
                        color: _statusColor(s).withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _statusColor(s).withValues(alpha: 0.16)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _statusColor(s).withValues(alpha: 0.08),
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
                            color: _statusColor(s).withValues(alpha: 0.06),
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
            if (_order['status'] == 'Shipped') ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDeliveryOtpDialog();
                  },
                  icon: const Icon(Icons.inventory_2, size: 20),
                  label: const Text('Confirm Delivery',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeliveryOtpDialog() {
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Confirm Delivery',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ask the customer for their delivery code and enter it below.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '------',
                    hintStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.grey.shade300,
                    ),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final otp = otpController.text.trim();
                      if (otp.length != 6) return;
                      setDialogState(() => loading = true);
                      try {
                        await _api.deliverOrder(_order['id'], otp);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!context.mounted) return;
                        setState(() {
                          _order['status'] = 'Delivered';
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Order delivered successfully'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() => loading = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('$e'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verify & Deliver'),
            ),
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
      case 'Cancelled':
        return 'Cancel this order';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    final statusColor = _statusColor(_order['status']);
    final gps = _order['user_gps_address'] as Map<String, dynamic>?;
    final deliveryAddr =
        _order['delivery_address'] as Map<String, dynamic>?;
    final shortId = _order['id'].toString().length > 8
        ? _order['id'].toString().substring(0, 8)
        : _order['id'].toString();
    final statusFlow = _statusFlow;
    final isCancelled = _order['status'] == 'Cancelled';

    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade500,
      letterSpacing: 1,
    );

    final cardShadow = BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 3),
    );

    Widget sectionLabel(String text) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(text, style: labelStyle),
      );
    }

    Widget card({required Widget child}) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [cardShadow],
        ),
        child: child,
      );
    }

    Widget iconCircle({
      required IconData icon,
      required Color color,
      double size = 44,
      double iconSize = 20,
    }) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(size / 2.5),
        ),
        child: Icon(icon, color: color, size: iconSize),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.adminHeaderGradient,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Order #$shortId',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text(_order['user_name'] ?? 'Unknown',
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.white70)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon(_order['status']),
                                      size: 14, color: Colors.white),
                                  const SizedBox(width: 5),
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
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    _order['created_at']
                                            ?.toString()
                                            .substring(0, 10) ??
                                        '',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${_order['total_amount']?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!isCancelled && statusFlow.isNotEmpty)
            SliverToBoxAdapter(child: sectionLabel('ORDER PROGRESS')),
          if (!isCancelled && statusFlow.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                        final dotSize = isCurrent ? 32.0 : 24.0;

                        return Expanded(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  if (i > 0)
                                    Expanded(
                                      child: Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          gradient: isDone
                                              ? LinearGradient(
                                                  colors: [
                                                    _statusColor(statusFlow[i - 1]['status'] as String),
                                                    _statusColor(label),
                                                  ],
                                                )
                                              : null,
                                          color: isDone ? null : Colors.grey.shade200,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    width: dotSize,
                                    height: dotSize,
                                    decoration: BoxDecoration(
                                      color: isDone || isCurrent ? stepColor : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                      border: isCurrent
                                          ? Border.all(color: Colors.white, width: 3)
                                          : null,
                                      boxShadow: isCurrent
                                          ? [
                                              BoxShadow(
                                                color: stepColor.withValues(alpha: 0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isDone
                                        ? const Icon(Icons.check,
                                            size: 14, color: Colors.white)
                                        : Icon(
                                            _statusIcon(label),
                                            size: isCurrent ? 16 : 12,
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
                                            ? _statusColor(label)
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
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
            ),
          if (isCancelled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.cancel_rounded,
                            color: Color(0xFFEF4444), size: 26),
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
                                    color: Color(0xFFEF4444))),
                            SizedBox(height: 2),
                            Text('This order has been cancelled',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFEF4444))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(child: sectionLabel('ORDER ITEMS')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: card(
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
                                      color: Colors.grey.withValues(alpha: 0.08)))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
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
                                  const SizedBox(height: 3),
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
                        color: primary.withValues(alpha: 0.04),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(18)),
                      ),
                      child: Row(
                        children: [
                          Text('Total',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700)),
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
          SliverToBoxAdapter(child: sectionLabel('PAYMENT')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      iconCircle(
                        icon: Icons.payment_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Method',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 3),
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
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 14, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                            const Text('COD',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: sectionLabel('CUSTOMER')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primary, primary.withValues(alpha: 0.7)],
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
                                  const SizedBox(height: 1),
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
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.phone_rounded,
                                    size: 20, color: Colors.green.shade600),
                              ),
                            ),
                        ],
                      ),
                      if (gps != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(Icons.my_location_rounded,
                                        size: 18, color: Color(0xFF10B981)),
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
                                            horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
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
                              const SizedBox(height: 12),
                              if ((gps['address_line2'] ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text('${gps['address_line2']}',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green.shade800)),
                                ),
                              Text('${gps['address_line1'] ?? ''}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600)),
                              if ((gps['landmark'] ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.flag_rounded,
                                        size: 15,
                                        color: Colors.amber.shade600),
                                    const SizedBox(width: 5),
                                    Text('${gps['landmark']}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.amber.shade700)),
                                  ],
                                ),
                              ],
                              if (gps['latitude'] != null &&
                                  gps['longitude'] != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.map_rounded,
                                          size: 13,
                                          color: Colors.grey.shade400),
                                      const SizedBox(width: 5),
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
          ),
          if (deliveryAddr != null) ...[
            SliverToBoxAdapter(child: sectionLabel('DELIVERY ADDRESS')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            iconCircle(
                              icon: Icons.location_on_rounded,
                              color: const Color(0xFF3B82F6),
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
                                  const SizedBox(height: 8),
                                  Text(
                                      '${deliveryAddr['address_line1'] ?? ''}',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700)),
                                  const SizedBox(height: 2),
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
                                          Icon(Icons.flag_rounded,
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
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _openMaps(deliveryAddr['maps_link']),
                              icon: const Icon(Icons.map_rounded, size: 18),
                              label: const Text('Open in Google Maps'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF3B82F6),
                                side: BorderSide(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
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
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _order['status'] == 'Delivered'
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF10B981), size: 22),
                          const SizedBox(width: 10),
                          const Text('Delivered',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981))),
                        ],
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _changeStatus,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                        label: const Text('Change Status',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
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
