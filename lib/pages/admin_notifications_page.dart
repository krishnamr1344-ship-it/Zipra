import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';
import '../services/cloudinary_service.dart';
import '../widgets/state_widgets.dart';
import '../services/notification_service.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final _api = AdminApiService();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _notifications = [];
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
      setState(() { _loading = true; _error = false; _page = 1; _hasMore = true; _notifications = []; });
    }
    try {
      final data = await _api.getNotifications(page: page);
      if (!mounted) return;
      setState(() {
        if (append) {
          _notifications.addAll(data.cast<Map<String, dynamic>>());
          if (data.length < 50) _hasMore = false;
        } else {
          _notifications = data.cast<Map<String, dynamic>>();
          if (data.length < 50) _hasMore = false;
        }
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
        debugPrint("pages.admin_notifications_page: $e");
      if (mounted) setState(() { _loading = false; _loadingMore = false; _error = !append; });
    }
  }

  void _showCreateForm() {
    final titleCtl = TextEditingController();
    final messageCtl = TextEditingController();
    String? imageUrl;
    final linkCtl = TextEditingController();
    String selectedType = 'offer';
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
                    child: const Icon(Icons.notifications, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text('New Notification', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              TextField(controller: titleCtl, decoration: InputDecoration(labelText: 'Title', errorText: titleError, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), onChanged: (_) { if (titleError != null) setSheetState(() => titleError = null); }),
              const SizedBox(height: 12),
              TextField(controller: messageCtl, decoration: InputDecoration(labelText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), maxLines: 3),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                items: const [
                  DropdownMenuItem(value: 'offer', child: Text('Offer')),
                  DropdownMenuItem(value: 'promo', child: Text('Promo')),
                  DropdownMenuItem(value: 'update', child: Text('Update')),
                  DropdownMenuItem(value: 'info', child: Text('Info')),
                ],
                onChanged: (v) { if (v != null) setSheetState(() => selectedType = v); },
              ),
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
                      : (imageUrl?.isNotEmpty == true)
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
                        'message': messageCtl.text.trim().isEmpty ? null : messageCtl.text.trim(),
                        'type': selectedType,
                        'image_url': (imageUrl?.isNotEmpty == true) ? imageUrl : null,
                        'link': linkCtl.text.trim().isEmpty ? null : linkCtl.text.trim(),
                      };
                      await _api.createNotification(body);
                      notificationService.load();
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
                      : const Text('Send Notification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNotification(Map<String, dynamic> notif) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text('Delete "${notif['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.deleteNotification(notif['id']);
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'offer': return Icons.local_offer;
      case 'promo': return Icons.discount;
      case 'update': return Icons.system_update;
      case 'info': return Icons.info_outline;
      default: return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'offer': return Colors.orange;
      case 'promo': return Colors.red;
      case 'update': return Colors.blue;
      case 'info': return Colors.grey;
      default: return AppColors.primary;
    }
  }

  String _timeAgo(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${diff.inDays ~/ 7}w ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateForm,
          ),
        ],
      ),
      body: _loading
          ? const LoadingWidget(message: 'Loading notifications\u2026')
          : _error
              ? ErrorStateWidget(onRetry: _load)
              : _notifications.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.notifications_none,
                      title: 'No notifications sent yet',
                      actionLabel: 'Send First Notification',
                      onAction: _showCreateForm,
                    )
                  : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final notif = _notifications[i];
                      final type = notif['type'] as String? ?? 'info';
                      final createdAt = notif['created_at'] as String? ?? '';
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _typeColor(type).withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_typeIcon(type), size: 20, color: _typeColor(type)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(notif['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                        if (notif['message'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(notif['message'], style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_timeAgo(createdAt), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _typeColor(type).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(type.toUpperCase(), style: TextStyle(fontSize: 9, color: _typeColor(type), fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (notif['image_url'] != null && (notif['image_url'] as String).isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    notif['image_url'],
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(height: 80, color: Colors.grey.withValues(alpha: 0.15), child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                                  ),
                                ),
                              ],
                              const Divider(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  tooltip: 'Delete',
                                  onPressed: () => _deleteNotification(notif),
                                ),
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

