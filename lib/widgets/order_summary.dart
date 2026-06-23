import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';

class OrderSummary extends StatelessWidget {
  const OrderSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final sub = cartNotifier.total;
    final itemCount = cartNotifier.itemCount;
    final delivery = sub >= 499 ? 0 : 40;
    final total = sub + delivery;
    final saving = delivery > 0 ? 0 : 40;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _SummaryRow(
              icon: Icons.shopping_bag_outlined,
              label: 'Subtotal ($itemCount items)',
              value: '₹$sub',
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              icon: Icons.delivery_dining_outlined,
              label: 'Delivery Fee',
              value: delivery == 0 ? 'FREE' : '₹$delivery',
              valueColor: delivery == 0 ? AppColors.success : null,
              valueWeight: delivery == 0 ? FontWeight.w700 : null,
            ),
            if (delivery > 0) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  'Add ₹${499 - sub} more for free delivery',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ],
            if (saving > 0) ...[
              const SizedBox(height: 12),
              _SavingsBanner(amount: saving),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF0F0F0)),
            ),
            _SummaryRow(
              icon: Icons.shield_outlined,
              label: 'Total Amount',
              value: '₹$total',
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              valueStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFF6B00),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final FontWeight? valueWeight;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWeight,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: labelStyle ?? TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: valueStyle ?? TextStyle(
            fontSize: 14,
            fontWeight: valueWeight ?? FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SavingsBanner extends StatelessWidget {
  final int amount;

  const _SavingsBanner({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Yay! You are saving ₹$amount on delivery',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
