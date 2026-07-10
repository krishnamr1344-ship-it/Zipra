import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/admin_api_service.dart';
import 'login_page.dart';
import 'admin_products_page.dart';
import 'admin_categories_page.dart';
import 'admin_orders_page.dart';
import 'admin_users_page.dart';
import 'admin_delivery_zone_page.dart';
import 'admin_combo_packs_page.dart';
import 'admin_offers_page.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await _api.getSavedUser();
      final stats = await _adminApi.getStats();
      if (!mounted) return;
      setState(() { _user = user; _stats = stats; });
    } catch (_) {
      if (!mounted) return;
      setState(() { /* stats failed, keep existing */ });
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
                                      color: Colors.white.withAlpha(40),
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
                                      Text('Welcome,', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(180))),
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
                                      color: Colors.white.withAlpha(30),
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
                                      color: Colors.white.withAlpha(20),
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
                          Text(_user['email'] ?? '', style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(150))),
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
                child: Text('MANAGEMENT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1)),
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
                  _menuCard(Colors.orange, Icons.local_offer, 'Offers', 'Discount deals', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOffersPage())).then((_) => _load())),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.withAlpha(30))),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: Colors.amber.withAlpha(25), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.bar_chart, color: Colors.amber, size: 22),
                    ),
                    title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Sales & revenue overview'),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (ctx) => Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(color: Colors.amber.withAlpha(25), borderRadius: BorderRadius.circular(14)),
                                    child: const Icon(Icons.bar_chart, color: Colors.amber, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Text('Revenue Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _reportRow(Icons.inventory_2, 'Total Products', '${_stats['products'] ?? 0}', primary),
                              const SizedBox(height: 14),
                              _reportRow(Icons.receipt_long, 'Total Orders', '${_stats['orders'] ?? 0}', primary),
                              const SizedBox(height: 14),
                              _reportRow(Icons.people, 'Total Users', '${_stats['users'] ?? 0}', primary),
                              const SizedBox(height: 14),
                              const Divider(),
                              const SizedBox(height: 14),
                              _reportRow(Icons.currency_rupee, 'Total Revenue', '₹${_stats['revenue']?.toStringAsFixed(2) ?? '0.00'}', Colors.amber),
                              const SizedBox(height: 14),
                              _reportRow(Icons.shopping_cart, 'Categories', '${_stats['categories'] ?? 0}', Colors.green),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
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
            BoxShadow(color: accent.withAlpha(20), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: accent.withAlpha(25), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accent)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
          BoxShadow(color: accent.withAlpha(15), blurRadius: 12, offset: const Offset(0, 4)),
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
                  decoration: BoxDecoration(color: accent.withAlpha(25), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, size: 26, color: accent),
                ),
                const Spacer(),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
