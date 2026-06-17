import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

class ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF5F5F5),
                Color(0xFFEEEEEE),
              ],
              stops: [
                max(0.0, _animation.value - 0.5).clamp(0.0, 1.0),
                max(0.0, _animation.value).clamp(0.0, 1.0),
                min(1.0, _animation.value + 0.5).clamp(0.0, 1.0),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        );
      },
    );
  }
}

class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: const ShimmerWidget(width: double.infinity, height: 130),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerWidget(width: 40, height: 10),
                const SizedBox(height: 6),
                const ShimmerWidget(width: 90, height: 14),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const ShimmerWidget(width: 50, height: 16),
                    ShimmerWidget(width: 40, height: 28, borderRadius: 8),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen centered loading spinner with optional message.
class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Full-screen empty state with icon, title, optional subtitle, and optional action button.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.chipBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 64, color: iconColor ?? AppColors.textHint),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen error state with icon, message, and retry button.
class ErrorStateWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.cloud_off, size: 64, color: AppColors.error),
            ),
            const SizedBox(height: 20),
            const Text('Something went wrong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
