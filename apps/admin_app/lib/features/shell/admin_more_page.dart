import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../categories/admin_categories_page.dart';
import '../delivery/admin_delivery_zone_page.dart';
import '../delivery/admin_delivery_fee_page.dart';
import '../offers/admin_offers_page.dart';
import '../shops/admin_shops_page.dart';
import '../combo_packs/admin_combo_packs_page.dart';
import '../products/admin_product_approvals_page.dart';
import '../../core/api/api_service.dart';

class AdminMorePage extends StatelessWidget {
  const AdminMorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Text('More', style: AppText.h2),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.1,
              children: [
                _buildTile(
                  context,
                  icon: Icons.category_rounded,
                  label: 'Categories',
                  gradient: AppColors.primaryGradient,
                  onTap: () => _open(context, const AdminCategoriesPage()),
                ),
                _buildTile(
                  context,
                  icon: Icons.map_rounded,
                  label: 'Delivery Zones',
                  gradient: AppColors.infoGradient,
                  onTap: () => _open(context, const AdminDeliveryZonePage()),
                ),
                _buildTile(
                  context,
                  icon: Icons.delivery_dining_rounded,
                  label: 'Delivery Fees',
                  gradient: AppColors.warningGradient,
                  onTap: () => _open(context, const AdminDeliveryFeePage()),
                ),
                _buildTile(
                  context,
                  icon: Icons.local_offer_rounded,
                  label: 'Offers',
                  gradient: AppColors.successGradient,
                  onTap: () => _open(context, const AdminOffersPage()),
                ),
                _buildTile(
                  context,
                  icon: Icons.store_rounded,
                  label: 'Shops',
                  gradient: AppColors.orangeGradient,
                  onTap: () => _open(context, const AdminShopsPage()),
                ),
                _buildTile(
                  context,
                  icon: Icons.inventory_2_outlined,
                  label: 'Combo Packs',
                  gradient: AppColors.pinkGradient,
                  onTap: () => _open(context, const AdminComboPacksPage()),
                ),
                _buildTile(
                  context,
                  icon: Icons.verified_rounded,
                  label: 'Approvals',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () =>
                      _open(context, const AdminProductApprovalsPage()),
                ),
                _buildTile(
                  context,
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  gradient: AppColors.errorGradient,
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => page));
  }

  void _confirmLogout(BuildContext context) {
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
              await ApiService().logout();
              if (context.mounted) {
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

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppText.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
