import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';
import 'orders_page.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final String orderId;
  final int total;
  final VoidCallback? onPaymentSuccess;

  const PaymentGatewayScreen({
    super.key,
    required this.orderId,
    required this.total,
    this.onPaymentSuccess,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  final _api = ApiService();
  Razorpay? _razorpay;
  bool _initializing = false;
  bool _checkoutOpen = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _openCheckout();
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _openCheckout() async {
    setState(() => _initializing = true);

    try {
      final result = await _api.createRazorpayOrder(widget.orderId);
      final options = {
        'key': result['key_id'],
        'amount': result['amount'],
        'order_id': result['razorpay_order_id'],
        'currency': 'INR',
        'name': 'Zipra',
        'description': 'Order #${widget.orderId.substring(0, 8)}',
        'theme': {'color': '#FF6B35'},
      };

      setState(() => _initializing = false);

      _razorpay?.open(options);
      setState(() => _checkoutOpen = true);
    } catch (e) {
      setState(() => _initializing = false);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Failed to initialize payment: $e',
        type: SnackbarType.error,
      );
      Navigator.pop(context);
    }
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    setState(() => _checkoutOpen = false);
    _verifyPayment(response.paymentId!, response.signature!);
  }

  void _handleError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _checkoutOpen = false);
    AppSnackbar.show(
      context,
      'Payment failed: ${response.message}',
      type: SnackbarType.error,
    );
    Navigator.pop(context);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    debugPrint('External wallet: ${response.walletName}');
  }

  Future<void> _verifyPayment(String paymentId, String signature) async {
    try {
      await _api.verifyRazorpayPayment(widget.orderId, paymentId, signature);
      widget.onPaymentSuccess?.call();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OrderStatusPage()),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Payment verification failed: $e',
        type: SnackbarType.error,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Gateway'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _razorpay?.clear();
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: _initializing
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Connecting to payment gateway...',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment initiated',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${widget.total}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!_checkoutOpen)
                    ElevatedButton(
                      onPressed: _openCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry Payment'),
                    ),
                ],
              ),
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
  @override
  void initState() {
    super.initState();
    _navigateHome();
  }

  void _navigateHome() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OrdersPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OrdersPage()),
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
                  'Payment Successful!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your order has been placed and payment confirmed.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const OrdersPage()),
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
                      'View My Orders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
