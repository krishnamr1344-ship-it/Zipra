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
  final _mapController = MapController();
  List<Map<String, dynamic>> _savedZones = [];
  bool _saving = false;
  int? _selectedZoneIndex;
  LatLng _center = const LatLng(13.0827, 80.2707);

  static const _defaultCenter = LatLng(13.0827, 80.2707);

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _mapController.dispose();
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
    setState(() {
      _points.add(point);
      _selectedZoneIndex = null;
    });
  }

  void _undoLastPoint() {
    if (_points.isNotEmpty) setState(() => _points.removeLast());
  }

  void _clearPoints() {
    setState(() {
      _points.clear();
      _selectedZoneIndex = null;
    });
  }

  void _fitZoneBounds(List<LatLng> pts) {
    if (pts.isEmpty) return;
    double minLat = pts[0].latitude, maxLat = pts[0].latitude;
    double minLng = pts[0].longitude, maxLng = pts[0].longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds));
  }

  void _editZone(Map<String, dynamic> zone) {
    try {
      final geo = jsonDecode(zone['geojson_data']);
      final coords = geo['coordinates'][0] as List;
      final pts = coords.map((c) => LatLng(c[1], c[0])).toList();
      setState(() {
        _points.clear();
        _points.addAll(pts);
        _nameCtl.text = zone['zone_name'] ?? '';
        _selectedZoneIndex = _savedZones.indexOf(zone);
      });
      _fitZoneBounds(pts);
    } catch (_) {}
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
      if (_selectedZoneIndex != null) {
        final zid = _savedZones[_selectedZoneIndex!]['id'];
        await _api.updateDeliveryZone(zid, name, geojson);
        _showSnack('Zone "$name" updated');
      } else {
        await _api.createDeliveryZone(name, geojson);
        _showSnack('Zone "$name" saved');
      }
      _nameCtl.clear();
      _points.clear();
      _selectedZoneIndex = null;
      _loadZones();
    } catch (e) {
      if (mounted) _showSnack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    final zname = zone['zone_name'] ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Zone'),
        content: Text('Are you sure you want to delete "$zname"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteDeliveryZone(zone['id']);
      if (_selectedZoneIndex != null && _savedZones[_selectedZoneIndex!]['id'] == zone['id']) {
        _clearPoints();
      }
      _loadZones();
      _showSnack('Zone deleted');
    } catch (e) {
      if (mounted) _showSnack('$e');
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
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_savedZones.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.list, color: Colors.white),
              onSelected: (v) {
                final idx = int.parse(v);
                _editZone(_savedZones[idx]);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('Select zone to edit')),
                ..._savedZones.asMap().entries.map((e) => PopupMenuItem(
                  value: e.key.toString(),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Text(e.value['zone_name'] ?? ''),
                    ],
                  ),
                )),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
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
                      color: Colors.deepPurple.withAlpha(60),
                      borderColor: Colors.deepPurple,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: _points.asMap().entries.map((e) {
                  return Marker(
                    point: e.value,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_savedZones.isNotEmpty)
                ..._savedZones.asMap().entries.map((entry) {
                  final z = entry.value;
                  try {
                    final geo = jsonDecode(z['geojson_data']);
                    final coords = geo['coordinates'][0] as List;
                    final pts = coords.map((c) => LatLng(c[1], c[0])).toList();
                    final isSelected = _selectedZoneIndex == entry.key;
                    return PolygonLayer(
                      polygons: [
                        Polygon(
                          points: pts,
                          color: isSelected ? Colors.orange.withAlpha(50) : Colors.green.withAlpha(40),
                          borderColor: isSelected ? Colors.orange : Colors.green,
                          borderStrokeWidth: isSelected ? 3 : 2,
                        ),
                      ],
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                }),
            ],
          ),

          // Saved zones bottom sheet
          if (_savedZones.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 160,
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: _savedZones.length,
                  itemBuilder: (_, i) {
                    final z = _savedZones[i];
                    final zname = z['zone_name'] ?? '';
                    final zid = z['id'] ?? '';
                    final isSelected = _selectedZoneIndex == i;
                    return GestureDetector(
                      onTap: () => _editZone(z),
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey.withAlpha(40),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 14, color: Colors.green.shade600),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(zname, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('ID: $zid', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _deleteZone(z),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Controls at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 20, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zone name + controls
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtl,
                          decoration: InputDecoration(
                            hintText: _selectedZoneIndex != null ? 'Editing zone...' : 'Zone name',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.withAlpha(10),
                            prefixIcon: const Icon(Icons.edit_location_alt, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _smallBtn(Icons.undo, 'Undo', _undoLastPoint),
                      const SizedBox(width: 4),
                      _smallBtn(Icons.clear_all, 'Clear', _clearPoints),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withAlpha(15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.touch_app, size: 14, color: Colors.deepPurple.shade300),
                            const SizedBox(width: 4),
                            Text('${_points.length} pts',
                                style: TextStyle(fontSize: 11, color: Colors.deepPurple.shade400, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      if (_selectedZoneIndex != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Editing',
                              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500)),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveZone,
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(_selectedZoneIndex != null ? Icons.cloud_done : Icons.save, size: 18),
                          label: Text(_saving
                              ? 'Saving...'
                              : _selectedZoneIndex != null
                                  ? 'Update'
                                  : 'Save Zone'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

          // Point count floating chip
          if (_points.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_location, size: 16, color: Colors.deepPurple.shade300),
                    const SizedBox(width: 6),
                    Text('$_points points drawn',
                        style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade400, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _smallBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withAlpha(30)),
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
