import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';
import 'delivery_location_page.dart';
import 'order_detail_page.dart';
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

    if (_selectedMethod == 'cash_on_delivery') {
      try {
        final order = await _api.placeOrder(_addressId, 'Cash on Delivery');
        final orderId = order['id'] as String?;
        if (orderId == null) throw Exception('Failed to create order');

        await _api.processPayment(orderId, 'Cash on Delivery');

        cartNotifier.clear();

        if (!mounted) return;

        final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        String? addr;
        if (order['delivery_address'] != null) {
          final da = order['delivery_address'] as Map<String, dynamic>;
          addr = '${da['address_line1'] ?? ''}, ${da['city'] ?? ''}';
        }
        final orderData = OrderData(
          id: orderId,
          total: ((order['total_amount'] ?? 0) as num).toDouble().round(),
          status: order['status'] ?? 'Confirmed',
          date: DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now(),
          deliveryAddress: addr,
          deliveryOtp: order['delivery_otp'],
          paymentMethod: 'Cash on Delivery',
          deliveryFee: ((order['delivery_fee'] ?? 0) as num).toDouble().round(),
          items: items.map((i) => CartItem(
            id: i['product_id'] ?? '',
            productId: i['product_id'] ?? '',
            name: i['product_name'] ?? '',
            qty: '',
            price: ((i['product_price'] ?? 0) as num).toDouble().round(),
            icon: Icons.shopping_bag,
            color: AppColors.success,
            count: i['quantity'] ?? 1,
          )).toList(),
        );

        setState(() => _processing = false);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => OrderDetailPage(order: orderData)),
          (route) => false,
        );
      } catch (e) {
        if (mounted) setState(() => _processing = false);
        if (!mounted) return;
        AppSnackbar.show(
          context,
          'Failed to place order. Please try again.',
          type: SnackbarType.error,
        );
      }
      return;
    }

    try {
      final items = cartNotifier.items
          .map((i) => ({'product_id': i.productId, 'quantity': i.count}))
          .toList();

      final intent = await _api.createPaymentIntent(
        items,
        _addressId.isNotEmpty ? _addressId : null,
      );
      final intentId = intent['intent_id'] as String?;
      final razorpayOrderId = intent['razorpay_order_id'] as String?;
      final razorpayKeyId = intent['key_id'] as String?;
      final razorpayAmount = intent['amount'] as int?;

      if (intentId == null || razorpayOrderId == null || razorpayKeyId == null || razorpayAmount == null) {
        debugPrint('payment_page: missing fields intentId=$intentId orderId=$razorpayOrderId keyId=$razorpayKeyId amount=$razorpayAmount');
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
                razorpayOrderId: razorpayOrderId,
                razorpayKeyId: razorpayKeyId,
                razorpayAmount: razorpayAmount,
                onPaymentSuccess: () => cartNotifier.clear(),
              ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _processing = false);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Failed to place order. Please try again.',
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
                const SizedBox(height: 12),
                _methodTile(
                  Icons.money_outlined,
                  'Cash on Delivery',
                  'Pay with cash when delivered',
                  'cash_on_delivery',
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
