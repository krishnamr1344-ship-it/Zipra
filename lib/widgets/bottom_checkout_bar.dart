import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../services/api_service.dart';
import 'app_snackbar.dart';
import '../pages/login_page.dart';
import '../pages/payment_page.dart';

class BottomCheckoutBar extends StatefulWidget {
  final VoidCallback? onCheckout;

  const BottomCheckoutBar({super.key, this.onCheckout});

  @override
  State<BottomCheckoutBar> createState() => _BottomCheckoutBarState();
}

class _BottomCheckoutBarState extends State<BottomCheckoutBar>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late AnimationController _animCtl;
  late Animation<double> _pulseAnim;
  int _deliveryFee = 40;
  int _freeThreshold = 499;

  @override
  void initState() {
    super.initState();
    _animCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseAnim = CurvedAnimation(
      parent: _animCtl,
      curve: Curves.easeInOut,
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _animCtl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _api.getSettings();
      if (mounted) {
        setState(() {
          _deliveryFee = data['delivery_fee'] ?? 40;
          _freeThreshold = data['free_delivery_threshold'] ?? 499;
        });
      }
    } catch (_) {}
  }

  void _pulse() {
    _animCtl.forward().then((_) => _animCtl.reverse());
  }

  Future<void> _onCheckout() async {
    _pulse();
    if (widget.onCheckout != null) {
      widget.onCheckout!();
      return;
    }

    final sub = cartNotifier.total;
    if (sub <= 0) {
      if (mounted) {
        AppSnackbar.show(context, 'Your cart is empty', type: SnackbarType.warning);
      }
      return;
    }

    final token = await ApiService().getToken();
    if (token == null) {
      if (!mounted) return;
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (loggedIn != true) return;
    }
    if (!mounted) return;
    final delivery = sub >= _freeThreshold ? 0 : _deliveryFee;
    final total = sub + delivery;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentPage(total: total)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = cartNotifier.total;
    final delivery = sub >= _freeThreshold ? 0 : _deliveryFee;
    final total = sub + delivery;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹$total',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF6B00),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: 1 - (_pulseAnim.value * 0.03),
              child: child,
            ),
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _onCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Checkout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFFFF6B00),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
