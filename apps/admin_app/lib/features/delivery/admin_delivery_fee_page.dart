import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/theme.dart';
import '../../core/api/admin_api_service.dart';

class AdminDeliveryFeePage extends StatefulWidget {
  const AdminDeliveryFeePage({super.key});

  @override
  State<AdminDeliveryFeePage> createState() => _AdminDeliveryFeePageState();
}

class _AdminDeliveryFeePageState extends State<AdminDeliveryFeePage> {
  final _api = AdminApiService();
  List<Map<String, dynamic>> _fees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getDeliveryFees();
      if (!mounted) return;
      setState(() {
        _fees = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showForm([Map<String, dynamic>? fee]) {
    final minCtl = TextEditingController(
        text: fee?['min_order_amount']?.toString() ?? '0');
    final maxCtl = TextEditingController(
        text: fee?['max_order_amount']?.toString() ?? '');
    final feeCtl =
        TextEditingController(text: fee?['fee']?.toString() ?? '');
    bool active = fee?['is_active'] ?? true;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: AppSpacing.xxl,
              right: AppSpacing.xxl,
              top: AppSpacing.xxl),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      fee == null ? 'Add Delivery Fee' : 'Edit Delivery Fee',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(minCtl, 'Min Order (₹)',
                          keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildInput(maxCtl, 'Max Order (₹, optional)',
                          keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildInput(feeCtl, 'Delivery Fee (₹)',
                    keyboardType: TextInputType.number),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: SwitchListTile(
                    title: const Text('Active',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      active ? 'Fee is live' : 'Fee is hidden',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              active ? AppColors.success : AppColors.textHint),
                    ),
                    value: active,
                    onChanged: (v) => setSheetState(() => active = v),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg)),
                      elevation: 0,
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            final min = double.tryParse(minCtl.text) ?? 0;
                              final max = double.tryParse(maxCtl.text);
                            final f = double.tryParse(feeCtl.text);
                            if (f == null || f <= 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Enter a valid fee amount'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            try {
                              final Map<String, dynamic> data = {
                                'min_order_amount': min,
                                if (max != null) 'max_order_amount': max,
                                'fee': f,
                                'is_active': active,
                              };
                              if (fee == null) {
                                await _api.createDeliveryFee(data);
                              } else {
                                await _api.updateDeliveryFee(fee['id'], data);
                              }
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _load();
                            } catch (e) {
                              setSheetState(() => saving = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString()),
                                      behavior: SnackBarBehavior.floating));
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            fee == null ? 'Add Fee' : 'Save',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctl, String label,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctl,
      keyboardType: keyboardType,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: AppColors.divider.withAlpha(120)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: AppColors.divider.withAlpha(120)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 14),
        filled: true,
        fillColor: AppColors.surface,
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
                child: const Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery Fees',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('Manage delivery charges',
                        style: TextStyle(
                            fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 22),
                  onPressed: () => _showForm(),
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
    if (_fees.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      itemCount: _fees.length,
      itemBuilder: (_, i) => _buildFeeCard(_fees[i]),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
      itemCount: 4,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        height: 100,
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
              color: AppColors.accent.withAlpha(10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_rounded,
                size: 48, color: AppColors.accentLight),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('No delivery fees configured',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          const Text('Tap + to add your first fee tier',
              style: TextStyle(fontSize: 13, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildFeeCard(Map<String, dynamic> f) {
    final min = f['min_order_amount'] ?? 0;
    final max = f['max_order_amount'];
    final fee = f['fee'] ?? 0;
    final active = f['is_active'] ?? false;

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
              decoration: BoxDecoration(
                color: active ? AppColors.success : AppColors.textHint,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.lg)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '₹${(min as num).toStringAsFixed(0)} — ${max != null ? '₹${(max as num).toStringAsFixed(0)}' : 'No limit'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '₹${(fee as num).toStringAsFixed(0)} delivery',
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.successLight
                                      : AppColors.surfaceDim,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(active ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: active
                                            ? AppColors.success
                                            : AppColors.textHint)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 20, color: AppColors.textSecondary),
                          onPressed: () => _showForm(f),
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: AppColors.error),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.xl)),
                                title: const Text('Delete Fee Tier'),
                                content: const Text(
                                    'Remove this delivery fee configuration?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppColors.error),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await _api.deleteDeliveryFee(f['id']);
                                _load();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')));
                                }
                              }
                            }
                          },
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
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
