import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';
import 'home_page.dart';
import 'orders_page.dart';
import 'delivery_location_page.dart';
import 'payment_gateway_screen.dart' show PaymentGatewayScreen;

class PaymentPage extends StatefulWidget {
  final int total;
  const PaymentPage({super.key, required this.total});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _api = ApiService();
  bool _processing = false;
  String _selectedMethod = 'razorpay';

  String _deliveryArea = '';
  String _deliveryDetail = '';
  String _deliveryLandmark = '';
  String _addressId = '';

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final addresses = await _api.getAddresses();
      if (!mounted) return;
      if (addresses.isNotEmpty) {
        final addr = addresses.firstWhere(
          (a) => (a['latitude'] != null && a['longitude'] != null),
          orElse: () => addresses.first,
        );
        setState(() {
          _addressId = addr['id'] ?? '';
          _deliveryArea = (addr['address_line2'] ?? '').isNotEmpty
              ? '${addr['address_line2']}, ${addr['city'] ?? ''}'
              : addr['city'] ?? '';
          _deliveryDetail = addr['address_line1'] ?? '';
          _deliveryLandmark = addr['landmark'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("pages.payment_page: $e");
    }
  }

  Future<void> _setDelivery() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryLocationPage()),
    );
    if (result != null) {
      await _loadAddress();
    }
  }

  Future<void> _pay() async {
    if (_addressId.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Delivery Address'),
          content: const Text(
            'Please set your delivery location before placing the order.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Set Location'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _setDelivery();
        if (_addressId.isEmpty) return;
      } else {
        return;
      }
    }

    setState(() => _processing = true);
    if (!mounted) return;
    try {
      final items = cartNotifier.items
          .map((i) => ({'product_id': i.productId, 'quantity': i.count}))
          .toList();

      final intent = await _api.createPaymentIntent(
        items,
        _addressId.isNotEmpty ? _addressId : null,
      );
      final intentId = intent['intent_id'] as String?;

      if (intentId == null) {
        throw Exception('Failed to create payment intent');
      }

      setState(() => _processing = false);
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PaymentGatewayScreen(
                intentId: intentId,
                total: widget.total,
                razorpayOrderId: intent['razorpay_order_id'] as String?,
                razorpayKeyId: intent['key_id'] as String?,
                razorpayAmount: intent['amount'] as int?,
                onPaymentSuccess: () => cartNotifier.clear(),
              ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _processing = false);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Failed to place order. $e',
        type: SnackbarType.error,
      );
    }
  }

  Widget _methodTile(
    IconData icon,
    String title,
    String subtitle,
    String value,
  ) {
    final selected = _selectedMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.chipBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : Colors.grey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${widget.total}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _setDelivery,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _addressId.isNotEmpty
                          ? AppColors.successLight
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _addressId.isNotEmpty
                            ? AppColors.success.withAlpha(80)
                            : Colors.orange.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _addressId.isNotEmpty
                                ? AppColors.success.withAlpha(20)
                                : Colors.orange.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _addressId.isNotEmpty
                                ? Icons.location_on
                                : Icons.add_location,
                            size: 24,
                            color: _addressId.isNotEmpty
                                ? AppColors.success
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _addressId.isNotEmpty
                                    ? 'Delivery Location'
                                    : 'Set Delivery Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: _addressId.isNotEmpty
                                      ? AppColors.textPrimary
                                      : Colors.orange.shade800,
                                ),
                              ),
                              if (_addressId.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _deliveryArea,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (_deliveryDetail.isNotEmpty)
                                  Text(
                                    _deliveryDetail,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                if (_deliveryLandmark.isNotEmpty)
                                  Text(
                                    '📍 $_deliveryLandmark',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade600,
                                    ),
                                  ),
                              ] else
                                Text(
                                  'Tap to add delivery address',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _methodTile(
                  Icons.credit_card_outlined,
                  'Pay Online',
                  'Credit / Debit card, UPI, Net Banking',
                  'razorpay',
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _processing ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Place Order · ₹${widget.total}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderStatusPage extends StatefulWidget {
  const OrderStatusPage({super.key});

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  int _seconds = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_seconds > 1) {
        setState(() => _seconds--);
      } else {
        _timer?.cancel();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        _timer?.cancel();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      },
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 64,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Order Placed!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your order has been placed successfully.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Order Confirmed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Redirecting to home in $_seconds s...',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      _timer?.cancel();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomePage()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Skip to Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () {
                      _timer?.cancel();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const OrdersPage()),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'View My Orders',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
