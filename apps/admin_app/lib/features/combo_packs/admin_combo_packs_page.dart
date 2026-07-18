import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/api/admin_api_service.dart';

class AdminComboPacksPage extends StatefulWidget {
  const AdminComboPacksPage({super.key});

  @override
  State<AdminComboPacksPage> createState() => _AdminComboPacksPageState();
}

class _AdminComboPacksPageState extends State<AdminComboPacksPage> {
  final _api = AdminApiService();
  List<Map<String, dynamic>> _packs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getComboPacks();
      if (!mounted) return;
      setState(() {
        _packs = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showForm([Map<String, dynamic>? pack]) {
    final nameCtl = TextEditingController(text: pack?['name'] ?? '');
    final descCtl =
        TextEditingController(text: pack?['description'] ?? '');
    final priceCtl = TextEditingController(
        text: pack != null ? '${pack['total_price']}' : '');
    final discountCtl =
        TextEditingController(text: pack?['discount_label'] ?? '');
    final savingsCtl =
        TextEditingController(text: pack?['savings_text'] ?? '');
    final imageCtl =
        TextEditingController(text: pack?['image_url'] ?? '');

    List<Map<String, dynamic>> items = [];
    if (pack != null && pack['items'] != null) {
      items = (pack['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    } else {
      items.add({'product_id': '', 'quantity': 1, 'product_name': ''});
    }

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
                      child: const Icon(Icons.inventory_2_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      pack == null ? 'Add Combo Pack' : 'Edit Combo Pack',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                _buildInput(nameCtl, 'Pack Name'),
                const SizedBox(height: AppSpacing.md),
                _buildInput(descCtl, 'Description', maxLines: 2),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                        child: _buildInput(priceCtl, 'Total Price (₹)')),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: _buildInput(discountCtl, 'Discount Label',
                            hint: 'e.g. 20% OFF')),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildInput(savingsCtl, 'Savings Text',
                    hint: 'e.g. Save ₹500'),
                const SizedBox(height: AppSpacing.md),
                _buildInput(imageCtl, 'Image URL (optional)'),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Text('Products in Pack',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setSheetState(() => items.add(
                            {'product_id': '', 'quantity': 1, 'product_name': ''}));
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Product'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent),
                    ),
                  ],
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: item['product_id'] ?? '',
                                decoration: InputDecoration(
                                  labelText: 'Product ID',
                                  hintText: item['product_name'] ?? '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.md),
                                    borderSide: BorderSide(
                                        color: AppColors.divider
                                            .withAlpha(120)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.md),
                                    borderSide: BorderSide(
                                        color: AppColors.divider
                                            .withAlpha(120)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.md),
                                    borderSide: const BorderSide(
                                        color: AppColors.accent,
                                        width: 1.5),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                                onChanged: (v) =>
                                    item['product_id'] = v,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextFormField(
                                initialValue: '${item['quantity'] ?? 1}',
                                decoration: InputDecoration(
                                  labelText: 'Qty',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.md),
                                    borderSide: BorderSide(
                                        color: AppColors.divider
                                            .withAlpha(120)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.md),
                                    borderSide: BorderSide(
                                        color: AppColors.divider
                                            .withAlpha(120)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.md),
                                    borderSide: const BorderSide(
                                        color: AppColors.accent,
                                        width: 1.5),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => item['quantity'] =
                                    int.tryParse(v) ?? 1,
                              ),
                            ),
                            if (items.length > 1)
                              IconButton(
                                icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: AppColors.error,
                                    size: 20),
                                onPressed: () => setSheetState(
                                    () => items.removeAt(i)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameCtl.text.trim().isEmpty) return;
                            if (priceCtl.text.trim().isEmpty) return;
                            setSheetState(() => saving = true);
                            try {
                              final body = {
                                'name': nameCtl.text.trim(),
                                'description': descCtl.text.trim().isEmpty
                                    ? null
                                    : descCtl.text.trim(),
                                'total_price':
                                    double.parse(priceCtl.text.trim()),
                                'discount_label':
                                    discountCtl.text.trim().isEmpty
                                        ? null
                                        : discountCtl.text.trim(),
                                'savings_text':
                                    savingsCtl.text.trim().isEmpty
                                        ? null
                                        : savingsCtl.text.trim(),
                                'image_url': imageCtl.text.trim().isEmpty
                                    ? null
                                    : imageCtl.text.trim(),
                                'items': items
                                    .where((e) => e['product_id']
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                    .map((e) => {
                                          'product_id': e['product_id']
                                              .toString()
                                              .trim(),
                                          'quantity':
                                              (e['quantity'] as int)
                                                  .clamp(1, 100),
                                        })
                                    .toList(),
                              };
                              if (pack == null) {
                                await _api.createComboPack(body);
                              } else {
                                await _api.updateComboPack(
                                    pack['id'], body);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              _load();
                            } catch (e) {
                              setSheetState(() => saving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('$e')));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg)),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            pack == null ? 'Create Pack' : 'Update Pack',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
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
      {String? hint, int maxLines = 1}) {
    return TextField(
      controller: ctl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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

  Future<void> _deletePack(Map<String, dynamic> pack) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Delete Pack'),
        content: Text('Delete "${pack['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.deleteComboPack(pack['id']);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  Future<void> _togglePack(Map<String, dynamic> pack) async {
    try {
      await _api.toggleComboPack(pack['id']);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
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
                child: const Icon(Icons.inventory_2_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Combo Packs',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('Monthly bundles & offers',
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
    if (_packs.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      itemCount: _packs.length,
      itemBuilder: (_, i) => _buildPackCard(_packs[i]),
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
              color: AppColors.accent.withAlpha(10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 48, color: AppColors.accentLight),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('No combo packs yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          const Text('Create your first bundle deal',
              style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => _showForm(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create First Pack'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackCard(Map<String, dynamic> pack) {
    final isEnabled = pack['is_enabled'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [AppShadows.soft],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.inventory_2_rounded,
                      color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pack['name'] ?? '',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      if (pack['description'] != null)
                        Text(pack['description'],
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textHint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? AppColors.successLight
                        : AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(isEnabled ? 'Enabled' : 'Disabled',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isEnabled
                              ? AppColors.success
                              : AppColors.textHint)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  '₹${pack['total_price']?.toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                if (pack['discount_label'] != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(pack['discount_label'],
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
                if (pack['savings_text'] != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(pack['savings_text'],
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  (pack['items'] as List<dynamic>?)?.map<Widget>((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${item['product_name'] ?? '?'} x${item['quantity'] ?? 1}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary),
                  ),
                );
              }).toList() ??
                  [],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              height: 1,
              color: AppColors.divider,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionBtn(
                  icon: isEnabled
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  tooltip: isEnabled ? 'Disable' : 'Enable',
                  color: AppColors.textSecondary,
                  onTap: () => _togglePack(pack),
                ),
                const SizedBox(width: 4),
                _actionBtn(
                  icon: Icons.edit_rounded,
                  tooltip: 'Edit',
                  color: AppColors.info,
                  onTap: () => _showForm(pack),
                ),
                const SizedBox(width: 4),
                _actionBtn(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete',
                  color: AppColors.error,
                  onTap: () => _deletePack(pack),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: color),
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
