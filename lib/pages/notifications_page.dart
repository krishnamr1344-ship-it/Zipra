import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/notification_service.dart';
import '../widgets/state_widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    if (!notificationService.loaded) {
      notificationService.addListener(_onData);
      notificationService.load();
    }
  }

  @override
  void dispose() {
    notificationService.removeListener(_onData);
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
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
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
                Text(notification.timeAgo,
                  style: const TextStyle(fontSize: 10, color: Color(0xFFBDBDBD))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
