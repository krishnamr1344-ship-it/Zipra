import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/api/admin_api_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _api = AdminApiService();
  List<dynamic> _users = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getUsers();
      if (!mounted) return;
      setState(() {
        _users = data;
        _filtered = List.from(data);
        _loading = false;
      });
      _applyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _users.where((u) {
        final user = u as Map<String, dynamic>;
        final q = _search.toLowerCase();
        return _search.isEmpty ||
            (user['name']?.toString().toLowerCase() ?? '').contains(q) ||
            (user['email']?.toString().toLowerCase() ?? '').contains(q);
      }).toList();
    });
  }

  Color _avatarColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.accent;
      case 'shop_owner':
        return AppColors.info;
      default:
        return AppColors.success;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'ADMIN';
      case 'shop_owner':
        return 'SHOP OWNER';
      default:
        return 'USER';
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.shield_rounded;
      case 'shop_owner':
        return Icons.store_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? _buildShimmer()
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _buildUserCard(_filtered[i] as Map<String, dynamic>),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.people_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Users',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_filtered.length} account${_filtered.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(160),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  border: Border.all(color: AppColors.accent.withAlpha(50)),
                ),
                child: Text(
                  '${_users.length}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
          border: Border.all(color: AppColors.divider),
        ),
        child: TextField(
          onChanged: (v) {
            _search = v;
            _applyFilter();
          },
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search users by name or email...',
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
            suffixIcon: _search.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _search = '';
                      _applyFilter();
                    },
                    child: const Icon(Icons.close_rounded, color: AppColors.textHint, size: 18),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final role = (u['role'] ?? 'user').toString();
    final isAdmin = role == 'admin';
    final accent = _avatarColor(role);
    final initial = (u['name']?.toString() ?? 'U')[0].toUpperCase();
    final phone = u['phone']?.toString();
    final createdAt = u['created_at']?.toString();
    final dateStr = createdAt != null && createdAt.length >= 10 ? createdAt.substring(0, 10) : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [AppShadows.soft],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          tilePadding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withAlpha(180)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [AppShadows.soft],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  u['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withAlpha(18),
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  border: Border.all(color: accent.withAlpha(40)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_roleIcon(role), size: 11, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      _roleLabel(role),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.email_rounded, size: 13, color: AppColors.textHint),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    u['email'] ?? '',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 1,
                  color: AppColors.divider,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildInfoRow(
                  icon: Icons.person_rounded,
                  label: 'Name',
                  value: u['name'] ?? '-',
                ),
                if (phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildInfoRow(
                    icon: Icons.phone_rounded,
                    label: 'Phone',
                    value: phone,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _buildInfoRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: u['email'] ?? '-',
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildInfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Joined',
                  value: dateStr,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildInfoRow(
                  icon: _roleIcon(role),
                  label: 'Role',
                  value: _roleLabel(role),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withAlpha(15),
                          AppColors.accent.withAlpha(8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.accent.withAlpha(30)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, size: 16, color: AppColors.accent),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Text(
                            'Full admin access to all features',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textHint),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: Row(
          children: [
            _shimmerBox(48, 48, AppRadius.md),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(120, 14, 6),
                  const SizedBox(height: 8),
                  _shimmerBox(180, 12, 6),
                ],
              ),
            ),
            _shimmerBox(60, 24, 12),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double w, double h, double r) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _search.isNotEmpty
                  ? 'Try a different search term'
                  : 'No user accounts yet',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            if (_search.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              GestureDetector(
                onTap: () {
                  _search = '';
                  _applyFilter();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    border: Border.all(color: AppColors.accent.withAlpha(40)),
                  ),
                  child: const Text(
                    'Clear Search',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
