import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/cart_model.dart';

class QuantitySelector extends StatefulWidget {
  final CartItem item;
  final VoidCallback onRemoved;

  const QuantitySelector({
    super.key,
    required this.item,
    required this.onRemoved,
  });

  @override
  State<QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animCtl,
      curve: Curves.elasticInOut,
    );
  }

  @override
  void dispose() {
    _animCtl.dispose();
    super.dispose();
  }

  void _animate() {
    _animCtl.forward().then((_) => _animCtl.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityBtn(
            icon: Icons.remove,
            onTap: () {
              if (widget.item.count > 1) {
                cartNotifier.updateCount(widget.item.productId, -1);
                _animate();
              } else {
                cartNotifier.removeAll(widget.item.productId);
                widget.onRemoved();
              }
            },
          ),
          SizedBox(
            width: 40,
            child: AnimatedBuilder(
              animation: _scaleAnim,
              builder: (_, child) => Transform.scale(
                scale: 1 + (_scaleAnim.value * 0.18),
                child: child,
              ),
              child: Center(
                child: Text(
                  '${widget.item.count}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          _QuantityBtn(
            icon: Icons.add,
            onTap: () {
              cartNotifier.updateCount(widget.item.productId, 1);
              _animate();
            },
          ),
        ],
      ),
    );
  }
}

class _QuantityBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.success, size: 18),
        ),
      ),
    );
  }
}
