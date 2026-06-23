import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';
import 'home_page.dart';
import 'orders_page.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final String? orderId;
  final String? intentId;
  final int total;
  final String? razorpayOrderId;
  final String? razorpayKeyId;
  final int? razorpayAmount;
  final VoidCallback? onPaymentSuccess;

  const PaymentGatewayScreen({
    super.key,
    this.orderId,
    this.intentId,
    required this.total,
    this.razorpayOrderId,
    this.razorpayKeyId,
    this.razorpayAmount,
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

  String get _refLabel {
    if (widget.intentId != null) return widget.intentId!.substring(0, 8);
    return widget.orderId?.substring(0, 8) ?? '';
  }

  Future<void> _openCheckout() async {
    setState(() => _initializing = true);

    try {
      String keyId;
      int amount;
      String razorpayOrderId;

      // New flow: use pre-created PaymentIntent data
      if (widget.intentId != null &&
          widget.razorpayOrderId != null &&
          widget.razorpayKeyId != null &&
          widget.razorpayAmount != null) {
        keyId = widget.razorpayKeyId!;
        amount = widget.razorpayAmount!;
        razorpayOrderId = widget.razorpayOrderId!;
      } else if (widget.orderId != null) {
        // Retry flow: fetch Razorpay order from existing order
        final result = await _api.createRazorpayOrder(widget.orderId!);
        keyId = result['key_id'] as String;
        amount = result['amount'] as int;
        razorpayOrderId = result['razorpay_order_id'] as String;
      } else {
        throw Exception('Missing payment reference');
      }

      final options = {
        'key': keyId,
        'amount': amount,
        'order_id': razorpayOrderId,
        'currency': 'INR',
        'name': 'Zipra',
        'description': 'Order #$_refLabel',
        'theme': {'color': '#FF6B35'},
      };

      setState(() => _initializing = false);

      _razorpay?.open(options);
      setState(() => _checkoutOpen = true);
    } catch (e) {
      setState(() => _initializing = false);
      debugPrint('PaymentGatewayScreen._openCheckout error: $e');
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
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (paymentId == null || signature == null) {
      AppSnackbar.show(context, 'Invalid payment response received', type: SnackbarType.error);
      return;
    }
    _verifyPayment(paymentId, signature);
  }

  Future<void> _handleError(PaymentFailureResponse response) async {
    if (!mounted) return;
    setState(() => _checkoutOpen = false);

    String? orderId;
    if (widget.intentId != null) {
      try {
        final result = await _api.cancelPaymentIntent(widget.intentId!);
        orderId = result['order_id'] as String?;
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentFailedScreen(
          orderId: orderId ?? widget.orderId,
          total: widget.total,
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    debugPrint('External wallet: ${response.walletName}');
  }

  Future<void> _verifyPayment(String paymentId, String signature) async {
    try {
      if (widget.intentId != null) {
        await _api.verifyRazorpayPayment(
          intentId: widget.intentId,
          paymentId: paymentId,
          signature: signature,
        );
      } else if (widget.orderId != null) {
        await _api.verifyRazorpayPayment(
          orderId: widget.orderId,
          paymentId: paymentId,
          signature: signature,
        );
      } else {
        throw Exception('Missing payment reference');
      }

      widget.onPaymentSuccess?.call();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OrderStatusPage()),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentFailedScreen(
            orderId: widget.orderId,
            total: widget.total,
          ),
        ),
      );
    }
  }

  Future<void> _handleBack() async {
    _razorpay?.clear();

    String? orderId;
    if (widget.intentId != null) {
      try {
        final result = await _api.cancelPaymentIntent(widget.intentId!);
        orderId = result['order_id'] as String?;
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentFailedScreen(
          orderId: orderId ?? widget.orderId,
          total: widget.total,
        ),
      ),
    );
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
          onPressed: _handleBack,
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
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
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
                  child:                   ElevatedButton(
                    onPressed: () async {
                      await Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomePage()),
                        (route) => false,
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OrdersPage()),
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

class PaymentFailedScreen extends StatelessWidget {
  final String? orderId;
  final int total;

  const PaymentFailedScreen({super.key, this.orderId, required this.total});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
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
                    color: AppColors.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your Order Payment Failed',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please retry payment to complete your order.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomePage()),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Go to Home',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (orderId != null)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentGatewayScreen(
                              orderId: orderId,
                              total: total,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment_rounded, size: 20),
                      label: const Text(
                        'Retry Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () async {
                      await Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomePage()),
                        (route) => false,
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OrdersPage()),
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
