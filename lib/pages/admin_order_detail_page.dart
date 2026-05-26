import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Confirmed': return Colors.blue;
      case 'Shipped': return Colors.purple;
      case 'Delivered': return Colors.green;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Pending': return Icons.hourglass_empty;
      case 'Confirmed': return Icons.check_circle_outline;
      case 'Shipped': return Icons.local_shipping;
      case 'Delivered': return Icons.inventory_2;
      case 'Cancelled': return Icons.cancel_outlined;
      default: return Icons.help_outline;
    }
  }

  void _changeStatus() {
    final statuses = ['Confirmed', 'Shipped', 'Delivered', 'Cancelled'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.swap_horiz, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Text('Update Status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Current: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: _statusColor(_order['status']).withAlpha(20), borderRadius: BorderRadius.circular(12)),
                  child: Text(_order['status'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(_order['status']))),
                ),
              ],
            ),
            const Divider(height: 28),
            ...statuses.where((s) => s != _order['status']).map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _statusColor(s).withAlpha(20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _statusColor(s).withAlpha(40)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _statusColor(s).withAlpha(25), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_statusIcon(s), size: 20, color: _statusColor(s)),
                ),
                title: Text(s, style: TextStyle(fontWeight: FontWeight.w600, color: _statusColor(s))),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.updateOrderStatus(_order['id'], s);
                    if (!context.mounted) return;
                    setState(() { _order['status'] = s; });
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final statusColor = _statusColor(_order['status']);
    final gps = _order['user_gps_address'] as Map<String, dynamic>?;
    final deliveryAddr = _order['delivery_address'] as Map<String, dynamic>?;
    final shortId = _order['id'].toString().length > 8 ? _order['id'].toString().substring(0, 8) : _order['id'].toString();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: primary,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withAlpha(180), const Color(0xFF1A1A2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                            child: Icon(_statusIcon(_order['status']), color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Order #$shortId', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('${_order['user_name'] ?? 'Unknown'}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(40),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withAlpha(100)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon(_order['status']), size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(_order['status'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.white60),
                          const SizedBox(width: 6),
                          Text(_order['created_at']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          const Spacer(),
                          Text('₹${_order['total_amount']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('ORDER ITEMS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    ...List.generate(_items.length, (i) {
                      final item = _items[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: i < _items.length - 1 ? Border(bottom: BorderSide(color: Colors.grey.withAlpha(20))) : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(color: primary.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                              child: Center(child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: primary))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  Text('Qty: ${item['quantity']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Text('₹${item['subtotal']?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
                          ],
                        ),
                      );
                    }),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primary.withAlpha(8),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                      ),
                      child: Row(
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('₹${_order['total_amount']?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary)),
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
              child: Text('PAYMENT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1)),
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
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.amber.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.payment, color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Method', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          Text('${_order['payment_method']?.toUpperCase() ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          const Text('Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
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
              child: Text('USER DETAILS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1)),
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
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.blue, Colors.blue.withAlpha(180)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(child: Text((_order['user_name']?.toString() ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_order['user_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              if (_order['user_email'] != null)
                                Text(_order['user_email'], style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        if (_order['user_phone'] != null && _order['user_phone'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone, size: 12, color: Colors.green.shade600),
                                const SizedBox(width: 4),
                                Text('${_order['user_phone']}', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (gps != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.withAlpha(30)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.my_location, size: 16, color: Colors.green),
                                ),
                                const SizedBox(width: 10),
                                const Text('User GPS Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if ((gps['address_line2'] ?? '').isNotEmpty)
                              Text('${gps['address_line2']}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.green.shade800)),
                            Text('${gps['address_line1'] ?? ''}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            if ((gps['landmark'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.flag, size: 14, color: Colors.amber.shade600),
                                  const SizedBox(width: 4),
                                  Text('${gps['landmark']}', style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
                                ],
                              ),
                            ],
                            if (gps['latitude'] != null && gps['longitude'] != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.map, size: 14, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Text('${gps['latitude']?.toStringAsFixed(4) ?? ''}, ${gps['longitude']?.toStringAsFixed(4) ?? ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                  const Spacer(),
                                  if (gps['maps_link'] != null)
                                    GestureDetector(
                                      onTap: () => _openMaps(gps['maps_link']),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.open_in_new, size: 12, color: Colors.blue.shade600),
                                            const SizedBox(width: 4),
                                            Text('Navigate', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue.shade600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
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
                child: Text('DELIVERY ADDRESS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1)),
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
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.location_on, size: 20, color: Colors.blue),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Delivery Address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('${deliveryAddr['address_line1'] ?? ''}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                Text('${deliveryAddr['city'] ?? ''}, ${deliveryAddr['state'] ?? ''} ${deliveryAddr['pincode'] ?? ''}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                                if ((deliveryAddr['landmark'] ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.flag, size: 14, color: Colors.amber.shade600),
                                        const SizedBox(width: 4),
                                        Text('${deliveryAddr['landmark']}', style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (deliveryAddr['maps_link'] != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openMaps(deliveryAddr['maps_link']),
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('Open in Google Maps'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: BorderSide(color: Colors.blue.withAlpha(60)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _changeStatus,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
