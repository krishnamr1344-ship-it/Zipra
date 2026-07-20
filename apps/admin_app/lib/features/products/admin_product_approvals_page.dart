import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/theme.dart';
import '../../core/api/admin_api_service.dart';

class AdminProductApprovalsPage extends StatefulWidget {
  const AdminProductApprovalsPage({super.key});

  @override
  State<AdminProductApprovalsPage> createState() =>
      _AdminProductApprovalsPageState();
}

class _AdminProductApprovalsPageState extends State<AdminProductApprovalsPage> {
  final _api = AdminApiService();
  List<dynamic> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final products = await _api.getPendingProducts();
      if (!mounted) return;
      setState(() {
        _pending = products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _approve(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Approve Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 30, color: AppColors.success),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Approve "$name" and make it visible to customers?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.approveProduct(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product approved'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
    }
  }

  Future<void> _reject(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Reject Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_rounded,
                  size: 30, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Reject "$name"? It will not appear in the customer app.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.rejectProduct(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product rejected'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
    }
  }

  void _showEditForm(Map<String, dynamic> product) {
    final nameCtl = TextEditingController(text: product['name'] ?? '');
    final origPriceCtl = TextEditingController(
      text: product['original_price']?.toString() ?? '',
    );
    final offerCtl = TextEditingController(
      text: product['price']?.toString() ?? '',
    );
    final unitCtl = TextEditingController(text: product['unit'] ?? '');
    final stockCtl =
        TextEditingController(text: product['stock']?.toString() ?? '0');
    final images = List.generate(
        3,
        (i) => TextEditingController(
              text: product['images'] != null && i < (product['images'] as List).length
                  ? (product['images'] as List)[i]?.toString() ?? ''
                  : '',
            ));
    String? catId = product['category_id'];
    bool saving = false;

    InputDecoration inputDeco(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceDim,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    left: 24, right: 24, top: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Text('Edit Product',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(controller: nameCtl, decoration: inputDeco('Product Name')),
                      const SizedBox(height: AppSpacing.md),
                      TextField(controller: origPriceCtl, decoration: inputDeco('Original Price'),
                          keyboardType: TextInputType.number),
                      const SizedBox(height: AppSpacing.md),
                      TextField(controller: offerCtl, decoration: inputDeco('Offer Price'),
                          keyboardType: TextInputType.number),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(controller: unitCtl, decoration: inputDeco('Unit'),
                                keyboardType: TextInputType.text),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TextField(controller: stockCtl, decoration: inputDeco('Stock'),
                                keyboardType: TextInputType.number),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text('Images (URL or upload)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.sm),
                      ...List.generate(3, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: images[i],
                                  decoration: InputDecoration(
                                    hintText: 'Image ${i + 1} URL',
                                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                                    filled: true,
                                    fillColor: AppColors.surfaceDim,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              GestureDetector(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(source: ImageSource.gallery);
                                  if (picked == null) return;
                                  try {
                                    final result = await _api.uploadProductImage(
                                        product['id'], File(picked.path));
                                    images[i].text = result['image_url'];
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
                                      );
                                    }
                                  }
                                },
                                child: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceDim,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: images[i].text.isNotEmpty && !images[i].text.startsWith('http')
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          child: Image.file(File(images[i].text), width: 44, height: 44, fit: BoxFit.cover),
                                        )
                                      : images[i].text.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(AppRadius.md),
                                              child: Image.network(AdminApiService.resolveImageUrl(images[i].text), width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, e, s) => const Icon(Icons.image, color: AppColors.textHint)),
                                            )
                                          : const Icon(Icons.image, color: AppColors.textHint, size: 22),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  setSheetState(() => saving = true);
                                  try {
                                    final List<String> urls = [];
                                    for (final c in images) {
                                      final val = c.text.trim();
                                      if (val.startsWith('http')) urls.add(val);
                                    }
                                    final data = {
                                      'category_id': catId ?? '',
                                      'name': nameCtl.text,
                                      'price': double.tryParse(offerCtl.text) ?? 0,
                                      'unit': unitCtl.text,
                                      'stock': int.tryParse(stockCtl.text) ?? 0,
                                      'images': urls,
                                      'original_price': double.tryParse(origPriceCtl.text) ?? 0,
                                    };
                                    await _api.updateProduct(product['id'], data);
                                    if (!context.mounted) return;
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Product updated'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
                                    );
                                    _load();
                                  } catch (e) {
                                    setSheetState(() => saving = false);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            elevation: 0,
                          ),
                          child: saving
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.approval_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Product Approvals',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('${_pending.length} pending',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
              if (_pending.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${_pending.length}',
                    style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_pending.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      itemCount: _pending.length,
      itemBuilder: (_, i) =>
          _buildApprovalCard(_pending[i] as Map<String, dynamic>),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
      itemCount: 4,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 48, color: AppColors.success),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('All caught up!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          const Text('No products pending approval',
              style: TextStyle(fontSize: 13, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> p) {
    final images = (p['images'] as List?) ?? [];
    final thumb = images.isNotEmpty ? images[0]?.toString() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [AppShadows.soft],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.lg)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDim,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          child: thumb != null && thumb.isNotEmpty
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  child: Image.network(AdminApiService.resolveImageUrl(thumb),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                          errorBuilder: (_, e, s) =>
                                          Center(
                                            child: Text(
                                                (p['name']?.toString().isEmpty ?? true ? '' : p['name'].toString()[0])
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.accent)),
                                          )),
                                )
                              : Center(
                                  child: Text(
                                      (p['name']?.toString().isEmpty ?? true ? '?' : p['name'].toString()[0])
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accent)),
                                ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                      '₹${p['price']} / ${p['unit'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w700)),
                                  if (p['category_name'] != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentBg,
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.sm),
                                      ),
                                      child: Text(p['category_name'],
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Stock: ${p['stock']}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textHint)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showEditForm(p),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit details'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _reject(p['id'], p['name']),
                            icon: const Icon(Icons.close_rounded,
                                size: 18),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.md)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _approve(p['id'], p['name']),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.md)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
