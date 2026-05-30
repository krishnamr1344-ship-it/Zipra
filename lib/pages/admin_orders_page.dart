import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';
import '../widgets/state_widgets.dart';
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
  bool _error = false;
  String _search = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final data = await _api.getOrders();
      if (!mounted) return;
      setState(() {
        _orders = data;
        _filtered = List.from(data);
        _loading = false;
      });
      _applyFilters();
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _orders.where((o) {
        final ord = o as Map<String, dynamic>;
        final statusMatch =
            _statusFilter == 'All' || ord['status'] == _statusFilter;
        final searchLower = _search.toLowerCase();
        final searchMatch = _search.isEmpty ||
            (ord['id']?.toString().toLowerCase() ?? '').contains(searchLower) ||
            (ord['user_name']?.toString().toLowerCase() ?? '')
                .contains(searchLower) ||
            (ord['total_amount']?.toString() ?? '').contains(searchLower);
        return statusMatch && searchMatch;
      }).toList();
    });
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

  String _timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.length < 19) return '';
    try {
      final dt = DateTime.parse(dateStr.substring(0, 19));
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 7) return '${dt.day}/${dt.month}/${dt.year}';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return dateStr.substring(0, 10);
    }
  }

  int _countByStatus(String status) {
    if (status == 'All') return _orders.length;
    return _orders.where((o) => (o as Map)['status'] == status).length;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final statuses = [
      'All',
      'Pending',
      'Confirmed',
      'Shipped',
      'Delivered',
      'Cancelled'
    ];

    final pending = _countByStatus('Pending');
    final totalRev = _orders.fold<double>(
      0,
      (sum, o) => sum + ((o as Map)['total_amount'] ?? 0).toDouble(),
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
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
                              child: const Icon(Icons.receipt_long,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Orders',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                Text('Manage all orders',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.white70)),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _StatCard(
                              icon: Icons.receipt_long,
                              label: 'Total',
                              value: '${_orders.length}',
                              color: Colors.white,
                              bgColor: Colors.white.withAlpha(20),
                            ),
                            const SizedBox(width: 10),
                            _StatCard(
                              icon: Icons.hourglass_bottom,
                              label: 'Pending',
                              value: '$pending',
                              color: const Color(0xFFFBBF24),
                              bgColor: const Color(0xFFF59E0B).withAlpha(25),
                            ),
                            const SizedBox(width: 10),
                            _StatCard(
                              icon: Icons.currency_rupee,
                              label: 'Revenue',
                              value: '₹${totalRev.toStringAsFixed(0)}',
                              color: const Color(0xFF34D399),
                              bgColor: const Color(0xFF10B981).withAlpha(25),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TextField(
                  onChanged: (v) {
                    _search = v;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by ID, name, amount...',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: Colors.grey.shade400),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _search = '';
                              _applyFilters();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.withAlpha(8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: statuses.map((s) {
                    final active = _statusFilter == s;
                    final count = _countByStatus(s);
                    final tabColor = s == 'All' ? primary : _statusColor(s);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _statusFilter = s);
                          _applyFilters();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: active ? tabColor : Colors.grey.withAlpha(12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: active
                                  ? tabColor
                                  : Colors.grey.withAlpha(30),
                            ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: tabColor.withAlpha(60),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s == 'All'
                                    ? Icons.all_inclusive
                                    : _statusIcon(s),
                                size: 16,
                                color: active
                                    ? Colors.white
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                s,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      active ? FontWeight.w700 : FontWeight.w600,
                                  color: active
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Colors.white.withAlpha(30)
                                        : tabColor.withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: active
                                          ? Colors.white
                                          : tabColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: LoadingWidget(message: 'Loading orders\u2026'),
              )
            else if (_error)
              const SliverFillRemaining(child: ErrorStateWidget())
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                child: _search.isNotEmpty || _statusFilter != 'All'
                    ? EmptyStateWidget(
                        icon: Icons.search_off,
                        title: 'No orders found',
                        subtitle: 'Try adjusting your search or filters',
                        actionLabel: 'Clear filters',
                        onAction: () {
                          setState(() { _search = ''; _statusFilter = 'All'; });
                          _applyFilters();
                        },
                      )
                    : const EmptyStateWidget(
                        icon: Icons.receipt_long,
                        title: 'No orders yet',
                        subtitle: 'Orders will appear here once customers place them',
                      ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final o = _filtered[i] as Map<String, dynamic>;
                      final items =
                          (o['items'] as List?)?.cast<Map<String, dynamic>>() ??
                              [];
                      final statusColor = _statusColor(o['status']);
                      final userInitial =
                          (o['user_name']?.toString() ?? 'U')[0]
                              .toUpperCase();
                      final shortId = o['id'].toString().length > 8
                          ? o['id'].toString().substring(0, 8)
                          : o['id'].toString();
                      final timeAgo = _timeAgo(o['created_at']?.toString());

                      return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(5),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminOrderDetailPage(order: o),
                                ),
                              ).then((_) => _load()),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius:
                                            const BorderRadius.horizontal(
                                                left: Radius.circular(18)),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        statusColor.withAlpha(15),
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    _statusIcon(o['status']),
                                                    size: 20,
                                                    color: statusColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            '#$shortId',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontSize: 15),
                                                          ),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text(
                                                            timeAgo,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .grey
                                                                  .shade400,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          _StatusBadge(
                                                            status:
                                                                o['status'] ?? '',
                                                            color: statusColor,
                                                            icon: _statusIcon(
                                                                o['status']),
                                                          ),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text(
                                                            '${items.length} item${items.length != 1 ? 's' : ''}',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .grey
                                                                  .shade500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '₹${o['total_amount']?.toStringAsFixed(0) ?? '0'}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 17,
                                                        color: primary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${o['payment_method'] ?? ''}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors
                                                            .grey.shade400,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Container(
                                                  width: 26,
                                                  height: 26,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        primary,
                                                        primary
                                                            .withAlpha(180),
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      userInitial,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    o['user_name'] ??
                                                        'Unknown',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Icon(Icons.chevron_right,
                                                    size: 18,
                                                    color:
                                                        Colors.grey.shade300),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
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
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.status,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
