import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';
import 'admin_order_detail_page.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _api = AdminApiService();
  List<dynamic> _orders = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getOrders();
      if (!mounted) return;
      setState(() { _orders = data; _filtered = List.from(data); _loading = false; });
      _applyFilters();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _orders.where((o) {
        final ord = o as Map<String, dynamic>;
        final statusMatch = _statusFilter == 'All' || ord['status'] == _statusFilter;
        final searchLower = _search.toLowerCase();
        final searchMatch = _search.isEmpty ||
            (ord['id']?.toString().toLowerCase() ?? '').contains(searchLower) ||
            (ord['user_name']?.toString().toLowerCase() ?? '').contains(searchLower) ||
            (ord['total_amount']?.toString() ?? '').contains(searchLower);
        return statusMatch && searchMatch;
      }).toList();
    });
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

  Color _statusBg(String status) {
    return _statusColor(status).withAlpha(20);
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

  void _changeStatus(String orderId, String currentStatus) {
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
                  decoration: BoxDecoration(color: _statusBg(currentStatus), borderRadius: BorderRadius.circular(12)),
                  child: Text(currentStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(currentStatus))),
                ),
              ],
            ),
            const Divider(height: 28),
            ...statuses.where((s) => s != currentStatus).map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _statusBg(s).withAlpha(30),
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
                    await _api.updateOrderStatus(orderId, s);
                    if (!context.mounted) return;
                    _load();
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
    final statuses = ['All', 'Pending', 'Confirmed', 'Shipped', 'Delivered', 'Cancelled'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
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
                            child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text('Manage all orders', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                onChanged: (v) { _search = v; _applyFilters(); },
                decoration: InputDecoration(
                  hintText: 'Search orders by ID, user, amount...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.withAlpha(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: statuses.map((s) {
                  final active = _statusFilter == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : Colors.grey.shade600)),
                      selected: active,
                      onSelected: (_) { setState(() => _statusFilter = s); _applyFilters(); },
                      selectedColor: s == 'All' ? primary : _statusColor(s),
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.grey.withAlpha(15),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade200),
                    const SizedBox(height: 12),
                    Text('No orders found', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                    if (_search.isNotEmpty || _statusFilter != 'All') ...[
                      const SizedBox(height: 4),
                      Text('Try adjusting your filters', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                    ],
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final o = _filtered[i] as Map<String, dynamic>;
                    final items = (o['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                    final statusColor = _statusColor(o['status']);
                    final statusBg = _statusBg(o['status']);
                    final userInitial = (o['user_name']?.toString() ?? 'U')[0].toUpperCase();
                    final shortId = o['id'].toString().length > 8 ? o['id'].toString().substring(0, 8) : o['id'].toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Material(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetailPage(order: o))).then((_) => _load()),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Container(
                                  width: 5,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 36, height: 36,
                                              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                                              child: Icon(_statusIcon(o['status']), size: 18, color: statusColor),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Order #$shortId', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                                                        child: Text(o['status'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text('${items.length} item(s)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text('₹${o['total_amount']?.toStringAsFixed(0) ?? '0'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primary)),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Container(
                                              width: 24, height: 24,
                                              decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                                              child: Text(userInitial, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(o['user_name'] ?? 'Unknown', style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                        if (o['user_gps_address'] != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.my_location, size: 16, color: Colors.deepPurple.shade400),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'GPS: ${o['user_gps_address']['address_line1'] ?? ''}',
                                                  style: TextStyle(fontSize: 11, color: Colors.deepPurple.shade600),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade300),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
