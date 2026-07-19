import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/api/api_service.dart';
import '../../core/api/admin_api_service.dart';
import '../orders/admin_order_detail_page.dart';
import '../categories/admin_categories_page.dart';
import '../delivery/admin_delivery_zone_page.dart';
import '../delivery/admin_delivery_fee_page.dart';
import '../combo_packs/admin_combo_packs_page.dart';
import '../offers/admin_offers_page.dart';
import '../shops/admin_shops_page.dart';
import '../products/admin_product_approvals_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _api = ApiService();
  final _adminApi = AdminApiService();
  Map<String, dynamic> _user = {};
  Map<String, dynamic> _stats = {};
  List<dynamic> _recentOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await _api.getSavedUser();
      final stats = await _adminApi.getStats();
      List<dynamic> orders = [];
      try {
        orders = await _adminApi.getOrders();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _user = user;
        _stats = stats;
        _recentOrders = orders.length > 5 ? orders.sublist(0, 5) : orders;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildStatsSection()),
                  SliverToBoxAdapter(child: _buildQuickActions()),
                  SliverToBoxAdapter(child: _buildRecentOrders()),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xl)),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _user['name'] ?? 'Admin';
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xl),
          bottomRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    name.toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderIcon(
                icon: Icons.notifications_outlined,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildStatsSection() {
    final products = _stats['total_products'] ?? 0;
    final orders = _stats['total_orders'] ?? 0;
    final users = _stats['total_users'] ?? 0;
    final revenue = _stats['total_revenue'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: AppText.h3),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Products',
                  value: '$products',
                  icon: Icons.inventory_2_rounded,
                  gradient: AppColors.primaryGradient,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  title: 'Orders',
                  value: '$orders',
                  icon: Icons.receipt_long_rounded,
                  gradient: AppColors.successGradient,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Users',
                  value: '$users',
                  icon: Icons.people_rounded,
                  gradient: AppColors.infoGradient,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  title: 'Revenue',
                  value: '₹${_formatRevenue(revenue)}',
                  icon: Icons.account_balance_wallet_rounded,
                  gradient: AppColors.warningGradient,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRevenue(dynamic value) {
    final double amount = (value is num) ? value.toDouble() : 0.0;
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  Widget _buildQuickActions() {
    final actions = [
      _ActionItem(Icons.category_rounded, 'Categories', AppColors.primaryGradient,
          () => _open(const AdminCategoriesPage())),
      _ActionItem(Icons.map_rounded, 'Zones', AppColors.infoGradient,
          () => _open(const AdminDeliveryZonePage())),
      _ActionItem(Icons.delivery_dining_rounded, 'Fees', AppColors.warningGradient,
          () => _open(const AdminDeliveryFeePage())),
      _ActionItem(Icons.local_offer_rounded, 'Offers', AppColors.successGradient,
          () => _open(const AdminOffersPage())),
      _ActionItem(Icons.store_rounded, 'Shops', AppColors.orangeGradient,
          () => _open(const AdminShopsPage())),
      _ActionItem(Icons.inventory_2_outlined, 'Combos', AppColors.pinkGradient,
          () => _open(const AdminComboPacksPage())),
      _ActionItem(Icons.verified_rounded, 'Approvals',
          const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          () => _open(const AdminProductApprovalsPage())),
      _ActionItem(Icons.logout_rounded, 'Logout', AppColors.errorGradient,
          _confirmLogout),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppText.h3),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.85,
            ),
            itemCount: actions.length,
            itemBuilder: (_, i) => _buildActionCard(actions[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(_ActionItem action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: action.gradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: (action.gradient as LinearGradient).colors.first
                      .withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(action.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            action.label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Orders', style: AppText.h3),
          const SizedBox(height: AppSpacing.md),
          if (_recentOrders.isEmpty)
            _buildEmptyOrders()
          else
            ...(_recentOrders.take(5).map((o) => _buildOrderCard(o))),
        ],
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [AppShadows.soft],
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 40, color: AppColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.sm),
            Text('No orders yet', style: AppText.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final o = order is Map<String, dynamic> ? order : <String, dynamic>{};
    final orderId = (o['id'] ?? '').toString();
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    final amount = o['total_amount'] ?? o['total'] ?? 0;
    final status = o['status'] ?? 'pending';
    final payment = o['payment_method'] ?? 'COD';
    final customerName = o['customer_name'] ?? 'Customer';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminOrderDetailPage(order: o),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Text(
                  customerName.toString().substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '#$shortId',
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          payment,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹$amount',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.statusColor(status.toString())
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusColor(status.toString()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _api.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text('Logout',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [AppShadows.soft],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppText.bodySmall.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  _ActionItem(this.icon, this.label, this.gradient, this.onTap);
}
