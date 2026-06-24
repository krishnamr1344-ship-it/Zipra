import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';
import '../services/cloudinary_service.dart';
import '../widgets/state_widgets.dart';

class AdminBannersPage extends StatefulWidget {
  const AdminBannersPage({super.key});

  @override
  State<AdminBannersPage> createState() => _AdminBannersPageState();
}

class _AdminBannersPageState extends State<AdminBannersPage> {
  final _api = AdminApiService();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;
  bool _error = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 && _hasMore && !_loadingMore) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_loadingMore || !_hasMore) return;
    _page++;
    _load(page: _page, append: true).catchError((_) {});
  }

  Future<void> _load({int page = 1, bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() { _loading = true; _error = false; _page = 1; _hasMore = true; _banners = []; });
    }
    try {
      final data = await _api.getBanners(page: page);
      if (!mounted) return;
      setState(() {
        if (append) {
          _banners.addAll(data.cast<Map<String, dynamic>>());
          if (data.length < 50) _hasMore = false;
        } else {
          _banners = data.cast<Map<String, dynamic>>();
          if (data.length < 50) _hasMore = false;
        }
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
        debugPrint("pages.admin_banners_page: $e");
      if (mounted) setState(() { _loading = false; _loadingMore = false; _error = !append; });
    }
  }

  void _showForm([Map<String, dynamic>? banner]) {
    final titleCtl = TextEditingController(text: banner?['title'] ?? '');
    final subtitleCtl = TextEditingController(text: banner?['subtitle'] ?? '');
    String? imageUrl = banner?['image_url'] as String?;
    final linkCtl = TextEditingController(text: banner?['link'] ?? '');
    final colorCtl = TextEditingController(text: banner?['color'] ?? 'FF6B00');
    final sortOrderCtl = TextEditingController(text: banner != null ? '${banner['sort_order'] ?? 0}' : '0');
    bool isActive = banner?['is_active'] ?? true;
    bool uploading = false;

    bool saving = false;
    String? titleError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.palette, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(banner == null ? 'Add Banner' : 'Edit Banner', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              TextField(controller: titleCtl, decoration: InputDecoration(labelText: 'Title', errorText: titleError, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), onChanged: (_) { if (titleError != null) setSheetState(() => titleError = null); }),
              const SizedBox(height: 12),
              TextField(controller: subtitleCtl, decoration: InputDecoration(labelText: 'Subtitle', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: uploading ? null : () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (picked == null) return;
                  setSheetState(() => uploading = true);
                  try {
                    final url = await CloudinaryService.uploadImage(picked.path);
                    setSheetState(() { imageUrl = url; uploading = false; });
                  } catch (e) {
                    setSheetState(() => uploading = false);
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: uploading
                      ? const Center(child: CircularProgressIndicator())
                      : imageUrl != null && imageUrl!.isNotEmpty
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(imageUrl!, width: double.infinity, height: 120, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 4, right: 4,
                                  child: GestureDetector(
                                    onTap: () => setSheetState(() => imageUrl = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade400),
                                const SizedBox(height: 6),
                                Text('Tap to upload image', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: linkCtl, decoration: InputDecoration(labelText: 'Link (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: colorCtl,
                      decoration: InputDecoration(
                        labelText: 'Color (hex)',
                        hintText: 'FF6B00',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: sortOrderCtl,
                      decoration: InputDecoration(
                        labelText: 'Sort Order',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: isActive,
                onChanged: (v) => setSheetState(() => isActive = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    setSheetState(() {
                      titleError = titleCtl.text.trim().isEmpty ? 'Title is required' : null;
                    });
                    if (titleError != null) return;
                    setSheetState(() => saving = true);
                    try {
                      final body = {
                        'title': titleCtl.text.trim(),
                        'subtitle': subtitleCtl.text.trim().isEmpty ? null : subtitleCtl.text.trim(),
                        'image_url': (imageUrl != null && imageUrl!.isNotEmpty) ? imageUrl : null,
                        'link': linkCtl.text.trim().isEmpty ? null : linkCtl.text.trim(),
                        'color': colorCtl.text.trim().isEmpty ? 'FF6B00' : colorCtl.text.trim(),
                        'is_active': isActive,
                        'sort_order': int.tryParse(sortOrderCtl.text.trim()) ?? 0,
                      };
                      if (banner == null) {
                        await _api.createBanner(body);
                      } else {
                        await _api.updateBanner(banner['id'], body);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      setSheetState(() => saving = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(banner == null ? 'Create Banner' : 'Update Banner', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBanner(Map<String, dynamic> banner) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Banner'),
        content: Text('Delete "${banner['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.deleteBanner(banner['id']);
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _toggleBanner(Map<String, dynamic> banner) async {
    try {
      await _api.updateBanner(banner['id'], {'is_active': banner['is_active'] != true});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banners'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showForm(),
          ),
        ],
      ),
      body: _loading
          ? const LoadingWidget(message: 'Loading banners\u2026')
          : _error
              ? ErrorStateWidget(onRetry: _load)
              : _banners.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.palette_outlined,
                      title: 'No banners yet',
                      actionLabel: 'Create First Banner',
                      onAction: () => _showForm(),
                    )
                  : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _banners.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _banners.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final banner = _banners[i];
                      final isActive = banner['is_active'] == true;
                      final color = _hexToColor(banner['color'] ?? 'FF6B00');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6, height: 48,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(banner['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        if (banner['subtitle'] != null) ...[
                                          const SizedBox(height: 2),
                                          Text(banner['subtitle'], style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green.withValues(alpha: 0.20) : Colors.grey.withValues(alpha: 0.20),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 12, color: isActive ? Colors.green : Colors.grey, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              if (banner['image_url'] != null && (banner['image_url'] as String).isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    banner['image_url'],
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(height: 80, color: Colors.grey.withValues(alpha: 0.15), child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                                  ),
                                ),
                              ],
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('Order: ${banner['sort_order'] ?? 0}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(isActive ? Icons.visibility_off : Icons.visibility, size: 20),
                                    tooltip: isActive ? 'Deactivate' : 'Activate',
                                    onPressed: () => _toggleBanner(banner),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showForm(banner),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    onPressed: () => _deleteBanner(banner),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
