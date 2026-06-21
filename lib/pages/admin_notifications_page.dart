import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';
import '../widgets/state_widgets.dart';
import '../services/notification_service.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final _api = AdminApiService();
  List<Map<String, dynamic>> _notifications = [];
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
      final data = await _api.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
        debugPrint("pages.admin_notifications_page: $e");
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  void _showCreateForm() {
    final titleCtl = TextEditingController();
    final messageCtl = TextEditingController();
    final imageUrlCtl = TextEditingController();
    final linkCtl = TextEditingController();
    String selectedType = 'offer';

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
                value: selectedType,
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
              TextField(controller: imageUrlCtl, decoration: InputDecoration(labelText: 'Image URL (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
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
                        'image_url': imageUrlCtl.text.trim().isEmpty ? null : imageUrlCtl.text.trim(),
                        'link': linkCtl.text.trim().isEmpty ? null : linkCtl.text.trim(),
                      };
                      await _api.createNotification(body);
                      notificationService.sendNotification(body);
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
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) {
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
