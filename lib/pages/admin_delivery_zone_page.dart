import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';
import '../widgets/state_widgets.dart';

class AdminDeliveryZonePage extends StatefulWidget {
  const AdminDeliveryZonePage({super.key});

  @override
  State<AdminDeliveryZonePage> createState() => _AdminDeliveryZonePageState();
}

class _AdminDeliveryZonePageState extends State<AdminDeliveryZonePage> {
  final _api = AdminApiService();
  final _nameCtl = TextEditingController();
  final _points = <LatLng>[];
  List<SavedZone> _savedZones = [];
  bool _loading = true;
  bool _error = false;
  bool _saving = false;
  String? _editingZoneId;
  bool _showSavedZones = true;
  final _mapController = MapController();

  static const _defaultCenter = LatLng(13.0827, 80.2707);

  static const _zoneColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
  ];

  Color _colorForIndex(int i) => _zoneColors[i % _zoneColors.length];

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
    setState(() { _loading = true; _error = false; });
    try {
      final zones = await _api.getDeliveryZones();
      if (!mounted) return;
      setState(() {
        _savedZones = zones.map((z) => SavedZone(
          id: z['id'] ?? '',
          name: z['zone_name'] ?? '',
          geojson: z['geojson_data'] ?? '',
          color: _colorForIndex(_savedZones.length),
        )).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
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
    if (_points.isEmpty) return;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear points'),
        content: const Text('Remove all drawn points?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    ).then((confirm) {
      if (confirm == true) setState(() => _points.clear());
    });
  }

  List<LatLng> _geoJsonToPoints(String geojson) {
    try {
      final geo = jsonDecode(geojson);
      final coords = geo['coordinates'][0] as List;
      return coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
    } catch (_) {
      return [];
    }
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
      if (_editingZoneId != null) {
        await _api.updateDeliveryZone(_editingZoneId!, name, geojson);
        _editingZoneId = null;
      } else {
        await _api.createDeliveryZone(name, geojson);
      }
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

  void _editZone(SavedZone zone) {
    _nameCtl.text = zone.name;
    final pts = _geoJsonToPoints(zone.geojson);
    if (pts.length >= 3) {
      pts.removeLast();
    }
    setState(() {
      _points.clear();
      _points.addAll(pts);
      _editingZoneId = zone.id;
    });
    _zoomToPoints(pts);
  }

  void _zoomToPoints(List<LatLng> pts) {
    if (pts.isEmpty) return;
    var minLat = pts.first.latitude, maxLat = pts.first.latitude;
    var minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final zoom = _estimateZoom(latDiff, lngDiff);
    _mapController.move(center, zoom.clamp(3.0, 18.0));
  }

  double _estimateZoom(double latDiff, double lngDiff) {
    final maxDiff = max(latDiff, lngDiff);
    if (maxDiff < 0.005) return 16;
    if (maxDiff < 0.01) return 15;
    if (maxDiff < 0.03) return 14;
    if (maxDiff < 0.07) return 13;
    if (maxDiff < 0.15) return 12;
    return 11;
  }

  Future<void> _deleteZone(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Zone'),
        content: const Text('Are you sure you want to delete this delivery zone?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.deleteDeliveryZone(id);
        _loadZones();
        if (mounted) _showSnack('Zone deleted');
      } catch (e) {
        if (mounted) _showSnack('$e');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
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
            IconButton(
              icon: Icon(_showSavedZones ? Icons.visibility : Icons.visibility_off),
              tooltip: 'Toggle saved zones',
              onPressed: () => setState(() => _showSavedZones = !_showSavedZones),
            ),
        ],
      ),
      body: _loading
          ? const LoadingWidget(message: 'Loading zones\u2026')
          : _error
              ? ErrorStateWidget(onRetry: _loadZones)
              : Column(
                  children: [
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _defaultCenter,
                          initialZoom: 11,
                          onTap: _editingZoneId != null ? null : _onMapTap,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.myapp',
                          ),
                          if (_showSavedZones)
                            ..._savedZones.asMap().entries.map((entry) {
                              final pts = _geoJsonToPoints(entry.value.geojson);
                              if (pts.length < 3) return const SizedBox.shrink();
                              final color = _colorForIndex(entry.key);
                              return PolygonLayer(
                                polygons: [
                                  Polygon(
                                    points: pts,
                                    color: color.withAlpha(30),
                                    borderColor: color,
                                    borderStrokeWidth: 2.5,
                                  ),
                                ],
                              );
                            }),
                          if (_points.length >= 3)
                            PolygonLayer(
                              polygons: [
                                Polygon(
                                  points: List.from(_points),
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
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 4, offset: const Offset(0, 2)),
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
                          if (_showSavedZones)
                            ..._savedZones.asMap().entries.map((entry) {
                              final pts = _geoJsonToPoints(entry.value.geojson);
                              if (pts.isEmpty) return const SizedBox.shrink();
                              final center = pts.fold<LatLng>(
                                LatLng(0, 0),
                                (sum, p) => LatLng(sum.latitude + p.latitude / pts.length, sum.longitude + p.longitude / pts.length),
                              );
                              return MarkerLayer(
                                markers: [
                                  Marker(
                                    point: center,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _colorForIndex(_savedZones.indexOf(entry.value)).withAlpha(200),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        entry.value.name,
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                        ],
                      ),
                    ),
                    _buildBottomPanel(),
                  ],
                ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // Zone name + action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtl,
                    decoration: InputDecoration(
                      hintText: _editingZoneId != null ? 'Edit zone name' : 'Zone name',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                _actionBtn(Icons.undo, 'Undo', _undoLastPoint),
                const SizedBox(width: 4),
                _actionBtn(Icons.clear_all, 'Clear all', _clearPoints),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Points count + save button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _points.length >= 3 ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_points.length} ${_points.length == 1 ? 'point' : 'points'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _points.length >= 3 ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ),
                const Spacer(),
                if (_editingZoneId != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _editingZoneId = null;
                        _nameCtl.clear();
                        _points.clear();
                      });
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade400, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: const Text('Cancel edit', style: TextStyle(fontSize: 13)),
                  ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveZone,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_editingZoneId != null ? Icons.cloud_done : Icons.cloud_upload, size: 18),
                    label: Text(
                      _saving ? 'Saving...' : (_editingZoneId != null ? 'Update' : 'Save Zone'),
                      style: const TextStyle(fontSize: 13),
                    ),
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
          ),
          // Saved zones list
          if (_savedZones.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.map_rounded, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Saved Zones (${_savedZones.length})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _savedZones.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 44),
                itemBuilder: (ctx, i) {
                  final zone = _savedZones[i];
                  final color = _colorForIndex(i);
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.polyline_rounded, size: 18, color: color),
                    ),
                    title: Text(zone.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _smallIconBtn(Icons.my_location, 'Zoom to zone', color, () => _zoomToPoints(_geoJsonToPoints(zone.geojson))),
                        const SizedBox(width: 2),
                        _smallIconBtn(Icons.edit_rounded, 'Edit zone', Colors.grey.shade600, () => _editZone(zone)),
                        const SizedBox(width: 2),
                        _smallIconBtn(Icons.delete_rounded, 'Delete zone', Colors.red.shade400, () => _deleteZone(zone.id)),
                      ],
                    ),
                    onTap: () => _zoomToPoints(_geoJsonToPoints(zone.geojson)),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withAlpha(30)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onTap,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _smallIconBtn(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      onPressed: onTap,
      tooltip: tooltip,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 16,
    );
  }
}

class SavedZone {
  final String id;
  final String name;
  final String geojson;
  final Color color;
  SavedZone({required this.id, required this.name, required this.geojson, required this.color});
}
