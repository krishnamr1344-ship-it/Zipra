import 'package:flutter/material.dart';
import 'package:zipra_shop/core/constants/theme.dart';
import 'package:zipra_shop/core/api/shop_api_service.dart';
import 'package:zipra_shop/core/utils/app_info.dart';
import 'package:zipra_shop/core/models/shop_model.dart';
import 'package:zipra_shop/core/models/shop_order.dart';
import 'package:zipra_shop/core/models/earning.dart';
import 'package:zipra_shop/features/auth/login_page.dart';
import 'package:zipra_shop/features/products/shop_products_page.dart';
import 'package:zipra_shop/features/orders/shop_orders_page.dart';
import 'package:zipra_shop/features/earnings/shop_earnings_page.dart';
import 'package:zipra_shop/features/profile/shop_profile_page.dart';
import 'package:zipra_shop/features/orders/shop_order_detail_page.dart';
import 'package:zipra_shop/features/profile/settings_page.dart';

class ShopHomePage extends StatefulWidget {
  const ShopHomePage({super.key});

  @override
  State<ShopHomePage> createState() => _ShopHomePageState();
}

class _ShopHomePageState extends State<ShopHomePage> {
  final _api = ShopApiService();
  int _currentIndex = 0;

  ShopModel? _shop;
  int _newOrders = 0;
  int _pendingProducts = 0;
  int _totalProducts = 0;
  double _todayEarnings = 0;
  List<dynamic> _recentOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final shop = await _api.getShopProfile();
      final newOrdersList = await _api.getOrders(status: 'new');
      final allProducts = await _api.getProducts();
      final summaryData = await _api.getEarningsSummary();
      final allOrders = await _api.getOrders();
      if (!mounted) return;
      final summary = EarningSummary.fromJson(summaryData);
      setState(() {
        _shop = ShopModel.fromJson(shop);
        _newOrders = newOrdersList.length;
        _totalProducts = allProducts.length;
        _pendingProducts = allProducts
            .where((p) => (p as Map<String, dynamic>)['approval_status'] == 'pending')
            .length;
        _todayEarnings = summary.today;
        _recentOrders = allOrders.take(10).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  Future<void> _toggleOpen() async {
    try {
      final msg = await _api.toggleOpen();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _api.logout();
              if (!mounted) return;
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].substring(0, parts[0].length > 2 ? 2 : parts[0].length).toUpperCase();
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _orderStatusLabel(String? status) {
    switch (status) {
      case 'new':
        return 'New';
      case 'accepted':
        return 'Accepted';
      case 'packing':
        return 'Packing';
      case 'ready_for_pickup':
        return 'Ready';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status ?? 'Unknown';
    }
  }

  Color _orderStatusColor(String? status) {
    switch (status) {
      case 'new':
        return AppColors.primary;
      case 'accepted':
        return AppColors.info;
      case 'packing':
        return AppColors.warning;
      case 'ready_for_pickup':
        return AppColors.accent;
      case 'out_for_delivery':
        return AppColors.info;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _currentIndex,
      children: [
        _buildDashboardTab(),
        const ShopProductsPage(),
        const ShopOrdersPage(),
        const ShopEarningsPage(),
        _buildProfileTab(),
      ],
    );
  }

  // ─── DASHBOARD TAB ─────────────────────────────────────────────

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: _loading ? _buildShimmerLoading() : _buildDashboardContent(),
    );
  }

  Widget _buildDashboardContent() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeaderPanel()),
        SliverToBoxAdapter(child: _buildStatCards()),
        SliverToBoxAdapter(child: _buildQuickActions()),
        SliverToBoxAdapter(child: _buildRecentOrders()),
        SliverToBoxAdapter(child: _buildYourShopSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ─── HEADER PANEL ──────────────────────────────────────────────

  Widget _buildHeaderPanel() {
    final isOpen = _shop?.isOpen == true;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(_shop?.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _shop?.name ?? 'My Shop',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                    icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOpen ? AppColors.success : AppColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isOpen ? AppColors.success : AppColors.error)
                                .withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOpen ? 'Shop is Open' : 'Shop is Closed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (_shop?.city != null)
                            Text(
                              '${_shop!.city}${_shop!.state != null ? ', ${_shop!.state}' : ''}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: isOpen,
                        onChanged: (_) => _toggleOpen(),
                        activeThumbColor: AppColors.success,
                        activeTrackColor: AppColors.success.withValues(alpha: 0.4),
                        inactiveThumbColor: AppColors.error,
                        inactiveTrackColor: AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── STAT CARDS ────────────────────────────────────────────────

  Widget _buildStatCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: "Today's Revenue",
                  value: _formatCurrency(_todayEarnings),
                  icon: Icons.account_balance_wallet_rounded,
                  gradient: AppColors.primaryGradient,
                  onTap: () => setState(() { _currentIndex = 3; }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'New Orders',
                  value: '$_newOrders',
                  icon: Icons.shopping_bag_rounded,
                  gradient: AppColors.warningGradient,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShopOrdersPage()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Products',
                  value: '$_totalProducts',
                  icon: Icons.inventory_2_rounded,
                  gradient: AppColors.successGradient,
                  onTap: () => setState(() { _currentIndex = 1; }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Pending Approval',
                  value: '$_pendingProducts',
                  icon: Icons.pending_actions_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => setState(() { _currentIndex = 1; }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── QUICK ACTIONS ─────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.add_box_rounded,
                  title: 'Add Product',
                  gradient: AppColors.accentGradient,
                   onTap: () => setState(() { _currentIndex = 1; }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'View Orders',
                  gradient: AppColors.primaryGradient,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShopOrdersPage()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── RECENT ORDERS ─────────────────────────────────────────────

  Widget _buildRecentOrders() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Orders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShopOrdersPage()),
                  ),
                  child: const Text('See All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_recentOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [AppShadows.soft],
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    const Text(
                      'No orders yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Orders will appear here',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _recentOrders.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final o = _recentOrders[index];
                  final orderId = o['id'] ?? o['order_id'] ?? '';
                  final status = o['status'] as String?;
                  final total = (o['total_amount'] as num?)?.toDouble() ?? 0;
                  final itemCount = o['item_count'] ?? 0;
                  final createdAt = o['created_at'] as String?;
                  DateTime? orderDate;
                  if (createdAt != null) {
                    try {
                      orderDate = DateTime.parse(createdAt);
                    } catch (_) {}
                  }
                  final timeAgo = orderDate != null ? _getTimeAgo(orderDate) : '';
                  return _RecentOrderCard(
                    orderId: orderId.toString().substring(0, orderId.toString().length > 8 ? 8 : orderId.toString().length),
                    status: status,
                    statusLabel: _orderStatusLabel(status),
                    statusColor: _orderStatusColor(status),
                    total: total,
                    itemCount: itemCount is int ? itemCount : 0,
                    timeAgo: timeAgo,
                    onTap: () async {
                      try {
                        final data = await _api.getOrder(orderId.toString());
                        if (!mounted) return;
                        final order = ShopOrder.fromJson(data);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ShopOrderDetailPage(order: order)),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to load order: $e')),
                        );
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ─── YOUR SHOP ─────────────────────────────────────────────────

  Widget _buildYourShopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Shop',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [AppShadows.medium],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(_shop?.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _shop?.name ?? 'My Shop',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _shop?.email ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_shop?.phone != null && _shop!.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _shop!.phone!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ShopStatItem(
                      label: 'Products',
                      value: '$_totalProducts',
                      icon: Icons.inventory_2_rounded,
                    ),
                    _ShopStatItem(
                      label: 'New Orders',
                      value: '$_newOrders',
                      icon: Icons.shopping_bag_rounded,
                    ),
                    _ShopStatItem(
                      label: 'Revenue',
                      value: _formatCurrency(_todayEarnings),
                      icon: Icons.trending_up_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShopProfilePage()),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit Shop Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PROFILE TAB (with logout) ────────────────────────────────

  Widget _buildProfileTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [AppShadows.medium],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(_shop?.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _shop?.name ?? 'My Shop',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _shop?.email ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ProfileTile(
            icon: Icons.store_rounded,
            title: 'Shop Profile',
            subtitle: 'Manage shop details',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopProfilePage())),
          ),
          _ProfileTile(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'App version & preferences',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          _ProfileTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Get assistance',
            onTap: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon'))); },
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Sign out of your account',
                style: TextStyle(fontSize: 12, color: AppColors.error),
              ),
              onTap: _logout,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Version ${AppInfo.version}',
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        surfaceTintColor: AppColors.primary.withValues(alpha: 0.08),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        animationDuration: const Duration(milliseconds: 400),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, size: 24),
            selectedIcon: Icon(Icons.dashboard_rounded, size: 24, color: AppColors.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined, size: 24),
            selectedIcon: Icon(Icons.inventory_2_rounded, size: 24, color: AppColors.primary),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined, size: 24),
            selectedIcon: Icon(Icons.shopping_bag_rounded, size: 24, color: AppColors.primary),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined, size: 24),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, size: 24, color: AppColors.primary),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, size: 24),
            selectedIcon: Icon(Icons.person_rounded, size: 24, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

// ─── SHIMMER LOADING ──────────────────────────────────────────────

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _ShimmerBox({required this.width, required this.height, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

Widget _buildShimmerLoading() {
  return SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 180,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _ShimmerBox(width: 52, height: 52, radius: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _ShimmerBox(width: 80, height: 12),
                            SizedBox(height: 6),
                            _ShimmerBox(width: 140, height: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const _ShimmerBox(width: double.infinity, height: 52, radius: 16),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ShimmerBox(width: 80, height: 18),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: _ShimmerBox(width: double.infinity, height: 90)),
                  SizedBox(width: 12),
                  Expanded(child: _ShimmerBox(width: double.infinity, height: 90)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: _ShimmerBox(width: double.infinity, height: 90)),
                  SizedBox(width: 12),
                  Expanded(child: _ShimmerBox(width: double.infinity, height: 90)),
                ],
              ),
              const SizedBox(height: 24),
              const _ShimmerBox(width: 120, height: 18),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: _ShimmerBox(width: double.infinity, height: 100)),
                  SizedBox(width: 12),
                  Expanded(child: _ShimmerBox(width: double.infinity, height: 100)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── STAT CARD ──────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── QUICK ACTION CARD ─────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Gradient gradient;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── RECENT ORDER CARD ─────────────────────────────────────────

class _RecentOrderCard extends StatelessWidget {
  final String orderId;
  final String? status;
  final String statusLabel;
  final Color statusColor;
  final double total;
  final int itemCount;
  final String timeAgo;
  final VoidCallback? onTap;

  const _RecentOrderCard({
    required this.orderId,
    this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.total,
    required this.itemCount,
    required this.timeAgo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#$orderId',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '₹${total.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  timeAgo,
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SHOP STAT ITEM ────────────────────────────────────────────

class _ShopStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ShopStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── PROFILE TILE ──────────────────────────────────────────────

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [AppShadows.soft],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 22),
        onTap: onTap,
      ),
    );
  }
}
