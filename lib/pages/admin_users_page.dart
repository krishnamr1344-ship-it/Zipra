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
  List<dynamic> _users = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  bool _error = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final data = await _api.getUsers();
      if (!mounted) return;
      setState(() { _users = data; _filtered = List.from(data); _loading = false; });
      _applyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
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
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.people, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Users', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text('Manage user accounts', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                onChanged: (v) { _search = v; _applyFilter(); },
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.withAlpha(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: LoadingWidget(message: 'Loading users\u2026'))
          else if (_error)
            SliverFillRemaining(child: ErrorStateWidget(onRetry: _load))
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              child: _search.isNotEmpty
                  ? const EmptyStateWidget(icon: Icons.search_off, title: 'No users found', subtitle: 'Try a different search')
                  : const EmptyStateWidget(icon: Icons.people_outline, title: 'No users yet', subtitle: 'Users will appear here once they register'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final u = _filtered[i] as Map<String, dynamic>;
                    final isAdmin = u['role'] == 'admin';
                    final accent = isAdmin ? Colors.amber : Colors.blue;
                    final initial = (u['name']?.toString() ?? 'U')[0].toUpperCase();
                    final gps = u['gps_address'] as Map<String, dynamic>?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Material(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.transparent,
                        child: ExpansionTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          leading: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accent, accent.withAlpha(180)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(child: Text(initial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(isAdmin ? Icons.shield : Icons.person, size: 12, color: accent),
                                    const SizedBox(width: 3),
                                    Text(isAdmin ? 'ADMIN' : 'USER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(u['email'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          children: [
                            if (gps != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(10),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.green.withAlpha(25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 16, color: Colors.green.shade600),
                                        const SizedBox(width: 6),
                                        const Text('GPS Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('${gps['address_line1'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    Text('${gps['city'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                if (u['phone'] != null && u['phone'].toString().isNotEmpty) ...[
                                  Icon(Icons.phone, size: 14, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Text('${u['phone']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  const SizedBox(width: 16),
                                ],
                                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Text('${u['created_at']?.toString().substring(0, 10) ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ],
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
    );
  }
}
