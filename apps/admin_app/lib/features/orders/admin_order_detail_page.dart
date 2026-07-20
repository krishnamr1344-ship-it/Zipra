import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/theme.dart';
import '../../core/api/admin_api_service.dart';

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
    _items =
        (widget.order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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

  Future<void> _load() async {
    try {
      final all = await _api.getOrders();
      final match = all.firstWhere(
        (o) => o['id'].toString() == _order['id'].toString(),
        orElse: () => _order,
      );
      if (!mounted) return;
      setState(() {
        _order = match;
        _items =
            (match['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      });
    } catch (_) {}
  }

  Color _statusColor(String status) => AppColors.statusColor(status);

  LinearGradient _statusGradient(String status) => AppColors.statusGradient(status);

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
    final idx = all.indexOf(_order['status'] == 'Cancelled'
        ? _order['previous_status'] ?? 'Pending'
        : _order['status']);
    if (idx <= 0) return 'Pending';
    return all[idx - 1];
  }

  void _changeStatus() {
    const validTransitions = {
      'Pending': ['Confirmed', 'Cancelled'],
      'Confirmed': ['Shipped', 'Cancelled'],
      'Shipped': ['Delivered', 'Cancelled'],
      'Delivered': <String>[],
      'Cancelled': <String>[],
    };
    final current = _order['status'] as String? ?? 'Pending';
    final statuses = validTransitions[current] ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _statusColor(_order['status']).withAlpha(20),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(_statusIcon(_order['status']),
                      color: _statusColor(_order['status']), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Update Status',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Current: ${_order['status']}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...statuses.where((s) => s != _order['status']).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await _api.updateOrderStatus(_order['id'], s);
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
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
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _statusColor(s).withAlpha(10),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                              color: _statusColor(s).withAlpha(30)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _statusColor(s).withAlpha(20),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(_statusIcon(s),
                                  size: 22, color: _statusColor(s)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: _statusColor(s))),
                                  const SizedBox(height: 2),
                                  Text(
                                    _statusSubtitle(s),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios,
                                size: 14, color: _statusColor(s).withAlpha(120)),
                          ],
                        ),
                      ),
                    ),
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
        return 'Accept the order and confirm stock';
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

  void _deleteOrder() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.delete_forever,
                  color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Delete Order?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. The order and all its data will be permanently removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg)),
                      side: const BorderSide(color: AppColors.surfaceDark),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await _api.deleteOrder(_order['id'].toString());
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Order deleted'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md)),
                          ),
                        );
                        Navigator.pop(context);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg)),
                      elevation: 0,
                    ),
                    child: const Text('Delete',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_order['status']);
    final gps = _order['user_gps_address'] is Map<String, dynamic>
        ? _order['user_gps_address'] as Map<String, dynamic>
        : null;
    final deliveryAddr =
        _order['delivery_address'] is Map<String, dynamic>
            ? _order['delivery_address'] as Map<String, dynamic>
            : null;
    final shortId = _order['id'].toString().length > 8
        ? _order['id'].toString().substring(0, 8)
        : _order['id'].toString();
    final statusFlow = _statusFlow;
    final isCancelled = _order['status'] == 'Cancelled';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
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
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(AppRadius.md),
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
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text(_order['user_name'] ?? 'Unknown',
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.white60)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(35),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: statusColor.withAlpha(80)),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 58),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 13,
                                          color: Colors.white.withAlpha(150)),
                                      const SizedBox(width: 6),
                                      Text(
                                        (() {
                                          final s = _order['created_at']?.toString() ?? '';
                                          return s.length >= 10 ? s.substring(0, 10) : s;
                                        })(),
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white.withAlpha(180)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                '₹${(double.tryParse(_order['total_amount']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── STATUS HERO CARD ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: _statusGradient(_order['status']),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withAlpha(50),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(_statusIcon(_order['status']),
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_order['status'] ?? '',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            _order['status'] == 'Delivered'
                                ? 'Successfully delivered'
                                : _order['status'] == 'Cancelled'
                                    ? 'Order was cancelled'
                                    : 'In progress',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withAlpha(200)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Amount',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${(double.tryParse(_order['total_amount']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── ORDER TRACKER ──
          if (!isCancelled && statusFlow.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [AppShadows.soft],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ORDER TRACKER',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      Row(
                        children: statusFlow.asMap().entries.map((entry) {
                          final i = entry.key;
                          final step = entry.value;
                          final isDone = step['done'] as bool;
                          final isCurrent = step['current'] as bool;
                          final label = step['status'] as String;
                          final stepColor = isDone || isCurrent
                              ? _statusColor(label)
                              : AppColors.surfaceDark;

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
                                            color: isDone
                                                ? _statusColor(label)
                                                : AppColors.surfaceDark,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    Container(
                                      width: isCurrent ? 38 : 30,
                                      height: isCurrent ? 38 : 30,
                                      decoration: BoxDecoration(
                                        color: isDone || isCurrent
                                            ? stepColor
                                            : AppColors.surfaceDim,
                                        shape: BoxShape.circle,
                                        border: isCurrent
                                            ? Border.all(
                                                color: Colors.white, width: 3)
                                            : null,
                                        boxShadow: isCurrent
                                            ? [
                                                BoxShadow(
                                                    color: stepColor
                                                        .withAlpha(80),
                                                    blurRadius: 14,
                                                    offset:
                                                        const Offset(0, 3))
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
                                                  : AppColors.textHint,
                                            ),
                                    ),
                                    if (i < statusFlow.length - 1)
                                      Expanded(
                                        child: Container(
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: isDone
                                                ? _statusColor(
                                                    statusFlow[i + 1]['status']
                                                        as String)
                                                : AppColors.surfaceDark,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
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
                                        : AppColors.textHint,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── CANCELLED BANNER ──
          if (isCancelled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: AppColors.error.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(15),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(Icons.cancel,
                            color: AppColors.error, size: 24),
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
                                    color: AppColors.error)),
                            SizedBox(height: 2),
                            Text('This order has been cancelled',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── SECTION: ORDER ITEMS ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text('ORDER ITEMS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [AppShadows.soft],
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
                              ? const Border(
                                  bottom: BorderSide(
                                      color: AppColors.divider,
                                      width: 0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.accentBg,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Center(
                                child: Icon(Icons.shopping_bag,
                                    color: AppColors.accent, size: 22),
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
                                          fontSize: 15,
                                          color: AppColors.textPrimary)),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Qty: ${item['quantity']} × ₹${(double.tryParse(item['product_price']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${(double.tryParse(item['subtotal']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      );
                    }),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceDim,
                        borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(AppRadius.xl)),
                      ),
                      child: Row(
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const Spacer(),
                          Text(
                            '₹${(double.tryParse(_order['total_amount']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── SECTION: PAYMENT ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text('PAYMENT',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [AppShadows.soft],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.payment,
                          color: AppColors.warning, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Method',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 3),
                          Text(
                            '${_order['payment_method']?.toUpperCase() ?? ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: AppColors.success),
                          SizedBox(width: 4),
                          Text('COD',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── SECTION: CUSTOMER ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text('CUSTOMER',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [AppShadows.soft],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Center(
                            child: Text(
                              (_order['user_name']?.toString().isEmpty ?? true
                                      ? 'U'
                                      : _order['user_name'].toString()[0])
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
                                      fontSize: 16,
                                      color: AppColors.textPrimary)),
                              if (_order['user_email'] != null)
                                Text(_order['user_email'],
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
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
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Icon(Icons.phone,
                                  size: 20, color: AppColors.success),
                            ),
                          ),
                      ],
                    ),
                    if (gps != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.successLight.withAlpha(80),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                              color: AppColors.success.withAlpha(25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.successLight,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: const Icon(Icons.my_location,
                                      size: 18, color: AppColors.success),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text('GPS Location',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary)),
                                ),
                                if (gps['maps_link'] != null)
                                  GestureDetector(
                                    onTap: () =>
                                        _openMaps(gps['maps_link']),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.infoLight,
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.navigation,
                                              size: 14,
                                              color: AppColors.info),
                                          SizedBox(width: 4),
                                          Text('Navigate',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.info)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if ((gps['address_line2'] ?? '').isNotEmpty)
                              Text('${gps['address_line2']}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                            Text('${gps['address_line1'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                            if ((gps['landmark'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.flag,
                                      size: 14, color: AppColors.warning),
                                  const SizedBox(width: 4),
                                  Text('${gps['landmark']}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.warning)),
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
                                  color: AppColors.surfaceDim,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.map,
                                        size: 13,
                                        color: AppColors.textHint),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${gps['latitude']?.toStringAsFixed(4) ?? ''}, ${gps['longitude']?.toStringAsFixed(4) ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
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

          // ── SECTION: DELIVERY ADDRESS ──
          if (deliveryAddr != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Text('DELIVERY ADDRESS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [AppShadows.soft],
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
                              color: AppColors.infoLight,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(Icons.location_on,
                                size: 22, color: AppColors.info),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Delivery Address',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 6),
                                Text(
                                    '${deliveryAddr['address_line1'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary)),
                                Text(
                                  '${deliveryAddr['city'] ?? ''}, ${deliveryAddr['state'] ?? ''} ${deliveryAddr['pincode'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textHint),
                                ),
                                if ((deliveryAddr['landmark'] ?? '')
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.flag,
                                            size: 14,
                                            color: AppColors.warning),
                                        const SizedBox(width: 4),
                                        Text(
                                            '${deliveryAddr['landmark']}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.warning)),
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
                              foregroundColor: AppColors.info,
                              side: const BorderSide(
                                  color: AppColors.infoLight),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg)),
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

          // ── ACTION BUTTONS ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg)),
                    elevation: 0,
                    shadowColor: AppColors.accent.withAlpha(80),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _deleteOrder,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Delete Order',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.errorLight),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
