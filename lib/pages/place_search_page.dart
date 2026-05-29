import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../widgets/state_widgets.dart';

class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({super.key});

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final _api = ApiService();
  final _searchCtl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _error = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() { _loading = true; _error = false; });
    try {
      final data = await _api.searchPlaces(q);
      if (!mounted) return;
      setState(() { _results = data.cast<Map<String, dynamic>>(); _error = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _results = []; _error = true; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtl,
          onChanged: _onSearchChanged,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search area, street, city...',
            hintStyle: TextStyle(color: Colors.white.withAlpha(150), fontSize: 16),
            border: InputBorder.none,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const LoadingWidget(message: 'Searching\u2026')
          : _error
              ? ErrorStateWidget(onRetry: () => _search(_searchCtl.text.trim()))
              : _results.isEmpty && _searchCtl.text.trim().isNotEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.search_off,
                      title: 'No results found',
                      subtitle: 'Try a different search term',
                    )
                  : _results.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.search,
                          title: 'Search for your area',
                          subtitle: 'Type an area, street, or city name',
                        )
                      : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 60),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.location_on, color: Colors.green, size: 22),
                      ),
                      title: Text(
                        '${r['address_line2'] ?? ''}, ${r['city'] ?? ''}'.replaceAll(RegExp(r'^,\s*'), ''),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(r['display_name'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.add_circle_outline, color: Colors.green, size: 22),
                      onTap: () => Navigator.pop(context, r),
                    );
                  },
                ),
    );
  }
}
