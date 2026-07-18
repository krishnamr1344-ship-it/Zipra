import 'package:flutter/material.dart';
import 'package:zipra_shop/core/constants/theme.dart';
import 'package:zipra_shop/core/api/shop_api_service.dart';
import 'package:zipra_shop/core/models/shop_order.dart';

class ShopOrderDetailPage extends StatefulWidget {
  final ShopOrder order;
  const ShopOrderDetailPage({super.key, required this.order});

  @override
  State<ShopOrderDetailPage> createState() => _ShopOrderDetailPageState();
}

class _ShopOrderDetailPageState extends State<ShopOrderDetailPage> {
  final _api = ShopApiService();
  late ShopOrder _order;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _updateStatus(String action) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      Map<String, dynamic> result;
      switch (action) {
        case 'accept':
          result = await _api.acceptOrder(_order.id);
          break;
        case 'packing':
          result = await _api.startPacking(_order.id);
          break;
        case 'ready':
          result = await _api.markReady(_order.id);
          break;
        case 'deliver':
          result = await _api.markDelivered(_order.id);
          break;
        default:
          setState(() => _loading = false);
          return;
      }
      if (!mounted) return;
      setState(() {
        _order = ShopOrder.fromJson(result);
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${_order.status.replaceAll('_', ' ')}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
        );
      }
    }
  }

  void _showCancelDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Cancel Order'),
          ],
        ),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            hintText: 'Reason (optional)',
            hintStyle: const TextStyle(color: AppColors.textHint),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.surfaceDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.surfaceDark),
            ),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Order', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (!mounted) return;
              setState(() => _loading = true);
              try {
                final result = await _api.cancelOrder(_order.id, reason: reasonCtrl.text);
                if (!mounted) return;
                setState(() {
                  _order = ShopOrder.fromJson(result);
                  _loading = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order cancelled'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                setState(() => _loading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Cancel Order', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).then((_) => reasonCtrl.dispose());
  }

  Color _statusColor() {
    switch (_order.status) {
      case 'new':
        return AppColors.primary;
      case 'accepted':
        return AppColors.info;
      case 'packing':
        return AppColors.warning;
      case 'ready_for_pickup':
        return AppColors.success;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  List<Widget> _buildActions() {
    switch (_order.status) {
      case 'new':
        return [
          _ActionBtn(
            label: 'Accept Order',
            icon: Icons.check_rounded,
            color: AppColors.success,
            bgColor: AppColors.successLight,
            onPressed: () => _updateStatus('accept'),
          ),
          _ActionBtn(
            label: 'Reject',
            icon: Icons.close_rounded,
            color: AppColors.error,
            bgColor: AppColors.errorLight,
            onPressed: _showCancelDialog,
          ),
        ];
      case 'accepted':
        return [
          _ActionBtn(
            label: 'Start Packing',
            icon: Icons.inventory_2_outlined,
            color: AppColors.warning,
            bgColor: AppColors.warningLight,
            onPressed: () => _updateStatus('packing'),
          ),
          _ActionBtn(
            label: 'Cancel',
            icon: Icons.close_rounded,
            color: AppColors.error,
            bgColor: AppColors.errorLight,
            onPressed: _showCancelDialog,
          ),
        ];
      case 'packing':
        return [
          _ActionBtn(
            label: 'Mark Ready',
            icon: Icons.done_all_rounded,
            color: AppColors.success,
            bgColor: AppColors.successLight,
            onPressed: () => _updateStatus('ready'),
          ),
        ];
      case 'ready_for_pickup':
        return [
          _ActionBtn(
            label: 'Mark Delivered',
            icon: Icons.verified_rounded,
            color: AppColors.primary,
            bgColor: AppColors.infoLight,
            onPressed: () => _updateStatus('deliver'),
          ),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusColor();
    final orderIdShort = _order.orderId.length >= 8
        ? _order.orderId.substring(0, 8)
        : _order.orderId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Order #$orderIdShort',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [status.withValues(alpha: 0.12), status.withValues(alpha: 0.04)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: status.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: status.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_statusIcon(), color: status, size: 26),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _order.status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: status,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '₹${_order.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (_order.customerName != null || _order.customerPhone != null || _order.deliveryAddress != null) ...[
                    _SectionHeader(title: 'Customer Details'),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [AppShadows.soft],
                      ),
                      child: Column(
                        children: [
                          if (_order.customerName != null)
                            _DetailRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Customer',
                              value: _order.customerName!,
                            ),
                          if (_order.customerName != null && _order.customerPhone != null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                          if (_order.customerPhone != null)
                            _DetailRow(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: _order.customerPhone!,
                            ),
                          if (_order.customerPhone != null && _order.deliveryAddress != null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                          if (_order.deliveryAddress != null)
                            _DetailRow(
                              icon: Icons.location_on_outlined,
                              label: 'Delivery Address',
                              value: _order.deliveryAddress!,
                            ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),
                          _DetailRow(
                            icon: Icons.payment_rounded,
                            label: 'Payment',
                            value: _order.paymentMethod,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  _SectionHeader(title: 'Items (${_order.items.length})'),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [AppShadows.soft],
                    ),
                    child: Column(
                      children: _order.items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Column(
                          children: [
                            if (idx > 0) const Divider(height: 20),
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.infoLight,
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${item.quantity}x',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${item.productPrice.toStringAsFixed(0)} each',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${item.subtotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  if (_buildActions().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    _SectionHeader(title: 'Actions'),
                    const SizedBox(height: AppSpacing.sm),
                    ...(_buildActions().map((btn) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: btn,
                    ))),
                  ],

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
    );
  }

  IconData _statusIcon() {
    switch (_order.status) {
      case 'new':
        return Icons.fiber_new_rounded;
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'packing':
        return Icons.inventory_2_outlined;
      case 'ready_for_pickup':
        return Icons.done_all_rounded;
      case 'out_for_delivery':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.verified_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceDim,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
