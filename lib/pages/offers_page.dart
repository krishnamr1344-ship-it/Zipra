import 'package:flutter/material.dart';
import '../models/combo_pack.dart';
import '../services/api_service.dart';
import 'pack_detail_sheet.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  final _api = ApiService();
  List<ComboPack> _packs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  Future<void> _loadPacks() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getComboPacks();
      if (!mounted) return;
      setState(() {
        _packs = data.map((e) => ComboPack.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFF6B00).withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.inventory_2, color: Color(0xFFFF6B00), size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Monthly Needs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Stock up & save big on bulk essentials', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          if (_packs.isEmpty) ...[
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No packs available', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          ] else ...[
            ..._packs.map((pack) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPackCard(pack),
            )),
          ],
        ],
      ),
    );
  }

  void _showPackDetail(ComboPack pack) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PackDetailSheet(pack: pack),
    );
  }

  Widget _buildPackCard(ComboPack pack) {
    final totalMrp = pack.items.fold<double>(0, (sum, item) => sum + item.productPrice * item.quantity);
    final savings = totalMrp - pack.totalPrice;

    return GestureDetector(
      onTap: () => _showPackDetail(pack),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF8C38)]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Center(
                    child: Text(pack.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                if (pack.discountLabel != null)
                  Positioned(
                    top: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomLeft: Radius.circular(12)),
                      ),
                      child: Text(pack.discountLabel!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pack.description != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(pack.description!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ),
                  ...pack.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFFFF6B00), shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${item.productName} × ${item.quantity}${item.productUnit}', style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
                        ),
                        Text('₹${(item.productPrice * item.quantity).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
                      ],
                    ),
                  )),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Total: ', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                              if (totalMrp > pack.totalPrice)
                                Text('₹${totalMrp.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, color: Color(0xFFAAAAAA), decoration: TextDecoration.lineThrough)),
                              const SizedBox(width: 8),
                              Text('₹${pack.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                            ],
                          ),
                          if (savings > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Save ₹${savings.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
                            ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () => _showPackDetail(pack),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('View Pack', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
