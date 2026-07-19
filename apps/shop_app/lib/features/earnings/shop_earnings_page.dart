import 'package:flutter/material.dart';
import 'package:zipra_shop/core/constants/theme.dart';
import 'package:zipra_shop/core/api/shop_api_service.dart';
import 'package:zipra_shop/core/models/earning.dart';

class ShopEarningsPage extends StatefulWidget {
  const ShopEarningsPage({super.key});

  @override
  State<ShopEarningsPage> createState() => _ShopEarningsPageState();
}

class _ShopEarningsPageState extends State<ShopEarningsPage> {
  final _api = ShopApiService();
  EarningSummary? _summary;
  List<Earning> _earnings = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getEarningsSummary(),
        _api.getEarnings(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = EarningSummary.fromJson(results[0] as Map<String, dynamic>);
        _earnings = (results[1] as List)
            .map((e) => Earning.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load earnings: $e')),
      );
    }
  }

  List<Earning> get _filteredEarnings {
    if (_filter == 'pending') return _earnings.where((e) => e.status == 'pending').toList();
    if (_filter == 'settled') return _earnings.where((e) => e.status == 'settled').toList();
    return _earnings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w600)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? _buildShimmer()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_summary != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Settled',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '₹${_summary!.totalSettled.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        _SummaryMiniCard(
                          title: 'Today',
                          amount: _summary!.today,
                          color: AppColors.primary,
                          icon: Icons.today_rounded,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _SummaryMiniCard(
                          title: 'This Week',
                          amount: _summary!.thisWeek,
                          color: AppColors.info,
                          icon: Icons.date_range_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        _SummaryMiniCard(
                          title: 'This Month',
                          amount: _summary!.thisMonth,
                          color: AppColors.success,
                          icon: Icons.calendar_month_rounded,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _SummaryMiniCard(
                          title: 'Pending',
                          amount: _summary!.totalPending,
                          color: AppColors.warning,
                          icon: Icons.pending_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Transactions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _FilterChip(
                        label: 'All',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Pending',
                        selected: _filter == 'pending',
                        onTap: () => setState(() => _filter = 'pending'),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Settled',
                        selected: _filter == 'settled',
                        onTap: () => setState(() => _filter = 'settled'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (_filteredEarnings.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [AppShadows.soft],
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.surfaceDark),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            'No transactions found',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...(_filteredEarnings.map((e) => _EarningCard(earning: e))),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: List.generate(
        6,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  const _SummaryMiniCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.soft],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceDark,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EarningCard extends StatelessWidget {
  final Earning earning;
  const _EarningCard({required this.earning});

  @override
  Widget build(BuildContext context) {
    final isSettled = earning.status == 'settled';
    final statusColor = isSettled ? AppColors.success : AppColors.warning;
    final statusBg = isSettled ? AppColors.successLight : AppColors.warningLight;
    final orderIdShort = earning.orderId.length >= 8
        ? earning.orderId.substring(0, 8)
        : earning.orderId;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [AppShadows.soft],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              isSettled ? Icons.check_circle_rounded : Icons.schedule_rounded,
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #$orderIdShort',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Commission: ₹${earning.commission.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${earning.netAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  isSettled ? 'SETTLED' : 'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
