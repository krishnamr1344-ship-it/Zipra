import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';

class AdminOffersPage extends StatefulWidget {
  const AdminOffersPage({super.key});

  @override
  State<AdminOffersPage> createState() => _AdminOffersPageState();
}

class _AdminOffersPageState extends State<AdminOffersPage> {
  final _api = AdminApiService();
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getOffers();
      if (!mounted) return;
      setState(() { _offers = data.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForm([Map<String, dynamic>? offer]) async {
    final nameC = TextEditingController(text: offer?['name'] ?? '');
    final descC = TextEditingController(text: offer?['description'] ?? '');
    final discC = TextEditingController(text: offer?['discount_percent']?.toString() ?? '');
    final imgC = TextEditingController(text: offer?['image_url'] ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(offer != null ? 'Edit Offer' : 'New Offer'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nameC, decoration: const InputDecoration(labelText: 'Offer Name', border: OutlineInputBorder()), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(controller: descC, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 12),
                TextFormField(controller: discC, decoration: const InputDecoration(labelText: 'Discount %', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n < 1 || n > 100) return '1-100';
                  return null;
                }),
                const SizedBox(height: 12),
                TextFormField(controller: imgC, decoration: const InputDecoration(labelText: 'Image URL (optional)', border: OutlineInputBorder())),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx, {
              'name': nameC.text.trim(),
              'description': descC.text.trim().isEmpty ? null : descC.text.trim(),
              'discount_percent': int.parse(discC.text.trim()),
              'image_url': imgC.text.trim().isEmpty ? null : imgC.text.trim(),
            });
          }, child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    try {
      if (offer != null) {
        await _api.updateOffer(offer['id'], result);
      } else {
        await _api.createOffer(result);
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(gradient: AppColors.adminHeaderGradient),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          const Text('Offers', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('${_offers.length} offers', style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(180))),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () => _showForm()),
              ],
            ),
            if (_loading)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())))
            else if (_offers.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No offers yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 20),
                      FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('Create Offer')),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final o = _offers[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF8C38)]),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(child: Text('${o['discount_percent']}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    if (o['description'] != null)
                                      Text(o['description'], style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (o['is_active'] == true)
                                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(6)), child: const Text('Active', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600)))
                                        else
                                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.withAlpha(20), borderRadius: BorderRadius.circular(6)), child: const Text('Inactive', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    _showForm(o);
                                  } else if (v == 'delete') {
                                    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete'), content: const Text('Delete this offer?'), actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
                                    ]));
                                    if (confirm == true) {
                                      try {
                                        await _api.deleteOffer(o['id']);
                                        _load();
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'), dense: true)),
                                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)), dense: true)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _offers.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}