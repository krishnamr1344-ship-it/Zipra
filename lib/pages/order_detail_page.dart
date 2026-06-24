import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';
import 'payment_gateway_screen.dart';

class OrderDetailPage extends StatelessWidget {
  final OrderData order;
  const OrderDetailPage({super.key, required this.order});

  bool get _showOtp =>
      order.deliveryOtp != null &&
      order.deliveryOtp!.isNotEmpty &&
      (order.status == 'Out For Delivery' || order.status == 'Shipped');

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusBox(order: order),
            const SizedBox(height: 16),
            if (_showOtp) ...[
              _OtpBox(deliveryOtp: order.deliveryOtp!),
              const SizedBox(height: 16),
            ],
            _InfoBox(order: order),
            const SizedBox(height: 16),
            _ItemsBox(order: order),
            if (order.status == 'Pending' || order.status == 'Failed') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentGatewayScreen(
                          orderId: order.id,
                          total: order.total,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment_rounded, size: 20),
                  label: Text(
                    order.status == 'Failed' ? 'Retry Payment' : 'Pay Now',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

class _OtpBox extends StatelessWidget {
  final String deliveryOtp;
  const _OtpBox({required this.deliveryOtp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'Share this code with the delivery partner',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(deliveryOtp.length, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 42,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Center(
                  child: Text(
                    deliveryOtp[i],
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.white70),
                  SizedBox(width: 6),
                  Text(
                    'Do not share unless you are receiving your order',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      case 'Out For Delivery': return const Color(0xFF9C27B0);
      case 'Delivered': return AppColors.success;
      case 'Cancelled': return AppColors.error;
      case 'Failed': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  int get _activeIndex {
    switch (order.status) {
      case 'Pending': return 0;
      case 'Confirmed': return 1;
      case 'Shipped': return 2;
      case 'Out For Delivery': return 3;
      case 'Delivered': return 4;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final failed = order.status == 'Failed';
    if (failed) return _buildFailedStatus(context);

    final steps = ['Placed', 'Confirmed', 'Shipped', 'Out For Delivery', 'Delivered'];
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
                decoration: BoxDecoration(
                  color: _accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.checklist, size: 22, color: _accent),
              ),
              const SizedBox(width: 12),
              const Text('Order Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(order.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _accent)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent.withAlpha(8), _accent.withAlpha(3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withAlpha(18)),
            ),
            child: Column(
              children: List.generate(steps.length, (i) {
                final isDone = i < active;
                final isCurrent = i == active;
                final isLast = i == steps.length - 1;
                final terminal = cancelled;
                final done = terminal ? i == 0 : isDone;
                final curr = terminal ? false : isCurrent;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: done || curr
                                  ? LinearGradient(
                                      colors: [_accent, _accent.withAlpha(200)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: done || curr ? null : Colors.grey.shade200,
                              shape: BoxShape.circle,
                              boxShadow: curr
                                  ? [BoxShadow(color: _accent.withAlpha(80), blurRadius: 10, spreadRadius: 1)]
                                  : done
                                      ? [BoxShadow(color: _accent.withAlpha(40), blurRadius: 6)]
                                      : null,
                            ),
                            child: Center(
                              child: terminal && i > 0
                                  ? Icon(Icons.close, size: 14, color: Colors.red.withAlpha(150))
                                  : done
                                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                                      : curr
                                          ? Container(
                                              width: 10,
                                              height: 10,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                            )
                                          : Icon(Icons.circle, size: 8, color: Colors.grey.shade400),
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: done
                                    ? LinearGradient(
                                        colors: [_accent.withAlpha(120), _accent.withAlpha(60)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      )
                                    : null,
                                color: done ? null : Colors.grey.shade200,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 18),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedStatus(BuildContext context) {
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
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.error_outline, size: 22, color: AppColors.error),
              ),
              const SizedBox(width: 12),
              const Text('Payment Failed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Failed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withAlpha(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.payment, size: 24, color: AppColors.error),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment could not be processed',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your order has been placed but payment failed. Click "Retry Payment" to try again with a different payment method.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withAlpha(30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your items are still reserved. Complete payment within the time limit to avoid order cancellation.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
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
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_outlined, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text('Order Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _infoItem(Icons.tag, 'Order ID', '#${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}')),
              const SizedBox(width: 12),
              Expanded(child: _infoItem(Icons.calendar_today, 'Date', '${order.date.day}/${order.date.month}/${order.date.year}')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _infoItem(Icons.payment, 'Payment', order.paymentMethod)),
              const SizedBox(width: 12),
              Expanded(child: _infoItem(Icons.shopping_bag, 'Items', '${order.items.length} item${order.items.length > 1 ? 's' : ''}')),
            ],
          ),
          if (order.deliveryAddress != null) ...[
            const SizedBox(height: 12),
            _infoItem(Icons.location_on, 'Delivery', order.deliveryAddress!),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              Text('₹${order.total}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
              ],
            ),
          ),
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
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shopping_bag_outlined, size: 20, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              Text('${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: item.color.withAlpha(25),
                  child: Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: item.color),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Text('₹${item.price} × ${item.count}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('₹${item.price * item.count}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
