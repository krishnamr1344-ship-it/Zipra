import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';
import '../widgets/state_widgets.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _api = AdminApiService();
  List<dynamic> _allUsers = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  bool _error = false;
  bool _hasMore = true;
  bool _loadingMore = false;
  String _search = '';
  int _page = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _page++;
    await _load(page: _page, append: true);
  }

  Future<void> _load({int page = 1, bool append = false}) async {
    if (append) {
      setState(() {
        _loadingMore = true;
      });
    } else {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final data = await _api.getUsers(page: page);
      if (!mounted) return;
      setState(() {
        if (append) {
          _allUsers.addAll(data);
          if (data.length < 50) _hasMore = false;
        } else {
          _allUsers = List.from(data);
          _page = 1;
          _hasMore = data.length >= 50;
        }
        _filtered = List.from(_allUsers);
        _loading = false;
        _loadingMore = false;
      });
      _applyFilter();
    } catch (e) {
      debugPrint("pages.admin_users_page: $e");
      if (!mounted) return;
      setState(() {
        if (append) {
          _loadingMore = false;
        } else {
          _loading = false;
          _error = true;
        }
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _allUsers.where((u) {
        final user = u as Map<String, dynamic>;
        final q = _search.toLowerCase();
        return _search.isEmpty ||
            (user['name']?.toString().toLowerCase() ?? '').contains(q) ||
            (user['email']?.toString().toLowerCase() ?? '').contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
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
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.people,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Users',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Manage user accounts',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
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
                onChanged: (v) {
                  _search = v;
                  _applyFilter();
                },
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.textHint),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: LoadingWidget(message: 'Loading users\u2026'),
            )
          else if (_error)
            SliverFillRemaining(child: ErrorStateWidget(onRetry: _load))
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              child: _search.isNotEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.search_off,
                      title: 'No users found',
                      subtitle: 'Try a different search',
                    )
                  : const EmptyStateWidget(
                      icon: Icons.people_outline,
                      title: 'No users yet',
                      subtitle: 'Users will appear here once they register',
                    ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  if (i == _filtered.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final u = _filtered[i] as Map<String, dynamic>;
                  final isAdmin = u['role'] == 'admin';
                  final accent = isAdmin ? Colors.amber : Colors.blue;
                  final initial = (u['name']?.toString() ?? 'U')[0]
                      .toUpperCase();
                  final gps = u['gps_address'] as Map<String, dynamic>?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                      child: ExpansionTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          14,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accent, accent.withValues(alpha: 0.180)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
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
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAdmin ? Icons.shield : Icons.person,
                                    size: 12,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isAdmin ? 'ADMIN' : 'USER',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          u['email'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        children: [
                          if (gps != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'GPS Address',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${gps['address_line1'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${gps['city'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              if (u['phone'] != null &&
                                  u['phone'].toString().isNotEmpty) ...[
                                Icon(
                                  Icons.phone,
                                  size: 14,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${u['phone']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                              ],
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: AppColors.textHint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                u['created_at']?.toString().substring(0, 10) ??
                                    '-',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: _filtered.length + (_loadingMore ? 1 : 0)),
              ),
            ),
        ],
      ),
    );
  }
}
