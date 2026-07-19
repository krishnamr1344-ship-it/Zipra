import 'package:flutter/material.dart';
import '../constants/theme.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? bottom;

  const AdminAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom != null ? 56 : 0));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: showBack
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
              title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
              actions: actions?.map((a) => IconTheme(data: const IconThemeData(color: Colors.white), child: a)).toList(),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}

class AdminHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? child;

  const AdminHeader({super.key, required this.title, this.subtitle, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null) ...[
                Text(subtitle!, style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(160))),
                const SizedBox(height: 4),
              ],
              Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              if (child != null) ...[const SizedBox(height: AppSpacing.lg), child!],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;

  const AdminCard({super.key, required this.child, this.padding, this.margin, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: child,
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaText;
  final VoidCallback? onCta;

  const AdminEmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.ctaText, this.onCta});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.textHint),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppText.h3),
            const SizedBox(height: AppSpacing.sm),
            Text(subtitle, textAlign: TextAlign.center, style: AppText.bodySmall),
            if (ctaText != null && onCta != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: onCta,
                icon: const Icon(Icons.add, size: 18),
                label: Text(ctaText!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent)),
            SizedBox(height: AppSpacing.lg),
            Text('Loading...', style: AppText.bodySmall),
          ],
        ),
      ),
    );
  }
}

class AdminShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const AdminShimmerList({super.key, this.itemCount = 5, this.itemHeight = 80});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (_, __) => Container(
        height: itemHeight,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Gradient gradient;

  const AdminStatCard({super.key, required this.icon, required this.value, required this.label, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [BoxShadow(color: gradient.colors.first.withAlpha(40), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(200), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class AdminSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const AdminSearchBar({super.key, required this.controller, required this.hint, this.onChanged, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.soft],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textHint),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
                  onPressed: () {
                    controller.clear();
                    onClear?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
        ),
      ),
    );
  }
}

class AdminTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const AdminTabBar({super.key, required this.tabs, required this.selectedIndex, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: sel ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: sel ? [AppShadows.soft] : null,
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                      color: sel ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

SnackBar adminSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
  Color bg = AppColors.textPrimary;
  if (isError) bg = AppColors.error;
  if (isSuccess) bg = AppColors.success;

  return SnackBar(
    content: Row(
      children: [
        Icon(
          isError ? Icons.error_outline_rounded : (isSuccess ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded),
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
      ],
    ),
    backgroundColor: bg,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    margin: const EdgeInsets.all(AppSpacing.lg),
  );
}

Future<bool> showAdminConfirmDialog(BuildContext context, {required String title, required String message, String confirmText = 'Delete', bool isDestructive = true}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      content: Text(message, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: isDestructive ? AppColors.error : AppColors.accent,
          ),
          child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return result ?? false;
}
