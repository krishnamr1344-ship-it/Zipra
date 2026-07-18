import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/models/cart_model.dart';

class OrderDetailPage extends StatelessWidget {
  final OrderData order;
  const OrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order Details', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusBox(order: order),
            const SizedBox(height: 16),
            _InfoBox(order: order),
            const SizedBox(height: 16),
            _ItemsBox(order: order),
          ],
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final OrderData order;
  const _StatusBox({required this.order});

  Color get _accent {
    switch (order.status) {
      case 'Pending': return AppColors.primaryLight;
      case 'Confirmed': return AppColors.primary;
      case 'Shipped': return const Color(0xFF2196F3);
      case 'Delivered': return AppColors.success;
      case 'Cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  int get _activeIndex {
    switch (order.status) {
      case 'Pending': return 0;
      case 'Confirmed': return 1;
      case 'Shipped': return 2;
      case 'Delivered': return 3;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Placed', 'Confirmed', 'Shipped', 'Delivered'];
    final active = _activeIndex;
    final cancelled = order.status == 'Cancelled';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accent.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.checklist, size: 22, color: _accent),
              ),
              const SizedBox(width: 12),
              const Text('Order Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: _accent.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                child: Text(order.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _accent)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...List.generate(steps.length, (i) {
            final isDone = i < active;
            final isCurrent = i == active;
            final isLast = i == steps.length - 1;
            final done = cancelled ? i == 0 : isDone;
            final curr = cancelled ? false : isCurrent;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: done ? _accent : (curr ? _accent.withAlpha(30) : Colors.grey.shade200),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: cancelled && i > 0
                              ? Icon(Icons.close, size: 14, color: Colors.red.withAlpha(150))
                              : done
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : curr
                                      ? const Icon(Icons.more_horiz, size: 16, color: AppColors.primary)
                                      : Icon(Icons.circle, size: 8, color: Colors.grey.shade300),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2, height: 32,
                          color: cancelled || done ? _accent.withAlpha(80) : Colors.grey.shade200,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i], style: TextStyle(
                          fontSize: 14,
                          fontWeight: done || curr ? FontWeight.w600 : FontWeight.normal,
                          color: done || curr ? AppColors.textPrimary : AppColors.textHint,
                        )),
                        if (curr && !cancelled)
                          Text('In progress', style: TextStyle(fontSize: 11, color: _accent)),
                        if (cancelled && i == 0)
                          const Text('Cancelled', style: TextStyle(fontSize: 11, color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final OrderData order;
  const _InfoBox({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.receipt_outlined, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text('Order Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Order ID', '#${order.id.length > 12 ? order.id.substring(0, 12).toUpperCase() : order.id.toUpperCase()}'),
          _infoRow('Date', '${order.date.day}/${order.date.month}/${order.date.year}'),
          _infoRow('Payment', 'Cash on Delivery'),
          _infoRow('Items', '${order.items.length} item${order.items.length > 1 ? 's' : ''}'),
          if (order.deliveryAddress != null) _infoRow('Delivery', order.deliveryAddress!),
          const Divider(height: 24),
          Row(
            children: [
              const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              Text('₹${order.total}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ItemsBox extends StatelessWidget {
  final OrderData order;
  const _ItemsBox({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.success.withAlpha(15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shopping_bag_outlined, size: 20, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          ...order.items.map((item) => Container(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: item.color.withAlpha(15), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: item.color))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('₹${item.price} × ${item.count}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Text('₹${item.price * item.count}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
