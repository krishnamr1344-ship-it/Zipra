import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/theme.dart';
import '../../core/models/cart_model.dart';
import '../../core/api/api_service.dart';
import '../home/home_page.dart';
import '../orders/orders_page.dart';
import '../location/pages/delivery_location_page.dart';

class PaymentPage extends StatefulWidget {
  final int total;
  const PaymentPage({super.key, required this.total});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _api = ApiService();
  bool _processing = false;

  String _deliveryArea = '';
  String _deliveryDetail = '';
  String _deliveryLandmark = '';
  String _addressId = '';

  double _deliveryFee = 0;
  String _deliveryFeeMsg = '';

  int get _grandTotal => widget.total + _deliveryFee.round();

  @override
  void initState() {
    super.initState();
    _loadAddress();
    _loadFee();
  }

  Future<void> _loadFee() async {
    try {
      final data = await _api.getDeliveryFee(widget.total.toDouble());
      if (!mounted) return;
      setState(() {
        _deliveryFee = (data['fee'] as num?)?.toDouble() ?? 0;
        _deliveryFeeMsg = data['message'] as String? ?? '';
      });
    } catch (_) {}
  }

  Future<void> _loadAddress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _addressId = prefs.getString('gps_address_id') ?? '';
      final line1 = prefs.getString('gps_address_line') ?? '';
      final line2 = prefs.getString('gps_address_line2') ?? '';
      final city = prefs.getString('gps_city') ?? '';
      _deliveryLandmark = prefs.getString('gps_landmark') ?? '';
      _deliveryArea = line2.isNotEmpty ? line2 : city.isNotEmpty ? city : '';
      _deliveryDetail = line1;
    });
  }

  Future<void> _setDelivery() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryLocationPage()),
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gps_address_id', result['id'] ?? '');
      await prefs.setString('gps_address_line', result['address_line1'] ?? '');
      await prefs.setString('gps_address_line2', result['address_line2'] ?? '');
      await prefs.setString('gps_city', result['city'] ?? '');
      await prefs.setString('gps_landmark', result['landmark'] ?? '');
      await prefs.setString('gps_latitude', '${result['latitude'] ?? ''}');
      await prefs.setString('gps_longitude', '${result['longitude'] ?? ''}');
      await prefs.setString('gps_pincode', result['pincode'] ?? '');
      await _loadAddress();
    }
  }

  Future<void> _pay() async {
    if (_addressId.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delivery Address'),
          content: const Text('Please set your delivery location before placing the order.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary), child: const Text('Set Location')),
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
      final items = cartNotifier.items.map((i) => ({
        'product_id': i.productId,
        'quantity': i.count,
      })).toList();
      await _api.createOrder(items, 'cod', addressId: _addressId.isNotEmpty ? _addressId : null, deliveryFee: _deliveryFee);
    } catch (e) {
      setState(() => _processing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    cartNotifier.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OrderStatusPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment'), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('Subtotal', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          const Spacer(),
                          Text('₹${widget.total}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (_deliveryFee > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Delivery Fee', style: TextStyle(fontSize: 14, color: Colors.teal.shade700)),
                            const Spacer(),
                            Text('₹${_deliveryFee.round()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.teal.shade700)),
                          ],
                        ),
                      ],
                      if (_deliveryFeeMsg.isNotEmpty && _deliveryFee == 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                            Text(_deliveryFeeMsg, style: TextStyle(fontSize: 12, color: Colors.green.shade600)),
                          ],
                        ),
                      ],
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('₹$_grandTotal', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
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
                      color: _addressId.isNotEmpty ? AppColors.successLight : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _addressId.isNotEmpty ? AppColors.success.withAlpha(80) : Colors.orange.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _addressId.isNotEmpty ? AppColors.success.withAlpha(20) : Colors.orange.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_addressId.isNotEmpty ? Icons.location_on : Icons.add_location, size: 24, color: _addressId.isNotEmpty ? AppColors.success : Colors.orange),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_addressId.isNotEmpty ? 'Delivery Location' : 'Set Delivery Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _addressId.isNotEmpty ? AppColors.textPrimary : Colors.orange.shade800)),
                              if (_addressId.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(_deliveryArea, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                if (_deliveryDetail.isNotEmpty)
                                  Text(_deliveryDetail, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                if (_deliveryLandmark.isNotEmpty)
                                  Text('📍 ${_deliveryLandmark}', style: TextStyle(fontSize: 11, color: Colors.blue.shade600)),
                              ] else
                                Text('Tap to add delivery address', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.money_outlined, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cash on Delivery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                            Text('Pay when you receive', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.radio_button_checked, color: AppColors.primary, size: 22),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _processing
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text('Place Order · ₹$_grandTotal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_seconds > 1) {
        setState(() => _seconds--);
        _startTimer();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                child: const Icon(Icons.check_circle, size: 64, color: AppColors.success),
              ),
              const SizedBox(height: 24),
              const Text('Order Placed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Your order has been placed successfully.', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.hourglass_empty, color: AppColors.primaryLight, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Order Pending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text('Redirecting to home in $_seconds s...', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomePage()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Skip to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const OrdersPage()),
                      (route) => false,
                    );
                  },
                  child: const Text('View My Orders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
