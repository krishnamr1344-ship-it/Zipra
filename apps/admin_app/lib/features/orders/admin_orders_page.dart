import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api_service.dart';
import 'admin_order_detail_page.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage>
    with SingleTickerProviderStateMixin {
  final _api = AdminApiService();
  List<dynamic> _orders = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _statusFilter = 'All';
  late TabController _tabController;

  static const _tabs = ['All', 'New', 'Processing', 'Completed'];
  static const _tabStatusMap = {
    'All': ['All'],
    'New': ['Pending', 'Confirmed'],
    'Processing': ['Shipped'],
    'Completed': ['Delivered', 'Cancelled'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final tab = _tabs[_tabController.index];
    setState(() {
      _statusFilter = tab;
    });
    _applyFilters();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      final allowedStatuses = _tabStatusMap[_statusFilter] ?? ['All'];
      final filterAll = allowedStatuses.contains('All');

      _filtered = _orders.where((o) {
        final ord = o as Map<String, dynamic>;
        final statusMatch =
            filterAll || allowedStatuses.contains(ord['status']);
        final searchLower = _search.toLowerCase();
        final searchMatch = _search.isEmpty ||
            (ord['id']?.toString().toLowerCase() ?? '')
                .contains(searchLower) ||
            (ord['user_name']?.toString().toLowerCase() ?? '')
                .contains(searchLower) ||
            (ord['total_amount']?.toString() ?? '').contains(searchLower);
        return statusMatch && searchMatch;
      }).toList();
    });
  }

  Color _statusColor(String status) => AppColors.statusColor(status);

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_bottom_rounded;
      case 'Confirmed':
        return Icons.check_circle_outline_rounded;
      case 'Shipped':
        return Icons.local_shipping_rounded;
      case 'Delivered':
        return Icons.inventory_2_rounded;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline_rounded;
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

  int _tabCount(String tab) {
    final statuses = _tabStatusMap[tab] ?? [];
    if (statuses.contains('All')) return _orders.length;
    return _orders
        .where((o) => statuses.contains((o as Map)['status']))
        .length;
  }

  void _deleteOrder(String orderId) async {
    try {
      await _api.deleteOrder(orderId);
      if (!mounted) return;
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        adminSnackBar('Order deleted', isError: true),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          adminSnackBar('$e', isError: true),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _orders
        .where((o) => (o as Map)['status'] == 'Pending')
        .length;
    final totalRev = _orders.fold<double>(
      0,
      (sum, o) => sum + ((o as Map)['total_amount'] ?? 0).toDouble(),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(pending, totalRev),
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int pending, double totalRev) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Orders',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('Manage all orders',
                          style:
                              TextStyle(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(30),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '${_orders.length}',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _StatCard(
                    icon: Icons.receipt_long_rounded,
                    label: 'Total',
                    value: '${_orders.length}',
                    color: Colors.white,
                    bgColor: Colors.white.withAlpha(20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _StatCard(
                    icon: Icons.hourglass_bottom_rounded,
                    label: 'Pending',
                    value: '$pending',
                    color: const Color(0xFFFBBF24),
                    bgColor: AppColors.warning.withAlpha(25),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _StatCard(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Revenue',
                    value: '₹${totalRev.toStringAsFixed(0)}',
                    color: const Color(0xFF34D399),
                    bgColor: AppColors.success.withAlpha(25),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
      child: TextField(
        onChanged: (v) {
          _search = v;
          _applyFilters();
        },
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by ID, name, amount...',
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textHint, size: 22),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textHint),
                  onPressed: () {
                    _search = '';
                    _applyFilters();
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(color: AppColors.divider.withAlpha(80)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(color: AppColors.divider.withAlpha(80)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 6),
        itemCount: _tabs.length,
        itemBuilder: (context, i) {
          final tab = _tabs[i];
          final active = _statusFilter == tab;
          final count = _tabCount(tab);
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(i);
                setState(() => _statusFilter = tab);
                _applyFilters();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: active
                        ? AppColors.accent
                        : AppColors.divider.withAlpha(120),
                  ),
                  boxShadow: active
                      ? [AppShadows.medium]
                      : [AppShadows.soft],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: active ? Colors.white : AppColors.textSecondary,
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
                              : AppColors.accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_filtered.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 100),
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      itemCount: _filtered.length,
      itemBuilder: (context, i) => _buildOrderCard(_filtered[i]),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 100),
      itemCount: 6,
      itemBuilder: (ctx, idx) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: _ShimmerWidget(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceDim,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded,
                size: 48, color: AppColors.accentLight),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('No orders found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _search.isNotEmpty
                ? 'Try a different search term'
                : 'No orders in this category yet',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
          if (_search.isNotEmpty || _statusFilter != 'All') ...[
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _search = '';
                  _statusFilter = 'All';
                  _tabController.animateTo(0);
                });
                _applyFilters();
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Clear filters'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCard(dynamic orderData) {
    final o = orderData as Map<String, dynamic>;
    final items =
        (o['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final statusColor = _statusColor(o['status'] ?? '');
    final userInitial = (o['user_name']?.toString() ?? 'U')[0].toUpperCase();
    final shortId = o['id'].toString().length > 8
        ? o['id'].toString().substring(0, 8)
        : o['id'].toString();
    final timeAgo = _timeAgo(o['created_at']?.toString());

    return Dismissible(
      key: Key(o['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xxl),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.error, AppColors.error.withAlpha(200)]),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl)),
            title: const Text('Delete Order?'),
            content: Text(
                'Delete order #$shortId? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteOrder(o['id']),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminOrderDetailPage(order: o),
          ),
        ).then((_) => _load()),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [AppShadows.soft],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(AppRadius.lg)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(15),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(
                                _statusIcon(o['status'] ?? ''),
                                size: 20,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '#$shortId',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color:
                                                AppColors.textPrimary),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      _StatusBadge(
                                        status: o['status'] ?? '',
                                        color: statusColor,
                                        icon: _statusIcon(
                                            o['status'] ?? ''),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${items.length} item${items.length != 1 ? 's' : ''} · $timeAgo',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${o['total_amount']?.toStringAsFixed(0) ?? '0'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${o['payment_method'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDim,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: AppColors.accentGradient,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Center(
                                  child: Text(
                                    userInitial,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  o['user_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 18, color: AppColors.textHint),
                            ],
                          ),
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
          borderRadius: BorderRadius.circular(AppRadius.md),
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
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

class _ShimmerWidget extends StatefulWidget {
  final Widget child;
  const _ShimmerWidget({required this.child});

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                AppColors.surfaceDim,
                AppColors.surfaceDark,
                AppColors.surfaceDim,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(rect);
          },
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}
