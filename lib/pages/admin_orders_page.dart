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
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;
  bool _hasMore = true;
  int _page = 1;
  String _search = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  Future<void> _load({int page = 1, bool append = false}) async {
    if (append) {
      setState(() { _loadingMore = true; });
    } else {
      setState(() { _loading = true; _error = false; });
    }
    try {
      final data = await _api.getOrders(page: page);
      if (!mounted) return;
      setState(() {
        if (append) {
          _allOrders.addAll(data.cast<Map<String, dynamic>>());
          if (data.length < 50) _hasMore = false;
          _loadingMore = false;
        } else {
          _allOrders = data.cast<Map<String, dynamic>>();
          _filtered = List.from(_allOrders);
          _loading = false;
          _page = 1;
          _hasMore = true;
        }
      });
      _applyFilters();
    } catch (e) {
        debugPrint("pages.admin_orders_page: $e");
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = !append;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        _hasMore &&
        !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    _page++;
    await _load(page: _page, append: true);
  }

  void _applyFilters() {
    setState(() {
      _filtered = _allOrders.where((o) {
        final statusMatch =
            _statusFilter == 'All' || o['status'] == _statusFilter;
        final searchLower = _search.toLowerCase();
        final searchMatch = _search.isEmpty ||
            (o['id']?.toString().toLowerCase() ?? '').contains(searchLower) ||
            (o['user_name']?.toString().toLowerCase() ?? '')
                .contains(searchLower) ||
            (o['total_amount']?.toString() ?? '').contains(searchLower);
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
      case 'Out For Delivery':
        return const Color(0xFF9C27B0);
      case 'Delivered':
        return const Color(0xFF10B981);
      case 'Cancelled':
        return const Color(0xFFEF4444);
      case 'Failed':
        return const Color(0xFFDC2626);
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
      case 'Out For Delivery':
        return Icons.directions_bike;
      case 'Delivered':
        return Icons.inventory_2;
      case 'Cancelled':
        return Icons.cancel_outlined;
      case 'Failed':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  int _countByStatus(String status) {
    if (status == 'All') return _allOrders.length;
    return _allOrders.where((o) => o['status'] == status).length;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    final statuses = [
      'All',
      'Pending',
      'Confirmed',
      'Shipped',
      'Out For Delivery',
      'Delivered',
      'Cancelled',
      'Failed'
    ];

    final pending = _countByStatus('Pending');
    final totalRev = _allOrders.fold<double>(
      0,
      (sum, o) => sum + (o['total_amount'] ?? 0).toDouble(),
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: primary,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
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
                                color: Colors.white.withValues(alpha: 0.1),
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
                              value: '${_allOrders.length}',
                              color: Colors.white,
                              bgColor: Colors.white.withValues(alpha: 0.08),
                            ),
                            const SizedBox(width: 10),
                            _StatCard(
                              icon: Icons.hourglass_bottom,
                              label: 'Pending',
                              value: '$pending',
                              color: const Color(0xFFFBBF24),
                              bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            ),
                            const SizedBox(width: 10),
                            _StatCard(
                              icon: Icons.currency_rupee,
                              label: 'Revenue',
                              value: '₹${totalRev.toStringAsFixed(0)}',
                              color: const Color(0xFF34D399),
                              bgColor: const Color(0xFF10B981).withValues(alpha: 0.15),
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
                        TextStyle(color: AppColors.textHint, fontSize: 14),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: AppColors.textHint),
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
                    fillColor: AppColors.chipBg,
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
                            color: active ? tabColor : AppColors.chipBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: active
                                  ? tabColor
                                  : AppColors.divider,
                            ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: tabColor.withValues(alpha: 0.25),
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
                                    : AppColors.textSecondary,
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
                                      : AppColors.textSecondary,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : tabColor.withValues(alpha: 0.12),
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
                      if (i >= _filtered.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final o = _filtered[i];
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
                      return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
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
                                                        statusColor.withValues(alpha: 0.1),
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
                                                              color: AppColors
                                                                  .textSecondary,
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
                                                        color: AppColors
                                                            .textHint,
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
                                                            .withValues(alpha: 0.7),
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
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Icon(Icons.chevron_right,
                                                    size: 18,
                                                    color: AppColors.divider),
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
                    childCount: _filtered.length + (_loadingMore ? 1 : 0),
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
                color: color.withValues(alpha: 0.7),
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
        color: color.withValues(alpha: 0.1),
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
