import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/admin_api_service.dart';
import '../widgets/state_widgets.dart';
import 'login_page.dart';
import 'admin_products_page.dart';
import 'admin_categories_page.dart';
import 'admin_orders_page.dart';
import 'admin_users_page.dart';
import 'admin_delivery_zone_page.dart';
import 'admin_combo_packs_page.dart';
import 'admin_banners_page.dart';
import 'admin_notifications_page.dart';

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
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final user = await _api.getSavedUser();
      final stats = await _adminApi.getStats();
      if (!mounted) return;
      setState(() { _user = user; _stats = stats; _loading = false; });
    } catch (e) {
        debugPrint("pages.admin_home_page: $e");
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Logout')),
        ],
      ),
    );
    if (confirm == true) {
      await _api.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (_loading) return const Scaffold(body: LoadingWidget(message: 'Loading dashboard\u2026'));
    if (_error) return Scaffold(body: ErrorStateWidget(onRetry: _load));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              stretch: true,
              backgroundColor: primary,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.adminHeaderGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 46, height: 46,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (_user['name'] ?? 'A').toString()[0].toUpperCase(),
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Welcome,', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.18))),
                                      Text(_user['name'] ?? 'Admin', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield, size: 12, color: Colors.white70),
                                        SizedBox(width: 4),
                                        Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
                                      onPressed: _logout,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(_user['email'] ?? '', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.15))),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    _statCard(primary, Icons.inventory_2, '${_stats['products'] ?? 0}', 'Products'),
                    const SizedBox(width: 10),
                    _statCard(Colors.orange, Icons.receipt_long, '${_stats['orders'] ?? 0}', 'Orders'),
                    const SizedBox(width: 10),
                    _statCard(Colors.blue, Icons.people, '${_stats['users'] ?? 0}', 'Users'),
                    const SizedBox(width: 10),
                    _statCard(Colors.green, Icons.currency_rupee, '₹${_stats['revenue']?.toStringAsFixed(0) ?? '0'}', 'Revenue'),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text('MANAGEMENT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildListDelegate([
                  _menuCard(primary, Icons.inventory_2, 'Products', 'Manage catalog', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProductsPage())).then((_) => _load())),
                  _menuCard(Colors.amber, Icons.category, 'Categories', 'Organize items', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCategoriesPage())).then((_) => _load())),
                  _menuCard(Colors.green, Icons.receipt_long, 'Orders', 'View & manage', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersPage()))),
                  _menuCard(Colors.blue, Icons.people, 'Users', 'Manage accounts', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersPage()))),
                  _menuCard(Colors.deepPurple, Icons.map, 'Delivery Zones', 'Set service areas', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDeliveryZonePage()))),
                  _menuCard(AppColors.primary, Icons.inventory_2, 'Combo Packs', 'Monthly Needs packs', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminComboPacksPage())).then((_) => _load())),
                  _menuCard(Colors.orange, Icons.palette, 'Banners', 'Manage promotions', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBannersPage())).then((_) => _load())),
                  _menuCard(Colors.red, Icons.notifications, 'Notifications', 'Send & manage', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNotificationsPage()))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(Color accent, IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accent)),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(Color accent, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(18),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, size: 26, color: accent),
                ),
                const Spacer(),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
