import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';

class AdminDeliveryZonePage extends StatefulWidget {
  const AdminDeliveryZonePage({super.key});

  @override
  State<AdminDeliveryZonePage> createState() => _AdminDeliveryZonePageState();
}

class _AdminDeliveryZonePageState extends State<AdminDeliveryZonePage> {
  final _api = AdminApiService();
  final _nameCtl = TextEditingController();
  final _points = <LatLng>[];
  List<Map<String, dynamic>> _savedZones = [];
  bool _saving = false;

  static const _center = LatLng(13.0827, 80.2707);

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    try {
      final zones = await _api.getDeliveryZones();
      if (!mounted) return;
      setState(() => _savedZones = zones.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  void _onMapTap(TapPosition tap, LatLng point) {
    setState(() => _points.add(point));
  }

  void _undoLastPoint() {
    if (_points.isNotEmpty) {
      setState(() => _points.removeLast());
    }
  }

  void _clearPoints() {
    setState(() => _points.clear());
  }

  Future<void> _saveZone() async {
    if (_points.length < 3) {
      _showSnack('Draw at least 3 points to form a polygon');
      return;
    }
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter a zone name');
      return;
    }

    final coords = _points.map((p) => [p.longitude, p.latitude]).toList();
    coords.add(coords.first);
    final geojson = jsonEncode({
      'type': 'Polygon',
      'coordinates': [coords],
    });

    setState(() => _saving = true);
    try {
      await _api.createDeliveryZone(name, geojson);
      if (!mounted) return;
      _showSnack('Zone "$name" saved');
      _nameCtl.clear();
      _points.clear();
      _loadZones();
    } catch (e) {
      if (mounted) _showSnack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Zones', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 11,
                      onTap: _onMapTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.myapp',
                      ),
                      if (_points.length >= 3)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _points,
                              color: Colors.deepPurple.withAlpha(50),
                              borderColor: Colors.deepPurple,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: _points.asMap().entries.map((e) {
                          return Marker(
                            point: e.value,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_savedZones.isNotEmpty)
                        ..._savedZones.map((z) {
                          try {
                            final geo = jsonDecode(z['geojson_data']);
                            final coords = geo['coordinates'][0] as List;
                            final pts = coords.map((c) => LatLng(c[1], c[0])).toList();
                            return PolygonLayer(
                              polygons: [
                                Polygon(
                                  points: pts,
                                  color: Colors.green.withAlpha(40),
                                  borderColor: Colors.green,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            );
                          } catch (_) {
                            return const SizedBox.shrink();
                          }
                        }),
                    ],
                  ),
                ),
                if (_savedZones.isNotEmpty)
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 4, offset: const Offset(0, -1))],
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      children: _savedZones.map((z) {
                        final zname = z['zone_name'] ?? '';
                        final zid = z['id'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.green.shade600),
                              const SizedBox(width: 8),
                              Expanded(child: Text(zname, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              InkWell(
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Zone'),
                                      content: Text('Delete "$zname"?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  try {
                                    await _api.deleteDeliveryZone(zid);
                                    _loadZones();
                                  } catch (e) {
                                    if (mounted) _showSnack('$e');
                                  }
                                },
                                child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtl,
                        decoration: InputDecoration(
                          hintText: 'Zone name',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _actionBtn(Icons.undo, 'Undo', _undoLastPoint),
                    const SizedBox(width: 4),
                    _actionBtn(Icons.clear_all, 'Clear', _clearPoints),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${_points.length} points drawn', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const Spacer(),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveZone,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save, size: 18),
                        label: Text(_saving ? 'Saving...' : 'Save Zone'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onTap,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
