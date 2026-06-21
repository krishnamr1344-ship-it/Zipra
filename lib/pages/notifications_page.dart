import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/theme.dart';
import '../services/notification_service.dart';
import '../widgets/state_widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _listenerAdded = false;

  @override
  void initState() {
    super.initState();
    if (!notificationService.loaded) {
      notificationService.addListener(_onData);
      _listenerAdded = true;
      notificationService.load();
    }
  }

  @override
  void dispose() {
    if (_listenerAdded) {
      notificationService.removeListener(_onData);
    }
    super.dispose();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'offer':
        return Icons.local_offer;
      case 'promo':
        return Icons.discount;
      case 'update':
        return Icons.system_update;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'offer':
        return AppColors.primary;
      case 'promo':
        return AppColors.success;
      case 'update':
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (notificationService.loading) {
      return const LoadingWidget();
    }

    if (!notificationService.loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notificationService.notifications.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.notifications_off_outlined,
        title: 'No notifications yet',
        subtitle: 'We\'ll notify you when there\'s something new',
      );
    }

    return RefreshIndicator(
      onRefresh: () => notificationService.load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: notificationService.notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final n = notificationService.notifications[i];
          return _NotificationCard(notification: n, typeIcon: _typeIcon(n.type), typeColor: _typeColor(n.type));
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final IconData typeIcon;
  final Color typeColor;

  const _NotificationCard({
    required this.notification,
    required this.typeIcon,
    required this.typeColor,
  });

  void _onTap(BuildContext context) {
    if (notification.link != null && notification.link!.isNotEmpty) {
      launchUrl(Uri.parse(notification.link!), mode: LaunchMode.externalApplication);
    } else if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(notification.imageUrl!, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(notification.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (notification.message != null && notification.message!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(notification.message!, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                      if (notification.message != null && notification.message!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(notification.message!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(notification.timeAgo,
                            style: const TextStyle(fontSize: 10, color: Color(0xFFBDBDBD))),
                          if (notification.imageUrl != null || (notification.link != null && notification.link!.isNotEmpty)) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Tap to view', style: TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  notification.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(height: 80, color: Colors.grey.withValues(alpha: 0.15), child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
